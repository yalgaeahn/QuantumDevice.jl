# Architecture

## Overview

`QuantumDevice.jl` currently operates as a script-first workflow for superconducting quantum circuit design and electromagnetic simulation, with a growing amount of shared case logic now living under `src/`.

It uses:

- `DeviceLayout.jl` for layout generation, schematic-driven construction, and mesh/GDS creation
- PALACE for eigenmode solves
- ParaView for result inspection and static rendering

The repository should eventually become a reusable Julia package, but the current architecture is still an execution scaffold around four script-first case families, including two migration-oriented flows.

## System Flow

```text
user
  -> scripts/build_transmon.sh or scripts/build_star_transmon.sh or scripts/build_qmetal_transmon.sh or scripts/build_trailblazer_fullchip.sh or scripts/build_trailblazer_q1_slice.sh
  -> scripts/export_trailblazer_spec.sh (for the Berkeley notebook-backed migration)
  -> scripts/julia.sh
  -> Julia build script
  -> src/QuantumDevice.jl / src/TrailBlazer.jl
  -> DeviceLayout.jl geometry + mesh generation
  -> build/<case>/device.msh or device.gds or palace.json

user
  -> scripts/run_palace.sh or scripts/run_star_transmon.sh or scripts/run_qmetal_transmon.sh or scripts/run_trailblazer_q1_slice.sh
  -> palace
  -> results/<case>/eig.csv and related CSV outputs
  -> results/<case>/paraview/*

user
  -> scripts/open_paraview.sh or scripts/render_star_transmon_visuals.sh
  -> ParaView / pvpython
  -> figures/<case>/*
```

## Current Components

### 1. Julia Environment Layer

`scripts/julia.sh` defines the active Julia binary, sets `JULIA_PROJECT` to the repository root, and defaults `JULIA_DEPOT_PATH` to `.julia_depot/`.

This keeps dependency resolution local to the workspace.

### 2. Case Builder Layer

There are currently four maintained case builders.

`scripts/build_transmon.jl`

- activates the repository environment
- locates the installed `DeviceLayout.jl` package
- stages the upstream `SingleTransmon.jl` example into `build/transmon/work/`
- runs the example to generate mesh and GDS artifacts
- patches the PALACE config so output paths point into this workspace

`scripts/build_star_transmon.jl`

- activates the repository environment
- constructs a local star-transmon plus filtered-readout layout from `ExamplePDK` components
- generates mesh and GDS artifacts
- emits a PALACE eigenmode configuration with material, boundary, and port definitions

`scripts/build_qmetal_transmon.jl`

- activates the repository environment
- loads a normalized migration spec from `inputs/qiskit-metal/qmetal-transmon/migration_spec.json`
- reconstructs a single-transmon layout natively in `DeviceLayout.jl`
- stages source reference artifacts into `build/qmetal-transmon/work/`
- emits mesh, GDS, and PALACE inputs under the existing workspace-local directory contract

`scripts/build_trailblazer_fullchip.jl`

- activates the repository environment
- loads the normalized Berkeley TrailBlazer full-chip spec from `inputs/qiskit-metal/trailblazer-fullchip/trailblazer_fullchip_spec.json`
- reconstructs the full 8-qubit layout natively with custom transmon, launchpad, open/short termination, and interdigital-cap components from `src/TrailBlazer.jl`
- writes the full-chip GDS and hook registry under `build/trailblazer-fullchip/`

`scripts/build_trailblazer_q1_slice.jl`

- activates the repository environment
- loads the same Berkeley TrailBlazer full-chip spec
- derives the `Q_1` plus Purcell slice from the full-chip component graph
- emits mesh, GDS, hook registry, and PALACE JSON under `build/trailblazer-q1-purcell-slice/`

Both builders write into:

- `build/<case>/device.msh`
- `build/<case>/device.gds`
- `build/<case>/palace.json`
- `results/<case>/`

### 3. Solver Runtime Layer

`scripts/run_palace.sh` is the shared runtime wrapper.

Responsibilities:

- resolve the PALACE input config
- locate or load `palace` from Spack if it is not already on `PATH`
- enforce the trusted runtime model with `OMP_NUM_THREADS=1`
- run PALACE with a configurable MPI rank count

`scripts/run_star_transmon.sh` is a thin wrapper that swaps in the star-transmon config and results directory.

`scripts/run_qmetal_transmon.sh` is the corresponding thin wrapper for the migrated qiskit-metal case.

`scripts/run_trailblazer_q1_slice.sh` is the thin wrapper for the Berkeley `Q_1` Purcell slice.

### 4. Visualization Layer

Interactive inspection is handled by `scripts/open_paraview.sh` and `scripts/open_star_transmon.sh`.

Static rendering for the star-transmon case is handled by:

- `scripts/render_star_transmon_visuals.sh`
- `scripts/render_star_transmon_visuals.py`

The Python script reads PALACE CSV and ParaView data products and generates summary figures under `figures/star-transmon/`.

### 5. Machine Configuration Layer

External tool configuration is split across:

- `scripts/install_homebrew_deps.sh`
- `scripts/install_palace.sh`
- `scripts/install_paraview.sh`
- `spack-config/`
- `spack-repo-scope/`

This layer is intentionally explicit because PALACE is an external native dependency rather than a Julia package dependency.

## Directory Contract

- `scripts/`: maintained workflow entrypoints and current implementation
- `cases/`: case notes and context
- `inputs/`: staged migration reference inputs and normalized specs
- `src/`: emerging shared Julia implementation, including the Berkeley TrailBlazer component and build logic
- `build/`: generated meshes, staged scripts, and PALACE inputs
- `results/`: PALACE outputs
- `figures/`: rendered outputs
- `benchmarks/`: captured runtime and output comparisons
- `spack-config/` and `spack-repo-scope/`: PALACE installation/runtime configuration

## Architectural Constraints

- The repository is not yet a standard Julia package despite the project name.
- Shared logic still exists in scripts, but the Berkeley TrailBlazer migration has started moving reusable types and builders into `src/QuantumDevice.jl` and `src/TrailBlazer.jl`.
- The transmon reference flow depends on upstream `DeviceLayout.jl` example internals.
- The qiskit-metal migration flow currently depends on a checked-in normalized spec rather than direct qiskit-metal API ingestion.
- The Berkeley TrailBlazer migration depends on a checked-in staged notebook copy plus a normalized JSON spec emitted by `scripts/export_trailblazer_spec.py`.
- The PALACE runtime remains an external process boundary.
- Visualization depends on ParaView rather than a Julia-native plotting stack.
- The documented stable runtime is machine-specific: MPI-only with one OpenMP thread per rank.

## Target Architecture

The intended next architecture is:

```text
src/QuantumDevice.jl
  -> Paths
  -> Cases
  -> Palace
  -> Results
  -> Visualization or Reporting

scripts/*
  -> thin wrappers over package entrypoints
```

Recommended module responsibilities:

- `QuantumDevice.Paths`: repository-local path resolution
- `QuantumDevice.Cases`: reusable case specifications and build entrypoints
- `QuantumDevice.Migration`: notebook-to-spec exporters and validation helpers for notebook-backed migrations
- `QuantumDevice.Palace`: config generation and solver invocation helpers
- `QuantumDevice.Results`: CSV parsing and summary extraction
- `QuantumDevice.Reporting`: figure generation and benchmark summaries

## Architectural Direction

The key transition is from a script-owned workflow to a package-owned workflow.

That means:

- builder logic moves from standalone scripts into `src/`
- shell commands remain, but only as convenience wrappers
- emitted PALACE configuration becomes a tested API surface
- case definitions become reusable Julia objects rather than one-off scripts
