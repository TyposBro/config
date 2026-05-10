#!/usr/bin/env bash

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_SKILLS="$DIR/skills"

MARK_DIR="$HOME/.local/state/config-claude"
mkdir -p "$MARK_DIR"

MANAGED_SKILLS="$HOME/.agents/claude/skills"
mkdir -p "$MANAGED_SKILLS"

echo "==> Syncing Claude skills from nixos-config..."
rsync -a --delete "$REPO_SKILLS/" "$MANAGED_SKILLS/"

if [ -e "$HOME/.claude/skills" ] && [ ! -L "$HOME/.claude/skills" ]; then
	rm -rf "$HOME/.claude/skills"
fi

mkdir -p "$HOME/.claude"
ln -sfn "$MANAGED_SKILLS" "$HOME/.claude/skills"

mkdir -p "$MARK_DIR/claude"
touch "$MARK_DIR/claude/setup"

echo "    Synced Claude skills -> $HOME/.claude/skills"
