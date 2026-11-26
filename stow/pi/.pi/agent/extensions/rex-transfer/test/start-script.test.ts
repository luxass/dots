/**
 * Run the generated start script against real Git repositories in a
 * temporary directory: a bare origin, the source checkout, and the host's
 * checkout under a fake HOME. pi and the fallback shell are stubs that
 * record how they were called. Git reads only a temporary config, so the
 * user's signing setup never applies to these throwaway repositories.
 */
import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import { chmodSync, existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { afterEach, beforeEach, test } from "node:test";
import { readLocalGitState, writeGitBundleFiles } from "../git-snapshot.ts";
import { buildTransferStartScript, transferBundleDirName, TRANSFER_BUNDLE_FILES, type TransferWorkspace } from "../transfer-plan.ts";

let root = "";
let env: NodeJS.ProcessEnv = {};

function git(cwd: string, ...args: string[]): string {
  return execFileSync("git", ["-C", cwd, ...args], { env, encoding: "utf8" }).trim();
}

function commitFile(repo: string, file: string, content: string, message: string): string {
  writeFileSync(join(repo, file), content);
  git(repo, "add", file);
  git(repo, "commit", "--quiet", "-m", message);
  return git(repo, "rev-parse", "HEAD");
}

beforeEach(() => {
  root = realpathSync(mkdtempSync(join(tmpdir(), "transfer-start-")));
  const gitConfig = join(root, "gitconfig");
  writeFileSync(gitConfig, "[user]\n\tname = Transfer Test\n\temail = transfer@example.invalid\n[init]\n\tdefaultBranch = main\n");
  env = {
    PATH: process.env.PATH,
    GIT_CONFIG_GLOBAL: gitConfig,
    GIT_CONFIG_NOSYSTEM: "1",
  };
});

afterEach(() => {
  rmSync(root, { recursive: true, force: true });
});

/** A bare origin, a source clone two commits ahead of a host clone, both on main. */
function setUpRepositories() {
  const origin = join(root, "origin.git");
  execFileSync("git", ["init", "--quiet", "--bare", origin], { env });
  const source = join(root, "source-home", "proj");
  mkdirSync(join(root, "source-home"), { recursive: true });
  execFileSync("git", ["clone", "--quiet", origin, source], { env });
  const first = commitFile(source, "tracked.txt", "one\n", "first");
  git(source, "push", "--quiet", "origin", "main");

  const hostHome = join(root, "host-home");
  mkdirSync(hostHome);
  execFileSync("git", ["clone", "--quiet", origin, join(hostHome, "proj")], { env });

  const second = commitFile(source, "tracked.txt", "two\n", "second");
  git(source, "push", "--quiet", "origin", "main");
  return { origin, source, hostHome, first, second };
}

/** Write the bundle into the host's HOME and run its start script there. */
async function runTransfer(source: string, hostHome: string, cwdRelative: string, topRelative = "proj") {
  const state = await readLocalGitState(source);
  assert.ok(state);
  const transferId = "t-1";
  const bundle = join(hostHome, transferBundleDirName(transferId));
  mkdirSync(bundle);
  writeFileSync(join(bundle, TRANSFER_BUNDLE_FILES.session), '{"type":"session"}\n');
  const written = await writeGitBundleFiles(state, bundle);
  const workspace: TransferWorkspace = {
    cwdRelative,
    git: { topRelative, head: state.head, branch: state.branch, ...written },
  };
  const script = join(bundle, TRANSFER_BUNDLE_FILES.script);
  writeFileSync(script, buildTransferStartScript({ transferId, sourceName: "source-mac", workspace }));

  const record = join(root, "record.txt");
  const piStub = join(root, "pi-stub");
  writeFileSync(piStub, `#!/bin/sh\nprintf 'pi cwd=%s args=%s\\n' "$(pwd)" "$*" > ${JSON.stringify(record)}\n`);
  const shellStub = join(root, "shell-stub");
  writeFileSync(shellStub, `#!/bin/sh\nprintf 'shell cwd=%s\\n' "$(pwd)" > ${JSON.stringify(record)}\n`);
  chmodSync(piStub, 0o755);
  chmodSync(shellStub, 0o755);

  const run = spawnSync("/bin/sh", [script], {
    env: { ...env, HOME: hostHome, PI_TRANSFER_PI: piStub, SHELL: shellStub },
    encoding: "utf8",
  });
  return {
    run,
    bundle,
    record: existsSync(record) ? readFileSync(record, "utf8").trim() : "",
    forkedSession: join(hostHome, ".cache", "pi-transfer", `${transferId}.jsonl`),
  };
}

test("fetches, fast-forwards, applies uncommitted and untracked work, then forks Pi", async () => {
  const { source, hostHome, second } = setUpRepositories();
  writeFileSync(join(source, "tracked.txt"), "two, edited\n");
  writeFileSync(join(source, "staged.txt"), "staged\n");
  git(source, "add", "staged.txt");
  mkdirSync(join(source, "notes"));
  writeFileSync(join(source, "notes", "untracked.md"), "untracked\n");
  mkdirSync(join(source, "web"));
  writeFileSync(join(source, ".gitignore"), "ignored.log\n");
  git(source, "add", ".gitignore");
  writeFileSync(join(source, "ignored.log"), "stays\n");
  writeFileSync(join(source, "web", "app.js"), "app\n");

  const result = await runTransfer(source, hostHome, "proj/web");
  const host = join(hostHome, "proj");

  assert.match(result.record, /^pi /, result.run.stderr);
  assert.equal(git(host, "rev-parse", "HEAD"), second);
  assert.equal(git(host, "symbolic-ref", "--short", "HEAD"), "main");
  assert.equal(readFileSync(join(host, "tracked.txt"), "utf8"), "two, edited\n");
  assert.equal(readFileSync(join(host, "staged.txt"), "utf8"), "staged\n");
  assert.equal(readFileSync(join(host, "notes", "untracked.md"), "utf8"), "untracked\n");
  assert.equal(readFileSync(join(host, "web", "app.js"), "utf8"), "app\n");
  assert.equal(existsSync(join(host, "ignored.log")), false);
  assert.equal(result.record, `pi cwd=${join(host, "web")} args=--fork ${result.forkedSession}`);
  assert.equal(existsSync(result.forkedSession), true);
  assert.equal(existsSync(result.bundle), false);
});

test("creates the branch on the host when it does not exist there", async () => {
  const { source, hostHome } = setUpRepositories();
  git(source, "switch", "--quiet", "-c", "feature");
  const feature = commitFile(source, "feature.txt", "f\n", "feature");
  git(source, "push", "--quiet", "origin", "feature");

  const result = await runTransfer(source, hostHome, "proj");
  const host = join(hostHome, "proj");

  assert.match(result.record, /^pi /, result.run.stderr);
  assert.equal(git(host, "symbolic-ref", "--short", "HEAD"), "feature");
  assert.equal(git(host, "rev-parse", "HEAD"), feature);
});

test("stops without changing anything when the host checkout has uncommitted changes", async () => {
  const { source, hostHome, first } = setUpRepositories();
  const host = join(hostHome, "proj");
  writeFileSync(join(host, "tracked.txt"), "local edit on the host\n");

  const result = await runTransfer(source, hostHome, "proj");

  assert.match(result.run.stderr, /has uncommitted changes on this Mac/);
  assert.equal(result.record, `shell cwd=${host}`);
  assert.equal(git(host, "rev-parse", "HEAD"), first);
  assert.equal(existsSync(result.bundle), true);
});

test("stops when the host's branch has commits the session does not", async () => {
  const { source, hostHome } = setUpRepositories();
  const host = join(hostHome, "proj");
  commitFile(host, "host-only.txt", "host\n", "host only");

  const result = await runTransfer(source, hostHome, "proj");

  assert.match(result.run.stderr, /has commits that the transferred session does not/);
  assert.match(result.record, /^shell /);
});

test("stops when an untracked file already exists on the host", async () => {
  const { source, hostHome } = setUpRepositories();
  writeFileSync(join(source, "new.txt"), "from source\n");
  writeFileSync(join(hostHome, "proj", "new.txt"), "already here\n");

  const result = await runTransfer(source, hostHome, "proj");

  assert.match(result.run.stderr, /untracked files already exist on this Mac:\n {2}new\.txt/);
  assert.equal(readFileSync(join(hostHome, "proj", "new.txt"), "utf8"), "already here\n");
  assert.match(result.record, /^shell /);
});

test("stops when the project is missing on the host", async () => {
  const { source, hostHome } = setUpRepositories();
  rmSync(join(hostHome, "proj"), { recursive: true, force: true });

  const result = await runTransfer(source, hostHome, "proj");

  assert.match(result.run.stderr, /~\/proj does not exist on this Mac/);
  assert.match(result.record, /^shell cwd=/);
});

test("a folder that is new in the transferred work does not need to exist on the host", async () => {
  const { source, hostHome } = setUpRepositories();
  mkdirSync(join(source, "docs"));
  writeFileSync(join(source, "docs", "plan.md"), "plan\n");

  const result = await runTransfer(source, hostHome, "proj/docs");

  assert.equal(result.record, `pi cwd=${join(hostHome, "proj", "docs")} args=--fork ${result.forkedSession}`);
});
