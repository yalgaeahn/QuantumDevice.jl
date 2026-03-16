#!/usr/bin/env bash
set -euo pipefail

export PATH="/opt/homebrew/bin:$PATH"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SPACK_EXE="${SPACK_EXE:-/opt/homebrew/bin/spack}"
SPACK_SCOPE="${SPACK_SCOPE:-$ROOT/spack-repo-scope}"
PALACE_SPEC="${PALACE_SPEC:-palace+arpack+gslib~int64~ipo~libxsmm~mumps~openmp~rocm+shared+slepc~strumpack~sundials+superlu-dist %c,cxx=apple-clang@17.0.0 %fortran=gcc@15.2.0 ^openblas threads=none}"

spack_cmd=("$SPACK_EXE")
if [[ -d "$SPACK_SCOPE" ]]; then
  spack_cmd+=("-C" "$SPACK_SCOPE")
fi

load_command() {
  local quoted_scope
  if [[ -d "$SPACK_SCOPE" ]]; then
    printf -v quoted_scope ' -C %q' "$SPACK_SCOPE"
  else
    quoted_scope=""
  fi
  printf 'eval "$(%q%s load --sh %q)"' "$SPACK_EXE" "$quoted_scope" "$PALACE_SPEC"
}

if [[ ! -x "$SPACK_EXE" ]]; then
  echo "Spack not found at: $SPACK_EXE" >&2
  exit 1
fi

if ! command -v gfortran >/dev/null 2>&1; then
  echo "gfortran is not available on PATH. Install the Homebrew gcc formula first." >&2
  exit 1
fi

if "${spack_cmd[@]}" find "$PALACE_SPEC" >/dev/null 2>&1; then
  echo "Palace is already installed in Spack for the target spec."
  echo "Load it in your shell with:"
  printf '  %s\n' "$(load_command)"
  exit 0
fi

echo "Refreshing Spack compiler detection with Homebrew compilers"
"$SPACK_EXE" compiler find /opt/homebrew/bin >/dev/null 2>&1 || true

echo "Resolving Palace with Spack config scope: ${SPACK_SCOPE:-<none>}"
read -r -a palace_spec_parts <<< "$PALACE_SPEC"
"${spack_cmd[@]}" spec "${palace_spec_parts[@]}" >/dev/null

echo "Installing Palace with Spack spec: $PALACE_SPEC"
"${spack_cmd[@]}" install --show-log-on-error "${palace_spec_parts[@]}"

echo "Palace installation complete."
echo "Load it in your shell with:"
printf '  %s\n' "$(load_command)"
