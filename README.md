# QuantumDevice.jl

Native macOS scaffold for `DeviceLayout.jl`, `Palace`, and ParaView on Apple Silicon.

## Layout

- `cases/transmon/`: case-specific notes and upstream example staging
- `cases/qpu17-reference/`: local reference notes for the upstream `DemoQPU17` schematic flow
- `cases/star-transmon/`: workspace-local star-transmon + filtered-readout case notes
- `cases/qmetal-transmon/`: pilot qiskit-metal migration case notes
- `cases/trailblazer-fullchip/`: Berkeley TrailBlazer migration notes for the full chip and local-context slice workflow
- `inputs/qiskit-metal/qmetal-transmon/`: staged source design, migration spec, and optional reference GDS
- `inputs/qiskit-metal/trailblazer-fullchip/`: staged Berkeley TrailBlazer notebook, reference GDS, and normalized full-chip spec
- `build/transmon/`: generated schematic graph, layout, mesh, and Palace input files
- `build/qpu17-reference/`: generated schematic graph, layout, and GDS for the upstream QPU17 reference path
- `build/star-transmon/`: generated schematic graph, layout, mesh, and Palace input files for the second case
- `build/qmetal-transmon/`: generated schematic graph, layout, mesh, and Palace input files for the migrated case
- `build/trailblazer-fullchip/`: generated full-chip schematic graph, layout, GDS, staged source inputs, and hook registry for the Berkeley migration
- `build/trailblazer-q1-local-context/`: generated Q1 local-context slice schematic graph, layout, mesh, GDS, and Palace inputs
- `results/transmon/`: Palace outputs
- `results/star-transmon/`: Palace outputs for the second case
- `results/qmetal-transmon/`: Palace outputs for the migrated case
- `results/trailblazer-q1-local-context/`: Palace outputs for the Berkeley Q1 local-context slice
- `scripts/`: build, solve, and visualization entrypoints
- `.julia_depot/`: workspace-local Julia depot used by the helper scripts

## Toolchain choices

- Julia uses the direct `1.10.11` binary already installed through `juliaup`.
- Julia packages are installed into a workspace-local depot so this project does not depend on global `~/.julia` state.
- `Palace` is expected from a Spack install using the native `apple-clang` CPU-only spec that benchmarked best on this Mac Studio.
- The supported runtime is MPI-only on this machine: `4 MPI ranks x 1 OpenMP thread`.
- The workspace Spack scope keeps `openblas` pinned as the `blas` and `lapack` provider so native rebuilds avoid the `nvpl-*` path on macOS.
- ParaView defaults to an official macOS app install under `~/Applications`, with `/Applications` supported as an override.

## Commands

Instantiate the Julia environment:

```bash
./scripts/julia.sh -e 'using Pkg; Pkg.instantiate()'
```

Install the native Homebrew prerequisites:

```bash
./scripts/install_homebrew_deps.sh
```

Install Palace through Spack:

```bash
./scripts/install_palace.sh
```

Build the documented single-transmon case:

```bash
./scripts/build_transmon.sh
```

Build the local QPU17 reference case aligned with the upstream schematic-driven tutorial:

```bash
./scripts/build_qpu17_reference.sh
```

Build the workspace star-transmon case derived from the `DemoQPU17` component set:

```bash
./scripts/build_star_transmon.sh
```

Build the pilot qiskit-metal migration case:

```bash
./scripts/build_qmetal_transmon.sh
```

Refresh the Berkeley TrailBlazer notebook export and staged migration spec:

```bash
./scripts/export_trailblazer_spec.sh
```

Build the native Berkeley TrailBlazer full-chip migration:

```bash
./scripts/build_trailblazer_fullchip.sh
```

Build a graph-derived Berkeley local-context slice for any target qubit:

```bash
./scripts/build_trailblazer_slice.sh Q_1
./scripts/build_trailblazer_slice.sh Q_2 2
```

The existing `Q_1` convenience wrapper still works and now targets the canonical `trailblazer-q1-local-context` outputs:

```bash
./scripts/build_trailblazer_q1_slice.sh
./scripts/build_trailblazer_q1_slice.sh 2
```

Run the Palace solve with one MPI rank for the first validation pass:

```bash
./scripts/run_palace.sh 1
```

Run with the recommended safe default on this Mac Studio (`4 MPI x 1 thread`):

```bash
./scripts/run_palace.sh
```

Run the star-transmon case with the same stable MPI-only runtime:

```bash
./scripts/run_star_transmon.sh 1
./scripts/run_star_transmon.sh
```

Run the migrated qiskit-metal transmon case:

```bash
./scripts/run_qmetal_transmon.sh 1
./scripts/run_qmetal_transmon.sh
```

Run the Berkeley TrailBlazer `Q_1` local-context slice:

```bash
./scripts/run_trailblazer_q1_slice.sh 1
./scripts/run_trailblazer_q1_slice.sh
./scripts/run_trailblazer_slice.sh Q_2 1
```

Validate parameter parity, config shape, and optional GDS fidelity for the migrated case:

```bash
./scripts/validate_qmetal_transmon.sh
```

Validate the Berkeley TrailBlazer notebook export, full-chip artifacts, and Q1 local-context slice artifacts:

```bash
./scripts/validate_trailblazer_fullchip.sh
```

Open ParaView on the star-transmon results:

```bash
./scripts/open_star_transmon.sh
```

Open ParaView on the TrailBlazer local-context slice results:

```bash
./scripts/open_trailblazer_q1_slice.sh
./scripts/open_trailblazer_slice.sh Q_2
```

Open the built TrailBlazer local-context slice mesh in Gmsh, or rebuild and inspect it live:

```bash
./scripts/open_trailblazer_q1_slice_mesh.sh
./scripts/open_trailblazer_q1_slice_mesh.sh --live
./scripts/open_trailblazer_slice_mesh.sh Q_2
./scripts/open_trailblazer_slice_mesh.sh Q_2 --live
```

Tune MPI rank count explicitly on this Mac Studio:

```bash
./scripts/run_palace.sh 1
./scripts/run_palace.sh 4
```

Open ParaView, optionally with the first result file found under `results/transmon/`:

```bash
./scripts/open_paraview.sh
```

Install the official stable ParaView macOS app from upstream:

```bash
./scripts/install_paraview.sh
```

## Notes

- The build step stages the upstream `DeviceLayout.jl` single-transmon example into `build/transmon/work/` so all generated files stay inside this workspace.
- The repo-wide build contract is source-aligned: inspect `build/<case>/schematic_graph.svg` first, then `build/<case>/layout.svg`, then mesh/GDS artifacts, and only then `results/<case>/` for PALACE outputs.
- The local `qpu17-reference` case is the contract reference for schematic-driven builds in this repo. It stages and runs the upstream `DemoQPU17` example while emitting the same `schematic_graph.svg` / `layout.svg` / `device.gds` artifact set expected of local cases.
- The second case in `build/star-transmon/` is a workspace-local example built from `ExampleStarTransmon` and `ExampleFilteredHairpinReadout`, the same component family used in the `DemoQPU17` layout example.
- The `qmetal-transmon` case is a native `DeviceLayout.jl` reconstruction driven by a staged qiskit-metal-style source export in `inputs/qiskit-metal/qmetal-transmon/`.
- The migration workflow keeps the qiskit-metal Python-style parameter export as the semantic source of truth and treats `reference_layout.gds` as an optional validation artifact.
- The Berkeley TrailBlazer migration flow stages the real qiskit-metal notebook and reference GDS under `inputs/qiskit-metal/trailblazer-fullchip/`, exports a normalized full-chip spec, rebuilds the layout from a real `SchematicGraph` / `plan` / `check!` flow, and derives per-qubit local-context slices from graph connectivity.
- Purcell is now strict graph-derived slice context. With the current staged Berkeley notebook, `TL1` remains commented out, so the `Q_1` local-context slice excludes the disconnected Purcell branch until the source notebook exposes that connection as a real route.
- `scripts/open_trailblazer_slice_mesh.sh` mirrors the upstream single-transmon mesh-inspection workflow: it opens the built `.msh` in Gmsh by default, and `--live` rebuilds the selected slice into an in-memory `SolidModel` before launching the Gmsh FLTK viewer.
- The TrailBlazer mesh wrapper expects `gmsh` on `PATH` or a `Gmsh.app` install. If it is missing, install it with `brew install gmsh` or set `GMSH_BIN` / `GMSH_APP`.
- The TrailBlazer validation contract preserves GDS layers `1/10` and `1/100` as the required geometry-comparison layers.
- The star-transmon case has been validated with native Palace on this Mac Studio:
  `1 rank` found modes near `7.027994 GHz` and `8.676492 GHz`, and `4 ranks` reproduced the same modes while reducing runtime from about `152 s` to about `56.7 s`.
- If `palace` is not already on `PATH`, `scripts/run_palace.sh` tries to load it from Spack automatically.
- Apple Silicon GPUs are not a `Palace` acceleration target, so the intended native setup is CPU-only with `~cuda ~rocm`.
- The single-transmon case is an eigenmode workflow, so `+slepc` is intentionally enabled in the Palace build.
- `scripts/install_palace.sh` and `scripts/run_palace.sh` default to the local Spack scope in `spack-repo-scope/`, which now exists only to pin `openblas` as the provider for native rebuilds.
- `scripts/install_palace.sh` is idempotent: it checks for an existing matching Spack install first, refreshes compiler detection, and targets the kept `apple-clang` MPI-only Palace spec.
- `scripts/run_palace.sh` now always forces `OMP_NUM_THREADS=1` and ignores inherited OpenMP thread settings for stability.
- Current benchmark result on this machine:
  `clang 1x1` = `111.21 s`, `clang 4x1` = `33.13 s`, `gcc 1x1` = `104.25 s`, `gcc 4x1` = `39.07 s`.
- OpenMP threading on this machine is not supported for trusted runs:
  `1x4` = `83.46 s` with wrong eigenmodes, `2x4` = `91.44 s` with wrong eigenmodes.
- Recommended trusted runtime:
  `./scripts/run_palace.sh`
- `scripts/install_paraview.sh` uses the official ParaView `5.13.3` Apple Silicon DMG URL, resumes partial downloads with `curl -C -`, and installs to `~/Applications` by default.
- If the ParaView app is installed somewhere else, set `PARAVIEW_APP` before running `scripts/open_paraview.sh`, or set `PARAVIEW_APP_DEST` before running `scripts/install_paraview.sh`.
- `scripts/open_paraview.sh` prefers a user-local ParaView app in `~/Applications` and falls back to `/Applications`.
