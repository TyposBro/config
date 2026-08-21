#!/usr/bin/env bash
set -euo pipefail

# OpenCode Theme uninstaller for Paseo Client.
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

if [[ -f "$ORIG_HTML" ]]; then
  echo "==> Restoring original index.html..."
  $SUDO cp "$ORIG_HTML" "$INDEX_HTML"
  $SUDO rm -f "$ORIG_HTML"
fi

if [[ -f "${APP_DIST}/opencode-theme.css" ]]; then
  echo "==> Removing opencode-theme.css..."
  $SUDO rm -f "${APP_DIST}/opencode-theme.css"
fi

if [[ -f "${APP_DIST}/opencode-zen.js" ]]; then
  echo "==> Removing opencode-zen.js..."
  $SUDO rm -f "${APP_DIST}/opencode-zen.js"
fi

if [[ -f "${APP_DIST}/moonlit-pine.jpg" ]]; then
  echo "==> Removing moonlit-pine.jpg..."
  $SUDO rm -f "${APP_DIST}/moonlit-pine.jpg"
fi

echo "==> Restored original Paseo styling."
