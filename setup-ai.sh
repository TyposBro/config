#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MEMORY="${AGENT_MEMORY_ROOT:-$HOME/agent-memory}"

[[ -f "$MEMORY/shared/cto-workflow.md" ]] || {
  echo "missing $MEMORY/shared/cto-workflow.md" >&2
  echo "Clone or restore ~/agent-memory before running this installer." >&2
  exit 1
}

bash "$ROOT/omp/setup.sh"
bash "$ROOT/pi/setup.sh"
bash "$ROOT/opencode/setup.sh"
bash "$ROOT/codex/setup.sh"
bash "$ROOT/paseo/setup-providers.sh"

echo "Shared Sol/Terra/Luna workflow installed for OMP, Pi, OpenCode, Codex CLI, and Paseo."
