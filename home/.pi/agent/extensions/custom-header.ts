import type { ExtensionAPI, ExtensionContext, Theme } from "@earendil-works/pi-coding-agent";
import { VERSION } from "@earendil-works/pi-coding-agent";
import { existsSync } from "node:fs";
import { readdir } from "node:fs/promises";
import { basename, dirname, fileURLToPath, join, relative, resolve } from "node:path";
import { Key, matchesKey, truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

const HEADER_MAX_WIDTH = 72;
const COMPACT_WIDTH = 44;

type ResourceSnapshot = {
	context: string[];
	skills: string[];
	extensions: string[];
};

function fit(text: string, width: number): string {
	const clipped = truncateToWidth(text, width, "…");
	return clipped + " ".repeat(Math.max(0, width - visibleWidth(clipped)));
}

function wrap(text: string, width: number): string[] {
	if (width < 1) return [""];

	const lines: string[] = [];
	let line = "";
	for (const word of text.split(/\s+/).filter(Boolean)) {
		if (word.length > width) {
			if (line) lines.push(line);
			line = "";
			for (let index = 0; index < word.length; index += width) {
				lines.push(word.slice(index, index + width));
			}
			continue;
		}

		const next = line ? `${line} ${word}` : word;
		if (next.length > width) {
			lines.push(line);
			line = word;
		} else {
			line = next;
		}
	}

	if (line) lines.push(line);
	return lines.length > 0 ? lines : [""];
}

function resourceName(path: string): string {
	const parts = path.replaceAll("\\", "/").split("/");
	const file = parts.at(-1) ?? path;
	if (file === "index.ts" || file === "index.js") return parts.at(-2) ?? file;
	return file.replace(/\.[cm]?[jt]sx?$/i, "");
}

async function collectResources(pi: ExtensionAPI, ctx: ExtensionContext): Promise<ResourceSnapshot> {
	const extensionPaths = new Set<string>();
	try {
		const extensionDir = dirname(fileURLToPath(import.meta.url));
		for (const entry of await readdir(extensionDir, { withFileTypes: true })) {
			if (entry.isFile() && /\.[cm]?[jt]sx?$/i.test(entry.name)) {
				extensionPaths.add(join(extensionDir, entry.name));
			}
		}
	} catch {
		// The extension directory may not be readable.
	}

	for (const command of pi.getCommands()) {
		if (command.source === "extension") extensionPaths.add(command.sourceInfo.path);
	}
	for (const tool of pi.getAllTools()) {
		if (tool.sourceInfo.source !== "builtin" && tool.sourceInfo.source !== "sdk") {
			extensionPaths.add(tool.sourceInfo.path);
		}
	}

	const context: string[] = [];
	let directory = resolve(ctx.cwd);
	while (true) {
		for (const filename of ["AGENTS.md", "CLAUDE.md"]) {
			const path = join(directory, filename);
			if (existsSync(path)) context.push(relative(ctx.cwd, path) || filename);
		}
		const parent = dirname(directory);
		if (parent === directory) break;
		directory = parent;
	}

	return {
		context: context.sort(),
		skills: pi
			.getCommands()
			.filter((command) => command.source === "skill")
			.map((command) => command.name.replace(/^skill:/, ""))
			.sort(),
		extensions: [...extensionPaths].map(resourceName).filter(Boolean).sort(),
	};
}

function renderHeader(theme: Theme, width: number, project: string, model: string): string[] {
	const accent = (text: string) => theme.fg("accent", text);
	const heading = (text: string) => theme.fg("mdHeading", theme.bold(text));
	const muted = (text: string) => theme.fg("muted", text);
	const dim = (text: string) => theme.fg("dim", text);
	const title = `${accent("π")} ${heading("Pi")} ${dim(`v${VERSION}`)}`;

	if (width < COMPACT_WIDTH) {
		return [fit(title, width), fit(muted("/ for commands · ! for shell"), width)];
	}

	const panelWidth = Math.min(HEADER_MAX_WIDTH, width - 4);
	const contentWidth = panelWidth - 2;
	const border = (text: string) => theme.fg("borderAccent", text);
	const line = (text = "") => `│${fit(` ${text}`, contentWidth)}│`;

	return [
		`  ${border(`╭${"─".repeat(panelWidth - 2)}╮`)}`,
		`  ${border(line(title))}`,
		`  ${border(line(`${muted(project)} ${dim("·")} ${dim(model)}`))}`,
		`  ${border(line())}`,
		`  ${border(line(`${accent("/")} ${muted("commands")}   ${accent("!")} ${muted("shell")}   ${accent("⇧Tab")} ${muted("thinking")}   ${accent("/resources")} ${muted("resources")}`))}`,
		`  ${border(`╰${"─".repeat(panelWidth - 2)}╯`)}`,
	];
}

function renderResources(snapshot: ResourceSnapshot, theme: Theme, width: number): string[] {
	if (width < 6) return [fit("Resources", width)];

	const panelWidth = Math.min(86, width);
	const contentWidth = panelWidth - 2;
	const border = (text: string) => theme.fg("borderAccent", text);
	const heading = (text: string) => theme.fg("mdHeading", theme.bold(text));
	const muted = (text: string) => theme.fg("muted", text);
	const dim = (text: string) => theme.fg("dim", text);
	const accent = (text: string) => theme.fg("accent", text);
	const line = (text = "") => `${border("│")}${fit(text, contentWidth)}${border("│")}`;
	const lines = [
		border(`╭${"─".repeat(panelWidth - 2)}╮`),
		line(`${accent("π")} ${heading("Resources")}`),
		line(dim("Loaded for this session")),
		line(),
	];

	const sections: Array<[string, string[], string]> = [
		["Context", snapshot.context, "✓"],
		["Skills", snapshot.skills, "•"],
		["Extensions", snapshot.extensions, "•"],
	];
	for (const [label, items, marker] of sections) {
		lines.push(line(heading(`${label} · ${items.length}`)));
		const entries = wrap(
			items.length > 0 ? items.join(", ") : "none detected",
			Math.max(1, contentWidth - 4),
		);
		for (const [index, entry] of entries.entries()) {
			const prefix = index === 0 ? `  ${marker} ` : "    ";
			lines.push(line(`${index === 0 ? accent(prefix) : dim(prefix)}${muted(entry)}`));
		}
		lines.push(line());
	}

	lines.push(line(dim("Press Esc, Enter, or q to close")));
	lines.push(border(`╰${"─".repeat(panelWidth - 2)}╯`));
	return lines;
}

export default function (pi: ExtensionAPI) {
	pi.on("session_start", (_event, ctx) => {
		if (ctx.mode !== "tui") return;

		ctx.ui.setHeader((_tui, theme) => ({
			render: (width: number) =>
				renderHeader(
					theme,
					width,
					basename(ctx.cwd) || "workspace",
					ctx.model ? `${ctx.model.provider}/${ctx.model.id}` : "model pending",
				),
			invalidate() {},
		}));
	});

	pi.registerCommand("resources", {
		description: "Show loaded context, skills, and extensions",
		handler: async (_args, ctx) => {
			if (ctx.mode !== "tui") return;
			const resources = await collectResources(pi, ctx);

			await ctx.ui.custom<void>(
				(tui, theme, _keybindings, done) => ({
					render: (width: number) => renderResources(resources, theme, width),
					handleInput: (data: string) => {
						if (matchesKey(data, Key.escape) || matchesKey(data, Key.enter) || data === "q") {
							done();
						}
						tui.requestRender();
					},
					invalidate() {},
				}),
				{
					overlay: true,
					overlayOptions: {
						anchor: "center",
						width: "70%",
						minWidth: 46,
						maxHeight: "80%",
						margin: 2,
					},
				},
			);
		},
	});
}
