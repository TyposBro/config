#!/usr/bin/env bash
# Reproduce the shared CTO routing while preserving unrelated Codex state.

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_HOME="${CODEX_HOME:-$HOME/.codex}"
TARGET_SKILLS="$TARGET_HOME/skills"
TARGET_AGENTS="$TARGET_HOME/agents"
TARGET_BIN="${LOCAL_BIN:-$HOME/.local/bin}"
POLICY="${AGENT_MEMORY_ROOT:-$HOME/agent-memory}/shared/cto-workflow.md"
[[ -f "$POLICY" ]] || { echo "missing $POLICY" >&2; exit 1; }
mkdir -p "$TARGET_SKILLS" "$TARGET_AGENTS" "$TARGET_BIN"

for skill in epic epics; do
	rm -rf "$TARGET_SKILLS/$skill"
	cp -R "$DIR/skills/$skill" "$TARGET_SKILLS/$skill"
done

for agent in epic-builder sol-reviewer adversarial-reviewer epic-designer implementer small-worker reviewer; do
	cp "$DIR/agents/$agent.toml" "$TARGET_AGENTS/$agent.toml"
done

cp "$DIR/cto.config.toml" "$TARGET_HOME/cto.config.toml"

if [[ -e "$TARGET_HOME/AGENTS.md" || -L "$TARGET_HOME/AGENTS.md" ]]; then
	if [[ ! -L "$TARGET_HOME/AGENTS.md" || "$(readlink "$TARGET_HOME/AGENTS.md")" != "$POLICY" ]]; then
		if [[ -s "$TARGET_HOME/AGENTS.md" ]]; then
			mv "$TARGET_HOME/AGENTS.md" "$TARGET_HOME/AGENTS.md.bak.$(date +%Y%m%d-%H%M%S)"
		else
			rm -f "$TARGET_HOME/AGENTS.md"
		fi
	fi
fi
[[ -e "$TARGET_HOME/AGENTS.md" || -L "$TARGET_HOME/AGENTS.md" ]] || ln -s "$POLICY" "$TARGET_HOME/AGENTS.md"

cat >"$TARGET_BIN/codex-cto" <<'EOF'
#!/bin/sh
if [ "${1:-}" = "app-server" ]; then
  shift
  exec codex app-server \
    -c 'model="gpt-5.6-sol"' \
    -c 'model_provider="openai"' \
    -c 'model_reasoning_effort="medium"' \
    -c 'review_model="gpt-5.6-terra"' \
    -c 'agents.enabled=true' \
    -c 'agents.max_concurrent_threads_per_session=3' \
    -c 'agents.default_subagent_model="gpt-5.6-terra"' \
    -c 'agents.default_subagent_reasoning_effort="xhigh"' \
    "$@"
fi
exec codex --profile cto "$@"
EOF
chmod +x "$TARGET_BIN/codex-cto"

chmod +x "$TARGET_SKILLS/epic/scripts/epic-lock.sh"

cat <<MSG
==> Codex CTO workflow installed.
    Profile: codex --profile cto
    Shortcut: $TARGET_BIN/codex-cto
    Main: GPT-5.6 Sol medium
    Workers: GPT-5.6 Terra xhigh; GPT-5.6 Luna xhigh for small work
    Review: GPT-5.6 Terra max
    Restart Codex or open a new task before first use.
MSG
