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
RESULTS_DIR="${PALACE_RESULTS_DIR:-$ROOT/results/$SLUG}"
DATASET_TARGET="${1:-}"

if [[ -z "$DATASET_TARGET" ]]; then
  preferred="$RESULTS_DIR/paraview/eigenmode/eigenmode.pvd"
  if [[ -f "$preferred" ]]; then
    DATASET_TARGET="$preferred"
  else
    while IFS= read -r candidate; do
      DATASET_TARGET="$candidate"
      break
    done < <(find "$RESULTS_DIR" -type f \( -name '*.pvd' -o -name '*.pvtu' -o -name '*.vtu' -o -name '*.vtk' -o -name '*.visit' \) | sort)
  fi
fi

if [[ -z "$DATASET_TARGET" || ! -e "$DATASET_TARGET" ]]; then
  echo "No TrailBlazer ParaView dataset found under: $RESULTS_DIR" >&2
  echo "Run ./scripts/run_trailblazer_slice.sh $TARGET 1 first." >&2
  exit 1
fi

export PALACE_RESULTS_DIR="$RESULTS_DIR"
exec "$ROOT/scripts/open_paraview.sh" "$DATASET_TARGET"
