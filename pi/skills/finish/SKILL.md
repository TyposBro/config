---
name: finish
description: Use when the user asks to implement, debug, fix, refactor, migrate, or complete a coding task end-to-end without an explicit existing plan; especially when they say execute don't instruct, do not stop, finish this, commit and continue, or complete 100%.
---

# Finish

## Goal

Complete the requested task end-to-end. Execute rather than instruct, keep durable progress, commit stable chunks when requested, and continue until the requested definition of done is met or a real blocker is documented.

Use this skill for open-ended implementation/debug/fix work. If the user explicitly references an existing plan, checklist, TODO, roadmap, migration plan, or says “finish plan”, use `finish-plan` instead.

## Autonomy Rules

- Execute, don't instruct: inspect the repo, reproduce or understand the issue, choose the safest reasonable implementation, edit code/config/docs, run checks, and continue.
- Do not stop at checkpoints, milestones, or “safe boundaries”; treat them as verify/commit/progress-update points and immediately continue.
- If commits are requested and a git repo exists, commit each stable logical chunk after relevant checks pass, then immediately continue.
- Ask the user only for a real blocker: missing credentials or external service access, destructive production/data risk, external outage, impossible requirement, or safety/security/legal concern.
- If uncertain, inspect code, tests, docs, history, and current behavior; choose the safest reasonable implementation without asking.
- Manage risk with focused tests, feature flags, small commits, rollback paths, and observability instead of stopping.
- Preserve user work: inspect `git status` before edits/commits, do not overwrite unrelated changes, and do not commit secrets, generated junk, or unrelated files.

## Progress Tracking

For non-trivial work, create or update `AGENT_PROGRESS.md` in the target repo/workspace unless the user explicitly specifies another durable progress file.

Track these sections:

- task summary,
- checklist,
- completed work,
- remaining work,
- tests/checks run,
- commits,
- blockers with evidence,
- exact next action.

If context gets large, update `AGENT_PROGRESS.md` and continue.

## Work Loop

1. Inspect current repo state and any existing progress file.
2. Reproduce or characterize the issue/request where practical.
3. Define a short checklist in `AGENT_PROGRESS.md`.
4. Implement the smallest stable logical chunk.
5. Run focused tests/checks; run broader lint/typecheck/build checks when relevant.
6. If checks pass and commits are requested, commit only intended changes.
7. Update `AGENT_PROGRESS.md`.
8. Continue immediately to the next item.

## Allowed Early Stops

Stop before completion only for a real blocker:

- missing credentials or external service access,
- destructive production/data risk or ambiguous destructive decision,
- external outage,
- impossible requirement,
- safety/security/legal concern.

When blocked, write the exact blocker, evidence, files touched, and the next command or decision needed into `AGENT_PROGRESS.md`, then report it.

## Completion Criteria

Do not stop until all applicable criteria are satisfied:

- Full requested task is implemented.
- All checklist items are complete or explicitly marked blocked with evidence.
- Tests/lint/typecheck pass, or failures are documented as unrelated existing failures.
- No TODO/stub/placeholder introduced for this task remains.
- Progress file is updated with final state.
- Requested commits are created, or commit inability is documented with evidence such as “target directory is not a git repo”.
- Final answer includes commits made, files changed, tests run, and remaining risks.
