#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASEO_HOME="${PASEO_HOME:-$HOME/.paseo}"
TARGET="$PASEO_HOME/config.json"
SOURCE="$HERE/providers.json"

command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 1; }
[[ -f "$SOURCE" ]] || { echo "missing $SOURCE" >&2; exit 1; }
mkdir -p "$PASEO_HOME"

base="$(mktemp)"
out="$(mktemp)"
trap 'rm -f "$base" "$out"' EXIT

if [[ -f "$TARGET" ]]; then
  jq empty "$TARGET" || { echo "invalid JSON: $TARGET" >&2; exit 1; }
  cp "$TARGET" "$base"
  cp "$TARGET" "$TARGET.bak.$(date +%Y%m%d-%H%M%S)"
else
  printf '{}\n' >"$base"
fi

jq -s '.[0] * .[1]' "$base" "$SOURCE" >"$out"
mv "$out" "$TARGET"

echo "Paseo CTO providers installed: $TARGET"
echo "The daemon is not started or restarted by this script."
echo "Paseo hot-reloads valid config changes; restart the daemon only if provider discovery is stale."
