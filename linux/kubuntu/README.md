# Kubuntu setup

Mirror of `mac/setup.sh` for Kubuntu 24.04 (noble).

## Fresh install

```bash
git clone https://github.com/TyposBro/config.git ~/config
~/config/linux/kubuntu/setup.sh --clean
```

Runs every step: apt install (including PulseAudio + OpenSSH server), SSH server enablement, AC-power always-on settings (no sleep/dim while plugged in), 16G swapfile setup, dedicated NVIDIA mode (prime-select nvidia), third-party repos, Perfect Equalizer (EasyEffects via Flatpak), Ghostty, Zen Browser (Flatpak), fonts, starship, fnm, bun, rustup, deno, lazygit, glab, cloudflared, awscli, gcloud, Terraform/OpenTofu, VS Code, Brave, Docker, ProtonVPN, snap apps (Spotify/Discord/Postman/Obsidian/Android Studio/ngrok), Bitwarden (Flatpak), Claude Code, OpenCode, Codex CLI, T3 Code (AppImage + `t3 code` shim), tectonic, configs, git config, fish theme, SSH key + GitHub/GitLab key upload, fish as default shell, Ghostty as KDE default terminal. The host script runs the convergent shared-skills installer before publishing canonical OMP routing.

Kubuntu OMP routing is owned by `omp/setup.sh`: lightweight task and commit roles use GPT-5.6 Luna, while adversarial review uses GPT-5.6 Terra. Do not apply provider or model overrides after OMP setup.

## Update / re-run

```bash
~/config/linux/kubuntu/setup.sh
```

Skips already-done steps. Markers live in `~/.local/state/config-kubuntu/`.

## Force re-run one step

```bash
rm ~/.local/state/config-kubuntu/<step>
~/config/linux/kubuntu/setup.sh
```

Step names: `apt`, `ssh-server`, `power-ac-always-on`, `swap-16g`, `nvidia-dgpu`, `flathub`, `perfect-eq`, `ghostty`, `zen`, `fonts-nerd`, `konsole-nerd-font`, `starship`, `fnm`, `bun`, `rust`, `deno`, `lazygit`, `glab`, `cloudflared`, `awscli`, `gcloud`, `terraform-tools`, `vscode`, `brave`, `docker`, `protonvpn`, `snap-apps`, `bitwarden`, `claude-code`, `opencode`, `codex`, `t3-code`, `tectonic`, `configs`, `git-config`, `fish-theme`, `ssh-key`, `gh-ssh`, `glab-ssh`, `kde-terminal`.

## After install

Log out and back in for: docker group, default shell change.
Reboot after first run if NVIDIA mode was switched to `nvidia`.

## What's skipped vs Mac/NixOS

macOS-only (skipped): karabiner-elements, raycast, alt-tab, iina, au-lab, eqmac, github-desktop cask.
No Linux build (skipped): antigravity (Google).
Use Linux equivalent: Konsole/Ghostty replaces iTerm; krunner/rofi replaces Raycast.
