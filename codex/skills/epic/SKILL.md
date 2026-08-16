---
name: epic
description: Reconcile, resume, implement, independently review, and hand off one GitHub epic through isolated Codex subagents. Use when the user invokes $epic, supplies a GitHub epic URL and asks to finish or resume it, requests epic implementation or review, or asks Codex to act as the control plane for a multi-issue GitHub epic. Preserve existing branches, PRs, worktrees, and durable checkpoints; stop before merge, deployment, production mutation, pricing changes, or manual issue closure unless the initiating request explicitly authorizes them.
---

# Epic Delivery

Act as the control plane. Reconstruct durable state, schedule bounded work, verify evidence, and return one honest handoff state. Do not edit delivered application code in the main thread.

## Parse the request

Accept:

```text
$epic <issue-url> [auto|implement|review] [frozen-sha]
```

Treat an omitted phase as `auto`. In `auto`, continue from the first incomplete gate. `implement` and `review` constrain the next eligible phase but never duplicate completed work. In review mode, freeze the supplied SHA or the current pushed integration head.

Require one complete GitHub issue URL. Confirm that it belongs to the current Git repository and is an epic under repository conventions. Stop on repository mismatch or ambiguous epic identity.

## Load the contract

Read [references/state-contract.md](references/state-contract.md) before changing GitHub, branches, worktrees, or checkpoints. Use [scripts/epic-lock.sh](scripts/epic-lock.sh) for the epic lease and every writer/review node lease.

Read the repository's nearest `AGENTS.md`, source-of-truth index, roadmap, architecture rules, engineering rules, GitHub conventions, and validation commands. Treat issue acceptance criteria and non-goals as the implementation contract.

Use the GitHub connector when available; otherwise use the authenticated `gh` CLI. Never use unauthenticated web search as evidence for private repository state.

## Reconcile before dispatch

Perform this on every invocation:

1. Refresh remote refs without modifying worktrees.
2. Read the epic, linked children, dependencies, project fields, comments, linked PRs, checks, reviews, branch heads, and merge state.
3. Inspect local and remote issue branches plus `git worktree list --porcelain`.
4. Locate the newest `<!-- codex-epic-flow:v1 -->` checkpoint and corroborate it against live Git and GitHub state.
5. Classify every child using only the states in the state contract.
6. Acquire the epic lease. Refuse a live owner; never run two control planes for the same epic.
7. Select the first incomplete dependency gate.

Reuse existing issue branches and PRs. Do not create replacements because a previous task ended. Never delete, reset, clean, stash, or overwrite a dirty worktree. Preserve and report ambiguous work as blocked.

## Build the execution graph

Map child issues into dependency waves. Serialize work when issues share contracts, migrations, generated artifacts, lockfiles, central configuration, or likely files. Parallelize only independent nodes.

Invocation of this skill explicitly requires a subagent workflow. Use these custom agents when available:

- `epic_builder`: sole writer for implementation, tests, migrations, integration, conflict resolution, and remediation.
- `sol_reviewer`: primary fresh read-only review of the frozen SHA.
- `adversarial_reviewer`: independent read-only review focused on subtle failure modes.
- `epic_designer`: optional read-only product/UI direction when acceptance criteria leave a material design decision unresolved.

If the current surface cannot select named custom agents but can choose a subagent model, preserve the same role contract explicitly in the spawn assignment:

- Spawn `gpt-5.6-luna` with max reasoning and the `epic_builder` instructions for writing.
- Spawn `gpt-5.6-sol` with max reasoning and the `sol_reviewer` read-only contract.
- Spawn `gpt-5.6-terra` with max reasoning and the `adversarial_reviewer` read-only contract.
- Spawn `gpt-5.6-sol` with max reasoning and the `epic_designer` read-only contract when needed.

Do not substitute the main thread as writer. If neither named agents nor model-selectable subagents are available, stop with the exact setup/restart action required.

Keep no more than three child agents active at once. Every writer owns exactly one issue branch, PR branch, or integration branch. Give each assignment the epic, issue contract, dependencies, branch/PR ownership, non-goals, expected evidence, applicable lease paths/tokens, and prohibition on merge/deployment/issue closure.

## Implement

Run only when reconciliation finds incomplete engineering work:

1. Acquire a writer-node lease before each branch-owning spawn.
2. Dispatch independent bounded child contracts to `epic_builder`.
3. Require complete issue-level changes, focused tests, observed commands, and an existing or newly created draft PR.
4. Verify every returned issue → PR → head SHA mapping from live GitHub state.
5. Dispatch one `epic_builder` to build or update a dedicated integration branch when the repository's epic convention requires it.
6. In the main thread, inspect the resulting diff, run repository-prescribed integrated validation, and wait for required CI.
7. Push and freeze one immutable integration SHA before review.

Do not run the same project-wide validation redundantly in every child. The main control plane owns integrated verification but does not patch failures.

## Review

For one frozen pushed SHA:

1. Acquire a SHA-scoped review-node lease.
2. Spawn fresh `sol_reviewer` and `adversarial_reviewer` agents in parallel.
3. Give both the issue contracts, PRs, exact SHA, and factual verification handoff—not implementation transcripts or another reviewer's findings.
4. Require each to return: verdict, reviewed SHA, acceptance-criterion matrix, P0–P3 findings with `path:line`, evidence, correction required, blockers, and safe merge order.
5. Compare findings after both initial opinions are frozen. Ask each reviewer to confirm or refute concrete disagreements with source evidence.

Synthesize:

- `changes_required`: any supported P0/P1/P2 defect or failed acceptance criterion.
- `blocked`: a required reviewer or verification gate is unavailable, or material disagreement remains unresolved.
- `pass`: both reviewers examined the same SHA, all criteria pass or are justified N/A, and no supported P0/P1/P2 remains.

P3 is advisory unless several P3 findings establish one systemic defect.

## Remediate

On `changes_required`:

1. Increment the durable remediation count before dispatch.
2. Translate supported findings into bounded contracts for `epic_builder`.
3. Require finding → fix → test → new pushed SHA evidence.
4. Independently verify the new SHA and CI.
5. Run fresh reviewers for the new SHA.

Allow at most three remediation/re-review cycles. Never reuse a verdict from an older SHA or lower the review standard to finish.

## Final gate

Confirm:

- final immutable SHA;
- child issue/PR coverage;
- intended heads included and mergeable in documented order;
- required checks and smoke evidence;
- a combined `pass` for the final SHA;
- project hierarchy/status consistent with repository conventions;
- no unauthorized merge, deployment, production mutation, pricing change, or issue closure;
- unavailable console, device, signing, staging, deployment, or observation evidence listed explicitly.

Update the single durable checkpoint, release owned locks, and return exactly one state:

- `BLOCKED`
- `READY FOR OWNER QA`
- `READY FOR STAGED RELEASE`

Include the final SHA, PR table, reviewer verdict, validation evidence, external acceptance checklist, safe merge order, and exactly one next owner action.
