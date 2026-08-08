---
name: omp-review
description: Run an omp-style parallel code review with a P0-P3 verdict. Use when the user says "/omp-review", "review the diff", "review this PR", or asks for a prioritized ship/no-ship call.
user-invocable: true
---

Review the working tree, a named branch, or a commit the way omp's `/review` does:

1. **Scope the surface.** Determine what changed: `git diff` against base for uncommitted work, or `branch...base` / a single commit for pushed work. Include only real changes — exclude lock files and generated output from the analysis.
2. **Fan out parallel reviewers.** Spawn one reviewer subagent per distinct area (e.g. auth, data layer, UI) with the `task` tool. Each reviewer MUST:
   - Read the actual diff and surrounding code, not just the diff text.
   - Return findings ranked P0 (blocks release) through P3 (nit), each with file/line and a one-line justification.
   - Report a confidence score per finding; never pad with style nits dressed as bugs.
3. **Synthesize.** Merge the findings, dedupe, and produce a verdict: `SHIP` / `SHIP WITH FIXES` / `BLOCKED`, with P0/P1 items listed first and exactly one sentence each.
4. **No edits.** This is analysis only. Apply fixes only after the user approves.

Keep the final verdict under 30 lines.
