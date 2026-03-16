#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"$ROOT/scripts/export_trailblazer_spec.sh"
exec "$ROOT/scripts/julia.sh" "$ROOT/scripts/build_trailblazer_fullchip.jl" "$@"
