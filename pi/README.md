# Pi setup

Reproducible pi coding-agent setup for Kubuntu + macOS.

Managed:

- `agent/settings.json` — global pi settings/packages
- `agent/AGENTS.md` — global autonomy/progress/default behavior rules
- `skills/` — global `~/.agents/skills` without duplicates
- `extensions/` — global `~/.pi/agent/extensions` automation helpers
- `setup.sh` — installs pi CLI and syncs settings/rules/skills/extensions

Not managed:

- `~/.pi/agent/auth.json` — provider/OAuth secrets
- `~/.pi/agent/sessions/` — local session history
- `~/.pi/agent/taskplane/` — runtime task state
- `~/.pi/agent/ralph-loop/` — Ralph loop run logs/state

## Restore

```bash
~/config/pi/setup.sh
```

macOS and Kubuntu setup scripts call this automatically on every run so changes to Pi rules/skills/extensions are synced without deleting setup markers.

Clean marker + rerun install step:

```bash
~/config/pi/setup.sh --clean
```

For pi-lens cleanup, set project cache root to avoid per-repo `~/.pi-lens` state:

```bash
export PILENS_DATA_DIR="$HOME/.agents/pi-lens/projects"
```

(Managed shell configs in `home/shared/shell.nix` and `mac/config/fish/config.fish` set this automatically for interactive shells.)

## Current audit

Kept skills in `pi/skills`:

- `caveman`
- `cloudflare`
- `cloudflare-email-service`
- `durable-objects`
- `agents-sdk`
- `gplay-cli`
- `sandbox-sdk`
- `workers-best-practices`
- `wrangler`

Removed to keep the set focused:

- `caveman-commit`, `caveman-compress`, `caveman-help`, `caveman-review`
- `finish`, `finish-plan`
- `web-perf`

Managed automation extension:

- `ralph-loop` — `/ralph <plan.md>` runs one milestone at a time in fresh Pi subprocess sessions: medium/default implementation, xhigh review, then next milestone. Use `/ralph-status` to inspect the latest run.

Backups:

- `pi/backups/<timestamp>/` contains pre-clean snapshot of non-secret settings + skills.
