# Skills audit — 2026-05-10

Loaded user skill root: `~/.agents/skills`.

## Result

Kept approved/custom items:

- `gplay-cli` in `~/.agents/skills/gplay-cli`
- Pi prompt command `/finish` in `~/.pi/agent/prompts/finish.md`
- Pi global rules in `~/.pi/agent/AGENTS.md`
- Local custom Pi extensions in `~/.pi/agent/extensions/`
- Ralph state/projects outside global skills, e.g. `~/agent-memory/.ralph` and project `.ralph` dirs

Removed from active global skills and reproducible source:

- `agents-sdk`
- `caveman`
- `caveman-commit`
- `caveman-compress`
- `caveman-help`
- `caveman-review`
- `cloudflare`
- `cloudflare-email-service`
- `durable-objects`
- `naver-local-research`
- `sandbox-sdk`
- `web-perf`
- `workers-best-practices`
- `wrangler`

Removed/disabled package installs:

- `npm:pi-markdown-preview`
- `npm:pi-simple`
- `npm:pi-subagents`
- `npm:taskplane`
- `npm:pi-mcp-adapter`
- `npm:pi-web-access`
- `npm:@plannotator/pi-extension`
- `npm:pi-lens`

## Backup

Pre-clean backup:

- `/home/typosbro/config/pi/backups/20260510-003455-pi-cleanup`

## Removed package artifacts

Moved inactive third-party package/runtime artifacts out of load/cache locations:

- `~/.pi-lens`
- `~/agent-memory/.pi-lens`
- `~/agent-memory/.pi/taskplane.json`
- `~/agent-memory/.pi/agents/supervisor.md`

Artifact backup location:

- `/home/typosbro/config/pi/backups/20260510-003455-pi-cleanup/removed-artifacts/`
