// OMP-specific copy of tmux-session-name-sync.ts
// Two fixes vs the pi original:
// 1. Uses require("child_process").execSync instead of pi.exec - pi.exec
//    (ptree.exec) returns code 0 for `tmux set-option -p` but the option
//    doesn't stick in omp's Bun runtime.
// 2. Always writes @pi_agent_status (the pi original suppresses it when
//    paneName is "-", which blanks the sidebar status icon in omp where
//    getSessionName() returns undefined and no conversation-title entries exist).
//    When no slug is derived, @pi_session_name is left unset so the sidebar
//    falls back to the pane title (omp sets "π: <name>") for the label.
import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";

const GENERIC_NAMES = new Set(["", "src", "main", "root", "fish", "bash", "zsh", "sh", "node", "pi", "omp", "bun"]);
const CONVERSATION_TITLE_CUSTOM_TYPE = "conversation-title";
const SLACK_URL_RE = /https:\/\/[\w.-]*slack\.com\/archives\/[A-Z0-9]+\/p\d+(?:\?[^\s<>)"']*)?/i;

function stripEmoji(text: string): string {
	return text.replace(/[\p{Emoji_Presentation}\p{Extended_Pictographic}]/gu, "");
}

function limitWords(text: string, maxWords: number): string {
	const words = text.trim().split(/\s+/);
	return words.length <= maxWords ? text.trim() : words.slice(0, maxWords).join(" ");
}

const TRAILING_STOPWORDS = new Set([
	"and", "or", "but", "for", "to", "in", "on", "of", "at", "by", "with", "from",
	"into", "onto", "the", "a", "an", "is", "are", "was", "were", "be", "as",
]);

function stripTrailingStopwords(words: string[]): string[] {
	let end = words.length;
	while (end > 0 && TRAILING_STOPWORDS.has(words[end - 1].toLowerCase())) end--;
	return end > 0 ? words.slice(0, end) : words;
}

function slugify(name: string | null | undefined): string {
	const stripped = stripEmoji(name ?? "").trim()
		.replace(/^π\s*[-:]\s*/i, "")
		.replace(/["'`]/g, "");
	const rawWords = stripped.split(/\s+/).filter(Boolean);
	const limited = limitWords(rawWords.join(" "), 7);
	const trimmed = stripTrailingStopwords(limited.split(/\s+/)).join(" ");
	const cleaned = trimmed
		.replace(/[^\p{L}\p{N}\s]+/gu, " ")
		.replace(/\s+/g, " ")
		.trim()
		.slice(0, 80);

	return GENERIC_NAMES.has(cleaned.toLowerCase()) ? "" : cleaned;
}

type AgentStatus = "working" | "completed" | "stopped" | "asking";
const STATUS_EXTENSION_VERSION = "2026-09-08.1";
export function agentEndContinues(event: { willContinue?: boolean; isTerminal?: boolean }): boolean {
	return Boolean(event.willContinue) || event.isTerminal === false;
}

let isAsking = false;
let currentStatus: AgentStatus = "completed";
let activeToolCalls = 0;
let syncToken = 0;
// Auto-retry, compaction, and async delivery can continue after agent_end.
// Keep working until the runtime marks an agent_end as terminal.
let ownsTmuxPane = false;

export function isPrimarySessionFile(sessionFile: string | undefined): boolean {
	if (!sessionFile) return false;
	const normalized = sessionFile.replace(/\\/g, "/");
	const marker = "/agent/sessions/";
	const markerIndex = normalized.indexOf(marker);
	if (markerIndex < 0) return true;
	return normalized.slice(markerIndex + marker.length).split("/").length === 2;
}
let turnActive = false;
let restoreAlternateScreen = false;

function enableTmuxScrollback(): void {
	if (!process.env.TMUX || !process.env.TMUX_PANE) return;
	const pane = process.env.TMUX_PANE;
	try {
		const cp = require("child_process") as { execSync: (cmd: string, opts?: { timeout?: number; encoding?: string }) => string };
		const options = { timeout: 2000, encoding: "utf-8" } as const;
		restoreAlternateScreen = cp.execSync(`tmux show-window-options -v -t ${pane} alternate-screen`, options).trim() === "on";
		cp.execSync(`tmux set-window-option -t ${pane} alternate-screen on`, options);
		const tty = cp.execSync(`tmux display-message -p -t ${pane} '#{pane_tty}'`, options).trim();
		require("fs").writeFileSync(tty, "\x1b[?1049l");
		cp.execSync(`tmux set-window-option -t ${pane} alternate-screen off`, options);
	} catch {}
}

function restoreTmuxAlternateScreen(): void {
	if (!restoreAlternateScreen || !process.env.TMUX || !process.env.TMUX_PANE) return;
	try {
		const cp = require("child_process") as { execSync: (cmd: string, opts?: { timeout?: number; encoding?: string }) => string };
		cp.execSync(`tmux set-window-option -t ${process.env.TMUX_PANE} alternate-screen on`, { timeout: 2000, encoding: "utf-8" });
	} catch {}
	restoreAlternateScreen = false;
}
function setTmuxPaneOption(key: string, value: string | undefined): void {
	if (!process.env.TMUX || !process.env.TMUX_PANE) return;
	const pane = process.env.TMUX_PANE;
	try {
		const cp = require("child_process") as { execSync: (cmd: string, opts?: { timeout?: number; encoding?: string }) => string };
		if (value) {
			const escaped = value.replace(/'/g, "'\\''");
			cp.execSync(`tmux set-option -p -t ${pane} ${key} '${escaped}'`, { timeout: 2000, encoding: "utf-8" });
		} else {
			cp.execSync(`tmux set-option -pu -t ${pane} ${key}`, { timeout: 2000, encoding: "utf-8" });
		}
	} catch {}
}

function extractText(content: unknown): string {
	if (typeof content === "string") return content.trim();
	if (!Array.isArray(content)) return "";
	return (content as Array<{ type?: string; text?: string }>)
		.filter((block) => block.type === "text" && typeof block.text === "string")
		.map((block) => block.text ?? "")
		.join("\n")
		.trim();
}

function findLatestConversationTitle(ctx: ExtensionContext): string | null {
	let latest: string | null = null;
	for (const entry of ctx.sessionManager.getBranch()) {
		if (entry.type !== "custom" || (entry as { customType?: string }).customType !== CONVERSATION_TITLE_CUSTOM_TYPE) continue;
		const name = ((entry as { data?: { name?: unknown } }).data)?.name;
		if (typeof name === "string" && name.trim()) latest = name.trim();
	}
	return latest;
}

function firstUserMessageText(ctx: ExtensionContext): string | null {
	for (const entry of ctx.sessionManager.getBranch()) {
		if (entry.type === "message" && (entry as { message?: { role?: string } }).message?.role === "user") {
			return extractText((entry as { message?: { content?: unknown } }).message?.content);
		}
	}
	return null;
}

function isSlackTrackingSession(ctx: ExtensionContext, _sessionName: string | null | undefined): boolean {
	return SLACK_URL_RE.test(firstUserMessageText(ctx) ?? "");
}

function statusForSidebar(status: AgentStatus): AgentStatus {
	if (isAsking) return "asking";
	if (activeToolCalls > 0) return "working";
	return status;
}

function syncTmuxPaneState(pi: ExtensionAPI, status: AgentStatus, ctx: ExtensionContext): void {
	ownsTmuxPane = isPrimarySessionFile(ctx.sessionManager.getSessionFile());
	if (!ownsTmuxPane) return;
	const sessionName = pi.getSessionName();
	const isSlack = isSlackTrackingSession(ctx, sessionName);
	// Fall back through: conversation title → session name → first user message
	const title = findLatestConversationTitle(ctx) ?? (isSlack ? null : sessionName) ?? firstUserMessageText(ctx);
	const slug = slugify(title);
	const effectiveStatus = statusForSidebar(status);
	const paneName = slug || undefined;
	const paneStatus = isSlack && !paneName ? undefined : effectiveStatus;
	setTmuxPaneOption("@pi_session_name", paneName);
	setTmuxPaneOption("@pi_agent_status", paneStatus);
	setTmuxPaneOption("@pi_status_extension_version", STATUS_EXTENSION_VERSION);
}



function clearTmuxPaneState(): void {
	if (!ownsTmuxPane) return;
	isAsking = false;
	activeToolCalls = 0;
	turnActive = false;
	currentStatus = "completed";
	syncToken += 1;
	setTmuxPaneOption("@pi_session_name", undefined);
	setTmuxPaneOption("@pi_agent_status", undefined);
}

function finalAgentStatus(event: { messages?: unknown[] }): AgentStatus {
	const assistant = [...(event.messages ?? [])]
		.reverse()
		.find((message) => (message as { role?: string }).role === "assistant") as
		| { stopReason?: string }
		| undefined;

	return assistant?.stopReason === "aborted" || assistant?.stopReason === "error" ? "stopped" : "completed";
}

function syncNow(pi: ExtensionAPI, status: AgentStatus, ctx: ExtensionContext): void {
	syncToken += 1;
	try { syncTmuxPaneState(pi, status, ctx); } catch {}
}

function syncWithRetries(pi: ExtensionAPI, status: AgentStatus, ctx: ExtensionContext): void {
	syncToken += 1;
	const token = syncToken;
	// Immediate synchronous write so the status is visible before the next
	// event loop tick. setTimeout(cb, 0) fires on the next tick, leaving a
	// window where a stale "completed" from a prior agent_end can be observed
	// by the sidebar's 1s refresh.
	try { syncTmuxPaneState(pi, status, ctx); } catch {}
	for (const delay of [250, 1000, 2500, 5000]) {
		setTimeout(() => {
			if (token !== syncToken) return;
			try { syncTmuxPaneState(pi, status, ctx); } catch {}
		}, delay);
	}
}

export default function (pi: ExtensionAPI) {
	setTmuxPaneOption("@pi_status_extension_version", STATUS_EXTENSION_VERSION);
	pi.on("session_start", async (_event, ctx) => {
		ownsTmuxPane = isPrimarySessionFile(ctx.sessionManager.getSessionFile());
		isAsking = false;
		activeToolCalls = 0;
		turnActive = false;
		currentStatus = "completed";
		if (ownsTmuxPane) enableTmuxScrollback();
		syncWithRetries(pi, currentStatus, ctx);
	});

	pi.on("agent_start", async (_event, ctx) => {
		turnActive = true;
		currentStatus = "working";
		syncWithRetries(pi, currentStatus, ctx);
	});

	pi.on("agent_end", async (event, ctx) => {
		const typedEvent = event as { willContinue?: boolean; isTerminal?: boolean; messages?: unknown[] };
		const continues = agentEndContinues(typedEvent);
		turnActive = continues;
		currentStatus = continues ? "working" : finalAgentStatus(typedEvent);
		activeToolCalls = 0;
		syncWithRetries(pi, currentStatus, ctx);
	});

	pi.on("tool_call", async (event, ctx) => {
		activeToolCalls += 1;
		if (event.toolName === "ask") {
			isAsking = true;
		}
		syncNow(pi, currentStatus, ctx);
	});

	pi.on("tool_result", async (event, ctx) => {
		if (activeToolCalls > 0) activeToolCalls -= 1;
		if (event.toolName === "ask") {
			isAsking = false;
		}
		syncNow(pi, currentStatus, ctx);
	});

	pi.on("auto_retry_start", async (_event, ctx) => {
		currentStatus = "working";
		syncNow(pi, "working", ctx);
	});

	pi.on("auto_retry_end", async (event, ctx) => {
		const typedEvent = event as { success: boolean };
		if (!typedEvent.success) {
			currentStatus = turnActive ? "working" : "stopped";
			syncNow(pi, currentStatus, ctx);
		} else {
			// A retry can happen mid-turn (retrying the current turn's
			// provider call), in which case the turn is still active and no
			// agent_start will follow - stay "working". Only default to
			// "completed" outside an active turn, pending the next
			// agent_start.
			currentStatus = turnActive ? "working" : "completed";
			syncNow(pi, currentStatus, ctx);
		}
	});

	pi.on("auto_compaction_start", async (_event, ctx) => {
		currentStatus = "working";
		syncNow(pi, "working", ctx);
	});

	pi.on("auto_compaction_end", async (event, ctx) => {
		const typedEvent = event as { aborted: boolean; willRetry: boolean; errorMessage?: string; skipped?: boolean };
		if (typedEvent.willRetry) {
			currentStatus = "working";
			syncNow(pi, "working", ctx);
		} else if (typedEvent.aborted || typedEvent.errorMessage) {
			currentStatus = turnActive ? "working" : "stopped";
			syncNow(pi, currentStatus, ctx);
		} else {
			// Compaction succeeded or was skipped. Mid-turn compaction
			// (between tool-loop steps, e.g. threshold compaction) leaves
			// the turn active with no agent_start to follow - stay
			// "working". Only outside an active turn is "completed" the
			// safe default, pending the next agent_start.
			currentStatus = turnActive ? "working" : "completed";
			syncNow(pi, currentStatus, ctx);
		}
	});

	pi.on("session_info_changed", async (_event, ctx) => {
		syncNow(pi, isAsking ? "asking" : currentStatus, ctx);
	});

	pi.on("session_shutdown", async () => {
		try { restoreTmuxAlternateScreen(); } catch {}
		try { clearTmuxPaneState(); } catch {}
	});
}
