/**
 * Git command interceptor.
 *
 * Applies two small guards to agent-driven git commands:
 *
 * 1. Editor hang prevention: set GIT_EDITOR and GIT_SEQUENCE_EDITOR to `true`,
 *    and GIT_MERGE_AUTOEDIT to `no`, so git does not open an interactive editor
 *    that would hang the shell tool.
 *
 * 2. Hook/signature bypass prevention: block `--no-verify` and
 *    `--no-gpg-sign` so the agent cannot skip repository safeguards.
 *    Hook or signing failures should be fixed or escalated to the user.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { isToolCallEventType } from "@earendil-works/pi-coding-agent";

const GIT_ENV_PREFIX =
  "export GIT_EDITOR=true GIT_SEQUENCE_EDITOR=true GIT_MERGE_AUTOEDIT=no\n";

const NO_GPG_SIGN_RE = /--no-gpg-sign\b/;
const NO_VERIFY_RE = /--no-verify\b/;
const GIT_RE = /(^|\s)git(\s|$)/;

const NO_GPG_SIGN_REASON = [
  "Blocked git command containing --no-gpg-sign.",
  "Signing must not be bypassed. This requires immediate user action: remove the flag and fix commit signing, or ask the user to commit manually."
].join(" ");

const NO_VERIFY_REASON = [
  "Blocked git command containing --no-verify.",
  "Fix hook failures instead of bypassing repository safeguards."
].join(" ");

export default function (pi: ExtensionAPI) {
  pi.on("tool_call", (event) => {
    if (!isToolCallEventType("bash", event)) return undefined;

    const { command } = event.input;
    if (!GIT_RE.test(command)) return undefined;

    if (NO_GPG_SIGN_RE.test(command)) {
      return { block: true, reason: NO_GPG_SIGN_REASON };
    }

    if (NO_VERIFY_RE.test(command)) {
      return { block: true, reason: NO_VERIFY_REASON };
    }

    if (!command.startsWith(GIT_ENV_PREFIX)) {
      event.input.command = `${GIT_ENV_PREFIX}${command}`;
    }

    return undefined;
  });
}
