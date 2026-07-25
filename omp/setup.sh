#!/usr/bin/env bash
# Reproduce TyposBro OMP agent harness policy/config. Safe to re-run.

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${PI_CODING_AGENT_DIR:-$HOME/.omp/agent}"

mkdir -p "$TARGET"

echo "==> Installing OMP agent harness config..."

# Remove stale artifacts from older setup iterations.
rm -rf \
	"$TARGET/skills" \
	"$TARGET/commands/loop.md" \
	"$TARGET/WATCHDOG.md"

# Remove obsolete Superpowers bootstrap / old agent definitions.
rm -f \
	"$TARGET/agents/gemini-pro.md" \
	"$TARGET/agents/deepseek-advisor.md" \
	"$TARGET/extensions/superpowers-bootstrap.ts"

mkdir -p \
	"$TARGET/skills" \
	"$TARGET/extensions" \
	"$TARGET/commands" \
	"$TARGET/agents"

cp "$DIR/agent/config.yml" "$TARGET/config.yml"
cp "$DIR/agent/APPEND_SYSTEM.md" "$TARGET/APPEND_SYSTEM.md"

# Idempotent copies — handle potentially empty/missing source dirs.
if [ -d "$DIR/agent/skills" ]; then
	cp -R "$DIR/agent/skills/." "$TARGET/skills/"
fi
if [ -d "$DIR/agent/agents" ]; then
	cp -R "$DIR/agent/agents/." "$TARGET/agents/"
fi
if [ -d "$DIR/agent/extensions" ]; then
	cp -R "$DIR/agent/extensions/." "$TARGET/extensions/"
fi

cat <<'MSG'
==> OMP agent harness setup restored.
    Managed: config.yml, APPEND_SYSTEM.md, skills, named agents (sol, fable).
    Removed: obsolete Superpowers plugin/bootstrap, /loop command, WATCHDOG.md, stale skills.
    Local-only state left untouched: models.yml, auth, sessions, DBs, blobs.
MSG
