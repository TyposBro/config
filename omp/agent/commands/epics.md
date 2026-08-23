---
description: Reconcile and deliver several GitHub epics through bounded capability-based lanes
---
Load and follow the installed `epics` skill as the canonical portfolio workflow.

Targets:

$ARGUMENTS

Pass the targets through without adding OMP-specific agent names, model requirements, provider requirements, command paths, lock namespaces, or task APIs. The `epics` skill composes the installed `epic` contract and maps control-plane, implementer, reviewer, and optional advisor roles by capability.

OMP's `task`, `hub`, isolated workspaces, and configured agents are adapters that may satisfy those roles; they are not durable workflow invariants.

If either installed skill or a required capability is unavailable, mark only the affected lane `BLOCKED` when safe; block the portfolio only when the missing prerequisite affects every lane. Do not fall back to the superseded harness-specific workflow.
