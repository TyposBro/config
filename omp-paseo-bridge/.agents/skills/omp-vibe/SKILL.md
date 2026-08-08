---
name: omp-vibe
description: Run omp's Vibe mode — act as a director driving fast/good worker sessions with a read-only toolset. Use when the user says "/omp-vibe", "direct this", or wants you to orchestrate workers instead of doing the work yourself.
user-invocable: true
---

Act as a director, not a doer. This mirrors omp's Vibe mode:

1. **Decompose** the goal into independent slices; name each slice and its acceptance criteria.
2. **Dispatch workers** with the `task` tool — one worker per slice. Workers do the implementation; you stay read-only.
3. **Review between phases.** When a worker yields, read its output (`agent://<id>` or the artifact it produced), verify against the slice's acceptance criteria, and either accept, send a steering correction, or re-dispatch.
4. **Reconcile** the results into a coherent whole: resolve cross-slice seams yourself (imports, contracts, config), then run a final verification pass on the integrated result.
5. **Report** a per-slice status table: done / needs review / blocked, plus what you verified and what you did not.

Constraints: you do not edit files while workers are active; if a slice is small enough that a worker is overhead, do it inline and say so. Never merge or push without explicit user approval.
