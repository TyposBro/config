#!/usr/bin/env bash
set -euo pipefail

# OpenCode Theme installer for Paseo Client (idempotent).
#   1. Copies opencode-theme.css into Paseo Desktop's web asset directory.
#   2. Injects the stylesheet link into index.html (with backup of original).
#   3. Normalizes ~/.paseo/config.json if invalid daemon keys are present.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASEO_APP="/Applications/Paseo.app"
APP_DIST="${PASEO_APP}/Contents/Resources/app-dist"
INDEX_HTML="${APP_DIST}/index.html"
ORIG_HTML="${APP_DIST}/index.html.orig"
THEME_CSS="${HERE}/opencode-theme.css"
PASEO_CONFIG="${PASEO_HOME:-$HOME/.paseo}/config.json"

echo "==> Checking Paseo Desktop installation..."
if [[ ! -d "$PASEO_APP" || ! -f "$INDEX_HTML" ]]; then
  echo "error: Paseo Desktop not found at $PASEO_APP" >&2
  exit 1
fi

# 1. Backup original index.html if not already backed up
if [[ ! -f "$ORIG_HTML" ]]; then
  echo "==> Creating backup: $ORIG_HTML"
  cp "$INDEX_HTML" "$ORIG_HTML"
fi

# 2. Copy theme stylesheet & background assets
echo "==> Copying Moonlit Pine & OpenCode theme assets to $APP_DIST"
cp "$THEME_CSS" "${APP_DIST}/opencode-theme.css"
if [[ -f "${HERE}/moonlit-pine.jpg" ]]; then
  cp "${HERE}/moonlit-pine.jpg" "${APP_DIST}/moonlit-pine.jpg"
fi

# 3. Inject stylesheet into index.html idempotently
if ! grep -q "id=\"opencode-theme-css\"" "$INDEX_HTML"; then
  echo "==> Injecting stylesheet link into index.html..."
  sed -i '' 's|</head>|<link rel="stylesheet" href="/opencode-theme.css" id="opencode-theme-css"></head>|' "$INDEX_HTML"
else
  echo "==> Stylesheet link already present in index.html"
fi

# 4. Clean ~/.paseo/config.json if invalid keys exist
if [[ -f "$PASEO_CONFIG" ]] && command -v jq >/dev/null 2>&1; then
  if jq -e '.daemon.agentProfiles != null' "$PASEO_CONFIG" >/dev/null 2>&1; then
    echo "==> Cleaning invalid keys in $PASEO_CONFIG"
    cp "$PASEO_CONFIG" "$PASEO_CONFIG.bak.$(date +%Y%m%d-%H%M%S)"
    jq 'del(.daemon.agentProfiles)' "$PASEO_CONFIG" > "$PASEO_CONFIG.tmp" && mv "$PASEO_CONFIG.tmp" "$PASEO_CONFIG"
  fi
fi

# 5. Apply Moonlit Pine skin persistently via paseo-skins loader if npx is available
if command -v npx >/dev/null 2>&1; then
  echo "==> Applying Moonlit Pine skin persistently (huangguang1999/paseo-skins)..."
  npx --yes github:huangguang1999/paseo-skins apply moonlit-pine --persist || echo "warning: paseo-skins apply failed, falling back to bundled theme assets"
fi

echo "==> Moonlit Pine & OpenCode Theme successfully applied to Paseo Desktop!"
echo "    If Paseo is currently open, reload the window (Cmd+R) or restart the app."
