---
name: epics
description: Reconcile and schedule several independent GitHub epics or issues through bounded capability-based workers, shared dependency analysis, and per-epic delivery gates. Use when the user invokes a portfolio epic command, supplies multiple issue URLs, or requests multi-epic orchestration.
user-invocable: true
---

# Epic Portfolio

Act as one portfolio control plane over several `epic` lanes. Do not create nested control planes and do not edit delivered application code in the portfolio context.

This workflow is harness-, provider-, and model-agnostic. Reuse the installed `epic` skill's capability roles and invariants; do not hardcode agent names, model families, providers, command paths, or task APIs.

## Normalize

Extract complete GitHub issue URLs from the request. Canonicalize each to `owner/repository#number`, remove duplicates while preserving input order, and reject non-issue URLs.

One invocation operates in one current Git repository. Reject targets belonging to another repository.

Read the installed `epic` skill, its state contract, and [references/portfolio-contract.md](references/portfolio-contract.md) before dispatching work. Apply the epic safety, reconciliation, tiering, ownership, review, remediation, and final-gate rules independently to every lane.

## Reconcile all lanes first

1. Acquire the generic portfolio lease.
2. Reconcile every target from live Git and authenticated GitHub state before spawning workers.
3. Determine each lane's tier, children, dependencies, branch and PR state, frozen SHA, current gate, next runnable node, dirty worktrees, and blockers.
4. Acquire required epic leases in canonical sorted order. If a lease is unavailable, mark that lane blocked without cancelling independent lanes.
5. Create or update one generic portfolio checkpoint on the first canonical epic.

## Build the global dependency graph

Create nodes for issue implementation, integration, frozen-SHA review, remediation, and final gates. Add edges when lanes share or may share:

- a child issue, branch, PR, or integration head;
- a migration, schema, generated artifact, lockfile, or central configuration;
- auth, billing, identity, user-data, ownership, deployment, or platform contracts;
- changed files or a direct producer/consumer API.

Serialize plausible overlap. Recompute edges after each implementation wave from actual changed-file lists. Never implement one shared foundation twice.

## Schedule bounded waves

- Admit at most four lanes concurrently unless the repository sets a lower limit.
- Keep at most the host/repository worker cap active, with three as the default ceiling.
- Batch only currently runnable independent nodes.
- Allow one implementer per branch and one review panel per epic/SHA.
- Parallel execution is optional; role independence and frozen inputs are required.
- A blocked lane does not cancel independent lanes.
- Update checkpoints after every settled wave.
- Continue until every requested lane reaches a terminal handoff.

## Execute each lane

For each runnable lane, invoke the installed `epic` contract rather than restating a harness-specific workflow:

- **Fast lane**: one isolated implementer, integrated validation, one fresh primary reviewer, then final gate.
- **Full lane**: dependency waves, isolated implementers, one integration owner, integrated validation, frozen SHA, fresh primary and adversarial reviewers, bounded remediation, then final gate.

Select workers by the role capabilities and risk rules in the epic skill. A historical agent name or configured model may satisfy a role, but it is never part of the durable contract.

Actual merge, deployment, production mutation, pricing change, branch deletion, and issue closure remain unauthorized unless the initiating user explicitly approved them.

## Final handoff

Return:

| Epic / Issue | Tier | Final State | Final SHA | PRs | Verdict | Next Owner Action |
| --- | --- | --- | --- | --- | --- | --- |

Report cross-epic dependencies, residual risks, and safe merge order. Durably update the generic portfolio checkpoint, release owned epic leases, then release the portfolio lease.
