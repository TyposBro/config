#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$(uname -s)" in
  Darwin)
    "$root/bin/macos.sh"
    "$root/bin/macos-app-bindings.sh"
    ;;
  Linux)
    exec "$root/bin/linux.sh"
    ;;
  *)
    echo "Unsupported OS: $(uname -s)" >&2
    exit 1
    ;;
esac
