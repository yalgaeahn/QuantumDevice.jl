# qmetal-transmon Case

This case is the pilot migration path from a qiskit-metal single-transmon design into a native `DeviceLayout.jl` builder.

Source artifacts:

- semantic source: `inputs/qiskit-metal/qmetal-transmon/source_design.py`
- normalized migration spec: `inputs/qiskit-metal/qmetal-transmon/migration_spec.json`
- optional qiskit-metal GDS for validation: `inputs/qiskit-metal/qmetal-transmon/reference_layout.gds`

Commands:

```bash
./scripts/build_qmetal_transmon.sh
./scripts/run_qmetal_transmon.sh 1
./scripts/validate_qmetal_transmon.sh
```

What this case validates:

- parameter parity between the staged qiskit-style source export and the normalized migration spec
- generated `palace.json` shape and workspace-local paths
- optional GDS bounding-box comparison when the qiskit-metal export is present

Current mapping assumptions:

- the migrated design is reconstructed as an editable `ExampleRectangleTransmon` plus `ExampleClawedMeanderReadout`
- the qiskit-metal GDS is treated as a comparison artifact, not the editable source
- the Josephson element remains a lumped-element PALACE boundary defined from the migration spec
