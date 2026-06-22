#!/usr/bin/env bash
set -euo pipefail

backup_dir="$HOME/config/space-shortcuts/backups"
mkdir -p "$backup_dir"
defaults export com.apple.spaces "$backup_dir/com.apple.spaces.$(date +%Y%m%d-%H%M%S).plist" 2>/dev/null || true

space_uuid() {
  local index="$1"
  /usr/bin/python3 - "$index" <<'PY'
import plistlib
import subprocess
import sys

index = int(sys.argv[1]) - 1
raw = subprocess.check_output(["defaults", "export", "com.apple.spaces", "-"])
data = plistlib.loads(raw)
monitors = data["SpacesDisplayConfiguration"]["Management Data"]["Monitors"]
main = next(m for m in monitors if m.get("Display Identifier") == "Main")
spaces = [s for s in main["Spaces"] if s.get("type", 0) == 0]
if index >= len(spaces):
    raise SystemExit(f"Desktop {index + 1} does not exist")
print(spaces[index].get("uuid", ""))
PY
}

bind_space() {
  local space_index="$1"
  shift
  local uuid
  uuid="$(space_uuid "$space_index")"

  for bundle_id in "$@"; do
    defaults write com.apple.spaces app-bindings -dict-add "$bundle_id" "$uuid"
  done
}

# Space 1: browser
bind_space 1 \
  app.zen-browser.zen

# Space 2: coding, terminal, AI development tools
bind_space 2 \
  com.mitchellh.ghostty \
  com.microsoft.VSCode \
  com.openai.codex \
  com.t3tools.t3code \
  com.google.antigravity

# Space 3: native/mobile IDEs
bind_space 3 \
  com.google.android.studio \
  com.apple.dt.Xcode

# Space 4: reference, media, comms
bind_space 4 \
  md.obsidian \
  com.spotify.client \
  ru.keepcoder.Telegram \
  net.whatsapp.WhatsApp \
  com.hnc.Discord

killall cfprefsd 2>/dev/null || true
killall Dock 2>/dev/null || true

cat <<'EOF'
Installed macOS app-to-Space bindings:
  Desktop 1: Zen
  Desktop 2: Ghostty, VS Code, Codex, T3 Code, Antigravity
  Desktop 3: Android Studio, Xcode
  Desktop 4: Obsidian, Spotify, Telegram, WhatsApp, Discord

Quit and reopen affected apps if they are already running.
If an app still opens elsewhere, use Dock > Options > Assign To > This Desktop once;
macOS sometimes repairs app bindings only after a manual assignment.
EOF
