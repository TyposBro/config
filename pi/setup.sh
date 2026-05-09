#!/usr/bin/env bash
# Reproduce TyposBro pi setup (Linux/macOS). Safe to re-run.

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MARK_DIR="$HOME/.local/state/config-pi"
PI_PACKAGE="@earendil-works/pi-coding-agent"
PI_VERSION="0.74.0"

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

if [ -d "$DIR/skills" ]; then
	echo "==> Syncing global skills..."
	mkdir -p "$HOME/.agents/skills"
	rsync -a --delete "$DIR/skills/" "$HOME/.agents/skills/"
fi

cat <<'EOF'
==> Pi setup done.
    Managed global rules: ~/.pi/agent/AGENTS.md
    Managed skills: ~/.agents/skills/
    Secrets intentionally not managed: ~/.pi/agent/auth.json
    Sessions intentionally not managed: ~/.pi/agent/sessions/
    First run may install packages from settings.json.
EOF
