# Agent Guide

This file explains how to work safely in this repository.

If your tooling only auto-loads `AGENTS.md`, duplicate or rename this file when needed.

## Project Reality

`QuantumDevice.jl` is intended to become a superconducting quantum circuit design and EM simulation package built on top of `DeviceLayout.jl` and PALACE.

Today, this repository is still script-driven.

- There is now an emerging shared Julia module under `src/QuantumDevice.jl`, with Berkeley TrailBlazer logic in `src/TrailBlazer.jl`.
- The workflow is still primarily driven by shell and Julia scripts under `scripts/`.
- The main supported cases are `transmon`, `star-transmon`, the pilot `qmetal-transmon` migration, and the Berkeley TrailBlazer full-chip plus local-context slice migration.
- There is also a local `qpu17-reference` build that mirrors the upstream schematic-driven example contract.
- Julia package dependencies are declared in `Project.toml`, but the repository still behaves more like a script-owned workspace than a finished package.

## Source Of Truth

Treat these files as authoritative:

- `scripts/build_transmon.jl`: stages and runs the upstream `DeviceLayout.jl` single-transmon example
- `scripts/build_star_transmon.jl`: defines the local star-transmon plus filtered-readout case
- `scripts/build_qmetal_transmon.jl`: reconstructs the pilot qiskit-metal single-transmon case from a normalized migration spec
- `scripts/export_trailblazer_spec.py`: stages the Berkeley notebook and reference GDS and emits the normalized full-chip migration spec
- `src/TrailBlazer.jl`: native TrailBlazer component definitions, full-chip builder, and graph-derived local-context slice builder
- `scripts/build_trailblazer_fullchip.jl`: rebuilds the Berkeley TrailBlazer full chip as a native `DeviceLayout.jl` layout
- `scripts/build_trailblazer_slice.jl`: derives and emits a target-qubit Berkeley local-context slice
- `scripts/run_palace.sh`: shared PALACE runtime wrapper
- `README.md`: operator-facing workflow and environment assumptions
- `cases/`: case notes and context, not the main implementation
- `inputs/qiskit-metal/qmetal-transmon/`: migration source artifacts and normalized spec
- `inputs/qiskit-metal/trailblazer-fullchip/`: staged Berkeley notebook, reference GDS, and normalized migration spec

Treat these directories as generated output unless the task is specifically about refreshing artifacts:

- `build/`
- `results/`

Do not hand-edit staged files under `build/transmon/work/` as if they were maintained source.

## Environment Assumptions

- The workflow is macOS-first and currently tuned for Apple Silicon.
- Julia is expected through `./scripts/julia.sh`.
- The default Julia depot is workspace-local: `.julia_depot/`.
- PALACE is expected from Spack, with local config under `spack-repo-scope/` and `spack-config/`.
- Stable runs are MPI-only. `scripts/run_palace.sh` forces `OMP_NUM_THREADS=1`.

## Safe Working Rules

- Prefer editing files in `scripts/`, `cases/`, and root documentation over editing generated artifacts.
- Treat `inputs/qiskit-metal/qmetal-transmon/` and `inputs/qiskit-metal/trailblazer-fullchip/` as maintained source, not throwaway generated output.
- When changing the workflow, keep paths workspace-local.
- Preserve environment-variable overrides such as `PALACE_CONFIG`, `PALACE_RESULTS_DIR`, `SPACK_EXE`, and `SPACK_SCOPE`.
- Keep shell wrappers thin. If logic grows, move it into Julia code.
- If you add package code, create `src/` and `test/` instead of expanding the generated `build/` tree.

## Common Commands

Instantiate Julia dependencies:

```bash
./scripts/julia.sh -e 'using Pkg; Pkg.instantiate()'
```

Build the reference cases:

```bash
./scripts/build_qpu17_reference.sh
./scripts/build_transmon.sh
./scripts/build_star_transmon.sh
./scripts/build_qmetal_transmon.sh
./scripts/build_trailblazer_fullchip.sh
./scripts/build_trailblazer_slice.sh Q_1
./scripts/build_trailblazer_q1_slice.sh
```

Run PALACE:

```bash
./scripts/run_palace.sh 1
./scripts/run_palace.sh
./scripts/run_star_transmon.sh 1
./scripts/run_star_transmon.sh
./scripts/run_qmetal_transmon.sh 1
./scripts/run_qmetal_transmon.sh
./scripts/run_trailblazer_slice.sh Q_1 1
./scripts/run_trailblazer_q1_slice.sh 1
./scripts/run_trailblazer_q1_slice.sh
```

Inspect results:

```bash
./scripts/open_paraview.sh
./scripts/open_trailblazer_slice.sh Q_1
./scripts/open_trailblazer_slice_mesh.sh Q_1
./scripts/open_star_transmon.sh
./scripts/open_trailblazer_q1_slice.sh
./scripts/open_trailblazer_q1_slice_mesh.sh
```

## Expected Contribution Pattern

For a new device case:

- add a Julia builder that writes to `build/<case>/`
- write PALACE outputs to `results/<case>/`
- add a short case note under `cases/<case>/`
- if the case is a migration, stage source inputs under `inputs/` and document the mapping assumptions
- only add shell wrappers if they improve usability

For PALACE config changes:

- keep JSON emission centralized
- preserve compatibility with the existing runtime wrapper
- avoid hard-coding machine-specific paths outside the existing environment variables

For documentation changes:

- update `README.md` for operator-facing command changes
- update `ARCHITECTURE.md` if the execution model changes
- update this file if the maintenance contract changes

## What Needs Extra Care

- `scripts/build_transmon.jl` depends on upstream `DeviceLayout.jl` example structure and filenames.
- `scripts/build_star_transmon.jl` uses `ExamplePDK` internals and custom PALACE material and boundary definitions.
- `scripts/build_qmetal_transmon.jl` assumes the normalized migration spec stays aligned with the staged qiskit-style source export.
- `scripts/export_trailblazer_spec.py` assumes the Berkeley notebook cells up to the layout/control-line section remain semantically compatible with the stub execution environment.
- `src/TrailBlazer.jl` assumes the TrailBlazer migration spec shape and route/component naming stay aligned with the exporter.
- `scripts/run_palace.sh` assumes the trusted runtime is `MPI ranks x 1 OpenMP thread`.
- Result inspection wrappers under `scripts/` assume ParaView or Gmsh is installed in the documented macOS locations.

## Recommended Next Refactor

The next structural improvement should be the creation of `src/QuantumDevice.jl` and migration of shared builder/runtime logic out of the shell and script layer.
