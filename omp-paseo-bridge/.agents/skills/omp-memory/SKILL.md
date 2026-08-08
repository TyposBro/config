---
name: omp-memory
description: Use omp's agent-curated memory tools. Use when the user says "/omp-memory", "remember this", "recall what we did", "store that lesson", or asks about project history across sessions.
user-invocable: true
---

Use omp's memory toolkit deliberately, not reflexively:

- **`retain`** — queue a durable fact into the active memory bank: decisions, architecture facts, environment quirks, ownership. Store facts the *next session* would need; do NOT store trivia, one-off commands, or anything recoverable from code.
- **`recall`** — search the bank for raw memories when the user asks about past work or before re-deciding something previously decided.
- **`reflect`** — synthesize an answer over the bank when the question needs judgment across multiple memories, not a lookup.
- **`learn`** — capture a reusable lesson after a painful or subtle fix; it is eligible for promotion into a managed skill.
- **`memory_edit`** — update, forget, or invalidate stored memories by id when they are superseded or wrong.

Discipline:
1. Before storing, ask: "would this survive a code read?" If yes, don't store it.
2. Tag or scope by project; the bank is project-scoped by default, so keep repo-specific facts in the repo's scope.
3. When the user says "forget X" or a memory is contradicted, invalidate it — never leave stale facts to fight the new ones.
4. If the memory backend is not configured, say so and note what to enable (`memory.backend` in omp config) instead of silently no-op'ing.
