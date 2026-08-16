---
name: epics
description: Reconcile and schedule several independent GitHub epics in one repository through bounded Codex subagents, shared dependency analysis, and per-epic $epic delivery gates. Use when the user invokes $epics, supplies multiple GitHub epic URLs, asks to finish several epics in parallel, or requests a portfolio control plane. Preserve lane isolation and durable state; do not merge, deploy, mutate production, change pricing, or close issues unless the initiating request explicitly authorizes those actions.
---

# Epic Portfolio

Act as one portfolio control plane over several `$epic` lanes. Do not create nested epic supervisors and do not edit delivered application code in the main thread.

## Normalize

Extract complete GitHub issue URLs from the request. Canonicalize to `owner/repository#number`, remove exact duplicates while preserving input order, and reject non-issue URLs.

Require every target to belong to the current repository and have objective epic evidence: an epic/tracking label, an epic-type project item, or at least two linked sub-issues. One invocation operates in one repository.

Read the installed `$epic` skill and its [state contract](../epic/references/state-contract.md) completely. Apply its reconciliation, implementation, review, remediation, safety, lease, and handoff rules independently to every lane.

Read [references/portfolio-contract.md](references/portfolio-contract.md) before dispatching work.

## Reconcile all lanes first

Acquire a portfolio lease, then reconcile every epic before spawning a writer. Build a lane table with:

- epic URL and canonical key;
- children and explicit dependencies;
- existing branches, PRs, SHAs, checks, reviews, and dirty worktrees;
- integration branch and frozen review SHA;
- durable checkpoint;
- current gate, next runnable node, blockers, and external acceptance.

Acquire each epic lease in canonical-key order. A live owner leaves only that lane queued or blocked; continue independent lanes.

Maintain one `<!-- codex-epics-flow:v1 -->` checkpoint on the first epic. Corroborate it against live Git/GitHub state on restart.

## Build one global DAG

Create nodes for issue implementation, integration, SHA review, remediation, and final gates. Add an edge when epics share a child, PR, branch, migration, schema, generated artifact, integration head, central configuration, high-risk contract, or changed files. Treat a shared foundation as one node with several consumers.

Prefer serialization when overlap is plausible but unresolved. Recompute conflicts after each implementation wave from actual changed-file lists.

## Schedule bounded waves

Invocation of this skill explicitly requires subagent orchestration. Use the custom agents and ownership rules defined by `$epic`.

- Admit at most four epic lanes.
- Keep no more than three spawned agents active at once.
- Batch only currently runnable, independent nodes.
- Permit one writer per branch and one review panel per epic/SHA.
- Do not let a blocked lane cancel unrelated lanes.
- Update lane and portfolio checkpoints after every settled wave.
- Continue scheduling until every requested lane reaches a terminal handoff.

Never launch a subagent that itself runs `$epic`; the main thread owns the global DAG and dispatches bounded leaf work directly.

## Execute each lane

For each runnable lane:

1. Dispatch independent child issues to `epic_builder`.
2. Verify issue → PR → head SHA live.
3. Dispatch one integration writer when required.
4. Run integrated validation and freeze the pushed SHA.
5. Run fresh `sol_reviewer` and `adversarial_reviewer` agents for that SHA.
6. Route supported findings only to `epic_builder`.
7. Repeat for at most three remediation cycles.
8. Run the `$epic` final gate and update its checkpoint.

Actual merge, deployment, production mutation, pricing changes, and issue closure remain unauthorized unless the initiating request explicitly permits them.

## Final handoff

Return one row per input URL, preserving input order:

- normalized epic;
- `BLOCKED`, `READY FOR OWNER QA`, or `READY FOR STAGED RELEASE`;
- final integration SHA;
- issue/PR coverage;
- combined reviewer verdict;
- CI and smoke evidence;
- unresolved findings or external acceptance;
- safe dependency/merge order;
- exactly one next owner action.

Also report the cross-epic dependency order and deliberately serialized lanes. Durably update the portfolio checkpoint with zero active tasks, then release owned locks.
