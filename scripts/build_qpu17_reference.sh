#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

exec "$ROOT/scripts/julia.sh" "$ROOT/scripts/build_qpu17_reference.jl" "$@"
