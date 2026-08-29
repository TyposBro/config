# typosbro's Config

NixOS 25.11 · Flakes · GNOME · x86_64-linux
macOS · Homebrew · aarch64-darwin

## Structure

```
home/
  shared/    # git, neovim, vscode, fish, ghostty, starship, packages (Linux)
  linux/     # GTK theming, rofi, GNOME keybindings, Linux-only packages
hosts/
  nixos/     # NixOS system config (GDM + GNOME)
mac/
  Brewfile    # all macOS packages and apps
  setup.sh    # idempotent setup — safe to re-run
  defaults.sh # macOS system settings (dock, finder, key repeat)
  config/     # fish, ghostty, starship dotfiles
pi/           # pi coding-agent settings/extensions (skills live in ~/agent-memory)
codex/        # Codex epic skills and custom agents
```

## macOS

### Fresh install

```bash
git clone https://github.com/TyposBro/config.git ~/config
~/config/mac/setup.sh --clean
```

Runs every step: brew bundle, symlink configs, fish theme, macOS defaults, Rust toolchain, Claude Code, pi setup, shared agent skills, canonical OMP routing, Codex setup, and fish as default shell. Shared skills run before OMP routing; both components are safe to re-run.

### Update / add a package

Edit `mac/Brewfile`, then:

```bash
~/config/mac/setup.sh
```

Skips already-done steps. Only `brew bundle` runs — picks up new packages.

### Force re-run one step

```bash
rm ~/.local/state/config-mac/<step>
~/config/mac/setup.sh
```

Step names: `configs`, `fish-theme`, `defaults`, `rust`, `claude-code`, `pi`.

### What's managed

| Thing                              | How                                       |
| ---------------------------------- | ----------------------------------------- |
| Packages & apps                    | `mac/Brewfile` (`brew bundle`)            |
| Dotfiles (fish, ghostty, starship) | `mac/config/` (symlinked to `~/.config/`) |
| macOS defaults                     | `mac/defaults.sh` (`defaults write`)      |
| Rust toolchain                     | `rustup`                                  |
| Claude Code CLI                    | `claude.ai/install.sh`                    |
| Pi settings/extensions             | `pi/setup.sh`                             |
| Codex epic workflow                | `codex/setup.sh`                          |
| Infisical CLI                      | `mac/Brewfile`                            |

## Linux (NixOS)

### Fresh install

```bash
# 1. Clone the repo
nix --extra-experimental-features "nix-command flakes" \
  run nixpkgs#git -- clone https://github.com/TyposBro/config.git ~/config

# 2. Regenerate hardware config for this machine
sudo nixos-generate-config --show-hardware-config \
  > ~/config/hosts/nixos/hardware-configuration.nix

# 3. Apply
sudo nixos-rebuild switch --flake ~/config#nixos
```

> Always regenerate `hardware-configuration.nix` on new hardware — never copy it from another machine.

### Rebuild / update

```bash
nr   # rebuild
nru  # flake update + rebuild
ngc  # delete old generations
```

### Managed CLIs

Infisical CLI is installed by `home/shared/packages.nix` on NixOS and `linux/kubuntu/setup.sh` on Kubuntu.

### Pi coding agent

Pi setup is backed up/reproducible under `pi/`:

```bash
~/config/pi/setup.sh
```

Kubuntu + macOS setup scripts call Pi setup automatically on every run, then run `omp/setup.sh`; OMP setup installs the curated shared skills as part of its run. The shared-skills installer owns the canonical global inventory: pinned third-party skills are checksum-verified, repo-owned skills override them, rejected skills are pruned, and unknown manually installed skills are preserved but reported by the checker. Pi and Claude discover the canonical set through `~/agent-memory/skills`; OMP setup installs and uses the curated set within the same run.

### OMP coding agent

OMP agent-harness setup is backed up/reproducible under `omp/`:

Run the focused installer directly:

```bash
~/config/omp/setup.sh
```

This restores the active OMP agent directory (default `~/.omp/agent`) with the shared CTO workflow and capability-based role routing. Sol remains the main control plane. The built-in `task` role handles implementation through `@task`; `reviewer` and `security-reviewer` provide fresh review through `@review`; `designer` stays read-only. Provider credentials, auth, sessions, databases, blobs, and `models.yml` stay local.

Managed slash commands are `/epic` and `/epics`. They load the installed provider-independent skills and map implementer, reviewer, adversarial-reviewer, and optional design-advisor roles to agents exposed by the current resolver. No workflow depends on legacy `luna-fast`, `sol-reviewer`, `terra-pro`, or `opus-reviewer` aliases, resolver fingerprint attestation, or worker-side CAS/fencing features the host does not expose.

After running the installer, stop and relaunch every OMP session. Existing sessions retain the model roles, agents, and system prompt loaded at startup; installing files does not hot-reload them.

### Codex coding agent

The OMP epic delivery contract has a Codex-native port:

```bash
~/config/codex/setup.sh
```

This installs personal `$epic` and `$epics` skills plus `epic_builder`, `sol_reviewer`, `adversarial_reviewer`, and `epic_designer` custom agents. Codex uses its native subagent threads and a three-worker concurrency budget. The main Sol task remains the control plane; Terra is the sole writer; Sol and auto-review provide independent frozen-SHA review. The workflow preserves durable GitHub checkpoints and fenced Git locks and stops before merge, deployment, production mutation, pricing changes, or issue closure unless explicitly authorized.

Restart Codex or open a new task after installation so custom agents are discovered.

`omp/setup.sh` installs the checked-in OMP config, commands, themes, and supported custom agents; removes deprecated named-role files; and links `APPEND_SYSTEM.md` to the canonical shared CTO workflow in `~/agent-memory/shared/cto-workflow.md`. Provider credentials, auth, sessions, databases, blobs, and `models.yml` remain local-only and untouched. Named profiles have separate agent directories; install each explicitly with `PI_CODING_AGENT_DIR=~/.omp/profiles/<name>/agent ~/config/omp/setup.sh`.

### Curated agent skills

Run:

```bash
~/config/agent-skills/setup.sh
```

Validate the installed inventory without changing it:

```bash
~/config/agent-skills/setup.sh --check
```

`agent-skills/manifest.json` is the source of truth for upstream pins, invocation policy, rejected skills, and any explicitly allowed host-local extras. No host-local skill exceptions are currently allowed, so every machine converges on the same inventory.

The managed set is intentionally small:

- Autonomous: `grilling`
- Manual workflows: `prototype`, `diagnosing-bugs`, `handoff`, `writing-great-skills`, `wise-teacher`
- Manual specialist references: `tdd`, `codebase-design`, `domain-modeling`

`prototype` cleans up throwaway code unless preservation is explicitly requested. `diagnosing-bugs` prefers a tight reproduction loop without blocking targeted source inspection. The installer removes the audited workflow bundle that caused automatic commits, issue-tracker ceremony, unsafe merge completion, or unnecessary subagent/document creation.

### Keybindings (GNOME, Caps Lock = Super)

| Binding                  | Action                   |
| ------------------------ | ------------------------ |
| `Super + Space`          | Rofi app launcher        |
| `Super + Return`         | Terminal (Ghostty)       |
| `Super + Shift + Return` | Browser (Zen)            |
| `Super + e`              | File Manager (Nautilus)  |
| `Super + q`              | Close window             |
| `Super + f`              | Fullscreen               |
| `Super + h / l`          | Tile window left / right |
| `Super + j / k`          | Workspace down / up      |
| `Super + Shift + j / k`  | Move window to workspace |
| `Super + 1–9`            | Switch to workspace      |
| `Super + Shift + 1–9`    | Move window to workspace |

### Neovim

- **LSP**: TypeScript, Tailwind CSS, Lua, Nix, Python, ESLint
- **Completion**: nvim-cmp + LuaSnip
- **Treesitter**: tsx, typescript, javascript, json, lua, nix, html, css, etc.
- **Formatting**: conform.nvim (prettierd, stylua)
- **UI**: lualine, bufferline, gitsigns, catppuccin

## Mirrors

| Host   | URL                                |
| ------ | ---------------------------------- |
| GitHub | https://github.com/TyposBro/config |
| GitLab | https://gitlab.com/typosbro/config |
