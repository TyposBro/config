#!/usr/bin/env bash
# Reproduce TyposBro's personal Codex epic workflow without replacing unrelated Codex state.

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_HOME="${CODEX_HOME:-$HOME/.codex}"
TARGET_SKILLS="$TARGET_HOME/skills"
TARGET_AGENTS="$TARGET_HOME/agents"

mkdir -p "$TARGET_SKILLS" "$TARGET_AGENTS"

for skill in epic epics; do
	rm -rf "$TARGET_SKILLS/$skill"
	cp -R "$DIR/skills/$skill" "$TARGET_SKILLS/$skill"
done

for agent in epic-builder sol-reviewer adversarial-reviewer epic-designer; do
	cp "$DIR/agents/$agent.toml" "$TARGET_AGENTS/$agent.toml"
done

chmod +x "$TARGET_SKILLS/epic/scripts/epic-lock.sh"

cat <<'MSG'
==> Codex epic workflow installed.
    Skills: $epic, $epics
    Agents: epic_builder, sol_reviewer, adversarial_reviewer, epic_designer
    Restart Codex or open a new task before first use so custom agents are discovered.
MSG
