#!/usr/bin/env bash
set -euo pipefail

plist="$HOME/Library/Preferences/com.apple.symbolichotkeys.plist"
backup_dir="$HOME/config/space-shortcuts/backups"
mkdir -p "$backup_dir"

if [[ -f "$plist" ]]; then
  cp "$plist" "$backup_dir/com.apple.symbolichotkeys.$(date +%Y%m%d-%H%M%S).plist"
fi

make_hotkey() {
  local sid="$1"
  local keycode="$2"

  /usr/libexec/PlistBuddy -c "Delete :AppleSymbolicHotKeys:${sid}" "$plist" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:${sid} dict" "$plist"
  /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:${sid}:enabled bool true" "$plist"
  /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:${sid}:value dict" "$plist"
  /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:${sid}:value:type string standard" "$plist"
  /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:${sid}:value:parameters array" "$plist"
  /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:${sid}:value:parameters:0 integer 65535" "$plist"
  /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:${sid}:value:parameters:1 integer ${keycode}" "$plist"
  /usr/libexec/PlistBuddy -c "Add :AppleSymbolicHotKeys:${sid}:value:parameters:2 integer 1835008" "$plist"
}

# Desktop switching hotkey IDs on current macOS:
# 118..121 = Switch to Desktop 1..4
# Virtual keycodes: H=4, J=38, K=40, L=37
make_hotkey 118 4
make_hotkey 119 38
make_hotkey 120 40
make_hotkey 121 37

# Keep Spaces in stable numeric order.
defaults write com.apple.dock mru-spaces -bool false

plutil -convert binary1 "$plist"
killall cfprefsd 2>/dev/null || true
killall Dock 2>/dev/null || true
killall SystemUIServer 2>/dev/null || true

cat <<'EOF'
Installed macOS Space shortcuts:
  Ctrl+Option+Command+H -> Desktop 1
  Ctrl+Option+Command+J -> Desktop 2
  Ctrl+Option+Command+K -> Desktop 3
  Ctrl+Option+Command+L -> Desktop 4

If macOS beeps instead of switching, log out and back in once.
EOF
