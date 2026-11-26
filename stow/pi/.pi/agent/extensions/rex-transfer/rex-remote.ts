/**
 * The rex commands a transfer runs: list hosts and sessions, copy the
 * bundle, and start the transferred session on the host. Runs rex without a
 * shell and never starts a server (--autostart=false). No Pi imports.
 */
import { execFile } from "node:child_process";
import { accessSync, constants } from "node:fs";
import { homedir } from "node:os";
import { delimiter, join } from "node:path";
import { assertTransferId, parseRexHostLabels, parseRexSessions, transferBundleDirName, TRANSFER_BUNDLE_FILES } from "./transfer-plan.ts";

/** Where the Rex app installs its CLI, for Pi sessions outside Rex. */
const REX_BUNDLED_CLI = join(
  homedir(),
  "Library/Application Support/com.superlogical.rex/RexServer/Versions/Current/Rex Server.app/Contents/MacOS/rex",
);

function isExecutable(path: string): boolean {
  try {
    accessSync(path, constants.X_OK);
    return true;
  } catch {
    return false;
  }
}

/** REX_BIN_DIR first (it matches the running server inside a pane), then PATH, then the app's copy. */
function findRexCli(): string {
  const candidates = [
    process.env.REX_BIN_DIR ? join(process.env.REX_BIN_DIR, "rex") : undefined,
    ...(process.env.PATH ?? "").split(delimiter).filter(Boolean).map((dir) => join(dir, "rex")),
    REX_BUNDLED_CLI,
  ];
  const found = candidates.find((candidate): candidate is string => candidate !== undefined && isExecutable(candidate));
  if (!found) {
    throw new Error("Rex CLI not found: launch Rex once so it installs its CLI");
  }
  return found;
}

/** Run rex and return stdout. Throws Rex's error message on a non-zero exit. */
function runRex(args: string[], what: string, timeoutMs = 30_000): Promise<string> {
  const binary = findRexCli();
  return new Promise((resolve, reject) => {
    execFile(
      binary,
      ["--autostart=false", ...args],
      { encoding: "utf8", maxBuffer: 16 * 1024 * 1024, timeout: timeoutMs },
      (error, stdout, stderr) => {
        if (error) {
          const message = (stderr.trim() || stdout.trim() || error.message).replace(/^Error:\s*/, "");
          reject(new Error(`Rex ${what} failed: ${message}`));
          return;
        }
        resolve(stdout);
      },
    );
  });
}

async function callRexJson(server: string | undefined, method: string): Promise<unknown> {
  const stdout = await runRex([...(server ? ["-S", server] : []), "api", "call", method], method, 15_000);
  return JSON.parse(stdout);
}

/** Labels of the hosts the local Rex server knows. */
export async function listRexHostLabels(): Promise<string[]> {
  return parseRexHostLabels(await callRexJson(undefined, "hosts.list"));
}

/** Fail fast when the host does not answer, with Rex's reason. */
export async function checkRexHostReachable(host: string): Promise<void> {
  await runRex(["-S", host, "--timeout", "8s", "api", "call", "server.version"], `connection to ${host}`, 15_000);
}

/** The host's Rex sessions. */
export async function listRexHostSessions(host: string): Promise<{ sessionId: string; label: string }[]> {
  return parseRexSessions(await callRexJson(host, "session.list"));
}

/** Copy the local bundle directory into the host's HOME as transferBundleDirName(transferId). */
export async function copyBundleToRexHost(host: string, bundleDir: string, transferId: string): Promise<void> {
  await runRex(["-S", host, "cp", "-r", bundleDir, `:${transferBundleDirName(transferId)}`], `copy to ${host}`, 10 * 60_000);
}

/** Where on the host the start script runs from. */
export type RexHostTarget = { sessionId: string } | { newSessionLabel: string };

/**
 * Start the bundle's start script in a new terminal on the host: a new window
 * in an existing session, or a new session. The host's login environment
 * provides PATH, and its /bin/sh expands $HOME.
 */
export async function startTransferOnRexHost(
  host: string,
  target: RexHostTarget,
  transferId: string,
  blockLabel: string,
): Promise<void> {
  assertTransferId(transferId);
  const command = [
    "/bin/sh",
    "-c",
    `exec /bin/sh "$HOME/${transferBundleDirName(transferId)}/${TRANSFER_BUNDLE_FILES.script}"`,
  ];
  const placement = "sessionId" in target
    ? ["run", "-s", target.sessionId, "--label", blockLabel]
    : ["new", target.newSessionLabel];
  await runRex(["-S", host, ...placement, "--", ...command], `start on ${host}`);
}
