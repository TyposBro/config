#!/usr/bin/env bash
set -euo pipefail

PASEO_APP="/Applications/Paseo.app"
APP_DIST="${PASEO_APP}/Contents/Resources/app-dist"
INDEX_HTML="${APP_DIST}/index.html"
THEME_INSTALLED="${APP_DIST}/opencode-theme.css"

echo "==> Verifying Paseo OpenCode Theme..."

if [[ ! -f "$THEME_INSTALLED" ]]; then
  echo "error: $THEME_INSTALLED does not exist" >&2
  exit 1
fi

if ! grep -q "id=\"opencode-theme-css\"" "$INDEX_HTML"; then
  echo "error: index.html missing opencode-theme-css stylesheet tag" >&2
  exit 1
fi

echo "==> Verifying Paseo daemon status..."
if command -v paseo >/dev/null 2>&1; then
  paseo daemon status --json >/dev/null 2>&1 && echo "==> Paseo daemon is active and valid."
fi

echo "==> Verification passed: OpenCode Theme is installed and active in Paseo."
