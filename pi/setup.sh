#!/usr/bin/env bash
# Reproduce TyposBro pi setup (Linux/macOS). Safe to re-run.

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARK_DIR="$HOME/.local/state/config-pi"
PI_PACKAGE="@earendil-works/pi-coding-agent"
PI_VERSION="0.83.0"

mkdir -p "$MARK_DIR"

if [ "${1:-}" = "--clean" ] || [ "${1:-}" = "-c" ]; then
	echo "==> Clean pi setup — clearing marker..."
	rm -f "$MARK_DIR"/*
fi

did() { [ -f "$MARK_DIR/$1" ]; }
mark() { touch "$MARK_DIR/$1"; }

ensure_node() {
	for p in "$HOME/.local/share/fnm" "$HOME/.fnm"; do
		[ -x "$p/fnm" ] && export PATH="$p:$PATH"
	done

	if command -v fnm >/dev/null 2>&1; then
		eval "$(fnm env --shell bash)"
		fnm install --lts
		fnm use lts-latest
		fnm default lts-latest
	fi

	if ! command -v npm >/dev/null 2>&1; then
		echo "ERROR: npm not found. Install fnm/node first, then rerun." >&2
		exit 1
	fi
}

CURRENT_PI_VERSION=""
if command -v pi >/dev/null 2>&1; then
	CURRENT_PI_VERSION="$(pi --version 2>&1 | sed -n 's/.*\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' | head -n1 || true)"
fi

if [ "$CURRENT_PI_VERSION" != "$PI_VERSION" ]; then
	echo "==> Installing pi coding agent ${PI_PACKAGE}@${PI_VERSION}..."
	ensure_node
	npm install -g "${PI_PACKAGE}@${PI_VERSION}"
	mark pi-cli
elif ! did pi-cli; then
	mark pi-cli
fi

echo "==> Installing pi global settings/rules (no auth/session secrets)..."
mkdir -p "$HOME/.pi/agent"
cp "$DIR/agent/settings.json" "$HOME/.pi/agent/settings.json"
if [ -f "$DIR/agent/AGENTS.md" ]; then
	cp "$DIR/agent/AGENTS.md" "$HOME/.pi/agent/AGENTS.md"
fi

# Agent/harness skills live in ~/agent-memory/skills. Remove stale Pi-local
# skills/prompts/package runtime artifacts that can shadow or re-enable old
# third-party resources. Keep auth.json, sessions, models, and taskplane state.
rm -rf \
	"$HOME/.pi/agent/skills" \
	"$HOME/.pi/agent/prompts" \
	"$HOME/.pi/agent/taskplane" \
	"$HOME/.pi/agent/bin" \
	"$HOME/.pi/taskplane-pointer.json" \
	"$HOME/.pi/taskplane-workspace.yaml"

# ralph-loop was a repo-managed extension; delete the generated mirror now that
# it has been removed from the source tree.
rm -rf "$HOME/.pi/agent/extensions/ralph-loop"

SKILLS_SOURCE="${AGENT_MEMORY_ROOT:-$HOME/agent-memory}/skills"
link_skills_dir() {
	local link="$1"
	local label="$2"

	mkdir -p "$(dirname "$link")"
	if [ -L "$link" ]; then
		CURRENT_TARGET="$(readlink "$link")"
		if [ "$CURRENT_TARGET" != "$SKILLS_SOURCE" ]; then
			rm "$link"
			ln -s "$SKILLS_SOURCE" "$link"
		fi
	elif [ -e "$link" ]; then
		BACKUP="$link.backup.$(date +%Y%m%d-%H%M%S)"
		mv "$link" "$BACKUP"
		ln -s "$SKILLS_SOURCE" "$link"
		echo "    Existing $label moved to $BACKUP"
	else
		ln -s "$SKILLS_SOURCE" "$link"
	fi
}

if [ -d "$SKILLS_SOURCE" ]; then
	echo "==> Linking global skills to agent-memory source..."
	# Pi auto-discovers ~/.agents/skills. Claude Code still expects ~/.claude/skills.
	link_skills_dir "$HOME/.agents/skills" "~/.agents/skills"
	link_skills_dir "$HOME/.claude/skills" "~/.claude/skills"
else
	echo "==> Skipping global skills link: $SKILLS_SOURCE not found (run ~/agent-memory/setup.sh after cloning agent-memory)."
fi

if [ -d "$DIR/extensions" ]; then
	echo "==> Syncing global extensions..."
	mkdir -p "$HOME/.pi/agent/extensions"
	for extension in "$DIR"/extensions/*; do
		[ -e "$extension" ] || continue
		name="$(basename "$extension")"
		if [ -d "$extension" ]; then
			mkdir -p "$HOME/.pi/agent/extensions/$name"
			rsync -a --delete "$extension/" "$HOME/.pi/agent/extensions/$name/"
		elif [ "${extension##*.}" = "ts" ]; then
			cp "$extension" "$HOME/.pi/agent/extensions/$name"
		fi
	done
fi

cat <<'EOF'
==> Pi setup done.
    Managed global rules: ~/.pi/agent/AGENTS.md
    Managed skills links: ~/.agents/skills + ~/.claude/skills -> ~/agent-memory/skills (when agent-memory is present)
    Managed extensions: ~/.pi/agent/extensions/
    Secrets intentionally not managed: ~/.pi/agent/auth.json
    Sessions intentionally not managed: ~/.pi/agent/sessions/
    First run may install packages from settings.json.
EOF
