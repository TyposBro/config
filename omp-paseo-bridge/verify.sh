#!/usr/bin/env bash
set -uo pipefail

# Verifies the omp <-> Paseo bridge: binaries, config, injected env, installed skills.
# Checks whose preconditions are absent (no key source, no opencode binary) are skipped
# so the same script works on machines with different setups (Linux vs macOS).

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASEO_HOME_DIR="${PASEO_HOME:-$HOME/.paseo}"
SKILLS_DIR="${SKILLS_DIR:-$HOME/.agents/skills}"
CONFIG="$PASEO_HOME_DIR/config.json"

ok=0; fail=0; skip=0
pass() { echo "  ok:   $1"; ok=$((ok + 1)); }
bad()  { echo "  FAIL: $1"; fail=$((fail + 1)); }
skp()  { echo "  skip: $1"; skip=$((skip + 1)); }

echo "== binaries =="
for c in omp paseo codex; do
  if command -v "$c" >/dev/null 2>&1; then
    pass "$c on PATH ($(command -v "$c"))"
  else
    bad "$c not on PATH"
  fi
done
if command -v opencode >/dev/null 2>&1; then
  pass "opencode on PATH ($(command -v opencode))"
elif [[ -x "$HOME/.opencode/bin/opencode" ]]; then
  bad "opencode exists at ~/.opencode/bin but not on PATH (run ./install.sh)"
else
  skp "opencode (binary not installed on this machine)"
fi

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
  skp "omp PI_CONFIG_DIR (not set in this shell — omp uses its default dir)"
fi

if [[ -n "${PI_CONFIG_DIR:-}" ]]; then
  case "$PI_CONFIG_DIR" in
    /*) OMP_ROOT="$PI_CONFIG_DIR" ;;
    *)  OMP_ROOT="$HOME/$PI_CONFIG_DIR" ;;
  esac
else
  OMP_ROOT="$HOME/.omp"
fi
EXPECT_SD="~${OMP_ROOT#$HOME}/agent/sessions"
jq -e --arg s "$EXPECT_SD" '.agents.providers.omp.params.sessionDir == $s' "$CONFIG" >/dev/null 2>&1 \
  && pass "omp sessionDir=$EXPECT_SD" || bad "omp sessionDir mismatch (want $EXPECT_SD)"

if [[ -n "${OPENCODE_GO_API_KEY:-}" ]] || [[ -f "$HOME/agent-memory/hermes/.env" ]]; then
  jq -e '.agents.providers["codex-go"] != null' "$CONFIG" >/dev/null 2>&1 \
    && pass "codex-go profile present" || bad "codex-go profile missing"
else
  skp "codex-go (no OPENCODE_GO_API_KEY source on this machine)"
fi

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
echo "result: $ok ok, $skip skipped, $fail failed"
if [[ $fail -gt 0 ]]; then
  echo "hint: re-run ./install.sh; restart Paseo; then: paseo provider ls"
  exit 1
fi
echo "hint: if providers are not listed yet, restart Paseo, then: paseo provider ls"
