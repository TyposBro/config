# Global Pi Agent Rules

## Response Formatting Preferences

- Do not wrap simple file paths, branch names, commit hashes, or short inline commands in fenced code blocks.
- Use inline code for paths/identifiers, for example `apps/example/file.md`.
- Use fenced code blocks only for multi-line snippets, copy-paste commands, SQL, JSON, diffs, logs, or code where formatting matters.
- When using fenced code blocks, use the actual language (`bash`, `sql`, `json`, etc.) and avoid `txt` fences for simple lists.

## External Rule Files

- Spiko clean architecture/code-quality rules live at `~/Documents/private/spiko/rules.md`.
- When the user says "follow the rules", "use the rules", references `rules.md`, or asks for Spiko/code-quality enforcement, read that file completely before editing or reviewing.
- In Spiko-related repos, treat those rules as the default architecture/code-quality rules unless repo-local instructions explicitly conflict.
- In Pi, `/skill:spiko-rules` can force-load the same workflow.

## Autonomous End-to-End Implementation Protocol

Use this protocol whenever the user asks to implement, debug, fix, refactor, migrate, continue a multi-step task, finish a checklist/TODO/roadmap, or explicitly requests autonomy such as “execute, don’t instruct”, “do not stop”, “commit and continue”, or “finish end-to-end”.

### Autonomy Rules

- Execute, don't instruct: inspect the repo, choose the safest reasonable implementation, edit code/config/docs, run checks, and continue.
- Do not stop at checkpoints, milestones, or “safe boundaries”; treat them as verify/commit/progress-update points and immediately continue.
- If commits are requested and a git repo exists, commit each stable logical chunk after relevant checks pass, then immediately continue.
- Ask the user only for a real blocker: missing credentials or external service access, destructive production/data risk, external outage, impossible requirement, or safety/security/legal concern.
- If uncertain, inspect code, tests, docs, and history; choose the safest reasonable path without asking.
- Manage risk with focused tests, feature flags, small commits, rollback paths, and observability instead of stopping.
- Preserve user work: inspect `git status` before edits/commits, do not overwrite unrelated changes, and do not commit secrets, generated junk, or unrelated files.

### Progress Tracking

- For non-trivial autonomous work, create or update `AGENT_PROGRESS.md` in the target repo/workspace unless the user specifies another durable progress file.
- Track checklist, completed work, remaining work, tests run, commits, blockers, and the exact next action.
- If context gets large, update `AGENT_PROGRESS.md` with current state and continue.
- Keep any existing plan file (`IMPLEMENTATION_PLAN.md`, `PLAN.md`, `TODO.md`, issue notes, etc.) in sync when it is the source of truth.

### Work Loop

1. Read current progress/plan and inspect repo state.
2. Pick the next incomplete or unblocked item.
3. Implement the smallest stable logical chunk.
4. Run focused tests/checks; run broader lint/typecheck/build checks when relevant.
5. Commit the intended changes if commits are requested and checks are green.
6. Update `AGENT_PROGRESS.md` and any source plan.
7. Continue until the completion criteria are satisfied or a real blocker is documented.

### Completion Criteria

Stop only when all are true, unless explicitly blocked:

- Full requested plan is implemented.
- All checklist items are complete or explicitly marked blocked with evidence.
- Tests/lint/typecheck pass, or failures are documented as unrelated existing failures.
- No TODO/stub/placeholder introduced for this plan remains.
- Progress file is updated with final state.
- Requested commits are created, or commit inability is documented with evidence (for example, target directory is not a git repo).
- Final response includes commits made, files changed, tests run, and remaining risks.
