import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { isToolCallEventType } from "@earendil-works/pi-coding-agent";

const GIT_ENV_PREFIX =
  "export GIT_EDITOR=true GIT_SEQUENCE_EDITOR=true GIT_MERGE_AUTOEDIT=no\n";

const NO_VERIFY_RE = /--no-verify\b/;
const GIT_RE = /(^|\s)git(\s|$)/;

const BLOCK_REASON = [
  "Blocked git command containing --no-verify.",
  "Fix the hook failure instead of bypassing repository safeguards."
].join(" ");

export default function (pi: ExtensionAPI) {
  pi.on("tool_call", (event) => {
    if (!isToolCallEventType("bash", event)) return undefined;

    const { command } = event.input;
    if (!GIT_RE.test(command)) return undefined;

    if (NO_VERIFY_RE.test(command)) {
      return { block: true, reason: BLOCK_REASON };
    }

    if (!command.startsWith(GIT_ENV_PREFIX)) {
      event.input.command = `${GIT_ENV_PREFIX}${command}`;
    }

    return undefined;
  });
}
