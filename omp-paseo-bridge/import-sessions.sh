#!/usr/bin/env bash
set -euo pipefail

# Import all existing omp terminal sessions into Paseo so you can continue them
# from the app. Idempotent: the daemon skips sessions that are already imported
# ("Provider session is already imported").
#
# Session dir resolution: providers.omp.params.sessionDir from ~/.paseo/config.json
#   > $PI_CONFIG_DIR (your shell's omp data root) > ~/.omp/agent/sessions.
# cwd for each session is read from the session JSONL itself.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASEO_HOME_DIR="${PASEO_HOME:-$HOME/.paseo}"
CONFIG="$PASEO_HOME_DIR/config.json"
PROVIDER="${PASEO_OMP_PROVIDER:-omp}"

SESSION_DIR="$(jq -r '.agents.providers.omp.params.sessionDir // empty' "$CONFIG" 2>/dev/null || true)"
if [[ -z "$SESSION_DIR" && -n "${PI_CONFIG_DIR:-}" ]]; then
  case "$PI_CONFIG_DIR" in
    /*) SESSION_DIR="$PI_CONFIG_DIR/agent/sessions" ;;
    *)  SESSION_DIR="$HOME/$PI_CONFIG_DIR/agent/sessions" ;;
  esac
fi
SESSION_DIR="${SESSION_DIR:-$HOME/.omp/agent/sessions}"
SESSION_DIR="${SESSION_DIR/#\~/$HOME}"

[[ -d "$SESSION_DIR" ]] || { echo "error: no session dir at $SESSION_DIR"; exit 1; }
command -v paseo >/dev/null || { echo "error: paseo CLI not on PATH"; exit 1; }

echo "session dir: $SESSION_DIR"
imported=0; skipped=0; failed=0

for f in "$SESSION_DIR"/*/*.jsonl; do
  [[ -f "$f" ]] || continue
  id="$(basename -- "$f" .jsonl | sed 's/.*_//')"
  cwd="$(jq -r 'select(.type == "session") | .cwd // empty' "$f" 2>/dev/null | head -1 || true)"
  if [[ -z "$cwd" ]]; then
    echo "skip $id: no cwd in session file"; skipped=$((skipped + 1)); continue
  fi
  echo "importing $id ($cwd)"
  if out="$(timeout 120 paseo agent import "$id" --provider "$PROVIDER" --cwd "$cwd" 2>&1)"; then
    imported=$((imported + 1))
  elif echo "$out" | grep -qi 'already imported'; then
    skipped=$((skipped + 1)); echo "  already imported"
  else
    failed=$((failed + 1)); echo "  FAILED: $(echo "$out" | head -2)"
  fi
done

echo "done: $imported imported, $skipped already imported/skipped, $failed failed"
[[ $failed -eq 0 ]] || exit 1
