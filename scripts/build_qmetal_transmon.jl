using Pkg

const ROOT = normpath(joinpath(@__DIR__, ".."))
Pkg.activate(ROOT; io=devnull)

using JSON
using DeviceLayout, DeviceLayout.SchematicDrivenLayout, DeviceLayout.PreferredUnits
using FileIO

include(joinpath(ROOT, "src", "SourceAlignedArtifacts.jl"))

import .SchematicDrivenLayout.ExamplePDK
import .SchematicDrivenLayout.ExamplePDK: LayerVocabulary, L1_TARGET, add_bridges!
using .ExamplePDK.Transmons, .ExamplePDK.ReadoutResonators
import .ExamplePDK.SimpleJunctions: ExampleSimpleJunction

const CASE_NAME = "qmetal-transmon"
const CELL_NAME = "qmetal_transmon"
const BUILD_DIR = joinpath(ROOT, "build", CASE_NAME)
const RESULTS_DIR = joinpath(ROOT, "results", CASE_NAME)
const WORK_DIR = joinpath(BUILD_DIR, "work")
const BUILD_MESH = joinpath(BUILD_DIR, "device.msh")
const BUILD_GDS = joinpath(BUILD_DIR, "device.gds")
const BUILD_GRAPH = joinpath(BUILD_DIR, "schematic_graph.svg")
const BUILD_LAYOUT = joinpath(BUILD_DIR, "layout.svg")
const BUILD_CONFIG = joinpath(BUILD_DIR, "palace.json")
const INPUT_DIR = joinpath(ROOT, "inputs", "qiskit-metal", CASE_NAME)
const SPEC_PATH = joinpath(INPUT_DIR, "migration_spec.json")
const SOURCE_DESIGN = joinpath(INPUT_DIR, "source_design.py")
const REFERENCE_GDS = joinpath(INPUT_DIR, "reference_layout.gds")

Base.@kwdef struct GeometrySpec
    chip_size_um::NTuple{2, Float64}
    simulation_box_um::NTuple{2, Float64}
    cpw_trace_um::Float64
    cpw_gap_um::Float64
    bridge_spacing_um::Float64
    readout_length_um::Float64
    feedline_attach_offset_um::Float64
    claw_gap_um::Float64
    claw_width_um::Float64
    claw_length_um::Float64
    shield_width_um::Float64
    coupling_gap_um::Float64
    coupling_length_um::Float64
    hanger_length_um::Float64
    bend_radius_um::Float64
    meander_turns::Int
    resonator_total_length_um::Float64
    transmon_cap_width_um::Float64
    transmon_cap_length_um::Float64
    transmon_cap_gap_um::Float64
    junction_gap_um::Float64
    island_rounding_um::Float64
end

Base.@kwdef struct JunctionSpec
    inductance_h::Float64
    capacitance_f::Float64
    direction::String
end

Base.@kwdef struct PortSpec
    impedance_ohm::Float64
    port_1_direction::String
    port_2_direction::String
end

Base.@kwdef struct MaterialSpec
    substrate_name::String
    vacuum_permittivity::Float64
    vacuum_permeability::Float64
    substrate_permittivity::Vector{Float64}
    substrate_permeability::Vector{Float64}
    substrate_loss_tangent::Vector{Float64}
    material_axes::Vector{Vector{Float64}}
end

Base.@kwdef struct SolverSpec
    order_default::Int
    mesh_order::Int
    amr_max_iterations::Int
    eigenmode_count::Int
    target_ghz::Float64
    linear_tol::Float64
    linear_max_iterations::Int
    eigenmode_tol::Float64
    save_fields::Int
end

Base.@kwdef struct QMetalTransmonSpec
    design_name::String
    design_origin::String
    geometry::GeometrySpec
    junction::JunctionSpec
    ports::PortSpec
    materials::MaterialSpec
    solver::SolverSpec
    approximations::Vector{String}
end

um(x) = Float64(x) * 1.0μm

function vector2(data, key)
    values = data[key]
    length(values) == 2 || error("Expected exactly two values for $(key).")
    return (Float64(values[1]), Float64(values[2]))
end

function vectorf(data, key)
    return Float64.(data[key])
end

function load_spec(path::AbstractString=SPEC_PATH)
    raw = JSON.parsefile(path)
    geometry_raw = raw["geometry"]
    materials_raw = raw["materials"]
    solver_raw = raw["solver"]
    return QMetalTransmonSpec(
        design_name=raw["design_name"],
        design_origin=raw["design_origin"],
        geometry=GeometrySpec(
            chip_size_um=vector2(geometry_raw, "chip_size_um"),
            simulation_box_um=vector2(geometry_raw, "simulation_box_um"),
            cpw_trace_um=Float64(geometry_raw["cpw_trace_um"]),
            cpw_gap_um=Float64(geometry_raw["cpw_gap_um"]),
            bridge_spacing_um=Float64(geometry_raw["bridge_spacing_um"]),
            readout_length_um=Float64(geometry_raw["readout_length_um"]),
            feedline_attach_offset_um=Float64(geometry_raw["feedline_attach_offset_um"]),
            claw_gap_um=Float64(geometry_raw["claw_gap_um"]),
            claw_width_um=Float64(geometry_raw["claw_width_um"]),
            claw_length_um=Float64(geometry_raw["claw_length_um"]),
            shield_width_um=Float64(geometry_raw["shield_width_um"]),
            coupling_gap_um=Float64(geometry_raw["coupling_gap_um"]),
            coupling_length_um=Float64(geometry_raw["coupling_length_um"]),
            hanger_length_um=Float64(geometry_raw["hanger_length_um"]),
            bend_radius_um=Float64(geometry_raw["bend_radius_um"]),
            meander_turns=Int(geometry_raw["meander_turns"]),
            resonator_total_length_um=Float64(geometry_raw["resonator_total_length_um"]),
            transmon_cap_width_um=Float64(geometry_raw["transmon_cap_width_um"]),
            transmon_cap_length_um=Float64(geometry_raw["transmon_cap_length_um"]),
            transmon_cap_gap_um=Float64(geometry_raw["transmon_cap_gap_um"]),
            junction_gap_um=Float64(geometry_raw["junction_gap_um"]),
            island_rounding_um=Float64(geometry_raw["island_rounding_um"])
        ),
        junction=JunctionSpec(
            inductance_h=Float64(raw["junction"]["inductance_h"]),
            capacitance_f=Float64(raw["junction"]["capacitance_f"]),
            direction=raw["junction"]["direction"]
        ),
        ports=PortSpec(
            impedance_ohm=Float64(raw["ports"]["impedance_ohm"]),
            port_1_direction=raw["ports"]["port_1_direction"],
            port_2_direction=raw["ports"]["port_2_direction"]
        ),
        materials=MaterialSpec(
            substrate_name=materials_raw["substrate_name"],
            vacuum_permittivity=Float64(materials_raw["vacuum_permittivity"]),
            vacuum_permeability=Float64(materials_raw["vacuum_permeability"]),
            substrate_permittivity=vectorf(materials_raw, "substrate_permittivity"),
            substrate_permeability=vectorf(materials_raw, "substrate_permeability"),
            substrate_loss_tangent=vectorf(materials_raw, "substrate_loss_tangent"),
            material_axes=[Float64.(axis) for axis in materials_raw["material_axes"]]
        ),
        solver=SolverSpec(
            order_default=Int(solver_raw["order_default"]),
            mesh_order=Int(solver_raw["mesh_order"]),
            amr_max_iterations=Int(solver_raw["amr_max_iterations"]),
            eigenmode_count=Int(solver_raw["eigenmode_count"]),
            target_ghz=Float64(solver_raw["target_ghz"]),
            linear_tol=Float64(solver_raw["linear_tol"]),
            linear_max_iterations=Int(solver_raw["linear_max_iterations"]),
            eigenmode_tol=Float64(solver_raw["eigenmode_tol"]),
            save_fields=Int(solver_raw["save_fields"])
        ),
        approximations=String.(raw["approximations"])
    )
end

function reset_workdir()
    mkpath(BUILD_DIR)
    mkpath(RESULTS_DIR)
    rm(WORK_DIR; recursive=true, force=true)
    mkpath(WORK_DIR)
end

function stage_source_artifacts()
    cp(SPEC_PATH, joinpath(WORK_DIR, "migration_spec.json"); force=true)
    cp(SOURCE_DESIGN, joinpath(WORK_DIR, "source_design.py"); force=true)
    isfile(REFERENCE_GDS) && cp(REFERENCE_GDS, joinpath(WORK_DIR, "reference_layout.gds"); force=true)
end

function build_layout(spec::QMetalTransmonSpec; save_mesh::Bool=false, save_gds::Bool=false)
    reset_uniquename!()

    geometry = spec.geometry
    path_style = Paths.SimpleCPW(um(geometry.cpw_trace_um), um(geometry.cpw_gap_um))
    bridge_style = ExamplePDK.bridge_geometry(path_style)

    qubit = ExampleRectangleTransmon(;
        name="qubit",
        jj_template=ExampleSimpleJunction(),
        cap_width=um(geometry.transmon_cap_width_um),
        cap_length=um(geometry.transmon_cap_length_um),
        cap_gap=um(geometry.transmon_cap_gap_um),
        junction_gap=um(geometry.junction_gap_um),
        island_rounding=um(geometry.island_rounding_um)
    )

    w_grasp = um(geometry.transmon_cap_width_um + 2 * geometry.transmon_cap_gap_um)
    arm_length = 428μm
    total_height =
        arm_length +
        um(geometry.coupling_gap_um) +
        Paths.extent(path_style) +
        um(geometry.hanger_length_um) +
        (3 + geometry.meander_turns * 2) * um(geometry.bend_radius_um)

    resonator = ExampleClawedMeanderReadout(;
        name="rres",
        coupling_length=um(geometry.coupling_length_um),
        coupling_gap=um(geometry.coupling_gap_um),
        total_length=um(geometry.resonator_total_length_um),
        w_shield=um(geometry.shield_width_um),
        w_claw=um(geometry.claw_width_um),
        l_claw=um(geometry.claw_length_um),
        claw_gap=um(geometry.claw_gap_um),
        w_grasp=w_grasp,
        n_meander_turns=geometry.meander_turns,
        total_height=total_height,
        hanger_length=um(geometry.hanger_length_um),
        bend_radius=um(geometry.bend_radius_um),
        bridge=bridge_style
    )

    readout_path = Path(
        Point(0μm, 0μm);
        α0=π / 2,
        name="p_ro",
        metadata=LayerVocabulary.METAL_NEGATIVE
    )
    half_length = um(geometry.readout_length_um / 2)
    straight!(readout_path, half_length, path_style)
    straight!(readout_path, half_length, path_style)

    port_cs = CoordinateSystem(uniquename("port"), nm)
    render!(
        port_cs,
        only_simulated(centered(Rectangle(um(geometry.cpw_trace_um), um(geometry.cpw_trace_um)))),
        LayerVocabulary.PORT
    )
    attach!(readout_path, sref(port_cs), um(geometry.cpw_trace_um), i=1)
    attach!(
        readout_path,
        sref(port_cs),
        half_length - um(geometry.cpw_trace_um),
        i=2
    )

    graph = SchematicGraph(CELL_NAME)
    qubit_node = add_node!(graph, qubit)
    resonator_node = fuse!(graph, qubit_node, resonator)
    readout_node = add_node!(graph, readout_path)
    attach!(
        graph,
        readout_node,
        resonator_node => :feedline,
        um(geometry.feedline_attach_offset_um),
        location=1
    )

    floorplan = plan(graph; log_dir=WORK_DIR)
    add_bridges!(floorplan, bridge_style, spacing=um(geometry.bridge_spacing_um))

    center_xyz = DeviceLayout.center(floorplan)
    chip = centered(
        Rectangle(um(geometry.chip_size_um[1]), um(geometry.chip_size_um[2])),
        on_pt=center_xyz
    )
    sim_area = centered(
        Rectangle(um(geometry.simulation_box_um[1]), um(geometry.simulation_box_um[2])),
        on_pt=center_xyz
    )

    render!(floorplan.coordinate_system, sim_area, LayerVocabulary.SIMULATED_AREA)
    render!(floorplan.coordinate_system, sim_area, LayerVocabulary.WRITEABLE_AREA)
    render!(floorplan.coordinate_system, chip, LayerVocabulary.CHIP_AREA)

    check!(floorplan)

    tech = ExamplePDK.singlechip_solidmodel_target("port_1", "port_2", "lumped_element")
    sm = SolidModel(CELL_NAME, overwrite=true)
    SolidModels.set_gmsh_option("General.Verbosity", 1)
    SolidModels.mesh_order(spec.solver.mesh_order)
    render!(sm, floorplan, tech)

    if save_mesh
        SolidModels.gmsh.model.mesh.generate(3)
        save(joinpath(WORK_DIR, "qmetal_transmon.msh2"), sm)
    end

    cell = Cell(CELL_NAME, nm)
    render!(cell, floorplan, L1_TARGET, strict=:no, simulation=true)
    flatten!(cell)
    save_gds && save(joinpath(WORK_DIR, "qmetal_transmon.gds"), cell)

    return (; graph, schematic=floorplan, layout_cell=cell, sm)
end

function locate_mesh()
    candidates = [
        joinpath(WORK_DIR, "qmetal_transmon.msh2"),
        joinpath(WORK_DIR, "qmetal_transmon.msh"),
    ]
    for candidate in candidates
        isfile(candidate) && return candidate
    end
    error("Expected a mesh file in $(WORK_DIR), but none of the known filenames were produced.")
end

function locate_gds()
    candidates = [
        joinpath(WORK_DIR, "qmetal_transmon.gds"),
        joinpath(WORK_DIR, "qmetal-transmon.gds"),
    ]
    for candidate in candidates
        isfile(candidate) && return candidate
    end
    return nothing
end

function configfile(sm::SolidModel, spec::QMetalTransmonSpec; solver_order::Int)
    attributes = SolidModels.attributes(sm)
    materials = spec.materials
    return Dict(
        "Problem" => Dict(
            "Type" => "Eigenmode",
            "Verbose" => 2,
            "Output" => RESULTS_DIR
        ),
        "Model" => Dict(
            "Mesh" => BUILD_MESH,
            "L0" => 1e-6,
            "Refinement" => Dict("MaxIts" => spec.solver.amr_max_iterations)
        ),
        "Domains" => Dict(
            "Materials" => [
                Dict(
                    "Attributes" => [attributes["vacuum"]],
                    "Permeability" => materials.vacuum_permeability,
                    "Permittivity" => materials.vacuum_permittivity
                ),
                Dict(
                    "Attributes" => [attributes["substrate"]],
                    "Permeability" => materials.substrate_permeability,
                    "Permittivity" => materials.substrate_permittivity,
                    "LossTan" => materials.substrate_loss_tangent,
                    "MaterialAxes" => materials.material_axes
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
                    "R" => spec.ports.impedance_ohm,
                    "Direction" => spec.ports.port_1_direction
                ),
                Dict(
                    "Index" => 2,
                    "Attributes" => [attributes["port_2"]],
                    "R" => spec.ports.impedance_ohm,
                    "Direction" => spec.ports.port_2_direction
                ),
                Dict(
                    "Index" => 3,
                    "Attributes" => [attributes["lumped_element"]],
                    "L" => spec.junction.inductance_h,
                    "C" => spec.junction.capacitance_f,
                    "Direction" => spec.junction.direction
                )
            ]
        ),
        "Solver" => Dict(
            "Order" => solver_order,
            "Eigenmode" => Dict(
                "N" => spec.solver.eigenmode_count,
                "Tol" => spec.solver.eigenmode_tol,
                "Target" => spec.solver.target_ghz,
                "Save" => spec.solver.save_fields
            ),
            "Linear" => Dict(
                "Type" => "Default",
                "Tol" => spec.solver.linear_tol,
                "MaxIts" => spec.solver.linear_max_iterations
            )
        )
    )
end

function write_config(config)
    open(BUILD_CONFIG, "w") do io
        JSON.print(io, config, 2)
        write(io, '\n')
    end
end

function build_case(spec::QMetalTransmonSpec; solver_order::Int=spec.solver.order_default)
    stage_source_artifacts()
    case_data = build_layout(spec; save_mesh=true, save_gds=true)
    cp(locate_mesh(), BUILD_MESH; force=true)
    gds = locate_gds()
    gds === nothing || cp(gds, BUILD_GDS; force=true)
    write_schematic_graph_svg(BUILD_GRAPH, case_data.schematic)
    write_layout_svg(BUILD_LAYOUT, case_data.layout_cell)
    write_config(configfile(case_data.sm, spec; solver_order))
end

function parse_solver_order(args, spec::QMetalTransmonSpec)
    isempty(args) && return spec.solver.order_default
    value = tryparse(Int, first(args))
    value === nothing && error("Solver order must be an integer. Received: $(first(args))")
    value > 0 || error("Solver order must be positive. Received: $(value)")
    return value
end

function main(args)
    spec = load_spec()
    solver_order = parse_solver_order(args, spec)
    reset_workdir()
    build_case(spec; solver_order)

    println("Generated mesh: $(BUILD_MESH)")
    println("Generated GDS: $(BUILD_GDS)")
    println("Generated schematic graph: $(BUILD_GRAPH)")
    println("Generated layout SVG: $(BUILD_LAYOUT)")
    println("Generated Palace config: $(BUILD_CONFIG)")
    println("Palace results directory: $(RESULTS_DIR)")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main(ARGS)
end
