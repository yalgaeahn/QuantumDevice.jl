using Pkg

const ROOT = normpath(joinpath(@__DIR__, ".."))
Pkg.activate(ROOT; io=devnull)

using JSON
using DeviceLayout, DeviceLayout.SchematicDrivenLayout, DeviceLayout.PreferredUnits
using FileIO

import .SchematicDrivenLayout.ExamplePDK
import .SchematicDrivenLayout.ExamplePDK: LayerVocabulary, L1_TARGET
using .ExamplePDK.Transmons, .ExamplePDK.ReadoutResonators
import .ExamplePDK.SimpleJunctions: ExampleSimpleJunction

const CASE_NAME = "star-transmon"
const CELL_NAME = "star_transmon"
const BUILD_DIR = joinpath(ROOT, "build", CASE_NAME)
const RESULTS_DIR = joinpath(ROOT, "results", CASE_NAME)
const WORK_DIR = joinpath(BUILD_DIR, "work")
const BUILD_MESH = joinpath(BUILD_DIR, "device.msh")
const BUILD_GDS = joinpath(BUILD_DIR, "device.gds")
const BUILD_CONFIG = joinpath(BUILD_DIR, "palace.json")

function reset_workdir()
    mkpath(BUILD_DIR)
    mkpath(RESULTS_DIR)
    rm(WORK_DIR; recursive=true, force=true)
    mkpath(WORK_DIR)
end

function solver_order_from_args(args)
    isempty(args) && return 1
    value = tryparse(Int, first(args))
    value === nothing && error("Solver order must be an integer. Received: $(first(args))")
    value > 0 || error("Solver order must be positive. Received: $(value)")
    return value
end

function stage_port_marker(width)
    port_cs = CoordinateSystem(uniquename("port"), nm)
    render!(
        port_cs,
        only_simulated(centered(Rectangle(width, width))),
        LayerVocabulary.PORT
    )
    return sref(port_cs)
end

function make_port_lead(name, length, style, port_ref)
    lead = Path(Point(0μm, 0μm); α0=0°, name=name, metadata=LayerVocabulary.METAL_NEGATIVE)
    straight!(lead, length, style)
    attach!(lead, port_ref, max(length - style.trace, style.trace))
    return lead
end

function direction_vector(hook)
    θ = in_direction(hook)
    return [Float64(cos(θ)), Float64(sin(θ)), 0.0]
end

function star_filtered_transmon(; save_mesh::Bool=false, save_gds::Bool=false, mesh_order::Int=2)
    reset_uniquename!()

    feedline_style = Paths.CPW(10μm, 6μm)
    resonator_style = Paths.CPW(10μm, 10μm)
    coupler_style = Paths.CPW(10μm, 10μm)
    control_style = Paths.CPW(3.3μm, 2μm)

    qubit = ExampleStarTransmon(;
        name="qubit",
        jj_template=ExampleSimpleJunction(),
        grounded_couplers=[1, 2, 3, 4],
        island_inner_radius=[80μm, 80μm, 80μm, 80μm, 20μm],
        coupler_style=coupler_style,
        resonator_style=resonator_style,
        feedline_style=feedline_style,
        xy_style=control_style,
        z_style=control_style,
        coupler_bridge=ExamplePDK.bridge_geometry(coupler_style),
        control_bridge=ExamplePDK.bridge_geometry(control_style)
    )

    readout = ExampleFilteredHairpinReadout(;
        name="readout",
        feedline_length=2.6mm,
        feedline_style=feedline_style,
        feedline_tap_style=feedline_style,
        feedline_bridge=ExamplePDK.bridge_geometry(feedline_style),
        resonator_style=resonator_style,
        resonator_bridge=ExamplePDK.bridge_geometry(resonator_style),
        filter_total_effective_length=4.0mm,
        readout_total_effective_length=4.8mm,
        filter_assumed_extra_length=1.0mm,
        readout_assumed_extra_length=1.0mm,
        straight_length=1.35mm,
        extra_filter_l1=450μm,
        extra_filter_θ1=15°,
        extra_filter_l2=250μm,
        extra_filter_θ2=-15°,
        readout_initial_snake=Point(750μm, 220μm),
        tap_position=0.9mm
    )

    port_ref = stage_port_marker(feedline_style.trace)
    lead_in = make_port_lead("feed_in", 350μm, feedline_style, port_ref)
    lead_out = make_port_lead("feed_out", 350μm, feedline_style, port_ref)

    g = SchematicGraph(CELL_NAME)
    qubit_node = add_node!(g, qubit)
    readout_node = fuse!(g, qubit_node => :readout, readout => :qubit)
    lead_in_node = fuse!(g, readout_node => :p0, lead_in => :p0)
    lead_out_node = fuse!(g, readout_node => :p1, lead_out => :p0)

    floorplan = plan(g; log_dir=WORK_DIR)

    sim_area = union2d(halo(bounds(floorplan), 1.0mm))
    chip = union2d(halo(bounds(floorplan), 1.1mm))
    render!(floorplan.coordinate_system, sim_area, LayerVocabulary.SIMULATED_AREA)
    render!(floorplan.coordinate_system, sim_area, LayerVocabulary.WRITEABLE_AREA)
    render!(floorplan.coordinate_system, chip, LayerVocabulary.CHIP_AREA)

    check!(floorplan)

    tech = ExamplePDK.singlechip_solidmodel_target("port_1", "port_2", "lumped_element")
    sm = SolidModel(CELL_NAME, overwrite=true)
    SolidModels.set_gmsh_option("General.Verbosity", 1)
    SolidModels.mesh_order(mesh_order)
    render!(sm, floorplan, tech)

    port_directions = (
        direction_vector(hooks(floorplan, lead_in_node).p1),
        direction_vector(hooks(floorplan, lead_out_node).p1)
    )

    if save_mesh
        SolidModels.gmsh.model.mesh.generate(3)
        save(joinpath(WORK_DIR, "star_transmon.msh2"), sm)
    end

    if save_gds
        c = Cell(CELL_NAME, nm)
        render!(c, floorplan, L1_TARGET, strict=:no, simulation=true)
        flatten!(c)
        save(joinpath(WORK_DIR, "star_transmon.gds"), c)
    end

    return (; sm, port_directions)
end

function configfile(sm::SolidModel; solver_order::Int=1, amr::Int=0, port_directions=nothing)
    attributes = SolidModels.attributes(sm)
    port_directions === nothing && (port_directions = ([1.0, 0.0, 0.0], [1.0, 0.0, 0.0]))
    port_1_direction, port_2_direction = port_directions

    return Dict(
        "Problem" => Dict(
            "Type" => "Eigenmode",
            "Verbose" => 2,
            "Output" => RESULTS_DIR
        ),
        "Model" => Dict(
            "Mesh" => BUILD_MESH,
            "L0" => 1e-6,
            "Refinement" => Dict("MaxIts" => amr)
        ),
        "Domains" => Dict(
            "Materials" => [
                Dict(
                    "Attributes" => [attributes["vacuum"]],
                    "Permeability" => 1.0,
                    "Permittivity" => 1.0
                ),
                Dict(
                    "Attributes" => [attributes["substrate"]],
                    "Permeability" => [0.99999975, 0.99999975, 0.99999979],
                    "Permittivity" => [9.3, 9.3, 11.5],
                    "LossTan" => [3.0e-5, 3.0e-5, 8.6e-5],
                    "MaterialAxes" =>
                        [[0.8, 0.6, 0.0], [-0.6, 0.8, 0.0], [0.0, 0.0, 1.0]]
                )
            ],
            "Postprocessing" => Dict(
                "Energy" => [Dict("Index" => 1, "Attributes" => [attributes["substrate"]])]
            )
        ),
        "Boundaries" => Dict(
            "PEC" => Dict("Attributes" => [attributes["metal"]]),
            "Absorbing" => Dict(
                "Attributes" => [attributes["exterior_boundary"]],
                "Order" => 1
            ),
            "LumpedPort" => [
                Dict(
                    "Index" => 1,
                    "Attributes" => [attributes["port_1"]],
                    "R" => 50,
                    "Direction" => port_1_direction
                ),
                Dict(
                    "Index" => 2,
                    "Attributes" => [attributes["port_2"]],
                    "R" => 50,
                    "Direction" => port_2_direction
                ),
                Dict(
                    "Index" => 3,
                    "Attributes" => [attributes["lumped_element"]],
                    "L" => 14.860e-9,
                    "C" => 5.5e-15,
                    "Direction" => "+Y"
                )
            ]
        ),
        "Solver" => Dict(
            "Order" => solver_order,
            "Eigenmode" =>
                Dict("N" => 2, "Tol" => 1.0e-6, "Target" => 4.0, "Save" => 2),
            "Linear" => Dict("Type" => "Default", "Tol" => 1.0e-7, "MaxIts" => 500)
        )
    )
end

function locate_mesh()
    candidates = [
        joinpath(WORK_DIR, "star_transmon.msh2"),
        joinpath(WORK_DIR, "star_transmon.msh"),
    ]
    for candidate in candidates
        isfile(candidate) && return candidate
    end
    error("Expected a mesh file in $(WORK_DIR), but none of the known filenames were produced.")
end

function locate_gds()
    candidates = [
        joinpath(WORK_DIR, "star_transmon.gds"),
        joinpath(WORK_DIR, "star-transmon.gds"),
    ]
    for candidate in candidates
        isfile(candidate) && return candidate
    end
    return nothing
end

function write_config(config)
    open(BUILD_CONFIG, "w") do io
        JSON.print(io, config, 2)
        write(io, '\n')
    end
end

function build_case(; solver_order::Int=1)
    case_data = star_filtered_transmon(save_mesh=true, save_gds=true)
    config = configfile(
        case_data.sm;
        solver_order=solver_order,
        port_directions=case_data.port_directions
    )

    cp(locate_mesh(), BUILD_MESH; force=true)
    gds = locate_gds()
    gds === nothing || cp(gds, BUILD_GDS; force=true)
    write_config(config)
end

function main(args)
    solver_order = solver_order_from_args(args)
    reset_workdir()
    build_case(; solver_order)

    println("Generated mesh: $(BUILD_MESH)")
    println("Generated Palace config: $(BUILD_CONFIG)")
    println("Palace results directory: $(RESULTS_DIR)")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main(ARGS)
end
