#!/usr/bin/env bash
# Install shared agent skills for Pi, OMP, OpenCode, Codex CLI, and Claude.
# Safe to re-run.

set -euo pipefail

SKILLS_SOURCE="${AGENT_MEMORY_ROOT:-$HOME/agent-memory}/skills"
WISE_TEACHER_SOURCE="$SKILLS_SOURCE/wise-teacher"
CONFIG_WISE_TEACHER="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/skills/wise-teacher"

if [ ! -d "$WISE_TEACHER_SOURCE" ]; then
	mkdir -p "$SKILLS_SOURCE"
	cp -R "$CONFIG_WISE_TEACHER" "$WISE_TEACHER_SOURCE"
fi

link_dir() {
	local target="$1"
	local source="$2"
	mkdir -p "$(dirname "$target")"
	if [ -L "$target" ]; then
		ln -sfn "$source" "$target"
	elif [ -e "$target" ]; then
		local backup="$target.backup.$(date +%Y%m%d-%H%M%S)"
		mv "$target" "$backup"
		ln -s "$source" "$target"
		echo "Moved existing $target to $backup"
	else
		ln -s "$source" "$target"
	fi
}

# Pi and Claude discover this shared skills directory.
link_dir "$HOME/.agents/skills" "$SKILLS_SOURCE"
link_dir "$HOME/.claude/skills" "$SKILLS_SOURCE"

# Codex CLI and OMP discover skills under their own skill roots.
link_dir "$HOME/.codex/skills/wise-teacher" "$WISE_TEACHER_SOURCE"
link_dir "$HOME/.omp/agent/skills/wise-teacher" "$WISE_TEACHER_SOURCE"

# OpenCode uses explicit additional skill folders in opencode.json.
python3 - <<'PY'
import json
from pathlib import Path

path = Path.home() / '.config/opencode/opencode.json'
path.parent.mkdir(parents=True, exist_ok=True)
if path.exists():
    data = json.loads(path.read_text())
else:
    data = {'$schema': 'https://opencode.ai/config.json'}

skills = data.setdefault('skills', {})
paths = skills.setdefault('paths', [])
skill_path = str(Path.home() / 'agent-memory/skills/wise-teacher')
if skill_path not in paths:
    paths.append(skill_path)

path.write_text(json.dumps(data, indent=2) + '\n')
PY

echo "Installed wise-teacher skill for Pi, Claude, Codex CLI, OMP, and OpenCode."
