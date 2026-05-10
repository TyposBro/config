# Skills audit — 2026-05-10

Loaded user skill root: `~/.agents/skills`.

## Source of truth

`~/agent-memory/skills` is the source of truth for global skills.

`~/.agents/skills` should be a symlink mirror:

```text
~/.agents/skills -> ~/agent-memory/skills
```

Do not edit skills directly under `~/.agents/skills`; edit `~/agent-memory/skills` and rerun `~/agent-memory/setup.sh` if the link needs repair.

## Active managed skills

Kept in `~/agent-memory/skills`:

- `agents-sdk`
- `caveman`
- `cloudflare`
- `cloudflare-email-service`
- `durable-objects`
- `github-project`
- `gplay-cli`
- `sandbox-sdk`
- `spec`
- `workers-best-practices`
- `wrangler`

## Removed from managed/live configs

- `caveman-commit`
- `caveman-compress`
- `caveman-help`
- `caveman-review`
- `finish`
- `finish-plan`
- `web-perf`

Pi prompt command `/finish` remains under `~/.pi/agent/prompts/finish.md` and is intentionally separate from skills.

## Package policy

`pi/agent/settings.json` uses local/custom skills and extensions only:

- `packages: []`

Previously disabled package installs include:

- `npm:pi-markdown-preview`
- `npm:pi-simple`
- `npm:pi-subagents`
- `npm:taskplane`
- `npm:pi-mcp-adapter`
- `npm:pi-web-access`
- `npm:@plannotator/pi-extension`
- `npm:pi-lens`

## Backup

Pre-clean backups live under:

- `/home/typosbro/config/pi/backups/`

Non-secret runtime state remains outside source control:

- `~/.pi/agent/auth.json`
- `~/.pi/agent/sessions/`
- `~/.pi/agent/taskplane/`
- `~/.pi/agent/ralph-loop/`
- `~/.agents/.skill-lock.json`
- `~/.agents/pi-lens/`
