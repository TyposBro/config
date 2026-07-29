#!/usr/bin/env bash
# Install TyposBro's curated shared skills for Pi, OMP, OpenCode, Codex, and Claude.
# Safe to re-run. Managed third-party skills are pinned and customized locally.

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_ROOT="$(cd "$DIR/.." && pwd)"
CONFIG_SKILLS="$CONFIG_ROOT/skills"
SKILLS_SOURCE="${AGENT_MEMORY_ROOT:-$HOME/agent-memory}/skills"

manifest_query() {
	python3 - "$DIR/manifest.json" "$1" <<'PY'
import json
from pathlib import Path
import sys

manifest = json.loads(Path(sys.argv[1]).read_text())
query = sys.argv[2]

if query.startswith("source."):
    value = manifest["source"][query.split(".", 1)[1]]
    if query == "source.url":
        value = value.format(commit=manifest["source"]["commit"])
    print(value)
elif query == "upstream":
    for skill in manifest["upstream"]:
        print(f'{skill["path"]}\t{skill["name"]}')
elif query == "rejected":
    print("\n".join(manifest["rejected"]))
else:
    raise SystemExit(f"unknown manifest query: {query}")
PY
}

MATTP_SKILLS_COMMIT="$(manifest_query source.commit)"
MATTP_SKILLS_SHA256="$(manifest_query source.sha256)"
MATTP_SKILLS_URL="$(manifest_query source.url)"

if [ "${1:-}" = "--check" ]; then
	exec python3 "$DIR/check.py"
elif [ "$#" -ne 0 ]; then
	echo "usage: $0 [--check]" >&2
	exit 2
fi

checksum() {
	local file="$1"
	if command -v sha256sum >/dev/null 2>&1; then
		sha256sum "$file" | awk '{print $1}'
	else
		shasum -a 256 "$file" | awk '{print $1}'
	fi
}

link_dir() {
	local target="$1"
	local source="$2"
	mkdir -p "$(dirname "$target")"
	if [ -L "$target" ]; then
		ln -sfn "$source" "$target"
	elif [ -e "$target" ]; then
		local backup_root="$HOME/.local/state/config-backups/agent-skills"
		local label="${target//\//_}"
		local backup="$backup_root/${label}_$(date +%Y%m%d-%H%M%S)"
		mkdir -p "$backup_root"
		mv "$target" "$backup"
		ln -s "$source" "$target"
		echo "Moved existing $target to $backup"
	else
		ln -s "$source" "$target"
	fi
}

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
ARCHIVE="$TMP_DIR/mattpocock-skills.tar.gz"

echo "==> Fetching pinned Matt Pocock skills..."
curl -fsSL "$MATTP_SKILLS_URL" -o "$ARCHIVE"
ACTUAL_SHA256="$(checksum "$ARCHIVE")"
if [ "$ACTUAL_SHA256" != "$MATTP_SKILLS_SHA256" ]; then
	echo "ERROR: skill archive checksum mismatch" >&2
	echo "expected: $MATTP_SKILLS_SHA256" >&2
	echo "actual:   $ACTUAL_SHA256" >&2
	exit 1
fi

tar -xzf "$ARCHIVE" -C "$TMP_DIR"
UPSTREAM_ROOT="$TMP_DIR/skills-$MATTP_SKILLS_COMMIT"

mkdir -p "$SKILLS_SOURCE"

while IFS= read -r name; do
	[ -n "$name" ] || continue
	rm -rf "$SKILLS_SOURCE/$name"
done < <(manifest_query rejected)

while IFS=$'\t' read -r source_path name; do
	[ -n "$name" ] || continue
	rm -rf "$SKILLS_SOURCE/$name"
	cp -R "$UPSTREAM_ROOT/$source_path" "$SKILLS_SOURCE/$name"
done < <(manifest_query upstream)

# Repo-owned skills override third-party skills with the same name.
if [ -d "$CONFIG_SKILLS" ]; then
	for source in "$CONFIG_SKILLS"/*; do
		[ -d "$source" ] || continue
		name="$(basename "$source")"
		rm -rf "$SKILLS_SOURCE/$name"
		cp -R "$source" "$SKILLS_SOURCE/$name"
	done
fi

python3 "$DIR/customize.py" "$SKILLS_SOURCE"

# Pi and Claude discover the complete shared skills directory.
link_dir "$HOME/.agents/skills" "$SKILLS_SOURCE"
link_dir "$HOME/.claude/skills" "$SKILLS_SOURCE"

# OMP uses the same canonical directory rather than a copied snapshot.
link_dir "$HOME/.omp/agent/skills" "$SKILLS_SOURCE"

# Codex keeps built-in .system skills, so link curated skills individually.
mkdir -p "$HOME/.codex/skills"
while IFS= read -r name; do
	[ -n "$name" ] || continue
	rm -rf "$HOME/.codex/skills/$name"
done < <(manifest_query rejected)
for source in "$SKILLS_SOURCE"/*; do
	[ -d "$source" ] || continue
	name="$(basename "$source")"
	link_dir "$HOME/.codex/skills/$name" "$source"
done

# OpenCode expects explicit skill-folder paths. Preserve unrelated paths.
python3 - "$SKILLS_SOURCE" <<'PY'
import json
from pathlib import Path
import sys

skills_root = Path(sys.argv[1]).resolve()
path = Path.home() / ".config/opencode/opencode.json"
path.parent.mkdir(parents=True, exist_ok=True)
if path.exists():
    data = json.loads(path.read_text())
else:
    data = {"$schema": "https://opencode.ai/config.json"}

skills = data.setdefault("skills", {})
paths = skills.setdefault("paths", [])
prefix = str(skills_root) + "/"
unrelated = [item for item in paths if not str(item).startswith(prefix)]
managed = [str(item) for item in sorted(skills_root.iterdir()) if item.is_dir()]
skills["paths"] = unrelated + managed
path.write_text(json.dumps(data, indent=2) + "\n")
PY

python3 "$DIR/check.py" --skip-archive

echo "Installed curated shared skills from $SKILLS_SOURCE."
