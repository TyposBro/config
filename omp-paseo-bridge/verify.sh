#!/usr/bin/env bash
set -uo pipefail

# Verifies the omp <-> Paseo bridge: binaries, config, injected env, installed skills.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASEO_HOME_DIR="${PASEO_HOME:-$HOME/.paseo}"
SKILLS_DIR="${SKILLS_DIR:-$HOME/.agents/skills}"
CONFIG="$PASEO_HOME_DIR/config.json"

ok=0; fail=0
pass() { echo "  ok:   $1"; ok=$((ok + 1)); }
bad()  { echo "  FAIL: $1"; fail=$((fail + 1)); }

echo "== binaries =="
for c in omp paseo codex opencode; do
  if command -v "$c" >/dev/null 2>&1; then
    pass "$c on PATH ($(command -v "$c"))"
  else
    bad "$c not on PATH"
  fi
done

echo "== config ($CONFIG) =="
if [[ -f "$CONFIG" ]]; then pass "config exists"; else bad "config missing"; fi
jq -e '.agents.providers.omp.enabled == true' "$CONFIG" >/dev/null 2>&1 \
  && pass "omp provider enabled" || bad "omp provider not enabled"
jq -e '.agents.providers["omp-main"] != null' "$CONFIG" >/dev/null 2>&1 \
  && pass "omp-main profile present" || bad "omp-main profile missing"
if [[ -n "${PI_CONFIG_DIR:-}" ]]; then
  jq -e --arg d "$PI_CONFIG_DIR" '.agents.providers.omp.env.PI_CONFIG_DIR == $d' "$CONFIG" >/dev/null 2>&1 \
    && pass "omp inherits PI_CONFIG_DIR=$PI_CONFIG_DIR" || bad "omp PI_CONFIG_DIR env missing"
else
  echo "  skip: PI_CONFIG_DIR not set in this shell (omp uses its default dir)"
fi
if [[ -L "$HOME/.local/bin/opencode" ]] \
  && [[ "$(readlink "$HOME/.local/bin/opencode")" == "$HOME/.opencode/bin/opencode" ]]; then
  pass "opencode symlink on daemon PATH"
else
  bad "opencode symlink missing (run ./install.sh)"
fi
jq -e '.agents.providers["codex-go"] != null' "$CONFIG" >/dev/null 2>&1 \
  && pass "codex-go profile present" || bad "codex-go profile missing"

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
