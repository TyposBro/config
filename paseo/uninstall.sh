#!/usr/bin/env bash
set -euo pipefail

# OpenCode Theme uninstaller for Paseo Client.
PASEO_APP="/Applications/Paseo.app"
APP_DIST="${PASEO_APP}/Contents/Resources/app-dist"
INDEX_HTML="${APP_DIST}/index.html"
ORIG_HTML="${APP_DIST}/index.html.orig"

if [[ -f "$ORIG_HTML" ]]; then
  echo "==> Restoring original index.html..."
  cp "$ORIG_HTML" "$INDEX_HTML"
  rm -f "$ORIG_HTML"
fi

if [[ -f "${APP_DIST}/opencode-theme.css" ]]; then
  echo "==> Removing opencode-theme.css..."
  rm -f "${APP_DIST}/opencode-theme.css"
fi

echo "==> Restored original Paseo styling."
