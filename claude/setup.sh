#!/usr/bin/env bash

set -euo pipefail

AGENT_MEMORY_ROOT="${AGENT_MEMORY_ROOT:-$HOME/agent-memory}"
SKILLS_SOURCE="$AGENT_MEMORY_ROOT/skills"
MARK_DIR="$HOME/.local/state/config-claude"

mkdir -p "$MARK_DIR"

if [ ! -d "$SKILLS_SOURCE" ]; then
	echo "ERROR: global skills source not found: $SKILLS_SOURCE" >&2
	echo "Clone/sync agent-memory first, then rerun: ~/agent-memory/setup.sh" >&2
	exit 1
fi

mkdir -p "$HOME/.claude"

if [ -L "$HOME/.claude/skills" ]; then
	CURRENT_TARGET="$(readlink "$HOME/.claude/skills")"
	if [ "$CURRENT_TARGET" != "$SKILLS_SOURCE" ]; then
		rm "$HOME/.claude/skills"
		ln -s "$SKILLS_SOURCE" "$HOME/.claude/skills"
	fi
elif [ -e "$HOME/.claude/skills" ]; then
	BACKUP="$HOME/.claude/skills.backup.$(date +%Y%m%d-%H%M%S)"
	mv "$HOME/.claude/skills" "$BACKUP"
	ln -s "$SKILLS_SOURCE" "$HOME/.claude/skills"
	echo "    Existing ~/.claude/skills moved to $BACKUP"
else
	ln -s "$SKILLS_SOURCE" "$HOME/.claude/skills"
fi

mkdir -p "$MARK_DIR/claude"
touch "$MARK_DIR/claude/setup"

echo "    Linked Claude skills -> $SKILLS_SOURCE"
