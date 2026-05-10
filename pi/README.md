# Pi setup

Reproducible pi coding-agent setup for Kubuntu + macOS.

Managed:

- `agent/settings.json` — global pi settings/packages
- `skills/` — global `~/.agents/skills` without duplicates
- `setup.sh` — installs pi CLI and syncs settings/skills

Not managed:

- `~/.pi/agent/auth.json` — provider/OAuth secrets
- `~/.pi/agent/sessions/` — local session history
- `~/.pi/agent/taskplane/` — runtime task state

## Restore

```bash
~/config/pi/setup.sh
```

Clean marker + rerun install step:

```bash
~/config/pi/setup.sh --clean
```

## Current audit

Pi is locked down to approved/custom resources only:

- No third-party Pi packages in `agent/settings.json` (`packages: []`).
- Only `gplay-cli` is managed under `skills/` / `~/.agents/skills`.
- Custom Pi rules and prompt commands remain under `~/.pi/agent/`.
- Local custom extensions remain under `~/.pi/agent/extensions/`.
- Ralph state/project dirs are not managed by this setup and were left intact.

Backups:

- `pi/backups/<timestamp>/` contains pre-clean snapshots of non-secret settings + skills.
