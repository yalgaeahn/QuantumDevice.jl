#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
JULIA_VERSION_DEFAULT="${JULIA_VERSION_DEFAULT:-1.10.11}"
JULIA_BIN_DEFAULT="$HOME/.julia/juliaup/julia-${JULIA_VERSION_DEFAULT}+0.aarch64.apple.darwin14/Julia-1.10.app/Contents/Resources/julia/bin/julia"

resolve_juliaup_binary() {
  local juliaup_bin
  local resolved

  if ! command -v juliaup >/dev/null 2>&1; then
    return 1
  fi
  juliaup_bin="$(command -v juliaup)"

  if [[ -z "${JULIAUP_DEPOT_PATH:-}" ]]; then
    if [[ -d "$HOME/.julia/juliaup" ]]; then
      export JULIAUP_DEPOT_PATH="$HOME/.julia/juliaup"
    elif [[ -d "$HOME/.juliaup" ]]; then
      export JULIAUP_DEPOT_PATH="$HOME/.juliaup"
    fi
  fi

  resolved="$("$juliaup_bin" which "$JULIA_VERSION_DEFAULT" 2>/dev/null || true)"
  [[ -n "$resolved" && -x "$resolved" ]] || return 1
  printf '%s\n' "$resolved"
}

if [[ -n "${JULIA_BIN:-}" ]]; then
  JULIA_BIN="$JULIA_BIN"
elif [[ -x "$JULIA_BIN_DEFAULT" ]]; then
  JULIA_BIN="$JULIA_BIN_DEFAULT"
elif JULIA_BIN_RESOLVED="$(resolve_juliaup_binary)"; then
  JULIA_BIN="$JULIA_BIN_RESOLVED"
elif command -v julia >/dev/null 2>&1; then
  JULIA_BIN="$(command -v julia)"
else
  JULIA_BIN="$JULIA_BIN_DEFAULT"
fi

if [[ ! -x "$JULIA_BIN" ]]; then
  echo "Julia binary not found: $JULIA_BIN" >&2
  exit 1
fi

export JULIA_PROJECT="$ROOT"
export JULIA_DEPOT_PATH="${JULIA_DEPOT_PATH:-$ROOT/.julia_depot}"

exec "$JULIA_BIN" "$@"
