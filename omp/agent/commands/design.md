---
description: Explore UI or product direction with Claude
---

Use an explicit `designer` task item with `isolated: true` to analyze this request without writing delivered code. Block if a repository-local OMP override changes the managed designer model or read-only tools.

Require one clear recommendation grounded in the existing product, design system, and user flow—not a generic collection of options. Do not implement until the direction is concrete. Delegate every resulting code and test edit exclusively to explicit `deepseek-fast` task items with `isolated: true`, then have Sol visually verify the result. For every meaningful delivered change, freeze an exact pushed SHA and run the required isolated `sol-reviewer` plus `deepseek-pro` panel and collaboration round before the final claim.

Request:

$ARGUMENTS
