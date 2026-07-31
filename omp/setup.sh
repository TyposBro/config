#!/usr/bin/env bash
# Reproduce TyposBro OMP agent harness policy/config. Safe to re-run.

set -Eeuo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_INPUT="${PI_CODING_AGENT_DIR:-$HOME/.omp/agent}"
SKILLS_SETUP="${OMP_AGENT_SKILLS_SETUP:-$DIR/../agent-skills/setup.sh}"
SKILLS_ROOT_INPUT="${AGENT_MEMORY_ROOT:-$HOME/agent-memory}"

case "$TARGET_INPUT" in
	/*) TARGET="$TARGET_INPUT" ;;
	*) TARGET="$PWD/$TARGET_INPUT" ;;
esac
while [ "$TARGET" != "/" ] && [ "${TARGET%/}" != "$TARGET" ]; do
	TARGET="${TARGET%/}"
done

case "$SKILLS_ROOT_INPUT" in
	/*) SKILLS_ROOT="$SKILLS_ROOT_INPUT" ;;
	*) SKILLS_ROOT="$PWD/$SKILLS_ROOT_INPUT" ;;
esac
while [ "$SKILLS_ROOT" != "/" ] && [ "${SKILLS_ROOT%/}" != "$SKILLS_ROOT" ]; do
	SKILLS_ROOT="${SKILLS_ROOT%/}"
done
SKILLS_SOURCE="$SKILLS_ROOT/skills"

case "$SKILLS_SETUP" in
	/*) ;;
	*) SKILLS_SETUP="$PWD/$SKILLS_SETUP" ;;
esac

# Resolve the existing part of a target without depending on realpath(1).
# The unresolved suffix is safe because target paths are directory paths and
# the nearest existing ancestor is resolved with cd -P.
canonical_target() {
	local path="$1"
	local unresolved=""
	local parent
	local name
	local resolved

	while :; do
		if [ -d "$path" ]; then
			resolved="$(cd -P "$path" && pwd)" || return 1
			if [ -n "$unresolved" ]; then
				printf '%s/%s\n' "$resolved" "$unresolved"
			else
				printf '%s\n' "$resolved"
			fi
			return 0
		fi
		parent="$(dirname "$path")"
		name="$(basename "$path")"
		[ "$parent" != "$path" ] || return 1
		if [ -n "$unresolved" ]; then
			unresolved="$name/$unresolved"
		else
			unresolved="$name"
		fi
		path="$parent"
	done
}

if ! CANONICAL_TARGET="$(canonical_target "$TARGET")"; then
	printf 'ERROR: cannot determine the canonical OMP target: %s\n' "$TARGET" >&2
	exit 1
fi

STAGE="$(mktemp -d "${TMPDIR:-/tmp}/omp-agent-setup.XXXXXX")"
LOCK_KEY="${CANONICAL_TARGET//%/%25}"
LOCK_KEY="${LOCK_KEY//\//%2F}"
LOCK_DIR="/tmp/omp-agent-setup-${LOCK_KEY}.lock"
LOCK_OWNER_FILE="$LOCK_DIR/owner"
INVOCATION_TOKEN="$$-${STAGE##*/}"

LOCK_HELD=0
KEEP_RECOVERY=0
TRANSACTION_ACTIVE=0
ABORTING=0
PUBLISHING=0
TARGET_WAS_ABSENT=0
RELEASE_ROOT_WAS_ABSENT=0
CURRENT_WAS_PRESENT=0
PREVIOUS_CURRENT_TARGET=""
PREVIOUS_RELEASE_PATH=""
NEW_RELEASE=""

MANAGED_ROOT="$CANONICAL_TARGET/.omp-routing"
RELEASES_DIR="$MANAGED_ROOT/releases"
CURRENT_PATH="$MANAGED_ROOT/current"
ROUTING_MARKER="$MANAGED_ROOT/.managed-by-omp-setup"
ROUTING_MARKER_VALUE="omp-routing-v1"
SNAPSHOT="$STAGE/snapshot"
RELEASE_STAGE="$STAGE/release"
CHILD_OMP_SKILLS="$HOME/.omp/agent/skills"

remove_path() {
	local path="$1"
	if [ -e "$path" ] || [ -L "$path" ]; then
		rm -rf "$path"
	fi
}

copy_entry() {
	local source="$1"
	local destination="$2"
	local link_target
	local child
	local name

	if [ -L "$source" ]; then
		link_target="$(readlink "$source")" || return 1
		mkdir -p "$(dirname "$destination")"
		ln -s "$link_target" "$destination"
	elif [ -d "$source" ]; then
		mkdir -p "$destination"
		for child in "$source"/* "$source"/.[!.]* "$source"/..?*; do
			[ -e "$child" ] || [ -L "$child" ] || continue
			name="${child##*/}"
			copy_entry "$child" "$destination/$name" || return 1
		done
	elif [ -f "$source" ]; then
		mkdir -p "$(dirname "$destination")"
		cp -p "$source" "$destination"
	elif [ -e "$source" ]; then
		printf 'ERROR: unsupported managed path type: %s\n' "$source" >&2
		return 1
	else
		printf 'ERROR: missing managed source: %s\n' "$source" >&2
		return 1
	fi
}

copy_tree_contents() {
	local source="$1"
	local destination="$2"
	local child
	local name

	mkdir -p "$destination"
	for child in "$source"/* "$source"/.[!.]* "$source"/..?*; do
		[ -e "$child" ] || [ -L "$child" ] || continue
		name="${child##*/}"
		copy_entry "$child" "$destination/$name" || return 1
	done
}

snapshot_entry() {
	local source="$1"
	local destination="$2"
	local link_target

	mkdir -p "$destination"
	if [ -L "$source" ]; then
		printf 'symlink\n' > "$destination/type"
		link_target="$(readlink "$source")" || return 1
		printf '%s\n' "$link_target" > "$destination/link"
	elif [ -d "$source" ]; then
		printf 'directory\n' > "$destination/type"
		mkdir -p "$destination/data"
		copy_tree_contents "$source" "$destination/data"
	elif [ -f "$source" ]; then
		printf 'file\n' > "$destination/type"
		cp -p "$source" "$destination/data"
	elif [ -e "$source" ]; then
		printf 'ERROR: unsupported managed path type: %s\n' "$source" >&2
		return 1
	else
		printf 'absent\n' > "$destination/type"
	fi
}

restore_entry() {
	local snapshot_path="$1"
	local destination="$2"
	local entry_type
	local link_target

	entry_type="$(cat "$snapshot_path/type")" || return 1
	remove_path "$destination"
	case "$entry_type" in
		absent)
			;;
		symlink)
			link_target="$(cat "$snapshot_path/link")" || return 1
			mkdir -p "$(dirname "$destination")"
			ln -s "$link_target" "$destination"
			;;
		file)
			mkdir -p "$(dirname "$destination")"
			cp -p "$snapshot_path/data" "$destination"
			;;
		directory)
			mkdir -p "$destination"
			copy_tree_contents "$snapshot_path/data" "$destination"
			;;
		*)
			printf 'ERROR: invalid recovery snapshot: %s\n' "$snapshot_path" >&2
			return 1
			;;
	esac
}

assert_lock_owner() {
	local owner

	if [ "$LOCK_HELD" -ne 1 ] || [ ! -d "$LOCK_DIR" ] || [ ! -f "$LOCK_OWNER_FILE" ]; then
		printf 'ERROR: OMP installer lock ownership was lost for %s; refusing further mutation.\n' \
			"$CANONICAL_TARGET" >&2
		return 1
	fi
	if ! owner="$(cat "$LOCK_OWNER_FILE" 2>/dev/null)"; then
		printf 'ERROR: OMP installer lock owner is unreadable for %s; refusing further mutation.\n' \
			"$CANONICAL_TARGET" >&2
		return 1
	fi
	if [ "$owner" != "$INVOCATION_TOKEN" ]; then
		printf 'ERROR: OMP installer lock ownership changed for %s; refusing further mutation.\n' \
			"$CANONICAL_TARGET" >&2
		return 1
	fi
}

acquire_lock() {
	local owner

	if mkdir "$LOCK_DIR" 2>/dev/null; then
		LOCK_HELD=1
		if ! (umask 077; printf '%s\n' "$INVOCATION_TOKEN" > "$LOCK_OWNER_FILE"); then
			printf 'ERROR: acquired but could not record the OMP installer lock owner for %s.\n' \
				"$CANONICAL_TARGET" >&2
			return 1
		fi
		return 0
	fi

	if [ ! -d "$LOCK_DIR" ]; then
		printf 'ERROR: cannot acquire the OMP installer lock for %s.\n' "$CANONICAL_TARGET" >&2
		return 1
	fi
	if [ ! -f "$LOCK_OWNER_FILE" ]; then
		printf 'ERROR: another OMP installer has an ambiguous lock for %s; refusing to steal it.\n' \
			"$CANONICAL_TARGET" >&2
		return 1
	fi
	if ! owner="$(cat "$LOCK_OWNER_FILE" 2>/dev/null)" || [ -z "$owner" ]; then
		printf 'ERROR: another OMP installer has an unreadable lock for %s; refusing to steal it.\n' \
			"$CANONICAL_TARGET" >&2
		return 1
	fi
	printf 'ERROR: another OMP installer owns %s (owner %s); wait for it to finish and retry.\n' \
		"$CANONICAL_TARGET" "$owner" >&2
	return 1
}

release_lock() {
	local owner

	[ "$LOCK_HELD" -eq 1 ] || return 0
	if [ ! -d "$LOCK_DIR" ] || [ ! -f "$LOCK_OWNER_FILE" ]; then
		printf 'ERROR: OMP installer lock became ambiguous; preserving it at %s.\n' "$LOCK_DIR" >&2
		return 1
	fi
	if ! owner="$(cat "$LOCK_OWNER_FILE" 2>/dev/null)" || [ "$owner" != "$INVOCATION_TOKEN" ]; then
		printf 'ERROR: OMP installer lock ownership changed; preserving lock at %s.\n' "$LOCK_DIR" >&2
		return 1
	fi
	rm -f "$LOCK_OWNER_FILE" || return 1
	if ! rmdir "$LOCK_DIR"; then
		printf 'ERROR: could not remove the OMP installer lock at %s; preserving it.\n' "$LOCK_DIR" >&2
		return 1
	fi
	LOCK_HELD=0
}

restore_snapshot_entry() {
	local snapshot_path="$1"
	local destination="$2"

	assert_lock_owner || return 1
	restore_entry "$snapshot_path" "$destination"
}

restore_snapshots() {
	local status=0

	restore_snapshot_entry "$SNAPSHOT/agents" "$TARGET/agents" || status=1
	restore_snapshot_entry "$SNAPSHOT/commands" "$TARGET/commands" || status=1
	restore_snapshot_entry "$SNAPSHOT/extensions" "$TARGET/extensions" || status=1
	restore_snapshot_entry "$SNAPSHOT/config.yml" "$TARGET/config.yml" || status=1
	restore_snapshot_entry "$SNAPSHOT/APPEND_SYSTEM.md" "$TARGET/APPEND_SYSTEM.md" || status=1
	restore_snapshot_entry "$SNAPSHOT/WATCHDOG.md" "$TARGET/WATCHDOG.md" || status=1
	restore_snapshot_entry "$SNAPSHOT/omp-skills" "$TARGET/skills" || status=1
	if [ "$CHILD_OMP_SKILLS" != "$TARGET/skills" ]; then
		restore_snapshot_entry "$SNAPSHOT/child-omp-skills" "$CHILD_OMP_SKILLS" || status=1
	fi
	restore_snapshot_entry "$SNAPSHOT/shared-skills" "$SKILLS_SOURCE" || status=1
	return "$status"
}


rollback_transaction() {
	local status=0

	assert_lock_owner || return 1
	restore_snapshot_entry "$SNAPSHOT/managed-root" "$MANAGED_ROOT" || status=1
	if ! restore_snapshots; then
		status=1
	fi
	if [ "$TARGET_WAS_ABSENT" -eq 1 ]; then
		assert_lock_owner || status=1
		if [ -d "$CANONICAL_TARGET" ] && [ ! -L "$CANONICAL_TARGET" ]; then
			if ! rmdir "$CANONICAL_TARGET"; then
				status=1
			fi
		fi
	fi
	return "$status"
}

abort_publish() {
	local status="${1:-1}"
	local rollback_status=0

	if [ "$ABORTING" -eq 1 ]; then
		exit "$status"
	fi
	ABORTING=1
	trap - ERR HUP INT TERM
	set +e
	if [ "$TRANSACTION_ACTIVE" -eq 1 ]; then
		rollback_transaction || rollback_status=$?
		TRANSACTION_ACTIVE=0
		if [ "$rollback_status" -eq 0 ]; then
			printf '%s\n' \
				"ERROR: OMP routing publication was interrupted and the previous managed inventory was restored." \
				"Stop all OMP sessions, rerun this installer, and relaunch only after it succeeds." >&2
		else
			KEEP_RECOVERY=1
			printf '%s\n' \
				"ERROR: OMP routing publication and automatic rollback both failed." \
				"Recovery material preserved at: $STAGE" \
				"Managed release metadata preserved at: $MANAGED_ROOT" \
				"Stop all OMP sessions, preserve the recovery material, and restore or rerun the installer before relaunching." >&2
		fi
	fi
	exit "$status"
}

cleanup() {
	local recovery_status=0

	set +e
	if [ "$LOCK_HELD" -eq 1 ] && [ "$KEEP_RECOVERY" -eq 0 ]; then
		if ! assert_lock_owner; then
			KEEP_RECOVERY=1
			recovery_status=1
		fi
	fi
	if [ "$KEEP_RECOVERY" -eq 0 ]; then
		if [ -d "$STAGE" ] || [ -L "$STAGE" ]; then
			if ! rm -rf "$STAGE"; then
				KEEP_RECOVERY=1
				recovery_status=1
				printf 'ERROR: could not clean temporary OMP setup material; preserve it at %s.\n' \
					"$STAGE" >&2
			fi
		fi
	else
		printf 'Recovery material preserved at: %s\n' "$STAGE" >&2
	fi
	if [ "$LOCK_HELD" -eq 1 ]; then
		release_lock || recovery_status=1
	fi
	return "$recovery_status"
}

validate_release_root() {
	local marker

	if [ -L "$MANAGED_ROOT" ] || [ ! -d "$MANAGED_ROOT" ]; then
		printf 'ERROR: managed release metadata is not a directory: %s\n' "$MANAGED_ROOT" >&2
		return 1
	fi
	if [ -L "$ROUTING_MARKER" ] || [ ! -f "$ROUTING_MARKER" ]; then
		printf 'ERROR: managed release metadata is ambiguous: %s\n' "$MANAGED_ROOT" >&2
		return 1
	fi
	if ! marker="$(cat "$ROUTING_MARKER" 2>/dev/null)" || [ "$marker" != "$ROUTING_MARKER_VALUE" ]; then
		printf 'ERROR: managed release metadata ownership is ambiguous: %s\n' "$MANAGED_ROOT" >&2
		return 1
	fi
	if [ -e "$RELEASES_DIR" ] || [ -L "$RELEASES_DIR" ]; then
		if [ -L "$RELEASES_DIR" ] || [ ! -d "$RELEASES_DIR" ]; then
			printf 'ERROR: managed release inventory is not a directory: %s\n' "$RELEASES_DIR" >&2
			return 1
		fi
	fi
}

inspect_release_root() {
	local current_resolved

	if [ -e "$MANAGED_ROOT" ] || [ -L "$MANAGED_ROOT" ]; then
		RELEASE_ROOT_WAS_ABSENT=0
		validate_release_root
		if [ -L "$CURRENT_PATH" ]; then
			CURRENT_WAS_PRESENT=1
			PREVIOUS_CURRENT_TARGET="$(readlink "$CURRENT_PATH")" || return 1
			if [ "$PREVIOUS_CURRENT_TARGET" = "" ]; then
				printf 'ERROR: managed release current link is empty: %s\n' "$CURRENT_PATH" >&2
				return 1
			fi
			case "$PREVIOUS_CURRENT_TARGET" in
				/*) current_resolved="$PREVIOUS_CURRENT_TARGET" ;;
				*) current_resolved="$MANAGED_ROOT/$PREVIOUS_CURRENT_TARGET" ;;
			esac
			case "$current_resolved" in
				"$RELEASES_DIR"/release-*) ;;
				*)
					printf 'ERROR: managed release current link is outside the release inventory: %s\n' \
						"$CURRENT_PATH" >&2
					return 1
					;;
			esac
			if [ ! -d "$current_resolved" ] || [ -L "$current_resolved" ] || \
				[ ! -f "$current_resolved/.complete" ]; then
				printf 'ERROR: managed release current link does not resolve to a complete release: %s\n' \
					"$CURRENT_PATH" >&2
				return 1
			fi
			PREVIOUS_RELEASE_PATH="$current_resolved"
		elif [ -e "$CURRENT_PATH" ]; then
			printf 'ERROR: managed release current switch is not a symlink: %s\n' "$CURRENT_PATH" >&2
			return 1
		fi
	else
		RELEASE_ROOT_WAS_ABSENT=1
	fi
}

ensure_release_root() {
	local marker_tmp
	local current_target

	if [ "$RELEASE_ROOT_WAS_ABSENT" -eq 1 ]; then
		if [ -e "$MANAGED_ROOT" ] || [ -L "$MANAGED_ROOT" ]; then
			printf 'ERROR: managed release metadata appeared during setup: %s\n' "$MANAGED_ROOT" >&2
			return 1
		fi
		mkdir -p "$RELEASES_DIR"
		marker_tmp="$MANAGED_ROOT/.managed-by-omp-setup-$INVOCATION_TOKEN"
		printf '%s\n' "$ROUTING_MARKER_VALUE" > "$marker_tmp"
		mv -f "$marker_tmp" "$ROUTING_MARKER"
	else
		validate_release_root
		if [ ! -d "$RELEASES_DIR" ]; then
			mkdir -p "$RELEASES_DIR"
		fi
		if [ -L "$CURRENT_PATH" ]; then
			current_target="$(readlink "$CURRENT_PATH")" || return 1
			if [ "$CURRENT_WAS_PRESENT" -ne 1 ] || [ "$current_target" != "$PREVIOUS_CURRENT_TARGET" ]; then
				printf 'ERROR: managed release current link changed during setup: %s\n' "$CURRENT_PATH" >&2
				return 1
			fi
		elif [ "$CURRENT_WAS_PRESENT" -eq 1 ] || [ -e "$CURRENT_PATH" ]; then
			printf 'ERROR: managed release current switch changed during setup: %s\n' "$CURRENT_PATH" >&2
			return 1
		fi
	fi
}

switch_current() {
	local switch_tmp="$MANAGED_ROOT/.current-$INVOCATION_TOKEN"

	assert_lock_owner || return 1
	remove_path "$switch_tmp"
	ln -s "$NEW_RELEASE" "$switch_tmp"
	# Replace the stable symlink itself atomically; do not traverse its target directory.
	python3 -c 'import os, sys; os.replace(sys.argv[1], sys.argv[2])' "$switch_tmp" "$CURRENT_PATH"
}

publish_link() {
	local name="$1"
	local desired="$MANAGED_ROOT/current/$name"
	local existing_target

	assert_lock_owner || return 1
	if [ -L "$TARGET/$name" ]; then
		existing_target="$(readlink "$TARGET/$name")" || return 1
		if [ "$existing_target" = "$desired" ]; then
			return 0
		fi
	fi
	remove_path "$TARGET/$name"
	ln -s "$desired" "$TARGET/$name"
}

prune_releases() {
	local candidate
	local candidate_name

	assert_lock_owner || return 1
	[ "$CURRENT_WAS_PRESENT" -eq 1 ] || return 0
	for candidate in "$RELEASES_DIR"/release-*; do
		[ -d "$candidate" ] || continue
		[ -L "$candidate" ] && continue
		[ "$candidate" = "$NEW_RELEASE" ] && continue
		[ "$candidate" = "$PREVIOUS_RELEASE_PATH" ] && continue
		candidate_name="${candidate##*/}"
		case "$candidate_name" in
			release-*) rm -rf "$candidate" ;;
		esac
	done
}

trap cleanup EXIT
trap 'abort_publish $?' ERR
trap 'abort_publish 130' HUP INT TERM

if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then
	if [ ! -d "$TARGET" ]; then
		printf 'ERROR: OMP target is not a directory: %s\n' "$TARGET" >&2
		exit 1
	fi
else
	TARGET_WAS_ABSENT=1
fi

if ! acquire_lock; then
	exit 1
fi

if [ ! -f "$SKILLS_SETUP" ]; then
	printf 'Missing skills installer: %s\n' "$SKILLS_SETUP" >&2
	exit 1
fi

echo "==> Staging OMP agent harness config..."
mkdir -p "$SNAPSHOT"
snapshot_entry "$TARGET/agents" "$SNAPSHOT/agents"
snapshot_entry "$TARGET/commands" "$SNAPSHOT/commands"
snapshot_entry "$TARGET/extensions" "$SNAPSHOT/extensions"
snapshot_entry "$TARGET/config.yml" "$SNAPSHOT/config.yml"
snapshot_entry "$TARGET/APPEND_SYSTEM.md" "$SNAPSHOT/APPEND_SYSTEM.md"
snapshot_entry "$TARGET/WATCHDOG.md" "$SNAPSHOT/WATCHDOG.md"
snapshot_entry "$TARGET/skills" "$SNAPSHOT/omp-skills"
if [ "$CHILD_OMP_SKILLS" != "$TARGET/skills" ]; then
	snapshot_entry "$CHILD_OMP_SKILLS" "$SNAPSHOT/child-omp-skills"
fi
snapshot_entry "$SKILLS_SOURCE" "$SNAPSHOT/shared-skills"
snapshot_entry "$MANAGED_ROOT" "$SNAPSHOT/managed-root"
inspect_release_root

mkdir -p "$RELEASE_STAGE/agents" "$RELEASE_STAGE/commands" "$RELEASE_STAGE/extensions"
copy_entry "$DIR/agent/config.yml" "$RELEASE_STAGE/config.yml"
copy_entry "$DIR/agent/APPEND_SYSTEM.md" "$RELEASE_STAGE/APPEND_SYSTEM.md"
if [ -d "$DIR/agent/agents" ]; then
	copy_tree_contents "$DIR/agent/agents" "$RELEASE_STAGE/agents"
fi
if [ -d "$DIR/agent/commands" ]; then
	copy_tree_contents "$DIR/agent/commands" "$RELEASE_STAGE/commands"
fi
if [ -d "$DIR/agent/extensions" ]; then
	copy_tree_contents "$DIR/agent/extensions" "$RELEASE_STAGE/extensions"
fi
ln -s "$SKILLS_SOURCE" "$RELEASE_STAGE/skills"

echo "==> Installing curated shared skills..."
TRANSACTION_ACTIVE=1
AGENT_MEMORY_ROOT="$SKILLS_ROOT" bash "$SKILLS_SETUP"
if ! assert_lock_owner; then
	abort_publish 1
fi

echo "==> Publishing OMP agent harness config..."
PUBLISHING=1
mkdir -p "$TARGET"
ensure_release_root
NEW_RELEASE="$RELEASES_DIR/release-$INVOCATION_TOKEN"
if [ -e "$NEW_RELEASE" ] || [ -L "$NEW_RELEASE" ]; then
	printf 'ERROR: managed release name already exists: %s\n' "$NEW_RELEASE" >&2
	abort_publish 1
fi
mkdir "$NEW_RELEASE"
copy_tree_contents "$RELEASE_STAGE" "$NEW_RELEASE"
printf '%s\n' "$INVOCATION_TOKEN" > "$NEW_RELEASE/.complete-$INVOCATION_TOKEN"
mv -f "$NEW_RELEASE/.complete-$INVOCATION_TOKEN" "$NEW_RELEASE/.complete"

# Convert legacy direct entries to stable links before the current switch.
# Once converted, every managed read follows MANAGED_ROOT/current.
publish_link agents
publish_link commands
publish_link extensions
publish_link config.yml
publish_link APPEND_SYSTEM.md
publish_link skills
assert_lock_owner
remove_path "$TARGET/WATCHDOG.md"
switch_current
prune_releases

TRANSACTION_ACTIVE=0
PUBLISHING=0
trap - ERR HUP INT TERM

cat <<'MSG'
==> OMP agent harness setup restored.
    Managed: config.yml, APPEND_SYSTEM.md, shared skills link, agents, extensions, commands.
    Routed workflow: Sol control plane, GPT-5.6 Luna writing, Sol/GPT-5.6 Terra review, conditional Claude Opus.
    Local-only state left untouched: models.yml, auth, sessions, DBs, blobs.
    IMPORTANT: Stop and relaunch every existing OMP session before using this routing.
    Running sessions retain the model roles, agent definitions, and system prompt loaded at startup.
MSG
printf '    Installed target: %s\n' "$TARGET"
