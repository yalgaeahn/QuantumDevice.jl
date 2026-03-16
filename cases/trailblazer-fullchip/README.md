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

Build the first PALACE-ready slice:

```bash
./scripts/build_trailblazer_q1_slice.sh
```

Run the `Q_1` slice in PALACE:

```bash
./scripts/run_trailblazer_q1_slice.sh 1
```

Validate source parity and generated artifacts:

```bash
./scripts/validate_trailblazer_fullchip.sh
```

## Inspect

The build outputs now include layout graphics beside the generated GDS:

- `build/trailblazer-fullchip/layout.svg`
- `build/trailblazer-fullchip/layout.png`
- `build/trailblazer-q1-purcell-slice/layout.svg`
- `build/trailblazer-q1-purcell-slice/layout.png`

The standardized placement-review bundle now sits next to those raw geometry exports:

- `build/trailblazer-fullchip/placement_graph.svg`
- `build/trailblazer-fullchip/placement_registry.json`
- `build/trailblazer-fullchip/connectivity.json`
- `build/trailblazer-q1-purcell-slice/placement_graph.svg`
- `build/trailblazer-q1-purcell-slice/placement_registry.json`
- `build/trailblazer-q1-purcell-slice/connectivity.json`

Use the placement graph as the first visual check when you want to answer “is each component where it should be?” It overlays route classes and component bounding boxes/labels in a QPU17-style component-aware view. Use the placement registry and connectivity JSON when you want machine-readable centers, bounds, orientations, and route endpoints.

Open the built Q1 slice mesh in Gmsh:

```bash
./scripts/open_trailblazer_q1_slice_mesh.sh
```

Rebuild the slice into an in-memory `SolidModel` and inspect it live in the Gmsh FLTK viewer:

```bash
./scripts/open_trailblazer_q1_slice_mesh.sh --live
```

Open the Q1 slice PALACE fields in ParaView:

```bash
./scripts/open_trailblazer_q1_slice.sh
```

Render a compact static review set from the PALACE results:

```bash
./scripts/render_trailblazer_q1_slice_visuals.sh
```

If Gmsh is not installed yet, `./scripts/open_trailblazer_q1_slice_mesh.sh` tells you to install it with `brew install gmsh`. If ParaView is not installed yet, use `./scripts/install_paraview.sh`.

## Outputs

- `build/trailblazer-fullchip/` contains the native full-chip review bundle: GDS, hook registry, staged source copies, raw layout graphics, and the placement-review artifacts `placement_graph.*`, `placement_registry.json`, and `connectivity.json`.
- `build/trailblazer-q1-purcell-slice/` contains the simulation-ready slice geometry: mesh, GDS, Palace config, hook registry, staged source copies, layout graphics, and the same placement-review bundle.
- `results/trailblazer-q1-purcell-slice/` contains PALACE numerical outputs and ParaView datasets.
- `figures/trailblazer-q1-purcell-slice/` contains optional static screenshots and the eigenmode summary graphic.

## Current assumptions

- The notebook is the semantic source of truth.
- The reference GDS is the geometry-validation artifact.
- GDS layers `1/10` and `1/100` are preserved as the validation layers for generated output checks.
- `TL1` is intentionally not instantiated because it is commented out in the notebook source.
