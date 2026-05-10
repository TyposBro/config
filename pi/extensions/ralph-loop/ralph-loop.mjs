#!/usr/bin/env node
import { spawn } from "node:child_process";
import { createHash } from "node:crypto";
import { existsSync } from "node:fs";
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { basename, dirname, isAbsolute, join, resolve } from "node:path";
import { parseArgs } from "node:util";

const VALID_THINKING = new Set(["off", "minimal", "low", "medium", "high", "xhigh"]);

function now() {
	return new Date().toISOString();
}

function log(message) {
	process.stdout.write(`[ralph ${now()}] ${message}\n`);
}

function fail(message, code = 1) {
	process.stderr.write(`[ralph error] ${message}\n`);
	process.exit(code);
}

function parseCli(argv) {
	const { values, positionals } = parseArgs({
		args: argv,
		allowPositionals: true,
		options: {
			plan: { type: "string" },
			cwd: { type: "string" },
			from: { type: "string" },
			to: { type: "string" },
			model: { type: "string" },
			"implement-thinking": { type: "string", default: "medium" },
			"review-thinking": { type: "string", default: "xhigh" },
			commit: { type: "boolean", default: false },
			"run-id": { type: "string" },
			"state-dir": { type: "string" },
			"pi-bin": { type: "string" },
			"extra-pi-arg": { type: "string", multiple: true },
			"no-extensions": { type: "boolean", default: false },
			"dry-run": { type: "boolean", default: false },
			status: { type: "boolean", default: false },
			help: { type: "boolean", short: "h", default: false },
		},
	});
	return { values, positionals };
}

function usage() {
	return `Ralph loop runner

Usage:
  ralph-loop.mjs <plan.md> [--from N] [--to N] [--model provider/model] [--commit]
  ralph-loop.mjs --status [--cwd <repo>]

Defaults:
  --implement-thinking medium
  --review-thinking xhigh

Each implement/review stage runs in a fresh pi process with its own session, using files + AGENT_PROGRESS.md as durable memory.
Run state is stored under ~/.pi/agent/ralph-loop by default, or --state-dir when provided.`;
}

function resolveFromCwd(cwd, maybePath) {
	return isAbsolute(maybePath) ? maybePath : resolve(cwd, maybePath);
}

function parsePositiveInt(raw, label, fallback) {
	if (raw === undefined || raw === null || raw === "") return fallback;
	const n = Number(raw);
	if (!Number.isInteger(n) || n < 1) fail(`${label} must be a positive integer, got: ${raw}`);
	return n;
}

function makeRunId(planPath) {
	const stamp = new Date().toISOString().replace(/[-:]/g, "").replace(/\.\d+Z$/, "Z");
	const safePlan = basename(planPath).replace(/[^a-zA-Z0-9_.-]+/g, "-").replace(/\.md$/i, "");
	return `${stamp}-${safePlan}`;
}

function defaultStateRoot(cwd) {
	const agentDir = process.env.PI_CODING_AGENT_DIR || join(homedir(), ".pi", "agent");
	const repoName = basename(cwd).replace(/[^a-zA-Z0-9_.-]+/g, "-") || "workspace";
	const hash = createHash("sha1").update(cwd).digest("hex").slice(0, 12);
	return join(agentDir, "ralph-loop", `${repoName}-${hash}`);
}

function extractMilestones(planText) {
	const re = /^(#{2,4})\s+Milestone\s+(\d+)\s*(?:[—-]\s*)?(.+?)\s*$/gim;
	const matches = [];
	let match;
	while ((match = re.exec(planText))) {
		matches.push({ index: match.index, heading: match[0], level: match[1].length, number: Number(match[2]), title: match[3].trim() });
	}
	if (matches.length === 0) return [];
	return matches.map((m, i) => {
		const next = matches[i + 1];
		return {
			number: m.number,
			title: m.title,
			heading: m.heading,
			section: planText.slice(m.index, next ? next.index : planText.length).trim(),
		};
	});
}

function finalAssistantTextFromMessage(message) {
	if (!message || message.role !== "assistant") return "";
	const content = message.content;
	if (typeof content === "string") return content;
	if (!Array.isArray(content)) return "";
	return content
		.filter((part) => part && part.type === "text" && typeof part.text === "string")
		.map((part) => part.text)
		.join("\n");
}

function parseStageStatus(text) {
	const match = text.match(/RALPH_STATUS:\s*(success|blocked|failed)/i);
	return match ? match[1].toLowerCase() : "unknown";
}

function usageFromMessage(message) {
	const usage = message?.usage;
	if (!usage) return undefined;
	return {
		input: usage.input ?? 0,
		output: usage.output ?? 0,
		cacheRead: usage.cacheRead ?? 0,
		cacheWrite: usage.cacheWrite ?? 0,
		totalTokens: usage.totalTokens ?? 0,
		cost: usage.cost?.total ?? 0,
	};
}

async function writeJson(path, data) {
	await mkdir(dirname(path), { recursive: true });
	await writeFile(path, `${JSON.stringify(data, null, 2)}\n`, "utf8");
}

async function readJson(path) {
	return JSON.parse(await readFile(path, "utf8"));
}

function buildPiArgs({ sessionDir, thinking, model, prompt, extraPiArgs, noExtensions }) {
	const args = ["--mode", "json", "--session-dir", sessionDir, "--thinking", thinking];
	if (model) args.push("--model", model);
	if (noExtensions) args.push("--no-extensions");
	if (extraPiArgs?.length) args.push(...extraPiArgs);
	args.push("-p", prompt);
	return args;
}

async function runPiStage({ cwd, piBin, sessionDir, logPath, thinking, model, prompt, extraPiArgs, noExtensions }) {
	await mkdir(dirname(logPath), { recursive: true });
	await mkdir(sessionDir, { recursive: true });

	const args = buildPiArgs({ sessionDir, thinking, model, prompt, extraPiArgs, noExtensions });
	const rawLines = [];
	let lastAssistantText = "";
	let lastUsage;
	let lastModel;
	let stopReason;
	let assistantTurns = 0;
	let toolCalls = 0;

	log(`spawn: ${piBin} ${args.slice(0, -1).join(" ")} <prompt:${prompt.length} chars>`);

	const exitCode = await new Promise((resolve) => {
		const child = spawn(piBin, args, {
			cwd,
			env: process.env,
			stdio: ["ignore", "pipe", "pipe"],
		});

		let stdoutBuffer = "";
		let stderrBuffer = "";

		function handleLine(line) {
			if (!line.trim()) return;
			rawLines.push(line);
			let event;
			try {
				event = JSON.parse(line);
			} catch {
				return;
			}

			if (event.type === "tool_execution_start") {
				toolCalls += 1;
				const name = event.toolName || "tool";
				log(`tool: ${name}`);
			}

			if (event.type === "message_end" && event.message?.role === "assistant") {
				assistantTurns += 1;
				lastAssistantText = finalAssistantTextFromMessage(event.message);
				lastUsage = usageFromMessage(event.message);
				lastModel = event.message.model || lastModel;
				stopReason = event.message.stopReason || stopReason;
				const status = parseStageStatus(lastAssistantText);
				const usageText = lastUsage ? ` tokens=${lastUsage.totalTokens} cost=$${Number(lastUsage.cost || 0).toFixed(4)}` : "";
				log(`assistant turn ${assistantTurns}: status=${status}${usageText}`);
			}
		}

		child.stdout.on("data", (chunk) => {
			stdoutBuffer += chunk.toString("utf8");
			const lines = stdoutBuffer.split(/\r?\n/);
			stdoutBuffer = lines.pop() ?? "";
			for (const line of lines) handleLine(line);
		});

		child.stderr.on("data", (chunk) => {
			stderrBuffer += chunk.toString("utf8");
		});

		child.on("error", (error) => {
			rawLines.push(JSON.stringify({ type: "spawn_error", error: error.message }));
			resolve(1);
		});

		child.on("close", (code) => {
			if (stdoutBuffer.trim()) handleLine(stdoutBuffer);
			if (stderrBuffer.trim()) {
				for (const line of stderrBuffer.split(/\r?\n/).filter(Boolean)) {
					rawLines.push(JSON.stringify({ type: "stderr", line }));
				}
			}
			resolve(code ?? 1);
		});
	});

	await writeFile(logPath, `${rawLines.join("\n")}\n`, "utf8");

	return {
		exitCode,
		status: exitCode === 0 ? parseStageStatus(lastAssistantText) : "process_failed",
		assistantTurns,
		toolCalls,
		usage: lastUsage,
		model: lastModel,
		stopReason,
		logPath,
		finalTextPreview: lastAssistantText.slice(-4000),
	};
}

function buildImplementPrompt({ planPath, milestone, commit }) {
	return `You are running inside an automated Ralph loop.

Stage: IMPLEMENT Milestone ${milestone.number} — ${milestone.title}
Source-of-truth plan: ${planPath}
Thinking level for this stage: medium/default

Rules:
- Implement ONLY Milestone ${milestone.number}. Do not implement later milestones.
- Backend/test work comes before UI when the milestone says so.
- Keep changes small and obvious. Prefer existing project patterns.
- Read the repo instructions/progress files you need, but avoid loading unrelated huge files.
- Update AGENT_PROGRESS.md with this milestone's work, tests, blockers, and exact next action.
- Run the validation commands listed in this milestone section when practical; fix failures.
- If you hit a real blocker, document it in AGENT_PROGRESS.md.
- Do NOT commit in this implementation stage. The review stage will commit after high-reasoning validation if --commit was requested.

Commit requested after review: ${commit ? "yes" : "no"}

Milestone section:

${milestone.section}

Final response contract:
- If this milestone is implemented and focused checks pass, end with this exact final line: RALPH_STATUS: success
- If blocked or checks fail and cannot be fixed, end with this exact final line: RALPH_STATUS: blocked`;
}

function buildReviewPrompt({ planPath, milestone, commit }) {
	return `You are running inside an automated Ralph loop.

Stage: HIGH-REASONING REVIEW Milestone ${milestone.number} — ${milestone.title}
Source-of-truth plan: ${planPath}
Thinking level for this stage: xhigh/high

Your job:
1. Inspect the current repo state and AGENT_PROGRESS.md.
2. Verify the implementation for ONLY Milestone ${milestone.number} against the plan section below.
3. Check for scope creep into later milestones, obvious bugs, missing tests, broken idempotency/security issues, and failing validation commands.
4. If you find safe fixes, apply them now and rerun focused checks.
5. Do not start the next milestone.
6. Update AGENT_PROGRESS.md with review findings, tests run, commits, blockers, and next action.
7. If commit requested and checks pass, commit only intended milestone changes as one stable milestone chunk.

Commit requested: ${commit ? "yes" : "no"}

Milestone section:

${milestone.section}

Final response contract:
- If the milestone is correct/reviewed and checks pass, end with this exact final line: RALPH_STATUS: success
- If blocked or checks fail and cannot be fixed, end with this exact final line: RALPH_STATUS: blocked`;
}

function printStatus(cwd, stateDir) {
	const latestPath = join(stateDir || defaultStateRoot(cwd), "latest.json");
	if (!existsSync(latestPath)) {
		log(`No Ralph loop state found at ${latestPath}`);
		return;
	}
	return readJson(latestPath).then((state) => {
		log(`Latest run: ${state.runId}`);
		log(`Status: ${state.status}; plan: ${state.planPath}`);
		log(`Milestones: ${state.from}-${state.to}; current: ${state.currentMilestone ?? "none"}`);
		for (const stage of state.stages ?? []) {
			const impl = stage.implement?.status ?? "pending";
			const review = stage.review?.status ?? "pending";
			log(`Milestone ${stage.milestone}: implement=${impl}, review=${review}`);
		}
	});
}

async function main() {
	const { values, positionals } = parseCli(process.argv.slice(2));
	if (values.help) {
		process.stdout.write(`${usage()}\n`);
		return;
	}

	const cwd = resolve(values.cwd || process.cwd());
	const stateRoot = values["state-dir"] ? resolveFromCwd(cwd, values["state-dir"]) : defaultStateRoot(cwd);

	if (values.status) {
		await printStatus(cwd, stateRoot);
		return;
	}

	const planArg = values.plan || positionals[0];
	if (!planArg) fail(`Missing plan path.\n\n${usage()}`);

	const implementThinking = values["implement-thinking"];
	const reviewThinking = values["review-thinking"];
	if (!VALID_THINKING.has(implementThinking)) fail(`Invalid --implement-thinking: ${implementThinking}`);
	if (!VALID_THINKING.has(reviewThinking)) fail(`Invalid --review-thinking: ${reviewThinking}`);

	const planPath = resolveFromCwd(cwd, planArg);
	if (!existsSync(planPath)) fail(`Plan file does not exist: ${planPath}`);

	const planText = await readFile(planPath, "utf8");
	const milestones = extractMilestones(planText).sort((a, b) => a.number - b.number);
	if (milestones.length === 0) fail(`No headings like "Milestone N" found in ${planPath}`);

	const from = parsePositiveInt(values.from, "--from", milestones[0].number);
	const to = values.to === "all" || values.to === undefined ? milestones[milestones.length - 1].number : parsePositiveInt(values.to, "--to");
	if (to < from) fail(`--to (${to}) must be >= --from (${from})`);

	const selected = milestones.filter((m) => m.number >= from && m.number <= to);
	if (selected.length === 0) fail(`No milestones selected for range ${from}-${to}`);

	const runId = values["run-id"] || makeRunId(planPath);
	const runRoot = join(stateRoot, runId);
	const sessionRoot = join(runRoot, "sessions");
	const statePath = join(runRoot, "state.json");
	const latestPath = join(stateRoot, "latest.json");
	const piBin = values["pi-bin"] || process.env.PI_BIN || "pi";
	const extraPiArgs = values["extra-pi-arg"] || [];

	const state = {
		runId,
		cwd,
		planPath,
		from,
		to,
		status: values["dry-run"] ? "dry-run" : "running",
		startedAt: now(),
		updatedAt: now(),
		implementThinking,
		reviewThinking,
		model: values.model || null,
		commit: Boolean(values.commit),
		noExtensions: Boolean(values["no-extensions"]),
		stages: [],
	};

	await writeJson(statePath, state);
	await writeJson(latestPath, state);

	log(`Run ${runId}`);
	log(`Plan ${planPath}`);
	log(`Milestones ${selected.map((m) => m.number).join(", ")}`);
	log(`Implement thinking=${implementThinking}; review thinking=${reviewThinking}; commit=${state.commit ? "yes" : "no"}`);

	if (values["dry-run"]) {
		for (const milestone of selected) log(`dry-run milestone ${milestone.number}: ${milestone.title}`);
		return;
	}

	for (const milestone of selected) {
		state.currentMilestone = milestone.number;
		const stageState = { milestone: milestone.number, title: milestone.title, startedAt: now() };
		state.stages.push(stageState);
		state.updatedAt = now();
		await writeJson(statePath, state);
		await writeJson(latestPath, state);

		log(`Milestone ${milestone.number} implement start: ${milestone.title}`);
		stageState.implement = await runPiStage({
			cwd,
			piBin,
			sessionDir: join(sessionRoot, `m${milestone.number}-implement`),
			logPath: join(runRoot, `m${milestone.number}-implement.jsonl`),
			thinking: implementThinking,
			model: values.model,
			prompt: buildImplementPrompt({ planPath, milestone, commit: state.commit }),
			extraPiArgs,
			noExtensions: state.noExtensions,
		});
		state.updatedAt = now();
		await writeJson(statePath, state);
		await writeJson(latestPath, state);

		if (stageState.implement.status !== "success") {
			state.status = "blocked";
			state.blockedAt = now();
			state.blockedReason = `Milestone ${milestone.number} implementation status: ${stageState.implement.status}`;
			await writeJson(statePath, state);
			await writeJson(latestPath, state);
			fail(state.blockedReason, 2);
		}

		log(`Milestone ${milestone.number} review start: ${milestone.title}`);
		stageState.review = await runPiStage({
			cwd,
			piBin,
			sessionDir: join(sessionRoot, `m${milestone.number}-review`),
			logPath: join(runRoot, `m${milestone.number}-review.jsonl`),
			thinking: reviewThinking,
			model: values.model,
			prompt: buildReviewPrompt({ planPath, milestone, commit: state.commit }),
			extraPiArgs,
			noExtensions: state.noExtensions,
		});
		stageState.completedAt = now();
		state.updatedAt = now();
		await writeJson(statePath, state);
		await writeJson(latestPath, state);

		if (stageState.review.status !== "success") {
			state.status = "blocked";
			state.blockedAt = now();
			state.blockedReason = `Milestone ${milestone.number} review status: ${stageState.review.status}`;
			await writeJson(statePath, state);
			await writeJson(latestPath, state);
			fail(state.blockedReason, 3);
		}

		log(`Milestone ${milestone.number} complete`);
	}

	state.status = "complete";
	state.completedAt = now();
	state.currentMilestone = null;
	state.updatedAt = now();
	await writeJson(statePath, state);
	await writeJson(latestPath, state);
	log(`Ralph loop complete: ${runId}`);
}

main().catch((error) => fail(error instanceof Error ? error.stack || error.message : String(error)));
