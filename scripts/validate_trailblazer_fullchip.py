from __future__ import annotations

import importlib.util
import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
INPUT_DIR = ROOT / "inputs" / "qiskit-metal" / "trailblazer-fullchip"
SPEC_PATH = INPUT_DIR / "trailblazer_fullchip_spec.json"
FULLCHIP_GDS = ROOT / "build" / "trailblazer-fullchip" / "device.gds"
FULLCHIP_HOOKS = ROOT / "build" / "trailblazer-fullchip" / "hook_registry.json"
FULLCHIP_LAYOUT_SVG = ROOT / "build" / "trailblazer-fullchip" / "layout.svg"
FULLCHIP_LAYOUT_PNG = ROOT / "build" / "trailblazer-fullchip" / "layout.png"
FULLCHIP_PLACEMENT_GRAPH_SVG = ROOT / "build" / "trailblazer-fullchip" / "placement_graph.svg"
FULLCHIP_PLACEMENT_GRAPH_PNG = ROOT / "build" / "trailblazer-fullchip" / "placement_graph.png"
FULLCHIP_PLACEMENT_REGISTRY = ROOT / "build" / "trailblazer-fullchip" / "placement_registry.json"
FULLCHIP_CONNECTIVITY = ROOT / "build" / "trailblazer-fullchip" / "connectivity.json"
SLICE_MESH = ROOT / "build" / "trailblazer-q1-purcell-slice" / "device.msh"
SLICE_GDS = ROOT / "build" / "trailblazer-q1-purcell-slice" / "device.gds"
SLICE_CONFIG = ROOT / "build" / "trailblazer-q1-purcell-slice" / "palace.json"
SLICE_HOOKS = ROOT / "build" / "trailblazer-q1-purcell-slice" / "hook_registry.json"
SLICE_LAYOUT_SVG = ROOT / "build" / "trailblazer-q1-purcell-slice" / "layout.svg"
SLICE_LAYOUT_PNG = ROOT / "build" / "trailblazer-q1-purcell-slice" / "layout.png"
SLICE_PLACEMENT_GRAPH_SVG = ROOT / "build" / "trailblazer-q1-purcell-slice" / "placement_graph.svg"
SLICE_PLACEMENT_GRAPH_PNG = ROOT / "build" / "trailblazer-q1-purcell-slice" / "placement_graph.png"
SLICE_PLACEMENT_REGISTRY = ROOT / "build" / "trailblazer-q1-purcell-slice" / "placement_registry.json"
SLICE_CONNECTIVITY = ROOT / "build" / "trailblazer-q1-purcell-slice" / "connectivity.json"


def load_json(path: Path):
    with path.open() as handle:
        return json.load(handle)


def load_exporter():
    exporter_path = ROOT / "scripts" / "export_trailblazer_spec.py"
    spec = importlib.util.spec_from_file_location("trailblazer_exporter", exporter_path)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def validate_spec_shape(spec: dict) -> list[str]:
    errors = []
    required_layers = spec.get("validation_layers", [])
    if required_layers != [[1, 10], [1, 100]]:
        errors.append(f"Unexpected validation layers: {required_layers!r}")

    counts = spec.get("source_component_counts", {})
    required = spec.get("validation", {}).get("required_counts", {})
    route_counts = counts.get("routes", {})

    if counts.get("qubits") != required.get("qubits"):
        errors.append(f"Expected {required.get('qubits')} qubits, found {counts.get('qubits')}")
    if route_counts.get("bus") != required.get("bus_routes"):
        errors.append(f"Expected {required.get('bus_routes')} bus routes, found {route_counts.get('bus')}")
    if route_counts.get("readout") != required.get("readout_routes"):
        errors.append(f"Expected {required.get('readout_routes')} readout routes, found {route_counts.get('readout')}")
    if route_counts.get("control") != required.get("control_routes"):
        errors.append(f"Expected {required.get('control_routes')} control routes, found {route_counts.get('control')}")
    if route_counts.get("purcell") != required.get("purcell_routes"):
        errors.append(f"Expected {required.get('purcell_routes')} Purcell routes, found {route_counts.get('purcell')}")

    if len(spec.get("qubits", [])) != 8:
        errors.append("Normalized spec does not contain 8 qubit entries")
    if spec.get("purcell", {}).get("route_names") != ["PF", "TL2"]:
        errors.append(f"Unexpected Purcell route set: {spec.get('purcell', {}).get('route_names')!r}")
    return errors


def approx_pair(left: list[float], right: list[float], tol_um: float) -> bool:
    return all(math.isclose(float(a), float(b), rel_tol=0.0, abs_tol=tol_um) for a, b in zip(left, right))


def validate_source_parity(spec: dict) -> list[str]:
    exporter = load_exporter()
    source_paths = exporter.load_source_paths()
    exporter.stage_sources(source_paths)
    design = exporter.execute_notebook(exporter.STAGED_NOTEBOOK)
    regenerated = exporter.build_spec(design, source_paths)

    errors = []
    for left, right in zip(spec["qubits"], regenerated["qubits"]):
        if left["name"] != right["name"]:
            errors.append(f"Qubit order/name mismatch: {left['name']!r} != {right['name']!r}")
            continue
        if not approx_pair(left["pos_um"], right["pos_um"], 1e-6):
            errors.append(f"Qubit position mismatch for {left['name']}: {left['pos_um']!r} != {right['pos_um']!r}")
        if left["hfss_inductance_nh"] != right["hfss_inductance_nh"]:
            errors.append(
                f"Qubit inductance mismatch for {left['name']}: {left['hfss_inductance_nh']!r} != {right['hfss_inductance_nh']!r}"
            )
        if [connector["name"] for connector in left["connectors"]] != [connector["name"] for connector in right["connectors"]]:
            errors.append(f"Connector name mismatch for {left['name']}")

    for route_name in ["Bus_12", "Bus_45", "PF", "TL2", "readout_res_1", "control1_line"]:
        left = next(route for route in spec["routes"] if route["name"] == route_name)
        right = next(route for route in regenerated["routes"] if route["name"] == route_name)
        if left["start_component"] != right["start_component"] or left["end_component"] != right["end_component"]:
            errors.append(f"Route endpoint mismatch for {route_name}")
        if len(left["resolved_waypoints_um"]) != len(right["resolved_waypoints_um"]):
            errors.append(f"Resolved waypoint count mismatch for {route_name}")
    return errors


def gds_bbox(path: Path):
    import gdstk

    lib = gdstk.read_gds(str(path))
    top = lib.top_level()
    if not top:
        raise RuntimeError(f"No top-level cells in {path}")
    bbox = top[0].bounding_box()
    if bbox is None:
        raise RuntimeError(f"No bounding box available for {path}")
    return bbox


def gds_layers(path: Path):
    import gdstk

    lib = gdstk.read_gds(str(path))
    layers = set()
    for cell in lib.cells:
        for polygon in cell.polygons:
            layers.add((polygon.layer, polygon.datatype))
        for path_obj in cell.paths:
            layers.add((path_obj.layer, path_obj.datatype))
    return layers


def validate_fullchip_outputs(spec: dict) -> list[str]:
    errors = []
    if not FULLCHIP_GDS.is_file():
        errors.append(f"Missing full-chip GDS: {FULLCHIP_GDS}")
    if not FULLCHIP_HOOKS.is_file():
        errors.append(f"Missing full-chip hook registry: {FULLCHIP_HOOKS}")
    for path in [
        FULLCHIP_LAYOUT_SVG,
        FULLCHIP_LAYOUT_PNG,
        FULLCHIP_PLACEMENT_GRAPH_SVG,
        FULLCHIP_PLACEMENT_GRAPH_PNG,
        FULLCHIP_PLACEMENT_REGISTRY,
        FULLCHIP_CONNECTIVITY,
    ]:
        if not path.is_file():
            errors.append(f"Missing full-chip inspection artifact: {path}")
        elif path.stat().st_size == 0:
            errors.append(f"Empty full-chip inspection artifact: {path}")
    if errors:
        return errors

    hooks = load_json(FULLCHIP_HOOKS)
    placement = load_json(FULLCHIP_PLACEMENT_REGISTRY)
    connectivity = load_json(FULLCHIP_CONNECTIVITY)
    for name in ["Q_1", "Q_5", "Launch_Q_Read", "control1_launch"]:
        if name not in hooks:
            errors.append(f"Missing hook entry for {name}")
        if name not in placement:
            errors.append(f"Missing placement entry for {name}")
    if not any(route.get("name") == "Bus_12" for route in connectivity):
        errors.append("Full-chip connectivity registry is missing Bus_12")

    reference_gds = Path(spec["reference_gds_path"])
    if not reference_gds.is_file():
        errors.append(f"Missing staged reference GDS: {reference_gds}")
        return errors

    try:
        generated_bbox = gds_bbox(FULLCHIP_GDS)
        reference_bbox = gds_bbox(reference_gds)
        generated_layers = gds_layers(FULLCHIP_GDS)
        reference_layers = gds_layers(reference_gds)
    except ImportError:
        print("Skipping GDS layer/bounding-box validation; install python package 'gdstk' to enable it.")
        return errors

    tol = float(spec.get("validation", {}).get("geometry_tolerance_um", 25.0))
    generated_size = [
        float(generated_bbox[1][0] - generated_bbox[0][0]),
        float(generated_bbox[1][1] - generated_bbox[0][1]),
    ]
    reference_size = [
        float(reference_bbox[1][0] - reference_bbox[0][0]),
        float(reference_bbox[1][1] - reference_bbox[0][1]),
    ]
    if not approx_pair(generated_size, reference_size, tol):
        errors.append(f"Full-chip GDS bounding-box mismatch: {generated_size!r} != {reference_size!r}")

    for layer in [(1, 10), (1, 100)]:
        if layer not in generated_layers:
            errors.append(f"Generated full-chip GDS is missing validation layer {layer}")
        if layer not in reference_layers:
            errors.append(f"Reference GDS is missing validation layer {layer}")
    return errors


def validate_slice_outputs(spec: dict) -> list[str]:
    errors = []
    for path in [
        SLICE_MESH,
        SLICE_GDS,
        SLICE_CONFIG,
        SLICE_HOOKS,
        SLICE_LAYOUT_SVG,
        SLICE_LAYOUT_PNG,
        SLICE_PLACEMENT_GRAPH_SVG,
        SLICE_PLACEMENT_GRAPH_PNG,
        SLICE_PLACEMENT_REGISTRY,
        SLICE_CONNECTIVITY,
    ]:
        if not path.is_file():
            errors.append(f"Missing slice artifact: {path}")
        elif path.suffix.lower() in {".svg", ".png"} and path.stat().st_size == 0:
            errors.append(f"Empty slice layout graphic: {path}")
    if errors:
        return errors

    config = load_json(SLICE_CONFIG)
    for section in ["Problem", "Model", "Domains", "Boundaries", "Solver"]:
        if section not in config:
            errors.append(f"Missing slice config section: {section}")

    if config.get("Problem", {}).get("Output") != str(ROOT / "results" / "trailblazer-q1-purcell-slice"):
        errors.append(f"Unexpected Problem.Output: {config.get('Problem', {}).get('Output')!r}")
    if config.get("Model", {}).get("Mesh") != str(SLICE_MESH):
        errors.append(f"Unexpected Model.Mesh: {config.get('Model', {}).get('Mesh')!r}")

    placement = load_json(SLICE_PLACEMENT_REGISTRY)
    connectivity = load_json(SLICE_CONNECTIVITY)
    if "Q_1" not in placement:
        errors.append("Slice placement registry is missing Q_1")
    if not any(route.get("name") == "readout_res_1" for route in connectivity):
        errors.append("Slice connectivity registry is missing readout_res_1")

    lumped_ports = config.get("Boundaries", {}).get("LumpedPort", [])
    if len(lumped_ports) != 3:
        errors.append(f"Expected 3 lumped ports/elements in slice config, found {len(lumped_ports)}")

    q1 = next(qubit for qubit in spec["qubits"] if qubit["name"] == "Q_1")
    q1_inductance_h = q1["hfss_inductance_nh"] * 1.0e-9
    if len(lumped_ports) >= 3 and not math.isclose(lumped_ports[2].get("L", 0.0), q1_inductance_h, rel_tol=0.0, abs_tol=1e-15):
        errors.append(f"Unexpected Q1 lumped inductance: {lumped_ports[2].get('L')!r}")
    return errors


def main() -> int:
    if not SPEC_PATH.is_file():
        print(f"Missing TrailBlazer spec: {SPEC_PATH}")
        return 1

    spec = load_json(SPEC_PATH)
    errors = []
    errors.extend(validate_spec_shape(spec))
    errors.extend(validate_source_parity(spec))
    errors.extend(validate_fullchip_outputs(spec))
    errors.extend(validate_slice_outputs(spec))

    if errors:
        print("TrailBlazer validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print("TrailBlazer validation passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
