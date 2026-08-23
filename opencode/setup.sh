#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
POLICY="${AGENT_MEMORY_ROOT:-$HOME/agent-memory}/shared/cto-workflow.md"

[[ -f "$HERE/opencode.json" ]] || { echo "missing $HERE/opencode.json" >&2; exit 1; }
[[ -f "$POLICY" ]] || { echo "missing $POLICY" >&2; exit 1; }
mkdir -p "$TARGET"

cp "$HERE/opencode.json" "$TARGET/opencode.json.tmp"
mv "$TARGET/opencode.json.tmp" "$TARGET/opencode.json"

echo "OpenCode CTO workflow installed"
echo "  config: $TARGET/opencode.json"
echo "Open a new OpenCode session to load the routing changes."
