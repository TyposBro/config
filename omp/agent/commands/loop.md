---
description: Run a GPT control-plane task with DeepSeek V4 Pro as advisory sidecar.
---

Run this task through the model delegation loop:

<task>
$ARGUMENTS
</task>

Use GPT as the control-plane. Use DeepSeek only through the `deepseek-advisor` task agent.

Decision policy:
- GPT owns: safety-critical choices, code edits, data migrations, auth/session/payment logic, secrets, destructive operations, final verification, and final user response.
- DeepSeek advises on: architecture, UI/product judgment, refactor strategy, debugging hypotheses, naming/API shape, alternative plans, and "what am I missing?" checks.

Loop:
1. Scope the task and inspect the repo/docs enough to avoid guessing.
2. Before asking the human for a creative/open-ended decision, spawn `deepseek-advisor` with one bounded question.
3. Treat DeepSeek's response as advisory. Verify factual claims with tools before acting.
4. Execute the selected path with GPT. Do not let DeepSeek mutate files or make final safety-critical calls.
5. Run the relevant verification for changed behavior before yielding.

Use this task-tool shape when a sidecar decision is needed:

```text
agent: deepseek-advisor
context:
# Goal
Use DeepSeek V4 Pro as read-only sidecar for this decision.
# Constraints
No edits. No commands. No final safety-critical decisions. Ground claims in files/sources. GPT owns execution and verification.
# Contract
Return Recommendation, Why, Assumptions, Risks, Checks.

tasks:
- role: DeepSeek sidecar specialist for <decision type>
  assignment: |
    # Target
    <exact files/symbols/decision; explicit non-goals>
    # Change
    <question to answer; options to compare; evidence already observed>
    # Acceptance
    Return one recommended path, tradeoffs, assumptions, risks, and checks. No edits. No commands.
```
