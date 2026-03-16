# Star Transmon Case

This workspace case is a local `DeviceLayout.jl` example built from `ExamplePDK` components used in the `DemoQPU17` documentation:

- `ExampleStarTransmon`
- `ExampleFilteredHairpinReadout`

It is not an upstream official Palace example. The goal is to provide a second native macOS EM case that is closer to the `QPU17` component stack than the upstream single-transmon demo.

Commands:

```bash
./scripts/build_star_transmon.sh
./scripts/run_star_transmon.sh 1
./scripts/run_star_transmon.sh
./scripts/open_star_transmon.sh
```
