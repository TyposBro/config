#!/usr/bin/env bash
# Reproduce TyposBro OMP agent harness policy/config. Safe to re-run.

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${PI_CODING_AGENT_DIR:-$HOME/.omp/agent}"
PLUGIN_SPEC="github:obra/superpowers"

mkdir -p "$TARGET"

if command -v omp >/dev/null 2>&1; then
	echo "==> Ensuring Superpowers OMP plugin is installed..."
	omp plugin install "$PLUGIN_SPEC" >/dev/null
else
	cat >&2 <<'MSG'
==> Warning: omp is not installed or not on PATH.
    Managed files will still be copied, but run this again after installing omp
    so the Superpowers plugin is registered.
MSG
fi

echo "==> Installing OMP Superpowers/personality config..."

# Remove old repo-managed workflows replaced by Superpowers.
rm -rf \
	"$TARGET/skills" \
	"$TARGET/commands/loop.md" \
	"$TARGET/agents/deepseek-advisor.md" \
	"$TARGET/WATCHDOG.md"

mkdir -p \
	"$TARGET/skills" \
	"$TARGET/extensions" \
	"$TARGET/commands" \
	"$TARGET/agents"

cp "$DIR/agent/config.yml" "$TARGET/config.yml"
cp "$DIR/agent/APPEND_SYSTEM.md" "$TARGET/APPEND_SYSTEM.md"
cp -R "$DIR/agent/skills/." "$TARGET/skills/"
cp -R "$DIR/agent/extensions/." "$TARGET/extensions/"

cat <<'MSG'
==> OMP agent harness setup restored.
    Managed: config.yml, APPEND_SYSTEM.md, Superpowers skills, bootstrap extension.
    Removed: old /loop command, deepseek-advisor workflow, WATCHDOG.md, previous skills.
    Local-only state left untouched: models.yml, auth, sessions, DBs, blobs.
MSG
