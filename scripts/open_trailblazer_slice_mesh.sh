#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

slice_slug() {
  local target="$1"
  local normalized
  normalized="$(printf '%s' "$target" | tr '[:upper:]' '[:lower:]' | tr -d '_')"
  printf 'trailblazer-%s-local-context' "$normalized"
}

usage() {
  cat <<'EOF'
Usage:
  ./scripts/open_trailblazer_slice_mesh.sh Q_1
  ./scripts/open_trailblazer_slice_mesh.sh Q_1 --live

Default: open the built TrailBlazer local-context slice mesh in Gmsh.
--live: rebuild the slice into an in-memory SolidModel and open the Gmsh FLTK viewer.
EOF
}

if [[ "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

TARGET="${1:-Q_1}"
shift || true
MODE="${1:-}"

SLUG="$(slice_slug "$TARGET")"
MESH_PATH="${TRAILBLAZER_SLICE_MESH:-$ROOT/build/$SLUG/device.msh}"

if [[ "$MODE" == "--live" ]]; then
  exec "$ROOT/scripts/julia.sh" "$ROOT/scripts/open_trailblazer_slice_mesh.jl" "$TARGET"
fi

if [[ ! -f "$MESH_PATH" ]]; then
  echo "TrailBlazer slice mesh not found: $MESH_PATH" >&2
  echo "Run ./scripts/build_trailblazer_slice.sh $TARGET first." >&2
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
