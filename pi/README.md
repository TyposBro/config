# Pi setup

Reproducible pi coding-agent setup for Kubuntu + macOS.

Managed:

- `agent/settings.json` — global pi settings/packages
- `agent/AGENTS.md` — global autonomy/progress/default behavior rules
- `skills/` — global `~/.agents/skills` without duplicates
- `setup.sh` — installs pi CLI and syncs settings/rules/skills

Not managed:

- `~/.pi/agent/auth.json` — provider/OAuth secrets
- `~/.pi/agent/sessions/` — local session history
- `~/.pi/agent/taskplane/` — runtime task state

## Restore

```bash
~/config/pi/setup.sh
```

macOS and Kubuntu setup scripts call this automatically on every run so changes to Pi rules/skills are synced without deleting setup markers.

Clean marker + rerun install step:

```bash
~/config/pi/setup.sh --clean
```

## Current audit

Kept dedicated autonomy skills:

- `finish` — open-ended end-to-end implement/debug/fix/refactor work with `AGENT_PROGRESS.md`
- `finish-plan` — explicit plan/checklist/TODO/roadmap completion with checkpoint commits/progress

Removed duplicate skill:

- `compress` duplicated `caveman-compress` purpose/scripts.
- Kept `caveman-compress` because name matches trigger family and has README/SECURITY.

Backups:

- `pi/backups/<timestamp>/` contains pre-clean snapshot of non-secret settings + skills.
