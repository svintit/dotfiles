/**
 * PR/Issue tracker - detects GitHub PR or issue URLs in the first user message
 * and prefixes the session name with pr-<number> or issue-<number>.
 *
 * Immediately fetches the PR/issue title from GitHub via gh CLI so the
 * session name is "pr-<number> <title>" right away. The retitle extension
 * can later refine the description while keeping the prefix.
 *
 * Detected URL patterns:
 *   - https://github.com/<org>/<repo>/pull/<number>
 *   - https://github.com/<org>/<repo>/issues/<number>
 *   - https://app.graphite.com/github/pr/<org>/<repo>/pr/<number>
 */

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const PR_ISSUE_PREFIX_TYPE = "pr-issue-prefix";

// Match PR and issue URLs
const GITHUB_PR_RE = /https?:\/\/github\.com\/([\w.-]+)\/([\w.-]+)\/pull\/(\d+)/i;
const GITHUB_ISSUE_RE = /https?:\/\/github\.com\/([\w.-]+)\/([\w.-]+)\/issues\/(\d+)/i;
const GRAPHITE_PR_RE = /https?:\/\/app\.graphite\.com\/github\/pr\/([\w.-]+)\/([\w.-]+)\/pr\/(\d+)/i;

function extractText(content: unknown): string {
	if (typeof content === "string") return content;
	if (!Array.isArray(content)) return "";
	return (content as Array<{ type?: string; text?: string }>)
		.filter((block) => block.type === "text" && typeof block.text === "string")
		.map((block) => block.text ?? "")
		.join("\n");
}

type DetectedPrefix = {
	prefix: string;
	repo?: string;
	number: string;
	isIssue: boolean;
};

function detectPrIssuePrefix(text: string): DetectedPrefix | null {
	// Check PR patterns first (Graphite before GitHub to avoid partial matches)
	const graphiteMatch = text.match(GRAPHITE_PR_RE);
	if (graphiteMatch) {
		return {
			prefix: `pr-${graphiteMatch[3]}`,
			repo: `${graphiteMatch[1]}/${graphiteMatch[2]}`,
			number: graphiteMatch[3],
			isIssue: false,
		};
	}

	const githubPrMatch = text.match(GITHUB_PR_RE);
	if (githubPrMatch) {
		return {
			prefix: `pr-${githubPrMatch[3]}`,
			repo: `${githubPrMatch[1]}/${githubPrMatch[2]}`,
			number: githubPrMatch[3],
			isIssue: false,
		};
	}

	const githubIssueMatch = text.match(GITHUB_ISSUE_RE);
	if (githubIssueMatch) {
		return {
			prefix: `issue-${githubIssueMatch[3]}`,
			repo: `${githubIssueMatch[1]}/${githubIssueMatch[2]}`,
			number: githubIssueMatch[3],
			isIssue: true,
		};
	}

	return null;
}

async function fetchTitle(
	pi: ExtensionAPI,
	repo: string,
	number: string,
	isIssue: boolean,
): Promise<string | null> {
	try {
		const result = await pi.exec(
			"gh",
			[isIssue ? "issue" : "pr", "view", number, "--repo", repo, "--json", "title", "-q", ".title"],
			{ timeout: 5000 },
		);
		if (result.code !== 0 || !result.stdout.trim()) return null;
		return result.stdout.trim();
	} catch {
		return null;
	}
}

function hasUserMessage(ctx: ExtensionContext): boolean {
	return ctx.sessionManager.getBranch().some(
		(entry) => entry.type === "message" && (entry as any).message?.role === "user",
	);
}

function findStoredPrefix(ctx: ExtensionContext): string | null {
	let latest: string | null = null;
	for (const entry of ctx.sessionManager.getBranch()) {
		if (entry.type !== "custom" || (entry as any).customType !== PR_ISSUE_PREFIX_TYPE) continue;
		const prefix = (entry as any)?.data?.prefix;
		if (typeof prefix === "string" && prefix.trim()) latest = prefix.trim();
	}
	return latest;
}

export default function (pi: ExtensionAPI) {
	pi.on("input", async (event, ctx) => {
		if (event.source === "extension") return { action: "continue" };

		const isFirstMessage = !hasUserMessage(ctx);
		if (!isFirstMessage) return { action: "continue" };

		const detected = detectPrIssuePrefix(event.text);
		if (!detected) return { action: "continue" };

		const { prefix, repo, number, isIssue } = detected;

		// Store the prefix as a custom entry so retitle can retrieve it
		pi.appendEntry(PR_ISSUE_PREFIX_TYPE, { prefix });

		// Set the session name immediately so the sidebar shows it right away
		pi.setSessionName(prefix);

		// Fetch the PR/issue title from GitHub and append it to the name
		if (repo) {
			const title = await fetchTitle(pi, repo, number, isIssue);
			if (title) {
				// Truncate title to keep the name reasonable
				const shortTitle = title.length > 60 ? title.slice(0, 57).trim() + "..." : title;
				const fullName = `${prefix} ${shortTitle}`;
				pi.setSessionName(fullName);
				ctx.ui.notify(`Tracked ${fullName}`, "info");
			} else {
				ctx.ui.notify(`Tracked ${prefix}`, "info");
			}
		} else {
			ctx.ui.notify(`Tracked ${prefix}`, "info");
		}

		return { action: "continue" };
	});

	// On session start/resume, restore the prefix if the name was lost
	pi.on("session_start", async (_event, ctx) => {
		const storedPrefix = findStoredPrefix(ctx);
		if (storedPrefix) {
			const currentName = pi.getSessionName();
			if (!currentName) {
				pi.setSessionName(storedPrefix);
			}
		}
	});
}
