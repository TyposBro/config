#!/usr/bin/env bash
set -euo pipefail

# OpenCode Theme installer for Paseo Client (idempotent).
#   1. Copies opencode-theme.css into Paseo Desktop's web asset directory.
#   2. Injects the stylesheet link into index.html (with backup of original).
#   3. Normalizes ~/.paseo/config.json if invalid daemon keys are present.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEME_CSS="${HERE}/opencode-theme.css"
ZEN_JS="${HERE}/opencode-zen.js"
PASEO_CONFIG="${PASEO_HOME:-$HOME/.paseo}/config.json"

find_app_dist() {
  if [[ -n "${PASEO_APP_DIST:-}" && -d "$PASEO_APP_DIST" ]]; then
    echo "$PASEO_APP_DIST"
    return 0
  fi
  if [[ -n "${PASEO_APP:-}" ]]; then
    for sub in "Contents/Resources/app-dist" "resources/app-dist" "app-dist"; do
      if [[ -d "${PASEO_APP}/${sub}" ]]; then
        echo "${PASEO_APP}/${sub}"
        return 0
      fi
    done
    if [[ -d "$PASEO_APP" && -f "$PASEO_APP/index.html" ]]; then
      echo "$PASEO_APP"
      return 0
    fi
  fi

  local candidates=(
    # macOS
    "/Applications/Paseo.app/Contents/Resources/app-dist"
    "$HOME/Applications/Paseo.app/Contents/Resources/app-dist"
    # Linux
    "/opt/Paseo/resources/app-dist"
    "/opt/paseo/resources/app-dist"
    "/usr/lib/paseo/resources/app-dist"
    "/usr/lib/Paseo/resources/app-dist"
    "/usr/share/paseo/resources/app-dist"
    "/usr/share/Paseo/resources/app-dist"
    "$HOME/.local/share/Paseo/resources/app-dist"
    "$HOME/.local/share/paseo/resources/app-dist"
    # Windows (Git Bash / MSYS / Cygwin / WSL)
    "${PROGRAMFILES:-/c/Program Files}/Paseo/resources/app-dist"
    "${LOCALAPPDATA:-/c/Users/${USER:-}/AppData/Local}/Programs/Paseo/resources/app-dist"
    "/c/Program Files/Paseo/resources/app-dist"
    "/c/Program Files (x86)/Paseo/resources/app-dist"
    "/mnt/c/Program Files/Paseo/resources/app-dist"
  )

  for cand in "${candidates[@]}"; do
    if [[ -d "$cand" && -f "$cand/index.html" ]]; then
      echo "$cand"
      return 0
    fi
  done

  return 1
}

echo "==> Checking Paseo Desktop installation..."
if ! APP_DIST="$(find_app_dist)"; then
  echo "error: Paseo Desktop installation not found. Set PASEO_APP_DIST or PASEO_APP environment variable." >&2
  exit 1
fi

INDEX_HTML="${APP_DIST}/index.html"
ORIG_HTML="${APP_DIST}/index.html.orig"

echo "==> Found Paseo Desktop web assets at: $APP_DIST"

SUDO=""
if [[ ! -w "$APP_DIST" || (! -w "$INDEX_HTML" && -f "$INDEX_HTML") ]]; then
  if [[ $EUID -ne 0 ]]; then
    if command -v sudo >/dev/null 2>&1; then
      SUDO="sudo"
    else
      echo "error: $APP_DIST requires elevated permissions but sudo is not available." >&2
      exit 1
    fi
  fi
fi

# 1. Backup original index.html if not already backed up
if [[ ! -f "$ORIG_HTML" ]]; then
  echo "==> Creating backup: $ORIG_HTML"
  $SUDO cp "$INDEX_HTML" "$ORIG_HTML"
fi

# 2. Copy theme stylesheet, background assets & Zen spotlight script
echo "==> Copying Moonlit Pine & OpenCode theme assets to $APP_DIST"
$SUDO cp "$THEME_CSS" "${APP_DIST}/opencode-theme.css"
if [[ -f "$ZEN_JS" ]]; then
  $SUDO cp "$ZEN_JS" "${APP_DIST}/opencode-zen.js"
fi
if [[ -f "${HERE}/moonlit-pine.jpg" ]]; then
  $SUDO cp "${HERE}/moonlit-pine.jpg" "${APP_DIST}/moonlit-pine.jpg"
fi

# 3. Inject stylesheet & Zen spotlight script into index.html idempotently
if ! grep -q "id=\"opencode-theme-css\"" "$INDEX_HTML"; then
  echo "==> Injecting stylesheet link into index.html..."
  if sed --version >/dev/null 2>&1; then
    $SUDO sed -i 's|</head>|<link rel="stylesheet" href="/opencode-theme.css" id="opencode-theme-css"></head>|' "$INDEX_HTML"
  else
    $SUDO sed -i '' 's|</head>|<link rel="stylesheet" href="/opencode-theme.css" id="opencode-theme-css"></head>|' "$INDEX_HTML"
  fi
else
  echo "==> Stylesheet link already present in index.html"
fi

if ! grep -q "id=\"opencode-zen-js\"" "$INDEX_HTML"; then
  echo "==> Injecting Zen spotlight script into index.html..."
  if sed --version >/dev/null 2>&1; then
    $SUDO sed -i 's|</body>|<script src="/opencode-zen.js" id="opencode-zen-js" defer></script></body>|' "$INDEX_HTML"
  else
    $SUDO sed -i '' 's|</body>|<script src="/opencode-zen.js" id="opencode-zen-js" defer></script></body>|' "$INDEX_HTML"
  fi
else
  echo "==> Zen spotlight script already present in index.html"
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
echo "    If Paseo is currently open, reload the window (Cmd+R / Ctrl+R) or restart the app."
