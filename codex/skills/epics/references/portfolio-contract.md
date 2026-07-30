# Portfolio Contract

## Portfolio checkpoint

Maintain one updatable comment on the first canonical epic:

```markdown
<!-- codex-epics-flow:v1 -->
portfolio_id: <stable-id>
repository: <owner/repository>
lanes:
  - <epic> | <gate> | <sha-or-none> | <terminal-state-or-in-progress>
dependency_edges:
  - <from> -> <to> | <reason>
active_nodes:
  - <node-or-none>
completed_wave: <number>
blockers:
  - <epic> | <blocker-or-none>
updated_at: <ISO-8601>
```

Compute `portfolio_id` from sorted canonical epic keys. Git/GitHub live state overrides stale portfolio data.

## Conflict rules

Serialize nodes that share or plausibly share:

- child issues, branches, PRs, or integration heads;
- migrations, schemas, generated artifacts, lockfiles, or central configuration;
- auth, billing, identity, user-data, ownership, deployment, or platform contracts;
- changed files or direct producer/consumer APIs.

Recompute edges after each wave using actual PR changed files. Never implement one shared foundation twice.

## Scheduling rules

- Maximum admitted lanes: four.
- Maximum active spawned agents: three.
- Main thread owns scheduling, reconciliation, validation, checkpoints, and final synthesis.
- Spawn leaf writers and reviewers only; no nested epic supervisors.
- A blocked lane does not cancel independent work.
- One writer owns one branch.
- One core review panel owns one epic/SHA.
- Do not merge one epic to unblock another; report the proposed dependency order.
