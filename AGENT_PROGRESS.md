# AGENT_PROGRESS.md

## Current Task
Add a Pi Ralph-loop automation extension that can run milestone implementation/review cycles in fresh contexts with medium implementation thinking and xhigh review thinking.

## Current Checklist
- [x] Read Pi extension/SDK/skills docs and relevant examples.
- [x] Choose extension over skill for true context clearing and thinking-level control.
- [x] Add repo-managed `ralph-loop` extension and standalone runner.
- [x] Add `/ralph` and `/ralph-status` commands.
- [x] Store Ralph loop state outside target repos by default.
- [x] Update Pi setup script to sync extensions.
- [x] Update Pi docs.
- [x] Sync extension into live `~/.pi/agent/extensions`.
- [x] Validate setup script, extension loading, and dry-run flow.
- [x] Commit stable logical chunk if appropriate.

## Current Completed Work
- Added `pi/extensions/ralph-loop/index.ts` Pi extension.
- Added `pi/extensions/ralph-loop/ralph-loop.mjs` runner that loops milestones with fresh nested Pi sessions.
- Added `pi/extensions/ralph-loop/README.md` usage docs.
- Updated `pi/setup.sh` to sync repo-managed extensions into `~/.pi/agent/extensions` without deleting unrelated extensions.
- Updated root and Pi README docs to mention `/ralph`.
- Validated standalone runner dry-run against Spiko Instagram Reels Spark plan.
- Validated `/ralph --help` and `/ralph ... --dry-run` through Pi extension loading.
- Ran `pi/setup.sh` to sync the extension into live `~/.pi/agent/extensions/ralph-loop`.
- Validated live auto-discovery with `/ralph-status`.

## Current Tests Run
- `node --check pi/extensions/ralph-loop/ralph-loop.mjs`
- `node /Users/typosbro/nixos-config/pi/extensions/ralph-loop/ralph-loop.mjs specs/todo/03-instagram-reels-spark-plan.md --from 1 --to 2 --dry-run --cwd /Users/typosbro/Documents/private/spiko`
- `PI_OFFLINE=1 pi --no-extensions -e ./pi/extensions/ralph-loop/index.ts --mode json --no-session --no-tools -p "/ralph --help"`
- `PI_OFFLINE=1 pi --no-extensions -e /Users/typosbro/nixos-config/pi/extensions/ralph-loop/index.ts --mode json --no-session --no-tools -p "/ralph specs/todo/03-instagram-reels-spark-plan.md --from 1 --to 1 --dry-run"`
- `bash -n pi/setup.sh mac/setup.sh linux/kubuntu/setup.sh`
- `git diff --check`
- Temp-home `HOME="$TMP_HOME" bash pi/setup.sh` sync test — verified settings, rules, skills, and `ralph-loop` extension copied without CLI reinstall.
- `bash pi/setup.sh`
- `PI_OFFLINE=1 pi --no-extensions -e ~/.pi/agent/extensions/ralph-loop/index.ts --mode json --no-session --no-tools -p "/ralph-status"`
- `PI_OFFLINE=1 pi --mode json --no-session --no-tools -p "/ralph-status"` — validated auto-discovered live extension.
- Fake nested-Pi loop test with a temp plan and fake `pi` binary — verified implement + review stages both run and state becomes `complete` without calling a real model.
- `shellcheck pi/setup.sh mac/setup.sh linux/kubuntu/setup.sh` — not run because `shellcheck` is not installed.

## Current Commits
- `feat(pi): add ralph loop extension`

## Current Blockers
- None.

## Current Exact Next Action
- Done; optional next action is `git push` when ready.

---

## Previous Task
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
