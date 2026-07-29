#!/usr/bin/env python3
"""Validate the curated skill installation without mutating it."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import tempfile
import urllib.request


ROOT = Path(__file__).resolve().parent
CONFIG_ROOT = ROOT.parent
MANIFEST_PATH = ROOT / "manifest.json"
SKILLS_ROOT = Path(
    os.environ.get("AGENT_MEMORY_ROOT", str(Path.home() / "agent-memory"))
) / "skills"


def tree_digest(root: Path) -> str:
    digest = hashlib.sha256()
    for path in sorted(item for item in root.rglob("*") if item.is_file()):
        digest.update(path.relative_to(root).as_posix().encode())
        digest.update(b"\0")
        digest.update(path.read_bytes())
        digest.update(b"\0")
    return digest.hexdigest()


def frontmatter(text: str) -> str:
    if not text.startswith("---\n"):
        return ""
    end = text.find("\n---\n", 4)
    return text[4:end] if end != -1 else ""


def resolved(path: Path) -> Path | None:
    try:
        return path.resolve(strict=True)
    except FileNotFoundError:
        return None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--skip-archive",
        action="store_true",
        help="skip the network checksum check after setup already verified it",
    )
    args = parser.parse_args()

    manifest = json.loads(MANIFEST_PATH.read_text())
    upstream = manifest["upstream"]
    local = manifest["local"]
    managed = upstream + local
    managed_names = {skill["name"] for skill in managed}
    rejected = set(manifest["rejected"])
    allowed_extras = set(manifest["allowedExtras"])
    errors: list[str] = []
    warnings: list[str] = []

    names = [skill["name"] for skill in managed]
    if len(names) != len(set(names)):
        errors.append("manifest contains duplicate managed skill names")
    if managed_names & rejected:
        errors.append("manifest lists managed skills as rejected")
    if (managed_names | rejected) & allowed_extras:
        errors.append("allowed extras overlap managed or rejected skills")
    for skill in managed:
        if skill["invocation"] not in {"autonomous", "user"}:
            errors.append(f'{skill["name"]}: invalid invocation policy')

    if not args.skip_archive:
        source = manifest["source"]
        url = source["url"].format(commit=source["commit"])
        try:
            with tempfile.NamedTemporaryFile() as archive:
                with urllib.request.urlopen(url, timeout=30) as response:
                    archive.write(response.read())
                archive.flush()
                actual = hashlib.sha256(Path(archive.name).read_bytes()).hexdigest()
            if actual != source["sha256"]:
                errors.append(
                    f'upstream archive checksum mismatch: expected {source["sha256"]}, got {actual}'
                )
        except OSError as error:
            errors.append(f"could not verify upstream archive: {error}")

    installed_names = (
        {path.name for path in SKILLS_ROOT.iterdir() if path.is_dir()}
        if SKILLS_ROOT.is_dir()
        else set()
    )
    for name in sorted(managed_names - installed_names):
        errors.append(f"missing managed skill: {name}")
    for name in sorted(rejected & installed_names):
        errors.append(f"rejected skill is installed: {name}")
    for name in sorted(installed_names - managed_names - allowed_extras):
        warnings.append(f"unclassified host-local skill: {name}")

    for skill in managed:
        name = skill["name"]
        skill_file = SKILLS_ROOT / name / "SKILL.md"
        if not skill_file.is_file():
            continue
        metadata = frontmatter(skill_file.read_text())
        is_user_invoked = "disable-model-invocation: true" in metadata
        if skill["invocation"] == "user" and not is_user_invoked:
            errors.append(f"{name}: user-invoked policy is missing")
        if skill["invocation"] == "autonomous" and is_user_invoked:
            errors.append(f"{name}: autonomous invocation is disabled")

    for skill in local:
        source = CONFIG_ROOT / "skills" / skill["name"]
        installed = SKILLS_ROOT / skill["name"]
        if not source.is_dir():
            errors.append(f'{skill["name"]}: repo-owned source is missing')
        elif installed.is_dir() and tree_digest(source) != tree_digest(installed):
            errors.append(f'{skill["name"]}: installed copy differs from repo-owned source')

    expected_root = resolved(SKILLS_ROOT)
    for path in (
        Path.home() / ".agents/skills",
        Path.home() / ".claude/skills",
        Path.home() / ".omp/agent/skills",
    ):
        if not path.is_symlink():
            errors.append(f"expected skill-directory symlink: {path}")
        elif resolved(path) != expected_root:
            errors.append(f"skill-directory link targets the wrong path: {path}")

    codex_root = Path.home() / ".codex/skills"
    for name in sorted(installed_names):
        link = codex_root / name
        if not link.is_symlink() or resolved(link) != resolved(SKILLS_ROOT / name):
            errors.append(f"Codex skill link is missing or incorrect: {name}")
    for name in sorted(rejected):
        if (codex_root / name).exists() or (codex_root / name).is_symlink():
            errors.append(f"rejected Codex skill is installed: {name}")

    opencode_path = Path.home() / ".config/opencode/opencode.json"
    try:
        opencode = json.loads(opencode_path.read_text())
        configured_paths = opencode.get("skills", {}).get("paths", [])
    except (OSError, json.JSONDecodeError) as error:
        errors.append(f"could not read OpenCode skill configuration: {error}")
        configured_paths = []
    expected_paths = {str(SKILLS_ROOT / name) for name in installed_names}
    configured_managed = {
        str(path) for path in configured_paths if str(path).startswith(str(SKILLS_ROOT) + "/")
    }
    if configured_managed != expected_paths:
        errors.append("OpenCode canonical skill paths do not match the installed inventory")
    if len(configured_paths) != len(set(map(str, configured_paths))):
        errors.append("OpenCode skill paths contain duplicates")

    discoverable_backups = []
    for parent in (
        Path.home() / ".agents",
        Path.home() / ".claude",
        Path.home() / ".omp/agent",
        codex_root,
    ):
        if parent.is_dir():
            discoverable_backups.extend(parent.glob("*.backup.*"))
    for backup in discoverable_backups:
        if backup.is_dir():
            errors.append(f"discoverable skill backup must be relocated: {backup}")

    for warning in warnings:
        print(f"WARN: {warning}")
    for error in errors:
        print(f"ERROR: {error}")
    if errors:
        print(f"Skill configuration check failed with {len(errors)} error(s).")
        return 1

    print(
        f"Skill configuration check passed: {len(managed_names)} managed, "
        f"{len(installed_names & allowed_extras)} allowed host-local."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
