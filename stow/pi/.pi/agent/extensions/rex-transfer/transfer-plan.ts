/**
 * Plan a Pi session transfer to another Rex host: map paths under HOME, and
 * write the start script that runs on the host. Pure: no Pi imports and no
 * processes, so plain Node tests cover it.
 */
import { isAbsolute, relative, sep } from "node:path";

/** File names inside a transfer bundle. */
export const TRANSFER_BUNDLE_FILES = {
  session: "session.jsonl",
  patch: "changes.patch",
  untracked: "untracked.tgz",
  script: "start.sh",
} as const;

/** What the host needs to rebuild the workspace before Pi starts. */
export interface TransferWorkspace {
  /** Directory Pi runs in, relative to HOME, for example "dots" or "work/app/web". */
  cwdRelative: string;
  /** Present when the directory is inside a Git repository. */
  git?: {
    /** Repository top level, relative to HOME. */
    topRelative: string;
    /** Full commit ID of HEAD. */
    head: string;
    /** Checked-out branch, or undefined for a detached HEAD. */
    branch?: string;
    /** The bundle has changes.patch: uncommitted changes to tracked files. */
    hasPatch: boolean;
    /** The bundle has untracked.tgz: untracked files that Git does not ignore. */
    hasUntracked: boolean;
  };
}

/** Everything the start script needs. */
export interface TransferPlan {
  /** Unique ID of this transfer: letters, digits, and dashes only. */
  transferId: string;
  /** Name of the source machine, for the script's header and messages. */
  sourceName: string;
  workspace: TransferWorkspace;
}

/** Name of the bundle directory in the host's HOME. */
export function transferBundleDirName(transferId: string): string {
  assertTransferId(transferId);
  return `.pi-transfer-${transferId}`;
}

/** Reject IDs that could escape a path or a shell word. */
export function assertTransferId(transferId: string): void {
  if (!/^[A-Za-z0-9-]+$/.test(transferId)) {
    throw new Error(`Invalid transfer ID: ${transferId}`);
  }
}

/**
 * The path of `path` relative to `home`, with "/" separators. "" means home
 * itself. Throws for paths outside home, because the host's home directory
 * may differ and only paths under it can be mapped.
 */
export function pathRelativeToHome(path: string, home: string): string {
  const relativePath = relative(home, path);
  if (relativePath.startsWith("..") || isAbsolute(relativePath)) {
    throw new Error(`Transfer only maps directories under your home folder, not ${path}`);
  }
  return relativePath.split(sep).join("/");
}

/** Quote a value as one POSIX shell word. */
export function shellQuote(value: string): string {
  return `'${value.replace(/'/g, `'\\''`)}'`;
}

/** A shell expression for a path under the host's $HOME. */
export function homePathExpression(relativePath: string): string {
  return relativePath === "" ? `"$HOME"` : `"$HOME"/${shellQuote(relativePath)}`;
}

/** A path under HOME as people read it, for example "~/dots". */
export function displayHomePath(relativePath: string): string {
  return relativePath === "" ? "~" : `~/${relativePath}`;
}

function gitSection(git: NonNullable<TransferWorkspace["git"]>): string {
  const head = shellQuote(git.head);
  const shortHead = git.head.slice(0, 12);
  const repoName = shellQuote(displayHomePath(git.topRelative));
  const lines = [
    `cd "$repo" || transfer_failed "Could not enter "${repoName}"."`,
    `git rev-parse --is-inside-work-tree >/dev/null 2>&1 \\`,
    `  || transfer_failed ${repoName}" is not a Git repository on this Mac."`,
    `if [ -n "$(git status --porcelain --untracked-files=no)" ]; then`,
    `  transfer_failed ${repoName}" has uncommitted changes on this Mac. Commit or stash them, then transfer again."`,
    `fi`,
    `if ! git cat-file -e ${head}'^{commit}' 2>/dev/null; then`,
    `  printf 'Fetching commit %s...\\n' ${shellQuote(shortHead)}`,
    `  git fetch --quiet --all || transfer_failed "git fetch failed."`,
    `  git cat-file -e ${head}'^{commit}' 2>/dev/null \\`,
    `    || transfer_failed "Commit ${shortHead} is not on this Mac or its remotes. Push it, then transfer again."`,
    `fi`,
  ];
  if (git.branch) {
    const branch = shellQuote(git.branch);
    lines.push(
      `if git show-ref --verify --quiet refs/heads/${branch}; then`,
      `  git checkout --quiet ${branch} || transfer_failed "Could not check out branch "${branch}"."`,
      `  if [ "$(git rev-parse HEAD)" != ${head} ]; then`,
      `    git merge-base --is-ancestor HEAD ${head} \\`,
      `      || transfer_failed "Branch "${branch}" on this Mac has commits that the transferred session does not."`,
      `    git merge --quiet --ff-only ${head} || transfer_failed "Could not fast-forward branch "${branch}"."`,
      `  fi`,
      `else`,
      `  git checkout --quiet -b ${branch} ${head} || transfer_failed "Could not create branch "${branch}"."`,
      `fi`,
    );
  } else {
    lines.push(`git checkout --quiet --detach ${head} || transfer_failed "Could not check out ${shortHead}."`);
  }
  if (git.hasPatch) {
    lines.push(
      `git apply --whitespace=nowarn "$bundle/${TRANSFER_BUNDLE_FILES.patch}" \\`,
      `  || transfer_failed "The uncommitted changes did not apply cleanly."`,
    );
  }
  if (git.hasUntracked) {
    lines.push(
      `existing=$(tar -tzf "$bundle/${TRANSFER_BUNDLE_FILES.untracked}" | while IFS= read -r entry; do`,
      `  if [ -e "$repo/$entry" ] || [ -L "$repo/$entry" ]; then printf '  %s\\n' "$entry"; fi`,
      `done)`,
      `if [ -n "$existing" ]; then`,
      `  transfer_failed "These untracked files already exist on this Mac:`,
      `$existing"`,
      `fi`,
      `tar -xzf "$bundle/${TRANSFER_BUNDLE_FILES.untracked}" -C "$repo" \\`,
      `  || transfer_failed "Could not unpack the untracked files."`,
    );
  }
  return lines.join("\n");
}

/**
 * The POSIX sh script the host runs in a new Rex terminal. It checks and
 * updates the host's checkout, applies the uncommitted work, keeps the
 * conversation in ~/.cache/pi-transfer/, removes the bundle, and replaces
 * itself with `pi --fork`. When a step fails, it says why and opens a login
 * shell in the project instead, and leaves the bundle for a retry.
 *
 * PI_TRANSFER_PI overrides the pi command, for tests.
 */
export function buildTransferStartScript(plan: TransferPlan): string {
  const { transferId, sourceName, workspace } = plan;
  const bundleDir = transferBundleDirName(transferId);
  const project = displayHomePath(workspace.cwdRelative);
  const lines = [
    "#!/bin/sh",
    `# Written by Pi's /transfer on ${sourceName.replace(/[\r\n]/g, " ")}. Applies the transferred work to this`,
    "# Mac's checkout, then forks the conversation into it with pi --fork.",
    "set -u",
    `bundle=${homePathExpression(bundleDir)}`,
    `project=${homePathExpression(workspace.cwdRelative)}`,
    ...(workspace.git ? [`repo=${homePathExpression(workspace.git.topRelative)}`] : []),
    `sessions="$HOME/.cache/pi-transfer"`,
    `pi_command="\${PI_TRANSFER_PI:-pi}"`,
    "",
    "transfer_failed() {",
    `  printf '\\n/transfer stopped: %s\\n' "$1" >&2`,
    `  printf 'The transferred files stay in %s.\\n\\n' "$bundle" >&2`,
    `  cd "$project" 2>/dev/null || cd "$HOME" || :`,
    `  exec "\${SHELL:-/bin/sh}" -l`,
    "}",
  ];
  if (workspace.git) {
    // The project folder itself may be new in the transferred work, so only
    // the repository has to exist before the work is applied.
    const repo = displayHomePath(workspace.git.topRelative);
    lines.push(
      "",
      `[ -d "$repo" ] || transfer_failed ${shellQuote(`${repo} does not exist on this Mac. Clone the repository there, then transfer again.`)}`,
      gitSection(workspace.git),
    );
  } else {
    lines.push(
      "",
      `[ -d "$project" ] || transfer_failed ${shellQuote(`${project} does not exist on this Mac. Create it or copy the files there, then transfer again.`)}`,
    );
  }
  lines.push(
    "",
    `command -v "$pi_command" >/dev/null 2>&1 || PATH="$HOME/.local/share/pnpm/bin:$PATH"`,
    `command -v "$pi_command" >/dev/null 2>&1 || transfer_failed "pi is not installed on this Mac."`,
    `mkdir -p "$sessions" || transfer_failed "Could not create $sessions."`,
    `cp "$bundle/${TRANSFER_BUNDLE_FILES.session}" "$sessions/${transferId}.jsonl" \\`,
    `  || transfer_failed "Could not keep the conversation in $sessions."`,
    `rm -rf "$bundle"`,
    `cd "$project" || transfer_failed ${shellQuote(`Could not enter ${project}.`)}`,
    `exec "$pi_command" --fork "$sessions/${transferId}.jsonl"`,
    "",
  );
  return lines.join("\n");
}

/** A host label from `rex api call hosts.list`. */
export function parseRexHostLabels(hostsList: unknown): string[] {
  const hosts = (hostsList as { hosts?: unknown } | null)?.hosts;
  if (!Array.isArray(hosts)) {
    return [];
  }
  return hosts
    .map((host) => (host as { label?: unknown }).label)
    .filter((label): label is string => typeof label === "string" && label !== "");
}

/** Sessions from `rex api call session.list`, as { sessionId, label }. */
export function parseRexSessions(sessionList: unknown): { sessionId: string; label: string }[] {
  const sessions = (sessionList as { sessions?: unknown } | null)?.sessions;
  if (!Array.isArray(sessions)) {
    return [];
  }
  return sessions.flatMap((session) => {
    const { session_id: sessionId, label } = session as { session_id?: unknown; label?: unknown };
    return typeof sessionId === "string"
      ? [{ sessionId, label: typeof label === "string" && label !== "" ? label : sessionId }]
      : [];
  });
}
