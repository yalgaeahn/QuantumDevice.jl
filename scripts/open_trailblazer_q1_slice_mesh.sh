#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MESH_PATH="${TRAILBLAZER_SLICE_MESH:-$ROOT/build/trailblazer-q1-purcell-slice/device.msh}"
MODE="${1:-}"

if [[ "$MODE" == "--help" ]]; then
  cat <<'EOF'
Usage:
  ./scripts/open_trailblazer_q1_slice_mesh.sh
  ./scripts/open_trailblazer_q1_slice_mesh.sh --live

Default: open the existing TrailBlazer Q1 slice mesh in Gmsh.
--live: rebuild the slice into an in-memory SolidModel and open the Gmsh FLTK viewer.
EOF
  exit 0
fi

if [[ "$MODE" == "--live" ]]; then
  shift
  exec "$ROOT/scripts/julia.sh" "$ROOT/scripts/open_trailblazer_q1_slice_mesh.jl" "$@"
fi

if [[ ! -f "$MESH_PATH" ]]; then
  echo "TrailBlazer slice mesh not found: $MESH_PATH" >&2
  echo "Run ./scripts/build_trailblazer_q1_slice.sh first." >&2
  exit 1
fi

GMSH_BIN="${GMSH_BIN:-}"
if [[ -n "$GMSH_BIN" ]]; then
  exec "$GMSH_BIN" "$MESH_PATH"
fi

if command -v gmsh >/dev/null 2>&1; then
  exec "$(command -v gmsh)" "$MESH_PATH"
fi

GMSH_APP="${GMSH_APP:-}"
if [[ -z "$GMSH_APP" ]]; then
  for candidate in \
    "$HOME/Applications/Gmsh.app" \
    /Applications/Gmsh.app
  do
    if [[ -d "$candidate" ]]; then
      GMSH_APP="$candidate"
      break
    fi
  done
fi

if [[ -n "$GMSH_APP" ]]; then
  echo "Opening Gmsh with: $MESH_PATH"
  exec open -a "$GMSH_APP" "$MESH_PATH"
fi

echo "Could not find Gmsh. Set GMSH_BIN or GMSH_APP, or install it with 'brew install gmsh'." >&2
exit 1
