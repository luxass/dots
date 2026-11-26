/**
 * Read the local Git state for a transfer and write the bundle's patch and
 * untracked-file archive. Uses git and tar without a shell. No Pi imports.
 */
import { execFile, spawn } from "node:child_process";
import { writeFile } from "node:fs/promises";
import { join } from "node:path";
import { TRANSFER_BUNDLE_FILES } from "./transfer-plan.ts";

/** The local repository state a transfer moves. */
export interface LocalGitState {
  /** Absolute repository top level. */
  top: string;
  /** Full commit ID of HEAD. */
  head: string;
  /** Checked-out branch, or undefined for a detached HEAD. */
  branch?: string;
  /** Remote-tracking branches that contain HEAD, so a host can fetch it. */
  remoteBranchesWithHead: string[];
  /** Tracked files with uncommitted changes, staged or not. */
  changedFiles: string[];
  /** Untracked files that Git does not ignore, relative to top. */
  untrackedFiles: string[];
}

function runGit(cwd: string, args: string[], encoding: "utf8" | "buffer" = "utf8"): Promise<{ ok: boolean; stdout: string | Buffer; stderr: string }> {
  return new Promise((resolve) => {
    execFile("git", ["-C", cwd, ...args], { encoding, maxBuffer: 512 * 1024 * 1024 }, (error, stdout, stderr) => {
      resolve({ ok: !error, stdout, stderr: String(stderr) });
    });
  });
}

async function gitText(cwd: string, args: string[]): Promise<string | undefined> {
  const result = await runGit(cwd, args);
  return result.ok ? String(result.stdout).trim() : undefined;
}

/** Split NUL-separated git output into paths. */
function nulSeparated(text: string): string[] {
  return text.split("\0").filter((path) => path !== "");
}

/**
 * The Git state of the repository that contains cwd, or undefined when cwd
 * is not in a repository. Throws for a repository without commits.
 */
export async function readLocalGitState(cwd: string): Promise<LocalGitState | undefined> {
  const top = await gitText(cwd, ["rev-parse", "--show-toplevel"]);
  if (!top) {
    return undefined;
  }
  const head = await gitText(top, ["rev-parse", "--verify", "HEAD^{commit}"]);
  if (!head) {
    throw new Error(`The repository at ${top} has no commits yet. Commit and push first.`);
  }
  const branch = await gitText(top, ["symbolic-ref", "--quiet", "--short", "HEAD"]);
  const remoteBranches = await gitText(top, ["branch", "--remotes", "--contains", head, "--format=%(refname:short)"]);
  const changed = await runGit(top, ["diff", "--name-only", "-z", "HEAD"]);
  const untracked = await runGit(top, ["ls-files", "--others", "--exclude-standard", "-z"]);
  if (!changed.ok || !untracked.ok) {
    throw new Error(`Could not read the working tree of ${top}: ${changed.stderr || untracked.stderr}`);
  }
  return {
    top,
    head,
    branch: branch || undefined,
    remoteBranchesWithHead: (remoteBranches ?? "").split("\n").filter((name) => name !== "" && !name.endsWith("/HEAD")),
    changedFiles: nulSeparated(String(changed.stdout)),
    untrackedFiles: nulSeparated(String(untracked.stdout)),
  };
}

/**
 * Write changes.patch (uncommitted changes to tracked files, binary safe)
 * and untracked.tgz into bundleDir. Returns which files it wrote.
 */
export async function writeGitBundleFiles(
  state: LocalGitState,
  bundleDir: string,
): Promise<{ hasPatch: boolean; hasUntracked: boolean }> {
  let hasPatch = false;
  if (state.changedFiles.length > 0) {
    const diff = await runGit(state.top, ["diff", "--binary", "HEAD"], "buffer");
    if (!diff.ok) {
      throw new Error(`git diff failed: ${diff.stderr}`);
    }
    await writeFile(join(bundleDir, TRANSFER_BUNDLE_FILES.patch), diff.stdout as Buffer);
    hasPatch = (diff.stdout as Buffer).length > 0;
  }

  let hasUntracked = false;
  if (state.untrackedFiles.length > 0) {
    await archiveFiles(state.top, state.untrackedFiles, join(bundleDir, TRANSFER_BUNDLE_FILES.untracked));
    hasUntracked = true;
  }
  return { hasPatch, hasUntracked };
}

/** Write a gzipped tar of paths (relative to cwd), read from stdin as a NUL list. */
function archiveFiles(cwd: string, paths: string[], archivePath: string): Promise<void> {
  return new Promise((resolve, reject) => {
    const tar = spawn("tar", ["-czf", archivePath, "--null", "-T", "-"], { cwd, stdio: ["pipe", "ignore", "pipe"] });
    let stderr = "";
    tar.stderr.on("data", (chunk) => {
      stderr += chunk;
    });
    tar.on("error", reject);
    tar.on("close", (code) => {
      if (code === 0) {
        resolve();
      } else {
        reject(new Error(`tar failed for the untracked files: ${stderr.trim()}`));
      }
    });
    tar.stdin.end(paths.map((path) => `${path}\0`).join(""));
  });
}
