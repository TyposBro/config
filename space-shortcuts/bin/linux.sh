#!/usr/bin/env bash
set -euo pipefail

desktop="${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-unknown}}"

install_gnome() {
  command -v gsettings >/dev/null || {
    echo "gsettings is required for GNOME." >&2
    exit 1
  }

  gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-1 "['<Control><Alt>h']"
  gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-2 "['<Control><Alt>j']"
  gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-3 "['<Control><Alt>k']"
  gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-4 "['<Control><Alt>l']"

  # GNOME defaults to dynamic workspaces on many distros. Static 4 workspaces
  # makes this layout deterministic.
  gsettings set org.gnome.mutter dynamic-workspaces false 2>/dev/null || true
  gsettings set org.gnome.desktop.wm.preferences num-workspaces 4 2>/dev/null || true

  echo "Installed GNOME workspace shortcuts: Ctrl+Alt+H/J/K/L -> Workspace 1/2/3/4"
}

install_kde() {
  local kwriteconfig kquitapp kstart

  kwriteconfig="$(command -v kwriteconfig6 || command -v kwriteconfig5 || true)"
  kquitapp="$(command -v kquitapp6 || command -v kquitapp5 || true)"
  kstart="$(command -v kstart6 || command -v kstart5 || true)"

  [[ -n "$kwriteconfig" ]] || {
    echo "kwriteconfig5 or kwriteconfig6 is required for KDE Plasma." >&2
    exit 1
  }

  # KGlobalAccel format: active shortcut, default shortcut, display name.
  "$kwriteconfig" --file kglobalshortcutsrc --group kwin --key "Switch to Desktop 1" "Ctrl+Alt+H,none,Switch to Desktop 1"
  "$kwriteconfig" --file kglobalshortcutsrc --group kwin --key "Switch to Desktop 2" "Ctrl+Alt+J,none,Switch to Desktop 2"
  "$kwriteconfig" --file kglobalshortcutsrc --group kwin --key "Switch to Desktop 3" "Ctrl+Alt+K,none,Switch to Desktop 3"
  "$kwriteconfig" --file kglobalshortcutsrc --group kwin --key "Switch to Desktop 4" "Ctrl+Alt+L,none,Switch to Desktop 4"

  # Plasma desktop count is version-dependent; try common locations.
  "$kwriteconfig" --file kwinrc --group Desktops --key Number 4 2>/dev/null || true
  # KDE supports the real 2x2 desktop grid that macOS no longer exposes.
  "$kwriteconfig" --file kwinrc --group Desktops --key Rows 2 2>/dev/null || true

  if [[ -n "$kquitapp" && -n "$kstart" ]]; then
    "$kquitapp" kglobalaccel 2>/dev/null || true
    "$kstart" kglobalaccel 2>/dev/null || true
  fi

  qdbus org.kde.KWin /KWin reconfigure 2>/dev/null || true
  qdbus6 org.kde.KWin /KWin reconfigure 2>/dev/null || true

  echo "Installed KDE Plasma workspace shortcuts: Ctrl+Alt+H/J/K/L -> Desktop 1/2/3/4"
  echo "Configured KDE for a 2x2 desktop grid."
  echo "If they do not take immediately, log out and back in."
}

case "${desktop,,}" in
  *gnome*)
    install_gnome
    ;;
  *kde*|*plasma*)
    install_kde
    ;;
  *)
    echo "Could not auto-detect GNOME or KDE from XDG_CURRENT_DESKTOP='$desktop'." >&2
    echo "Run one of these explicitly:" >&2
    echo "  $0 gnome" >&2
    echo "  $0 kde" >&2
    case "${1:-}" in
      gnome) install_gnome ;;
      kde|plasma) install_kde ;;
      *) exit 1 ;;
    esac
    ;;
esac
