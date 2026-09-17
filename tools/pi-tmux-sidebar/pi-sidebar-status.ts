import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// Pi sidebar status bridge.
//
// Writes the agent's current status to the tmux pane option @pi_agent_status
// so the pi-tmux-sidebar can show per-session status icons
// (working / asking / done / stopped). No session-name logic here - the
// sidebar detects sessions and labels via Pi's native pane title.
//
// Requires: running inside tmux (TMUX_PANE is set).

type AgentStatus = "working" | "completed" | "stopped" | "asking";

let isAsking = false;

async function setStatus(pi: ExtensionAPI, status: AgentStatus): Promise<void> {
	if (!process.env.TMUX || !process.env.TMUX_PANE) return;
	const value = isAsking ? "asking" : status;
	const args = ["set-option", "-p", "-t", process.env.TMUX_PANE, "@pi_agent_status", value];
	await pi.exec("tmux", args, { timeout: 2000 }).catch(() => {});
}

function finalAgentStatus(event: { messages?: unknown[] }): AgentStatus {
	const assistant = [...(event.messages ?? [])]
		.reverse()
		.find((message) => (message as { role?: string }).role === "assistant") as
		| { stopReason?: string }
		| undefined;
	return assistant?.stopReason === "aborted" || assistant?.stopReason === "error" ? "stopped" : "completed";
}

export default function (pi: ExtensionAPI) {
	pi.on("session_start", async () => {
		isAsking = false;
		await setStatus(pi, "completed");
	});

	pi.on("agent_start", async () => {
		await setStatus(pi, "working");
	});

	pi.on("agent_end", async (event) => {
		await setStatus(pi, finalAgentStatus(event));
	});

	pi.on("tool_call", async (event) => {
		if (event.toolName !== "ask") return;
		isAsking = true;
		await setStatus(pi, "asking");
	});

	pi.on("tool_result", async (event) => {
		if (event.toolName !== "ask") return;
		isAsking = false;
		await setStatus(pi, "working");
	});

	pi.on("session_shutdown", async () => {
		if (!process.env.TMUX || !process.env.TMUX_PANE) return;
		await pi
			.exec("tmux", ["set-option", "-pu", "-t", process.env.TMUX_PANE, "@pi_agent_status"], { timeout: 2000 })
			.catch(() => {});
	});
}
