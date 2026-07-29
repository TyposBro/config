---
description: Execute a bounded task through DeepSeek Flash
---

Treat this as a fast, bounded, reversible iteration.

Delegate every code and test edit to `deepseek-fast`. Keep architecture, scope, and production-risk decisions in the Sol parent; no other model may patch the implementation. Inspect the result and exercise the changed path before reporting completion. If the bounded task is still a meaningful behavioral change, use fresh `sol-reviewer` and `deepseek-pro` sessions before the final claim; reserve Opus for the global high-risk/disagreement triggers.

Task:

$ARGUMENTS
