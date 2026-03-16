# qiskit-metal Source Staging

This directory holds the source-of-truth artifacts for the pilot `qmetal-transmon` migration.

Files:

- `source_design.py`: a qiskit-metal-style Python parameter export used as the semantic reference
- `migration_spec.json`: normalized machine-readable handoff consumed by the Julia builder
- `reference_layout.gds`: optional exported qiskit-metal GDS used only for geometry comparison

Workflow:

1. Keep `source_design.py` aligned with the original qiskit-metal design intent.
2. Update `migration_spec.json` when a parameter is intentionally mapped or approximated.
3. Place the original exported qiskit-metal GDS at `reference_layout.gds` to enable geometry validation.

Notes:

- The Julia builder reads `migration_spec.json` and reconstructs the device natively in `DeviceLayout.jl`.
- The generated `DeviceLayout.jl` GDS is compared against `reference_layout.gds` only when that file exists.
- Missing `reference_layout.gds` does not block build or simulation; it only skips the geometry-parity check.
