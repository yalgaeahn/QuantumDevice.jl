#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

export PALACE_CONFIG="${PALACE_CONFIG:-$ROOT/build/qmetal-transmon/palace.json}"
export PALACE_RESULTS_DIR="${PALACE_RESULTS_DIR:-$ROOT/results/qmetal-transmon}"

exec "$ROOT/scripts/run_palace.sh" "$@"
