#!/usr/bin/env bash
# Reproduce TyposBro OMP agent policy/config. Safe to re-run.

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$HOME/.omp/agent"

mkdir -p \
	"$TARGET/agents" \
	"$TARGET/commands" \
	"$TARGET/skills/model-delegation-loop"

cp "$DIR/agent/config.yml" "$TARGET/config.yml"
cp "$DIR/agent/APPEND_SYSTEM.md" "$TARGET/APPEND_SYSTEM.md"
cp "$DIR/agent/WATCHDOG.md" "$TARGET/WATCHDOG.md"
cp "$DIR/agent/agents/deepseek-advisor.md" "$TARGET/agents/deepseek-advisor.md"
cp "$DIR/agent/commands/loop.md" "$TARGET/commands/loop.md"
cp "$DIR/agent/skills/model-delegation-loop/SKILL.md" "$TARGET/skills/model-delegation-loop/SKILL.md"

if [ ! -f "$TARGET/models.yml" ]; then
	cat <<'MSG'
==> OMP model routing restored.
    ~/.omp/agent/models.yml is still local-only and was not created.
    Configure provider credentials on this machine before using Google/Gemini models.
MSG
else
	echo "==> OMP model routing restored. Local models.yml left untouched."
fi
