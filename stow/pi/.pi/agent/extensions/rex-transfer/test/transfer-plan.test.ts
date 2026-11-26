import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import {
  buildTransferStartScript,
  displayHomePath,
  homePathExpression,
  parseRexHostLabels,
  parseRexSessions,
  pathRelativeToHome,
  shellQuote,
  transferBundleDirName,
} from "../transfer-plan.ts";

test("pathRelativeToHome maps paths under home and rejects others", () => {
  assert.equal(pathRelativeToHome("/Users/me/dots", "/Users/me"), "dots");
  assert.equal(pathRelativeToHome("/Users/me/work/app/web", "/Users/me"), "work/app/web");
  assert.equal(pathRelativeToHome("/Users/me", "/Users/me"), "");
  assert.throws(() => pathRelativeToHome("/opt/project", "/Users/me"), /under your home folder/);
  assert.throws(() => pathRelativeToHome("/Users/meme/x", "/Users/me"), /under your home folder/);
});

test("shellQuote keeps every character literal", () => {
  const tricky = "it's $HOME `id` \"quoted\" ; rm -rf /";
  const echoed = execFileSync("/bin/sh", ["-c", `printf '%s' ${shellQuote(tricky)}`], { encoding: "utf8" });
  assert.equal(echoed, tricky);
});

test("homePathExpression and displayHomePath handle home itself", () => {
  assert.equal(homePathExpression(""), '"$HOME"');
  assert.equal(homePathExpression("my dir"), `"$HOME"/'my dir'`);
  assert.equal(displayHomePath(""), "~");
  assert.equal(displayHomePath("dots"), "~/dots");
});

test("transferBundleDirName rejects IDs that could escape a path", () => {
  assert.equal(transferBundleDirName("abc-123"), ".pi-transfer-abc-123");
  assert.throws(() => transferBundleDirName("../x"), /Invalid transfer ID/);
  assert.throws(() => transferBundleDirName("a b"), /Invalid transfer ID/);
});

test("the start script is valid sh for every workspace shape", () => {
  const dir = mkdtempSync(join(tmpdir(), "transfer-plan-"));
  try {
    const workspaces = [
      { cwdRelative: "notes" },
      { cwdRelative: "", git: { topRelative: "", head: "a".repeat(40), hasPatch: false, hasUntracked: false } },
      {
        cwdRelative: "work/it's/web",
        git: { topRelative: "work/it's", head: "b".repeat(40), branch: "feat/o'brien", hasPatch: true, hasUntracked: true },
      },
    ];
    for (const workspace of workspaces) {
      const script = join(dir, "start.sh");
      writeFileSync(script, buildTransferStartScript({ transferId: "t-1", sourceName: "mac", workspace }));
      execFileSync("/bin/sh", ["-n", script]);
    }
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("parseRexHostLabels and parseRexSessions read Rex API results", () => {
  assert.deepEqual(parseRexHostLabels({ hosts: [{ label: "Ember" }, { label: "" }, {}] }), ["Ember"]);
  assert.deepEqual(parseRexHostLabels(null), []);
  assert.deepEqual(
    parseRexSessions({ sessions: [{ session_id: "session:1", label: "dots" }, { session_id: "session:2" }, { label: "x" }] }),
    [
      { sessionId: "session:1", label: "dots" },
      { sessionId: "session:2", label: "session:2" },
    ],
  );
});
