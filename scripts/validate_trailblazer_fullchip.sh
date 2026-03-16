#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"$ROOT/scripts/export_trailblazer_spec.sh"
exec python3 "$ROOT/scripts/validate_trailblazer_fullchip.py" "$@"
