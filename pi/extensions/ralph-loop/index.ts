import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
import { basename, dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import type { ExtensionAPI, ExtensionCommandContext } from "@earendil-works/pi-coding-agent";

const MAX_BUFFER_LINES = 400;
const WIDGET_LINES = 14;

function shellSplit(input: string): string[] {
	const args: string[] = [];
	let current = "";
	let quote: "'" | '"' | undefined;
	let escaping = false;

	for (const char of input) {
		if (escaping) {
			current += char;
			escaping = false;
			continue;
		}

		if (char === "\\" && quote !== "'") {
			escaping = true;
			continue;
		}

		if ((char === "'" || char === '"') && !quote) {
			quote = char;
			continue;
		}

		if (quote === char) {
			quote = undefined;
			continue;
		}

		if (!quote && /\s/.test(char)) {
			if (current.length > 0) {
				args.push(current);
				current = "";
			}
			continue;
		}

		current += char;
	}

	if (escaping) current += "\\";
	if (quote) throw new Error(`Unclosed quote: ${quote}`);
	if (current.length > 0) args.push(current);
	return args;
}

function trimLines(lines: string[]): string[] {
	return lines.length > MAX_BUFFER_LINES ? lines.slice(-MAX_BUFFER_LINES) : [...lines];
}

function formatOutput(lines: string[]): string {
	return lines.slice(-80).join("\n") || "(no output)";
}

function getNodeCommand(): string {
	if (process.env.RALPH_NODE_BIN) return process.env.RALPH_NODE_BIN;
	const execBase = basename(process.execPath).toLowerCase();
	return execBase.startsWith("node") ? process.execPath : "node";
}

async function runRalphScript(
	pi: ExtensionAPI,
	ctx: ExtensionCommandContext,
	scriptPath: string,
	args: string[],
): Promise<number> {
	const outputLines: string[] = [];
	let child: ChildProcessWithoutNullStreams | undefined;

	const append = (chunk: Buffer, stream: "stdout" | "stderr") => {
		const text = chunk.toString("utf8");
		for (const rawLine of text.split(/\r?\n/)) {
			const line = rawLine.trimEnd();
			if (!line) continue;
			outputLines.push(stream === "stderr" ? `[stderr] ${line}` : line);
		}
		const trimmed = trimLines(outputLines);
		outputLines.length = 0;
		outputLines.push(...trimmed);
		ctx.ui.setWidget("ralph-loop", outputLines.slice(-WIDGET_LINES), { placement: "belowEditor" });
	};

	try {
		const nodeCommand = getNodeCommand();
		outputLines.push(`[ralph-extension] spawn: ${nodeCommand} ${scriptPath} ${args.join(" ")}`);
		child = spawn(nodeCommand, [scriptPath, ...args], {
			cwd: ctx.cwd,
			env: process.env,
			stdio: ["ignore", "pipe", "pipe"],
		});

		activeChild = child;
		child.stdout.on("data", (chunk) => append(chunk, "stdout"));
		child.stderr.on("data", (chunk) => append(chunk, "stderr"));

		const exitCode = await new Promise<number>((resolve) => {
			child!.on("close", (code) => resolve(code ?? 1));
			child!.on("error", (error) => {
				outputLines.push(`[error] ${error.message}`);
				resolve(1);
			});
		});

		const finalOutput = formatOutput(outputLines);
		pi.sendMessage(
			{
				customType: "ralph-loop",
				content: `Ralph loop finished with exit code ${exitCode}.\n\n${finalOutput}`,
				display: true,
				details: { exitCode, args },
			},
			{ triggerTurn: false },
		);
		ctx.ui.notify(exitCode === 0 ? "Ralph loop complete" : `Ralph loop stopped (${exitCode})`, exitCode === 0 ? "info" : "error");
		return exitCode;
	} finally {
		if (activeChild === child) activeChild = undefined;
		ctx.ui.setWidget("ralph-loop", outputLines.slice(-WIDGET_LINES), { placement: "belowEditor" });
	}
}

let activeChild: ChildProcessWithoutNullStreams | undefined;

export default function ralphLoopExtension(pi: ExtensionAPI) {
	const scriptPath = join(dirname(fileURLToPath(import.meta.url)), "ralph-loop.mjs");

	pi.registerCommand("ralph", {
		description: "Run an autonomous milestone loop: implement with medium thinking, review with xhigh, then continue in fresh contexts.",
		handler: async (rawArgs, ctx) => {
			if (activeChild) {
				ctx.ui.notify("A Ralph loop is already running.", "warning");
				return;
			}

			const trimmed = rawArgs.trim();
			if (!trimmed || trimmed === "--help" || trimmed === "-h") {
				pi.sendMessage(
					{
						customType: "ralph-loop",
						content: [
							"Usage:",
							"/ralph <plan.md> [--from N] [--to N] [--model provider/model] [--commit]",
							"",
							"Defaults:",
							"- implementation thinking: medium",
							"- review thinking: xhigh",
							"- context clearing: each implement/review stage is a separate pi process/session",
							"",
							"Example:",
							"/ralph specs/todo/03-instagram-reels-spark-plan.md --from 1 --to 8 --commit",
						].join("\n"),
						display: true,
					},
					{ triggerTurn: false },
				);
				return;
			}

			let args: string[];
			try {
				args = shellSplit(trimmed);
			} catch (error) {
				ctx.ui.notify(error instanceof Error ? error.message : String(error), "error");
				return;
			}

			args.push("--cwd", ctx.cwd);
			ctx.ui.notify("Starting Ralph loop...", "info");
			await runRalphScript(pi, ctx, scriptPath, args);
		},
	});

	pi.registerCommand("ralph-status", {
		description: "Show latest Ralph loop state for this repo.",
		handler: async (rawArgs, ctx) => {
			let args: string[];
			try {
				args = shellSplit(rawArgs.trim());
			} catch (error) {
				ctx.ui.notify(error instanceof Error ? error.message : String(error), "error");
				return;
			}
			args.push("--cwd", ctx.cwd, "--status");
			await runRalphScript(pi, ctx, scriptPath, args);
		},
	});

	pi.on("session_shutdown", () => {
		if (activeChild && !activeChild.killed) {
			activeChild.kill("SIGTERM");
			activeChild = undefined;
		}
	});
}
