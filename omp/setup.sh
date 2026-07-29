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

restore_previous() {
	rm -rf "$TARGET/agents" "$TARGET/commands" "$TARGET/extensions"
	mkdir -p "$TARGET/agents" "$TARGET/commands" "$TARGET/extensions"
	cp -R "$STAGE/previous/agents/." "$TARGET/agents/"
	cp -R "$STAGE/previous/commands/." "$TARGET/commands/"
	cp -R "$STAGE/previous/extensions/." "$TARGET/extensions/"
	if [ -f "$STAGE/previous/config.yml" ]; then
		cp "$STAGE/previous/config.yml" "$TARGET/config.yml"
	else
		rm -f "$TARGET/config.yml"
	fi
	if [ -f "$STAGE/previous/APPEND_SYSTEM.md" ]; then
		cp "$STAGE/previous/APPEND_SYSTEM.md" "$TARGET/APPEND_SYSTEM.md"
	else
		rm -f "$TARGET/APPEND_SYSTEM.md"
	fi
	if [ -f "$STAGE/previous/WATCHDOG.md" ]; then
		cp "$STAGE/previous/WATCHDOG.md" "$TARGET/WATCHDOG.md"
	else
		rm -f "$TARGET/WATCHDOG.md"
	fi
}

abort_publish() {
	local status="${1:-1}"
	trap - ERR HUP INT TERM
	if [ "$PUBLISHING" -eq 1 ]; then
		set +e
		restore_previous
		PUBLISHING=0
		printf '%s\n' \
			"ERROR: OMP routing publication was interrupted and the previous managed inventory was restored." \
			"Stop all OMP sessions, rerun this installer, and relaunch only after it succeeds." >&2
	fi
	exit "$status"
}

trap cleanup EXIT
trap 'abort_publish $?' ERR
trap 'abort_publish 130' HUP INT TERM

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

mkdir -p "$STAGE/previous/agents" "$STAGE/previous/commands" "$STAGE/previous/extensions"
if [ -d "$TARGET/agents" ]; then
	cp -R "$TARGET/agents/." "$STAGE/previous/agents/"
fi
if [ -d "$TARGET/commands" ]; then
	cp -R "$TARGET/commands/." "$STAGE/previous/commands/"
fi
if [ -d "$TARGET/extensions" ]; then
	cp -R "$TARGET/extensions/." "$STAGE/previous/extensions/"
fi
if [ -f "$TARGET/config.yml" ]; then
	cp "$TARGET/config.yml" "$STAGE/previous/config.yml"
fi
if [ -f "$TARGET/APPEND_SYSTEM.md" ]; then
	cp "$TARGET/APPEND_SYSTEM.md" "$STAGE/previous/APPEND_SYSTEM.md"
fi
if [ -f "$TARGET/WATCHDOG.md" ]; then
	cp "$TARGET/WATCHDOG.md" "$STAGE/previous/WATCHDOG.md"
fi

echo "==> Publishing OMP agent harness config..."
PUBLISHING=1
mkdir -p "$TARGET"

# Agents, commands, and extensions are managed inventories. Replace them
# completely so prior custom routes cannot bypass the pinned model contracts.
rm -rf "$TARGET/agents" "$TARGET/commands" "$TARGET/extensions"
mkdir -p "$TARGET/agents" "$TARGET/commands" "$TARGET/extensions"
rm -f "$TARGET/WATCHDOG.md"

cp -R "$STAGE/agents/." "$TARGET/agents/"
cp -R "$STAGE/commands/." "$TARGET/commands/"
cp -R "$STAGE/extensions/." "$TARGET/extensions/"

# Publish policy and configuration last, after every referenced agent exists.
cp "$STAGE/APPEND_SYSTEM.md" "$TARGET/APPEND_SYSTEM.md"
cp "$STAGE/config.yml" "$TARGET/config.yml"
PUBLISHING=0
trap - ERR HUP INT TERM

cat <<'MSG'
==> OMP agent harness setup restored.
    Managed: config.yml, APPEND_SYSTEM.md, shared skills link, agents, extensions, commands.
    Routed workflow: Sol control plane, DeepSeek Flash writing, Sol/DeepSeek review, conditional Claude Opus.
    Local-only state left untouched: models.yml, auth, sessions, DBs, blobs.
    IMPORTANT: Stop and relaunch every existing OMP session before using this routing.
    Running sessions retain the model roles, agent definitions, and system prompt loaded at startup.
MSG
printf '    Installed target: %s\n' "$TARGET"
