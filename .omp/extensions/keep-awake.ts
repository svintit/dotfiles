import { spawn } from "node:child_process";
import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import type { AutocompleteItem } from "@mariozechner/pi-tui";

const STATUS_KEY = "keep-awake";

type AwakeMode = "active" | "session";

function buildPlainStatus(
	enabled: boolean,
	available: boolean,
	running: boolean,
	mode: AwakeMode,
	activeAgentRuns: number,
): string {
	if (!available) {
		return "keep-awake unavailable (macOS caffeinate command not found)";
	}

	if (!enabled) {
		return "keep-awake off";
	}

	if (mode === "session") {
		if (running) {
			return "keep-awake on (entire session)";
		}
		return "keep-awake starting...";
	}

	if (activeAgentRuns > 0) {
		if (running) {
			return "keep-awake on (agent active)";
		}
		return "keep-awake starting (agent active)...";
	}

	return "keep-awake off (idle)";
}

export default function keepAwakeExtension(pi: ExtensionAPI) {
	let enabled = process.platform === "darwin";
	let mode: AwakeMode = "active";
	let activeAgentRuns = 0;
	let caffeinateAvailable = process.platform === "darwin";
	let caffeinateProcess: ReturnType<typeof spawn> | undefined;
	let lastContext: ExtensionContext | undefined;
	let didWarnUnsupportedPlatform = false;

	const isRunning = (): boolean => caffeinateProcess !== undefined;

	const shouldHoldAwake = (): boolean =>
		enabled && caffeinateAvailable && (mode === "session" || activeAgentRuns > 0);

	const renderStatus = (ctx: ExtensionContext) => {
		if (!ctx.hasUI) {
			return;
		}

		const theme = ctx.ui.theme;
		if (!caffeinateAvailable) {
			ctx.ui.setStatus(
				STATUS_KEY,
				`${theme.fg("error", "awake")} ${theme.fg("dim", "unavailable")}`,
			);
			return;
		}

		if (!enabled) {
			ctx.ui.setStatus(
				STATUS_KEY,
				`${theme.fg("dim", "awake")} ${theme.fg("muted", "off")}`,
			);
			return;
		}

		if (mode === "session") {
			if (isRunning()) {
				ctx.ui.setStatus(
					STATUS_KEY,
					`${theme.fg("accent", "awake")} ${theme.fg("success", "on (session)")}`,
				);
				return;
			}

			ctx.ui.setStatus(
				STATUS_KEY,
				`${theme.fg("accent", "awake")} ${theme.fg("warning", "starting...")}`,
			);
			return;
		}

		if (activeAgentRuns > 0) {
			if (isRunning()) {
				ctx.ui.setStatus(
					STATUS_KEY,
					`${theme.fg("accent", "awake")} ${theme.fg("success", "on (active)")}`,
				);
				return;
			}

			ctx.ui.setStatus(
				STATUS_KEY,
				`${theme.fg("accent", "awake")} ${theme.fg("warning", "starting (active)...")}`,
			);
			return;
		}

		if (isRunning()) {
			ctx.ui.setStatus(
				STATUS_KEY,
				`${theme.fg("dim", "awake")} ${theme.fg("warning", "off (stopping...)")}`,
			);
			return;
		}

		ctx.ui.setStatus(
			STATUS_KEY,
			`${theme.fg("dim", "awake")} ${theme.fg("muted", "off (idle)")}`,
		);
	};

	const stopCaffeinate = () => {
		const processRef = caffeinateProcess;
		if (!processRef) {
			return;
		}

		caffeinateProcess = undefined;
		try {
			processRef.kill("SIGTERM");
		} catch {
			// no-op
		}
	};

	const startCaffeinate = (ctx?: ExtensionContext) => {
		if (!shouldHoldAwake() || isRunning()) {
			return;
		}

		const child = spawn("caffeinate", ["-i"], { stdio: "ignore" });
		caffeinateProcess = child;

		child.once("error", (error) => {
			if (caffeinateProcess === child) {
				caffeinateProcess = undefined;
			}

			caffeinateAvailable = false;
			const message = `keep-awake failed to start caffeinate: ${error.message}`;
			if (ctx?.hasUI) {
				ctx.ui.notify(message, "error");
			} else {
				console.error(message);
			}
		});

		child.once("exit", () => {
			if (caffeinateProcess === child) {
				caffeinateProcess = undefined;
				if (shouldHoldAwake()) {
					startCaffeinate(lastContext);
				}
			}

			if (lastContext) {
				renderStatus(lastContext);
			}
		});
	};

	const reconcileKeepAwake = (ctx?: ExtensionContext) => {
		if (ctx) {
			lastContext = ctx;
		}

		if (shouldHoldAwake()) {
			startCaffeinate(lastContext);
		} else {
			stopCaffeinate();
		}

		if (lastContext) {
			renderStatus(lastContext);
		}
	};

	const notifyStatus = (ctx: ExtensionContext, level: "info" | "warning" = "info") => {
		if (!ctx.hasUI) {
			return;
		}

		ctx.ui.notify(
			buildPlainStatus(enabled, caffeinateAvailable, isRunning(), mode, activeAgentRuns),
			level,
		);
	};

	const awakeCompletions: AutocompleteItem[] = [
		{ value: "status", label: "status" },
		{ value: "on", label: "on" },
		{ value: "off", label: "off" },
		{ value: "active", label: "active" },
		{ value: "session", label: "session" },
		{ value: "help", label: "help" },
	];

	pi.registerCommand("awake", {
		description: "Manage macOS keep-awake behavior (active-only or session-wide)",
		getArgumentCompletions: (prefix) => {
			const normalized = prefix.trim().toLowerCase();
			const matches = awakeCompletions.filter((item) => item.value.startsWith(normalized));
			return matches.length > 0 ? matches : null;
		},
		handler: async (args, ctx) => {
			lastContext = ctx;
			const input = args?.trim().toLowerCase() ?? "";

			if (!input || input === "status") {
				notifyStatus(ctx);
				renderStatus(ctx);
				return;
			}

			if (input === "help") {
				ctx.ui.notify("Usage: /awake [status|on|off|active|session|help]", "info");
				return;
			}

			if (input === "on") {
				enabled = true;
				reconcileKeepAwake(ctx);
				notifyStatus(ctx);
				return;
			}

			if (input === "off") {
				enabled = false;
				reconcileKeepAwake(ctx);
				notifyStatus(ctx, "warning");
				return;
			}

			if (input === "active") {
				enabled = true;
				mode = "active";
				reconcileKeepAwake(ctx);
				notifyStatus(ctx);
				return;
			}

			if (input === "session") {
				enabled = true;
				mode = "session";
				reconcileKeepAwake(ctx);
				notifyStatus(ctx);
				return;
			}

			ctx.ui.notify(
				`Unknown argument "${input}". Usage: /awake [status|on|off|active|session|help]`,
				"warning",
			);
		},
	});

	pi.on("session_start", async (_event, ctx) => {
		lastContext = ctx;
		activeAgentRuns = 0;

		if (process.platform !== "darwin" && !didWarnUnsupportedPlatform) {
			didWarnUnsupportedPlatform = true;
			enabled = false;
			if (ctx.hasUI) {
				ctx.ui.notify("keep-awake is only supported on macOS.", "warning");
			}
		}

		reconcileKeepAwake(ctx);
	});

	pi.on("session_switch", async (_event, ctx) => {
		activeAgentRuns = 0;
		reconcileKeepAwake(ctx);
	});

	pi.on("session_fork", async (_event, ctx) => {
		activeAgentRuns = 0;
		reconcileKeepAwake(ctx);
	});

	pi.on("session_tree", async (_event, ctx) => {
		activeAgentRuns = 0;
		reconcileKeepAwake(ctx);
	});

	pi.on("agent_start", async (_event, ctx) => {
		lastContext = ctx;
		activeAgentRuns += 1;
		reconcileKeepAwake(ctx);
	});

	pi.on("agent_end", async (_event, ctx) => {
		lastContext = ctx;
		activeAgentRuns = Math.max(0, activeAgentRuns - 1);
		reconcileKeepAwake(ctx);
	});

	pi.on("session_shutdown", async (_event, ctx) => {
		lastContext = ctx;
		activeAgentRuns = 0;
		stopCaffeinate();
		if (ctx.hasUI) {
			ctx.ui.setStatus(STATUS_KEY, undefined);
		}
	});
}
