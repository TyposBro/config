---
name: finish-plan
description: Use when the user asks to implement or continue an explicit plan, checklist, TODO, roadmap, migration plan, refactor plan, or issue plan to completion; especially when they say finish plan, continue the plan, do not stop at safe boundaries, or commit and continue through a checklist.
---

# Finish Plan

## Goal

Drive an explicit plan/checklist/TODO/roadmap to its requested definition of done. Execute the plan rather than explaining it, and do not treat checkpoints as stopping points.

Use this skill when there is an existing or user-provided plan. For open-ended debug/fix/implementation requests without an explicit plan, use `finish` instead.

## Plan State

1. Locate durable task state:
   - Prefer a user-specified plan/progress file.
   - Otherwise look for `AGENT_PROGRESS.md`, `IMPLEMENTATION_PLAN.md`, `PLAN.md`, `TODO.md`, roadmap docs, issue notes, or relevant migration/refactor docs.
   - If no durable plan exists and the work is non-trivial, create `AGENT_PROGRESS.md` with checklist, acceptance criteria, and progress.
2. Treat the located plan as the source of truth, but keep `AGENT_PROGRESS.md` updated for autonomous progress unless the user requests a different progress file.
3. Track checklist, completed work, remaining work, tests/checks run, commits, blockers with evidence, and exact next action.
4. If context gets large, update `AGENT_PROGRESS.md` and continue.

## Autonomy Rules

- Execute, don't instruct: inspect the repo, read the plan, choose the safest reasonable implementation, edit files, run checks, and continue.
- Do not stop at checkpoints, “safe boundaries”, or milestones; use them to verify, optionally commit, update progress, and keep going.
- If commits are requested and a git repo exists, commit each stable logical chunk after relevant checks pass, then immediately continue.
- Ask the user only for a real blocker: missing credentials or external service access, destructive production/data risk, external outage, impossible requirement, or safety/security/legal concern.
- If uncertain, inspect repo state, code, tests, docs, and history; choose the safest reasonable path without asking.
- Manage risk with tests, feature flags, small commits, rollback paths, and observability instead of stopping.
- Preserve user work: inspect `git status` before edits/commits, avoid unrelated changes, and never commit secrets or generated junk.

## Work Loop

1. Read the plan/progress and inspect current repo state.
2. Pick the next incomplete or unblocked checklist item.
3. Implement the smallest stable logical chunk.
4. Run focused tests/checks; run broader lint/typecheck/build checks when relevant.
5. If checks pass and commits are requested, commit only intended changes.
6. Update `AGENT_PROGRESS.md` and any source plan.
7. Continue immediately until the plan is done or truly blocked.

## Allowed Early Stops

Stop before completion only for a real blocker:

- missing credentials or external service access,
- destructive production/data risk or ambiguous destructive decision,
- external outage,
- impossible requirement,
- safety/security/legal concern.

When blocked, write the exact blocker, evidence, files touched, and the next command or decision needed into `AGENT_PROGRESS.md`, then report it.

## Completion Criteria

Stop only when all applicable criteria are satisfied:

- Full requested plan is implemented.
- All checklist items are complete or explicitly marked blocked with evidence.
- Tests/lint/typecheck pass, or failures are documented as unrelated existing failures.
- No TODO/stub/placeholder introduced for this plan remains.
- Progress file is updated with final state.
- Requested commits are created, or commit inability is documented with evidence such as “not a git repo”.
- Final answer includes commits made, files changed, tests run, and remaining risks.

## Commit Guidance

When commits are requested:

```bash
git status --short
git diff
# stage only intended files
git add <files>
git commit -m "<concise conventional-ish message>"
```

The commit is a checkpoint, not a stopping condition.
