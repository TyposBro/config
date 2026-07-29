---
description: Let Sol orchestrate production-grade delivery with Flash as the sole code writer
---

Own scope, architecture, sequencing, integration decisions, and final verification in the current Sol session. Do not write application code directly.

Research existing conventions and affected callsites, validate that no repository-local OMP override changes the managed agent models or tools, then delegate every implementation, test, migration, integration, conflict-resolution, and remediation edit to explicit `deepseek-fast` task items with `isolated: true`. Block if isolation or the resolved managed route is unavailable. Decompose complex work into bounded Flash tasks rather than switching models. Exercise the changed behavior and run targeted verification. For meaningful changes, freeze an exact pushed SHA and launch fresh `sol-reviewer` and `deepseek-pro` task items independently with `isolated: true`; request one narrow `opus-reviewer` opinion only for high-risk surfaces, reviewer disagreement, supported P0/P1/P2 findings, or explicit user request. Freeze initial verdicts before one `hub` collaboration round. Any fixes return exclusively to isolated Flash.

Task:

$ARGUMENTS
