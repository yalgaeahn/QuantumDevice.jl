#!/usr/bin/env bash
set -euo pipefail

export PATH="/opt/homebrew/bin:$PATH"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${PALACE_CONFIG:-$ROOT/build/transmon/palace.json}"
RESULTS_DIR="${PALACE_RESULTS_DIR:-$ROOT/results/transmon}"
SPACK_EXE="${SPACK_EXE:-/opt/homebrew/bin/spack}"
SPACK_SCOPE="${SPACK_SCOPE:-$ROOT/spack-repo-scope}"
PALACE_SPEC="${PALACE_SPEC:-palace+arpack+gslib~int64~ipo~libxsmm~mumps~openmp~rocm+shared+slepc~strumpack~sundials+superlu-dist %c,cxx=apple-clang@17.0.0 %fortran=gcc@15.2.0 ^openblas threads=none}"
PALACE_BIN="${PALACE_BIN:-}"
MPI_RANKS="${1:-4}"
INHERITED_OMP_NUM_THREADS="${OMP_NUM_THREADS:-}"
INHERITED_PALACE_THREADS="${PALACE_THREADS:-}"

spack_cmd=("$SPACK_EXE")
if [[ -d "$SPACK_SCOPE" ]]; then
  spack_cmd+=("-C" "$SPACK_SCOPE")
fi

if [[ $# -gt 0 ]]; then
  shift
fi

if [[ ! -f "$CONFIG" ]]; then
  echo "Palace config not found: $CONFIG" >&2
  echo "Run ./scripts/build_transmon.sh first." >&2
  exit 1
fi

if [[ -z "$PALACE_BIN" ]] && command -v palace >/dev/null 2>&1; then
  PALACE_BIN="$(command -v palace)"
fi

if [[ -z "$PALACE_BIN" ]]; then
  if [[ -x "$SPACK_EXE" ]]; then
    set +e
    spack_load_sh="$("${spack_cmd[@]}" load --sh "$PALACE_SPEC" 2>/dev/null)"
    spack_status=$?
    set -e
    if [[ $spack_status -eq 0 ]]; then
      eval "$spack_load_sh"
    fi
  fi
fi

if [[ -z "$PALACE_BIN" ]] && command -v palace >/dev/null 2>&1; then
  PALACE_BIN="$(command -v palace)"
fi

if [[ -z "$PALACE_BIN" ]]; then
  echo "palace is not available on PATH and could not be loaded from Spack." >&2
  exit 1
fi

if ! command -v mpirun >/dev/null 2>&1; then
  echo "mpirun is not available on PATH." >&2
  exit 1
fi

mkdir -p "$RESULTS_DIR"
unset PALACE_THREADS || true
export OMP_NUM_THREADS=1

if [[ -n "$INHERITED_OMP_NUM_THREADS" || -n "$INHERITED_PALACE_THREADS" ]]; then
  echo "Ignoring inherited OpenMP thread settings; using OMP_NUM_THREADS=1 for stability." >&2
fi

echo "Using palace: $PALACE_BIN"
echo "Using mpirun: $(command -v mpirun)"
echo "Using OMP_NUM_THREADS: $OMP_NUM_THREADS"
echo "Writing results under: $RESULTS_DIR"

exec mpirun -np "$MPI_RANKS" "$PALACE_BIN" "$CONFIG" "$@"
