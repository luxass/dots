import type { ExtensionAPI, SessionInfo, Theme } from "@earendil-works/pi-coding-agent";
import { SessionManager, VERSION } from "@earendil-works/pi-coding-agent";

const ANSI_PATTERN = /\u001B\[[0-?]*[ -/]*[@-~]/g;

function visibleLength(value: string): number {
	return value.replace(ANSI_PATTERN, "").length;
}

function padRight(value: string, width: number): string {
	return value + " ".repeat(Math.max(0, width - visibleLength(value)));
}

function truncate(value: string, width: number): string {
	const clean = value.replace(/\s+/g, " ").trim();
	if (clean.length <= width) return clean;
	return `${clean.slice(0, Math.max(0, width - 1))}…`;
}

function timeAgo(date: Date): string {
	const seconds = Math.max(0, Math.floor((Date.now() - date.getTime()) / 1000));
	if (seconds < 60) return "just now";
	const minutes = Math.floor(seconds / 60);
	if (minutes < 60) return `${minutes}m ago`;
	const hours = Math.floor(minutes / 60);
	if (hours < 24) return `${hours}h ago`;
	const days = Math.floor(hours / 24);
	return `${days}d ago`;
}

function sessionLabel(session: SessionInfo): string {
	const label = session.name || session.firstMessage || session.id.slice(0, 8);
	return label.replace(/\s+/g, " ").trim();
}

function getPiLogo(theme: Theme): string[] {
	const left = (text: string) => theme.fg("customMessageLabel", text);
	const mid = (text: string) => theme.fg("accent", text);
	const right = (text: string) => theme.fg("userMessageText", text);

	return [
		` ${left("██")} ${mid("████")} ${right("██")}`,
		`    ${mid("██")}   ${right("██")}`,
		`    ${mid("██")}   ${right("██")}`,
		`    ${mid("██")}   ${right("██")}`,
		` ${left("██")} ${mid("████")} ${right("██")}`,
	];
}

function countExtensionSources(pi: ExtensionAPI): number {
	const sources = new Set<string>();

	for (const command of pi.getCommands()) {
		if (command.source === "extension" && command.sourceInfo?.path) {
			sources.add(command.sourceInfo.path);
		}
	}

	for (const tool of pi.getAllTools()) {
		const sourceInfo = tool.sourceInfo;
		if (sourceInfo?.path?.includes("/extensions/")) {
			sources.add(sourceInfo.path);
		}
	}

	return sources.size;
}

export default function (pi: ExtensionAPI) {
	pi.on("session_start", async (_event, ctx) => {
		if (ctx.mode !== "tui") return;

		const commands = pi.getCommands();
		const extensionCount = countExtensionSources(pi);
		const skillCount = commands.filter((command) => command.source === "skill").length;
		const promptCount = commands.filter((command) => command.source === "prompt").length;
		const recentSessions = await SessionManager.list(ctx.cwd).catch(() => [] as SessionInfo[]);
		const modelName = ctx.model?.id ?? "no model";
		const providerName = ctx.model?.provider ?? "provider unknown";

		ctx.ui.setHeader((_tui, theme) => {
			const border = (text: string) => theme.fg("borderMuted", text);
			const title = (text: string) => theme.fg("customMessageLabel", text);
			const heading = (text: string) => theme.fg("warning", text);
			const ok = (text: string) => theme.fg("success", text);
			const dim = (text: string) => theme.fg("dim", text);
			const muted = (text: string) => theme.fg("muted", text);
			const accent = (text: string) => theme.fg("accent", text);

			return {
				render(width: number): string[] {
					const boxWidth = Math.max(58, Math.min(86, width - 2));
					const leftWidth = 21;
					const rightWidth = boxWidth - leftWidth - 3;
					const label = " pi agent ";
					const topFill = Math.max(0, boxWidth - 4 - label.length);
					const rule = border("─".repeat(rightWidth));

					const model = truncate(modelName, leftWidth - 4);
					const provider = truncate(providerName, leftWidth - 6);
					const sessions = recentSessions
						.slice()
						.sort((a, b) => b.modified.getTime() - a.modified.getTime())
						.slice(0, 3);

					const leftLines = [
						"",
						`   ${theme.bold("Welcome back!")}`,
						"",
						...getPiLogo(theme).map((line) => `  ${line}`),
						"",
						` ${title(model)}`,
						`   ${muted(provider)}`,
					];

					const rightLines = [
						heading("Tips"),
						`${accent("/")} ${dim("for commands")}`,
						`${accent("!")} ${dim("to run bash")}`,
						`${dim("Shift+Tab")} cycle thinking`,
						rule,
						heading("Loaded"),
						`${ok("✓")} ${extensionCount} extensions`,
						`${ok("✓")} ${skillCount} skills`,
						`${ok("✓")} ${promptCount} prompt templates`,
						rule,
						heading("Recent sessions"),
						...(sessions.length > 0
							? sessions.map((session) => {
									const ago = `(${timeAgo(session.modified)})`;
									const labelWidth = Math.max(8, rightWidth - visibleLength(`•  ${ago}`) - 1);
									const label = truncate(sessionLabel(session), labelWidth);
									return `${accent("•")} ${label} ${dim(ago)}`;
								})
							: [dim("No recent sessions")]),
						"",
						`${dim("pi")} ${dim(`v${VERSION}`)}`,
					];

					const rowCount = Math.max(leftLines.length, rightLines.length);
					const rows = [
						`${border("╭──")}${title(label)}${border(`${"─".repeat(topFill)}╮`)}`,
					];

					for (let index = 0; index < rowCount; index++) {
						rows.push(
							`${border("│")}${padRight(leftLines[index] ?? "", leftWidth)}${border("│")}${padRight(rightLines[index] ?? "", rightWidth)}${border("│")}`,
						);
					}

					rows.push(`${border("╰")}${border("─".repeat(boxWidth - 2))}${border("╯")}`);
					return rows;
				},
				invalidate() {},
			};
		});
	});

	pi.registerCommand("builtin-header", {
		description: "Restore built-in header with keybinding hints",
		handler: async (_args, ctx) => {
			ctx.ui.setHeader(undefined);
			ctx.ui.notify("Built-in header restored", "info");
		},
	});
}
