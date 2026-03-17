#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

slice_slug() {
  local target="$1"
  local normalized
  normalized="$(printf '%s' "$target" | tr '[:upper:]' '[:lower:]' | tr -d '_')"
  printf 'trailblazer-%s-local-context' "$normalized"
}

TARGET="${1:-Q_1}"
shift || true

SLUG="$(slice_slug "$TARGET")"
export PALACE_CONFIG="${PALACE_CONFIG:-$ROOT/build/$SLUG/palace.json}"
export PALACE_RESULTS_DIR="${PALACE_RESULTS_DIR:-$ROOT/results/$SLUG}"

exec "$ROOT/scripts/run_palace.sh" "$@"
