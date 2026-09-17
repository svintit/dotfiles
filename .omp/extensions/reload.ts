import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

export default function (pi: ExtensionAPI) {
	pi.registerCommand("reload", {
		description: "Reload extensions, config, and runtime state without restarting the session",
		handler: async (_args, ctx) => {
			await ctx.reload();
		},
	});
}
