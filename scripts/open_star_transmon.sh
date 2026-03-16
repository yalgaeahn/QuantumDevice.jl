#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

export PALACE_RESULTS_DIR="${PALACE_RESULTS_DIR:-$ROOT/results/star-transmon}"

exec "$ROOT/scripts/open_paraview.sh" "$@"
