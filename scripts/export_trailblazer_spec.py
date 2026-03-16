from __future__ import annotations

import json
import math
import re
import shutil
import sys
from collections import OrderedDict
from dataclasses import dataclass
from pathlib import Path
from types import SimpleNamespace
from typing import Any

ROOT = Path(__file__).resolve().parent.parent
INPUT_DIR = ROOT / "inputs" / "qiskit-metal" / "trailblazer-fullchip"
SOURCE_PATHS = INPUT_DIR / "source_paths.json"
STAGED_NOTEBOOK = INPUT_DIR / "source_notebook.ipynb"
STAGED_GDS = INPUT_DIR / "reference_layout.gds"
SPEC_PATH = INPUT_DIR / "trailblazer_fullchip_spec.json"

DEFAULT_NOTEBOOK = Path(
    "/Users/yalgaeahn/Research/qiskit-metal-gyum/Berkeley_TrailBlazer_mimic_fullchip_1_1design_change.ipynb"
)
DEFAULT_GDS = Path(
    "/Users/yalgaeahn/Research/qiskit-metal-gyum/Berkeley_TrailBlazer_mimic_fullchip_v1_1.gds"
)

ROUTE_CELL_STOP = 24
CPW_WIDTH_MM = 0.01
CPW_GAP_MM = 0.006


class AttrDict(dict):
    def __init__(self, *args, **kwargs):
        super().__init__()
        self.update(*args, **kwargs)

    def __getattr__(self, key):
        if key.startswith("_"):
            raise AttributeError(key)
        if key not in self:
            value = AttrDict()
            dict.__setitem__(self, key, value)
            return value
        return dict.__getitem__(self, key)

    def __setattr__(self, key, value):
        if key.startswith("_"):
            super().__setattr__(key, value)
            return
        self[key] = value

    def __setitem__(self, key, value):
        dict.__setitem__(self, key, wrap(value))

    def update(self, *args, **kwargs):
        other = {}
        if args:
            if len(args) != 1:
                raise TypeError("AttrDict.update accepts at most one positional argument")
            other.update(dict(args[0]))
        other.update(kwargs)
        for key, value in other.items():
            self[key] = value


def wrap(value):
    if isinstance(value, AttrDict):
        return value
    if isinstance(value, OrderedDict):
        wrapped = OrderedDict()
        for key, item in value.items():
            wrapped[key] = wrap(item)
        return wrapped
    if isinstance(value, dict):
        return AttrDict(value)
    if isinstance(value, list):
        return [wrap(item) for item in value]
    if isinstance(value, tuple):
        return tuple(wrap(item) for item in value)
    return value


def Dict(*args, **kwargs):
    merged = AttrDict()
    if args:
        if len(args) != 1:
            raise TypeError("Dict accepts at most one positional argument")
        merged.update(args[0])
    merged.update(kwargs)
    return merged


def deep_merge(base: Any, override: Any):
    if isinstance(base, (dict, AttrDict)) and isinstance(override, (dict, AttrDict)):
        merged = AttrDict()
        for key in base:
            merged[key] = deep_merge(base[key], override[key]) if key in override else base[key]
        for key in override:
            if key not in base:
                merged[key] = override[key]
        return merged
    return wrap(override)


def safe_eval(text: str, unit_map: dict[str, float]) -> float:
    expr = text.replace(" ", "")
    expr = expr.replace("cpw_width", str(CPW_WIDTH_MM))
    expr = expr.replace("cpw_gap", str(CPW_GAP_MM))

    def repl(match: re.Match[str]) -> str:
        number = match.group("number")
        unit = match.group("unit")
        scale = unit_map.get(unit or "", 1.0)
        return f"({number}*{scale})"

    expr = re.sub(
        r"(?P<number>(?:\d+(?:\.\d*)?|\.\d+)(?:e[+-]?\d+)?)\s*(?P<unit>mm|um|nm|nH|fF)?",
        repl,
        expr,
    )
    return float(eval(expr, {"__builtins__": {}}, {}))


def parse_length_mm(value: Any) -> float:
    if value is None:
        return 0.0
    if isinstance(value, (int, float)):
        return float(value)
    text = str(value).strip()
    if not text:
        return 0.0
    if re.fullmatch(r"[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:e[+-]?\d+)?", text):
        return float(text)
    return safe_eval(text, {"mm": 1.0, "um": 0.001, "nm": 1e-6})


def parse_length_um(value: Any) -> float:
    return parse_length_mm(value) * 1000.0


def parse_angle_deg(value: Any) -> float:
    if value is None:
        return 0.0
    return float(str(value).strip())


def parse_intish(value: Any) -> int:
    if isinstance(value, int):
        return value
    return int(float(str(value).strip()))


def parse_inductance_nh(value: Any) -> float:
    if isinstance(value, (int, float)):
        return float(value)
    return safe_eval(str(value).strip(), {"nH": 1.0})


def natural_key(name: str):
    return [int(token) if token.isdigit() else token for token in re.split(r"(\d+)", name)]


def rotate_point(point: tuple[float, float], angle_deg: float) -> tuple[float, float]:
    theta = math.radians(angle_deg)
    x, y = point
    return (
        x * math.cos(theta) - y * math.sin(theta),
        x * math.sin(theta) + y * math.cos(theta),
    )


def translate_point(point: tuple[float, float], offset: tuple[float, float]) -> tuple[float, float]:
    return (point[0] + offset[0], point[1] + offset[1])


def transform_points(
    points: list[tuple[float, float]],
    local_rotation_deg: float,
    local_translation: tuple[float, float],
    component_rotation_deg: float,
    component_translation: tuple[float, float],
) -> list[tuple[float, float]]:
    out = []
    for point in points:
        current = rotate_point(point, local_rotation_deg)
        current = translate_point(current, local_translation)
        current = rotate_point(current, component_rotation_deg)
        current = translate_point(current, component_translation)
        out.append(current)
    return out


def midpoint(points: list[tuple[float, float]]) -> tuple[float, float]:
    return ((points[0][0] + points[1][0]) / 2.0, (points[0][1] + points[1][1]) / 2.0)


def polar_step(point: tuple[float, float], angle_deg: float, length_mm: float) -> tuple[float, float]:
    theta = math.radians(angle_deg)
    return (point[0] + length_mm * math.cos(theta), point[1] + length_mm * math.sin(theta))


@dataclass
class Pin:
    name: str
    points: list[tuple[float, float]]
    width_mm: float
    outward_deg: float

    @property
    def midpoint(self) -> tuple[float, float]:
        return midpoint(self.points)


class DesignPlanar:
    def __init__(self):
        self.overwrite_enabled = False
        self.components: OrderedDict[str, Any] = OrderedDict()
        self.chips = AttrDict(
            main=AttrDict(
                size=AttrDict(
                    size_x="10mm",
                    size_y="10mm",
                    center_x="0mm",
                    center_y="0mm",
                )
            )
        )


class MetalGUI:
    def __init__(self, design: DesignPlanar):
        self.design = design

    def rebuild(self):
        return None

    def autoscale(self):
        return None


TRANSMON_DEFAULTS = Dict(
    pos_x="0mm",
    pos_y="0mm",
    orientation="0",
    gds_cell_name="",
    hfss_inductance="0nH",
    pad_gap="30um",
    inductor_width="20um",
    pad_width="455um",
    pad_height="90um",
    pocket_width="650um",
    pocket_height="650um",
    connection_pads=Dict(),
    _default_connection_pads=Dict(
        connector_type="0",
        pad_width="125um",
        pad_height="30um",
        pad_cpw_shift="0um",
        pad_cpw_extent="25um",
        claw_length="30um",
        claw_width="10um",
        claw_gap="6um",
        claw_cpw_length="40um",
        claw_cpw_width="10um",
        ground_spacing="5um",
        t_claw_height="0um",
        connector_location="0",
    ),
)

LAUNCHPAD_DEFAULTS = Dict(
    pos_x="0mm",
    pos_y="0mm",
    orientation="0",
    trace_width="cpw_width",
    trace_gap="cpw_gap",
    lead_length="25um",
    pad_width="80um",
    pad_height="80um",
    pad_gap="58um",
    taper_height="122um",
)

OPEN_DEFAULTS = Dict(
    pos_x="0mm",
    pos_y="0mm",
    orientation="0",
    width="10um",
    gap="6um",
    termination_gap="6um",
)

SHORT_DEFAULTS = Dict(
    pos_x="0mm",
    pos_y="0mm",
    orientation="0",
    width="10um",
)

CAP_DEFAULTS = Dict(
    pos_x="0mm",
    pos_y="0mm",
    orientation="0",
    north_width="10um",
    north_gap="6um",
    south_width="10um",
    south_gap="6um",
    cap_width="10um",
    cap_gap="6um",
    cap_gap_ground="6um",
    finger_length="20um",
    finger_count="5",
    cap_distance="50um",
    taper_length="200um",
)

ROUTE_DEFAULTS = Dict(
    pin_inputs=Dict(
        start_pin=Dict(component="", pin=""),
        end_pin=Dict(component="", pin=""),
    ),
    lead=Dict(
        start_straight="0um",
        end_straight="0um",
        start_jogged_extension=OrderedDict(),
    ),
    meander=Dict(
        spacing="200um",
        asymmetry="0um",
    ),
    fillet="0um",
    trace_width="10um",
    trace_gap="6um",
)


class BaseComponent:
    kind = "component"

    def __init__(self, design: DesignPlanar, name: str):
        self.design = design
        self.name = name
        self.pins = AttrDict()
        design.components[name] = self


class TransmonPocket_sqnl(BaseComponent):
    kind = "qubit"

    def __init__(self, design: DesignPlanar, name: str, options: dict[str, Any]):
        super().__init__(design, name)
        merged = deep_merge(TRANSMON_DEFAULTS, options)
        connection_pads = AttrDict()
        for pad_name, pad_options in merged.connection_pads.items():
            connection_pads[pad_name] = deep_merge(merged["_default_connection_pads"], pad_options)
        self.options = AttrDict(
            pos_x=parse_length_mm(merged.pos_x),
            pos_y=parse_length_mm(merged.pos_y),
            orientation=parse_angle_deg(merged.orientation),
            gds_cell_name=str(merged.gds_cell_name),
            hfss_inductance=parse_inductance_nh(merged.hfss_inductance),
            pad_gap=parse_length_mm(merged.pad_gap),
            inductor_width=parse_length_mm(merged.inductor_width),
            pad_width=parse_length_mm(merged.pad_width),
            pad_height=parse_length_mm(merged.pad_height),
            pocket_width=parse_length_mm(merged.pocket_width),
            pocket_height=parse_length_mm(merged.pocket_height),
            connection_pads=connection_pads,
        )
        self._build_pins()

    def _build_pins(self):
        pad_width = self.options.pad_width
        pad_height = self.options.pad_height
        pad_gap = self.options.pad_gap
        orientation = self.options.orientation
        component_translation = (self.options.pos_x, self.options.pos_y)

        rotation_lookup = {0: -180.0, 1: -90.0, 2: 0.0, 3: 0.0, 4: 90.0, 5: 180.0}

        for pad_name, pad in self.options.connection_pads.items():
            c_gap = parse_length_mm(pad.claw_gap)
            c_width = parse_length_mm(pad.claw_width)
            c_cpw_length = parse_length_mm(pad.claw_cpw_length)
            c_cpw_width = parse_length_mm(pad.claw_cpw_width)
            connector_location = parse_intish(pad.connector_location)

            local_points = [
                (-c_width, 0.5 * c_cpw_width),
                (-c_width - c_cpw_length, -0.5 * c_cpw_width),
            ]
            local_rotation = rotation_lookup[connector_location]
            local_translation = (
                ((connector_location in (0, 5)) * (pad_width / 2.0 + c_gap))
                + ((connector_location in (2, 3)) * (-pad_width / 2.0 - c_gap)),
                ((connector_location in (0, 2)) * (pad_height + pad_gap) / 2.0)
                + ((connector_location in (5, 3)) * (-(pad_height + pad_gap) / 2.0))
                + ((connector_location == 1) * (pad_height + pad_gap / 2.0 + c_gap))
                - ((connector_location == 4) * (pad_height + pad_gap / 2.0 + c_gap)),
            )
            points = transform_points(
                local_points,
                local_rotation,
                local_translation,
                orientation,
                component_translation,
            )
            outward = (local_rotation + orientation + 180.0) % 360.0
            self.pins[pad_name] = Pin(str(pad_name), points, c_cpw_width, outward)


class LaunchpadWirebond(BaseComponent):
    kind = "launch"

    def __init__(self, design: DesignPlanar, name: str, options: dict[str, Any]):
        super().__init__(design, name)
        merged = deep_merge(LAUNCHPAD_DEFAULTS, options)
        self.options = AttrDict(
            pos_x=parse_length_mm(merged.pos_x),
            pos_y=parse_length_mm(merged.pos_y),
            orientation=parse_angle_deg(merged.orientation),
            trace_width=parse_length_mm(merged.trace_width),
            trace_gap=parse_length_mm(merged.trace_gap),
            lead_length=parse_length_mm(merged.lead_length),
            pad_width=parse_length_mm(merged.pad_width),
            pad_height=parse_length_mm(merged.pad_height),
            pad_gap=parse_length_mm(merged.pad_gap),
            taper_height=parse_length_mm(merged.taper_height),
        )
        self._build_pins()

    def _build_pins(self):
        points = transform_points(
            [
                (self.options.lead_length, self.options.trace_width / 2.0),
                (self.options.lead_length, -self.options.trace_width / 2.0),
            ],
            self.options.orientation,
            (0.0, 0.0),
            0.0,
            (self.options.pos_x, self.options.pos_y),
        )
        self.pins.tie = Pin("tie", points, self.options.trace_width, self.options.orientation % 360.0)


class OpenToGround(BaseComponent):
    kind = "open_termination"

    def __init__(self, design: DesignPlanar, name: str, options: dict[str, Any]):
        super().__init__(design, name)
        merged = deep_merge(OPEN_DEFAULTS, options)
        self.options = AttrDict(
            pos_x=parse_length_mm(merged.pos_x),
            pos_y=parse_length_mm(merged.pos_y),
            orientation=parse_angle_deg(merged.orientation),
            width=parse_length_mm(merged.width),
            gap=parse_length_mm(merged.gap),
            termination_gap=parse_length_mm(merged.termination_gap),
        )
        self._build_pins()

    def _build_pins(self):
        points = transform_points(
            [(0.0, -self.options.width / 2.0), (0.0, self.options.width / 2.0)],
            self.options.orientation,
            (0.0, 0.0),
            0.0,
            (self.options.pos_x, self.options.pos_y),
        )
        outward = (180.0 + self.options.orientation) % 360.0
        self.pins.open = Pin("open", points, self.options.width, outward)


class ShortToGround(BaseComponent):
    kind = "short_termination"

    def __init__(self, design: DesignPlanar, name: str, options: dict[str, Any]):
        super().__init__(design, name)
        merged = deep_merge(SHORT_DEFAULTS, options)
        self.options = AttrDict(
            pos_x=parse_length_mm(merged.pos_x),
            pos_y=parse_length_mm(merged.pos_y),
            orientation=parse_angle_deg(merged.orientation),
            width=parse_length_mm(merged.width),
        )
        self._build_pins()

    def _build_pins(self):
        points = transform_points(
            [(0.0, -self.options.width / 2.0), (0.0, self.options.width / 2.0)],
            self.options.orientation,
            (0.0, 0.0),
            0.0,
            (self.options.pos_x, self.options.pos_y),
        )
        self.pins.short = Pin("short", points, self.options.width, self.options.orientation % 360.0)


class CapNInterdigital_sqnl(BaseComponent):
    kind = "interdigital_cap"

    def __init__(self, design: DesignPlanar, name: str, options: dict[str, Any]):
        super().__init__(design, name)
        merged = deep_merge(CAP_DEFAULTS, options)
        self.options = AttrDict(
            pos_x=parse_length_mm(merged.pos_x),
            pos_y=parse_length_mm(merged.pos_y),
            orientation=parse_angle_deg(merged.orientation),
            north_width=parse_length_mm(merged.north_width),
            north_gap=parse_length_mm(merged.north_gap),
            south_width=parse_length_mm(merged.south_width),
            south_gap=parse_length_mm(merged.south_gap),
            cap_width=parse_length_mm(merged.cap_width),
            cap_gap=parse_length_mm(merged.cap_gap),
            cap_gap_ground=parse_length_mm(merged.cap_gap_ground),
            finger_length=parse_length_mm(merged.finger_length),
            finger_count=parse_intish(merged.finger_count),
            cap_distance=parse_length_mm(merged.cap_distance),
            taper_length=parse_length_mm(merged.taper_length),
        )
        self._build_pins()

    def _build_pins(self):
        north_cpw = [
            (0.0, self.options.taper_length - self.options.cap_distance),
            (0.0, self.options.taper_length),
        ]
        south_cpw = [
            (
                0.0,
                -self.options.taper_length
                - self.options.cap_distance
                - (self.options.cap_gap + 2 * self.options.cap_width + self.options.finger_length),
            ),
            (
                0.0,
                -self.options.taper_length
                - 2 * self.options.cap_distance
                - (self.options.cap_gap + 2 * self.options.cap_width + self.options.finger_length),
            ),
        ]
        north_points = transform_points(
            north_cpw,
            self.options.orientation,
            (0.0, 0.0),
            0.0,
            (self.options.pos_x, self.options.pos_y),
        )
        south_points = transform_points(
            south_cpw,
            self.options.orientation,
            (0.0, 0.0),
            0.0,
            (self.options.pos_x, self.options.pos_y),
        )
        self.pins.north_end = Pin(
            "north_end",
            north_points,
            self.options.north_width,
            (90.0 + self.options.orientation) % 360.0,
        )
        self.pins.south_end = Pin(
            "south_end",
            south_points,
            self.options.south_width,
            (270.0 + self.options.orientation) % 360.0,
        )


def ordered_jogs(data: Any) -> list[tuple[str, float]]:
    if isinstance(data, OrderedDict):
        items = data.items()
    elif isinstance(data, list):
        items = enumerate(data)
    elif isinstance(data, dict):
        items = sorted(data.items(), key=lambda item: int(item[0]))
    else:
        return []

    jogs = []
    for _, pair in items:
        turn, length = pair
        jogs.append((str(turn), parse_length_mm(length)))
    return jogs


def meander_points(
    start_point: tuple[float, float],
    end_point: tuple[float, float],
    total_length_mm: float | None,
    spacing_mm: float | None,
    asymmetry_mm: float | None,
) -> list[tuple[float, float]]:
    if total_length_mm is None:
        return []
    spacing = spacing_mm if spacing_mm is not None else 0.2
    asymmetry = asymmetry_mm if asymmetry_mm is not None else 0.0
    dx = end_point[0] - start_point[0]
    dy = end_point[1] - start_point[1]
    horizontal = abs(dx) >= abs(dy)
    direct = abs(dx) if horizontal else abs(dy)
    if total_length_mm <= direct:
        return []

    count = max(2, int(math.floor(direct / max(spacing, 1e-6))))
    amplitude = max(spacing / 2.0, (total_length_mm - direct) / (2.0 * count))
    amplitude += abs(asymmetry)

    points = []
    if horizontal:
        x_step = dx / count
        sign_y = 1.0 if dy >= 0 else -1.0
        for index in range(1, count):
            x = start_point[0] + x_step * index
            y = start_point[1] + (amplitude if index % 2 else -amplitude) * sign_y
            points.append((x, y))
    else:
        y_step = dy / count
        sign_x = 1.0 if dx >= 0 else -1.0
        for index in range(1, count):
            y = start_point[1] + y_step * index
            x = start_point[0] + (amplitude if index % 2 else -amplitude) * sign_x
            points.append((x, y))
    return points


class BaseRoute(BaseComponent):
    kind = "route"
    route_kind = "route"

    def __init__(self, design: DesignPlanar, name: str, options: dict[str, Any]):
        super().__init__(design, name)
        merged = deep_merge(ROUTE_DEFAULTS, options)
        self.options = AttrDict(
            pin_inputs=AttrDict(
                start_pin=AttrDict(
                    component=str(merged.pin_inputs.start_pin.component),
                    pin=str(merged.pin_inputs.start_pin.pin),
                ),
                end_pin=AttrDict(
                    component=str(merged.pin_inputs.end_pin.component),
                    pin=str(merged.pin_inputs.end_pin.pin),
                ),
            ),
            trace_width=parse_length_mm(merged.trace_width),
            trace_gap=parse_length_mm(merged.trace_gap),
            fillet=parse_length_mm(merged.fillet),
            lead=AttrDict(
                start_straight=parse_length_mm(merged.lead.start_straight),
                end_straight=parse_length_mm(merged.lead.end_straight),
                start_jogged_extension=OrderedDict(
                    (index, jog) for index, jog in enumerate(ordered_jogs(merged.lead.start_jogged_extension))
                ),
            ),
            meander=AttrDict(
                spacing=parse_length_mm(merged.meander.spacing),
                asymmetry=parse_length_mm(merged.meander.asymmetry),
            ),
            total_length=parse_length_mm(merged["total_length"]) if "total_length" in merged else None,
            qgeometry_types=str(getattr(merged, "qgeometry_types", "path")),
        )
        self.resolved_waypoints_mm = self._resolve_waypoints()

    def _resolve_waypoints(self) -> list[tuple[float, float]]:
        start_component = self.design.components[self.options.pin_inputs.start_pin.component]
        end_component = self.design.components[self.options.pin_inputs.end_pin.component]
        start_pin = start_component.pins[self.options.pin_inputs.start_pin.pin]
        end_pin = end_component.pins[self.options.pin_inputs.end_pin.pin]

        points = [start_pin.midpoint]
        current = start_pin.midpoint
        direction = start_pin.outward_deg

        if self.options.lead.start_straight > 0:
            current = polar_step(current, direction, self.options.lead.start_straight)
            points.append(current)

        jogs = ordered_jogs(self.options.lead.start_jogged_extension)
        for turn, length_mm in jogs:
            direction += 90.0 if turn == "L" else -90.0
            current = polar_step(current, direction, length_mm)
            points.append(current)

        end_anchor = end_pin.midpoint
        if self.options.lead.end_straight > 0:
            end_anchor = polar_step(end_pin.midpoint, end_pin.outward_deg, self.options.lead.end_straight)

        if self.route_kind == "meander":
            points.extend(
                meander_points(
                    current,
                    end_anchor,
                    self.options.total_length,
                    self.options.meander.spacing,
                    self.options.meander.asymmetry,
                )
            )

        if points[-1] != end_anchor:
            points.append(end_anchor)
        if points[-1] != end_pin.midpoint:
            points.append(end_pin.midpoint)
        return points


class RouteMeander(BaseRoute):
    route_kind = "meander"


class RouteFramed(BaseRoute):
    route_kind = "framed"


class RouteStraight(BaseRoute):
    route_kind = "straight"


class RoutePathfinder(BaseRoute):
    route_kind = "pathfinder"


class RouteAnchors(BaseRoute):
    route_kind = "anchors"


class CapNInterdigital:
    def __init__(self, *args, **kwargs):
        raise RuntimeError("CapNInterdigital is imported but not instantiated in this notebook")


class CapNInterdigitalTee:
    def __init__(self, *args, **kwargs):
        raise RuntimeError("CapNInterdigitalTee is imported but not instantiated in this notebook")


class CoupledLineTee:
    def __init__(self, *args, **kwargs):
        raise RuntimeError("CoupledLineTee is imported but not instantiated in this notebook")


class LaunchpadWirebondCoupled:
    def __init__(self, *args, **kwargs):
        raise RuntimeError("LaunchpadWirebondCoupled is imported but not instantiated in this notebook")


def guided_wavelength(*args, **kwargs):
    return [0.0, 0.0, 0.0]


def notebook_globals():
    metal = SimpleNamespace(designs=SimpleNamespace(DesignPlanar=DesignPlanar), MetalGUI=MetalGUI)
    return {
        "__builtins__": __builtins__,
        "metal": metal,
        "MetalGUI": MetalGUI,
        "Dict": Dict,
        "OrderedDict": OrderedDict,
        "guided_wavelength": guided_wavelength,
        "RouteMeander": RouteMeander,
        "RoutePathfinder": RoutePathfinder,
        "RouteAnchors": RouteAnchors,
        "CapNInterdigital": CapNInterdigital,
        "CapNInterdigitalTee": CapNInterdigitalTee,
        "CoupledLineTee": CoupledLineTee,
        "LaunchpadWirebond": LaunchpadWirebond,
        "LaunchpadWirebondCoupled": LaunchpadWirebondCoupled,
        "RouteFramed": RouteFramed,
        "ShortToGround": ShortToGround,
        "OpenToGround": OpenToGround,
        "RouteStraight": RouteStraight,
        "TransmonPocket_sqnl": TransmonPocket_sqnl,
        "CapNInterdigital_sqnl": CapNInterdigital_sqnl,
    }


def sanitize_cell(source_lines: list[str]) -> str:
    kept = []
    for line in source_lines:
        stripped = line.lstrip()
        if stripped.startswith("%"):
            continue
        if stripped.startswith("import ") or stripped.startswith("from "):
            continue
        kept.append(line)
    return "".join(kept)


def load_source_paths() -> dict[str, str]:
    if SOURCE_PATHS.is_file():
        return json.loads(SOURCE_PATHS.read_text())
    return {
        "notebook_path": str(DEFAULT_NOTEBOOK),
        "reference_gds_path": str(DEFAULT_GDS),
    }


def stage_sources(paths: dict[str, str]):
    notebook = Path(paths["notebook_path"])
    reference_gds = Path(paths["reference_gds_path"])
    INPUT_DIR.mkdir(parents=True, exist_ok=True)
    shutil.copy2(notebook, STAGED_NOTEBOOK)
    if reference_gds.is_file():
        shutil.copy2(reference_gds, STAGED_GDS)


def execute_notebook(notebook_path: Path) -> DesignPlanar:
    notebook = json.loads(notebook_path.read_text())
    env = notebook_globals()
    for index, cell in enumerate(notebook["cells"]):
        if index > ROUTE_CELL_STOP:
            break
        if cell.get("cell_type") != "code":
            continue
        code = sanitize_cell(cell.get("source", []))
        if code.strip():
            exec(compile(code, f"{notebook_path.name}:cell_{index}", "exec"), env, env)
    design = env.get("design")
    if not isinstance(design, DesignPlanar):
        raise RuntimeError("Notebook execution did not produce a DesignPlanar instance")
    return design


def route_category(name: str) -> str:
    if name.startswith("Bus_"):
        return "bus"
    if name.startswith("readout_res_"):
        return "readout"
    if name.startswith("control") and name.endswith("_line"):
        return "control"
    return "purcell"


def export_qubit(component: TransmonPocket_sqnl) -> dict[str, Any]:
    connectors = []
    for connector_name, connector in component.options.connection_pads.items():
        entry = {
            "name": str(connector_name),
            "style": "tee" if parse_intish(connector.connector_type) == 1 else "claw",
            "connector_location": parse_intish(connector.connector_location),
            "claw_gap_um": parse_length_um(connector.claw_gap),
            "claw_width_um": parse_length_um(connector.claw_width),
            "claw_cpw_length_um": parse_length_um(connector.claw_cpw_length),
            "claw_cpw_width_um": parse_length_um(connector.claw_cpw_width),
            "ground_spacing_um": parse_length_um(connector.ground_spacing),
        }
        if entry["style"] == "tee":
            entry["t_claw_height_um"] = parse_length_um(connector.t_claw_height)
        else:
            entry["claw_length_um"] = parse_length_um(connector.claw_length)
        connectors.append(entry)

    return {
        "name": component.name,
        "pos_um": [component.options.pos_x * 1000.0, component.options.pos_y * 1000.0],
        "orientation_deg": component.options.orientation,
        "hfss_inductance_nh": component.options.hfss_inductance,
        "gds_cell_name": component.options.gds_cell_name,
        "pad_gap_um": component.options.pad_gap * 1000.0,
        "inductor_width_um": component.options.inductor_width * 1000.0,
        "pad_width_um": component.options.pad_width * 1000.0,
        "pad_height_um": component.options.pad_height * 1000.0,
        "pocket_width_um": component.options.pocket_width * 1000.0,
        "pocket_height_um": component.options.pocket_height * 1000.0,
        "connectors": connectors,
    }


def export_launch(component: LaunchpadWirebond) -> dict[str, Any]:
    return {
        "name": component.name,
        "pos_um": [component.options.pos_x * 1000.0, component.options.pos_y * 1000.0],
        "orientation_deg": component.options.orientation,
        "trace_width_um": component.options.trace_width * 1000.0,
        "trace_gap_um": component.options.trace_gap * 1000.0,
        "lead_length_um": component.options.lead_length * 1000.0,
        "pad_width_um": component.options.pad_width * 1000.0,
        "pad_height_um": component.options.pad_height * 1000.0,
        "pad_gap_um": component.options.pad_gap * 1000.0,
        "taper_height_um": component.options.taper_height * 1000.0,
    }


def export_open(component: OpenToGround) -> dict[str, Any]:
    return {
        "name": component.name,
        "pos_um": [component.options.pos_x * 1000.0, component.options.pos_y * 1000.0],
        "orientation_deg": component.options.orientation,
        "width_um": component.options.width * 1000.0,
        "gap_um": component.options.gap * 1000.0,
        "termination_gap_um": component.options.termination_gap * 1000.0,
    }


def export_short(component: ShortToGround) -> dict[str, Any]:
    return {
        "name": component.name,
        "pos_um": [component.options.pos_x * 1000.0, component.options.pos_y * 1000.0],
        "orientation_deg": component.options.orientation,
        "width_um": component.options.width * 1000.0,
    }


def export_cap(component: CapNInterdigital_sqnl) -> dict[str, Any]:
    return {
        "name": component.name,
        "pos_um": [component.options.pos_x * 1000.0, component.options.pos_y * 1000.0],
        "orientation_deg": component.options.orientation,
        "north_width_um": component.options.north_width * 1000.0,
        "north_gap_um": component.options.north_gap * 1000.0,
        "south_width_um": component.options.south_width * 1000.0,
        "south_gap_um": component.options.south_gap * 1000.0,
        "cap_width_um": component.options.cap_width * 1000.0,
        "cap_gap_um": component.options.cap_gap * 1000.0,
        "cap_gap_ground_um": component.options.cap_gap_ground * 1000.0,
        "finger_length_um": component.options.finger_length * 1000.0,
        "finger_count": component.options.finger_count,
        "cap_distance_um": component.options.cap_distance * 1000.0,
        "taper_length_um": component.options.taper_length * 1000.0,
    }


def export_route(component: BaseRoute) -> dict[str, Any]:
    component.resolved_waypoints_mm = component._resolve_waypoints()
    jogs = [
        {"turn": turn, "length_um": length_mm * 1000.0}
        for turn, length_mm in ordered_jogs(component.options.lead.start_jogged_extension)
    ]
    total_length = component.options.total_length
    return {
        "name": component.name,
        "kind": component.route_kind,
        "category": route_category(component.name),
        "start_component": component.options.pin_inputs.start_pin.component,
        "start_hook": component.options.pin_inputs.start_pin.pin,
        "end_component": component.options.pin_inputs.end_pin.component,
        "end_hook": component.options.pin_inputs.end_pin.pin,
        "trace_width_um": component.options.trace_width * 1000.0,
        "trace_gap_um": component.options.trace_gap * 1000.0,
        "fillet_um": component.options.fillet * 1000.0,
        "lead_start_straight_um": component.options.lead.start_straight * 1000.0,
        "lead_end_straight_um": component.options.lead.end_straight * 1000.0,
        "start_jogs": jogs,
        "total_length_um": None if total_length is None else total_length * 1000.0,
        "meander_spacing_um": component.options.meander.spacing * 1000.0 if component.route_kind == "meander" else None,
        "meander_asymmetry_um": component.options.meander.asymmetry * 1000.0 if component.route_kind == "meander" else None,
        "resolved_waypoints_um": [[x * 1000.0, y * 1000.0] for x, y in component.resolved_waypoints_mm],
    }


def build_spec(design: DesignPlanar, source_paths: dict[str, str]) -> dict[str, Any]:
    components = list(design.components.values())
    qubits = sorted(
        [export_qubit(component) for component in components if isinstance(component, TransmonPocket_sqnl)],
        key=lambda item: natural_key(item["name"]),
    )
    launches = [export_launch(component) for component in components if isinstance(component, LaunchpadWirebond)]
    open_terms = [export_open(component) for component in components if isinstance(component, OpenToGround)]
    short_terms = [export_short(component) for component in components if isinstance(component, ShortToGround)]
    caps = [export_cap(component) for component in components if isinstance(component, CapNInterdigital_sqnl)]
    routes = [export_route(component) for component in components if isinstance(component, BaseRoute)]

    route_counts = {
        "bus": len([route for route in routes if route["category"] == "bus"]),
        "readout": len([route for route in routes if route["category"] == "readout"]),
        "control": len([route for route in routes if route["category"] == "control"]),
        "purcell": len([route for route in routes if route["category"] == "purcell"]),
    }

    chip_size_um = [
        parse_length_um(design.chips.main.size.size_x),
        parse_length_um(design.chips.main.size.size_y),
    ]
    chip_center_um = [
        parse_length_um(design.chips.main.size.center_x),
        parse_length_um(design.chips.main.size.center_y),
    ]

    return {
        "notebook_path": source_paths["notebook_path"],
        "reference_gds_path": str(STAGED_GDS if STAGED_GDS.is_file() else source_paths["reference_gds_path"]),
        "source_design_name": "Berkeley_TrailBlazer_mimic_fullchip_1_1design_change",
        "chip_size_um": chip_size_um,
        "chip_center_um": chip_center_um,
        "validation_layers": [[1, 10], [1, 100]],
        "qubits": qubits,
        "launches": launches,
        "open_terminations": open_terms,
        "short_terminations": short_terms,
        "interdigital_caps": caps,
        "routes": routes,
        "purcell": {
            "launch_name": "Launch_Q_Read",
            "helper_launch_names": ["bridge_Q_in", "bridge_Q_out"],
            "capacitor_name": "highC_PF_TL",
            "open_name": "otg_PF",
            "route_names": [route["name"] for route in routes if route["category"] == "purcell"],
        },
        "provenance": {
            "notebook_source_path": source_paths["notebook_path"],
            "reference_gds_source_path": source_paths["reference_gds_path"],
            "staged_notebook_path": str(STAGED_NOTEBOOK),
            "staged_reference_gds_path": str(STAGED_GDS),
            "component_porting_scope": [
                "TransmonPocket_sqnl",
                "CapNInterdigital_sqnl",
                "LaunchpadWirebond",
                "OpenToGround",
                "ShortToGround",
            ],
            "ignored_imports": [
                "LaunchpadWirebondCoupled",
                "RouteAnchors",
                "RoutePathfinder",
                "CapNInterdigital",
                "CapNInterdigitalTee",
                "CoupledLineTee",
            ],
        },
        "simulation": {
            "notebook_target_ghz": 5.2,
            "notebook_mode_count": 20,
            "notebook_max_passes": 20,
            "q1_slice_target_ghz": 5.2,
            "q1_slice_mode_count": 6,
        },
        "validation": {
            "required_counts": {
                "qubits": 8,
                "bus_routes": 8,
                "readout_routes": 8,
                "control_routes": 8,
                "purcell_routes": 2,
            },
            "required_layers": [[1, 10], [1, 100]],
            "geometry_tolerance_um": 25.0,
        },
        "source_component_counts": {
            "qubits": len(qubits),
            "launches": len(launches),
            "open_terminations": len(open_terms),
            "short_terminations": len(short_terms),
            "interdigital_caps": len(caps),
            "routes": route_counts,
        },
        "notes": [
            "The notebook is the semantic source of truth; the staged GDS is the geometry-validation artifact.",
            "Resolved route waypoints are captured from the executed notebook state using a lightweight qiskit-metal stub environment.",
            "TL1 is intentionally absent because it is commented out in the notebook source.",
        ],
    }


def write_spec(spec: dict[str, Any]):
    INPUT_DIR.mkdir(parents=True, exist_ok=True)
    with SPEC_PATH.open("w") as handle:
        json.dump(spec, handle, indent=2)
        handle.write("\n")


def main() -> int:
    source_paths = load_source_paths()
    stage_sources(source_paths)
    design = execute_notebook(STAGED_NOTEBOOK)
    spec = build_spec(design, source_paths)
    write_spec(spec)

    print(f"Wrote TrailBlazer migration spec to {SPEC_PATH}")
    print(
        "Counts:",
        json.dumps(spec["source_component_counts"], indent=2),
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
