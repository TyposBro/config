# Skills audit — 2026-05-10

Loaded user skill root: `~/.agents/skills`.

## Source of truth

`~/agent-memory/skills` is the source of truth for global skills.

`~/.agents/skills` should be a symlink mirror for Pi and Agent Skills-compatible harnesses. `~/.claude/skills` should be the Claude Code compatibility mirror:

```text
~/.agents/skills -> ~/agent-memory/skills
~/.claude/skills -> ~/agent-memory/skills
```

Pi auto-discovers `~/.agents/skills`, so no copy under `~/.pi/agent/skills` is needed. Do not edit skills directly under runtime harness paths; edit `~/agent-memory/skills` and rerun `~/agent-memory/setup.sh` or `~/config/pi/setup.sh` if links need repair.

## Active managed skills

Kept in `~/agent-memory/skills`:

- `agents-sdk`
- `caveman`
- `caveman-commit`
- `caveman-compress`
- `caveman-help`
- `caveman-review`
- `cloudflare`
- `cloudflare-email-service`
- `codex-spark-e2e`
- `compress`
- `design-iteration-harness`
- `durable-objects`
- `finish`
- `finish-plan`
- `frontend-design`
- `github-project`
- `gplay-cli`
- `sandbox-sdk`
- `spec`
- `spiko-rules`
- `workers-best-practices`
- `wrangler`

## Removed from managed/live configs

- `web-perf`

Pi prompt command `/finish` remains under `~/.pi/agent/prompts/finish.md` and is intentionally separate from skills.

## Package policy

`pi/agent/settings.json` uses auto-discovered/local custom skills and extensions only:

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
