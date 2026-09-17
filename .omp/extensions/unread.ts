import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

export default function (pi: ExtensionAPI) {
	pi.registerCommand("unread", {
		description: "Mark this conversation unread in the Pi sidebar",
		handler: async (_args, ctx) => {
			const pane = process.env.TMUX_PANE;
			if (!process.env.TMUX || !pane) {
				ctx.ui.notify("This Pi session is not running in tmux.", "warning");
				return;
			}

			const marker = `unread-${Date.now().toString(36)}-${process.pid}-${Math.random().toString(36).slice(2)}`;
			try {
				const result = await pi.exec(
					"tmux",
					["set-option", "-p", "-t", pane, "@pi_sidebar_unread", marker],
					{ timeout: 2000 },
				);
				if (result.code !== 0) {
					ctx.ui.notify("Could not mark this conversation unread.", "error");
					return;
				}
				ctx.ui.notify("Marked this conversation unread in the Pi sidebar.", "success");
			} catch {
				ctx.ui.notify("Could not mark this conversation unread.", "error");
			}
		},
	});
}
