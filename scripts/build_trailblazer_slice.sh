#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${1:-Q_1}"

"$ROOT/scripts/export_trailblazer_spec.sh"
exec "$ROOT/scripts/julia.sh" "$ROOT/scripts/build_trailblazer_slice.jl" "$TARGET" "${2:-1}"
