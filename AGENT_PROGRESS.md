# AGENT_PROGRESS.md

## Task
Copy the current Pi autonomous finish/finish-plan setup into the `nixos-config` dotfiles repo so macOS and Kubuntu setup installs it out of the box.

## Checklist
- [x] Inspect current live Pi setup and dotfiles Pi setup.
- [x] Add managed global Pi rules to repo and install script.
- [x] Add separate `finish` and `finish-plan` skills to repo-managed skills.
- [x] Align Pi settings/install version where needed.
- [x] Update docs for restore behavior.
- [x] Validate shell scripts, JSON, and skill discovery.
- [x] Commit stable logical chunk.
- [x] Record final state.

## Completed work
- Read live `~/.pi/agent/skills/finish/SKILL.md`.
- Checked repo status: clean on `main...origin/main`.
- Inspected `pi/setup.sh`, `pi/README.md`, `pi/agent/settings.json`, root `README.md`, `mac/setup.sh`, and `linux/kubuntu/setup.sh`.
- Copied live global Pi rules into `pi/agent/AGENTS.md`.
- Added repo-managed `pi/skills/finish/SKILL.md` and `pi/skills/finish-plan/SKILL.md`.
- Updated `pi/setup.sh` to install `@earendil-works/pi-coding-agent@0.74.0`, copy `AGENTS.md`, sync skills, and avoid reinstalling when the current version already matches.
- Updated macOS and Kubuntu setup scripts to sync Pi setup on every run, not only the first marked run.
- Updated Pi settings to `lastChangelogVersion` 0.74.0, `defaultThinkingLevel` xhigh, and `hideThinkingBlock` true while preserving existing package list.
- Updated docs/audit to mention managed global rules and the separate `finish`/`finish-plan` skills.
- Validated scripts, JSON, skill discovery, temp-home setup sync, and whitespace.

## Remaining work
- None.

## Tests run
- `git status --short`
- `git status --branch --porcelain=v1`
- File inspection via `read`
- `bash -n pi/setup.sh mac/setup.sh linux/kubuntu/setup.sh`
- `python3 -m json.tool pi/agent/settings.json >/dev/null`
- `node --input-type=module ... loadSkillsFromDir({ dir: '/Users/typosbro/nixos-config/pi/skills' })` — found 15 skills including `finish` and `finish-plan`, zero diagnostics
- Temp-home `HOME="$TMP_HOME" bash pi/setup.sh` sync test — verified settings, global rules, `finish`, and `finish-plan` files installed without CLI reinstall when current version matches
- `git diff --check`
- `shellcheck pi/setup.sh mac/setup.sh linux/kubuntu/setup.sh` — not run because `shellcheck` is not installed

## Commits
- `2cc66fb` — `feat(pi): sync finish skills setup`

## Blockers
- None.

## Exact next action
- Done; optional next user action is `git push` when ready.
