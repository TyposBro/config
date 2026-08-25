#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${PI_CODING_AGENT_DIR:-$HOME/.omp/agent}"
MEMORY="${AGENT_MEMORY_ROOT:-$HOME/agent-memory}"
POLICY="$MEMORY/shared/cto-workflow.md"

[[ -f "$HERE/agent/config.yml" ]] || { echo "missing $HERE/agent/config.yml" >&2; exit 1; }
[[ -f "$POLICY" ]] || { echo "missing $POLICY" >&2; exit 1; }
mkdir -p "$TARGET"

cp "$HERE/agent/config.yml" "$TARGET/config.yml.tmp"
mv "$TARGET/config.yml.tmp" "$TARGET/config.yml"
for asset in agents commands hooks themes; do
  [[ -d "$HERE/agent/$asset" ]] || continue
  mkdir -p "$TARGET/$asset"
  cp "$HERE/agent/$asset/"* "$TARGET/$asset/"
done


link_policy() {
  local target="$1"
  if [[ -L "$target" && "$(readlink "$target")" == "$POLICY" ]]; then
    return
  fi
  if [[ -e "$target" || -L "$target" ]]; then
    mv "$target" "$target.bak.$(date +%Y%m%d-%H%M%S)"
  fi
  ln -s "$POLICY" "$target"
}

link_policy "$TARGET/APPEND_SYSTEM.md"

echo "OMP CTO workflow installed"
echo "  config: $TARGET/config.yml"
echo "  policy: $TARGET/APPEND_SYSTEM.md -> $POLICY"
echo "Open a new OMP session to load the routing changes."
