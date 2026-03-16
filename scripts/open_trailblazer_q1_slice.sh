#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="${PALACE_RESULTS_DIR:-$ROOT/results/trailblazer-q1-purcell-slice}"
TARGET="${1:-}"

if [[ -z "$TARGET" ]]; then
  preferred="$RESULTS_DIR/paraview/eigenmode/eigenmode.pvd"
  if [[ -f "$preferred" ]]; then
    TARGET="$preferred"
  else
    while IFS= read -r candidate; do
      TARGET="$candidate"
      break
    done < <(find "$RESULTS_DIR" -type f \( -name '*.pvd' -o -name '*.pvtu' -o -name '*.vtu' -o -name '*.vtk' -o -name '*.visit' \) | sort)
  fi
fi

if [[ -z "$TARGET" || ! -e "$TARGET" ]]; then
  echo "No TrailBlazer ParaView dataset found under: $RESULTS_DIR" >&2
  echo "Run ./scripts/run_trailblazer_q1_slice.sh 1 first." >&2
  exit 1
fi

export PALACE_RESULTS_DIR="$RESULTS_DIR"
exec "$ROOT/scripts/open_paraview.sh" "$TARGET"
