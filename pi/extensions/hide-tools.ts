import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import {
	createBashTool,
	createEditTool,
	createFindTool,
	createGrepTool,
	createLsTool,
	createReadTool,
	createWriteTool,
} from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";

/**
 * Clean OpenCode-style tool rendering for Pi.
 * Suppresses verbose tool call boxes and execution output when collapsed,
 * keeping the conversation stream focused on streaming Markdown prose.
 */
export default function (pi: ExtensionAPI) {
	const toolFactories = {
		read: createReadTool,
		bash: createBashTool,
		edit: createEditTool,
		write: createWriteTool,
		grep: createGrepTool,
		find: createFindTool,
		ls: createLsTool,
	};

	for (const [name, factory] of Object.entries(toolFactories)) {
		const original = factory(process.cwd());

		pi.registerTool({
			name,
			label: name,
			description: original.description,
			parameters: original.parameters,
			renderShell: "self",

			async execute(toolCallId, params, signal, onUpdate, ctx) {
				const tool = factory(ctx.cwd);
				return tool.execute(toolCallId, params as any, signal, onUpdate);
			},

			renderCall(_args, _theme, _ctx) {
				return new Text("", 0, 0);
			},

			renderResult(_result, _options, _theme, _ctx) {
				return new Text("", 0, 0);
			},
		});
	}
}
