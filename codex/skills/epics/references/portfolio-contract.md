# Portfolio Contract

## Generic checkpoint

Maintain one updatable comment on the first canonical epic:

```markdown
<!-- epics-flow:v2 -->
portfolio_id: <stable-id>
repository: <owner/repository>
lanes:
  - <epic> | <tier> | <gate> | <sha-or-none> | <terminal-state-or-in-progress>
dependency_edges:
  - <from> -> <to> | <reason>
active_nodes:
  - <epic> | <issue-or-integration> | <implementer|primary-reviewer|adversarial-reviewer|advisor> | <branch-or-sha>
completed_wave: <number>
blockers:
  - <epic> | <blocker-or-none>
updated_at: <ISO-8601>
```

Recognize legacy `epics-flow`, `opencode-epics-flow`, `omp-portfolio-flow`, and `codex-epics-flow` markers during reconciliation. On the next mutation, update the existing comment in place to `<!-- epics-flow:v2 -->`; do not create parallel harness-specific comments.

Compute `portfolio_id` from sorted canonical epic keys. Live Git and GitHub state overrides stale portfolio data.

## Conflict rules

Serialize nodes that share or plausibly share:

- child issues, branches, PRs, or integration heads;
- migrations, schemas, generated artifacts, lockfiles, or central configuration;
- auth, billing, identity, user-data, ownership, deployment, or platform contracts;
- changed files or direct producer/consumer APIs.

Recompute edges after each wave using actual changed files. Never implement one shared foundation twice.

## Scheduling rules

- Maximum admitted lanes: four, unless repository policy is lower.
- Maximum active workers: the lower of the host cap, repository cap, and three by default.
- Fast lanes use one isolated implementer and one fresh primary reviewer.
- Full lanes use dependency waves, one integration owner, a frozen SHA, and two fresh independent reviewer contexts.
- Worker selection is capability- and risk-based; names, models, providers, and harness APIs are not checkpoint fields or scheduling invariants.
- The portfolio context owns reconciliation, scheduling, validation, checkpoints, and synthesis—not application-code edits.
- A blocked lane does not cancel independent lanes.
- Do not merge one epic to unblock another; report the proposed dependency and safe merge order.
