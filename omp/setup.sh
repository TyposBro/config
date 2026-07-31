#!/usr/bin/env bash
# Reproduce TyposBro OMP agent harness policy/config. Safe to re-run.

set -Eeuo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_INPUT="${PI_CODING_AGENT_DIR:-$HOME/.omp/agent}"
SKILLS_SOURCE_INPUT="${AGENT_MEMORY_ROOT:-$HOME/agent-memory}/skills"

# Normalize a path even when its final components do not exist. Resolve the
# nearest existing ancestor strictly so dangling links, loops, and inaccessible
# paths are rejected instead of producing an ambiguous identity.
normalize_path() {
	python3 - "$1" <<'PY'
import os
import sys

raw = sys.argv[1]
if not raw or "\x00" in raw:
    print("path is empty or contains NUL", file=sys.stderr)
    raise SystemExit(1)
try:
    absolute = os.path.abspath(raw)
    if not os.path.isabs(absolute):
        raise ValueError("absolute normalization failed")
    probe = absolute
    while not os.path.lexists(probe):
        parent = os.path.dirname(probe)
        if parent == probe:
            raise OSError("no existing ancestor")
        probe = parent
    resolved_probe = os.path.realpath(probe, strict=True)
    if not os.path.exists(resolved_probe):
        raise OSError("existing ancestor cannot be resolved")
    canonical = os.path.realpath(absolute)
    if not canonical or not os.path.isabs(canonical):
        raise ValueError("realpath normalization failed")
    if os.path.lexists(absolute) and not os.path.exists(canonical):
        raise OSError("path resolves through a missing target")
except (OSError, RuntimeError, ValueError) as exc:
    print(f"cannot normalize path: {exc}", file=sys.stderr)
    raise SystemExit(1)
print(canonical)
PY
}

if ! CANONICAL_TARGET="$(normalize_path "$TARGET_INPUT")"; then
	printf 'ERROR: cannot determine the canonical OMP target: %s\n' "$TARGET_INPUT" >&2
	exit 1
fi
if ! SKILLS_SOURCE="$(normalize_path "$SKILLS_SOURCE_INPUT")"; then
	printf 'ERROR: cannot determine the canonical shared skills source: %s\n' "$SKILLS_SOURCE_INPUT" >&2
	exit 1
fi
TARGET="$CANONICAL_TARGET"

# The host orchestrator owns the shared skills installation. OMP only links
# its target-scoped release to this already-existing canonical directory.
if [ ! -d "$SKILLS_SOURCE" ] || [ -L "$SKILLS_SOURCE" ]; then
	printf 'ERROR: canonical shared skills source is not a directory: %s\n' "$SKILLS_SOURCE" >&2
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
TARGET_WAS_ABSENT=0
RELEASE_ROOT_WAS_ABSENT=0
CURRENT_WAS_PRESENT=0
PREVIOUS_CURRENT_TARGET=""
PREVIOUS_RELEASE_PATH=""
NEW_RELEASE=""
LEGACY_RELEASE=""
CURRENT_BASELINE=""

MANAGED_ROOT="$CANONICAL_TARGET/.omp-routing"
RELEASES_DIR="$MANAGED_ROOT/releases"
CANONICAL_RELEASES_DIR=""
if ! CANONICAL_RELEASES_DIR="$(normalize_path "$RELEASES_DIR")"; then
	printf 'ERROR: cannot determine the canonical managed release inventory: %s\n' "$RELEASES_DIR" >&2
	exit 1
fi
CURRENT_PATH="$MANAGED_ROOT/current"
ROUTING_MARKER="$MANAGED_ROOT/.managed-by-omp-setup"
ROUTING_MARKER_VALUE="omp-routing-v1"
SNAPSHOT="$STAGE/snapshot"
RELEASE_STAGE="$STAGE/release"

remove_path() {
	local path="$1"

	if [ -z "$path" ]; then
		printf 'ERROR: refusing to remove an empty path.\n' >&2
		return 1
	fi
	if [ -e "$path" ] || [ -L "$path" ]; then
		if ! rm -rf "$path"; then
			printf 'ERROR: could not remove path: %s\n' "$path" >&2
			return 1
		fi
	fi
	if [ -e "$path" ] || [ -L "$path" ]; then
		printf 'ERROR: path remains after removal: %s\n' "$path" >&2
		return 1
	fi
}

ensure_directory() {
	local path="$1"

	if [ -z "$path" ]; then
		printf 'ERROR: refusing to create an empty directory path.\n' >&2
		return 1
	fi
	if ! mkdir -p "$path"; then
		printf 'ERROR: could not create directory: %s\n' "$path" >&2
		return 1
	fi
	if [ ! -d "$path" ] || [ -L "$path" ]; then
		printf 'ERROR: created path is not a real directory: %s\n' "$path" >&2
		return 1
	fi
}

copy_entry() {
	local source="$1"
	local destination="$2"
	local link_target
	local child
	local name

	if [ -L "$source" ]; then
		if ! link_target="$(readlink "$source")"; then
			printf 'ERROR: could not read managed source link: %s\n' "$source" >&2
			return 1
		fi
		if ! ensure_directory "$(dirname "$destination")"; then
			return 1
		fi
		if ! ln -s "$link_target" "$destination"; then
			printf 'ERROR: could not copy managed source link: %s\n' "$source" >&2
			return 1
		fi
		if [ ! -L "$destination" ]; then
			printf 'ERROR: copied link is missing: %s\n' "$destination" >&2
			return 1
		fi
	elif [ -d "$source" ]; then
		if ! ensure_directory "$destination"; then
			return 1
		fi
		for child in "$source"/* "$source"/.[!.]* "$source"/..?*; do
			[ -e "$child" ] || [ -L "$child" ] || continue
			name="${child##*/}"
			if ! copy_entry "$child" "$destination/$name"; then
				return 1
			fi
		done
	elif [ -f "$source" ]; then
		if ! ensure_directory "$(dirname "$destination")"; then
			return 1
		fi
		if ! cp -p "$source" "$destination"; then
			printf 'ERROR: could not copy managed source file: %s\n' "$source" >&2
			return 1
		fi
		if [ ! -f "$destination" ] || [ -L "$destination" ]; then
			printf 'ERROR: copied file is missing: %s\n' "$destination" >&2
			return 1
		fi
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

	if [ ! -d "$source" ] || [ -L "$source" ]; then
		printf 'ERROR: managed tree source is not a real directory: %s\n' "$source" >&2
		return 1
	fi
	if ! ensure_directory "$destination"; then
		return 1
	fi
	for child in "$source"/* "$source"/.[!.]* "$source"/..?*; do
		[ -e "$child" ] || [ -L "$child" ] || continue
		name="${child##*/}"
		if ! copy_entry "$child" "$destination/$name"; then
			return 1
		fi
	done
}

snapshot_entry() {
	local source="$1"
	local destination="$2"
	local link_target

	if ! ensure_directory "$destination"; then
		return 1
	fi
	if [ -L "$source" ]; then
		if ! printf '%s\n' symlink > "$destination/type"; then
			return 1
		fi
		if ! link_target="$(readlink "$source")"; then
			printf 'ERROR: could not read source link for snapshot: %s\n' "$source" >&2
			return 1
		fi
		if ! printf '%s\n' "$link_target" > "$destination/link"; then
			return 1
		fi
	elif [ -d "$source" ]; then
		if ! printf '%s\n' directory > "$destination/type"; then
			return 1
		fi
		if ! ensure_directory "$destination/data"; then
			return 1
		fi
		if ! copy_tree_contents "$source" "$destination/data"; then
			return 1
		fi
	elif [ -f "$source" ]; then
		if ! printf '%s\n' file > "$destination/type"; then
			return 1
		fi
		if ! cp -p "$source" "$destination/data"; then
			printf 'ERROR: could not snapshot source file: %s\n' "$source" >&2
			return 1
		fi
		if [ ! -f "$destination/data" ] || [ -L "$destination/data" ]; then
			printf 'ERROR: file snapshot is missing: %s\n' "$destination/data" >&2
			return 1
		fi
	elif [ -e "$source" ]; then
		printf 'ERROR: unsupported managed path type: %s\n' "$source" >&2
		return 1
	else
		if ! printf '%s\n' absent > "$destination/type"; then
			return 1
		fi
	fi
}

restore_entry() {
	local snapshot_path="$1"
	local destination="$2"
	local entry_type
	local link_target

	if ! entry_type="$(cat "$snapshot_path/type")"; then
		printf 'ERROR: recovery snapshot type is unreadable: %s\n' "$snapshot_path" >&2
		return 1
	fi
	if ! remove_path "$destination"; then
		return 1
	fi
	case "$entry_type" in
		absent)
			if [ -e "$destination" ] || [ -L "$destination" ]; then
				printf 'ERROR: absent snapshot could not remove destination: %s\n' "$destination" >&2
				return 1
			fi
			;;
		symlink)
			if ! link_target="$(cat "$snapshot_path/link")"; then
				printf 'ERROR: recovery snapshot link is unreadable: %s\n' "$snapshot_path" >&2
				return 1
			fi
			if ! ensure_directory "$(dirname "$destination")"; then
				return 1
			fi
			if ! ln -s "$link_target" "$destination"; then
				printf 'ERROR: could not restore snapshot link: %s\n' "$destination" >&2
				return 1
			fi
			if [ ! -L "$destination" ]; then
				printf 'ERROR: restored snapshot link is missing: %s\n' "$destination" >&2
				return 1
			fi
			;;
		file)
			if ! ensure_directory "$(dirname "$destination")"; then
				return 1
			fi
			if ! cp -p "$snapshot_path/data" "$destination"; then
				printf 'ERROR: could not restore snapshot file: %s\n' "$destination" >&2
				return 1
			fi
			if [ ! -f "$destination" ] || [ -L "$destination" ]; then
				printf 'ERROR: restored snapshot file is missing: %s\n' "$destination" >&2
				return 1
			fi
			;;
		directory)
			if ! copy_tree_contents "$snapshot_path/data" "$destination"; then
				return 1
			fi
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
		if ! assert_lock_owner; then
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
	if ! rm -f "$LOCK_OWNER_FILE"; then
		printf 'ERROR: could not remove the OMP installer lock owner at %s.\n' "$LOCK_OWNER_FILE" >&2
		return 1
	fi
	if [ -e "$LOCK_OWNER_FILE" ] || [ -L "$LOCK_OWNER_FILE" ]; then
		printf 'ERROR: OMP installer lock owner remains at %s.\n' "$LOCK_OWNER_FILE" >&2
		return 1
	fi
	if ! rmdir "$LOCK_DIR"; then
		printf 'ERROR: could not remove the OMP installer lock at %s; preserving it.\n' "$LOCK_DIR" >&2
		return 1
	fi
	LOCK_HELD=0
}

restore_snapshot_entry() {
	local snapshot_path="$1"
	local destination="$2"

	if ! assert_lock_owner; then
		return 1
	fi
	if ! restore_entry "$snapshot_path" "$destination"; then
		return 1
	fi
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
	return "$status"
}

rollback_transaction() {
	local status=0

	if ! assert_lock_owner; then
		return 1
	fi
	restore_snapshot_entry "$SNAPSHOT/managed-root" "$MANAGED_ROOT" || status=1
	restore_snapshots || status=1
	if [ "$TARGET_WAS_ABSENT" -eq 1 ]; then
		if assert_lock_owner; then
			if [ -L "$TARGET" ]; then
				printf 'ERROR: target became a symlink during rollback: %s\n' "$TARGET" >&2
				status=1
			elif [ -d "$TARGET" ]; then
				if ! rmdir "$TARGET"; then
					printf 'ERROR: could not remove newly-created empty target: %s\n' "$TARGET" >&2
					status=1
				fi
				if [ -d "$TARGET" ] || [ -L "$TARGET" ]; then
					status=1
				fi
			elif [ -e "$TARGET" ]; then
				printf 'ERROR: target became an unexpected path during rollback: %s\n' "$TARGET" >&2
				status=1
			fi
		else
			status=1
		fi
	fi
	return "$status"
}

abort_publish() {
	local status="${1:-1}"
	local rollback_status=0

	if [ "$ABORTING" -eq 1 ]; then
		:
		exit "$status"
	fi
	ABORTING=1
	KEEP_RECOVERY=1
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
	else
		KEEP_RECOVERY=1
		printf 'ERROR: OMP setup failed before publication; recovery material preserved at: %s\n' "$STAGE" >&2
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
			if ! remove_path "$STAGE"; then
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

validate_release_path() {
	local path="$1"
	local mode="$2"
	local required="$3"

	if [ ! -e "$path" ] && [ ! -L "$path" ]; then
		if [ "$required" -eq 1 ]; then
			printf 'ERROR: required release entry is missing: %s\n' "$path" >&2
			return 1
		fi
		return 0
	fi
	if [ -L "$path" ] && [ ! -e "$path" ]; then
		printf 'ERROR: release entry is a broken link: %s\n' "$path" >&2
		return 1
	fi
	case "$mode" in
		file)
			if [ ! -f "$path" ]; then
				printf 'ERROR: release entry is not a file: %s\n' "$path" >&2
				return 1
			fi
			;;
		directory)
			if [ ! -d "$path" ]; then
				printf 'ERROR: release entry is not a directory: %s\n' "$path" >&2
				return 1
			fi
			;;
		any)
			;;
		*)
			printf 'ERROR: invalid release validation mode: %s\n' "$mode" >&2
			return 1
			;;
	esac
}

validate_release_contents() {
	local release="$1"

	validate_release_path "$release/config.yml" file 1 || return 1
	validate_release_path "$release/APPEND_SYSTEM.md" file 1 || return 1
	validate_release_path "$release/skills" directory 1 || return 1
	validate_release_path "$release/agents" directory 0 || return 1
	validate_release_path "$release/commands" directory 0 || return 1
	validate_release_path "$release/extensions" directory 0 || return 1
}

validate_direct_release() {
	local release="$1"
	local canonical_release
	local release_name

	if ! canonical_release="$(normalize_path "$release")"; then
		printf 'ERROR: release path cannot be normalized: %s\n' "$release" >&2
		return 1
	fi
	if [ "$canonical_release" != "$release" ]; then
		printf 'ERROR: release path is not canonical: %s\n' "$release" >&2
		return 1
	fi
	if [ "${canonical_release%/*}" != "$CANONICAL_RELEASES_DIR" ]; then
		printf 'ERROR: release path is not a direct child of the release inventory: %s\n' \
			"$release" >&2
		return 1
	fi
	release_name="${canonical_release##*/}"
	case "$release_name" in
		release-?*)
			;;
		*)
			printf 'ERROR: release path has an invalid name: %s\n' "$release" >&2
			return 1
			;;
	esac
	if [ ! -d "$release" ] || [ -L "$release" ]; then
		printf 'ERROR: release path is not a non-symlink directory: %s\n' "$release" >&2
		return 1
	fi
	if [ ! -f "$release/.complete" ] || [ -L "$release/.complete" ]; then
		printf 'ERROR: release is not marked complete: %s\n' "$release" >&2
		return 1
	fi
	validate_release_contents "$release"
}

inspect_release_root() {
	local current_resolved

	if [ -e "$MANAGED_ROOT" ] || [ -L "$MANAGED_ROOT" ]; then
		RELEASE_ROOT_WAS_ABSENT=0
		validate_release_root || return 1
		if [ -L "$CURRENT_PATH" ]; then
			CURRENT_WAS_PRESENT=1
			if ! PREVIOUS_CURRENT_TARGET="$(readlink "$CURRENT_PATH")"; then
				return 1
			fi
			if [ -z "$PREVIOUS_CURRENT_TARGET" ]; then
				printf 'ERROR: managed release current link is empty: %s\n' "$CURRENT_PATH" >&2
				return 1
			fi
			if ! current_resolved="$(normalize_path "$CURRENT_PATH")"; then
				printf 'ERROR: managed release current link cannot be normalized: %s\n' "$CURRENT_PATH" >&2
				return 1
			fi
			validate_direct_release "$current_resolved" || return 1
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
	local current_resolved

	if ! assert_lock_owner; then
		return 1
	fi
	if [ "$RELEASE_ROOT_WAS_ABSENT" -eq 1 ]; then
		if [ -e "$MANAGED_ROOT" ] || [ -L "$MANAGED_ROOT" ]; then
			printf 'ERROR: managed release metadata appeared during setup: %s\n' "$MANAGED_ROOT" >&2
			return 1
		fi
		if ! ensure_directory "$RELEASES_DIR"; then
			return 1
		fi
		marker_tmp="$MANAGED_ROOT/.managed-by-omp-setup-$INVOCATION_TOKEN"
		if [ -e "$ROUTING_MARKER" ] || [ -L "$ROUTING_MARKER" ] || \
			[ -e "$marker_tmp" ] || [ -L "$marker_tmp" ]; then
			printf 'ERROR: managed release marker appeared during setup: %s\n' "$ROUTING_MARKER" >&2
			return 1
		fi
		if ! printf '%s\n' "$ROUTING_MARKER_VALUE" > "$marker_tmp"; then
			printf 'ERROR: could not stage managed release marker: %s\n' "$marker_tmp" >&2
			return 1
		fi
		if ! mv -f "$marker_tmp" "$ROUTING_MARKER"; then
			printf 'ERROR: could not publish managed release marker: %s\n' "$ROUTING_MARKER" >&2
			return 1
		fi
		if [ ! -f "$ROUTING_MARKER" ] || [ -L "$ROUTING_MARKER" ]; then
			printf 'ERROR: managed release marker is missing: %s\n' "$ROUTING_MARKER" >&2
			return 1
		fi
	else
		validate_release_root || return 1
		if [ ! -d "$RELEASES_DIR" ]; then
			if ! ensure_directory "$RELEASES_DIR"; then
				return 1
			fi
		fi
		if [ "$CURRENT_WAS_PRESENT" -eq 1 ]; then
			if [ ! -L "$CURRENT_PATH" ]; then
				printf 'ERROR: managed release current switch changed during setup: %s\n' "$CURRENT_PATH" >&2
				return 1
			fi
			if ! current_target="$(readlink "$CURRENT_PATH")" || \
				[ "$current_target" != "$PREVIOUS_CURRENT_TARGET" ]; then
				printf 'ERROR: managed release current link changed during setup: %s\n' "$CURRENT_PATH" >&2
				return 1
			fi
			if ! current_resolved="$(normalize_path "$CURRENT_PATH")" || \
				[ "$current_resolved" != "$PREVIOUS_RELEASE_PATH" ]; then
				printf 'ERROR: managed release current target changed during setup: %s\n' "$CURRENT_PATH" >&2
				return 1
			fi
		elif [ -e "$CURRENT_PATH" ] || [ -L "$CURRENT_PATH" ]; then
			printf 'ERROR: managed release current switch appeared during setup: %s\n' "$CURRENT_PATH" >&2
			return 1
		fi
	fi
}

ensure_target_directory() {
	if ! assert_lock_owner; then
		return 1
	fi
	if [ "$TARGET_WAS_ABSENT" -eq 1 ]; then
		if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then
			printf 'ERROR: OMP target appeared during setup: %s\n' "$TARGET" >&2
			return 1
		fi
		if ! ensure_directory "$TARGET"; then
			return 1
		fi
	else
		if [ -L "$TARGET" ] || [ ! -d "$TARGET" ]; then
			printf 'ERROR: OMP target topology changed during setup: %s\n' "$TARGET" >&2
			return 1
		fi
	fi
}

switch_current() {
	local release="$1"
	local expected="${2:-}"
	local switch_tmp="$MANAGED_ROOT/.current-$INVOCATION_TOKEN"
	local current_resolved

	if ! assert_lock_owner; then
		return 1
	fi
	validate_direct_release "$release" || return 1
	if [ -n "$expected" ]; then
		if [ ! -L "$CURRENT_PATH" ]; then
			printf 'ERROR: current switch precondition changed: %s\n' "$CURRENT_PATH" >&2
			return 1
		fi
		if ! current_resolved="$(normalize_path "$CURRENT_PATH")" || \
			[ "$current_resolved" != "$expected" ]; then
			printf 'ERROR: current switch target changed: %s\n' "$CURRENT_PATH" >&2
			return 1
		fi
	else
		if [ -e "$CURRENT_PATH" ] || [ -L "$CURRENT_PATH" ]; then
			printf 'ERROR: current switch destination unexpectedly exists: %s\n' "$CURRENT_PATH" >&2
			return 1
		fi
	fi
	if ! remove_path "$switch_tmp"; then
		return 1
	fi
	if ! ln -s "$release" "$switch_tmp"; then
		printf 'ERROR: could not stage current release switch: %s\n' "$switch_tmp" >&2
		return 1
	fi
	if [ ! -L "$switch_tmp" ]; then
		printf 'ERROR: staged current release switch is missing: %s\n' "$switch_tmp" >&2
		return 1
	fi
	# Replace the stable symlink itself atomically; do not traverse its target directory.
	if ! python3 -c 'import os, sys; os.replace(sys.argv[1], sys.argv[2])' "$switch_tmp" "$CURRENT_PATH"; then
		printf 'ERROR: could not atomically switch the managed release: %s\n' "$CURRENT_PATH" >&2
		return 1
	fi
	if [ ! -L "$CURRENT_PATH" ]; then
		printf 'ERROR: atomic current switch did not produce a symlink: %s\n' "$CURRENT_PATH" >&2
		return 1
	fi
	if ! current_resolved="$(normalize_path "$CURRENT_PATH")" || [ "$current_resolved" != "$release" ]; then
		printf 'ERROR: atomic current switch resolved to an unexpected release: %s\n' "$CURRENT_PATH" >&2
		return 1
	fi
}

is_required_entry() {
	case "$1" in
		config.yml|APPEND_SYSTEM.md|skills)
			return 0
			;;
		*)
			return 1
			;;
	esac
}

atomic_exchange_paths() {
	local staged="$1"
	local destination="$2"

	if ! python3 - "$staged" "$destination" <<'PY'
import ctypes
import errno
import os
import platform
import sys

system = platform.system()
if system == "Linux":
    symbol = "renameat2"
elif system == "Darwin":
    symbol = "renamex_np"
else:
    print(
        f"ERROR: atomic link exchange is unsupported on {system or 'this platform'}.",
        file=sys.stderr,
    )
    raise SystemExit(errno.ENOTSUP)

try:
    libc = ctypes.CDLL(None, use_errno=True)
    exchange = getattr(libc, symbol)
except (AttributeError, OSError) as exc:
    print(
        f"ERROR: atomic link exchange is unavailable ({symbol}): {exc}",
        file=sys.stderr,
    )
    raise SystemExit(errno.ENOSYS)

exchange.restype = ctypes.c_int
source = os.fsencode(sys.argv[1])
target = os.fsencode(sys.argv[2])
if system == "Linux":
    exchange.argtypes = [
        ctypes.c_int,
        ctypes.c_char_p,
        ctypes.c_int,
        ctypes.c_char_p,
        ctypes.c_uint,
    ]
    result = exchange(-100, source, -100, target, 2)
else:
    exchange.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_uint]
    result = exchange(source, target, 2)

if result != 0:
    error_number = ctypes.get_errno() or errno.EIO
    print(
        f"ERROR: atomic link exchange failed [{error_number}]: "
        f"{os.strerror(error_number)}",
        file=sys.stderr,
    )
    raise SystemExit(error_number)
PY
	then
		printf 'ERROR: could not atomically exchange the managed routing entry: %s\n' \
			"$destination" >&2
		return 1
	fi
}

publish_link() {
	local name="$1"
	local desired="$MANAGED_ROOT/current/$name"
	local destination="$TARGET/$name"
	local stage="$MANAGED_ROOT/.publish-$name"
	local existing_target
	local destination_present=0

	if ! assert_lock_owner; then
		return 1
	fi
	if [ ! -e "$desired" ] && [ ! -L "$desired" ]; then
		if is_required_entry "$name"; then
			printf 'ERROR: required routing entry is absent from the current release: %s\n' "$desired" >&2
			return 1
		fi
		if ! remove_path "$destination"; then
			return 1
		fi
		if ! remove_path "$stage"; then
			return 1
		fi
		return 0
	fi
	if [ -L "$destination" ]; then
		if ! existing_target="$(readlink "$destination")"; then
			return 1
		fi
		if [ "$existing_target" = "$desired" ]; then
			if ! remove_path "$stage"; then
				return 1
			fi
			return 0
		fi
	fi
	if [ -e "$destination" ] || [ -L "$destination" ]; then
		destination_present=1
	fi
	if ! remove_path "$stage"; then
		return 1
	fi
	if ! ln -s "$desired" "$stage"; then
		printf 'ERROR: could not stage managed routing link: %s\n' "$stage" >&2
		return 1
	fi
	if [ ! -L "$stage" ]; then
		printf 'ERROR: staged managed routing link is missing: %s\n' "$stage" >&2
		return 1
	fi
	if ! assert_lock_owner; then
		return 1
	fi
	if [ "$destination_present" -eq 1 ]; then
		if ! atomic_exchange_paths "$stage" "$destination"; then
			return 1
		fi
		if [ ! -L "$destination" ]; then
			printf 'ERROR: atomic routing exchange did not produce a symlink: %s\n' \
				"$destination" >&2
			return 1
		fi
		if ! remove_path "$stage"; then
			printf 'ERROR: could not remove the previous routing entry after exchange: %s\n' \
				"$stage" >&2
			return 1
		fi
	else
		if ! python3 -c 'import os, sys; os.replace(sys.argv[1], sys.argv[2])' \
			"$stage" "$destination"; then
			printf 'ERROR: could not atomically publish managed routing link: %s\n' \
				"$destination" >&2
			return 1
		fi
	fi
	if [ ! -L "$destination" ]; then
		printf 'ERROR: published managed routing link is missing: %s\n' "$destination" >&2
		return 1
	fi
}


publish_all_links() {
	publish_link agents || return 1
	publish_link commands || return 1
	publish_link extensions || return 1
	publish_link config.yml || return 1
	publish_link APPEND_SYSTEM.md || return 1
	publish_link skills || return 1
}

snapshot_type_is_absent() {
	local snapshot_path="$1"
	local entry_type

	if ! entry_type="$(cat "$snapshot_path/type")"; then
		return 1
	fi
	[ "$entry_type" = absent ]
}

legacy_inventory_present() {
	local entry_snapshot

	for entry_snapshot in \
		"$SNAPSHOT/agents" \
		"$SNAPSHOT/commands" \
		"$SNAPSHOT/extensions" \
		"$SNAPSHOT/config.yml" \
		"$SNAPSHOT/APPEND_SYSTEM.md" \
		"$SNAPSHOT/omp-skills"; do
		if ! snapshot_type_is_absent "$entry_snapshot"; then
			return 0
		fi
	done
	return 1
}

legacy_required_state() {
	local entry_snapshot
	local required_present=0
	local required_missing=0
	local entry_type

	for entry_snapshot in \
		"$SNAPSHOT/config.yml" \
		"$SNAPSHOT/APPEND_SYSTEM.md" \
		"$SNAPSHOT/omp-skills"; do
		if ! entry_type="$(cat "$entry_snapshot/type")"; then
			return 1
		fi
		if [ "$entry_type" = absent ]; then
			required_missing=1
		else
			required_present=1
		fi
	done
	if [ "$required_present" -eq 0 ]; then
		return 2
	fi
	if [ "$required_missing" -eq 1 ]; then
		return 1
	fi
	return 0
}

materialize_legacy_symlink() {
	local snapshot_path="$1"
	local original_path="$2"
	local destination="$3"
	local link_target
	local absolute_target

	if ! link_target="$(cat "$snapshot_path/link")"; then
		printf 'ERROR: legacy snapshot link is unreadable: %s\n' "$snapshot_path" >&2
		return 1
	fi
	case "$link_target" in
		/*)
			absolute_target="$link_target"
			;;
		*)
			if ! absolute_target="$(normalize_path "$(dirname "$original_path")/$link_target")"; then
				printf 'ERROR: legacy relative link cannot be normalized: %s\n' "$original_path" >&2
				return 1
			fi
			;;
	esac
	if ! ensure_directory "$(dirname "$destination")"; then
		return 1
	fi
	if ! ln -s "$absolute_target" "$destination"; then
		printf 'ERROR: could not materialize legacy link: %s\n' "$destination" >&2
		return 1
	fi
	if [ ! -L "$destination" ]; then
		printf 'ERROR: materialized legacy link is missing: %s\n' "$destination" >&2
		return 1
	fi
}

materialize_legacy_entry() {
	local snapshot_path="$1"
	local original_path="$2"
	local destination="$3"
	local entry_type

	if ! entry_type="$(cat "$snapshot_path/type")"; then
		return 1
	fi
	case "$entry_type" in
		absent)
			return 0
			;;
		symlink)
			materialize_legacy_symlink "$snapshot_path" "$original_path" "$destination"
			;;
		file|directory)
			restore_entry "$snapshot_path" "$destination"
			;;
		*)
			printf 'ERROR: invalid legacy snapshot: %s\n' "$snapshot_path" >&2
			return 1
			;;
	esac
}

mark_release_complete() {
	local release="$1"
	local marker_tmp="$release/.complete-$INVOCATION_TOKEN"

	if [ -e "$release/.complete" ] || [ -L "$release/.complete" ] || \
		[ -e "$marker_tmp" ] || [ -L "$marker_tmp" ]; then
		printf 'ERROR: release completion marker already exists: %s\n' "$release" >&2
		return 1
	fi
	if ! printf '%s\n' "$INVOCATION_TOKEN" > "$marker_tmp"; then
		printf 'ERROR: could not stage release completion marker: %s\n' "$marker_tmp" >&2
		return 1
	fi
	if ! mv -f "$marker_tmp" "$release/.complete"; then
		printf 'ERROR: could not publish release completion marker: %s\n' "$release" >&2
		return 1
	fi
	if [ ! -f "$release/.complete" ] || [ -L "$release/.complete" ]; then
		printf 'ERROR: release completion marker is missing: %s\n' "$release" >&2
		return 1
	fi
}

materialize_legacy_release() {
	LEGACY_RELEASE="$RELEASES_DIR/release-legacy-$INVOCATION_TOKEN"
	if [ -e "$LEGACY_RELEASE" ] || [ -L "$LEGACY_RELEASE" ]; then
		printf 'ERROR: legacy release name already exists: %s\n' "$LEGACY_RELEASE" >&2
		return 1
	fi
	if ! mkdir "$LEGACY_RELEASE"; then
		printf 'ERROR: could not create legacy release: %s\n' "$LEGACY_RELEASE" >&2
		return 1
	fi
	if ! materialize_legacy_entry "$SNAPSHOT/agents" "$TARGET/agents" "$LEGACY_RELEASE/agents"; then return 1; fi
	if ! materialize_legacy_entry "$SNAPSHOT/commands" "$TARGET/commands" "$LEGACY_RELEASE/commands"; then return 1; fi
	if ! materialize_legacy_entry "$SNAPSHOT/extensions" "$TARGET/extensions" "$LEGACY_RELEASE/extensions"; then return 1; fi
	if ! materialize_legacy_entry "$SNAPSHOT/config.yml" "$TARGET/config.yml" "$LEGACY_RELEASE/config.yml"; then return 1; fi
	if ! materialize_legacy_entry "$SNAPSHOT/APPEND_SYSTEM.md" "$TARGET/APPEND_SYSTEM.md" "$LEGACY_RELEASE/APPEND_SYSTEM.md"; then return 1; fi
	if ! materialize_legacy_entry "$SNAPSHOT/omp-skills" "$TARGET/skills" "$LEGACY_RELEASE/skills"; then return 1; fi
	validate_release_contents "$LEGACY_RELEASE" || return 1
	mark_release_complete "$LEGACY_RELEASE" || return 1
	validate_direct_release "$LEGACY_RELEASE"
}

create_new_release() {
	NEW_RELEASE="$RELEASES_DIR/release-$INVOCATION_TOKEN"
	if [ -e "$NEW_RELEASE" ] || [ -L "$NEW_RELEASE" ]; then
		printf 'ERROR: managed release name already exists: %s\n' "$NEW_RELEASE" >&2
		return 1
	fi
	if ! mkdir "$NEW_RELEASE"; then
		printf 'ERROR: could not create managed release: %s\n' "$NEW_RELEASE" >&2
		return 1
	fi
	if ! copy_tree_contents "$RELEASE_STAGE" "$NEW_RELEASE"; then
		return 1
	fi
	validate_release_contents "$NEW_RELEASE" || return 1
	mark_release_complete "$NEW_RELEASE" || return 1
	validate_direct_release "$NEW_RELEASE"
}

prune_releases() {
	local candidate
	local candidate_name
	local candidate_canonical

	if ! assert_lock_owner; then
		return 1
	fi
	[ "$CURRENT_WAS_PRESENT" -eq 1 ] || return 0
	for candidate in "$RELEASES_DIR"/release-*; do
		[ -e "$candidate" ] || [ -L "$candidate" ] || continue
		candidate_name="${candidate##*/}"
		case "$candidate_name" in
			release-?*)
				;;
			*)
				continue
				;;
		esac
		[ -d "$candidate" ] || continue
		[ -L "$candidate" ] && continue
		if ! candidate_canonical="$(normalize_path "$candidate")"; then
			printf 'ERROR: release candidate cannot be normalized: %s\n' "$candidate" >&2
			return 1
		fi
		[ "$candidate_canonical" = "$candidate" ] || continue
		[ "${candidate_canonical%/*}" = "$CANONICAL_RELEASES_DIR" ] || continue
		[ -f "$candidate/.complete" ] || continue
		[ ! -L "$candidate/.complete" ] || continue
		[ "$candidate" = "$NEW_RELEASE" ] && continue
		[ "$candidate" = "$PREVIOUS_RELEASE_PATH" ] && continue
		if ! assert_lock_owner; then
			return 1
		fi
		if ! remove_path "$candidate"; then
			return 1
		fi
	done
}

revalidate_after_lock() {
	local target_again
	local skills_again

	if ! target_again="$(normalize_path "$TARGET_INPUT")"; then
		printf 'ERROR: OMP target could not be normalized after lock acquisition.\n' >&2
		return 1
	fi
	if [ "$target_again" != "$CANONICAL_TARGET" ]; then
		printf 'ERROR: OMP target identity changed while acquiring the lock: %s\n' "$TARGET_INPUT" >&2
		return 1
	fi
	if ! skills_again="$(normalize_path "$SKILLS_SOURCE_INPUT")"; then
		printf 'ERROR: shared skills source could not be normalized after lock acquisition.\n' >&2
		return 1
	fi
	if [ "$skills_again" != "$SKILLS_SOURCE" ]; then
		printf 'ERROR: shared skills source identity changed while acquiring the lock: %s\n' \
			"$SKILLS_SOURCE_INPUT" >&2
		return 1
	fi
	if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then
		if [ -L "$TARGET" ] || [ ! -d "$TARGET" ]; then
			printf 'ERROR: OMP target is not a directory: %s\n' "$TARGET" >&2
			return 1
		fi
		TARGET_WAS_ABSENT=0
	else
		TARGET_WAS_ABSENT=1
	fi
	if [ ! -d "$SKILLS_SOURCE" ] || [ -L "$SKILLS_SOURCE" ]; then
		printf 'ERROR: canonical shared skills source is not a directory: %s\n' "$SKILLS_SOURCE" >&2
		return 1
	fi
}

trap cleanup EXIT
trap 'abort_publish $?' ERR
trap 'abort_publish 130' HUP INT TERM

if ! acquire_lock; then
	exit 1
fi
revalidate_after_lock

if ! ensure_directory "$SNAPSHOT"; then
	abort_publish 1
fi
snapshot_entry "$TARGET/agents" "$SNAPSHOT/agents"
snapshot_entry "$TARGET/commands" "$SNAPSHOT/commands"
snapshot_entry "$TARGET/extensions" "$SNAPSHOT/extensions"
snapshot_entry "$TARGET/config.yml" "$SNAPSHOT/config.yml"
snapshot_entry "$TARGET/APPEND_SYSTEM.md" "$SNAPSHOT/APPEND_SYSTEM.md"
snapshot_entry "$TARGET/WATCHDOG.md" "$SNAPSHOT/WATCHDOG.md"
snapshot_entry "$TARGET/skills" "$SNAPSHOT/omp-skills"
snapshot_entry "$MANAGED_ROOT" "$SNAPSHOT/managed-root"
inspect_release_root

if ! ensure_directory "$RELEASE_STAGE"; then
	abort_publish 1
fi
ensure_directory "$RELEASE_STAGE/agents"
ensure_directory "$RELEASE_STAGE/commands"
ensure_directory "$RELEASE_STAGE/extensions"
copy_entry "$DIR/agent/config.yml" "$RELEASE_STAGE/config.yml"
copy_entry "$DIR/agent/APPEND_SYSTEM.md" "$RELEASE_STAGE/APPEND_SYSTEM.md"
if [ -d "$DIR/agent/agents" ] && [ ! -L "$DIR/agent/agents" ]; then
	copy_tree_contents "$DIR/agent/agents" "$RELEASE_STAGE/agents"
fi
if [ -d "$DIR/agent/commands" ] && [ ! -L "$DIR/agent/commands" ]; then
	copy_tree_contents "$DIR/agent/commands" "$RELEASE_STAGE/commands"
fi
if [ -d "$DIR/agent/extensions" ] && [ ! -L "$DIR/agent/extensions" ]; then
	copy_tree_contents "$DIR/agent/extensions" "$RELEASE_STAGE/extensions"
fi
if [ ! -d "$SKILLS_SOURCE" ] || [ -L "$SKILLS_SOURCE" ]; then
	printf 'ERROR: canonical shared skills source disappeared before staging: %s\n' "$SKILLS_SOURCE" >&2
	abort_publish 1
fi
if ! ln -s "$SKILLS_SOURCE" "$RELEASE_STAGE/skills"; then
	printf 'ERROR: could not stage the shared skills link: %s\n' "$RELEASE_STAGE/skills" >&2
	abort_publish 1
fi
if [ ! -L "$RELEASE_STAGE/skills" ]; then
	printf 'ERROR: staged shared skills link is missing: %s\n' "$RELEASE_STAGE/skills" >&2
	abort_publish 1
fi
validate_release_contents "$RELEASE_STAGE"

TRANSACTION_ACTIVE=1
ensure_target_directory
ensure_release_root

LEGACY_STATE=2
if [ "$CURRENT_WAS_PRESENT" -eq 0 ] && legacy_inventory_present; then
	if legacy_required_state; then
		LEGACY_STATE=0
	else
		LEGACY_STATE=$?
	fi
	case "$LEGACY_STATE" in
		0)
			materialize_legacy_release
			switch_current "$LEGACY_RELEASE"
			CURRENT_BASELINE="$LEGACY_RELEASE"
			publish_all_links
			;;
		1)
			printf 'ERROR: existing OMP routing inventory is missing a required legacy entry; refusing migration.\n' >&2
			abort_publish 1
			;;
		2)
			# Only optional legacy entries exist; leave them untouched until the
			# complete new release is ready, then replace them with stable links.
			;;
		*)
			printf 'ERROR: could not classify the legacy OMP routing inventory.\n' >&2
			abort_publish 1
			;;
	esac
elif [ "$CURRENT_WAS_PRESENT" -eq 1 ]; then
	CURRENT_BASELINE="$PREVIOUS_RELEASE_PATH"
	publish_all_links
fi

create_new_release
if [ -n "$CURRENT_BASELINE" ]; then
	switch_current "$NEW_RELEASE" "$CURRENT_BASELINE"
else
	switch_current "$NEW_RELEASE"
fi
CURRENT_BASELINE="$NEW_RELEASE"
publish_all_links
if ! assert_lock_owner; then
		abort_publish 1
fi
remove_path "$TARGET/WATCHDOG.md"
prune_releases

TRANSACTION_ACTIVE=0
trap - ERR HUP INT TERM

cat <<'MSG'
==> OMP agent harness setup restored.
    Managed: config.yml, APPEND_SYSTEM.md, shared skills link, agents, extensions, commands.
    Shared skills source: existing host-managed canonical directory (linked, not installed or mutated by OMP).
    Routed workflow: Sol control plane, GPT-5.6 Luna writing, Sol/GPT-5.6 Terra review, conditional Claude Opus.
    Local-only state left untouched: models.yml, auth, sessions, DBs, blobs.
    IMPORTANT: Stop and relaunch every existing OMP session before using this routing.
    Running sessions retain the model roles, agent definitions, and system prompt loaded at startup.
MSG
printf '    Installed target: %s\n' "$TARGET"
printf '    Shared skills link: %s -> %s\n' "$TARGET/skills" "$SKILLS_SOURCE"
