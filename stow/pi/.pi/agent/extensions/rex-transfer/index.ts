/**
 * /transfer [host]: move this Pi conversation, and in a Git repository its
 * uncommitted work, to another Rex host, then continue it there with
 * `pi --fork` in the same project under the host's home folder.
 *
 * - The host must already have the repository at the same path under HOME.
 *   HEAD must be pushed, so the host can fetch it; the host's checkout must
 *   have no uncommitted changes.
 * - Moves: the conversation, uncommitted changes to tracked files, and
 *   untracked files that Git does not ignore. Ignored files stay here.
 * - Uses rex cp and rex run against the host, no SSH. This session stays
 *   open here; nothing local is changed or deleted.
 */
import type { ExtensionAPI, ExtensionCommandContext } from "@earendil-works/pi-coding-agent";
import { randomUUID } from "node:crypto";
import { chmod, copyFile, mkdir, mkdtemp, rm, writeFile } from "node:fs/promises";
import { homedir, hostname, tmpdir } from "node:os";
import { basename, join } from "node:path";
import { readLocalGitState, writeGitBundleFiles, type LocalGitState } from "./git-snapshot.ts";
import {
  checkRexHostReachable,
  copyBundleToRexHost,
  listRexHostLabels,
  listRexHostSessions,
  startTransferOnRexHost,
  type RexHostTarget,
} from "./rex-remote.ts";
import {
  buildTransferStartScript,
  displayHomePath,
  pathRelativeToHome,
  TRANSFER_BUNDLE_FILES,
  type TransferWorkspace,
} from "./transfer-plan.ts";

const STATUS_KEY = "rex-transfer";

/** A short unique transfer ID: time and randomness, letters, digits, and dashes. */
function newTransferId(): string {
  return `${Date.now().toString(36)}-${randomUUID().slice(0, 8)}`;
}

function plural(count: number, word: string): string {
  return `${count} ${word}${count === 1 ? "" : "s"}`;
}

/** Ask which host to use, unless the argument names one. */
async function chooseRexHost(argument: string, ctx: ExtensionCommandContext): Promise<string | undefined> {
  const hosts = await listRexHostLabels();
  if (argument !== "") {
    if (!hosts.includes(argument)) {
      throw new Error(`Unknown Rex host "${argument}". Known hosts: ${hosts.join(", ") || "none"}`);
    }
    return argument;
  }
  if (hosts.length === 0) {
    throw new Error("Rex knows no other hosts. Add one in Rex first.");
  }
  return ctx.ui.select("Transfer this session to which Rex host?", hosts);
}

/** Ask where on the host the session continues: a new session, or a window in an existing one. */
async function chooseRexHostTarget(
  host: string,
  projectName: string,
  ctx: ExtensionCommandContext,
): Promise<{ target: RexHostTarget; description: string } | undefined> {
  const sessions = await listRexHostSessions(host);
  const newSessionOption = `New Rex session "${projectName}"`;
  const choice = await ctx.ui.select(`Where on ${host}?`, [
    newSessionOption,
    ...sessions.map((session) => `New window in "${session.label}"`),
  ]);
  if (choice === undefined) {
    return undefined;
  }
  if (choice === newSessionOption) {
    return { target: { newSessionLabel: projectName }, description: `a new Rex session "${projectName}"` };
  }
  const session = sessions[sessions.findIndex((candidate) => choice === `New window in "${candidate.label}"`)];
  return { target: { sessionId: session.sessionId }, description: `a new window in "${session.label}"` };
}

/** The confirmation text that says what moves where. */
function describeTransfer(host: string, workspace: TransferWorkspace, git: LocalGitState | undefined, where: string): string {
  const lines = [`Pi continues on ${host} in ${displayHomePath(workspace.cwdRelative)}, in ${where}.`];
  if (git && workspace.git) {
    lines.push(
      `Checkout there: ${displayHomePath(workspace.git.topRelative)} at ${git.head.slice(0, 12)}${git.branch ? ` (${git.branch})` : " (detached)"}.`,
      `Moves: the conversation, ${plural(git.changedFiles.length, "changed file")}, and ${plural(git.untrackedFiles.length, "untracked file")}.`,
      "Ignored files stay here. This session stays open here.",
    );
  } else {
    lines.push("Moves: the conversation only. Files in this folder stay here.");
  }
  return lines.join("\n");
}

async function transferSession(argument: string, ctx: ExtensionCommandContext): Promise<void> {
  if (!ctx.hasUI) {
    return;
  }
  await ctx.waitForIdle();
  const sessionFile = ctx.sessionManager.getSessionFile();
  if (!sessionFile) {
    throw new Error("This session is not saved to a file, so there is nothing to transfer.");
  }

  const host = await chooseRexHost(argument, ctx);
  if (!host) {
    return;
  }
  ctx.ui.setStatus(STATUS_KEY, `Connecting to ${host}…`);
  await checkRexHostReachable(host);

  const home = homedir();
  const git = await readLocalGitState(ctx.cwd);
  const workspace: TransferWorkspace = { cwdRelative: pathRelativeToHome(ctx.cwd, home) };
  if (git) {
    if (git.remoteBranchesWithHead.length === 0) {
      throw new Error(
        `HEAD (${git.head.slice(0, 12)}) is not on any remote branch, so ${host} cannot fetch it. Push it first (git push).`,
      );
    }
    workspace.git = {
      topRelative: pathRelativeToHome(git.top, home),
      head: git.head,
      branch: git.branch,
      hasPatch: false,
      hasUntracked: false,
    };
  }

  const projectName = basename(git?.top ?? ctx.cwd) || "pi";
  ctx.ui.setStatus(STATUS_KEY, undefined);
  const where = await chooseRexHostTarget(host, projectName, ctx);
  if (!where) {
    return;
  }
  const confirmed = await ctx.ui.confirm(`Transfer to ${host}?`, describeTransfer(host, workspace, git, where.description));
  if (!confirmed) {
    return;
  }

  const transferId = newTransferId();
  const scratchDir = await mkdtemp(join(tmpdir(), "pi-transfer-"));
  try {
    ctx.ui.setStatus(STATUS_KEY, `Packing the transfer for ${host}…`);
    const bundleDir = join(scratchDir, "bundle");
    await mkdir(bundleDir);
    await copyFile(sessionFile, join(bundleDir, TRANSFER_BUNDLE_FILES.session));
    if (git && workspace.git) {
      const written = await writeGitBundleFiles(git, bundleDir);
      workspace.git.hasPatch = written.hasPatch;
      workspace.git.hasUntracked = written.hasUntracked;
    }
    const scriptPath = join(bundleDir, TRANSFER_BUNDLE_FILES.script);
    await writeFile(scriptPath, buildTransferStartScript({ transferId, sourceName: hostname(), workspace }));
    await chmod(scriptPath, 0o755);

    ctx.ui.setStatus(STATUS_KEY, `Copying to ${host}…`);
    await copyBundleToRexHost(host, bundleDir, transferId);
    ctx.ui.setStatus(STATUS_KEY, `Starting Pi on ${host}…`);
    await startTransferOnRexHost(host, where.target, transferId, `pi ${projectName}`);
    ctx.ui.notify(`Pi continues on ${host}. This session stays here; close it when you are done.`, "info");
  } finally {
    ctx.ui.setStatus(STATUS_KEY, undefined);
    await rm(scratchDir, { recursive: true, force: true });
  }
}

export default function rexTransfer(pi: ExtensionAPI) {
  pi.registerCommand("transfer", {
    description: "Move this conversation and its uncommitted work to another Rex host",
    getArgumentCompletions: async (prefix: string) => {
      const hosts = await listRexHostLabels().catch(() => [] as string[]);
      const matches = hosts.filter((host) => host.toLowerCase().startsWith(prefix.toLowerCase()));
      return matches.length > 0 ? matches.map((host) => ({ value: host, label: host })) : null;
    },
    handler: async (args, ctx) => {
      try {
        await transferSession(args.trim(), ctx);
      } catch (error) {
        ctx.ui.setStatus(STATUS_KEY, undefined);
        ctx.ui.notify(`Transfer failed: ${error instanceof Error ? error.message : String(error)}`, "error");
      }
    },
  });
}
