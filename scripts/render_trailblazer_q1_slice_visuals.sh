#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="${TRAILBLAZER_RESULTS_DIR:-$ROOT/results/trailblazer-q1-purcell-slice}"
PVPYTHON="${PVPYTHON:-$HOME/Applications/ParaView-5.13.3.app/Contents/bin/pvpython}"

if [[ ! -x "$PVPYTHON" ]]; then
  for candidate in \
    "$HOME/Applications/ParaView"*.app/Contents/bin/pvpython \
    /Applications/ParaView*.app/Contents/bin/pvpython
  do
    if [[ -x "$candidate" ]]; then
      PVPYTHON="$candidate"
      break
    fi
  done
fi

if [[ ! -f "$RESULTS_DIR/eig.csv" ]]; then
  echo "TrailBlazer eig.csv not found: $RESULTS_DIR/eig.csv" >&2
  echo "Run ./scripts/run_trailblazer_q1_slice.sh 1 first." >&2
  exit 1
fi

if [[ ! -f "$RESULTS_DIR/paraview/eigenmode/eigenmode.pvd" ]]; then
  echo "TrailBlazer ParaView dataset not found: $RESULTS_DIR/paraview/eigenmode/eigenmode.pvd" >&2
  echo "Run ./scripts/run_trailblazer_q1_slice.sh 1 first." >&2
  exit 1
fi

if [[ ! -x "$PVPYTHON" ]]; then
  echo "pvpython not found. Install ParaView with ./scripts/install_paraview.sh or set PVPYTHON explicitly." >&2
  exit 1
fi

exec "$PVPYTHON" "$ROOT/scripts/render_trailblazer_q1_slice_visuals.py"
