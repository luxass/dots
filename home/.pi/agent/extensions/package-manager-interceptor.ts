/**
 * Package-manager command interceptor.
 *
 * Registers a wrapped bash tool that prepends `intercepted-commands/` to PATH.
 * The shim scripts for `pnpm`, `npm`, `yarn`, and `bun` route install-like
 * commands through Socket Firewall (`sfw`) and leave read-only commands alone.
 *
 * A spawn hook still blocks explicit install-policy bypass flags, including
 * attempts that call package managers by absolute path and bypass the shims.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { createBashTool } from "@earendil-works/pi-coding-agent";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const interceptedCommandsPath = join(__dirname, "..", "intercepted-commands");

const BLOCKED_FLAGS = [
	"--ignore-scripts=false",
	"--enable-pre-post-scripts",
	"--dangerously-allow-all-builds",
	"--allow-scripts",
];

const PACKAGE_MANAGER_SEGMENT_RE =
	/(?:^|\n|[;|&]{1,2})\s*(?:\S+\/)?(?:pnpm|npm|yarn|bun)\b[^\n;|&]*/m;

function getBlockedCommandMessage(command: string): string | null {
	const segment = command.match(PACKAGE_MANAGER_SEGMENT_RE)?.[0] ?? "";
	const blockedFlag = BLOCKED_FLAGS.find((flag) => segment.includes(flag));
	if (!blockedFlag) {
		return null;
	}

	return [
		`Error: package-manager safety bypass flag is disabled: ${blockedFlag}`,
		"",
		"Keep dependency lifecycle-script and build-approval policy intact.",
		"Use the tracked npm/pnpm/Bun policy or ask the user before changing it.",
		"",
	].join("\n");
}

export default function packageManagerInterceptor(pi: ExtensionAPI) {
	const cwd = process.cwd();
	const bashTool = createBashTool(cwd, {
		commandPrefix: `export PATH="${interceptedCommandsPath}:$PATH"`,
		spawnHook: (ctx) => {
			const blockedMessage = getBlockedCommandMessage(ctx.command);
			if (blockedMessage) {
				throw new Error(blockedMessage);
			}
			return ctx;
		},
	});

	pi.registerTool(bashTool);
}
