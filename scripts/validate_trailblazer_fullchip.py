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
FULLCHIP_ROUTE_REGISTRY = ROOT / "build" / "trailblazer-fullchip" / "route_registry.json"
FULLCHIP_GRAPH_SVG = ROOT / "build" / "trailblazer-fullchip" / "schematic_graph.svg"
FULLCHIP_LAYOUT_SVG = ROOT / "build" / "trailblazer-fullchip" / "layout.svg"
SLICE_DIR = ROOT / "build" / "trailblazer-q1-local-context"
SLICE_RESULTS_DIR = ROOT / "results" / "trailblazer-q1-local-context"
SLICE_MESH = SLICE_DIR / "device.msh"
SLICE_GDS = SLICE_DIR / "device.gds"
SLICE_CONFIG = SLICE_DIR / "palace.json"
SLICE_HOOKS = SLICE_DIR / "hook_registry.json"
SLICE_MEMBERSHIP = SLICE_DIR / "slice_membership.json"
SLICE_GRAPH_SVG = SLICE_DIR / "schematic_graph.svg"
SLICE_LAYOUT_SVG = SLICE_DIR / "layout.svg"


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
    if "purcell" in spec:
        errors.append("Normalized spec should not contain a top-level 'purcell' object")
    return errors


def component_kind_map(spec: dict) -> dict[str, str]:
    kinds: dict[str, str] = {}
    for qubit in spec.get("qubits", []):
        kinds[qubit["name"]] = "qubit"
    for launch in spec.get("launches", []):
        kinds[launch["name"]] = "launch"
    for term in spec.get("open_terminations", []):
        kinds[term["name"]] = "open_termination"
    for term in spec.get("short_terminations", []):
        kinds[term["name"]] = "short_termination"
    for cap in spec.get("interdigital_caps", []):
        kinds[cap["name"]] = "interdigital_cap"
    return kinds


def route_peer(route: dict, component_name: str) -> str:
    if route["start_component"] == component_name:
        return route["end_component"]
    if route["end_component"] == component_name:
        return route["start_component"]
    raise ValueError(f"Route {route['name']!r} is not incident to {component_name!r}")


def primary_readout_route(spec: dict, target_qubit: str) -> dict:
    for route in spec.get("routes", []):
        if route["category"] != "readout":
            continue
        if route["start_component"] == target_qubit or route["end_component"] == target_qubit:
            return route
    raise KeyError(f"No readout route found for {target_qubit}")


def derive_local_context_membership(spec: dict, target_qubit: str) -> dict:
    component_names = {target_qubit}
    route_names: set[str] = set()

    for route in spec.get("routes", []):
        if target_qubit not in {route["start_component"], route["end_component"]}:
            continue
        if route["category"] in {"readout", "bus"}:
            route_names.add(route["name"])
            component_names.add(route_peer(route, target_qubit))

    changed = True
    while changed:
        changed = False
        for route in spec.get("routes", []):
            if route["category"] != "purcell" or route["name"] in route_names:
                continue
            if route["start_component"] in component_names or route["end_component"] in component_names:
                route_names.add(route["name"])
                component_names.add(route["start_component"])
                component_names.add(route["end_component"])
                changed = True

    degrees = {name: 0 for name in component_names}
    for route in spec.get("routes", []):
        if route["name"] not in route_names:
            continue
        degrees[route["start_component"]] = degrees.get(route["start_component"], 0) + 1
        degrees[route["end_component"]] = degrees.get(route["end_component"], 0) + 1

    kinds = component_kind_map(spec)
    readout_component = route_peer(primary_readout_route(spec, target_qubit), target_qubit)
    external_port_components = []
    if readout_component in component_names:
        external_port_components.append(readout_component)
    for name in sorted(component_names):
        if name == readout_component:
            continue
        if kinds.get(name) not in {"launch", "open_termination", "short_termination"}:
            continue
        if degrees.get(name, 0) == 1:
            external_port_components.append(name)

    return {
        "target_qubit": target_qubit,
        "context": "local_bus",
        "component_names": sorted(component_names),
        "route_names": sorted(route_names),
        "external_port_components": external_port_components,
    }


def validate_positive_purcell_fixture(spec: dict) -> list[str]:
    fixture = json.loads(json.dumps(spec))
    fixture["routes"].append(
        {
            "name": "fixture_purcell_link",
            "category": "purcell",
            "kind": "straight",
            "start_component": "readout1_short",
            "start_hook": "short",
            "end_component": "highC_PF_TL",
            "end_hook": "north_end",
            "trace_width_um": 20.0,
            "trace_gap_um": 10.0,
            "fillet_um": 0.0,
            "lead_start_straight_um": 0.0,
            "lead_end_straight_um": 0.0,
            "start_jogs": [],
            "total_length_um": None,
            "meander_spacing_um": None,
            "meander_asymmetry_um": None,
            "resolved_waypoints_um": [],
        }
    )
    derived = derive_local_context_membership(fixture, "Q_1")
    errors = []
    for name in ["fixture_purcell_link", "PF"]:
        if name not in derived["route_names"]:
            errors.append(f"Fixture Purcell route was not included automatically: {name}")
    for name in ["highC_PF_TL", "otg_PF"]:
        if name not in derived["component_names"]:
            errors.append(f"Fixture Purcell component was not included automatically: {name}")
    return errors


def approx_pair(left: list[float], right: list[float], tol_um: float) -> bool:
    return all(math.isclose(float(a), float(b), rel_tol=0.0, abs_tol=tol_um) for a, b in zip(left, right))


def approx_points(left: list[list[float]], right: list[list[float]], tol_um: float) -> bool:
    if len(left) != len(right):
        return False
    return all(approx_pair(list(a), list(b), tol_um) for a, b in zip(left, right))


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


def _to_um(value: float, unit_in_meters: float) -> float:
    return float(value) * float(unit_in_meters) * 1.0e6


def _accumulate_bbox(store: dict[tuple[int, int], list[list[float]]], key: tuple[int, int], bbox, unit_in_meters: float):
    if bbox is None:
        return
    lo = [_to_um(bbox[0][0], unit_in_meters), _to_um(bbox[0][1], unit_in_meters)]
    hi = [_to_um(bbox[1][0], unit_in_meters), _to_um(bbox[1][1], unit_in_meters)]
    if key not in store:
        store[key] = [lo, hi]
        return
    store[key][0][0] = min(store[key][0][0], lo[0])
    store[key][0][1] = min(store[key][0][1], lo[1])
    store[key][1][0] = max(store[key][1][0], hi[0])
    store[key][1][1] = max(store[key][1][1], hi[1])


def gds_summary(path: Path):
    import gdstk

    lib = gdstk.read_gds(str(path))
    layers = set()
    layer_bboxes_um: dict[tuple[int, int], list[list[float]]] = {}
    for cell in lib.cells:
        for polygon in cell.polygons:
            key = (polygon.layer, polygon.datatype)
            layers.add(key)
            _accumulate_bbox(layer_bboxes_um, key, polygon.bounding_box(), lib.unit)
        for path_obj in cell.paths:
            key = (path_obj.layer, path_obj.datatype)
            layers.add(key)
            _accumulate_bbox(layer_bboxes_um, key, path_obj.bounding_box(), lib.unit)

    top = lib.top_level()
    if not top:
        raise RuntimeError(f"No top-level cells in {path}")
    bbox = top[0].bounding_box()
    if bbox is None:
        raise RuntimeError(f"No bounding box available for {path}")
    top_bbox_um = [
        [_to_um(bbox[0][0], lib.unit), _to_um(bbox[0][1], lib.unit)],
        [_to_um(bbox[1][0], lib.unit), _to_um(bbox[1][1], lib.unit)],
    ]
    return {
        "unit": float(lib.unit),
        "precision": float(lib.precision),
        "layers": layers,
        "top_bbox_um": top_bbox_um,
        "layer_bboxes_um": layer_bboxes_um,
    }


def approx_bbox(left: list[list[float]], right: list[list[float]], tol_um: float) -> bool:
    return approx_pair(left[0], right[0], tol_um) and approx_pair(left[1], right[1], tol_um)


def route_by_name(spec: dict, route_name: str) -> dict:
    return next(route for route in spec["routes"] if route["name"] == route_name)


def validate_fullchip_outputs(spec: dict) -> list[str]:
    errors = []
    if not FULLCHIP_GDS.is_file():
        errors.append(f"Missing full-chip GDS: {FULLCHIP_GDS}")
    if not FULLCHIP_HOOKS.is_file():
        errors.append(f"Missing full-chip hook registry: {FULLCHIP_HOOKS}")
    if not FULLCHIP_ROUTE_REGISTRY.is_file():
        errors.append(f"Missing full-chip route registry: {FULLCHIP_ROUTE_REGISTRY}")
    for path in [
        FULLCHIP_LAYOUT_SVG,
        FULLCHIP_GRAPH_SVG,
    ]:
        if not path.is_file():
            errors.append(f"Missing full-chip source-aligned artifact: {path}")
        elif path.stat().st_size == 0:
            errors.append(f"Empty full-chip source-aligned artifact: {path}")
    if errors:
        return errors

    hooks = load_json(FULLCHIP_HOOKS)
    for name in ["Q_1", "Q_5", "Launch_Q_Read", "control1_launch"]:
        if name not in hooks:
            errors.append(f"Missing hook entry for {name}")

    reference_gds = Path(spec["reference_gds_path"])
    if not reference_gds.is_file():
        errors.append(f"Missing staged reference GDS: {reference_gds}")
        return errors

    try:
        generated_gds = gds_summary(FULLCHIP_GDS)
        reference_gds = gds_summary(reference_gds)
    except ImportError:
        print("Skipping GDS layer/bounding-box validation; install python package 'gdstk' to enable it.")
        return errors

    tol = float(spec.get("validation", {}).get("geometry_tolerance_um", 25.0))
    if not math.isclose(generated_gds["unit"], 0.001, rel_tol=0.0, abs_tol=1.0e-12):
        errors.append(f"Unexpected full-chip GDS unit: {generated_gds['unit']!r}")
    if not math.isclose(generated_gds["precision"], 1.0e-9, rel_tol=0.0, abs_tol=1.0e-15):
        errors.append(f"Unexpected full-chip GDS precision: {generated_gds['precision']!r}")

    for layer in [(1, 10), (1, 100)]:
        if layer not in generated_gds["layers"]:
            errors.append(f"Generated full-chip GDS is missing validation layer {layer}")
            continue
        if layer not in reference_gds["layers"]:
            errors.append(f"Reference GDS is missing validation layer {layer}")
            continue
        if not approx_bbox(generated_gds["layer_bboxes_um"][layer], reference_gds["layer_bboxes_um"][layer], tol):
            errors.append(
                f"Full-chip GDS layer {layer} bbox mismatch: "
                f"{generated_gds['layer_bboxes_um'][layer]!r} != {reference_gds['layer_bboxes_um'][layer]!r}"
            )

    route_registry = load_json(FULLCHIP_ROUTE_REGISTRY)
    for route in spec.get("routes", []):
        route_name = route["name"]
        entry = route_registry.get(route_name)
        if entry is None:
            errors.append(f"Missing full-chip route registry entry for {route_name}")
            continue
        component_type = entry.get("component_type", "")
        if "RouteComponent" not in component_type:
            errors.append(f"Route {route_name} is not using a native DeviceLayout RouteComponent: {component_type!r}")
        if "TrailBlazerResolvedRoute" in component_type:
            errors.append(f"Route {route_name} still uses the deprecated TrailBlazerResolvedRoute component")

    for route_name in [route["name"] for route in spec.get("routes", []) if route["kind"] == "meander"]:
        route = route_by_name(spec, route_name)
        entry = route_registry.get(route_name, {})
        if entry.get("rule_type") and "StraightAnd90" not in entry["rule_type"]:
            errors.append(f"Meander route {route_name} is not using StraightAnd90: {entry['rule_type']!r}")
        if entry.get("global_waypoints") is not True:
            errors.append(f"Meander route {route_name} should use global waypoints")
        if entry.get("global_waypoint_count") != len(route["resolved_waypoints_um"]):
            errors.append(
                f"Meander route {route_name} waypoint-count mismatch: "
                f"{entry.get('global_waypoint_count')!r} != {len(route['resolved_waypoints_um'])}"
            )
        if not approx_points(entry.get("global_waypoints_um", []), route["resolved_waypoints_um"], tol):
            errors.append(f"Meander route {route_name} does not preserve the notebook-resolved waypoint sequence")
        min_bend_radius_um = entry.get("min_bend_radius_um")
        if min_bend_radius_um is None or min_bend_radius_um <= 0.0:
            errors.append(f"Meander route {route_name} should have a positive bend radius")
    return errors


def validate_slice_outputs(spec: dict) -> list[str]:
    errors = []
    for path in [
        SLICE_MESH,
        SLICE_GDS,
        SLICE_CONFIG,
        SLICE_HOOKS,
        SLICE_MEMBERSHIP,
        SLICE_LAYOUT_SVG,
        SLICE_GRAPH_SVG,
    ]:
        if not path.is_file():
            errors.append(f"Missing slice artifact: {path}")
        elif path.suffix.lower() == ".svg" and path.stat().st_size == 0:
            errors.append(f"Empty slice SVG artifact: {path}")
    if errors:
        return errors

    config = load_json(SLICE_CONFIG)
    membership = load_json(SLICE_MEMBERSHIP)
    expected = derive_local_context_membership(spec, "Q_1")
    for section in ["Problem", "Model", "Domains", "Boundaries", "Solver"]:
        if section not in config:
            errors.append(f"Missing slice config section: {section}")

    if config.get("Problem", {}).get("Output") != str(SLICE_RESULTS_DIR):
        errors.append(f"Unexpected Problem.Output: {config.get('Problem', {}).get('Output')!r}")
    if config.get("Model", {}).get("Mesh") != str(SLICE_MESH):
        errors.append(f"Unexpected Model.Mesh: {config.get('Model', {}).get('Mesh')!r}")

    if membership.get("target_qubit") != "Q_1":
        errors.append(f"Unexpected slice target qubit: {membership.get('target_qubit')!r}")
    if membership.get("context") != "local_bus":
        errors.append(f"Unexpected slice context: {membership.get('context')!r}")
    if membership.get("component_names") != expected["component_names"]:
        errors.append(
            f"Unexpected slice component membership: {membership.get('component_names')!r} != {expected['component_names']!r}"
        )
    if membership.get("route_names") != expected["route_names"]:
        errors.append(f"Unexpected slice route membership: {membership.get('route_names')!r} != {expected['route_names']!r}")
    if membership.get("external_port_components") != expected["external_port_components"]:
        errors.append(
            "Unexpected slice external ports: "
            f"{membership.get('external_port_components')!r} != {expected['external_port_components']!r}"
        )

    hooks = load_json(SLICE_HOOKS)
    for name in expected["component_names"]:
        if name not in hooks:
            errors.append(f"Missing slice hook entry for {name}")

    lumped_ports = config.get("Boundaries", {}).get("LumpedPort", [])
    expected_port_count = len(expected["external_port_components"]) + 1
    if len(lumped_ports) != expected_port_count:
        errors.append(f"Expected {expected_port_count} lumped ports/elements in slice config, found {len(lumped_ports)}")

    q1 = next(qubit for qubit in spec["qubits"] if qubit["name"] == "Q_1")
    q1_inductance_h = q1["hfss_inductance_nh"] * 1.0e-9
    if lumped_ports:
        lumped = lumped_ports[-1]
        if not math.isclose(lumped.get("L", 0.0), q1_inductance_h, rel_tol=0.0, abs_tol=1e-15):
            errors.append(f"Unexpected Q1 lumped inductance: {lumped.get('L')!r}")

    forbidden_components = {
        "Launch_Q_Read",
        "bridge_Q_in",
        "bridge_Q_out",
        "highC_PF_TL",
        "otg_PF",
    }
    forbidden_routes = {"PF", "TL2"}
    for name in forbidden_components:
        if name in membership.get("component_names", []):
            errors.append(f"Strict graph slice should not include disconnected Purcell component {name}")
    for name in forbidden_routes:
        if name in membership.get("route_names", []):
            errors.append(f"Strict graph slice should not include disconnected Purcell route {name}")
    return errors


def main() -> int:
    if not SPEC_PATH.is_file():
        print(f"Missing TrailBlazer spec: {SPEC_PATH}")
        return 1

    spec = load_json(SPEC_PATH)
    errors = []
    errors.extend(validate_spec_shape(spec))
    errors.extend(validate_source_parity(spec))
    errors.extend(validate_positive_purcell_fixture(spec))
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
