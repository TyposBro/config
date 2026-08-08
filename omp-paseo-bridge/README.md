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
