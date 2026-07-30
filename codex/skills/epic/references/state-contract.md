# Epic State Contract

## Contents

- Safety boundary
- Lease protocol
- Durable checkpoint
- Child states
- Evidence and review invariants
- Dirty-worktree recovery

## Safety boundary

The initiating request authorizes work inside the named epic: read Git/GitHub state, create or update issue branches and draft PRs, run local validation, push non-default branches, and update the epic's existing workflow checkpoint.

It does not implicitly authorize merging, deploying, publishing, mutating production, changing pricing, manually closing issues, deleting branches/worktrees, or overwriting existing work.

## Lease protocol

Resolve the shared Git directory:

```bash
git rev-parse --path-format=absolute --git-common-dir
```

Store locks under `<git-common-dir>/codex-epic-locks/`. Use `scripts/epic-lock.sh` for `acquire`, `verify`, `heartbeat`, and `release`.

Use keys:

- Epic: `<owner>-<repository>-<issue>`
- Portfolio: `portfolio-<stable-id>`
- Writer: `<epic-key>-writer-<issue-or-branch>`
- Review: `<epic-key>-review-<sha>`

After acquiring a lock, preserve its returned fencing token. Validate every applicable portfolio/epic/node token immediately before commit, push, PR mutation, checkpoint mutation, project-field mutation, or branch-changing action.

The main wait loop must heartbeat every active lock at least once per third of the lease TTL. On ownership loss, interrupt affected agents, record `blocked`, and perform no further mutation for that node.

Release only after the result and current SHA are durably checkpointed.

## Durable checkpoint

Keep one updatable GitHub comment containing:

```markdown
<!-- codex-epic-flow:v1 -->
epic: <url>
phase: <reconcile|implement|integrate|review|remediate|final>
integration_sha: <sha-or-none>
children:
  - <issue> | <state> | <pr-or-none> | <head-sha-or-none>
review:
  sha: <sha-or-none>
  sol: <pass|changes_required|blocked|not_run>
  adversarial: <pass|changes_required|blocked|not_run>
  combined: <pass|changes_required|blocked|not_run>
remediation_cycles: <0-3>
unresolved_findings:
  - <finding-or-none>
external_blockers:
  - <blocker-or-none>
lease:
  owner: <token-or-none>
  expires_at: <unix-seconds-or-none>
final_state: <BLOCKED|READY FOR OWNER QA|READY FOR STAGED RELEASE|in_progress>
updated_at: <ISO-8601>
```

Update this comment instead of appending phase spam. Git/GitHub live state overrides a stale checkpoint. Review evidence is valid only for its exact SHA.

## Child states

Use only:

- `not_started`
- `dirty_local_worktree`
- `branch_without_pr`
- `implementation_in_progress`
- `pr_waiting_for_ci`
- `ready_for_integration`
- `ready_for_review`
- `review_in_progress`
- `changes_required`
- `ready_for_owner_qa`
- `merged_done`
- `blocked`

## Evidence and review invariants

- Treat acceptance criteria and non-goals as the contract.
- Treat pushed commits and current PR metadata as authoritative over abandoned transcripts.
- Do not review a branch while a writer owns it.
- Freeze a pushed SHA before review.
- Require two fresh independent reviews of the same SHA.
- Preserve each initial opinion before cross-review discussion.
- Do not dismiss a reproduced defect by majority vote.
- Any supported P0/P1/P2 means `changes_required`.
- A new SHA requires a new review panel.
- Increment remediation count before dispatch so interruption cannot reset the cap.
- Maximum remediation/re-review cycles: three.
- Existing CI success cannot override contradictory source evidence or an unmet criterion.

## Dirty-worktree recovery

Never reset, clean, stash, delete, or overwrite a dirty worktree.

Record its path, branch, HEAD, tracked diff summary, and untracked inventory. If ownership is unambiguous, have a bounded writer reconstruct the work in an isolated workspace on the same issue branch, preserving the original worktree until recovered commits are pushed and verified. Ambiguous ownership is `blocked`.
