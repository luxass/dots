/**
 * Trusted GitHub repository extension.
 *
 * Automatically grants Pi project trust for git checkouts whose `origin`
 * remotes all point to GitHub repositories owned by trusted organizations or
 * users. Everything else remains undecided so Pi still asks before loading
 * project-local resources.
 */

import type { ExtensionAPI, ProjectTrustEventResult } from "@earendil-works/pi-coding-agent";

const TRUSTED_GITHUB_OWNERS = new Set(["kvalitetsit", "luxass"]);
const GIT_TIMEOUT_MS = 5_000;

type GitHubRepo = {
	owner: string;
	repo: string;
};

function trimGitSuffix(repo: string): string {
	return repo.replace(/\.git$/i, "");
}

function parseGitHubRemoteUrl(remoteUrl: string): GitHubRepo | null {
	const value = remoteUrl.trim();
	if (!value) {
		return null;
	}

	const scpMatch = value.match(/^(?:[^@/:\s]+@)?github\.com:([^/:\s]+)\/([^/\s]+?)(?:\.git)?\/?$/i);
	if (scpMatch) {
		return {
			owner: scpMatch[1],
			repo: trimGitSuffix(scpMatch[2]),
		};
	}

	try {
		const parsed = new URL(value);
		if (parsed.hostname.toLowerCase() !== "github.com") {
			return null;
		}

		const parts = parsed.pathname
			.replace(/^\/+|\/+$/g, "")
			.split("/")
			.filter(Boolean);

		if (parts.length !== 2) {
			return null;
		}

		return {
			owner: decodeURIComponent(parts[0]),
			repo: trimGitSuffix(decodeURIComponent(parts[1])),
		};
	} catch {
		return null;
	}
}

function isTrustedGitHubRemote(remoteUrl: string): boolean {
	const repo = parseGitHubRemoteUrl(remoteUrl);
	return !!repo && TRUSTED_GITHUB_OWNERS.has(repo.owner.toLowerCase());
}

async function getOriginRemoteUrls(pi: ExtensionAPI, cwd: string): Promise<string[]> {
	try {
		const result = await pi.exec("git", ["remote", "get-url", "--all", "origin"], {
			cwd,
			timeout: GIT_TIMEOUT_MS,
		});

		if (result.code !== 0) {
			return [];
		}

		return result.stdout
			.split(/\r?\n/)
			.map((line) => line.trim())
			.filter(Boolean);
	} catch {
		return [];
	}
}

export default function trustGitHubRepos(pi: ExtensionAPI): void {
	pi.on("project_trust", async (event): Promise<ProjectTrustEventResult> => {
		const originUrls = await getOriginRemoteUrls(pi, event.cwd);
		if (originUrls.length > 0 && originUrls.every(isTrustedGitHubRemote)) {
			return { trusted: "yes", remember: true };
		}

		return { trusted: "undecided" };
	});
}
