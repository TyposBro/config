#!/usr/bin/env bash
set -euo pipefail

# omp <-> Paseo bridge installer (idempotent).
#   1. Enables Paseo's built-in OMP provider + omp-main profile in $PASEO_HOME/config.json
#      (deep merge, backup first, nothing else touched).
#   2. Injects machine-specific provider env so Paseo's spawned agents see the same
#      auth/config your interactive shell sees:
#        - omp:      PI_CONFIG_DIR (your shell's omp data dir override)
#        - opencode: symlinks ~/.opencode/bin/opencode onto the daemon PATH
#        - codex-go: DeepSeek V4 Flash via OpenCode Go (key read from env or
#                    ~/agent-memory/hermes/.env — never stored in this repo)
#   3. Installs the omp-* bridge skills into ~/.agents/skills.
# Optional: --with-paseo-skills also installs getpaseo/paseo orchestration skills.
#
# Reproducible: re-running is a no-op that just re-copies files and re-merges config.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASEO_HOME_DIR="${PASEO_HOME:-$HOME/.paseo}"
SKILLS_DIR="${SKILLS_DIR:-$HOME/.agents/skills}"
CONFIG="$PASEO_HOME_DIR/config.json"
FRAGMENT="$HERE/config/omp-provider.json"
SKILLS_SRC="$HERE/.agents/skills"
WITH_PASEO_SKILLS=0

for arg in "$@"; do
  case "$arg" in
    --with-paseo-skills) WITH_PASEO_SKILLS=1 ;;
    *) echo "unknown arg: $arg"; exit 2 ;;
  esac
done

command -v jq >/dev/null || { echo "error: jq is required (apt install jq / brew install jq)"; exit 1; }
command -v omp >/dev/null || echo "warning: omp not on PATH — install: curl -fsSL https://omp.sh/install | sh"
command -v paseo >/dev/null || echo "warning: paseo CLI not on PATH — install: npm install -g @getpaseo/cli (desktop app bundles its own daemon)"

mkdir -p "$PASEO_HOME_DIR" "$SKILLS_DIR"

# ---- dynamic provider env (machine-specific values injected at install time) ----
DYN="$(mktemp)"
jq -n '{agents:{providers:{}}}' > "$DYN"

# 1. omp: inherit the same data dir your shell uses, so Paseo's spawned omp sees the
#    same auth (opencode-go, codex, google-antigravity, ...).
if [[ -n "${PI_CONFIG_DIR:-}" ]]; then
  jq --arg d "$PI_CONFIG_DIR" '.agents.providers.omp = {env:{PI_CONFIG_DIR:$d}}' "$DYN" > "$DYN.tmp" && mv "$DYN.tmp" "$DYN"
  echo "env: omp PI_CONFIG_DIR=$PI_CONFIG_DIR (inherited from your shell)"
else
  echo "warning: PI_CONFIG_DIR not set in this shell — omp in Paseo will use its default dir (~/.omp)."
  echo "         export PI_CONFIG_DIR=<dir> (e.g. config/omp) and re-run to inherit."
fi

# 1b. omp sessionDir: import-only path for terminal sessions, resolved from the real
#     omp data root (PI_CONFIG_DIR, else default ~/.omp) so the same kit works on
#     machines with a redirected omp home (Linux) and default layouts (macOS).
if [[ -n "${PI_CONFIG_DIR:-}" ]]; then
  case "$PI_CONFIG_DIR" in
    /*) OMP_ROOT="$PI_CONFIG_DIR" ;;
    *)  OMP_ROOT="$HOME/$PI_CONFIG_DIR" ;;
  esac
else
  OMP_ROOT="$HOME/.omp"
fi
SESSION_DIR="~${OMP_ROOT#$HOME}/agent/sessions"
jq --arg s "$SESSION_DIR" \
   '.agents.providers.omp.params.sessionDir = $s | .agents.providers["omp-main"].params.sessionDir = $s' \
   "$DYN" > "$DYN.tmp" && mv "$DYN.tmp" "$DYN"
echo "env: omp sessionDir=$SESSION_DIR"

# 2. opencode: binary lives in ~/.opencode/bin, which is not on the Paseo daemon PATH.
if [[ -x "$HOME/.opencode/bin/opencode" ]]; then
  mkdir -p "$HOME/.local/bin"
  ln -sf "$HOME/.opencode/bin/opencode" "$HOME/.local/bin/opencode"
  echo "env: symlinked ~/.opencode/bin/opencode -> ~/.local/bin/opencode (on daemon PATH)"
else
  echo "warning: opencode binary not found at ~/.opencode/bin/opencode"
fi

# 3. codex-go: DeepSeek V4 Flash via OpenCode Go (Paseo's documented endpoint override).
#    Key is read at install time from the environment or ~/agent-memory/hermes/.env
#    (gitignored) — it never lands in this repo.
KEY=""
if [[ -n "${OPENCODE_GO_API_KEY:-}" ]]; then
  KEY="$OPENCODE_GO_API_KEY"
elif [[ -f "$HOME/agent-memory/hermes/.env" ]]; then
  KEY="$(grep '^OPENCODE_GO_API_KEY=' "$HOME/agent-memory/hermes/.env" 2>/dev/null | head -1 | cut -d= -f2- || true)"
fi
if [[ -n "$KEY" ]]; then
  jq --arg k "$KEY" \
     '.agents.providers["codex-go"] = {extends:"codex", label:"Codex (OpenCode Go)", env:{OPENAI_BASE_URL:"https://opencode.ai/zen/go/v1", OPENAI_API_KEY:$k}, models:[{id:"deepseek-v4-flash", label:"DeepSeek V4 Flash (Go)", isDefault:true}]}' \
     "$DYN" > "$DYN.tmp" && mv "$DYN.tmp" "$DYN"
  echo "env: codex-go profile (DeepSeek V4 Flash via OpenCode Go)"
else
  echo "warning: OPENCODE_GO_API_KEY not found (env or ~/agent-memory/hermes/.env) — skipping codex-go profile"
fi

# ---- merge: existing config * static fragment * dynamic env ----
if [[ -f "$CONFIG" ]]; then
  cp "$CONFIG" "$CONFIG.bak.$(date +%Y%m%d-%H%M%S)"
  jq -s '.[0] * .[1] * .[2]' "$CONFIG" "$FRAGMENT" "$DYN" > "$CONFIG.tmp"
else
  jq -s '.[0] * .[1]' "$FRAGMENT" "$DYN" > "$CONFIG.tmp"
fi
mv "$CONFIG.tmp" "$CONFIG"
rm -f "$DYN"
echo "config: $CONFIG updated (backup written)"

# ---- bridge skills ----
count=0
for dir in "$SKILLS_SRC"/*/; do
  name="$(basename "$dir")"
  mkdir -p "$SKILLS_DIR/$name"
  cp -f "$dir/SKILL.md" "$SKILLS_DIR/$name/SKILL.md"
  echo "skill: $name"
  count=$((count + 1))
done
echo "installed $count skills into $SKILLS_DIR"

# ---- optional: Paseo orchestration skills ----
if [[ $WITH_PASEO_SKILLS -eq 1 ]]; then
  if command -v npx >/dev/null 2>&1; then
    echo "installing Paseo orchestration skills (getpaseo/paseo)..."
    npx -y skills add getpaseo/paseo \
      || echo "warning: 'npx skills add getpaseo/paseo' failed — use Settings -> Integrations -> Install"
  else
    echo "warning: npx not found; skipped Paseo skills (use Settings -> Integrations -> Install)"
  fi
fi

cat <<'EOF'

Done. Next:
  1. Restart Paseo — systemd: systemctl --user restart paseo.service (desktop: quit & relaunch; CLI: paseo daemon restart)
  2. paseo provider ls          # expect omp + codex available, opencode available
  3. paseo provider models omp  # expect opencode-go / codex / antigravity / deepseek
  4. In the composer type '/'  # omp-review, omp-vibe, ... autocomplete
EOF
