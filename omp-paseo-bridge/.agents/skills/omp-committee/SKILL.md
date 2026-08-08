---
name: omp-committee
description: Form a committee of two high-reasoning agents for root-cause analysis or planning, then synthesize. Use when the user says "/omp-committee", "get a second opinion on this plan", or when stuck, looping, or facing a hard design decision.
user-invocable: true
---

Convene a committee when the problem is hard enough that one pass is likely to miss something:

1. **Brief the committee.** Write a shared briefing: the question, what has been tried, constraints, and any evidence gathered so far. Put it in a `local://` file the members can read.
2. **Spell out the goal.** The first member is instructed to produce a plan or root-cause analysis with assumptions stated. The second member is instructed to find flaws in that analysis and propose alternatives. Both are analysis-only: no file edits, no shell mutations.
3. **Synthesize.** Merge both outputs into a single recommendation: the plan, its stated assumptions, the flaws found, and which alternative (if any) wins. Mark anything unresolved.
4. **Implement only on approval.** Present the recommendation, then wait for explicit user approval before touching files.

If the question is simple enough that a committee is theater, say so and answer directly instead.
