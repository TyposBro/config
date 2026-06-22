/**
 * Quick provider + model + thinking shortcuts for my common agent modes.
 *
 * Commands:
 *   /spark      -> openai-codex/gpt-5.3-codex-spark + medium
 *   /high       -> openai-codex/gpt-5.5 + high
 *   /xhigh      -> openai-codex/gpt-5.5 + xhigh
 *   /reviewer   -> openai-codex/gpt-5.5 + xhigh
 *   /oracle     -> openai-codex/gpt-5.5 + xhigh
 *   /explore    -> google/gemini-3.1-pro-preview + high
 *   /quick_task -> deepseek/deepseek-v4-pro + medium
 */

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import type { Model } from "@earendil-works/pi-ai";

type ThinkingLevel = "off" | "minimal" | "low" | "medium" | "high" | "xhigh";

interface Shortcut {
	provider: string;
	modelId: string;
	thinking: ThinkingLevel;
}

const SHORTCUTS: Record<string, Shortcut> = {
	spark: {
		provider: "openai-codex",
		modelId: "gpt-5.3-codex-spark",
		thinking: "medium",
	},
	high: {
		provider: "openai-codex",
		modelId: "gpt-5.5",
		thinking: "high",
	},
	xhigh: {
		provider: "openai-codex",
		modelId: "gpt-5.5",
		thinking: "xhigh",
	},
	reviewer: {
		provider: "openai-codex",
		modelId: "gpt-5.5",
		thinking: "xhigh",
	},
	oracle: {
		provider: "openai-codex",
		modelId: "gpt-5.5",
		thinking: "xhigh",
	},
	explore: {
		provider: "google",
		modelId: "gemini-3.1-pro-preview",
		thinking: "high",
	},
	quick_task: {
		provider: "deepseek",
		modelId: "deepseek-v4-pro",
		thinking: "medium",
	},
};

function resolveModel(ctxModel: ExtensionContext["modelRegistry"], shortcut: Shortcut): Model<any> | undefined {
	const direct = ctxModel.find(shortcut.provider, shortcut.modelId);
	if (direct) return direct;

	return ctxModel.getAll().find((m) => m.provider === shortcut.provider && m.id === shortcut.modelId);
}

export default function modelShortcuts(pi: ExtensionAPI) {
	for (const [name, cfg] of Object.entries(SHORTCUTS)) {
		pi.registerCommand(name, {
			description: `Set model to ${cfg.modelId} + thinking ${cfg.thinking}`,
			handler: async (_args, ctx) => {
				const model = resolveModel(ctx.modelRegistry, cfg);
				if (!model) {
					ctx.ui.notify(
						`Model not found: ${cfg.provider}/${cfg.modelId}. Check your login/provider config.`,
						"error",
					);
					return;
				}

				const success = await pi.setModel(model);
				if (!success) {
					ctx.ui.notify(`No API key configured for ${cfg.provider}/${cfg.modelId}`, "error");
					return;
				}

				pi.setThinkingLevel(cfg.thinking);
				ctx.ui.notify(`Switched to ${cfg.provider}/${cfg.modelId} (${cfg.thinking})`, "success");
			},
		});
	}
}
