const TRAILBLAZER_INPUT_DIR = joinpath(ROOT, "inputs", "qiskit-metal", "trailblazer-fullchip")
const TRAILBLAZER_SPEC_PATH = joinpath(TRAILBLAZER_INPUT_DIR, "trailblazer_fullchip_spec.json")
const TRAILBLAZER_SOURCE_PATHS = joinpath(TRAILBLAZER_INPUT_DIR, "source_paths.json")
const TRAILBLAZER_NOTEBOOK_COPY = joinpath(TRAILBLAZER_INPUT_DIR, "source_notebook.ipynb")
const TRAILBLAZER_REFERENCE_GDS_COPY = joinpath(TRAILBLAZER_INPUT_DIR, "reference_layout.gds")
const TRAILBLAZER_FULLCHIP_BUILD_DIR = joinpath(ROOT, "build", "trailblazer-fullchip")
const TRAILBLAZER_SLICE_BUILD_DIR = joinpath(ROOT, "build", "trailblazer-q1-purcell-slice")
const TRAILBLAZER_SLICE_RESULTS_DIR = joinpath(ROOT, "results", "trailblazer-q1-purcell-slice")

export TrailBlazerConnectorSpec
export TrailBlazerClawConnectorSpec
export TrailBlazerTeeConnectorSpec
export TrailBlazerQubitSpec
export TrailBlazerRouteSpec
export TrailBlazerPurcellSpec
export TrailBlazerFullChipSpec
export load_trailblazer_spec
export build_fullchip
export build_slice
export inspect_slice_solidmodel

abstract type TrailBlazerConnectorSpec{T} end

struct TrailBlazerClawConnectorSpec{T} <: TrailBlazerConnectorSpec{T}
    name::Symbol
    connector_location::Int
    claw_gap_um::T
    claw_width_um::T
    claw_length_um::T
    claw_cpw_length_um::T
    claw_cpw_width_um::T
    ground_spacing_um::T
end

struct TrailBlazerTeeConnectorSpec{T} <: TrailBlazerConnectorSpec{T}
    name::Symbol
    connector_location::Int
    claw_gap_um::T
    claw_width_um::T
    t_claw_height_um::T
    claw_cpw_length_um::T
    claw_cpw_width_um::T
    ground_spacing_um::T
end

struct TrailBlazerQubitSpec{T}
    name::String
    pos_um::NTuple{2, T}
    orientation_deg::Float64
    hfss_inductance_nh::Float64
    gds_cell_name::String
    pad_gap_um::T
    inductor_width_um::T
    pad_width_um::T
    pad_height_um::T
    pocket_width_um::T
    pocket_height_um::T
    connectors::Vector{TrailBlazerConnectorSpec{T}}
end

struct TrailBlazerLaunchpadSpec{T}
    name::String
    pos_um::NTuple{2, T}
    orientation_deg::Float64
    trace_width_um::T
    trace_gap_um::T
    lead_length_um::T
    pad_width_um::T
    pad_height_um::T
    pad_gap_um::T
    taper_height_um::T
end

struct TrailBlazerOpenTerminationSpec{T}
    name::String
    pos_um::NTuple{2, T}
    orientation_deg::Float64
    width_um::T
    gap_um::T
    termination_gap_um::T
end

struct TrailBlazerShortTerminationSpec{T}
    name::String
    pos_um::NTuple{2, T}
    orientation_deg::Float64
    width_um::T
end

struct TrailBlazerInterdigitalCapSpec{T}
    name::String
    pos_um::NTuple{2, T}
    orientation_deg::Float64
    north_width_um::T
    north_gap_um::T
    south_width_um::T
    south_gap_um::T
    cap_width_um::T
    cap_gap_um::T
    cap_gap_ground_um::T
    finger_length_um::T
    finger_count::Int
    cap_distance_um::T
    taper_length_um::T
end

struct TrailBlazerRouteSpec{T}
    name::String
    kind::Symbol
    start_component::String
    start_hook::Symbol
    end_component::String
    end_hook::Symbol
    trace_width_um::T
    trace_gap_um::T
    fillet_um::T
    lead_start_straight_um::T
    lead_end_straight_um::T
    start_jogs::Vector{Tuple{Char, T}}
    total_length_um::Union{Nothing, T}
    meander_spacing_um::Union{Nothing, T}
    meander_asymmetry_um::Union{Nothing, T}
    resolved_waypoints_um::Vector{NTuple{2, T}}
end

struct TrailBlazerPurcellSpec
    launch_name::String
    helper_launch_names::Vector{String}
    capacitor_name::String
    open_name::String
    route_names::Vector{String}
end

struct TrailBlazerFullChipSpec{T}
    notebook_path::String
    reference_gds_path::String
    source_design_name::String
    chip_size_um::NTuple{2, T}
    chip_center_um::NTuple{2, T}
    validation_layers::Vector{Tuple{Int, Int}}
    qubits::Vector{TrailBlazerQubitSpec{T}}
    launches::Vector{TrailBlazerLaunchpadSpec{T}}
    open_terminations::Vector{TrailBlazerOpenTerminationSpec{T}}
    short_terminations::Vector{TrailBlazerShortTerminationSpec{T}}
    interdigital_caps::Vector{TrailBlazerInterdigitalCapSpec{T}}
    routes::Vector{TrailBlazerRouteSpec{T}}
    purcell::TrailBlazerPurcellSpec
end

struct TrailBlazerPocketBody <: Component
    name::String
    pad_gap
    inductor_width
    pad_width
    pad_height
    pocket_width
    pocket_height
    connection_pads::Vector{<:TrailBlazerConnectorSpec}
    _geometry::CoordinateSystem
end

struct TrailBlazerPocketTransmon <: Component
    name::String
    body::TrailBlazerPocketBody
    junction_width
    junction_mode::Symbol
    _geometry::CoordinateSystem
end

struct TrailBlazerLaunchpad <: Component
    name::String
    trace_width
    trace_gap
    lead_length
    pad_width
    pad_height
    pad_gap
    taper_height
    _geometry::CoordinateSystem
end

struct TrailBlazerOpenTermination <: Component
    name::String
    width
    gap
    termination_gap
    _geometry::CoordinateSystem
end

struct TrailBlazerShortTermination <: Component
    name::String
    width
    _geometry::CoordinateSystem
end

struct TrailBlazerInterdigitalCap <: Component
    name::String
    north_width
    north_gap
    south_width
    south_gap
    cap_width
    cap_gap
    cap_gap_ground
    finger_length
    finger_count::Int
    cap_distance
    taper_length
    _geometry::CoordinateSystem
end

struct PlacedTrailBlazerComponent
    name::String
    kind::Symbol
    position_um::NTuple{2, Float64}
    orientation_deg::Float64
    component::AbstractComponent
    reference::StructureReference
    hooks::Dict{Symbol, Hook}
end

struct TrailBlazerLayoutBuild
    coordinate_system::CoordinateSystem
    placed::Dict{String, PlacedTrailBlazerComponent}
end

tbcs(name::AbstractString) = CoordinateSystem(name, nm)
umcoord(x::Real) = Float64(x) * 1.0μm
umpt(x::Real, y::Real) = Point(umcoord(x), umcoord(y))
μm_number(x) = Float64(DeviceLayout.Unitful.ustrip(DeviceLayout.Unitful.uconvert(μm, x)))

tbrect(x0, y0, x1, y1) = Rectangle(
    Point(min(x0, x1), min(y0, y1)),
    Point(max(x0, x1), max(y0, y1))
)

function vector_point(angle, length)
    return Point(length * cos(angle), length * sin(angle))
end

connector_name(spec::TrailBlazerConnectorSpec) = spec.name
connector_location(spec::TrailBlazerConnectorSpec) = spec.connector_location
connector_gap_um(spec::TrailBlazerClawConnectorSpec) = spec.claw_gap_um
connector_gap_um(spec::TrailBlazerTeeConnectorSpec) = spec.claw_gap_um
connector_width_um(spec::TrailBlazerClawConnectorSpec) = spec.claw_width_um
connector_width_um(spec::TrailBlazerTeeConnectorSpec) = spec.claw_width_um
connector_cpw_length_um(spec::TrailBlazerClawConnectorSpec) = spec.claw_cpw_length_um
connector_cpw_length_um(spec::TrailBlazerTeeConnectorSpec) = spec.claw_cpw_length_um
connector_cpw_width_um(spec::TrailBlazerClawConnectorSpec) = spec.claw_cpw_width_um
connector_cpw_width_um(spec::TrailBlazerTeeConnectorSpec) = spec.claw_cpw_width_um
connector_ground_spacing_um(spec::TrailBlazerClawConnectorSpec) = spec.ground_spacing_um
connector_ground_spacing_um(spec::TrailBlazerTeeConnectorSpec) = spec.ground_spacing_um
connector_length_um(spec::TrailBlazerClawConnectorSpec) = spec.claw_length_um
connector_length_um(spec::TrailBlazerTeeConnectorSpec) = zero(spec.t_claw_height_um)
connector_total_height_um(spec::TrailBlazerClawConnectorSpec, body::TrailBlazerPocketBody) =
    connector_location(spec) in (0, 2, 3, 5) ? (2 * connector_gap_um(spec) + 2 * connector_width_um(spec) + body.pad_height / 1.0μm) :
    (2 * connector_gap_um(spec) + 2 * connector_width_um(spec) + body.pad_width / 1.0μm)
connector_total_height_um(spec::TrailBlazerTeeConnectorSpec, body::TrailBlazerPocketBody) =
    spec.t_claw_height_um

function TrailBlazerPocketBody(spec::TrailBlazerQubitSpec{T}) where {T}
    return TrailBlazerPocketBody(
        spec.name * "_body",
        umcoord(spec.pad_gap_um),
        umcoord(spec.inductor_width_um),
        umcoord(spec.pad_width_um),
        umcoord(spec.pad_height_um),
        umcoord(spec.pocket_width_um),
        umcoord(spec.pocket_height_um),
        spec.connectors,
        tbcs(spec.name * "_body")
    )
end

function TrailBlazerPocketTransmon(spec::TrailBlazerQubitSpec{T}) where {T}
    return TrailBlazerPocketTransmon(spec; junction_mode=:lumped)
end

function TrailBlazerPocketTransmon(spec::TrailBlazerQubitSpec{T}; junction_mode::Symbol=:lumped) where {T}
    body = TrailBlazerPocketBody(spec)
    return TrailBlazerPocketTransmon(
        spec.name,
        body,
        umcoord(spec.inductor_width_um),
        junction_mode,
        tbcs(spec.name)
    )
end

function TrailBlazerLaunchpad(spec::TrailBlazerLaunchpadSpec{T}) where {T}
    return TrailBlazerLaunchpad(
        spec.name,
        umcoord(spec.trace_width_um),
        umcoord(spec.trace_gap_um),
        umcoord(spec.lead_length_um),
        umcoord(spec.pad_width_um),
        umcoord(spec.pad_height_um),
        umcoord(spec.pad_gap_um),
        umcoord(spec.taper_height_um),
        tbcs(spec.name)
    )
end

function TrailBlazerOpenTermination(spec::TrailBlazerOpenTerminationSpec{T}) where {T}
    return TrailBlazerOpenTermination(
        spec.name,
        umcoord(spec.width_um),
        umcoord(spec.gap_um),
        umcoord(spec.termination_gap_um),
        tbcs(spec.name)
    )
end

function TrailBlazerShortTermination(spec::TrailBlazerShortTerminationSpec{T}) where {T}
    return TrailBlazerShortTermination(
        spec.name,
        umcoord(spec.width_um),
        tbcs(spec.name)
    )
end

function TrailBlazerInterdigitalCap(spec::TrailBlazerInterdigitalCapSpec{T}) where {T}
    return TrailBlazerInterdigitalCap(
        spec.name,
        umcoord(spec.north_width_um),
        umcoord(spec.north_gap_um),
        umcoord(spec.south_width_um),
        umcoord(spec.south_gap_um),
        umcoord(spec.cap_width_um),
        umcoord(spec.cap_gap_um),
        umcoord(spec.cap_gap_ground_um),
        umcoord(spec.finger_length_um),
        spec.finger_count,
        umcoord(spec.cap_distance_um),
        umcoord(spec.taper_length_um),
        tbcs(spec.name)
    )
end

function _connector_transform(spec::TrailBlazerConnectorSpec, body::TrailBlazerPocketBody)
    c_gap = umcoord(connector_gap_um(spec))
    tx =
        ((connector_location(spec) in (0, 5)) * (body.pad_width / 2 + c_gap)) +
        ((connector_location(spec) in (2, 3)) * (-body.pad_width / 2 - c_gap))
    ty =
        ((connector_location(spec) in (0, 2)) * ((body.pad_height + body.pad_gap) / 2)) +
        ((connector_location(spec) in (5, 3)) * (-(body.pad_height + body.pad_gap) / 2)) +
        ((connector_location(spec) == 1) * (body.pad_height + body.pad_gap / 2 + c_gap)) -
        ((connector_location(spec) == 4) * (body.pad_height + body.pad_gap / 2 + c_gap))
    rot = Dict(0 => -180°, 1 => -90°, 2 => 0°, 3 => 0°, 4 => 90°, 5 => 180°)[connector_location(spec)]
    return Translation(Point(tx, ty)) ∘ Rotation(rot)
end

function _connector_geometry(spec::TrailBlazerClawConnectorSpec, body::TrailBlazerPocketBody)
    c_gap = umcoord(spec.claw_gap_um)
    c_len = umcoord(spec.claw_length_um)
    c_width = umcoord(spec.claw_width_um)
    c_cpw_len = umcoord(spec.claw_cpw_length_um)
    c_cpw_width = umcoord(spec.claw_cpw_width_um)
    ground_spacing = umcoord(spec.ground_spacing_um)
    total_height = umcoord(connector_total_height_um(spec, body))

    claw_cpw = tbrect(-c_width, -c_cpw_width / 2, -c_cpw_len - c_width, c_cpw_width / 2)
    claw_base = tbrect(-c_width, -total_height / 2, c_len, total_height / 2)
    claw_sub = tbrect(0μm, -total_height / 2 + c_width, c_len, total_height / 2 - c_width)
    connector_arm = union2d([claw_base, claw_cpw])
    connector_arm = only(to_polygons(difference2d(connector_arm, [claw_sub])))
    etch_pad = connector_location(spec) in (1, 4) ? ground_spacing : c_gap
    connector_etcher = only(halo(connector_arm, etch_pad))

    transform = _connector_transform(spec, body)
    port_mid = transform(Point(-(c_width + c_cpw_len / 2), 0μm))
    inward = rotated_direction(0°, transform)
    return transform(connector_arm), transform(connector_etcher), PointHook(port_mid, inward)
end

function _connector_geometry(spec::TrailBlazerTeeConnectorSpec, body::TrailBlazerPocketBody)
    c_gap = umcoord(spec.claw_gap_um)
    c_width = umcoord(spec.claw_width_um)
    c_cpw_len = umcoord(spec.claw_cpw_length_um)
    c_cpw_width = umcoord(spec.claw_cpw_width_um)
    ground_spacing = umcoord(spec.ground_spacing_um)
    total_height = umcoord(spec.t_claw_height_um)

    claw_cpw = tbrect(-c_width, -c_cpw_width / 2, -c_cpw_len - c_width, c_cpw_width / 2)
    claw_base = tbrect(-c_width, -total_height / 2, 0μm, total_height / 2)
    connector_arm = union2d([claw_base, claw_cpw])
    connector_arm = only(to_polygons(connector_arm))
    etch_pad = connector_location(spec) in (1, 4) ? ground_spacing : c_gap
    connector_etcher = only(halo(connector_arm, etch_pad))

    transform = _connector_transform(spec, body)
    port_mid = transform(Point(-(c_width + c_cpw_len / 2), 0μm))
    inward = rotated_direction(0°, transform)
    return transform(connector_arm), transform(connector_etcher), PointHook(port_mid, inward)
end

function SchematicDrivenLayout._geometry!(cs::CoordinateSystem, body::TrailBlazerPocketBody)
    pad = centered(Rectangle(body.pad_width, body.pad_height))
    pad_top = pad + Point(0μm, (body.pad_height + body.pad_gap) / 2)
    pad_bot = pad + Point(0μm, -(body.pad_height + body.pad_gap) / 2)
    pocket = centered(Rectangle(body.pocket_width, body.pocket_height))

    place!(cs, pad_top, LayerVocabulary.METAL_POSITIVE)
    place!(cs, pad_bot, LayerVocabulary.METAL_POSITIVE)
    place!(cs, pocket, LayerVocabulary.METAL_NEGATIVE)

    for connector in body.connection_pads
        positive, negative, _ = _connector_geometry(connector, body)
        place!(cs, positive, LayerVocabulary.METAL_POSITIVE)
        place!(cs, negative, LayerVocabulary.METAL_NEGATIVE)
    end
    return cs
end

function SchematicDrivenLayout.hooks(body::TrailBlazerPocketBody)
    pairs = Pair{Symbol, Hook}[]
    push!(pairs, :junction => PointHook(0μm, 0μm, 90°))
    for connector in body.connection_pads
        _, _, hook = _connector_geometry(connector, body)
        push!(pairs, connector_name(connector) => hook)
    end
    names = Tuple(first.(pairs))
    values = Tuple(last.(pairs))
    return NamedTuple{names}(values)
end

function SchematicDrivenLayout._geometry!(cs::CoordinateSystem, transmon::TrailBlazerPocketTransmon)
    addref!(cs, sref(geometry(transmon.body)))
    if transmon.junction_mode == :lumped
        junction = ExampleSimpleJunction(;
            name=transmon.name * "_junction",
            w_jj=transmon.junction_width,
            h_ground_island=transmon.body.pad_gap
        )
        addref!(cs, sref(geometry(junction)))
    else
        bridge = centered(Rectangle(transmon.junction_width, transmon.body.pad_gap))
        place!(cs, bridge, LayerVocabulary.METAL_POSITIVE)
    end
    return cs
end

SchematicDrivenLayout.hooks(transmon::TrailBlazerPocketTransmon) = hooks(transmon.body)

function SchematicDrivenLayout._geometry!(cs::CoordinateSystem, launch::TrailBlazerLaunchpad)
    tw = launch.trace_width
    twh = tw / 2
    pwh = launch.pad_width / 2
    lead = launch.lead_length
    taper = launch.taper_height
    pad = launch.pad_height
    gap = launch.trace_gap
    pad_gap = launch.pad_gap

    launch_pad = Polygon([
        Point(0μm, twh),
        Point(-taper, pwh),
        Point(-(pad + taper), pwh),
        Point(-(pad + taper), -pwh),
        Point(-taper, -pwh),
        Point(0μm, -twh),
        Point(lead, -twh),
        Point(lead, twh),
    ])
    pocket = Polygon([
        Point(0μm, twh + gap),
        Point(-taper, pwh + pad_gap),
        Point(-(pad + taper + pad_gap), pwh + pad_gap),
        Point(-(pad + taper + pad_gap), -(pwh + pad_gap)),
        Point(-taper, -(pwh + pad_gap)),
        Point(0μm, -(twh + gap)),
        Point(lead, -(twh + gap)),
        Point(lead, twh + gap),
    ])
    place!(cs, launch_pad, LayerVocabulary.METAL_POSITIVE)
    place!(cs, pocket, LayerVocabulary.METAL_NEGATIVE)
    return cs
end

function SchematicDrivenLayout.hooks(launch::TrailBlazerLaunchpad)
    return (; tie = PointHook(Point(launch.lead_length, 0μm), 180°))
end

function SchematicDrivenLayout._geometry!(cs::CoordinateSystem, term::TrailBlazerOpenTermination)
    open_rect = tbrect(0μm, -(term.width / 2 + term.gap), term.termination_gap, term.width / 2 + term.gap)
    place!(cs, open_rect, LayerVocabulary.METAL_NEGATIVE)
    return cs
end

function SchematicDrivenLayout.hooks(term::TrailBlazerOpenTermination)
    return (; open = PointHook(0μm, 0μm, 0°))
end

function SchematicDrivenLayout._geometry!(cs::CoordinateSystem, term::TrailBlazerShortTermination)
    return cs
end

function SchematicDrivenLayout.hooks(term::TrailBlazerShortTermination)
    return (; short = PointHook(0μm, 0μm, 0°))
end

function SchematicDrivenLayout._geometry!(cs::CoordinateSystem, cap::TrailBlazerInterdigitalCap)
    n = cap.finger_count
    body_width = n * cap.cap_width + (n - 1) * cap.cap_gap
    body_height = cap.cap_gap + 2 * cap.cap_width + cap.finger_length
    top_y = -cap.cap_distance
    bottom_y = top_y - body_height
    pitch = cap.cap_width + cap.cap_gap

    body_parts = [
        tbrect(-body_width / 2, top_y, body_width / 2, top_y - cap.cap_width),
        tbrect(-body_width / 2, bottom_y + cap.cap_width, body_width / 2, bottom_y),
    ]
    x0 = -body_width / 2
    for idx in 0:(n - 1)
        finger = tbrect(x0, top_y - cap.cap_width, x0 + cap.cap_width, top_y - cap.cap_width - cap.finger_length)
        if isodd(idx)
            finger = tbrect(
                x0,
                bottom_y + cap.cap_width + cap.finger_length,
                x0 + cap.cap_width,
                bottom_y + cap.cap_width
            )
        end
        push!(body_parts, finger)
        x0 += pitch
    end

    cap_body = to_polygons(union2d(body_parts))
    north = tbrect(-cap.north_width / 2, cap.taper_length, cap.north_width / 2, top_y)
    south = tbrect(
        -cap.south_width / 2,
        bottom_y,
        cap.south_width / 2,
        -cap.taper_length - 2 * cap.cap_distance - body_height
    )

    place!(cs, north, LayerVocabulary.METAL_POSITIVE)
    place!(cs, south, LayerVocabulary.METAL_POSITIVE)
    place!.(Ref(cs), cap_body, Ref(LayerVocabulary.METAL_POSITIVE))
    place!.(Ref(cs), halo(cap_body, cap.cap_gap_ground), Ref(LayerVocabulary.METAL_NEGATIVE))
    place!(cs, only(halo(north, cap.north_gap)), LayerVocabulary.METAL_NEGATIVE)
    place!(cs, only(halo(south, cap.south_gap)), LayerVocabulary.METAL_NEGATIVE)
    return cs
end

function SchematicDrivenLayout.hooks(cap::TrailBlazerInterdigitalCap)
    return (;
        north_end = PointHook(Point(0μm, cap.taper_length), -90°),
        south_end = PointHook(
            Point(0μm, -cap.taper_length - 2 * cap.cap_distance - (cap.cap_gap + 2 * cap.cap_width + cap.finger_length)),
            90°
        )
    )
end

function _connector_from_json(data)
    style = String(data["style"])
    if style == "claw"
        return TrailBlazerClawConnectorSpec(
            Symbol(data["name"]),
            Int(data["connector_location"]),
            Float64(data["claw_gap_um"]),
            Float64(data["claw_width_um"]),
            Float64(data["claw_length_um"]),
            Float64(data["claw_cpw_length_um"]),
            Float64(data["claw_cpw_width_um"]),
            Float64(data["ground_spacing_um"])
        )
    end
    return TrailBlazerTeeConnectorSpec(
        Symbol(data["name"]),
        Int(data["connector_location"]),
        Float64(data["claw_gap_um"]),
        Float64(data["claw_width_um"]),
        Float64(data["t_claw_height_um"]),
        Float64(data["claw_cpw_length_um"]),
        Float64(data["claw_cpw_width_um"]),
        Float64(data["ground_spacing_um"])
    )
end

_pairtuple(values) = (Float64(values[1]), Float64(values[2]))

function _route_jogs(data)
    jogs = Tuple{Char, Float64}[]
    for item in data
        push!(jogs, (only(String(item["turn"])), Float64(item["length_um"])))
    end
    return jogs
end

function _route_points(data)
    points = Tuple{Float64, Float64}[]
    for item in data
        push!(points, (Float64(item[1]), Float64(item[2])))
    end
    return points
end

function load_trailblazer_spec(path::AbstractString=TRAILBLAZER_SPEC_PATH)
    raw = JSON.parsefile(path)

    qubits = TrailBlazerQubitSpec{Float64}[]
    for item in raw["qubits"]
        connectors = TrailBlazerConnectorSpec{Float64}[]
        for connector in item["connectors"]
            push!(connectors, _connector_from_json(connector))
        end
        push!(
            qubits,
            TrailBlazerQubitSpec(
                item["name"],
                _pairtuple(item["pos_um"]),
                Float64(item["orientation_deg"]),
                Float64(item["hfss_inductance_nh"]),
                item["gds_cell_name"],
                Float64(item["pad_gap_um"]),
                Float64(item["inductor_width_um"]),
                Float64(item["pad_width_um"]),
                Float64(item["pad_height_um"]),
                Float64(item["pocket_width_um"]),
                Float64(item["pocket_height_um"]),
                connectors
            )
        )
    end

    launches = TrailBlazerLaunchpadSpec{Float64}[
        TrailBlazerLaunchpadSpec(
            item["name"],
            _pairtuple(item["pos_um"]),
            Float64(item["orientation_deg"]),
            Float64(item["trace_width_um"]),
            Float64(item["trace_gap_um"]),
            Float64(item["lead_length_um"]),
            Float64(item["pad_width_um"]),
            Float64(item["pad_height_um"]),
            Float64(item["pad_gap_um"]),
            Float64(item["taper_height_um"])
        ) for item in raw["launches"]
    ]

    opens = TrailBlazerOpenTerminationSpec{Float64}[
        TrailBlazerOpenTerminationSpec(
            item["name"],
            _pairtuple(item["pos_um"]),
            Float64(item["orientation_deg"]),
            Float64(item["width_um"]),
            Float64(item["gap_um"]),
            Float64(item["termination_gap_um"])
        ) for item in raw["open_terminations"]
    ]

    shorts = TrailBlazerShortTerminationSpec{Float64}[
        TrailBlazerShortTerminationSpec(
            item["name"],
            _pairtuple(item["pos_um"]),
            Float64(item["orientation_deg"]),
            Float64(item["width_um"])
        ) for item in raw["short_terminations"]
    ]

    caps = TrailBlazerInterdigitalCapSpec{Float64}[
        TrailBlazerInterdigitalCapSpec(
            item["name"],
            _pairtuple(item["pos_um"]),
            Float64(item["orientation_deg"]),
            Float64(item["north_width_um"]),
            Float64(item["north_gap_um"]),
            Float64(item["south_width_um"]),
            Float64(item["south_gap_um"]),
            Float64(item["cap_width_um"]),
            Float64(item["cap_gap_um"]),
            Float64(item["cap_gap_ground_um"]),
            Float64(item["finger_length_um"]),
            Int(item["finger_count"]),
            Float64(item["cap_distance_um"]),
            Float64(item["taper_length_um"])
        ) for item in raw["interdigital_caps"]
    ]

    routes = TrailBlazerRouteSpec{Float64}[]
    for item in raw["routes"]
        push!(
            routes,
            TrailBlazerRouteSpec(
                item["name"],
                Symbol(item["kind"]),
                item["start_component"],
                Symbol(item["start_hook"]),
                item["end_component"],
                Symbol(item["end_hook"]),
                Float64(item["trace_width_um"]),
                Float64(item["trace_gap_um"]),
                Float64(item["fillet_um"]),
                Float64(item["lead_start_straight_um"]),
                Float64(item["lead_end_straight_um"]),
                _route_jogs(item["start_jogs"]),
                isnothing(item["total_length_um"]) ? nothing : Float64(item["total_length_um"]),
                isnothing(item["meander_spacing_um"]) ? nothing : Float64(item["meander_spacing_um"]),
                isnothing(item["meander_asymmetry_um"]) ? nothing : Float64(item["meander_asymmetry_um"]),
                haskey(item, "resolved_waypoints_um") ? _route_points(item["resolved_waypoints_um"]) : Tuple{Float64, Float64}[]
            )
        )
    end

    purcell = TrailBlazerPurcellSpec(
        raw["purcell"]["launch_name"],
        String.(raw["purcell"]["helper_launch_names"]),
        raw["purcell"]["capacitor_name"],
        raw["purcell"]["open_name"],
        String.(raw["purcell"]["route_names"])
    )

    return TrailBlazerFullChipSpec(
        raw["notebook_path"],
        raw["reference_gds_path"],
        raw["source_design_name"],
        _pairtuple(raw["chip_size_um"]),
        _pairtuple(raw["chip_center_um"]),
        [(Int(layer[1]), Int(layer[2])) for layer in raw["validation_layers"]],
        qubits,
        launches,
        opens,
        shorts,
        caps,
        routes,
        purcell
    )
end

function _transform_for_pos(pos_um::NTuple{2, Float64}, orientation_deg::Real)
    return Translation(umpt(pos_um[1], pos_um[2])) ∘ Rotation(orientation_deg * 1.0°)
end

function _global_hook_dict(component::AbstractComponent, transform)
    out = Dict{Symbol, Hook}()
    for (name, hook) in pairs(hooks(component))
        out[name] = transform(hook)
    end
    return out
end

function _component_kind(component::AbstractComponent)
    component isa TrailBlazerPocketTransmon && return :qubit
    component isa TrailBlazerLaunchpad && return :launch
    component isa TrailBlazerOpenTermination && return :open_termination
    component isa TrailBlazerShortTermination && return :short_termination
    component isa TrailBlazerInterdigitalCap && return :interdigital_cap
    return :component
end

function _place_component!(cs::CoordinateSystem, component::AbstractComponent, pos_um, orientation_deg)
    transform = _transform_for_pos(pos_um, orientation_deg)
    ref = sref(geometry(component), transform)
    push!(refs(cs), ref)
    return PlacedTrailBlazerComponent(
        name(component),
        _component_kind(component),
        (Float64(pos_um[1]), Float64(pos_um[2])),
        Float64(orientation_deg),
        component,
        ref,
        _global_hook_dict(component, transform)
    )
end

function _build_component_registry(spec::TrailBlazerFullChipSpec; component_filter=nothing, lumped_qubits=nothing)
    include_all = isnothing(component_filter)
    wanted = include_all ? Set{String}() : Set(String.(component_filter))
    active_lumped_qubits = isnothing(lumped_qubits) ? Set(qubit.name for qubit in spec.qubits) : Set(String.(lumped_qubits))
    cs = CoordinateSystem("trailblazer_fullchip", nm)
    placed = Dict{String, PlacedTrailBlazerComponent}()

    for qubit in spec.qubits
        include_all || (qubit.name in wanted) || continue
        junction_mode = qubit.name in active_lumped_qubits ? :lumped : :metal
        placed[qubit.name] = _place_component!(cs, TrailBlazerPocketTransmon(qubit; junction_mode=junction_mode), qubit.pos_um, qubit.orientation_deg)
    end
    for launch in spec.launches
        include_all || (launch.name in wanted) || continue
        placed[launch.name] = _place_component!(cs, TrailBlazerLaunchpad(launch), launch.pos_um, launch.orientation_deg)
    end
    for term in spec.open_terminations
        include_all || (term.name in wanted) || continue
        placed[term.name] = _place_component!(cs, TrailBlazerOpenTermination(term), term.pos_um, term.orientation_deg)
    end
    for term in spec.short_terminations
        include_all || (term.name in wanted) || continue
        placed[term.name] = _place_component!(cs, TrailBlazerShortTermination(term), term.pos_um, term.orientation_deg)
    end
    for cap in spec.interdigital_caps
        include_all || (cap.name in wanted) || continue
        placed[cap.name] = _place_component!(cs, TrailBlazerInterdigitalCap(cap), cap.pos_um, cap.orientation_deg)
    end

    return TrailBlazerLayoutBuild(cs, placed)
end

function _style(route::TrailBlazerRouteSpec)
    return Paths.SimpleCPW(umcoord(route.trace_width_um), umcoord(route.trace_gap_um))
end

function _bend_radius(route::TrailBlazerRouteSpec)
    return max(umcoord(route.fillet_um), 1.0μm)
end

function _lead_anchor(hook::Hook, length_um::Real, outward::Bool)
    direction = outward ? out_direction(hook) : in_direction(hook)
    return hook.p + vector_point(direction, umcoord(length_um))
end

function _same_point(left::Point, right::Point; tol=0.1μm)
    return abs(left.x - right.x) <= tol && abs(left.y - right.y) <= tol
end

function _segment_angle(p0::Point, p1::Point)
    dx = Float64((p1.x - p0.x) / 1.0μm)
    dy = Float64((p1.y - p0.y) / 1.0μm)
    return atan(dy, dx)
end

_segment_length(p0::Point, p1::Point) = hypot(p1.x - p0.x, p1.y - p0.y)

function _normalized_turn(α_next, α_prev)
    dα = α_next - α_prev
    while dα <= -π
        dα += 2π
    end
    while dα > π
        dα -= 2π
    end
    return dα
end

function _jog_waypoints(start_point::Point, start_direction, jogs)
    current = start_point
    current_direction = start_direction
    points = Point[]
    for (turn, length_um) in jogs
        current_direction += turn == 'L' ? 90° : -90°
        current += vector_point(current_direction, umcoord(length_um))
        push!(points, current)
    end
    return points, current_direction
end

function _manhattan_meander_waypoints(start_anchor::Point, end_anchor::Point, route::TrailBlazerRouteSpec)
    spacing = isnothing(route.meander_spacing_um) ? 200.0 : route.meander_spacing_um
    total_length = isnothing(route.total_length_um) ? nothing : route.total_length_um
    asymmetry = isnothing(route.meander_asymmetry_um) ? 0.0 : route.meander_asymmetry_um
    dx = end_anchor.x - start_anchor.x
    dy = end_anchor.y - start_anchor.y

    horizontal = abs(dx) >= abs(dy)
    direct = horizontal ? abs(dx) : abs(dy)
    if isnothing(total_length) || total_length <= direct / 1.0μm
        return Point[]
    end

    meander_count = max(2, Int(floor(direct / umcoord(spacing))))
    amplitude = max(umcoord(spacing) / 2, (umcoord(total_length) - direct) / (2 * meander_count))
    amplitude += umcoord(abs(asymmetry))

    waypoints = Point[]
    if horizontal
        xstep = dx / meander_count
        signy = dy >= 0 ? 1 : -1
        for idx in 1:(meander_count - 1)
            x = start_anchor.x + xstep * idx
            y = start_anchor.y + (isodd(idx) ? signy * amplitude : -signy * amplitude)
            push!(waypoints, Point(x, y))
        end
    else
        ystep = dy / meander_count
        signx = dx >= 0 ? 1 : -1
        for idx in 1:(meander_count - 1)
            y = start_anchor.y + ystep * idx
            x = start_anchor.x + (isodd(idx) ? signx * amplitude : -signx * amplitude)
            push!(waypoints, Point(x, y))
        end
    end
    return waypoints
end

function _route_waypoints(route::TrailBlazerRouteSpec, start_hook::Hook, end_hook::Hook)
    if !isempty(route.resolved_waypoints_um)
        path_points = [umpt(x, y) for (x, y) in route.resolved_waypoints_um]
        waypoints = Point[]
        if !_same_point(first(path_points), start_hook.p)
            push!(waypoints, first(path_points))
        end
        if length(path_points) > 2
            append!(waypoints, path_points[2:(end - 1)])
        end
        if !_same_point(last(path_points), end_hook.p)
            push!(waypoints, last(path_points))
        end
        return start_hook.p, waypoints
    end

    start_anchor = route.lead_start_straight_um > 0 ? _lead_anchor(start_hook, route.lead_start_straight_um, true) : start_hook.p
    start_direction = out_direction(start_hook)
    points, _ = _jog_waypoints(start_anchor, start_direction, route.start_jogs)
    end_anchor = route.lead_end_straight_um > 0 ? _lead_anchor(end_hook, route.lead_end_straight_um, false) : end_hook.p

    if route.kind == :meander
        append!(points, _manhattan_meander_waypoints(isempty(points) ? start_anchor : last(points), end_anchor, route))
    end

    route.lead_end_straight_um > 0 && push!(points, end_anchor)
    return start_anchor, points
end

function _resolved_route_points(route::TrailBlazerRouteSpec, start_hook::Hook, end_hook::Hook)
    isempty(route.resolved_waypoints_um) && return nothing
    points = [umpt(x, y) for (x, y) in route.resolved_waypoints_um]
    !_same_point(first(points), start_hook.p) && pushfirst!(points, start_hook.p)
    !_same_point(last(points), end_hook.p) && push!(points, end_hook.p)
    return points
end

function _route_points(route::TrailBlazerRouteSpec, placed::Dict{String, PlacedTrailBlazerComponent})
    haskey(placed, route.start_component) || return Point[]
    haskey(placed, route.end_component) || return Point[]
    start_hook = placed[route.start_component].hooks[route.start_hook]
    end_hook = placed[route.end_component].hooks[route.end_hook]

    resolved_points = _resolved_route_points(route, start_hook, end_hook)
    if !isnothing(resolved_points)
        return resolved_points
    end

    start_anchor, waypoints = _route_waypoints(route, start_hook, end_hook)
    points = Point[start_hook.p]
    !_same_point(start_anchor, start_hook.p) && push!(points, start_anchor)
    append!(points, waypoints)
    !_same_point(points[end], end_hook.p) && push!(points, end_hook.p)
    return points
end

function _render_polyline_path!(cs, path_name::AbstractString, points::AbstractVector{<:Point}, style, meta)
    filtered = Point[]
    for point in points
        isempty(filtered) || _same_point(filtered[end], point) || push!(filtered, point)
        isempty(filtered) && push!(filtered, point)
    end
    length(filtered) < 2 && return

    α0 = _segment_angle(filtered[1], filtered[2])
    path = Path(filtered[1]; α0=α0, name=path_name, metadata=meta)
    straight!(path, _segment_length(filtered[1], filtered[2]), style)

    for idx in 2:(length(filtered) - 1)
        prev = filtered[idx - 1]
        curr = filtered[idx]
        nxt = filtered[idx + 1]
        α_prev = _segment_angle(prev, curr)
        α_next = _segment_angle(curr, nxt)
        dα = _normalized_turn(α_next, α_prev)
        !iszero(dα) && turn!(path, dα, zero(_segment_length(curr, nxt)), style)
        straight!(path, _segment_length(curr, nxt), style)
    end

    render!(cs, path)
end

function _render_polyline_route!(cs::CoordinateSystem, route::TrailBlazerRouteSpec, style, points::AbstractVector{<:Point})
    return _render_polyline_path!(cs, route.name, points, style, LayerVocabulary.METAL_NEGATIVE)
end

function _render_route!(cs::CoordinateSystem, route::TrailBlazerRouteSpec, placed::Dict{String, PlacedTrailBlazerComponent})
    haskey(placed, route.start_component) || return
    haskey(placed, route.end_component) || return
    start_hook = placed[route.start_component].hooks[route.start_hook]
    end_hook = placed[route.end_component].hooks[route.end_hook]
    style = _style(route)

    resolved_points = _resolved_route_points(route, start_hook, end_hook)
    !isnothing(resolved_points) && return _render_polyline_route!(cs, route, style, resolved_points)

    path = Path(start_hook.p; α0=out_direction(start_hook), name=route.name, metadata=LayerVocabulary.METAL_NEGATIVE)

    start_anchor, waypoints = _route_waypoints(route, start_hook, end_hook)
    if start_anchor != start_hook.p
        pushfirst!(waypoints, start_anchor)
    end
    rule = Paths.StraightAnd90(min_bend_radius=_bend_radius(route), max_bend_radius=_bend_radius(route))
    route!(path, end_hook.p, in_direction(end_hook), rule, style; waypoints=waypoints)
    render!(cs, path)
end

function _render_selected_routes!(layout::TrailBlazerLayoutBuild, spec::TrailBlazerFullChipSpec; route_filter=nothing)
    include_all = isnothing(route_filter)
    wanted = include_all ? Set{String}() : Set(String.(route_filter))
    for route in spec.routes
        include_all || (route.name in wanted) || continue
        _render_route!(layout.coordinate_system, route, layout.placed)
    end
    return layout
end

function _serialize_hooks(path::AbstractString, placed::Dict{String, PlacedTrailBlazerComponent})
    data = Dict{String, Any}()
    for (name, comp) in placed
        hooks_out = Dict{String, Any}()
        for (hook_name, hook) in comp.hooks
            hooks_out[String(hook_name)] = Dict(
                "point_um" => [Float64(hook.p.x / 1.0μm), Float64(hook.p.y / 1.0μm)],
                "in_direction_deg" => Float64(in_direction(hook) / 1.0°)
            )
        end
        data[name] = hooks_out
    end
    open(path, "w") do io
        JSON.print(io, data, 2)
        write(io, '\n')
    end
end

function _trailblazer_map_meta(meta)
    meta isa GDSMeta && return meta
    meta == LayerVocabulary.METAL_POSITIVE && return GDSMeta(1, 10)
    meta == LayerVocabulary.METAL_NEGATIVE && return GDSMeta(1, 100)
    meta == LayerVocabulary.JUNCTION_PATTERN && return GDSMeta(1, 10)
    meta == LayerVocabulary.PORT && return GDSMeta(1, 10)
    return nothing
end

function _trailblazer_graphics_meta(meta)
    meta isa GDSMeta && return meta
    meta == LayerVocabulary.METAL_POSITIVE && return GDSMeta(10, 0)
    meta == LayerVocabulary.METAL_NEGATIVE && return GDSMeta(11, 0)
    meta == LayerVocabulary.PORT && return GDSMeta(12, 0)
    meta == LayerVocabulary.JUNCTION_PATTERN && return GDSMeta(13, 0)
    meta == LayerVocabulary.SIMULATED_AREA && return GDSMeta(14, 0)
    meta == LayerVocabulary.CHIP_AREA && return GDSMeta(15, 0)
    meta == LayerVocabulary.WRITEABLE_AREA && return nothing
    return nothing
end

const TRAILBLAZER_COMPONENT_ROLE_LAYERS = Dict(
    :qubit => 20,
    :launch => 21,
    :open_termination => 22,
    :short_termination => 23,
    :interdigital_cap => 24,
    :component => 25,
)

const TRAILBLAZER_ROUTE_ROLE_LAYERS = Dict(
    :bus => 30,
    :readout => 31,
    :control => 32,
    :purcell => 33,
)

const TRAILBLAZER_INSPECTION_BASE_LAYERS = Dict(
    :metal => 50,
    :etch => 51,
    :port => 52,
    :simulated_area => 53,
    :chip_area => 54,
    :label => 60,
)

function _trailblazer_inspection_base_meta(meta)
    meta isa GDSMeta && return meta
    (meta == LayerVocabulary.METAL_POSITIVE || meta == LayerVocabulary.JUNCTION_PATTERN) &&
        return GDSMeta(TRAILBLAZER_INSPECTION_BASE_LAYERS[:metal], 0)
    meta == LayerVocabulary.METAL_NEGATIVE &&
        return GDSMeta(TRAILBLAZER_INSPECTION_BASE_LAYERS[:etch], 0)
    meta == LayerVocabulary.PORT &&
        return GDSMeta(TRAILBLAZER_INSPECTION_BASE_LAYERS[:port], 0)
    meta == LayerVocabulary.SIMULATED_AREA &&
        return GDSMeta(TRAILBLAZER_INSPECTION_BASE_LAYERS[:simulated_area], 0)
    meta == LayerVocabulary.CHIP_AREA &&
        return GDSMeta(TRAILBLAZER_INSPECTION_BASE_LAYERS[:chip_area], 0)
    meta == LayerVocabulary.WRITEABLE_AREA && return nothing
    return nothing
end

function _trailblazer_layout_graphics_options(; fullchip::Bool=false)
    layercolors = Dict(
        10 => (0.09, 0.18, 0.31, 0.92),
        11 => (0.91, 0.55, 0.20, 0.46),
        12 => (0.16, 0.59, 0.43, 0.88),
        13 => (0.73, 0.20, 0.16, 0.95),
        14 => (0.23, 0.61, 0.80, 0.17),
        15 => (0.88, 0.80, 0.56, 0.13),
        20 => (0.11, 0.29, 0.73, 0.55),
        21 => (0.10, 0.58, 0.43, 0.55),
        22 => (0.86, 0.52, 0.14, 0.55),
        23 => (0.76, 0.24, 0.20, 0.55),
        24 => (0.53, 0.30, 0.72, 0.55),
        25 => (0.27, 0.32, 0.38, 0.55),
        30 => (0.20, 0.36, 0.86, 0.88),
        31 => (0.12, 0.63, 0.49, 0.88),
        32 => (0.90, 0.56, 0.14, 0.88),
        33 => (0.77, 0.20, 0.17, 0.88),
        50 => (0.18, 0.20, 0.23, 0.18),
        51 => (0.43, 0.46, 0.50, 0.12),
        52 => (0.14, 0.53, 0.42, 0.75),
        53 => (0.20, 0.57, 0.82, 0.08),
        54 => (0.88, 0.80, 0.56, 0.08),
        60 => (0.07, 0.09, 0.12, 0.95),
    )
    return fullchip ?
        (; width=2200, height=1400, layercolors) :
        (; width=1600, height=1100, layercolors)
end

function _trailblazer_layout_cell(name::AbstractString, cs::CoordinateSystem; graphics::Bool=false)
    cell = Cell(name, nm)
    render!(cell, cs; map_meta=graphics ? _trailblazer_graphics_meta : _trailblazer_map_meta)
    return cell
end

function _write_graphics_bundle(output_dir::AbstractString, basename::AbstractString, cell::Cell; fullchip::Bool=false, include_pdf::Bool=true)
    options = _trailblazer_layout_graphics_options(; fullchip=fullchip)
    svg_path = joinpath(output_dir, basename * ".svg")
    png_path = joinpath(output_dir, basename * ".png")
    pdf_path = include_pdf ? joinpath(output_dir, basename * ".pdf") : nothing

    save(svg_path, cell; options...)
    save(png_path, cell; options...)
    !isnothing(pdf_path) && save(pdf_path, cell; options...)
    return (; svg_path, png_path, pdf_path)
end

function _write_layout_graphics(output_dir::AbstractString, cell::Cell; fullchip::Bool=false, include_pdf::Bool=true)
    return _write_graphics_bundle(output_dir, "layout", cell; fullchip=fullchip, include_pdf=include_pdf)
end

function _write_trailblazer_layout_outputs(output_dir::AbstractString, cs::CoordinateSystem, cell_name::AbstractString; save_layout_graphics::Bool=true, fullchip::Bool=false)
    gds_path = joinpath(output_dir, "device.gds")
    save(gds_path, _trailblazer_layout_cell(cell_name, cs))

    if !save_layout_graphics
        return (; gds_path, layout_svg_path=nothing, layout_png_path=nothing, layout_pdf_path=nothing)
    end

    graphics_paths = _write_layout_graphics(
        output_dir,
        _trailblazer_layout_cell(cell_name * "_layout", cs; graphics=true);
        fullchip=fullchip
    )
    return (;
        gds_path,
        layout_svg_path=graphics_paths.svg_path,
        layout_png_path=graphics_paths.png_path,
        layout_pdf_path=graphics_paths.pdf_path
    )
end

function _component_visual_bounds(pc::PlacedTrailBlazerComponent)
    bbox = try
        bounds(pc.reference)
    catch
        nothing
    end

    if isnothing(bbox)
        pts = [hook.p for hook in values(pc.hooks)]
        center_pt = isempty(pts) ? umpt(pc.position_um[1], pc.position_um[2]) : Point(
            sum(point.x for point in pts) / length(pts),
            sum(point.y for point in pts) / length(pts)
        )
        return centered(Rectangle(140μm, 140μm), on_pt=center_pt)
    end

    cx = (bbox.ll.x + bbox.ur.x) / 2
    cy = (bbox.ll.y + bbox.ur.y) / 2
    halfw = max((bbox.ur.x - bbox.ll.x) / 2 + 25μm, 55μm)
    halfh = max((bbox.ur.y - bbox.ll.y) / 2 + 25μm, 55μm)
    return Rectangle(Point(cx - halfw, cy - halfh), Point(cx + halfw, cy + halfh))
end

function _write_placement_registry(path::AbstractString, placed::Dict{String, PlacedTrailBlazerComponent})
    data = Dict{String, Any}()
    for (name, pc) in sort(collect(placed); by=first)
        bbox = _component_visual_bounds(pc)
        center_pt = DeviceLayout.center(bbox)
        data[name] = Dict(
            "kind" => String(pc.kind),
            "position_um" => [pc.position_um[1], pc.position_um[2]],
            "orientation_deg" => pc.orientation_deg,
            "center_um" => [μm_number(center_pt.x), μm_number(center_pt.y)],
            "bounds_um" => Dict(
                "ll" => [μm_number(bbox.ll.x), μm_number(bbox.ll.y)],
                "ur" => [μm_number(bbox.ur.x), μm_number(bbox.ur.y)]
            )
        )
    end
    open(path, "w") do io
        JSON.print(io, data, 2)
        write(io, '\n')
    end
end

function _write_connectivity_registry(path::AbstractString, spec::TrailBlazerFullChipSpec, placed::Dict{String, PlacedTrailBlazerComponent}; route_filter=nothing)
    include_all = isnothing(route_filter)
    wanted = include_all ? Set{String}() : Set(String.(route_filter))
    routes_out = Any[]

    for route in spec.routes
        include_all || (route.name in wanted) || continue
        points = _route_points(route, placed)
        isempty(points) && continue
        path_length_um = 0.0
        for idx in 1:(length(points) - 1)
            path_length_um += Float64(_segment_length(points[idx], points[idx + 1]) / 1.0μm)
        end
        push!(routes_out, Dict(
            "name" => route.name,
            "kind" => String(route.kind),
            "start_component" => route.start_component,
            "start_hook" => String(route.start_hook),
            "end_component" => route.end_component,
            "end_hook" => String(route.end_hook),
            "path_length_um" => path_length_um,
            "points_um" => [[Float64(point.x / 1.0μm), Float64(point.y / 1.0μm)] for point in points]
        ))
    end

    open(path, "w") do io
        JSON.print(io, routes_out, 2)
        write(io, '\n')
    end
end

function _legend_items()
    return [
        ("qubit", TRAILBLAZER_COMPONENT_ROLE_LAYERS[:qubit]),
        ("launch", TRAILBLAZER_COMPONENT_ROLE_LAYERS[:launch]),
        ("open term", TRAILBLAZER_COMPONENT_ROLE_LAYERS[:open_termination]),
        ("short term", TRAILBLAZER_COMPONENT_ROLE_LAYERS[:short_termination]),
        ("IDC", TRAILBLAZER_COMPONENT_ROLE_LAYERS[:interdigital_cap]),
        ("bus route", TRAILBLAZER_ROUTE_ROLE_LAYERS[:bus]),
        ("readout route", TRAILBLAZER_ROUTE_ROLE_LAYERS[:readout]),
        ("control route", TRAILBLAZER_ROUTE_ROLE_LAYERS[:control]),
        ("Purcell route", TRAILBLAZER_ROUTE_ROLE_LAYERS[:purcell]),
    ]
end

function _add_inspection_legend!(cell::Cell, frame_bounds::Rectangle)
    base_x = frame_bounds.ll.x + 70μm
    base_y = frame_bounds.ur.y - 70μm
    text!(
        cell,
        "TrailBlazer placement review",
        Point(base_x, base_y),
        GDSMeta(TRAILBLAZER_INSPECTION_BASE_LAYERS[:label], 0);
        mag=1.2
    )

    row_y = base_y - 75μm
    for (label, layer) in _legend_items()
        render!(cell, Rectangle(Point(base_x, row_y - 14μm), Point(base_x + 26μm, row_y + 12μm)), GDSMeta(layer, 0))
        text!(
            cell,
            label,
            Point(base_x + 40μm, row_y + 8μm),
            GDSMeta(TRAILBLAZER_INSPECTION_BASE_LAYERS[:label], 0);
            mag=1.0
        )
        row_y -= 42μm
    end
end

function _inspection_cell(cell_name::AbstractString, layout::TrailBlazerLayoutBuild, spec::TrailBlazerFullChipSpec; route_filter=nothing)
    cell = Cell(cell_name, nm)
    render!(cell, layout.coordinate_system; map_meta=_trailblazer_inspection_base_meta)

    include_all = isnothing(route_filter)
    wanted = include_all ? Set{String}() : Set(String.(route_filter))
    for route in spec.routes
        include_all || (route.name in wanted) || continue
        points = _route_points(route, layout.placed)
        isempty(points) && continue
        layer = get(TRAILBLAZER_ROUTE_ROLE_LAYERS, route.kind, TRAILBLAZER_ROUTE_ROLE_LAYERS[:control])
        style = Paths.Trace(max(umcoord(route.trace_width_um), 10μm))
        _render_polyline_path!(cell, route.name * "_inspect", points, style, GDSMeta(layer, 0))
    end

    for (_, pc) in sort(collect(layout.placed); by=first)
        bbox = _component_visual_bounds(pc)
        layer = get(TRAILBLAZER_COMPONENT_ROLE_LAYERS, pc.kind, TRAILBLAZER_COMPONENT_ROLE_LAYERS[:component])
        render!(cell, bbox, GDSMeta(layer, 0))
        text!(
            cell,
            pc.name,
            Point(bbox.ll.x, bbox.ur.y + 18μm),
            GDSMeta(TRAILBLAZER_INSPECTION_BASE_LAYERS[:label], 0);
            mag=0.95
        )
    end

    _add_inspection_legend!(cell, bounds(cell))
    return cell
end

function _write_trailblazer_inspection_outputs(output_dir::AbstractString, layout::TrailBlazerLayoutBuild, spec::TrailBlazerFullChipSpec; route_filter=nothing, fullchip::Bool=false)
    placement_registry_path = joinpath(output_dir, "placement_registry.json")
    connectivity_path = joinpath(output_dir, "connectivity.json")
    _write_placement_registry(placement_registry_path, layout.placed)
    _write_connectivity_registry(connectivity_path, spec, layout.placed; route_filter=route_filter)

    cell = _inspection_cell(
        fullchip ? "trailblazer_fullchip_inspection" : "trailblazer_q1_slice_inspection",
        layout,
        spec;
        route_filter=route_filter
    )
    graphics_paths = _write_graphics_bundle(output_dir, "placement_graph", cell; fullchip=fullchip)
    return (;
        placement_registry_path,
        connectivity_path,
        placement_graph_svg_path=graphics_paths.svg_path,
        placement_graph_png_path=graphics_paths.png_path,
        placement_graph_pdf_path=graphics_paths.pdf_path
    )
end

function _reset_output_dirs(build_dir::AbstractString, results_dir::Union{Nothing, AbstractString}=nothing)
    mkpath(build_dir)
    rm(joinpath(build_dir, "work"); recursive=true, force=true)
    mkpath(joinpath(build_dir, "work"))
    !isnothing(results_dir) && mkpath(results_dir)
end

function _stage_trailblazer_sources(work_dir::AbstractString)
    isfile(TRAILBLAZER_SPEC_PATH) && cp(TRAILBLAZER_SPEC_PATH, joinpath(work_dir, basename(TRAILBLAZER_SPEC_PATH)); force=true)
    isfile(TRAILBLAZER_SOURCE_PATHS) && cp(TRAILBLAZER_SOURCE_PATHS, joinpath(work_dir, basename(TRAILBLAZER_SOURCE_PATHS)); force=true)
    isfile(TRAILBLAZER_NOTEBOOK_COPY) && cp(TRAILBLAZER_NOTEBOOK_COPY, joinpath(work_dir, basename(TRAILBLAZER_NOTEBOOK_COPY)); force=true)
    isfile(TRAILBLAZER_REFERENCE_GDS_COPY) && cp(TRAILBLAZER_REFERENCE_GDS_COPY, joinpath(work_dir, basename(TRAILBLAZER_REFERENCE_GDS_COPY)); force=true)
end

function build_fullchip(spec::TrailBlazerFullChipSpec; output_dir::AbstractString=TRAILBLAZER_FULLCHIP_BUILD_DIR, save_layout_graphics::Bool=true)
    _reset_output_dirs(output_dir)
    work_dir = joinpath(output_dir, "work")
    _stage_trailblazer_sources(work_dir)

    layout = _build_component_registry(spec)
    _render_selected_routes!(layout, spec)

    hooks_path = joinpath(output_dir, "hook_registry.json")
    outputs = _write_trailblazer_layout_outputs(
        output_dir,
        layout.coordinate_system,
        "trailblazer_fullchip";
        save_layout_graphics=save_layout_graphics,
        fullchip=true
    )
    inspection_outputs = _write_trailblazer_inspection_outputs(output_dir, layout, spec; fullchip=true)
    _serialize_hooks(hooks_path, layout.placed)

    return (; outputs..., inspection_outputs..., hooks_path, build_dir=output_dir)
end

const Q1_SLICE_COMPONENTS = [
    "Q_1",
    "Q_2",
    "Q_8",
    "Launch_Q_Read",
    "bridge_Q_out",
    "bridge_Q_in",
    "highC_PF_TL",
    "otg_PF",
    "readout1_short",
]

const Q1_SLICE_ROUTES = [
    "Bus_12",
    "Bus_81",
    "PF",
    "TL1",
    "TL2",
    "readout_res_1",
]

function _add_port_marker!(cs::CoordinateSystem, point::Point, width, index::Int)
    marker = centered(Rectangle(width, width), on_pt=point)
    meta = DeviceLayout.SemanticMeta(DeviceLayout.layer(LayerVocabulary.PORT), index=index)
    render!(cs, only_simulated(marker), meta)
end

function _slice_geometry(spec::TrailBlazerFullChipSpec)
    component_names = Set(Q1_SLICE_COMPONENTS)
    for route in spec.routes
        if route.name in Q1_SLICE_ROUTES
            push!(component_names, route.start_component)
            push!(component_names, route.end_component)
        end
    end

    layout = _build_component_registry(spec; component_filter=collect(component_names), lumped_qubits=["Q_1"])
    _render_selected_routes!(layout, spec; route_filter=Q1_SLICE_ROUTES)
    cs = layout.coordinate_system

    launch_hook = layout.placed["Launch_Q_Read"].hooks[:tie]
    short_hook = layout.placed["readout1_short"].hooks[:short]
    junction_hook = layout.placed["Q_1"].hooks[:junction]
    _add_port_marker!(cs, launch_hook.p, 30μm, 1)
    _add_port_marker!(cs, short_hook.p, 20μm, 2)

    sim_area = only(halo(bounds(cs), 0.8mm))
    chip_area = only(halo(bounds(cs), 0.9mm))
    render!(cs, sim_area, LayerVocabulary.SIMULATED_AREA)
    render!(cs, sim_area, LayerVocabulary.WRITEABLE_AREA)
    render!(cs, chip_area, LayerVocabulary.CHIP_AREA)
    return layout, launch_hook, short_hook, junction_hook
end

function _direction_vector(hook::Hook)
    return [Float64(cos(in_direction(hook))), Float64(sin(in_direction(hook))), 0.0]
end

function _slice_config(sm::SolidModel, launch_hook::Hook, short_hook::Hook, junction_hook::Hook, q1_inductance_h::Float64; solver_order::Int, results_dir::AbstractString, mesh_path::AbstractString)
    attrs = SolidModels.attributes(sm)
    lumped_attr = haskey(attrs, "lumped_element") ? attrs["lumped_element"] : attrs["lumped_element_1"]
    return Dict(
        "Problem" => Dict(
            "Type" => "Eigenmode",
            "Verbose" => 2,
            "Output" => results_dir
        ),
        "Model" => Dict(
            "Mesh" => mesh_path,
            "L0" => 1e-6,
            "Refinement" => Dict("MaxIts" => 0)
        ),
        "Domains" => Dict(
            "Materials" => [
                Dict("Attributes" => [attrs["vacuum"]], "Permeability" => 1.0, "Permittivity" => 1.0),
                Dict(
                    "Attributes" => [attrs["substrate"]],
                    "Permeability" => [0.99999975, 0.99999975, 0.99999979],
                    "Permittivity" => [9.3, 9.3, 11.5],
                    "LossTan" => [3.0e-5, 3.0e-5, 8.6e-5],
                    "MaterialAxes" => [[0.8, 0.6, 0.0], [-0.6, 0.8, 0.0], [0.0, 0.0, 1.0]]
                )
            ]
        ),
        "Boundaries" => Dict(
            "PEC" => Dict("Attributes" => [attrs["metal"]]),
            "Absorbing" => Dict("Attributes" => [attrs["exterior_boundary"]], "Order" => 1),
            "LumpedPort" => [
                Dict("Index" => 1, "Attributes" => [attrs["port_1"]], "R" => 50, "Direction" => _direction_vector(launch_hook)),
                Dict("Index" => 2, "Attributes" => [attrs["port_2"]], "R" => 50, "Direction" => _direction_vector(short_hook)),
                Dict("Index" => 3, "Attributes" => [lumped_attr], "L" => q1_inductance_h, "C" => 0.0, "Direction" => _direction_vector(junction_hook))
            ]
        ),
        "Solver" => Dict(
            "Order" => solver_order,
            "Eigenmode" => Dict("N" => 6, "Tol" => 1.0e-6, "Target" => 5.2, "Save" => 2),
            "Linear" => Dict("Type" => "Default", "Tol" => 1.0e-7, "MaxIts" => 500)
        )
    )
end

function _slice_postrender_ops(target::SolidModelTarget, cs::CoordinateSystem)
    _string_refs(x) =
        x isa AbstractString ? String[x] :
        (x isa Tuple || x isa Vector) ? reduce(vcat, (_string_refs(item) for item in x); init=String[]) :
        String[]

    fake_schematic = (; coordinate_system=cs)
    map_meta = DeviceLayout.SchematicDrivenLayout._map_meta_fn(target)
    available_groups = Set(filter(!isnothing, map_meta.(element_metadata(flatten(cs)))))
    extrusion_ops = Any[]
    for (layer_name, (thickness, dim)) in pairs(DeviceLayout.SchematicDrivenLayout.layer_extrusions_dz(target, fake_schematic))
        suffix = dim == 1 ? "" : "_extrusion"
        push!(extrusion_ops, (string(layer_name) * suffix, SolidModels.extrude_z!, (layer_name, thickness, dim)))
    end

    wave_ports = String[]
    for meta in element_metadata(cs)
        if DeviceLayout.layer(meta) in target.wave_port_layers
            layer_name = map_meta(meta)
            !isnothing(layer_name) && push!(wave_ports, layer_name)
        end
    end

    boundary_volumes = string.(target.bounding_layers) .* "_extrusion"
    intersection_ops = Any[]
    if !isempty(boundary_volumes)
        if length(boundary_volumes) == 1
            push!(intersection_ops, ("rendered_volume", SolidModels.restrict_to_volume!, (boundary_volumes[1],)))
            push!(intersection_ops, ("exterior_boundary", SolidModels.get_boundary, ("rendered_volume", 3)))
        else
            push!(intersection_ops, ("rendered_volume", SolidModels.union_geom!, boundary_volumes, 3))
            push!(intersection_ops, ("rendered_volume", SolidModels.restrict_to_volume!, ("rendered_volume",)))
            push!(intersection_ops, ("exterior_boundary", SolidModels.get_boundary, ("rendered_volume", 3)))
        end
        for wave_port in wave_ports
            push!(
                intersection_ops,
                (
                    "exterior_boundary",
                    SolidModels.difference_geom!,
                    ("exterior_boundary", wave_port, 2, 2),
                    :remove_object => true
                )
            )
        end
    end

    postrenderer = filter(target.postrenderer) do op
        op isa Tuple || return true
        refs = Set(_string_refs(op))
        has_bridge_refs = !isempty(intersect(refs, Set(["bridge", "bridge_base", "bridge_metal", "_shadow", "_shadow_bdy", "_foot", "_foot_bdy", "_leg", "_platform"])))
        has_port_ref = "port" in refs
        has_bridge_refs && !("bridge" in available_groups || "bridge_base" in available_groups) && return false
        has_port_ref && !("port" in available_groups) && return false
        return true
    end

    return vcat(extrusion_ops, postrenderer, intersection_ops)
end

function _render_slice_solidmodel!(sm::SolidModel, cs::CoordinateSystem, target::SolidModelTarget)
    render!(
        sm,
        cs;
        zmap=Base.Fix1(DeviceLayout.SchematicDrivenLayout.layer_z, target),
        postrender_ops=_slice_postrender_ops(target, cs),
        map_meta=DeviceLayout.SchematicDrivenLayout._map_meta_fn(target),
        retained_physical_groups=target.retained_physical_groups,
        target.rendering_options...
    )
end

function _slice_solidmodel(layout::TrailBlazerLayoutBuild; name::AbstractString="trailblazer_q1_slice", mesh_order::Int=2)
    sm = SolidModel(name, overwrite=true)
    SolidModels.set_gmsh_option("General.Verbosity", 1)
    SolidModels.mesh_order(mesh_order)
    target = ExamplePDK.singlechip_solidmodel_target("port_1", "port_2", "lumped_element_1")
    _render_slice_solidmodel!(sm, layout.coordinate_system, target)
    return sm
end

function inspect_slice_solidmodel(spec::TrailBlazerFullChipSpec, slice::Symbol=:q1_purcell; mesh_dim::Int=3, mesh_order::Int=2)
    slice == :q1_purcell || error("Only :q1_purcell is implemented in v1.")
    layout, _, _, _ = _slice_geometry(spec)
    sm = _slice_solidmodel(layout; name="trailblazer_q1_slice_live", mesh_order=mesh_order)
    SolidModels.gmsh.model.mesh.generate(mesh_dim)
    SolidModels.gmsh.fltk.run()
    return sm
end

function build_slice(spec::TrailBlazerFullChipSpec, slice::Symbol=:q1_purcell; solver_order::Int=1, output_dir::AbstractString=TRAILBLAZER_SLICE_BUILD_DIR, results_dir::AbstractString=TRAILBLAZER_SLICE_RESULTS_DIR, save_layout_graphics::Bool=true)
    slice == :q1_purcell || error("Only :q1_purcell is implemented in v1.")
    _reset_output_dirs(output_dir, results_dir)
    work_dir = joinpath(output_dir, "work")
    _stage_trailblazer_sources(work_dir)

    layout, launch_hook, short_hook, junction_hook = _slice_geometry(spec)
    hooks_path = joinpath(output_dir, "hook_registry.json")
    _serialize_hooks(hooks_path, layout.placed)

    mesh_path = joinpath(output_dir, "device.msh")
    config_path = joinpath(output_dir, "palace.json")

    sm = _slice_solidmodel(layout)

    SolidModels.gmsh.model.mesh.generate(3)
    SolidModels.set_gmsh_option("Mesh.MshFileVersion", 2.2)
    save(mesh_path, sm)

    outputs = _write_trailblazer_layout_outputs(
        output_dir,
        layout.coordinate_system,
        "trailblazer_q1_slice";
        save_layout_graphics=save_layout_graphics
    )
    inspection_outputs = _write_trailblazer_inspection_outputs(output_dir, layout, spec; route_filter=Q1_SLICE_ROUTES)

    q1 = only(filter(qubit -> qubit.name == "Q_1", spec.qubits))
    config = _slice_config(sm, launch_hook, short_hook, junction_hook, q1.hfss_inductance_nh * 1.0e-9; solver_order=solver_order, results_dir=results_dir, mesh_path=mesh_path)
    open(config_path, "w") do io
        JSON.print(io, config, 2)
        write(io, '\n')
    end

    return (; mesh_path, outputs..., inspection_outputs..., config_path, hooks_path, results_dir)
end
