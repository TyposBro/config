---
name: omp-subagents
description: Fan work out to parallel subagents with typed results. Use when the user says "/omp-subagents", "parallelize", "fan out", "split this across agents", or hands you several independent slices of work.
user-invocable: true
---

Run parallel subagents the way omp's `task` tool is designed to be used:

1. **Scope before you spawn.** Read the request, map the work, and name the independent slices yourself. State the cross-slice contracts (formats, schemas, interfaces) in the batch `context` — subagents start blank and never see this conversation.
2. **Batch the fan-out.** Put every slice in one `tasks[]` array. Never serialize slices that can run concurrently; never invent slices to look parallel.
3. **Isolate.** Use worktree isolation for slices that touch the same files; overlap is safe when slices are contract-separated.
4. **Demand typed results.** Give each task an `outputSchema` so the final yield is a schema-validated object you read directly — no prose to parse.
5. **Verify, don't trust.** A `completed` job means the subagent yielded, not that its work is correct. Spot-check artifacts before integrating.
6. **Coordinate through `hub`** when slices need to hand each other data — wire the dependency explicitly, don't leave it implicit.
7. **Synthesize** the results into the final answer with a per-slice status line and what remains unverified.

Concurrency cap: at most 32 subagents run at once; a larger batch just queues, so keep fan-out at or under the cap.
