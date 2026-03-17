from __future__ import annotations

import json
import math
import runpy
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
INPUT_DIR = ROOT / "inputs" / "qiskit-metal" / "qmetal-transmon"
SPEC_PATH = INPUT_DIR / "migration_spec.json"
SOURCE_PATH = INPUT_DIR / "source_design.py"
REFERENCE_GDS = INPUT_DIR / "reference_layout.gds"
GENERATED_GDS = ROOT / "build" / "qmetal-transmon" / "device.gds"
GRAPH_SVG = ROOT / "build" / "qmetal-transmon" / "schematic_graph.svg"
LAYOUT_SVG = ROOT / "build" / "qmetal-transmon" / "layout.svg"
CONFIG_PATH = ROOT / "build" / "qmetal-transmon" / "palace.json"


def load_source_spec() -> dict:
    namespace = runpy.run_path(str(SOURCE_PATH))
    source = namespace.get("QMETAL_SOURCE_SPEC")
    if not isinstance(source, dict):
        raise RuntimeError(f"Expected QMETAL_SOURCE_SPEC in {SOURCE_PATH}")
    return source


def load_json(path: Path) -> dict:
    with path.open() as handle:
        return json.load(handle)


def get_nested(data: dict, path: tuple[str, ...]):
    value = data
    for key in path:
        value = value[key]
    return value


def approx_equal(left, right, tol: float) -> bool:
    if isinstance(left, list) and isinstance(right, list):
        return len(left) == len(right) and all(approx_equal(a, b, tol) for a, b in zip(left, right))
    if isinstance(left, (int, float)) and isinstance(right, (int, float)):
        return math.isclose(float(left), float(right), rel_tol=0.0, abs_tol=tol)
    return left == right


def validate_parameter_parity(source: dict, spec: dict) -> list[str]:
    tol = float(spec["validation"]["parameter_tolerance_um"])
    comparisons = [
        (("chip", "size_um"), ("geometry", "chip_size_um")),
        (("chip", "simulation_box_um"), ("geometry", "simulation_box_um")),
        (("cpw", "trace_um"), ("geometry", "cpw_trace_um")),
        (("cpw", "gap_um"), ("geometry", "cpw_gap_um")),
        (("cpw", "bridge_spacing_um"), ("geometry", "bridge_spacing_um")),
        (("cpw", "readout_length_um"), ("geometry", "readout_length_um")),
        (("transmon", "cap_width_um"), ("geometry", "transmon_cap_width_um")),
        (("transmon", "cap_length_um"), ("geometry", "transmon_cap_length_um")),
        (("transmon", "cap_gap_um"), ("geometry", "transmon_cap_gap_um")),
        (("transmon", "junction_gap_um"), ("geometry", "junction_gap_um")),
        (("readout", "claw_gap_um"), ("geometry", "claw_gap_um")),
        (("readout", "claw_width_um"), ("geometry", "claw_width_um")),
        (("readout", "claw_length_um"), ("geometry", "claw_length_um")),
        (("readout", "shield_width_um"), ("geometry", "shield_width_um")),
        (("readout", "coupling_gap_um"), ("geometry", "coupling_gap_um")),
        (("readout", "coupling_length_um"), ("geometry", "coupling_length_um")),
        (("readout", "hanger_length_um"), ("geometry", "hanger_length_um")),
        (("readout", "bend_radius_um"), ("geometry", "bend_radius_um")),
        (("readout", "meander_turns"), ("geometry", "meander_turns")),
        (("readout", "total_length_um"), ("geometry", "resonator_total_length_um")),
        (("junction", "inductance_h"), ("junction", "inductance_h")),
        (("junction", "capacitance_f"), ("junction", "capacitance_f")),
        (("junction", "direction"), ("junction", "direction")),
        (("ports", "port_1", "direction"), ("ports", "port_1_direction")),
        (("ports", "port_2", "direction"), ("ports", "port_2_direction")),
        (("ports", "port_1", "impedance_ohm"), ("ports", "impedance_ohm")),
        (("solver", "order_default"), ("solver", "order_default")),
        (("solver", "modes"), ("solver", "eigenmode_count")),
        (("solver", "target_ghz"), ("solver", "target_ghz")),
        (("solver", "amr_max_iterations"), ("solver", "amr_max_iterations")),
    ]

    errors = []
    for source_path, spec_path in comparisons:
        source_value = get_nested(source, source_path)
        spec_value = get_nested(spec, spec_path)
        if not approx_equal(source_value, spec_value, tol):
            errors.append(
                f"Parameter mismatch: {'.'.join(source_path)}={source_value!r} "
                f"!= {'.'.join(spec_path)}={spec_value!r}"
            )
    return errors


def validate_config(spec: dict) -> list[str]:
    errors = []
    for path in [GRAPH_SVG, LAYOUT_SVG, CONFIG_PATH]:
        if not path.is_file():
            errors.append(f"Missing generated artifact: {path}")
        elif path.suffix == ".svg" and path.stat().st_size == 0:
            errors.append(f"Empty SVG artifact: {path}")
    if errors:
        return errors

    config = load_json(CONFIG_PATH)
    required_sections = ["Problem", "Model", "Domains", "Boundaries", "Solver"]
    errors = [f"Missing config section: {section}" for section in required_sections if section not in config]

    expected_output = str(ROOT / "results" / "qmetal-transmon")
    expected_mesh = str(ROOT / "build" / "qmetal-transmon" / "device.msh")

    if config.get("Problem", {}).get("Output") != expected_output:
        errors.append(f"Unexpected Problem.Output: {config.get('Problem', {}).get('Output')!r}")
    if config.get("Model", {}).get("Mesh") != expected_mesh:
        errors.append(f"Unexpected Model.Mesh: {config.get('Model', {}).get('Mesh')!r}")

    lumped_ports = config.get("Boundaries", {}).get("LumpedPort", [])
    if len(lumped_ports) != 3:
        errors.append(f"Expected 3 lumped ports, found {len(lumped_ports)}")

    solver = config.get("Solver", {})
    if solver.get("Order") != spec["solver"]["order_default"]:
        errors.append(f"Unexpected solver order: {solver.get('Order')!r}")
    if solver.get("Eigenmode", {}).get("N") != spec["solver"]["eigenmode_count"]:
        errors.append(f"Unexpected eigenmode count: {solver.get('Eigenmode', {}).get('N')!r}")

    return errors


def gds_bbox(path: Path):
    import gdstk

    library = gdstk.read_gds(str(path))
    top = library.top_level()
    if not top:
        raise RuntimeError(f"No top-level cells in {path}")
    bbox = top[0].bounding_box()
    if bbox is None:
        raise RuntimeError(f"No bounding box available for {path}")
    return bbox


def validate_geometry(spec: dict) -> list[str]:
    if not GENERATED_GDS.is_file():
        return [f"Missing generated GDS: {GENERATED_GDS}"]
    if not REFERENCE_GDS.is_file():
        print(f"Skipping GDS comparison; reference export not found at {REFERENCE_GDS}")
        return []

    try:
        generated_bbox = gds_bbox(GENERATED_GDS)
        reference_bbox = gds_bbox(REFERENCE_GDS)
    except ImportError:
        print("Skipping GDS comparison; install python package 'gdstk' to enable bounding-box validation.")
        return []

    tol = float(spec["validation"]["geometry_tolerance_um"])
    generated_size = [
        float(generated_bbox[1][0] - generated_bbox[0][0]),
        float(generated_bbox[1][1] - generated_bbox[0][1]),
    ]
    reference_size = [
        float(reference_bbox[1][0] - reference_bbox[0][0]),
        float(reference_bbox[1][1] - reference_bbox[0][1]),
    ]
    if not approx_equal(generated_size, reference_size, tol):
        return [f"GDS bounding-box mismatch: generated={generated_size!r}, reference={reference_size!r}"]
    return []


def main() -> int:
    source = load_source_spec()
    spec = load_json(SPEC_PATH)

    errors = []
    errors.extend(validate_parameter_parity(source, spec))
    errors.extend(validate_config(spec))
    errors.extend(validate_geometry(spec))

    if errors:
        print("qmetal-transmon validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print("qmetal-transmon validation passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
