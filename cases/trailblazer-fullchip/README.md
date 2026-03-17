# Berkeley TrailBlazer

This case ports the Berkeley TrailBlazer qiskit-metal full-chip notebook into native `DeviceLayout.jl` components.

## Source artifacts

- Notebook: `inputs/qiskit-metal/trailblazer-fullchip/source_notebook.ipynb`
- Reference GDS: `inputs/qiskit-metal/trailblazer-fullchip/reference_layout.gds`
- Normalized migration spec: `inputs/qiskit-metal/trailblazer-fullchip/trailblazer_fullchip_spec.json`

## What is ported natively

- `TransmonPocket_sqnl` as a native pocket-transmon body plus junction-bearing transmon component
- `CapNInterdigital_sqnl` as a native interdigital capacitor with `north_end` and `south_end` hooks
- `LaunchpadWirebond`, `OpenToGround`, and `ShortToGround` as native termination components
- Full-chip bus, readout, control, and Purcell routes as named route specs with preserved endpoints and resolved waypoint exports

## Build workflow

Refresh the notebook-backed spec:

```bash
./scripts/export_trailblazer_spec.sh
```

Build the full chip:

```bash
./scripts/build_trailblazer_fullchip.sh
```

Build a local-context slice for any target qubit:

```bash
./scripts/build_trailblazer_slice.sh Q_1
./scripts/build_trailblazer_slice.sh Q_2
```

The `Q_1` convenience wrapper still works and targets the canonical `Q_1` local-context outputs:

```bash
./scripts/build_trailblazer_q1_slice.sh
./scripts/run_trailblazer_q1_slice.sh 1
```

Validate source parity and generated artifacts:

```bash
./scripts/validate_trailblazer_fullchip.sh
```

## Inspect

The build outputs now follow the repo-wide source-aligned contract:

- `build/trailblazer-fullchip/schematic_graph.svg`
- `build/trailblazer-fullchip/layout.svg`
- `build/trailblazer-fullchip/device.gds`
- `build/trailblazer-q1-local-context/schematic_graph.svg`
- `build/trailblazer-q1-local-context/layout.svg`
- `build/trailblazer-q1-local-context/device.gds`
- `build/trailblazer-q1-local-context/device.msh`
- `build/trailblazer-q1-local-context/palace.json`

Use `schematic_graph.svg` first when you want to answer “is each component where it should be?” It is generated from the actual `SchematicGraph` / planned `Schematic`, not from a postprocessed review overlay. Use `layout.svg` next to inspect rendered geometry, and only then move to mesh or PALACE outputs.

Open the built local-context slice mesh in Gmsh:

```bash
./scripts/open_trailblazer_q1_slice_mesh.sh
./scripts/open_trailblazer_slice_mesh.sh Q_2
```

Rebuild the selected slice into an in-memory `SolidModel` and inspect it live in the Gmsh FLTK viewer:

```bash
./scripts/open_trailblazer_q1_slice_mesh.sh --live
./scripts/open_trailblazer_slice_mesh.sh Q_2 --live
```

Open the local-context slice PALACE fields in ParaView:

```bash
./scripts/open_trailblazer_q1_slice.sh
./scripts/open_trailblazer_slice.sh Q_2
```

If Gmsh is not installed yet, `./scripts/open_trailblazer_q1_slice_mesh.sh` tells you to install it with `brew install gmsh`. If ParaView is not installed yet, use `./scripts/install_paraview.sh`.

## Outputs

- `build/trailblazer-fullchip/` contains the source-aligned full-chip build artifacts: `schematic_graph.svg`, `layout.svg`, `device.gds`, `hook_registry.json`, and staged source copies under `work/`.
- `build/trailblazer-q1-local-context/` contains the source-aligned `Q_1` slice build artifacts: `schematic_graph.svg`, `layout.svg`, `device.gds`, `device.msh`, `palace.json`, `hook_registry.json`, `slice_membership.json`, and staged source copies under `work/`.
- `results/trailblazer-q1-local-context/` contains PALACE numerical outputs and ParaView datasets.

## Current assumptions

- The notebook is the semantic source of truth.
- The reference GDS is the geometry-validation artifact.
- GDS layers `1/10` and `1/100` are preserved as the validation layers for generated output checks.
- `TL1` is intentionally not instantiated because it is commented out in the notebook source.
- Purcell is included in a slice only when the schematic graph connects it. With the current staged Berkeley notebook, the `Q_1` local-context slice excludes the disconnected Purcell branch.
