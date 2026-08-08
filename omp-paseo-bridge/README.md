# omp-paseo-bridge

Reproducible bridge between **Oh My Pi (omp)** and **Paseo**: run the full omp engine (hashline edits, LSP/DAP, subagents, memory, 60+ providers) from Paseo's desktop/web/mobile UI — no terminal — with omp's workflows exposed as slash commands that autocomplete in Paseo's composer.

Why this exists: Paseo has shipped a native OMP provider since v0.2.0 (July 24, 2026) and loads slash commands/skills into OMP agents since v0.1.100 — but the provider is **disabled by default**, and omp's *TUI* slash commands (`/model`, `/vibe`, `/review`, …) never appear in Paseo's composer. This kit:

1. Enables the built-in `omp` provider (+ an `omp-main` profile) in `~/.paseo/config.json` — idempotent deep merge, your existing config is preserved and backed up.
2. Installs an `omp-*` skills pack into `~/.agents/skills/` — each skill maps one omp feature to a Paseo slash command with composer autocomplete.
3. Verifies the whole setup.

## Prerequisites

- Paseo ≥ 0.2.0 (0.2.4+ recommended; 0.3.x beta for Command-Center model/mode/plan switching) — `npm install -g @getpaseo/cli` or the desktop app from paseo.sh/download
- omp installed — `curl -fsSL https://omp.sh/install | sh`
- `jq`

## Install

```sh
./install.sh                 # provider config + omp-* skills
./install.sh --with-paseo-skills   # also install getpaseo/paseo orchestration skills (/paseo, /paseo-handoff, /paseo-loop, /paseo-committee, /paseo-advisor)
```

Then **restart Paseo** (desktop: quit & relaunch; CLI: `paseo daemon restart`) and check:

```sh
./verify.sh
paseo provider ls            # expect omp + omp-main
```

In the composer, type `/` — `omp-review`, `omp-vibe`, `omp-committee`, `omp-advisor`, `omp-memory`, `omp-subagents`, `omp-plan`, `omp-ultrathink` autocomplete.

## Uninstall

```sh
./uninstall.sh               # removes omp/omp-main providers + omp-* skills; leaves Paseo skills and your config backups
```

## Import your existing omp sessions

Continue terminal omp sessions from Paseo (they import with title, cwd, and model; full history loads on resume):

```sh
./import-sessions.sh            # imports every session under the omp sessionDir (idempotent)
paseo ls -a                     # see imported agents
paseo send <agent-id> "continue"  # resume one
```

Or use the app's import picker (it calls the same `listImportableSessions` API), or the CLI directly:

```sh
paseo agent import <session-id> --provider omp --cwd <path>
```

Sessions live in `~/.paseo`-configured `params.sessionDir` (here `~/config/omp/agent/sessions`), one `<timestamp>_<session-id>.jsonl` per session grouped by cwd directory. The daemon dedupes by native session id, so re-running the script is safe.

## What's in the pack

| Skill | omp feature it bridges |
|---|---|
| `/omp-review` | `/review` — parallel reviewer subagents, P0–P3 findings, ship/no-ship verdict |
| `/omp-vibe` | `/vibe` — director mode driving `fast`/`good` worker sessions |
| `/omp-committee` | committee planning — two analysis-only subagents, synthesis, then implement on approval |
| `/omp-advisor` | `/advisor` — second-opinion subagent, analysis only, no edits |
| `/omp-memory` | `retain`/`recall`/`reflect`/`learn` — agent-curated project memory |
| `/omp-subagents` | `task` fan-out — parallel worktree-isolated workers, typed outputs |
| `/omp-plan` | plan mode — recon, present plan, await approval, implement, verify |
| `/omp-ultrathink` | `ultrathink` keyword — explicit deep-reasoning turn |

Everything else in omp is engine-level and already works under Paseo (Paseo drives `omp --mode rpc-ui`): all 31 tools, LSP, DAP, time-traveling stream rules, extensions, web_search, browser/computer. Model roles map to Paseo via `params` (below) or the Command-Center model picker. `/collab` is redundant — Paseo's phone/web/relay access is the same feature. Only TUI-only bits (`/fresh`, hotkeys) need a terminal; run raw `omp` in a Paseo workspace terminal tab if you ever need them.

## Provider model visibility (why your models were missing)

Paseo spawns agent CLIs with the **daemon's environment**, not your interactive shell's. If your shell redirects a CLI's config/auth via an env var or a PATH entry, Paseo misses it:

| Provider | Root cause | Fix (applied by `install.sh`) |
|---|---|---|
| omp | shell exports `PI_CONFIG_DIR` (e.g. `config/omp`); daemon doesn't → spawned omp uses `~/.omp` and shows only its auth (DeepSeek official) | provider `env.PI_CONFIG_DIR` inherited from the installing shell (pass it explicitly if your shell lacks it: `PI_CONFIG_DIR=config/omp ./install.sh`) |
| opencode | binary lives at `~/.opencode/bin`, not on the daemon PATH → provider "unavailable" | symlink `~/.opencode/bin/opencode` → `~/.local/bin/opencode` |
| codex | working routes are `--profile`-based (deepseek / opencode-go-deepseek); Paseo launches plain `app-server` → only the base default (direct DeepSeek) is visible | base `codex` provider reset to OpenAI first-party (GPT catalog, 2026-08-08: `model_catalog_json` dropped, `models.json` parked as `deepseek-models.json`); `codex-go` profile added via Paseo's documented `OPENAI_BASE_URL`+`OPENAI_API_KEY` endpoint override (key read from `OPENCODE_GO_API_KEY` env or `~/agent-memory/hermes/.env` at install time — never stored in this repo). NOTE: OpenAI auth required before GPT calls work: `codex login` once, or set `OPENAI_API_KEY` |
| pi | no `pi` binary installed on this machine (`~/.pi` has only worktrees); nothing to bridge — omp *is* your pi | n/a; install `pi` only if you actually use the vanilla CLI |

After install, verify: `paseo provider ls` (all available), `paseo provider models omp` (opencode-go / codex / antigravity / deepseek).

## Tuning

Model roles (`smol`/`slow`/`plan`) come from omp's own `config.yml` `modelRoles` by default. To pin them per Paseo profile, edit `config/omp-provider.json` before installing:

```json
"omp-main": {
  "extends": "omp",
  "label": "Oh My Pi (main)",
  "params": {
    "smolModel": "openai/gpt-5-mini",
    "slowModel": "anthropic/claude-opus-4-1",
    "planModel": "openai/o3"
  }
}
```

List real model IDs with `omp models <provider>`. `params.sessionDir` imports sessions started outside Paseo; multiple profiles with `command` + `env` (`XDG_CONFIG_HOME`/`XDG_STATE_HOME`) give isolated omp setups.

## Publishing

The skills live in `.agents/skills/` (canonical Agent Skills layout). Publish this directory as its own repo (or push to a repo root) and install anywhere with:

```sh
npx skills add <owner>/<repo>
```

## Layout

```
omp-paseo-bridge/
├── README.md
├── install.sh / uninstall.sh / verify.sh
├── config/omp-provider.json     # Paseo provider fragment (deep-merged into ~/.paseo/config.json)
└── .agents/skills/omp-*/SKILL.md
```
