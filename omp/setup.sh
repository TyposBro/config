#!/usr/bin/env bash
# Reproduce TyposBro OMP agent harness policy/config. Safe to re-run.

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${PI_CODING_AGENT_DIR:-$HOME/.omp/agent}"
SKILLS_SETUP="${OMP_AGENT_SKILLS_SETUP:-$DIR/../agent-skills/setup.sh}"

STAGE="$(mktemp -d "${TMPDIR:-/tmp}/omp-agent-setup.XXXXXX")"
PUBLISHING=0

cleanup() {
	rm -rf "$STAGE"
}

warn_incomplete() {
	if [ "$PUBLISHING" -eq 1 ]; then
		printf '%s\n' \
			"ERROR: OMP routing publication stopped after target mutation." \
			"Stop all OMP sessions, rerun this installer, and relaunch only after it succeeds." >&2
	fi
}

trap cleanup EXIT
trap warn_incomplete ERR

echo "==> Staging OMP agent harness config..."
mkdir -p "$STAGE/agents" "$STAGE/commands" "$STAGE/extensions"
cp "$DIR/agent/config.yml" "$STAGE/config.yml"
cp "$DIR/agent/APPEND_SYSTEM.md" "$STAGE/APPEND_SYSTEM.md"
if [ -d "$DIR/agent/agents" ]; then
	cp -R "$DIR/agent/agents/." "$STAGE/agents/"
fi
if [ -d "$DIR/agent/commands" ]; then
	cp -R "$DIR/agent/commands/." "$STAGE/commands/"
fi
if [ -d "$DIR/agent/extensions" ]; then
	cp -R "$DIR/agent/extensions/." "$STAGE/extensions/"
fi

echo "==> Installing curated shared skills..."
if [ ! -f "$SKILLS_SETUP" ]; then
	printf 'Missing skills installer: %s\n' "$SKILLS_SETUP" >&2
	exit 1
fi
bash "$SKILLS_SETUP"

echo "==> Publishing OMP agent harness config..."
PUBLISHING=1
mkdir -p "$TARGET" "$TARGET/extensions" "$TARGET/commands" "$TARGET/agents"

# Agents and commands are managed inventories. Remove stale definitions so
# bundled or prior custom routes cannot bypass the pinned model contracts.
rm -f "$TARGET/agents/"*.md "$TARGET/commands/"*.md
rm -f "$TARGET/WATCHDOG.md" "$TARGET/extensions/superpowers-bootstrap.ts"

cp -R "$STAGE/agents/." "$TARGET/agents/"
cp -R "$STAGE/commands/." "$TARGET/commands/"
cp -R "$STAGE/extensions/." "$TARGET/extensions/"

# Publish policy and configuration last, after every referenced agent exists.
cp "$STAGE/APPEND_SYSTEM.md" "$TARGET/APPEND_SYSTEM.md"
cp "$STAGE/config.yml" "$TARGET/config.yml"
PUBLISHING=0
trap - ERR

cat <<'MSG'
==> OMP agent harness setup restored.
    Managed: config.yml, APPEND_SYSTEM.md, shared skills link, agents, extensions, commands.
    Routed workflow: Sol control plane, DeepSeek Flash writing, Sol/DeepSeek review, conditional Claude Opus.
    Local-only state left untouched: models.yml, auth, sessions, DBs, blobs.
    IMPORTANT: Stop and relaunch every existing OMP session before using this routing.
    Running sessions retain the model roles, agent definitions, and system prompt loaded at startup.
MSG
