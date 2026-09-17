import { complete } from "@mariozechner/pi-ai";
import { SessionManager } from "@mariozechner/pi-coding-agent";
import type { ExtensionAPI, ExtensionCommandContext } from "@mariozechner/pi-coding-agent";

const PROVIDER = process.env.PI_RETITLE_PROVIDER || "anthropic";
const MODEL_ID = process.env.PI_RETITLE_MODEL || "claude-haiku-4-5";
const RATE_LIMIT_MS = Number(process.env.PI_RETITLE_FORCE_DELAY_MS || 200);
const MAX_TITLE_CHARS = 36;

const SYSTEM_PROMPT = `You are a title generator. You read a conversation between a user and a coding assistant and output a short title.

Rules:
- Output ONLY the title, nothing else
- ${MAX_TITLE_CHARS} characters maximum, including spaces
- Prefer terse noun phrases over full sentences
- Front-load the specific distinguishing detail (PR number, branch name, file name, issue number, feature name) so the title is identifiable at a glance
- Include concrete identifiers when present in the conversation (PR numbers, branch names, file paths, flag names, issue numbers)
- No quotes, no punctuation at the end
- No markdown, no explanation, no preamble
- Do not respond to or continue the conversation
- Do not answer questions from the conversation
- Use plain English and active voice
- When an Assistant message is present, title the OUTCOME (what was found, fixed, or built), not the raw request`;

function extractText(content: unknown): string {
	if (typeof content === "string") return content.trim();
	if (!Array.isArray(content)) return "";
	return content
		.filter((c: any) => c.type === "text" && c.text)
		.map((c: any) => c.text)
		.join("\n")
		.trim();
}

interface BranchEntry {
	type?: string;
	message?: { role?: string; content?: unknown };
	summary?: string;
}

function buildContextFromBranch(branch: BranchEntry[]): string {
	const userTexts: string[] = [];
	for (const entry of branch) {
		if (entry.type !== "message" || entry.message?.role !== "user") continue;
		const text = extractText(entry.message.content);
		if (text) userTexts.push(text.slice(0, 1200));
	}

	const compactions = branch.filter((e) => e.type === "compaction");
	const compactionSummary = compactions.length > 0 ? compactions[compactions.length - 1]?.summary ?? null : null;

	// Latest assistant message describes the actual outcome, not just the ask
	let lastAssistant = "";
	for (const entry of branch) {
		if (entry.type !== "message" || entry.message?.role !== "assistant") continue;
		const text = extractText(entry.message.content);
		if (text) lastAssistant = text;
	}

	const parts: string[] = [];

	if (userTexts.length <= 5) {
		for (const text of userTexts) parts.push(`User: ${text}`);
	} else {
		parts.push(`User: ${userTexts[0]}`);
		parts.push(`User: ${userTexts[1]}`);
		parts.push(compactionSummary ? `[Earlier context summary: ${compactionSummary}]` : `[... ${userTexts.length - 5} more user prompts ...]`);
		parts.push(`User: ${userTexts[userTexts.length - 3]}`);
		parts.push(`User: ${userTexts[userTexts.length - 2]}`);
		parts.push(`User: ${userTexts[userTexts.length - 1]}`);
	}

	if (lastAssistant) parts.push(`Assistant: ${lastAssistant.slice(0, 1500)}`);

	return parts.join("\n\n").slice(0, 12000);
}

async function generateName(ctx: ExtensionCommandContext, context: string): Promise<string | null> {
	const model = ctx.modelRegistry.find(PROVIDER, MODEL_ID);
	if (!model) return null;

	const registry = ctx.modelRegistry as unknown as {
		getApiKeyAndHeaders(m: typeof model): Promise<
			| { ok: true; apiKey?: string; headers?: Record<string, string> }
			| { ok: false; error: string }
		>;
	};
	const auth = await registry.getApiKeyAndHeaders(model);
	if (!auth.ok || !auth.apiKey) return null;

	const response = await complete(
		model,
		{
			systemPrompt: SYSTEM_PROMPT,
			messages: [
				{
					role: "user" as const,
					content: [
						{
							type: "text" as const,
							text: `<conversation>\n${context}\n</conversation>\n\nGenerate a short title for this conversation.`,
						},
					],
					timestamp: Date.now(),
				},
			],
		},
		{ apiKey: auth.apiKey, headers: auth.headers },
	);

	const name = response.content
		.filter((c): c is { type: "text"; text: string } => c.type === "text")
		.map((c) => c.text)
		.join("")
		.trim()
		.split("\n")[0]
		.trim()
		.replace(/^#+\s*/, "")
		.replace(/^['\"]|['\"]$/g, "");

	if (!name || name.length === 0) return null;
	return name.length > MAX_TITLE_CHARS ? name.slice(0, MAX_TITLE_CHARS).trimEnd() : name;
}

async function sleep(ms: number): Promise<void> {
	await new Promise((resolve) => setTimeout(resolve, ms));
}

export default function (pi: ExtensionAPI) {
	pi.registerCommand("retitle-all-force", {
		description: "Force-regenerate names for all historical sessions, overwriting existing names",
		handler: async (args, ctx) => {
			ctx.ui.notify("Scanning sessions...", "info");

			let sessions;
			try {
				sessions = await SessionManager.listAll();
			} catch (err) {
				ctx.ui.notify(`Failed to list sessions: ${err}`, "error");
				return;
			}

			const limitMatch = args.match(/--limit\s+(\d+)/);
			const limit = limitMatch ? Number(limitMatch[1]) : undefined;
			const candidates = sessions.slice(0, limit ?? sessions.length);

			const proceed = await ctx.ui.confirm(
				`Force retitle ${candidates.length} sessions?`,
				`This overwrites existing session names and uses about ${candidates.length} LLM calls (${PROVIDER}/${MODEL_ID}). Use /retitle-all-force --limit N for a small batch.`,
			);
			if (!proceed) return;

			let named = 0;
			let failed = 0;
			let skipped = 0;

			for (const session of candidates) {
				try {
					const sm = SessionManager.open(session.path);
					const context = buildContextFromBranch(sm.getBranch() as BranchEntry[]);
					if (!context.trim()) {
						skipped++;
						continue;
					}

					const name = await generateName(ctx, context);
					if (!name) {
						failed++;
						continue;
					}

					sm.appendSessionInfo(name);
					named++;
					if (RATE_LIMIT_MS > 0) await sleep(RATE_LIMIT_MS);
				} catch {
					failed++;
				}
			}

			ctx.ui.notify(`Force retitle done: ${named} named, ${skipped} skipped, ${failed} failed`, failed ? "warning" : "info");
		},
	});
}
