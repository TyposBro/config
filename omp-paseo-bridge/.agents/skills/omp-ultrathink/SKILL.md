---
name: omp-ultrathink
description: Take a turn with maximal care — multi-step reasoning, assumptions stated, alternatives weighed, then verify. Use when the user says "/omp-ultrathink", "think hard about this", "ultrathink", or the problem is subtle and one pass is not enough.
user-invocable: true
---

Spend the reasoning budget this turn deserves:

1. **Restate the problem** in your own words, including what success looks like and what "done" means.
2. **State assumptions** explicitly, especially the ones that would invalidate the answer if wrong. Mark them as assumptions, not facts.
3. **Generate alternatives before committing.** For each candidate approach: what breaks, what it costs, what it buys. Weigh them in one short table.
4. **Reason multi-step.** Trace the full path from change to observable effect, including edge cases and failure modes — not just the happy path.
5. **Choose and justify** the winner in one or two sentences tied to the evidence, not to familiarity.
6. **Verify the outcome** with the specific check that would catch a wrong answer (run it, not a proxy). If verification is impossible from here, say exactly what is unverified.

Do not use this skill for routine turns — it is for the turns where a cheap answer would be a bad answer.
