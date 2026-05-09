# Skills audit — 2026-05-09

Loaded user skill root: `~/.agents/skills`.

## Result

Kept 15 skills:

- `agents-sdk`
- `caveman`
- `caveman-commit`
- `caveman-compress`
- `caveman-help`
- `caveman-review`
- `cloudflare`
- `cloudflare-email-service`
- `durable-objects`
- `finish`
- `finish-plan`
- `sandbox-sdk`
- `web-perf`
- `workers-best-practices`
- `wrangler`

Added dedicated autonomy skills:

- `finish` for open-ended end-to-end implement/debug/fix/refactor tasks.
- `finish-plan` for explicit plan/checklist/TODO/roadmap completion.

Removed duplicate:

- `compress`

## Why

`compress` and `caveman-compress` had the same purpose and identical `scripts/` implementation. `caveman-compress` is better canonical name because it matches the caveman skill family and includes extra `README.md` + `SECURITY.md`.

No other exact duplicate skill implementations found.
