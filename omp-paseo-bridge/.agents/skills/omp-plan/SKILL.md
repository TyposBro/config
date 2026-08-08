---
name: omp-plan
description: Plan before you build — recon, present a plan, get approval, then implement and verify. Use when the user says "/omp-plan", "plan this", "think before you act", or the work is multi-step with real blast radius.
user-invocable: true
---

Run the plan-then-execute loop:

1. **Recon (read-only).** Map the affected surface before proposing anything: read the relevant files, check callers of anything you would change, note existing conventions. Never propose against code you have not read.
2. **Present the plan.** Phases, files touched, interfaces changed, and how each phase will be verified (command or check per phase). Include risks and what you will NOT touch. Keep it scannable.
3. **Wait for approval.** Do not edit until the user approves. If the plan is ambiguous, ask the narrowest question that resolves it.
4. **Implement phase by phase.** Verify each phase with its stated check before starting the next. If reality diverges from the plan, say so and re-plan the remainder instead of silently improvising.
5. **Final verification.** Run the end-to-end check that proves the deliverable works, not just that it compiles. Report what was verified and what was not.

The plan is a contract: deviations are reported, not hidden. If the task turns out trivial, say "this is smaller than a plan — doing it directly" and proceed.
