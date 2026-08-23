---
description: Reconcile, deliver, independently review, and hand off one GitHub epic or bounded issue
---
Load and follow the installed `epic` skill as the canonical workflow.

Target: $1
Requested mode: $2
Frozen review SHA: $3

Pass the arguments through without adding OMP-specific agent names, model requirements, provider requirements, command paths, lock namespaces, or task APIs. Map the skill's control-plane, implementer, reviewer, and optional advisor roles to capabilities available in this session.

OMP's `task`, `hub`, isolated workspaces, and configured agents are adapters that may satisfy those roles; they are not workflow invariants. Select workers by capability and risk according to the skill.

If the installed skill or a required capability is unavailable, report the exact missing prerequisite as `BLOCKED`. Do not fall back to the superseded harness-specific workflow.
