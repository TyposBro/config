#!/usr/bin/env bash
set -uo pipefail

# Verifies the omp <-> Paseo bridge: binaries, config, installed skills.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASEO_HOME_DIR="${PASEO_HOME:-$HOME/.paseo}"
SKILLS_DIR="${SKILLS_DIR:-$HOME/.agents/skills}"
CONFIG="$PASEO_HOME_DIR/config.json"

ok=0; fail=0
pass() { echo "  ok:   $1"; ok=$((ok + 1)); }
bad()  { echo "  FAIL: $1"; fail=$((fail + 1)); }

echo "== omp =="
if command -v omp >/dev/null 2>&1; then
  v="$(omp --version 2>/dev/null || echo '?')"
  pass "omp on PATH ($v)"
else
  bad "omp not on PATH"
fi

echo "== paseo =="
if command -v paseo >/dev/null 2>&1; then
  v="$(paseo --version 2>/dev/null || echo '?')"
  pass "paseo on PATH ($v)"
else
  bad "paseo CLI not on PATH (desktop app bundles its own daemon; CLI is optional)"
fi

echo "== config ($CONFIG) =="
if [[ -f "$CONFIG" ]]; then pass "config exists"; else bad "config missing"; fi
jq -e '.agents.providers.omp.enabled == true' "$CONFIG" >/dev/null 2>&1 \
  && pass "omp provider enabled" || bad "omp provider not enabled"
jq -e '.agents.providers["omp-main"] != null' "$CONFIG" >/dev/null 2>&1 \
  && pass "omp-main profile present" || bad "omp-main profile missing"

echo "== skills =="
for dir in "$HERE"/.agents/skills/*/; do
  name="$(basename "$dir")"
  if [[ -f "$SKILLS_DIR/$name/SKILL.md" ]]; then
    pass "skill $name installed"
  else
    bad "skill $name missing"
  fi
done

echo
echo "result: $ok ok, $fail failed"
if [[ $fail -gt 0 ]]; then
  echo "hint: re-run ./install.sh; restart Paseo; then: paseo provider ls"
  exit 1
fi
echo "hint: if providers are not listed yet, restart Paseo, then: paseo provider ls"
