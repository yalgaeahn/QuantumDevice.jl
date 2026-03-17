# QPU17 Reference

This case stages and runs the upstream `DeviceLayout.jl` `DemoQPU17` example locally so the repo has a concrete reference for the top-level schematic-driven workflow.

## Build

```bash
./scripts/build_qpu17_reference.sh
```

## Outputs

- `build/qpu17-reference/schematic_graph.svg`
- `build/qpu17-reference/layout.svg`
- `build/qpu17-reference/device.gds`
- `build/qpu17-reference/work/`

Use this case as the local reference for how graph-driven builders in this repo should expose source, planned schematic, and rendered layout artifacts.
