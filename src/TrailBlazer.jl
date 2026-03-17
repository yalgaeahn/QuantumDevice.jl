const TRAILBLAZER_INPUT_DIR = joinpath(ROOT, "inputs", "qiskit-metal", "trailblazer-fullchip")
const TRAILBLAZER_SPEC_PATH = joinpath(TRAILBLAZER_INPUT_DIR, "trailblazer_fullchip_spec.json")
const TRAILBLAZER_SOURCE_PATHS = joinpath(TRAILBLAZER_INPUT_DIR, "source_paths.json")
const TRAILBLAZER_NOTEBOOK_COPY = joinpath(TRAILBLAZER_INPUT_DIR, "source_notebook.ipynb")
const TRAILBLAZER_REFERENCE_GDS_COPY = joinpath(TRAILBLAZER_INPUT_DIR, "reference_layout.gds")
const TRAILBLAZER_FULLCHIP_BUILD_DIR = joinpath(ROOT, "build", "trailblazer-fullchip")
const TRAILBLAZER_Q1_SLICE_BUILD_DIR = joinpath(ROOT, "build", "trailblazer-q1-local-context")
const TRAILBLAZER_Q1_SLICE_RESULTS_DIR = joinpath(ROOT, "results", "trailblazer-q1-local-context")

export TrailBlazerConnectorSpec
export TrailBlazerClawConnectorSpec
export TrailBlazerTeeConnectorSpec
export TrailBlazerQubitSpec
export TrailBlazerRouteSpec
export TrailBlazerFullChipSpec
export load_trailblazer_spec
export build_fullchip
export build_slice
export derive_slice_membership
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
    category::Symbol
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

struct TrailBlazerPlacementFrame{T,H} <: AbstractComponent{T}
    name::String
    placement_hooks::H
    _geometry::CoordinateSystem{T}
end

struct TrailBlazerResolvedRoute{T,S,M} <: AbstractComponent{T}
    name::String
    kind::Symbol
    points::Vector{Point{T}}
    p0_in_direction
    p1_in_direction
    style::S
    meta::M
    _geometry::CoordinateSystem{T}
end

struct TrailBlazerComponentPlacement
    name::String
    kind::Symbol
    position_um::NTuple{2, Float64}
    orientation_deg::Float64
    component::AbstractComponent
    hooks::Dict{Symbol, Hook}
end

struct TrailBlazerSchematicBuild{S}
    graph::SchematicGraph
    schematic::Schematic{S}
    frame_node::ComponentNode
    component_nodes::Dict{String, ComponentNode}
    route_nodes::Dict{String, ComponentNode}
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

source_graph_hidden(::TrailBlazerPlacementFrame) = true
source_graph_role(::TrailBlazerResolvedRoute) = :route

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

_origin_hook() = PointHook(0μm, 0μm, 180°)

function _namedtuple_from_pairs(pairs::AbstractVector{<:Pair})
    names = Tuple(first.(pairs))
    values = Tuple(last.(pairs))
    return NamedTuple{names}(values)
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
    push!(pairs, :origin => _origin_hook())
    push!(pairs, :junction => PointHook(0μm, 0μm, 90°))
    for connector in body.connection_pads
        _, _, hook = _connector_geometry(connector, body)
        push!(pairs, connector_name(connector) => hook)
    end
    return _namedtuple_from_pairs(pairs)
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
    return (; origin = _origin_hook(), tie = PointHook(Point(launch.lead_length, 0μm), 180°))
end

function SchematicDrivenLayout._geometry!(cs::CoordinateSystem, term::TrailBlazerOpenTermination)
    open_rect = tbrect(0μm, -(term.width / 2 + term.gap), term.termination_gap, term.width / 2 + term.gap)
    place!(cs, open_rect, LayerVocabulary.METAL_NEGATIVE)
    return cs
end

function SchematicDrivenLayout.hooks(term::TrailBlazerOpenTermination)
    return (; origin = _origin_hook(), open = PointHook(0μm, 0μm, 0°))
end

function SchematicDrivenLayout._geometry!(cs::CoordinateSystem, term::TrailBlazerShortTermination)
    return cs
end

function SchematicDrivenLayout.hooks(term::TrailBlazerShortTermination)
    return (; origin = _origin_hook(), short = PointHook(0μm, 0μm, 0°))
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
        origin = _origin_hook(),
        north_end = PointHook(Point(0μm, cap.taper_length), -90°),
        south_end = PointHook(
            Point(0μm, -cap.taper_length - 2 * cap.cap_distance - (cap.cap_gap + 2 * cap.cap_width + cap.finger_length)),
            90°
        )
    )
end

function SchematicDrivenLayout._geometry!(cs::CoordinateSystem, frame::TrailBlazerPlacementFrame)
    return cs
end

SchematicDrivenLayout.hooks(frame::TrailBlazerPlacementFrame) = frame.placement_hooks

function SchematicDrivenLayout._geometry!(cs::CoordinateSystem, route::TrailBlazerResolvedRoute)
    _render_polyline_path!(cs, route.name, route.points, route.style, route.meta)
    return cs
end

function SchematicDrivenLayout.hooks(route::TrailBlazerResolvedRoute)
    return (
        ;
        p0 = PointHook(first(route.points), route.p0_in_direction),
        p1 = PointHook(last(route.points), route.p1_in_direction),
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
                Symbol(item["category"]),
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
        routes
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

function _component_placement(component::AbstractComponent, pos_um::NTuple{2, Float64}, orientation_deg::Real)
    transform = _transform_for_pos(pos_um, orientation_deg)
    return TrailBlazerComponentPlacement(
        name(component),
        _component_kind(component),
        (Float64(pos_um[1]), Float64(pos_um[2])),
        Float64(orientation_deg),
        component,
        _global_hook_dict(component, transform)
    )
end

function _component_catalog(spec::TrailBlazerFullChipSpec; component_filter=nothing, lumped_qubits=nothing)
    include_all = isnothing(component_filter)
    wanted = include_all ? Set{String}() : Set(String.(component_filter))
    active_lumped_qubits =
        isnothing(lumped_qubits) ? Set(qubit.name for qubit in spec.qubits) : Set(String.(lumped_qubits))
    catalog = Dict{String, TrailBlazerComponentPlacement}()

    for qubit in spec.qubits
        include_all || (qubit.name in wanted) || continue
        junction_mode = qubit.name in active_lumped_qubits ? :lumped : :metal
        component = TrailBlazerPocketTransmon(qubit; junction_mode=junction_mode)
        catalog[qubit.name] = _component_placement(component, qubit.pos_um, qubit.orientation_deg)
    end
    for launch in spec.launches
        include_all || (launch.name in wanted) || continue
        component = TrailBlazerLaunchpad(launch)
        catalog[launch.name] = _component_placement(component, launch.pos_um, launch.orientation_deg)
    end
    for term in spec.open_terminations
        include_all || (term.name in wanted) || continue
        component = TrailBlazerOpenTermination(term)
        catalog[term.name] = _component_placement(component, term.pos_um, term.orientation_deg)
    end
    for term in spec.short_terminations
        include_all || (term.name in wanted) || continue
        component = TrailBlazerShortTermination(term)
        catalog[term.name] = _component_placement(component, term.pos_um, term.orientation_deg)
    end
    for cap in spec.interdigital_caps
        include_all || (cap.name in wanted) || continue
        component = TrailBlazerInterdigitalCap(cap)
        catalog[cap.name] = _component_placement(component, cap.pos_um, cap.orientation_deg)
    end

    return catalog
end

function _placement_frame(name::AbstractString, catalog::Dict{String, TrailBlazerComponentPlacement})
    pairs = Pair{Symbol, Hook}[]
    for (component_name, placement) in sort(collect(catalog); by=first)
        push!(
            pairs,
            Symbol(component_name) => PointHook(
                umpt(placement.position_um[1], placement.position_um[2]),
                placement.orientation_deg * 1.0°
            )
        )
    end
    return TrailBlazerPlacementFrame(
        String(name),
        _namedtuple_from_pairs(pairs),
        CoordinateSystem{typeof(1.0μm)}(String(name))
    )
end

function _filtered_route_specs(spec::TrailBlazerFullChipSpec; route_filter=nothing)
    if isnothing(route_filter)
        return spec.routes
    end
    wanted = Set(String.(route_filter))
    return [route for route in spec.routes if route.name in wanted]
end

function _normalize_slice_target(target)
    if target isa Symbol
        target == :q1_purcell && return "Q_1"
        target == Symbol("Q_1") && return "Q_1"
        startswith(String(target), "Q_") && return String(target)
    elseif target isa AbstractString
        target == "q1_purcell" && return "Q_1"
        startswith(target, "Q_") && return String(target)
    end
    error("Expected a target qubit like \"Q_1\"; got $(repr(target)).")
end

function _slice_shortname(target_qubit::AbstractString)
    match = Base.match(r"^Q_(\d+)$", target_qubit)
    isnothing(match) && error("Expected a target qubit like \"Q_1\"; got $(repr(target_qubit)).")
    return "q" * only(match.captures)
end

_slice_output_name(target_qubit::AbstractString) = "trailblazer-" * _slice_shortname(target_qubit) * "-local-context"
_slice_graph_name(target_qubit::AbstractString) = "trailblazer_" * _slice_shortname(target_qubit) * "_local_context"
_slice_cell_name(target_qubit::AbstractString) = "trailblazer_" * _slice_shortname(target_qubit) * "_slice"
_slice_live_name(target_qubit::AbstractString) = "trailblazer_" * _slice_shortname(target_qubit) * "_slice_live"
_slice_build_dir(target_qubit::AbstractString) = joinpath(ROOT, "build", _slice_output_name(target_qubit))
_slice_results_dir(target_qubit::AbstractString) = joinpath(ROOT, "results", _slice_output_name(target_qubit))

function _qubit_names(spec::TrailBlazerFullChipSpec)
    return Set(qubit.name for qubit in spec.qubits)
end

function _component_kind_map(spec::TrailBlazerFullChipSpec)
    kinds = Dict{String, Symbol}()
    for qubit in spec.qubits
        kinds[qubit.name] = :qubit
    end
    for launch in spec.launches
        kinds[launch.name] = :launch
    end
    for term in spec.open_terminations
        kinds[term.name] = :open_termination
    end
    for term in spec.short_terminations
        kinds[term.name] = :short_termination
    end
    for cap in spec.interdigital_caps
        kinds[cap.name] = :interdigital_cap
    end
    return kinds
end

function _component_route_adjacency(spec::TrailBlazerFullChipSpec)
    adjacency = Dict{String, Vector{TrailBlazerRouteSpec{Float64}}}()
    for route in spec.routes
        push!(get!(adjacency, route.start_component, TrailBlazerRouteSpec{Float64}[]), route)
        push!(get!(adjacency, route.end_component, TrailBlazerRouteSpec{Float64}[]), route)
    end
    return adjacency
end

function _route_peer(route::TrailBlazerRouteSpec, component_name::AbstractString)
    component_name == route.start_component && return route.end_component
    component_name == route.end_component && return route.start_component
    error("Route $(route.name) is not incident to component $(component_name).")
end

function _primary_readout_route(spec::TrailBlazerFullChipSpec, target_qubit::AbstractString)
    for route in spec.routes
        route.category == :readout || continue
        (route.start_component == target_qubit || route.end_component == target_qubit) && return route
    end
    error("No readout route found for $(target_qubit).")
end

function derive_slice_membership(
    spec::TrailBlazerFullChipSpec,
    target;
    include_bus_neighbors::Bool=true,
    include_readout::Bool=true,
    include_control::Bool=false,
    include_purcell_if_connected::Bool=true
)
    target_qubit = _normalize_slice_target(target)
    target_qubit in _qubit_names(spec) || error("Unknown TrailBlazer target qubit $(repr(target_qubit)).")

    adjacency = _component_route_adjacency(spec)
    component_names = Set([target_qubit])
    route_names = Set{String}()

    for route in get(adjacency, target_qubit, TrailBlazerRouteSpec{Float64}[])
        if route.category == :readout && include_readout
            push!(route_names, route.name)
            push!(component_names, _route_peer(route, target_qubit))
        elseif route.category == :bus && include_bus_neighbors
            push!(route_names, route.name)
            push!(component_names, _route_peer(route, target_qubit))
        elseif route.category == :control && include_control
            push!(route_names, route.name)
            push!(component_names, _route_peer(route, target_qubit))
        end
    end

    if include_purcell_if_connected
        changed = true
        while changed
            changed = false
            for route in spec.routes
                route.category == :purcell || continue
                route.name in route_names && continue
                if route.start_component in component_names || route.end_component in component_names
                    push!(route_names, route.name)
                    push!(component_names, route.start_component)
                    push!(component_names, route.end_component)
                    changed = true
                end
            end
        end
    end

    kind_map = _component_kind_map(spec)
    degree = Dict(name => 0 for name in component_names)
    for route in spec.routes
        route.name in route_names || continue
        degree[route.start_component] = get(degree, route.start_component, 0) + 1
        degree[route.end_component] = get(degree, route.end_component, 0) + 1
    end

    primary_readout_route = _primary_readout_route(spec, target_qubit)
    primary_readout_component = _route_peer(primary_readout_route, target_qubit)
    external_port_components = String[]
    if primary_readout_component in component_names
        push!(external_port_components, primary_readout_component)
    end
    additional = sort([
        name for name in component_names
        if name != primary_readout_component &&
            get(kind_map, name, :component) in (:launch, :open_termination, :short_termination) &&
            get(degree, name, 0) == 1
    ])
    append!(external_port_components, additional)

    return (
        target_qubit=target_qubit,
        context=:local_bus,
        component_names=sort!(collect(component_names)),
        route_names=sort!(collect(route_names)),
        external_port_components=external_port_components
    )
end

function _global_route_points(route::TrailBlazerRouteSpec, start_hook::Hook, end_hook::Hook)
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

function _global_route_waypoints(route::TrailBlazerRouteSpec, start_hook::Hook, end_hook::Hook)
    if !isempty(route.resolved_waypoints_um)
        return [umpt(x, y) for (x, y) in route.resolved_waypoints_um]
    end
    points = _global_route_points(route, start_hook, end_hook)
    length(points) <= 2 && return Point{typeof(start_hook.p.x)}[]
    return collect(points[2:(end - 1)])
end

function _route_rule(route::TrailBlazerRouteSpec)
    return Paths.StraightAnd90(_bend_radius(route))
end

function _route_prefix_state(route::TrailBlazerRouteSpec, start_hook::Hook, end_hook::Hook)
    start_anchor = route.lead_start_straight_um > 0 ? _lead_anchor(start_hook, route.lead_start_straight_um, true) : start_hook.p
    start_direction = out_direction(start_hook)
    jog_points, jog_direction = _jog_waypoints(start_anchor, start_direction, route.start_jogs)
    end_anchor = route.lead_end_straight_um > 0 ? _lead_anchor(end_hook, route.lead_end_straight_um, false) : end_hook.p
    meander_start = isempty(jog_points) ? start_anchor : last(jog_points)
    return start_anchor, jog_points, jog_direction, meander_start, end_anchor
end

function _meander_segment_count(start_point::Point, end_point::Point, route::TrailBlazerRouteSpec)
    spacing_um = isnothing(route.meander_spacing_um) ? 200.0 : route.meander_spacing_um
    spacing = max(umcoord(spacing_um), 1.0μm)
    direct = max(abs(end_point.x - start_point.x), abs(end_point.y - start_point.y))
    return max(1, Int(floor(Float64(direct / spacing) / 2)))
end

function _meander_offset(route::TrailBlazerRouteSpec)
    isnothing(route.meander_asymmetry_um) && return 0.0
    total = isnothing(route.total_length_um) ? 1.0 : max(route.total_length_um, 1.0)
    return clamp(route.meander_asymmetry_um / total, -0.45, 0.45)
end

function _orthogonal_meander_points(start_point::Point, end_point::Point, route::TrailBlazerRouteSpec)
    spacing_um = isnothing(route.meander_spacing_um) ? 200.0 : route.meander_spacing_um
    spacing = max(umcoord(spacing_um), 1.0μm)
    dx = end_point.x - start_point.x
    dy = end_point.y - start_point.y
    horizontal = abs(dx) >= abs(dy)
    primary = horizontal ? abs(dx) : abs(dy)
    secondary = horizontal ? abs(dy) : abs(dx)
    count = max(2, Int(floor(Float64(primary / spacing))))
    total_length = isnothing(route.total_length_um) ? (primary + secondary) : umcoord(route.total_length_um)
    available_extra = max(total_length - primary - secondary, zero(primary))
    base_amplitude = max(spacing / 2, available_extra / (2 * max(count - 1, 1)))
    asymmetry = isnothing(route.meander_asymmetry_um) ? zero(base_amplitude) : abs(umcoord(route.meander_asymmetry_um)) / 2
    positive_amplitude = base_amplitude + asymmetry
    negative_amplitude = max(spacing / 2, base_amplitude - asymmetry)

    points = Point[start_point]
    current = start_point
    if horizontal
        sign_secondary = dy >= zero(dy) ? 1 : -1
        for idx in 1:(count - 1)
            x = start_point.x + dx * idx / count
            base_y = start_point.y + dy * idx / count
            amplitude = isodd(idx) ? positive_amplitude : -negative_amplitude
            target_y = base_y + sign_secondary * amplitude
            corner1 = Point(x, current.y)
            !_same_point(corner1, current) && push!(points, corner1)
            current = points[end]
            corner2 = Point(x, target_y)
            !_same_point(corner2, current) && push!(points, corner2)
            current = points[end]
        end
        corner = Point(end_point.x, current.y)
        !_same_point(corner, current) && push!(points, corner)
    else
        sign_secondary = dx >= zero(dx) ? 1 : -1
        for idx in 1:(count - 1)
            y = start_point.y + dy * idx / count
            base_x = start_point.x + dx * idx / count
            amplitude = isodd(idx) ? positive_amplitude : -negative_amplitude
            target_x = base_x + sign_secondary * amplitude
            corner1 = Point(current.x, y)
            !_same_point(corner1, current) && push!(points, corner1)
            current = points[end]
            corner2 = Point(target_x, y)
            !_same_point(corner2, current) && push!(points, corner2)
            current = points[end]
        end
        corner = Point(current.x, end_point.y)
        !_same_point(corner, current) && push!(points, corner)
    end
    !_same_point(points[end], end_point) && push!(points, end_point)
    return points
end

function _assemble_trailblazer_graph!(
    g::SchematicGraph,
    spec::TrailBlazerFullChipSpec;
    component_filter=nothing,
    route_filter=nothing,
    lumped_qubits=nothing
)
    catalog = _component_catalog(spec; component_filter=component_filter, lumped_qubits=lumped_qubits)
    frame = _placement_frame(name(g) * "_placement", catalog)
    frame_node = add_node!(g, frame; base_id=frame.name)

    component_nodes = Dict{String, ComponentNode}()
    for (component_name, placement) in sort(collect(catalog); by=first)
        node = add_node!(g, placement.component; base_id=component_name)
        component_nodes[component_name] = node
        fuse!(g, frame_node => Symbol(component_name), node => :origin)
    end

    route_nodes = Dict{String, ComponentNode}()
    for route in _filtered_route_specs(spec; route_filter=route_filter)
        haskey(component_nodes, route.start_component) || continue
        haskey(component_nodes, route.end_component) || continue
        start_hook = catalog[route.start_component].hooks[route.start_hook]
        end_hook = catalog[route.end_component].hooks[route.end_hook]
        route_node = route!(
            g,
            _route_rule(route),
            component_nodes[route.start_component] => route.start_hook,
            component_nodes[route.end_component] => route.end_hook,
            _style(route),
            LayerVocabulary.METAL_NEGATIVE;
            name=route.name,
            waypoints=_global_route_waypoints(route, start_hook, end_hook),
            global_waypoints=true,
            route_kind=String(route.kind),
            route_category=String(route.category),
            fillet_um=Float64(route.fillet_um),
            resolved_waypoint_count=length(route.resolved_waypoints_um)
        )
        route_component = component(route_node)
        route_path = _route_component_path(route, start_hook, end_hook)
        !isnothing(route_path) && (route_component._path = route_path)
        route_nodes[route.name] = route_node
    end

    return (; frame_node, component_nodes, route_nodes)
end

function _plan_trailblazer_schematic(
    spec::TrailBlazerFullChipSpec;
    graph_name::AbstractString,
    log_dir::AbstractString,
    component_filter=nothing,
    route_filter=nothing,
    lumped_qubits=nothing
)
    reset_uniquename!()
    graph = SchematicGraph(String(graph_name))
    assembled = _assemble_trailblazer_graph!(
        graph,
        spec;
        component_filter=component_filter,
        route_filter=route_filter,
        lumped_qubits=lumped_qubits
    )
    schematic = plan(graph; log_dir=log_dir)
    check!(schematic)
    return TrailBlazerSchematicBuild(
        graph,
        schematic,
        assembled.frame_node,
        assembled.component_nodes,
        assembled.route_nodes
    )
end

function _schematic_component_hooks(build::TrailBlazerSchematicBuild)
    out = Dict{String, Dict{Symbol, Hook}}()
    for (component_name, node) in sort(collect(build.component_nodes); by=first)
        hook_dict = Dict{Symbol, Hook}()
        for (hook_name, hook) in pairs(hooks(build.schematic, node))
            hook_dict[hook_name] = hook
        end
        out[component_name] = hook_dict
    end
    return out
end

function _serialize_schematic_hooks(path::AbstractString, build::TrailBlazerSchematicBuild)
    data = Dict{String, Any}()
    for (component_name, hook_dict) in _schematic_component_hooks(build)
        hooks_out = Dict{String, Any}()
        for (hook_name, hook) in hook_dict
            hooks_out[String(hook_name)] = Dict(
                "point_um" => [_μm_value(hook.p.x), _μm_value(hook.p.y)],
                "in_direction_deg" => Float64(in_direction(hook) / 1.0°)
            )
        end
        data[component_name] = hooks_out
    end
    open(path, "w") do io
        JSON.print(io, data, 2)
        write(io, '\n')
    end
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

function _filtered_points(points::AbstractVector{<:Point})
    filtered = Point[]
    for point in points
        isempty(filtered) || _same_point(filtered[end], point) || push!(filtered, point)
        isempty(filtered) && push!(filtered, point)
    end
    return filtered
end

function _sanitize_polyline_points(points::Vector{<:Point}, bend_radius)
    length(points) <= 2 && return points
    filtered = copy(points)
    changed = true
    while changed && length(filtered) > 2
        changed = false
        for idx in 2:(length(filtered) - 1)
            prev = filtered[idx - 1]
            curr = filtered[idx]
            nxt = filtered[idx + 1]
            len_prev = _segment_length(prev, curr)
            len_next = _segment_length(curr, nxt)
            dα = abs(Float64(_normalized_turn(_segment_angle(curr, nxt), _segment_angle(prev, curr)) / 1.0°))
            is_short = min(len_prev, len_next) < bend_radius
            is_near_uturn = dα > 165.0
            if is_short && is_near_uturn
                deleteat!(filtered, idx)
                changed = true
                break
            end
        end
    end
    return filtered
end

function _polyline_path(path_name::AbstractString, points::AbstractVector{<:Point}, style, meta; bend_radius=0.0μm)
    filtered = _sanitize_polyline_points(_filtered_points(points), bend_radius)
    length(filtered) < 2 && return nothing

    segment_directions = [_segment_angle(filtered[idx], filtered[idx + 1]) for idx in 1:(length(filtered) - 1)]
    segment_lengths = [_segment_length(filtered[idx], filtered[idx + 1]) for idx in 1:(length(filtered) - 1)]
    path = Path(filtered[1]; α0=segment_directions[1], name=path_name, metadata=meta)

    if length(filtered) == 2
        straight!(path, segment_lengths[1], style)
        return path
    end

    n_corners = length(filtered) - 2
    trims = [zero(segment_lengths[1]) for _ in 1:n_corners]
    turn_angles = fill(0.0°, n_corners)
    tan_halves = zeros(Float64, n_corners)

    for corner_idx in 1:n_corners
        dα = _normalized_turn(segment_directions[corner_idx + 1], segment_directions[corner_idx])
        turn_angles[corner_idx] = dα
        abs(Float64(dα / 1.0°)) <= 1.0e-6 && continue
        tan_half = abs(tan(Float64(dα / 1.0°) * pi / 360.0))
        tan_half <= 1.0e-12 && continue
        tan_halves[corner_idx] = tan_half
        trims[corner_idx] = bend_radius * tan_half
    end

    scale_factors = ones(Float64, n_corners)
    for seg_idx in 1:length(segment_lengths)
        left_corner = seg_idx - 1
        right_corner = seg_idx
        trim_total = zero(segment_lengths[seg_idx])
        if left_corner >= 1
            trim_total += trims[left_corner]
        end
        if right_corner <= n_corners
            trim_total += trims[right_corner]
        end
        trim_total > segment_lengths[seg_idx] || continue
        scale = Float64((0.98 * segment_lengths[seg_idx]) / trim_total)
        left_corner >= 1 && (scale_factors[left_corner] = min(scale_factors[left_corner], scale))
        right_corner <= n_corners && (scale_factors[right_corner] = min(scale_factors[right_corner], scale))
    end
    for corner_idx in 1:n_corners
        trims[corner_idx] *= scale_factors[corner_idx]
    end

    for seg_idx in 1:length(segment_lengths)
        trim_start = seg_idx > 1 ? trims[seg_idx - 1] : zero(segment_lengths[seg_idx])
        trim_end = seg_idx <= n_corners ? trims[seg_idx] : zero(segment_lengths[seg_idx])
        straight_length = segment_lengths[seg_idx] - trim_start - trim_end
        straight_length > 1.0e-9 * oneunit(straight_length) && straight!(path, straight_length, style)
        if seg_idx <= n_corners && tan_halves[seg_idx] > 1.0e-12 && trims[seg_idx] > zero(trims[seg_idx])
            turn_radius = trims[seg_idx] / tan_halves[seg_idx]
            turn!(path, turn_angles[seg_idx], turn_radius, style)
        end
    end
    return path
end

function _render_polyline_path!(cs, path_name::AbstractString, points::AbstractVector{<:Point}, style, meta; bend_radius=0.0μm)
    path = _polyline_path(path_name, points, style, meta; bend_radius=bend_radius)
    isnothing(path) && return
    render!(cs, path)
end

function _render_polyline_route!(cs::CoordinateSystem, route::TrailBlazerRouteSpec, style, points::AbstractVector{<:Point})
    return _render_polyline_path!(cs, route.name, points, style, LayerVocabulary.METAL_NEGATIVE; bend_radius=_bend_radius(route))
end

function _route_component_path(route::TrailBlazerRouteSpec, start_hook::Hook, end_hook::Hook)
    if route.kind == :meander && !isnothing(route.total_length_um)
        bend_radius = _bend_radius(route)
        start_anchor, jog_points, _, meander_start, end_anchor = _route_prefix_state(route, start_hook, end_hook)
        points = Point[start_hook.p]
        !_same_point(start_anchor, start_hook.p) && push!(points, start_anchor)
        append!(points, jog_points)
        meander_points = _orthogonal_meander_points(meander_start, end_anchor, route)
        append!(points, meander_points[2:end])
        !_same_point(points[end], end_hook.p) && push!(points, end_hook.p)
        return _polyline_path(route.name, points, _style(route), LayerVocabulary.METAL_NEGATIVE; bend_radius=bend_radius)
    end

    return _polyline_path(
        route.name,
        _global_route_points(route, start_hook, end_hook),
        _style(route),
        LayerVocabulary.METAL_NEGATIVE;
        bend_radius=_bend_radius(route)
    )
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

function _trailblazer_qiskit_gds_meta(meta)
    meta isa GDSMeta && return meta
    meta == LayerVocabulary.METAL_POSITIVE && return GDSMeta(1, 10)
    meta == LayerVocabulary.METAL_NEGATIVE && return GDSMeta(1, 100)
    meta == LayerVocabulary.JUNCTION_PATTERN && return GDSMeta(1, 10)
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

function _trailblazer_chip_geometry(spec::TrailBlazerFullChipSpec)
    return centered(
        Rectangle(umcoord(spec.chip_size_um[1]), umcoord(spec.chip_size_um[2])),
        on_pt=umpt(spec.chip_center_um[1], spec.chip_center_um[2])
    )
end

function _trailblazer_layout_cell(name::AbstractString, schematic::Schematic; graphics::Bool=false)
    build!(schematic)
    cell = Cell(name, nm)
    render!(
        cell,
        schematic.coordinate_system;
        map_meta=graphics ? _trailblazer_graphics_meta : _trailblazer_map_meta
    )
    flatten!(cell)
    return cell
end

function _trailblazer_qiskit_gds_cell(
    name::AbstractString,
    schematic::Schematic,
    spec::TrailBlazerFullChipSpec;
    fullchip::Bool=false
)
    build!(schematic)
    cell = Cell(name, nm)
    render!(cell, schematic.coordinate_system; map_meta=_trailblazer_qiskit_gds_meta)
    fullchip && render!(cell, _trailblazer_chip_geometry(spec), GDSMeta(1, 100))
    flatten!(cell)
    return cell
end

function _route_min_bend_radius_um(rule)
    hasproperty(rule, :min_bend_radius) || return nothing
    return _μm_value(getproperty(rule, :min_bend_radius))
end

function _serialize_route_registry(path::AbstractString, build::TrailBlazerSchematicBuild, spec::TrailBlazerFullChipSpec)
    spec_routes = Dict(route.name => route for route in spec.routes)
    data = Dict{String, Any}()
    for (route_name, node) in sort(collect(build.route_nodes); by=first)
        route_component = component(node)
        spec_route = spec_routes[route_name]
        data[route_name] = Dict(
            "component_type" => string(typeof(route_component)),
            "rule_type" => string(typeof(route_component.r.rule)),
            "route_kind" => String(spec_route.kind),
            "route_category" => String(spec_route.category),
            "global_waypoints" => route_component.global_waypoints,
            "global_waypoint_count" => length(route_component.r.waypoints),
            "global_waypoints_um" => [[_μm_value(point.x), _μm_value(point.y)] for point in route_component.r.waypoints],
            "resolved_waypoint_count" => length(spec_route.resolved_waypoints_um),
            "min_bend_radius_um" => _route_min_bend_radius_um(route_component.r.rule),
        )
    end
    open(path, "w") do io
        JSON.print(io, data, 2)
        write(io, '\n')
    end
end

function _write_trailblazer_contract_outputs(
    output_dir::AbstractString,
    schematic::Schematic,
    spec::TrailBlazerFullChipSpec,
    cell_name::AbstractString;
    save_layout_graphics::Bool=true,
    fullchip::Bool=false
)
    graph_svg_path = joinpath(output_dir, "schematic_graph.svg")
    write_schematic_graph_svg(graph_svg_path, schematic)

    gds_path = joinpath(output_dir, "device.gds")
    save(gds_path, _trailblazer_qiskit_gds_cell(cell_name, schematic, spec; fullchip=fullchip); userunit=1.0mm)

    layout_svg_path = nothing
    if save_layout_graphics
        graphics_cell = _trailblazer_layout_cell(cell_name * "_layout", schematic; graphics=true)
        layout_svg_path = joinpath(output_dir, "layout.svg")
        write_layout_svg(
            layout_svg_path,
            graphics_cell;
            options=_trailblazer_layout_graphics_options(; fullchip=fullchip)
        )
    end

    return (; gds_path, graph_svg_path, layout_svg_path)
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
    build = _plan_trailblazer_schematic(spec; graph_name="trailblazer_fullchip", log_dir=work_dir)
    render!(build.schematic.coordinate_system, _trailblazer_chip_geometry(spec), LayerVocabulary.CHIP_AREA)
    hooks_path = joinpath(output_dir, "hook_registry.json")
    route_registry_path = joinpath(output_dir, "route_registry.json")
    outputs = _write_trailblazer_contract_outputs(
        output_dir,
        build.schematic,
        spec,
        "trailblazer_fullchip";
        save_layout_graphics=save_layout_graphics,
        fullchip=true
    )
    _serialize_schematic_hooks(hooks_path, build)
    _serialize_route_registry(route_registry_path, build, spec)

    return (; outputs..., hooks_path, route_registry_path, build_dir=output_dir)
end

function _add_port_marker!(cs::CoordinateSystem, point::Point, width, index::Int)
    marker = centered(Rectangle(width, width), on_pt=point)
    meta = DeviceLayout.SemanticMeta(DeviceLayout.layer(LayerVocabulary.PORT), index=index)
    render!(cs, only_simulated(marker), meta)
end

function _preferred_port_hook_name(kind::Symbol)
    kind == :launch && return :tie
    kind == :open_termination && return :open
    kind == :short_termination && return :short
    return nothing
end

_port_marker_width(kind::Symbol) = kind == :launch ? 30μm : 20μm

function _slice_port_specs(build::TrailBlazerSchematicBuild, spec::TrailBlazerFullChipSpec, membership)
    kind_map = _component_kind_map(spec)
    hook_map = _schematic_component_hooks(build)
    port_specs = NamedTuple[]
    for (index, component_name) in enumerate(membership.external_port_components)
        component_hooks = hook_map[component_name]
        kind = get(kind_map, component_name, :component)
        preferred = _preferred_port_hook_name(kind)
        hook_name = if !isnothing(preferred) && haskey(component_hooks, preferred)
            preferred
        else
            first(sort!(collect(keys(component_hooks)); by=string))
        end
        push!(
            port_specs,
            (
                index=index,
                group_name="port_$(index)",
                component_name=component_name,
                hook_name=hook_name,
                hook=component_hooks[hook_name],
                kind=kind
            )
        )
    end
    return port_specs, hook_map
end

function _write_slice_membership(path::AbstractString, membership, port_specs)
    data = Dict(
        "target_qubit" => membership.target_qubit,
        "context" => String(membership.context),
        "component_names" => membership.component_names,
        "route_names" => membership.route_names,
        "external_port_components" => membership.external_port_components,
        "external_ports" => [
            Dict(
                "index" => port.index,
                "group_name" => port.group_name,
                "component_name" => port.component_name,
                "hook_name" => String(port.hook_name)
            ) for port in port_specs
        ],
    )
    open(path, "w") do io
        JSON.print(io, data, 2)
        write(io, '\n')
    end
    return path
end

function _direction_vector(hook::Hook)
    return [Float64(cos(in_direction(hook))), Float64(sin(in_direction(hook))), 0.0]
end

function _slice_schematic_build(spec::TrailBlazerFullChipSpec, target_qubit::AbstractString; log_dir::AbstractString)
    membership = derive_slice_membership(spec, target_qubit)
    build = _plan_trailblazer_schematic(
        spec;
        graph_name=_slice_graph_name(target_qubit),
        log_dir=log_dir,
        component_filter=membership.component_names,
        route_filter=membership.route_names,
        lumped_qubits=[target_qubit]
    )
    cs = build.schematic.coordinate_system
    port_specs, hook_map = _slice_port_specs(build, spec, membership)
    junction_hook = hook_map[target_qubit][:junction]

    for port in port_specs
        _add_port_marker!(cs, port.hook.p, _port_marker_width(port.kind), port.index)
    end

    sim_area = only(halo(bounds(cs), 0.8mm))
    chip_area = only(halo(bounds(cs), 0.9mm))
    render!(cs, sim_area, LayerVocabulary.SIMULATED_AREA)
    render!(cs, sim_area, LayerVocabulary.WRITEABLE_AREA)
    render!(cs, chip_area, LayerVocabulary.CHIP_AREA)
    return membership, build, port_specs, junction_hook
end

function _slice_config(
    sm::SolidModel,
    port_specs,
    junction_hook::Hook,
    qubit_inductance_h::Float64;
    solver_order::Int,
    results_dir::AbstractString,
    mesh_path::AbstractString
)
    attrs = SolidModels.attributes(sm)
    lumped_attr = haskey(attrs, "lumped_element") ? attrs["lumped_element"] : attrs["lumped_element_1"]
    lumped_ports = Any[
        Dict(
            "Index" => port.index,
            "Attributes" => [attrs[port.group_name]],
            "R" => 50,
            "Direction" => _direction_vector(port.hook)
        ) for port in port_specs
    ]
    push!(
        lumped_ports,
        Dict(
            "Index" => length(port_specs) + 1,
            "Attributes" => [lumped_attr],
            "L" => qubit_inductance_h,
            "C" => 0.0,
            "Direction" => _direction_vector(junction_hook)
        )
    )
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
            "LumpedPort" => lumped_ports
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

function _slice_solidmodel(cs::CoordinateSystem; name::AbstractString="trailblazer_q1_slice", mesh_order::Int=2, boundary_groups::Vector{String}=String[])
    sm = SolidModel(name, overwrite=true)
    SolidModels.set_gmsh_option("General.Verbosity", 1)
    SolidModels.mesh_order(mesh_order)
    target = ExamplePDK.singlechip_solidmodel_target(vcat(boundary_groups, ["lumped_element_1"]))
    _render_slice_solidmodel!(sm, cs, target)
    return sm
end

function inspect_slice_solidmodel(spec::TrailBlazerFullChipSpec, target="Q_1"; mesh_dim::Int=3, mesh_order::Int=2, context::Symbol=:local_bus)
    context == :local_bus || error("Only :local_bus is implemented in v1.")
    target_qubit = _normalize_slice_target(target)
    membership, build, port_specs, _ = _slice_schematic_build(spec, target_qubit; log_dir=mktempdir())
    sm = _slice_solidmodel(
        build.schematic.coordinate_system;
        name=_slice_live_name(target_qubit),
        mesh_order=mesh_order,
        boundary_groups=[port.group_name for port in port_specs]
    )
    SolidModels.gmsh.model.mesh.generate(mesh_dim)
    SolidModels.gmsh.fltk.run()
    return sm
end

function build_slice(
    spec::TrailBlazerFullChipSpec,
    target="Q_1";
    solver_order::Int=1,
    context::Symbol=:local_bus,
    output_dir::Union{Nothing, AbstractString}=nothing,
    results_dir::Union{Nothing, AbstractString}=nothing,
    save_layout_graphics::Bool=true
)
    context == :local_bus || error("Only :local_bus is implemented in v1.")
    target_qubit = _normalize_slice_target(target)
    output_dir = isnothing(output_dir) ? _slice_build_dir(target_qubit) : String(output_dir)
    results_dir = isnothing(results_dir) ? _slice_results_dir(target_qubit) : String(results_dir)
    _reset_output_dirs(output_dir, results_dir)
    work_dir = joinpath(output_dir, "work")
    _stage_trailblazer_sources(work_dir)

    membership, build, port_specs, junction_hook = _slice_schematic_build(spec, target_qubit; log_dir=work_dir)
    hooks_path = joinpath(output_dir, "hook_registry.json")
    route_registry_path = joinpath(output_dir, "route_registry.json")
    membership_path = joinpath(output_dir, "slice_membership.json")
    _serialize_schematic_hooks(hooks_path, build)
    _serialize_route_registry(route_registry_path, build, spec)
    _write_slice_membership(membership_path, membership, port_specs)

    mesh_path = joinpath(output_dir, "device.msh")
    config_path = joinpath(output_dir, "palace.json")

    sm = _slice_solidmodel(
        build.schematic.coordinate_system;
        name=_slice_cell_name(target_qubit),
        boundary_groups=[port.group_name for port in port_specs]
    )

    SolidModels.gmsh.model.mesh.generate(3)
    SolidModels.set_gmsh_option("Mesh.MshFileVersion", 2.2)
    save(mesh_path, sm)

    outputs = _write_trailblazer_contract_outputs(
        output_dir,
        build.schematic,
        spec,
        _slice_cell_name(target_qubit);
        save_layout_graphics=save_layout_graphics
    )

    qubit = only(filter(qubit -> qubit.name == target_qubit, spec.qubits))
    config = _slice_config(
        sm,
        port_specs,
        junction_hook,
        qubit.hfss_inductance_nh * 1.0e-9;
        solver_order=solver_order,
        results_dir=results_dir,
        mesh_path=mesh_path
    )
    open(config_path, "w") do io
        JSON.print(io, config, 2)
        write(io, '\n')
    end

    return (; target_qubit, mesh_path, outputs..., config_path, hooks_path, route_registry_path, membership_path, results_dir)
end
