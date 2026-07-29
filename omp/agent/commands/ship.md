---
description: Let Sol orchestrate production-grade delivery with Flash as the sole code writer
---

Own scope, architecture, sequencing, integration decisions, and final verification in the current Sol session. Do not write application code directly.

Research existing conventions and affected callsites, then delegate every implementation, test, migration, integration, conflict-resolution, and remediation edit to `deepseek-fast`. Decompose complex work into bounded Flash tasks rather than switching models. Exercise the changed behavior and run targeted verification. For meaningful changes, freeze the SHA and launch fresh `sol-reviewer` and `deepseek-pro` sessions independently; request one narrow `opus-reviewer` opinion only for high-risk surfaces, reviewer disagreement, supported P0/P1/P2 findings, or explicit user request. Freeze initial verdicts before one `hub` collaboration round. Any fixes return exclusively to Flash.

Task:

$ARGUMENTS
