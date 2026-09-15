import { execFile } from "node:child_process";

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

/**
 * Session sound and banner.
 *
 * Plays a macOS system sound and posts a notification banner whenever the
 * agent settles into idle (turn finished, waiting for input). Mirrors the
 * OpenCode notification plugin behavior for Pi.
 */
const SOUND = "/System/Library/Sounds/Glass.aiff";

function playSound(): void {
	try {
		const child = execFile("afplay", [SOUND], () => {});
		child.unref?.();
	} catch {
		// Sound is best-effort; never break the agent turn.
	}
}

function notifyBanner(message: string): void {
	try {
		const child = execFile(
			"osascript",
			["-e", `display notification ${JSON.stringify(message)} with title "Pi"`],
			() => {},
		);
		child.unref?.();
	} catch {
		// Banner is best-effort; never break the agent turn.
	}
}

export default function (pi: ExtensionAPI) {
	pi.on("agent_settled", (_event, ctx) => {
		if (ctx?.isIdle?.() !== true) return;
		notifyBanner("Agent is idle");
		playSound();
	});
}
