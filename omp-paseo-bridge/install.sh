#!/usr/bin/env bash
set -euo pipefail

# omp <-> Paseo bridge installer (idempotent).
#   1. Enables Paseo's built-in OMP provider + omp-main profile in $PASEO_HOME/config.json
#      (deep merge, backup first, nothing else touched).
#   2. Installs the omp-* bridge skills into ~/.agents/skills.
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

# 1. Provider config: deep merge fragment into existing config, keep a backup.
if [[ -f "$CONFIG" ]]; then
  cp "$CONFIG" "$CONFIG.bak.$(date +%Y%m%d-%H%M%S)"
  jq -s '.[0] * .[1]' "$CONFIG" "$FRAGMENT" > "$CONFIG.tmp"
else
  cp "$FRAGMENT" "$CONFIG.tmp"
fi
mv "$CONFIG.tmp" "$CONFIG"
echo "config: $CONFIG updated (backup written)"

# 2. Bridge skills.
count=0
for dir in "$SKILLS_SRC"/*/; do
  name="$(basename "$dir")"
  mkdir -p "$SKILLS_DIR/$name"
  cp -f "$dir/SKILL.md" "$SKILLS_DIR/$name/SKILL.md"
  echo "skill: $name"
  count=$((count + 1))
done
echo "installed $count skills into $SKILLS_DIR"

# 3. Optional: Paseo orchestration skills.
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
  1. Restart Paseo (desktop: quit & relaunch; CLI: paseo daemon restart)
  2. paseo provider ls        # expect 'omp' and 'omp-main'
  3. In the composer type '/' # omp-review, omp-vibe, ... autocomplete
EOF
