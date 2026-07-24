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
```

## macOS

### Fresh install

```bash
git clone https://github.com/TyposBro/config.git ~/config
~/config/mac/setup.sh --clean
```

Runs every step: brew bundle, symlink configs, fish theme, macOS defaults, Rust toolchain, Claude Code, pi setup, fish as default shell.

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

Kubuntu + macOS setup scripts call this automatically on every run. It manages non-secret Pi settings, global rules, and repo-managed extensions; auth/session data stays local. Global harness skills live in `~/agent-memory/skills`; Pi auto-discovers them via `~/.agents/skills`, and Claude Code gets the same skills via `~/.claude/skills`.

### OMP coding agent

OMP agent-harness setup is backed up/reproducible under `omp/`:

```bash
~/config/omp/setup.sh
```

This restores the global personality/AuDHD communication layer, role routing, and model-pinned task agents (`sol`, `fable`, and `gemini-pro`). It removes the old Superpowers bootstrap and workflow assets. Provider credentials, auth, sessions, DBs, blobs, and `models.yml` stay local.

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
