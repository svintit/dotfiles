import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

type UnknownRecord = Record<string, unknown>;

function isRecord(value: unknown): value is UnknownRecord {
	return typeof value === "object" && value !== null;
}

function isAssistantMessage(value: unknown): value is { role: "assistant"; content: unknown[] } {
	if (!isRecord(value)) return false;
	if (value.role !== "assistant") return false;
	return Array.isArray(value.content);
}

function isTextContent(value: unknown): value is { type: "text"; text: string } {
	if (!isRecord(value)) return false;
	if (value.type !== "text") return false;
	return typeof value.text === "string";
}

function stripClipboardPathPreamble(text: string): string {
	const lines = text.split(/\r?\n/);
	if (lines.length === 0) return text;

	const first = lines[0]?.trim() ?? "";
	const isClipboardImagePath = /^@?\/var\/folders\/.+\/pi-clipboard-[a-f0-9-]+\.(png|jpe?g|gif|webp)$/i.test(first);
	if (!isClipboardImagePath) return text;

	return lines.slice(1).join("\n").replace(/^\s+/, "");
}

function sanitizeAssistantMessage(message: { content: unknown[] }): boolean {
	for (const block of message.content) {
		if (!isTextContent(block)) continue;

		const cleaned = stripClipboardPathPreamble(block.text);
		if (cleaned === block.text) return false;

		block.text = cleaned;
		return true;
	}

	return false;
}

export default function (pi: ExtensionAPI) {
	let showedNotice = false;

	pi.on("message_end", async (event, ctx) => {
		if (!isAssistantMessage(event.message)) return;

		const changed = sanitizeAssistantMessage(event.message);
		if (!changed || showedNotice) return;

		showedNotice = true;
		ctx.ui.notify("Sanitized clipboard image path preamble. /copy now copies clean text.", "info");
	});

}
