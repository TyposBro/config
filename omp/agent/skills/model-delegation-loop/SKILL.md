---
name: model-delegation-loop
description: Use when a GPT control-plane agent should delegate creative/open-ended decisions to DeepSeek V4 Pro instead of stopping to ask the human.
---

# Model Delegation Loop

Use GPT as the control-plane and DeepSeek as a read-only sidecar.

## Loop

1. **Classify the next decision.**
   - GPT-only: prod deploys, data migrations, auth/session/payment logic, secrets, destructive operations, final verification, and all file mutations.
   - DeepSeek-advisory: architecture options, UI/product judgment, refactor strategy, debugging hypotheses, naming/API shape, "what am I missing?", and open-ended planning.
2. **If DeepSeek-advisory, spawn `deepseek-advisor`.**
   - Ask one bounded question.
   - Give exact target files/symbols and current evidence.
   - Require recommendation, risks, and checks.
3. **Synthesize; do not obey blindly.**
   - GPT chooses the final path.
   - Treat DeepSeek output as advice, not truth.
   - Verify any factual claim with tools before using it.
4. **Execute with GPT.**
   - GPT edits, runs checks, handles safety-critical branches, and owns the final answer.
5. **Stop only when the requested deliverable is complete and verified.**

## Spawn template

```text
agent: deepseek-advisor
context:
# Goal
Use DeepSeek V4 Pro as read-only creative sidecar for this decision.
# Constraints
Do not edit files. Do not run commands. Do not make final safety-critical decisions. Ground claims in files/sources. GPT control-plane owns final execution and verification.
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

## Human escalation remains required

Ask the human only when:
- required secrets/credentials/accounts are unavailable
- product intent is genuinely unknowable from context
- the action is destructive or irreversible
- legal/compliance/business-risk approval is needed
- DeepSeek and GPT disagree on a safety-critical path and tools cannot resolve it
