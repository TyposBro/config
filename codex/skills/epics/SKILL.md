---
name: epics
description: Reconcile and schedule several independent GitHub epics or issues in parallel through bounded Codex subagents, shared dependency analysis, and per-epic delivery gates. Use when the user invokes $epics, supplies multiple issue URLs, or requests a multi-epic portfolio control plane.
---

# Epic Portfolio

Act as the portfolio control plane over several `$epic` lanes. Do not create nested epic supervisors and do not edit delivered application code in the main thread.

## Normalize

Extract complete GitHub issue URLs from the request. Canonicalize to `owner/repository#number`, remove duplicates while preserving input order, and reject non-issue URLs.

Require every target to belong to the current Git repository.

Read the installed `epic` skill and its state contract. Apply its tiering, reconciliation, implementation, review, remediation, safety, lease, and handoff rules independently to every lane.

Read [references/portfolio-contract.md](references/portfolio-contract.md) before dispatching work.

## Reconcile all lanes first

Acquire a portfolio lease via `scripts/epic-lock.sh`, then reconcile every epic before spawning workers:

- Canonical key and issue URL;
- Execution tier (Fast Tier for single/leaf issues vs Full Epic Tier for multi-issue trees);
- Sub-issues and explicit dependencies;
- Existing branches, PRs, SHAs, checks, reviews, and dirty worktrees;
- Current gate, next runnable node, and blockers.

Maintain one `<!-- epics-flow:v1 -->` (or `<!-- codex-epics-flow:v1 -->` / `<!-- omp-portfolio-flow:v1 -->`) comment on the first epic. Corroborate against live Git/GitHub state on restart.

## Build the global dependency graph

Create nodes for issue implementation, integration, SHA review, remediation, and final gates. Add dependency edges when epics share a sub-issue, PR, branch, migration, schema, central configuration, or modified files.

Prefer serialization when overlap is plausible. Recompute conflicts after each implementation wave from actual changed-file lists.

## Schedule bounded waves

- Admit at most 4 epic lanes concurrently.
- Keep no more than 3 spawned subagents active at once across all lanes.
- Batch currently runnable, independent nodes.
- Permit 1 writer per branch and 1 review panel per epic/SHA.
- A blocked lane never cancels independent lanes.
- Update checkpoints after every settled wave.
- Continue scheduling until every requested lane reaches a terminal handoff.

## Execute each lane

For each runnable lane:

1. **Fast Tier lanes**: Dispatch single `epic_builder` → integrated validation → single `sol_reviewer` → deliver.
2. **Full Epic Tier lanes**:
   - Dispatch independent child issues to `epic_builder`.
   - Verify PR heads live on GitHub via `gh`.
   - Dispatch integration writer on dedicated review branch; freeze integration SHA.
   - Run parallel `sol_reviewer` and `adversarial_reviewer` subagents on frozen SHA.
   - Route findings to `epic_builder` (max 3 remediation cycles; prompt owner on stubborn impasse).
   - Run the final gate and update lane checkpoint.

Actual merge, deployment, production mutation, and issue closure remain unauthorized unless explicitly approved.

## Final handoff

Return a summary table for all lanes:

| Epic / Issue | Tier | Final State | Final SHA | PRs | Verdict | Next Owner Action |
| --- | --- | --- | --- | --- | --- | --- |

Report cross-epic dependencies and safe merge order, durably update the portfolio checkpoint, and release owned locks.
