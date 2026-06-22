# Space Shortcuts

Portable workspace switching shortcuts for macOS, GNOME, and KDE Plasma.

## Layout

App arrangement is declared in [layout.toml](layout.toml):

```text
Desktop 1: Browser
  Zen

Desktop 2: Development
  Ghostty, VS Code, Codex, T3 Code, Antigravity

Desktop 3: Native Apps
  Android Studio, Xcode

Desktop 4: Reference And Comms
  Obsidian, Spotify, Telegram, WhatsApp, Discord
```

Linux:

```text
Ctrl+Alt+H -> Workspace/Desktop 1
Ctrl+Alt+J -> Workspace/Desktop 2
Ctrl+Alt+K -> Workspace/Desktop 3
Ctrl+Alt+L -> Workspace/Desktop 4
```

macOS:

```text
Ctrl+Option+Command+H -> Desktop 1
Ctrl+Option+Command+J -> Desktop 2
Ctrl+Option+Command+K -> Desktop 3
Ctrl+Option+Command+L -> Desktop 4
```

The macOS chord intentionally includes Command because `Ctrl+Option` is more likely to collide with app, input source, and accessibility shortcuts.

macOS Mission Control is still physically a 1x4 strip. Modern macOS does not provide native KDE-style 2x2 animations. KDE Plasma can use a real 2x2 grid; this config sets KDE to two rows.

## Install

```sh
~/config/space-shortcuts/install.sh
```

On macOS, this installs both keyboard shortcuts and app-to-Space bindings.

For Linux, auto-detection uses `XDG_CURRENT_DESKTOP`. You can force a backend:

```sh
~/config/space-shortcuts/bin/linux.sh gnome
~/config/space-shortcuts/bin/linux.sh kde
```

## Notes

macOS needs four Spaces to already exist. Create them in Mission Control first if Desktop 2-4 do not appear in Keyboard Shortcuts.

The macOS script disables "Automatically rearrange Spaces based on most recent use" so Desktop numbers stay stable.

GNOME is configured for four static workspaces.

KDE Plasma is configured for four desktops in two rows. Shortcut labels remain `H J K L` so the same muscle memory works everywhere.
