import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";

function getDisplayedThinkingLevel(pi: ExtensionAPI): string {
	return pi.getThinkingLevel();
}

function renderThinkingStatus(pi: ExtensionAPI, ctx: ExtensionContext): void {
	if (!ctx.hasUI) return;
	const level = getDisplayedThinkingLevel(pi);
	ctx.ui.setStatus("thinking", ctx.ui.theme.fg("dim", `thinking:${level}`));
}

export default function (pi: ExtensionAPI) {
	let latestCtx: ExtensionContext | null = null;
	let pollTimer: ReturnType<typeof setInterval> | null = null;
	let lastRenderedLevel: string | null = null;

	const refresh = (_event: unknown, ctx: ExtensionContext) => {
		latestCtx = ctx;
		const level = getDisplayedThinkingLevel(pi);
		if (level === lastRenderedLevel) return;
		lastRenderedLevel = level;
		renderThinkingStatus(pi, ctx);
	};

	const startPolling = (ctx: ExtensionContext) => {
		latestCtx = ctx;
		if (pollTimer) clearInterval(pollTimer);
		pollTimer = setInterval(() => {
			if (!latestCtx || !latestCtx.hasUI) return;
			const level = getDisplayedThinkingLevel(pi);
			if (level === lastRenderedLevel) return;
			lastRenderedLevel = level;
			renderThinkingStatus(pi, latestCtx);
		}, 300);
	};

	const stopPolling = () => {
		if (!pollTimer) return;
		clearInterval(pollTimer);
		pollTimer = null;
	};

	pi.on("session_start", (_event, ctx) => {
		lastRenderedLevel = null;
		startPolling(ctx);
		refresh(_event, ctx);
	});
	pi.on("session_switch", (_event, ctx) => {
		lastRenderedLevel = null;
		startPolling(ctx);
		refresh(_event, ctx);
	});
	pi.on("session_fork", refresh);
	pi.on("session_tree", refresh);
	pi.on("model_select", refresh);
	pi.on("turn_start", refresh);
	pi.on("turn_end", refresh);

	pi.on("session_shutdown", async (_event, ctx) => {
		stopPolling();
		lastRenderedLevel = null;
		if (ctx.hasUI) ctx.ui.setStatus("thinking", undefined);
	});

	pi.registerCommand("thinking-status-refresh", {
		description: "Refresh thinking level indicator in footer",
		handler: async (_args, ctx) => {
			lastRenderedLevel = null;
			refresh(null, ctx);
			ctx.ui.notify("Thinking status refreshed", "info");
		},
	});
}
