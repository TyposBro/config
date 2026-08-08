#!/usr/bin/env bash
set -euo pipefail

# Removes everything install.sh added:
#   - omp / omp-main / codex-go providers from $PASEO_HOME/config.json (backup first)
#   - the omp-* bridge skills from ~/.agents/skills
#   - the opencode -> ~/.local/bin symlink (if it points at ~/.opencode/bin/opencode)
# Paseo orchestration skills (getpaseo/paseo) and config backups are left untouched.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASEO_HOME_DIR="${PASEO_HOME:-$HOME/.paseo}"
SKILLS_DIR="${SKILLS_DIR:-$HOME/.agents/skills}"
CONFIG="$PASEO_HOME_DIR/config.json"

if [[ -f "$CONFIG" ]]; then
  cp "$CONFIG" "$CONFIG.bak.$(date +%Y%m%d-%H%M%S)"
  jq 'del(.agents.providers.omp, .agents.providers["omp-main"], .agents.providers["codex-go"])' "$CONFIG" > "$CONFIG.tmp" \
    && mv "$CONFIG.tmp" "$CONFIG"
  echo "removed providers omp / omp-main / codex-go from $CONFIG"
else
  echo "no $CONFIG — nothing to clean"
fi

for dir in "$HERE"/.agents/skills/*/; do
  name="$(basename "$dir")"
  if [[ -f "$SKILLS_DIR/$name/SKILL.md" ]]; then
    rm -rf "$SKILLS_DIR/$name"
    echo "removed skill: $name"
  fi
done

if [[ -L "$HOME/.local/bin/opencode" ]] && [[ "$(readlink "$HOME/.local/bin/opencode")" == "$HOME/.opencode/bin/opencode" ]]; then
  rm "$HOME/.local/bin/opencode"
  echo "removed symlink: ~/.local/bin/opencode"
fi

echo "Uninstall done. Restart Paseo to drop the providers."
