#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

export PALACE_CONFIG="${PALACE_CONFIG:-$ROOT/build/star-transmon/palace.json}"
export PALACE_RESULTS_DIR="${PALACE_RESULTS_DIR:-$ROOT/results/star-transmon}"

exec "$ROOT/scripts/run_palace.sh" "$@"
