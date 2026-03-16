# QuantumDevice Plan

## Vision

`QuantumDevice.jl` should become a Julia-first toolkit for superconducting quantum circuit layout generation, electromagnetic model assembly, PALACE execution, and result extraction.

The package direction is:

- use `DeviceLayout.jl` for geometry, schematic-driven layout, and mesh generation
- use PALACE for eigenmode and field solves
- keep generated meshes, solver inputs, and results reproducible inside the workspace
- expose a reusable Julia API instead of relying only on shell scripts

## Current Baseline

The repository is currently a workflow scaffold rather than a conventional Julia package.

- There is no `src/` tree or `QuantumDevice` module yet.
- The main logic lives in `scripts/build_transmon.jl` and `scripts/build_star_transmon.jl`.
- `scripts/build_transmon.jl` stages the upstream `DeviceLayout.jl` `SingleTransmon` example into `build/transmon/work/`.
- `scripts/build_star_transmon.jl` defines a local star-transmon plus filtered-readout case using `ExamplePDK` components.
- PALACE is invoked through `scripts/run_palace.sh` and `scripts/run_star_transmon.sh`.
- ParaView is used for interactive inspection and static rendering.

## Near-Term Priorities

### Phase 0: Repository Contract

- Keep `build/`, `results/`, and `figures/` as generated-artifact directories.
- Treat `scripts/` as the current source of truth until package modules exist.
- Document the execution model in `README.md`, `ARCHITECTURE.md`, and `AGENT.md`.

Exit criteria:

- a new contributor can build and run both reference cases using only the documented commands

### Phase 1: Package Skeleton

- Add `src/QuantumDevice.jl`.
- Move shared path handling, case setup, and config writing out of ad hoc scripts into Julia modules.
- Keep the shell scripts as thin wrappers over package entrypoints.

Suggested first modules:

- `QuantumDevice.Paths`
- `QuantumDevice.Cases`
- `QuantumDevice.Palace`
- `QuantumDevice.Results`

Exit criteria:

- the shell scripts delegate to package code instead of owning the workflow logic

### Phase 2: Typed Case and Solver APIs

- Replace loosely structured dictionaries and duplicated path logic with typed Julia structs.
- Define stable interfaces for case build, solver config generation, and run metadata.
- Centralize PALACE JSON generation so case builders describe physics and topology rather than emitting raw configuration fragments.

Candidate core types:

- `CaseSpec`
- `BuildArtifacts`
- `PalaceConfig`
- `RunConfig`
- `CaseResult`

Exit criteria:

- both the transmon and star-transmon flows can be built through a shared API

### Phase 3: Post-Processing and Analysis

- Add Julia utilities for parsing PALACE CSV outputs.
- Promote common derived quantities such as eigenfrequencies, Q values, and participation summaries into package APIs.
- Decide which visualization steps stay in ParaView and which should gain Julia-native reporting.

Exit criteria:

- result summaries no longer require manual CSV inspection

### Phase 4: Testing and Automation

- Add a `test/` tree.
- Cover path generation, config generation, and smoke-test case builds.
- Add schema checks for emitted `palace.json`.
- Add a lightweight CI lane for non-solver checks and a documented manual path for full PALACE validation.

Exit criteria:

- the repository can catch config regressions before running large solves

### Phase 5: Product Features

- add parameter sweeps and optimization entrypoints
- add support for more circuit families beyond the two current reference cases
- add reusable reporting for benchmark and convergence studies
- define a stable public API for downstream design automation

## Immediate Implementation Order

1. Create `src/QuantumDevice.jl` and move shared filesystem/config helpers there.
2. Refactor the two Julia build scripts to call package functions.
3. Add `test/runtests.jl` with non-solver validation of generated configs.
4. Introduce Julia result parsers for `eig.csv`, `domain-E.csv`, and port summaries.
5. Revisit whether artifact outputs should remain checked into the repository.

## Non-Goals For The First Package Pass

- replacing `DeviceLayout.jl`
- replacing PALACE
- building a full GUI
- hiding external tool dependencies behind opaque automation

## Definition Of Done For The Initial Package Milestone

The first real `QuantumDevice.jl` milestone is complete when:

- `src/QuantumDevice.jl` exists and is the main entrypoint
- both reference cases build through reusable Julia APIs
- PALACE config generation is centralized and tested
- result parsing has a minimal Julia API
- shell scripts remain available, but are wrappers rather than the core implementation
