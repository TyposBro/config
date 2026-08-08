---
name: omp-advisor
description: Spawn a single advisor agent for an outside judgment without delegating the work. Use when the user says "/omp-advisor", "second opinion", "what does X think", or wants a review of a plan, diff, or approach.
user-invocable: true
---

Get a second opinion on the current task or proposal:

1. **Give the advisor everything it needs** — the plan, diff, or question, plus the relevant files it must read to judge (paths, not summaries). Keep it self-contained.
2. **Frame the ask** as a judgment call: risks, blind spots, simpler alternatives, or a specific question the user named.
3. **The advisor is analysis-only** — its prompt ends with a no-edits instruction. It runs on its own context, so it sees the question fresh.
4. **Report back** the advisor's judgment verbatim enough to be useful, then add your own take: where you agree, where you disagree and why, and what you will do differently.
5. **You decide.** The advisor gives a judgment; you do not implement anything the advisor says without the user's go-ahead.
