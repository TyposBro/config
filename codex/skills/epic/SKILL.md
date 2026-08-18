---
name: epic
description: Reconcile, resume, implement, independently review, and hand off one GitHub epic or bounded issue. Supports both Fast Tier (single-issue / bounded fix) and Full Epic Tier (multi-issue DAG + dual review + frozen SHA) through isolated Codex subagents. Use when the user invokes $epic, supplies an issue URL, or asks Codex to act as the control plane for epic delivery.
---

# Epic Delivery

Act as the control plane. Reconstruct durable state, select execution tier, schedule bounded work, verify evidence, and return an honest handoff state. Do not edit delivered application code in the main thread.

## Parse the request

Accept:

```text
$epic <issue-url> [auto|fast|full|implement|review] [frozen-sha]
```

- `auto` (default): Reconstruct durable state and continue from the first incomplete gate. Auto-selects Fast Tier for single issues or Full Epic Tier for epics with sub-issues.
- `fast`: Fast Tier for bounded/single issues: 1 writer (`epic_builder`), 1 reviewer (`sol_reviewer`), direct integrated validation.
- `full`: Full Epic Tier: multi-agent dependency graph, dedicated integration branch, frozen SHA, dual independent review (`sol_reviewer` + `adversarial_reviewer`), and bounded remediation.
- `implement` / `review`: Constrain to implementation or review phase without duplicating completed work. In review mode, freeze the supplied SHA or current pushed integration head.

Require one complete GitHub issue URL belonging to the current Git repository.

## Load the contract

Read [references/state-contract.md](references/state-contract.md) before changing GitHub, branches, worktrees, or checkpoints. Use [scripts/epic-lock.sh](scripts/epic-lock.sh) for acquiring and releasing leases.

Read the repository's nearest `AGENTS.md`, source-of-truth index, roadmap, architecture rules, engineering rules, GitHub conventions, and validation commands. Treat issue acceptance criteria and non-goals as the implementation contract.

Use the GitHub connector when available; otherwise use the authenticated `gh` CLI. Never use unauthenticated web search as evidence for private repository state.

## Phase 0 — Reconcile before dispatch

Perform on every invocation:

1. Refresh remote refs without modifying worktrees.
2. Read the epic/issue, linked children, dependencies, project fields, comments, linked PRs, checks, reviews, branch heads, and merge state.
3. Inspect local and remote issue branches plus `git worktree list --porcelain`.
4. Locate the newest checkpoint (`<!-- epic-flow:v1 -->`, `<!-- codex-epic-flow:v1 -->`, or legacy markers) and corroborate against live state.
5. Determine execution tier:
   - **Fast Tier**: Single issue without sub-issues, or explicit `fast` mode.
   - **Full Epic Tier**: Multi-issue epic with sub-issues/dependencies, or explicit `full` mode.
6. Acquire the epic lease via `scripts/epic-lock.sh`. Refuse a live running owner; clean stale dead locks automatically.
7. Select the first incomplete dependency gate.

Reuse existing issue branches and PRs. Never delete, reset, clean, stash, or overwrite a dirty worktree.

## Execution Tiers

### Fast Tier (Single / Bounded Issue)

1. Dispatch bounded contract to `epic_builder` in an isolated worktree.
2. `epic_builder` implements changes, runs focused tests, and pushes to an issue PR branch.
3. In main thread, run repository-prescribed integrated validation on the PR branch.
4. Spawn one fresh read-only `sol_reviewer` for acceptance criteria & safety.
5. If issues are found, dispatch 1 remediation pass to `epic_builder`.
6. Proceed directly to Final Gate.

### Full Epic Tier (Multi-Issue Epic)

1. **Graph Construction**: Map child issues into dependency waves. Serialize work sharing contracts, migrations, schemas, lockfiles, or central config. Parallelize only independent nodes (max 3 concurrent agents).
2. **Subagents**:
   - `epic_builder`: sole writer (`gpt-5.6-luna` with max reasoning).
   - `sol_reviewer`: primary fresh read-only review (`gpt-5.6-sol` with max reasoning).
   - `adversarial_reviewer`: independent failure-mode review (`gpt-5.6-terra` with max reasoning).
   - `epic_designer`: optional read-only product/UI direction (`gpt-5.6-sol`).
3. **Implementation Waves**:
   - Dispatch independent child contracts to `epic_builder`.
   - Verify returned issue → PR → head SHA mapping from live GitHub state.
   - Dispatch one `epic_builder` to update the dedicated integration branch.
4. **Integrated Validation & Freeze**:
   - In main thread, inspect diff, run validation, and wait for required CI.
   - Push and freeze one immutable integration SHA before review.
5. **Dual Independent Review**:
   - Spawn fresh `sol_reviewer` and `adversarial_reviewer` in parallel on the frozen SHA.
   - Compare findings. If high-risk contracts or disputes exist, escalate.
6. **Remediation**:
   - On `changes_required`, increment durable remediation count (max 3 cycles).
   - Translate findings into contracts for `epic_builder`, verify new SHA, and re-review.
   - If blocked by ambiguous spec after 2 cycles, escalate to owner interactively.

## Final Gate

Confirm:
- Final immutable SHA verified and mergeable in documented order.
- Child issue/PR coverage complete with required CI and smoke evidence.
- Reviewer verdict is `pass` (or explicitly approved by owner).
- No unauthorized merge, deployment, production mutation, pricing change, or issue closure occurred.

Update the durable checkpoint, release owned locks, and return:
- `READY FOR OWNER QA` (or `READY FOR STAGED RELEASE` / `BLOCKED`)
- Final SHA, PR table, reviewer verdict, validation evidence, external acceptance checklist, safe merge order, and exactly one next owner action.
