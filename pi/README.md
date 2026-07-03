# Pi setup

Reproducible pi coding-agent setup for Kubuntu + macOS.

`~/config/pi` manages Pi installation/settings/extensions. Agent/harness memory and global skills live in `~/agent-memory`; runtime locations under `~/.pi` and `~/.agents` should be treated as generated mirrors, not edited directly.

Managed:

- `agent/settings.json` — global pi settings/packages
- `agent/AGENTS.md` — global autonomy/progress/default behavior rules copied to `~/.pi/agent/AGENTS.md`; includes the `~/Documents/private/spiko/rules.md` trigger for "follow the rules"
- global skills links — `~/.agents/skills` and `~/.claude/skills` point to `~/agent-memory/skills` when agent-memory is present
- `extensions/` — global Pi extensions copied/synced to `~/.pi/agent/extensions`
- `setup.sh` — installs Pi CLI and links/syncs settings/rules/extensions; skills are linked from agent-memory

Not managed:

- `~/.pi/agent/auth.json` — provider/OAuth secrets
- `~/.pi/agent/sessions/` — local session history
- `~/.pi/agent/taskplane/` — runtime task state
- `~/.agents/.skill-lock.json` — local skill UI/selection state
- `~/.agents/pi-lens/` — local Pi Lens project cache/runtime state

## Restore

```bash
~/config/pi/setup.sh
```

macOS and Kubuntu setup scripts call this automatically on every run so changes to Pi rules/skills/extensions are applied without deleting setup markers.

Clean marker + rerun install step:

```bash
~/config/pi/setup.sh --clean
```

For pi-lens cleanup, set project cache root to avoid per-repo `~/.pi-lens` state:

```bash
export PILENS_DATA_DIR="$HOME/.agents/pi-lens/projects"
```

(Managed shell configs in `home/shared/shell.nix` and `mac/config/fish/config.fish` set this automatically for interactive shells.)

## Skill source of truth

Edit skills only under:

```text
~/agent-memory/skills/
```

`setup.sh` makes these links when `~/agent-memory/skills` exists:

```text
~/.agents/skills -> ~/agent-memory/skills
~/.claude/skills -> ~/agent-memory/skills
```

Pi auto-discovers `~/.agents/skills`, so no copy under `~/.pi/agent/skills` is needed. Claude Code uses the compatibility `~/.claude/skills` link. If either link path already exists as a real directory, setup moves it to a timestamped backup before creating the symlink.

## AI model shortcuts (reproducible)

This repo includes quick provider/model/thinking profiles for pi and other CLIs:

- `aispark [cli] [args...]` → `openai-codex/gpt-5.3-codex-spark` + `medium`
- `ai_high [cli] [args...]` → `openai-codex/gpt-5.5` + `high`
- `ai_xhigh [cli] [args...]` → `openai-codex/gpt-5.5` + `xhigh`
- `ai_reviewer [cli] [args...]` → `openai-codex/gpt-5.5` + `xhigh`
- `ai_oracle [cli] [args...]` → `openai-codex/gpt-5.5` + `xhigh`
- `ai_explore [cli] [args...]` → `google/gemini-3.1-pro-preview` + `high`
- `ai_quick_task [cli] [args...]` → `deepseek/deepseek-v4-pro` + `medium`

`cli` defaults to `pi`. You can pass `codex`, `opencode`, or `claude`; `codex` rejects non-`openai-codex` profiles.
Examples:

- `aispark` (defaults to pi)
- `ai_reviewer codex`
- `ai_explore pi --continue`
- `ai_quick_task pi -p "rename this file-safe string"`

Aliases are also provided for short names:

- `spark`
- `high`
- `xhigh`
- `reviewer`
- `oracle`
- `explore`
- `quick_task`

These are defined in `shell/model-shortcuts.fish` and are loaded by
`mac/config/fish/config.fish`.

If you also use bash/zsh, source `pi/shell/model-shortcuts.sh` from your startup file
(e.g., `.bashrc`/`.zshrc`) to get the same commands.

## Current audit

Active managed skills in `~/agent-memory/skills`:

- `agents-sdk`
- `caveman`
- `caveman-commit`
- `caveman-compress`
- `caveman-help`
- `caveman-review`
- `cloudflare`
- `cloudflare-email-service`
- `compress`
- `context7-cli`
- `context7-mcp`
- `design-iteration-harness`
- `durable-objects`
- `find-docs`
- `finish-plan`
- `github-project`
- `gplay-cli`
- `frontend-design`
- `sandbox-sdk`
- `spec`
- `workers-best-practices`
- `wrangler`

Removed from active managed skills:

- `web-perf`

Pi prompt command `/finish` remains under `~/.pi/agent/prompts/finish.md` and is intentionally not managed here.

No third-party Pi packages are installed by `agent/settings.json`; custom skills are managed from `~/agent-memory` via `~/.agents/skills`, and custom Pi extensions are managed locally from this repo.

Backups:

- `pi/backups/<timestamp>/` contains pre-clean snapshots of non-secret settings + skills.
