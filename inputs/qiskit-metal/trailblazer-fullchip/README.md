# TrailBlazer Source Staging

This directory stages the Berkeley TrailBlazer qiskit-metal sources used by the native `DeviceLayout.jl` migration flow.

- `source_paths.json`: authoritative absolute paths for the notebook and reference GDS used to regenerate this input set
- `source_notebook.ipynb`: staged copy of `Berkeley_TrailBlazer_mimic_fullchip_1_1design_change.ipynb`
- `reference_layout.gds`: staged copy of `Berkeley_TrailBlazer_mimic_fullchip_v1_1.gds`
- `trailblazer_fullchip_spec.json`: normalized migration spec emitted by `scripts/export_trailblazer_spec.py`

The notebook remains the semantic source of truth. The staged GDS is the geometry-validation artifact, especially for validation layers `1/10` and `1/100`.
