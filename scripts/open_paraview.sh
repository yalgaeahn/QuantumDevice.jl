#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="${PALACE_RESULTS_DIR:-$ROOT/results/transmon}"
TARGET="${1:-}"

if [[ -z "$TARGET" ]]; then
  while IFS= read -r candidate; do
    TARGET="$candidate"
    break
  done < <(find "$RESULTS_DIR" -type f \( -name '*.pvd' -o -name '*.pvtu' -o -name '*.vtu' -o -name '*.vtk' -o -name '*.visit' \) | sort)
fi

PARAVIEW_APP="${PARAVIEW_APP:-}"
if [[ -z "$PARAVIEW_APP" ]]; then
  for candidate in \
    "$HOME/Applications/ParaView"*.app \
    /Applications/ParaView*.app
  do
    if [[ -d "$candidate" ]]; then
      PARAVIEW_APP="$candidate"
      break
    fi
  done
fi

if [[ -z "$PARAVIEW_APP" ]]; then
  echo "Could not find a ParaView app. Set PARAVIEW_APP to the .app bundle path." >&2
  exit 1
fi

if [[ -n "$TARGET" && -e "$TARGET" ]]; then
  echo "Opening ParaView with: $TARGET"
  exec open -a "$PARAVIEW_APP" "$TARGET"
fi

echo "Opening ParaView without a file. Results are under: $RESULTS_DIR"
exec open -a "$PARAVIEW_APP"
