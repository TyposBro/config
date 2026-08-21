#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$DIR/.." && pwd)"
MARK_DIR="$HOME/.local/state/config-mac"
OLD_MARK_DIR="$HOME/.local/state/nixos-config-mac"

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

echo "==> Installing packages (brew bundle)..."
export HOMEBREW_CASK_OPTS="--no-quarantine"
brew bundle --file="$DIR/Brewfile"

if ! did configs; then
	echo "==> Linking shell + terminal configs..."
	mkdir -p ~/.config/fish ~/.config/ghostty ~/.config/fish/themes
	ln -sfn "$DIR/config/fish/config.fish" ~/.config/fish/config.fish
	ln -sfn "$DIR/config/ghostty/config" ~/.config/ghostty/config
	ln -sfn "$DIR/config/starship.toml" ~/.config/starship.toml
	mark configs
fi

if ! did fish-theme; then
	echo "==> Installing Catppuccin Mocha fish theme..."
	curl -fsSL https://raw.githubusercontent.com/catppuccin/fish/main/themes/catppuccin-mocha.theme \
		-o "$HOME/.config/fish/themes/Catppuccin Mocha.theme"
	fish -c 'yes | fish_config theme save "Catppuccin Mocha"' >/dev/null 2>&1 || true
	mark fish-theme
fi

if ! did defaults; then
	echo "==> Applying macOS defaults..."
	bash "$DIR/defaults.sh"
	mark defaults
fi

if ! did rust; then
	echo "==> Setting up Rust toolchain..."
	rustup default stable
	rustup component add clippy rust-analyzer
	mark rust
fi

if ! did claude-code; then
	echo "==> Installing Claude Code..."
	curl -fsSL https://claude.ai/install.sh | bash
	mark claude-code
fi

echo "==> Syncing pi coding agent setup..."
bash "$REPO/pi/setup.sh"
if ! did pi; then
	mark pi
fi

echo "==> Syncing OMP coding agent setup..."
bash "$REPO/omp/setup.sh"

echo "==> Syncing Codex coding agent setup..."
bash "$REPO/codex/setup.sh"

echo "==> Linking Claude skills from agent-memory..."
bash "$REPO/claude/setup.sh"

echo "==> Applying Paseo OpenCode Theme & Styling..."
bash "$REPO/paseo/install.sh"


FISH_PATH="$(command -v fish)"
if [ "$(dscl . -read "/Users/$(whoami)" UserShell | awk '{print $2}')" != "$FISH_PATH" ]; then
	echo "==> Setting fish as default shell..."
	if ! grep -qx "$FISH_PATH" /etc/shells; then
		echo "$FISH_PATH" | sudo tee -a /etc/shells >/dev/null
	fi
	chsh -s "$FISH_PATH"
fi

echo "==> Done. Re-run anytime; already-done steps are skipped."
echo "    Force re-run: rm $MARK_DIR/<step>"
