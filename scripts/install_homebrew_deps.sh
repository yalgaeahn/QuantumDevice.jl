#!/usr/bin/env bash
set -euo pipefail

BREW_BIN="${BREW_BIN:-/opt/homebrew/bin/brew}"

if [[ ! -x "$BREW_BIN" ]]; then
  echo "Homebrew not found at: $BREW_BIN" >&2
  exit 1
fi

exec "$BREW_BIN" install spack cmake pkgconf gcc
