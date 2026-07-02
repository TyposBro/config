import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

const EXTREMELY_IMPORTANT_MARKER = "<EXTREMELY_IMPORTANT>";
const BOOTSTRAP_MARKER = "superpowers:using-superpowers bootstrap for omp";

const extensionDir = dirname(fileURLToPath(import.meta.url));
const agentRoot = resolve(extensionDir, "..");
const skillsDir = resolve(agentRoot, "skills");
const bootstrapSkillPath = resolve(skillsDir, "using-superpowers", "SKILL.md");

let cachedBootstrap: string | null | undefined;

export default function superpowersOmpBootstrap(pi: ExtensionAPI) {
	pi.setLabel("Superpowers Bootstrap");

	let injectBootstrap = true;

	pi.on("session_start", async () => {
		injectBootstrap = true;
	});

	pi.on("session_compact", async () => {
		injectBootstrap = true;
	});

	pi.on("agent_end", async () => {
		injectBootstrap = false;
	});

	pi.on("context", async (event) => {
		if (!injectBootstrap) return;
		if (event.messages.some(messageContainsBootstrap)) return;

		const bootstrap = getBootstrapContent();
		if (!bootstrap) return;

		const bootstrapMessage = {
			role: "user" as const,
			content: [{ type: "text" as const, text: bootstrap }],
			timestamp: Date.now(),
		};

		const insertAt = firstNonCompactionSummaryIndex(event.messages);
		return {
			messages: [
				...event.messages.slice(0, insertAt),
				bootstrapMessage,
				...event.messages.slice(insertAt),
			],
		};
	});
}

function getBootstrapContent(): string | null {
	if (cachedBootstrap !== undefined) return cachedBootstrap;

	try {
		const skillContent = readFileSync(bootstrapSkillPath, "utf8");
		const body = stripFrontmatter(skillContent);
		cachedBootstrap = `${EXTREMELY_IMPORTANT_MARKER}
${BOOTSTRAP_MARKER}

You have Superpowers.

The using-superpowers skill content is included below and is already loaded for this OMP session. Follow it now. Do not try to load using-superpowers again.

${body}

${ompToolMapping()}
</EXTREMELY_IMPORTANT>`;
		return cachedBootstrap;
	} catch {
		cachedBootstrap = null;
		return null;
	}
}

function stripFrontmatter(content: string): string {
	const match = content.match(/^---\n[\s\S]*?\n---\n([\s\S]*)$/);
	return (match ? match[1] : content).trim();
}

function ompToolMapping(): string {
	return `## OMP tool mapping

Superpowers skills are installed at \`${skillsDir}\`. When a Superpowers instruction says to invoke a skill, first try \`read skill://<skill-name>\` or \`/skill:<skill-name>\` in the TUI. If OMP reports an unknown skill, read \`${skillsDir}/<skill-name>/SKILL.md\` directly.

OMP's coding tools include \`read\`, \`write\`, \`edit\`, \`bash\`, \`search\`, \`find\`, \`lsp\`, \`task\`, \`todo\`, and \`ask\`. Use those for the corresponding Superpowers actions: read files, create or edit files, run shell commands, search file contents, find files by name, inspect symbols, dispatch subagents, track tasks, and ask the human.

For Superpowers subagent workflows, use OMP's \`task\` tool. For task tracking, use OMP's \`todo\` tool. Treat older \`TodoWrite\` references as this task-tracking action.`;
}

function messageContainsBootstrap(message: unknown): boolean {
	if (!message || typeof message !== "object" || !("content" in message)) {
		return false;
	}

	const content = message.content;
	if (typeof content === "string") return content.includes(BOOTSTRAP_MARKER);
	if (!Array.isArray(content)) return false;

	return content.some((part) => {
		if (!part || typeof part !== "object" || !("type" in part) || !("text" in part)) {
			return false;
		}

		return part.type === "text" && typeof part.text === "string" && part.text.includes(BOOTSTRAP_MARKER);
	});
}

function firstNonCompactionSummaryIndex(messages: unknown[]): number {
	let index = 0;
	while (messageRole(messages[index]) === "compactionSummary") {
		index += 1;
	}
	return index;
}

function messageRole(message: unknown): unknown {
	if (!message || typeof message !== "object" || !("role" in message)) {
		return undefined;
	}
	return message.role;
}
