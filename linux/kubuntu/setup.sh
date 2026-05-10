#!/usr/bin/env bash
# Kubuntu setup — mirror of mac/setup.sh idempotent pattern.
# Re-run anytime; already-done steps are skipped.

set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$DIR/../.." && pwd)"
MARK_DIR="$HOME/.local/state/config-kubuntu"
OLD_MARK_DIR="$HOME/.local/state/nixos-config-kubuntu"

if [ -d "$OLD_MARK_DIR" ] && [ ! -d "$MARK_DIR" ]; then
	mkdir -p "$(dirname "$MARK_DIR")"
	mv "$OLD_MARK_DIR" "$MARK_DIR"
fi

mkdir -p "$MARK_DIR"

if [ "$1" = "--clean" ] || [ "$1" = "-c" ]; then
	echo "==> Clean install — clearing markers..."
	rm -f "$MARK_DIR"/*
fi

did() { [ -f "$MARK_DIR/$1" ]; }
mark() { touch "$MARK_DIR/$1"; }

# Keep sudo timestamp fresh in background
sudo -v
(while true; do
	sudo -n true
	sleep 60
	kill -0 "$$" 2>/dev/null || exit
done) 2>/dev/null &
SUDO_KEEPALIVE=$!
trap 'kill $SUDO_KEEPALIVE 2>/dev/null || true' EXIT

CODENAME="$(lsb_release -cs)"
ARCH="$(dpkg --print-architecture)"

# ── 1. Apt packages ──────────────────────────────────────────────────────────
if ! did apt; then
	echo "==> Installing apt packages..."
	sudo apt update
	sudo apt install -y \
		git gh fish curl wget vim build-essential pkg-config ca-certificates gnupg \
		openssh-server \
		apt-transport-https lsb-release software-properties-common \
		fzf jq htop btop tmux ripgrep fd-find unzip zip tree rsync \
		mpv aria2 cloc tesseract-ocr qbittorrent obs-studio kdenlive \
		python3 python3-pip python3-venv ruby gradle \
		neovim \
		fonts-noto-core fonts-noto-color-emoji fonts-font-awesome \
		pulseaudio pulseaudio-utils pavucontrol playerctl pamixer brightnessctl wl-clipboard \
		flatpak \
		git-lfs git-filter-repo
	# fd-find ships as `fdfind` on Ubuntu — symlink to `fd`
	mkdir -p "$HOME/.local/bin"
	[ -e "$HOME/.local/bin/fd" ] || ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
	mark apt
fi

# ── 1b. SSH server: make this PC reachable over SSH ─────────────────────────
if ! did ssh-server; then
	echo "==> Enabling SSH server..."
	sudo apt install -y openssh-server
	sudo systemctl enable --now ssh

	# If UFW is active, allow OpenSSH. If inactive/missing, do not change firewall policy.
	if command -v ufw >/dev/null 2>&1 && sudo ufw status | grep -q "Status: active"; then
		sudo ufw allow OpenSSH
	fi

	echo "    SSH ready: ssh $USER@$(hostname -I | awk '{print $1}')"
	mark ssh-server
fi

# ── 1c. Power: never sleep/dim while plugged in ─────────────────────────────
if ! did power-ac-always-on; then
	echo "==> Disabling sleep + screen dimming on AC power..."

	# KDE PowerDevil: AC profile. Values are stable config keys used by Plasma.
	KWRITECONFIG="$(command -v kwriteconfig5 || command -v kwriteconfig6 || true)"
	if [ -n "$KWRITECONFIG" ]; then
		"$KWRITECONFIG" --file powermanagementprofilesrc --group AC --group SuspendSession --key idleTime --delete 2>/dev/null || true
		"$KWRITECONFIG" --file powermanagementprofilesrc --group AC --group SuspendSession --key suspendType --delete 2>/dev/null || true
		"$KWRITECONFIG" --file powermanagementprofilesrc --group AC --group DPMSControl --key idleTime --delete 2>/dev/null || true
		"$KWRITECONFIG" --file powermanagementprofilesrc --group AC --group DimDisplay --key idleTime --delete 2>/dev/null || true
		"$KWRITECONFIG" --file powermanagementprofilesrc --group AC --key powerButtonAction 0 2>/dev/null || true
	fi

	# systemd-logind backstop: ignore lid close and idle actions while on wall power.
	sudo mkdir -p /etc/systemd/logind.conf.d
	sudo tee /etc/systemd/logind.conf.d/90-config-kubuntu-ac-always-on.conf >/dev/null <<'EOF'
[Login]
HandleLidSwitchExternalPower=ignore
IdleAction=ignore
EOF
	sudo systemctl restart systemd-logind || true

	# Apply KDE setting without requiring logout when possible.
	qdbus org.kde.Solid.PowerManagement /org/kde/Solid/PowerManagement org.kde.Solid.PowerManagement.refreshStatus 2>/dev/null || true

	mark power-ac-always-on
fi

# ── 1d. Swap: ensure 16G swapfile ───────────────────────────────────────────
if ! did swap-16g; then
	echo "==> Ensuring 16G swapfile at /swapfile..."
	TARGET_BYTES="$((16 * 1024 * 1024 * 1024))"

	if [ -f /swapfile ]; then
		CUR_BYTES="$(sudo stat -c%s /swapfile 2>/dev/null || echo 0)"
		if [ "$CUR_BYTES" != "$TARGET_BYTES" ]; then
			sudo swapoff /swapfile 2>/dev/null || true
			sudo rm -f /swapfile
		fi
	fi

	if [ ! -f /swapfile ]; then
		sudo fallocate -l 16G /swapfile
		sudo chmod 600 /swapfile
		sudo mkswap /swapfile >/dev/null
	fi

	sudo swapon /swapfile
	if ! sudo grep -qE '^/swapfile\s+none\s+swap\s+' /etc/fstab; then
		echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab >/dev/null
	fi

	mark swap-16g
fi

# ── 1e. NVIDIA: force dedicated dGPU mode ───────────────────────────────────
if ! did nvidia-dgpu; then
	echo "==> Enabling dedicated NVIDIA GPU mode..."
	sudo apt install -y nvidia-prime

	if command -v prime-select >/dev/null 2>&1; then
		CURRENT_MODE="$(prime-select query 2>/dev/null || true)"
		if [ "$CURRENT_MODE" != "nvidia" ]; then
			sudo prime-select nvidia
		fi
	else
		echo "    prime-select not found; skipping dedicated GPU switch"
	fi

	mark nvidia-dgpu
fi

# ── 2. Flatpak: add Flathub ──────────────────────────────────────────────────
if ! did flathub; then
	echo "==> Adding Flathub remote..."
	flatpak remote-add --if-not-exists --user flathub https://flathub.org/repo/flathub.flatpakrepo
	mark flathub
fi

# ── 2b. Perfect Equalizer (EasyEffects, GitHub project via Flathub) ─────────
if ! did perfect-eq; then
	echo "==> Installing Perfect Equalizer (EasyEffects)..."
	flatpak install -y --user flathub com.github.wwmm.easyeffects
	mark perfect-eq
fi

# ── 3. Ghostty (community .deb from mkasberg/ghostty-ubuntu) ─────────────────
if ! did ghostty; then
	echo "==> Installing Ghostty..."
	UBVER="$(lsb_release -rs)" # e.g. 24.04
	URL="$(curl -fsSL https://api.github.com/repos/mkasberg/ghostty-ubuntu/releases/latest |
		jq -r --arg arch "$ARCH" --arg ver "$UBVER" \
			'.assets[] | select(.name | endswith("_\($arch)_\($ver).deb")) | .browser_download_url' |
		head -1)"
	if [ -z "$URL" ]; then
		echo "    No prebuilt ghostty .deb for ${ARCH}/${UBVER}; skipping"
	else
		curl -fsSL -o /tmp/ghostty.deb "$URL"
		sudo apt install -y /tmp/ghostty.deb
		rm /tmp/ghostty.deb
	fi
	mark ghostty
fi

# ── 4. Zen Browser (Flatpak) ─────────────────────────────────────────────────
if ! did zen; then
	echo "==> Installing Zen Browser..."
	flatpak install -y --user flathub app.zen_browser.zen
	mark zen
fi

# ── 5. JetBrainsMono Nerd Font ───────────────────────────────────────────────
if ! did fonts-nerd; then
	echo "==> Installing JetBrainsMono Nerd Font..."
	mkdir -p "$HOME/.local/share/fonts/JetBrainsMonoNF"
	curl -fsSL -o /tmp/JBM.zip \
		https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
	unzip -o -q /tmp/JBM.zip -d "$HOME/.local/share/fonts/JetBrainsMonoNF"
	fc-cache -f
	rm /tmp/JBM.zip
	mark fonts-nerd
fi

# ── 6. Starship prompt ───────────────────────────────────────────────────────
if ! did starship; then
	echo "==> Installing Starship..."
	curl -fsSL https://starship.rs/install.sh | sh -s -- -y
	mark starship
fi

# ── 7. fnm (node version manager) ────────────────────────────────────────────
if ! did fnm; then
	echo "==> Installing fnm..."
	curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell
	mark fnm
fi

# ── 8. Bun ───────────────────────────────────────────────────────────────────
if ! did bun; then
	echo "==> Installing Bun..."
	curl -fsSL https://bun.sh/install | bash
	mark bun
fi

# ── 9. Rust (rustup + stable + clippy + rust-analyzer) ───────────────────────
if ! did rust; then
	echo "==> Installing Rust toolchain..."
	curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs |
		sh -s -- -y --default-toolchain stable -c clippy -c rust-analyzer
	mark rust
fi

# ── 10. Deno ─────────────────────────────────────────────────────────────────
if ! did deno; then
	echo "==> Installing Deno..."
	curl -fsSL https://deno.land/install.sh | sh -s -- -y
	mark deno
fi

# ── 11. Lazygit (github release) ─────────────────────────────────────────────
if ! did lazygit; then
	echo "==> Installing Lazygit..."
	LG_TAG="$(curl -fsSL https://api.github.com/repos/jesseduffield/lazygit/releases/latest | jq -r .tag_name)"
	LG_VER="${LG_TAG#v}"
	curl -fsSL -o /tmp/lg.tar.gz \
		"https://github.com/jesseduffield/lazygit/releases/download/${LG_TAG}/lazygit_${LG_VER}_Linux_x86_64.tar.gz"
	tar -xzf /tmp/lg.tar.gz -C /tmp lazygit
	sudo install /tmp/lazygit /usr/local/bin/
	rm /tmp/lg.tar.gz /tmp/lazygit
	mark lazygit
fi

# ── 12. glab (GitLab CLI) ────────────────────────────────────────────────────
if ! did glab; then
	echo "==> Installing glab..."
	GL_TAG="$(curl -fsSL https://gitlab.com/api/v4/projects/gitlab-org%2Fcli/releases | jq -r '.[0].tag_name')"
	GL_VER="${GL_TAG#v}"
	curl -fsSL -o /tmp/glab.deb \
		"https://gitlab.com/gitlab-org/cli/-/releases/${GL_TAG}/downloads/glab_${GL_VER}_linux_amd64.deb"
	sudo apt install -y /tmp/glab.deb
	rm /tmp/glab.deb
	mark glab
fi

# ── 13. Cloudflared ──────────────────────────────────────────────────────────
if ! did cloudflared; then
	echo "==> Installing cloudflared..."
	curl -fsSL -o /tmp/cloudflared.deb \
		"https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH}.deb"
	sudo apt install -y /tmp/cloudflared.deb
	rm /tmp/cloudflared.deb
	mark cloudflared
fi

# ── 14. AWS CLI v2 ───────────────────────────────────────────────────────────
if ! did awscli; then
	echo "==> Installing AWS CLI v2..."
	curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
	unzip -o -q /tmp/awscliv2.zip -d /tmp
	sudo /tmp/aws/install --update
	rm -rf /tmp/aws /tmp/awscliv2.zip
	mark awscli
fi

# ── 15. Google Cloud SDK ─────────────────────────────────────────────────────
if ! did gcloud; then
	echo "==> Installing Google Cloud SDK..."
	curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg |
		sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
	echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" |
		sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list >/dev/null
	sudo apt update && sudo apt install -y google-cloud-cli
	mark gcloud
fi

# ── 16. Terraform + OpenTofu ─────────────────────────────────────────────────
if ! did terraform-tools; then
	echo "==> Installing Terraform + OpenTofu..."
	sudo rm -f /usr/share/keyrings/hashicorp-archive-keyring.gpg
	curl -fsSL https://apt.releases.hashicorp.com/gpg |
		sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
	echo "deb [arch=$ARCH signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $CODENAME main" |
		sudo tee /etc/apt/sources.list.d/hashicorp.list >/dev/null

	sudo install -m 0755 -d /etc/apt/keyrings
	sudo rm -f /etc/apt/keyrings/opentofu.gpg /etc/apt/keyrings/opentofu-repo.gpg
	curl -fsSL https://get.opentofu.org/opentofu.gpg |
		sudo tee /etc/apt/keyrings/opentofu.gpg >/dev/null
	curl -fsSL https://packages.opentofu.org/opentofu/tofu/gpgkey |
		sudo gpg --no-tty --batch --dearmor -o /etc/apt/keyrings/opentofu-repo.gpg >/dev/null
	sudo chmod a+r /etc/apt/keyrings/opentofu.gpg /etc/apt/keyrings/opentofu-repo.gpg
	echo "deb [signed-by=/etc/apt/keyrings/opentofu.gpg,/etc/apt/keyrings/opentofu-repo.gpg] https://packages.opentofu.org/opentofu/tofu/any/ any main" |
		sudo tee /etc/apt/sources.list.d/opentofu.list >/dev/null
	sudo chmod a+r /etc/apt/sources.list.d/opentofu.list

	sudo apt update
	sudo apt install -y terraform tofu
	mark terraform-tools
fi

# ── 16b. Infisical CLI ───────────────────────────────────────────────────────
if ! did infisical; then
	echo "==> Installing Infisical CLI..."
	curl -1sLf 'https://artifacts-cli.infisical.com/setup.deb.sh' | sudo -E bash
	sudo apt update
	sudo apt install -y infisical
	mark infisical
fi

# ── 17. VS Code ──────────────────────────────────────────────────────────────
if ! did vscode; then
	echo "==> Installing VS Code..."
	curl -fsSL https://packages.microsoft.com/keys/microsoft.asc |
		sudo gpg --dearmor -o /usr/share/keyrings/microsoft.gpg
	echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" |
		sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
	sudo apt update && sudo apt install -y code
	mark vscode
fi

# ── 18. Brave Browser ────────────────────────────────────────────────────────
if ! did brave; then
	echo "==> Installing Brave..."
	sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
		https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
	echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" |
		sudo tee /etc/apt/sources.list.d/brave-browser-release.list >/dev/null
	sudo apt update && sudo apt install -y brave-browser
	mark brave
fi

# ── 19. Docker (docker-ce + compose plugin) ──────────────────────────────────
if ! did docker; then
	echo "==> Installing Docker..."
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg |
		sudo gpg --dearmor -o /usr/share/keyrings/docker.gpg
	echo "deb [arch=$ARCH signed-by=/usr/share/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $CODENAME stable" |
		sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
	sudo apt update
	sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
	sudo usermod -aG docker "$USER"
	mark docker
fi

# ── 20. ProtonVPN ────────────────────────────────────────────────────────────
if ! did protonvpn; then
	echo "==> Installing ProtonVPN..."
	curl -fsSL -o /tmp/proton-release.deb \
		"https://repo.protonvpn.com/debian/dists/stable/main/binary-all/protonvpn-stable-release_1.0.8_all.deb"
	sudo apt install -y /tmp/proton-release.deb
	sudo apt update
	sudo apt install -y proton-vpn-gnome-desktop || true
	rm /tmp/proton-release.deb
	mark protonvpn
fi

# ── 21. Snap apps (Kubuntu has snap by default) ──────────────────────────────
if ! did snap-apps; then
	echo "==> Installing snap apps..."
	sudo snap install spotify || true
	sudo snap install discord || true
	sudo snap install telegram-desktop || true
	sudo snap install postman || true
	sudo snap install obsidian --classic || true
	sudo snap install android-studio --classic || true
	sudo snap install ngrok || true
	mark snap-apps
fi

# ── 22. Bitwarden Desktop (Flatpak) ──────────────────────────────────────────
if ! did bitwarden; then
	echo "==> Installing Bitwarden..."
	flatpak install -y --user flathub com.bitwarden.desktop
	mark bitwarden
fi

# ── 22b. WhatsApp (Whatsie, Flatpak) ─────────────────────────────────────────
if ! did whatsapp; then
	echo "==> Installing WhatsApp (Whatsie)..."
	flatpak install -y --user flathub com.ktechpit.whatsie
	mark whatsapp
fi

# ── 23. Claude Code CLI ──────────────────────────────────────────────────────
if ! did claude-code; then
	echo "==> Installing Claude Code..."
	curl -fsSL https://claude.ai/install.sh | bash
	mark claude-code
fi

# ── 24. OpenCode CLI ─────────────────────────────────────────────────────────
if ! did opencode; then
	echo "==> Installing OpenCode..."
	curl -fsSL https://opencode.ai/install | bash
	mark opencode
fi

# ── 25. Codex CLI (npm @openai/codex) — needs node from fnm ──────────────────
if ! did codex; then
	echo "==> Installing Codex CLI..."
	# Find fnm — it installs to ~/.local/share/fnm or ~/.fnm depending on version
	for p in "$HOME/.local/share/fnm" "$HOME/.fnm"; do
		[ -x "$p/fnm" ] && export PATH="$p:$PATH"
	done
	if command -v fnm >/dev/null 2>&1; then
		eval "$(fnm env --shell bash)"
		fnm install --lts
		fnm use lts-latest
		fnm default lts-latest
		npm install -g @openai/codex
		mark codex
	else
		echo "    fnm not found on PATH; rerun after a new shell session"
	fi
fi

# ── 26. Pi coding agent ─────────────────────────────────────────────────────
echo "==> Syncing pi coding agent setup..."
bash "$REPO/pi/setup.sh"
if ! did pi; then
	mark pi
fi

echo "==> Syncing Claude skills setup..."
bash "$REPO/claude/setup.sh"

# ── 27. T3 Code (AppImage from pingdotgg/t3code) ─────────────────────────────
if ! did t3-code; then
	echo "==> Installing T3 Code..."
	T3_URL="$(curl -fsSL https://api.github.com/repos/pingdotgg/t3code/releases/latest |
		jq -r '.assets[] | select(.name | test("x86_64.AppImage$")) | .browser_download_url' |
		head -1)"
	if [ -n "$T3_URL" ]; then
		mkdir -p "$HOME/.local/bin" "$HOME/.local/share/applications"
		curl -fsSL -o "$HOME/.local/bin/t3-code.AppImage" "$T3_URL"
		chmod +x "$HOME/.local/bin/t3-code.AppImage"

		cat >"$HOME/.local/bin/t3-code" <<'EOF'
#!/usr/bin/env bash
exec "$HOME/.local/bin/t3-code.AppImage" "$@"
EOF
		chmod +x "$HOME/.local/bin/t3-code"

		cat >"$HOME/.local/bin/t3" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = "code" ]; then
  shift
  exec "$HOME/.local/bin/t3-code" "$@"
fi
echo "Usage: t3 code [args...]"
exit 1
EOF
		chmod +x "$HOME/.local/bin/t3"

		cat >"$HOME/.local/share/applications/t3-code.desktop" <<EOF
[Desktop Entry]
Name=T3 Code
Comment=T3 Code desktop app
Exec=$HOME/.local/bin/t3-code %U
Terminal=false
Type=Application
Categories=Development;
StartupWMClass=T3 Code
EOF
		update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true

		mark t3-code
	else
		echo "    No Linux AppImage asset found for t3code; skipping (rerun later)"
	fi
fi

# ── 28. Tectonic (LaTeX) — prebuilt static binary ────────────────────────────
if ! did tectonic; then
	echo "==> Installing tectonic (prebuilt static binary)..."
	TEC_TAG="$(curl -fsSL https://api.github.com/repos/tectonic-typesetting/tectonic/releases/latest | jq -r .tag_name)"
	TEC_URL="$(curl -fsSL https://api.github.com/repos/tectonic-typesetting/tectonic/releases/latest |
		jq -r '.assets[] | select(.name | test("x86_64-unknown-linux-musl.tar.gz$")) | .browser_download_url' |
		head -1)"
	if [ -n "$TEC_URL" ]; then
		curl -fsSL -o /tmp/tectonic.tar.gz "$TEC_URL"
		tar -xzf /tmp/tectonic.tar.gz -C /tmp
		sudo install /tmp/tectonic /usr/local/bin/
		rm -f /tmp/tectonic.tar.gz /tmp/tectonic
		mark tectonic
	else
		echo "    No prebuilt tectonic for x86_64-linux; skipping (rerun later)"
	fi
fi

# ── 29. Symlink configs ──────────────────────────────────────────────────────
if ! did configs; then
	echo "==> Linking shell + terminal configs..."
	mkdir -p "$HOME/.config/fish/themes" "$HOME/.config/ghostty"
	ln -sfn "$DIR/config/fish/config.fish" "$HOME/.config/fish/config.fish"
	ln -sfn "$DIR/config/ghostty/config" "$HOME/.config/ghostty/config"
	ln -sfn "$REPO/mac/config/starship.toml" "$HOME/.config/starship.toml"
	mark configs
fi

# ── 30. Git config (mirrors home/shared/git.nix) ─────────────────────────────
if ! did git-config; then
	echo "==> Applying git config..."
	git config --global user.name "TyposBro"
	git config --global user.email "typosbro@proton.me"
	git config --global init.defaultBranch main
	git config --global push.autoSetupRemote true
	git config --global pull.rebase false
	git config --global core.autocrlf input
	git config --global core.editor vim
	git config --global diff.colorMoved zebra
	mark git-config
fi

# ── 31. Catppuccin Mocha fish theme ──────────────────────────────────────────
if ! did fish-theme; then
	echo "==> Installing Catppuccin Mocha fish theme..."
	curl -fsSL https://raw.githubusercontent.com/catppuccin/fish/main/themes/catppuccin-mocha.theme \
		-o "$HOME/.config/fish/themes/Catppuccin Mocha.theme"
	fish -c 'yes | fish_config theme save "Catppuccin Mocha"' >/dev/null 2>&1 || true
	mark fish-theme
fi

# ── 32. Set fish as default shell ────────────────────────────────────────────
FISH_PATH="$(command -v fish)"
if [ -n "$FISH_PATH" ] && [ "$(getent passwd "$USER" | cut -d: -f7)" != "$FISH_PATH" ]; then
	echo "==> Setting fish as default shell..."
	if ! grep -qx "$FISH_PATH" /etc/shells; then
		echo "$FISH_PATH" | sudo tee -a /etc/shells >/dev/null
	fi
	sudo chsh -s "$FISH_PATH" "$USER"
fi

# ── 33. SSH key + config (mirrors home/shared/git.nix) ───────────────────────
if ! did ssh-key; then
	echo "==> Setting up SSH key + config..."
	mkdir -p "$HOME/.ssh"
	chmod 700 "$HOME/.ssh"
	if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
		ssh-keygen -t ed25519 -C "typosbro@proton.me" -f "$HOME/.ssh/id_ed25519" -N ""
	fi
	cat >"$HOME/.ssh/config" <<'EOF'
Host *
  AddKeysToAgent yes

Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519

Host gitlab.com
  HostName gitlab.com
  User git
  IdentityFile ~/.ssh/id_ed25519
EOF
	chmod 600 "$HOME/.ssh/config"
	eval "$(ssh-agent -s)" >/dev/null
	ssh-add "$HOME/.ssh/id_ed25519" 2>/dev/null || true
	mark ssh-key
fi

# ── 34. GitHub + GitLab SSH key upload (interactive) ─────────────────────────
if ! did gh-ssh; then
	echo "==> GitHub auth + SSH key upload (browser will open)..."
	if ! gh auth status >/dev/null 2>&1; then
		gh auth login -p ssh -h github.com -w
	fi
	gh ssh-key add "$HOME/.ssh/id_ed25519.pub" -t "kubuntu-$(hostname)" || true
	mark gh-ssh
fi

if ! did glab-ssh; then
	echo "==> GitLab auth + SSH key upload..."
	if ! glab auth status 2>&1 | grep -q "Logged in to gitlab.com"; then
		echo "    Pick 'Web' for browser auth, or 'Token' if you have one ready."
		glab auth login --hostname gitlab.com --git-protocol ssh
	fi
	echo "    glab has no built-in ssh-key add. Open this URL and paste the key:"
	echo "      https://gitlab.com/-/user_settings/ssh_keys"
	echo "    --- Public key ---"
	cat "$HOME/.ssh/id_ed25519.pub"
	echo "    ------------------"
	mark glab-ssh
fi

# ── 35. KDE: set Ghostty as default terminal ─────────────────────────────────
if ! did kde-terminal; then
	echo "==> Setting Ghostty as KDE default terminal..."
	KFILE="$HOME/.config/kdeglobals"
	touch "$KFILE"
	if grep -q '^\[General\]' "$KFILE"; then
		if grep -q '^TerminalApplication=' "$KFILE"; then
			sed -i 's|^TerminalApplication=.*|TerminalApplication=ghostty|' "$KFILE"
		else
			sed -i '/^\[General\]/a TerminalApplication=ghostty' "$KFILE"
		fi
		if grep -q '^TerminalService=' "$KFILE"; then
			sed -i 's|^TerminalService=.*|TerminalService=com.mitchellh.ghostty.desktop|' "$KFILE"
		else
			sed -i '/^TerminalApplication=/a TerminalService=com.mitchellh.ghostty.desktop' "$KFILE"
		fi
	else
		printf '\n[General]\nTerminalApplication=ghostty\nTerminalService=com.mitchellh.ghostty.desktop\n' >>"$KFILE"
	fi
	mark kde-terminal
fi

echo
echo "==> Done. Re-run anytime; already-done steps are skipped."
echo "    Force re-run a step:  rm $MARK_DIR/<step>"
echo "    Log out and back in for: docker group, default shell change."
