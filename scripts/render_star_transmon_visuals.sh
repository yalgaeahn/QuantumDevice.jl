#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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

if [[ ! -x "$PVPYTHON" ]]; then
  echo "pvpython not found. Install ParaView with ./scripts/install_paraview.sh or set PVPYTHON explicitly." >&2
  exit 1
fi

exec "$PVPYTHON" "$ROOT/scripts/render_star_transmon_visuals.py"
