#!/usr/bin/env bash
# Kubuntu KDE Rice (macOS/GNOME Style with Orchis, Kvantum & Tela Circle Icons)
# Idempotent and reproducible.

set -euo pipefail

echo "==> Configuring KDE Plasma Orchis rice..."

TMP_DIR="/tmp/kde-orchis-rice"
mkdir -p "$TMP_DIR"

run_sudo() {
    if [ "${EUID:-$(id -u)}" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

# 1. Install Kvantum Qt engine
echo "--> Installing Kvantum engine..."
run_sudo apt-get update -qq
run_sudo apt-get install -y -qq qt5-style-kvantum qt5-style-kvantum-themes

# 2. Install Orchis KDE theme system-wide
echo "--> Installing Orchis KDE theme..."
if [ ! -d "$TMP_DIR/Orchis-kde" ]; then
    git clone --depth 1 https://github.com/vinceliuice/Orchis-kde.git "$TMP_DIR/Orchis-kde"
fi
(cd "$TMP_DIR/Orchis-kde" && run_sudo ./install.sh)

# 3. Install Tela Circle Icon theme system-wide
echo "--> Installing Tela Circle icons..."
if [ ! -d "$TMP_DIR/Tela-circle-icon-theme" ]; then
    git clone --depth 1 https://github.com/vinceliuice/Tela-circle-icon-theme.git "$TMP_DIR/Tela-circle-icon-theme"
fi
(cd "$TMP_DIR/Tela-circle-icon-theme" && run_sudo ./install.sh -a)

# 4. Flatpak & Snap icon sandboxing overrides
if command -v flatpak &>/dev/null; then
    echo "--> Applying Flatpak icon theme overrides..."
    flatpak override --user --filesystem=/usr/share/icons:ro || true
    flatpak override --user --filesystem=xdg-data/icons:ro || true
    flatpak override --user --env=ICON_THEME=Tela-circle-dark || true
fi

# 5. Apply Look & Feel, Color Scheme, and Icon Theme
echo "--> Applying Global Theme, Kvantum & Icons..."
mkdir -p "$HOME/.config/Kvantum"
cat << 'EOF' > "$HOME/.config/Kvantum/kvantum.kvconfig"
[General]
theme=Orchis-solidDark
EOF

if command -v lookandfeeltool &>/dev/null; then
    lookandfeeltool -a com.github.vinceliuice.Orchis-dark || true
fi

if command -v kwriteconfig5 &>/dev/null; then
    kwriteconfig5 --file kdeglobals --group General --key widgetStyle "kvantum"
    kwriteconfig5 --file kdeglobals --group Icons --key Theme "Tela-circle-dark"
    kwriteconfig5 --file plasmarc --group Theme --key name "Orchis-dark"

    mkdir -p "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"
    kwriteconfig5 --file "$HOME/.config/gtk-3.0/settings.ini" --group Settings --key gtk-icon-theme-name "Tela-circle-dark"
    kwriteconfig5 --file "$HOME/.config/gtk-4.0/settings.ini" --group Settings --key gtk-icon-theme-name "Tela-circle-dark"

    # 6. KWin Configuration (macOS/GNOME Top-Left buttons & Overview Hot Corner)
    kwriteconfig5 --file kwinrc --group Plugins --key overviewEnabled "true"
    kwriteconfig5 --file kwinrc --group ElectricBorders --key TopLeft "Overview"
    kwriteconfig5 --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnLeft "XIA"
    kwriteconfig5 --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnRight ""
    kwriteconfig5 --file kwinrc --group org.kde.kdecoration2 --key BorderSize "None"
    kwriteconfig5 --file kwinrc --group org.kde.kdecoration2 --key BorderSizeAuto "false"
    kwriteconfig5 --file kwinrc --group org.kde.kdecoration2 --key library "org.kde.kwin.aurorae"
    kwriteconfig5 --file kwinrc --group org.kde.kdecoration2 --key theme "__aurorae__svg__Orchis-dark"
fi

# 7. Apply Plasma Panels Layout (Top Bar + Centered Floating Dock)
echo "--> Applying Plasma panel layout (Top Bar + Centered Dock)..."
if command -v qdbus &>/dev/null && qdbus org.kde.plasmashell /PlasmaShell &>/dev/null; then
    qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript '
        // Remove existing panels
        var curPanels = panels();
        for (var i = 0; i < curPanels.length; i++) {
            curPanels[i].remove();
        }

        // Set Wallpaper
        var allDesktops = desktops();
        for (var i = 0; i < allDesktops.length; i++) {
            var d = allDesktops[i];
            d.wallpaperPlugin = "org.kde.image";
            d.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
            d.writeConfig("Image", "file:///usr/share/wallpapers/Orchis/contents/images/3840x2560.jpg");
            d.writeConfig("FillMode", "2");
        }

        // Top Status Bar
        var topBar = new Panel();
        topBar.location = "top";
        topBar.height = 30;

        var launcher = topBar.addWidget("org.kde.plasma.kickoff");
        launcher.currentConfigGroup = ["Configuration", "General"];
        launcher.writeConfig("icon", "start-here-kde");

        var appmenu = topBar.addWidget("org.kde.plasma.appmenu");

        var s1 = topBar.addWidget("org.kde.plasma.panelspacer");
        s1.currentConfigGroup = ["Configuration", "General"];
        s1.writeConfig("expanding", "true");

        var clock = topBar.addWidget("org.kde.plasma.digitalclock");
        clock.currentConfigGroup = ["Configuration", "Appearance"];
        clock.writeConfig("showDate", "false");
        clock.writeConfig("displayTimezoneFormat", "None");

        var s2 = topBar.addWidget("org.kde.plasma.panelspacer");
        s2.currentConfigGroup = ["Configuration", "General"];
        s2.writeConfig("expanding", "true");

        var tray = topBar.addWidget("org.kde.plasma.systemtray");

        // Bottom Dock
        var dock = new Panel();
        dock.location = "bottom";
        dock.height = 60;
        dock.alignment = "center";

        var tasks = dock.addWidget("org.kde.plasma.icontasks");
        tasks.currentConfigGroup = ["Configuration", "General"];
        tasks.writeConfig("launchers", [
            "applications:app.zen_browser.zen.desktop",
            "applications:com.mitchellh.ghostty.desktop",
            "applications:code.desktop",
            "applications:org.kde.dolphin.desktop",
            "applications:spotify_spotify.desktop",
            "applications:discord_discord.desktop",
            "applications:obsidian_md.obsidian.Obsidian.desktop",
            "applications:systemsettings.desktop"
        ]);
    ' || true

    # Configure dock floating and alignment in plasmashellrc
    if [ -f "$HOME/.config/plasmashellrc" ]; then
        DOCK_ID=$(qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript 'var p = panels(); print(p[p.length-1].id);' 2>/dev/null || echo 144)
        kwriteconfig5 --file "$HOME/.config/plasmashellrc" --group PlasmaViews --group "Panel $DOCK_ID" --key alignment "130" || true
        kwriteconfig5 --file "$HOME/.config/plasmashellrc" --group PlasmaViews --group "Panel $DOCK_ID" --key floating "1" || true
        kwriteconfig5 --file "$HOME/.config/plasmashellrc" --group PlasmaViews --group "Panel $DOCK_ID" --key panelVisibility "0" || true
        kwriteconfig5 --file "$HOME/.config/plasmashellrc" --group PlasmaViews --group "Panel $DOCK_ID" --group Defaults --key thickness "60" || true
    fi
fi

# 8. Refresh Caches and Restart Windows/Panels
echo "--> Refreshing caches and window manager..."
if command -v kbuildsycoca5 &>/dev/null; then
    kbuildsycoca5 --noincremental || true
fi

killall plasmashell || true
sleep 1
nohup kstart5 plasmashell >/dev/null 2>&1 &
nohup kwin_x11 --replace >/dev/null 2>&1 &

# Cleanup
rm -rf "$TMP_DIR"

echo "==> KDE Orchis rice applied successfully!"
