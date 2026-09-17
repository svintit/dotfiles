import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

export default function (pi: ExtensionAPI) {
	pi.registerCommand("mute", {
		description: "Toggle notification sound for the Pi sidebar",
		handler: async (_args, ctx) => {
			if (!process.env.TMUX) {
				ctx.ui.notify("This Pi session is not running in tmux.", "warning");
				return;
			}

			try {
				const result = await pi.exec(
					"tmux",
					["show-options", "-gqv", "@pi_sidebar_muted"],
					{ timeout: 2000 },
				);
				const isMuted = result.stdout.trim() === "1";
				const next = isMuted ? "0" : "1";

				const setResult = await pi.exec(
					"tmux",
					["set-option", "-g", "@pi_sidebar_muted", next],
					{ timeout: 2000 },
				);
				if (setResult.code !== 0) {
					ctx.ui.notify("Could not toggle sidebar mute.", "error");
					return;
				}

				ctx.ui.notify(
					isMuted ? "Sidebar sound unmuted." : "Sidebar sound muted.",
					"info",
				);
			} catch {
				ctx.ui.notify("Could not toggle sidebar mute.", "error");
			}
		},
	});
}
