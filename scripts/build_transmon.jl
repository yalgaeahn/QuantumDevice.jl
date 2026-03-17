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

const BUILD_DIR = joinpath(ROOT, "build", "transmon")
const RESULTS_DIR = joinpath(ROOT, "results", "transmon")
const WORK_DIR = joinpath(BUILD_DIR, "work")
const STAGED_EXAMPLE = joinpath(WORK_DIR, "SingleTransmon.jl")
const BUILD_MESH = joinpath(BUILD_DIR, "device.msh")
const BUILD_GDS = joinpath(BUILD_DIR, "device.gds")
const BUILD_GRAPH = joinpath(BUILD_DIR, "schematic_graph.svg")
const BUILD_LAYOUT = joinpath(BUILD_DIR, "layout.svg")
const BUILD_CONFIG = joinpath(BUILD_DIR, "palace.json")

function package_root(pkg::AbstractString)
    src = Base.find_package(pkg)
    src === nothing && error("Package $(pkg) is not available in the active Julia environment.")
    return dirname(dirname(src))
end

function example_path()
    return joinpath(package_root("DeviceLayout"), "examples", "SingleTransmon", "SingleTransmon.jl")
end

function reset_workdir()
    mkpath(BUILD_DIR)
    rm(WORK_DIR; recursive=true, force=true)
    mkpath(WORK_DIR)
    mkpath(RESULTS_DIR)
end

function stage_example()
    cp(example_path(), STAGED_EXAMPLE; force=true)
end

function find_first_existing(candidates)
    for candidate in candidates
        isfile(candidate) && return candidate
    end
    return nothing
end

function locate_mesh()
    candidates = [
        joinpath(WORK_DIR, "single_transmon.msh2"),
        joinpath(WORK_DIR, "single_transmon.msh"),
        joinpath(WORK_DIR, "single-transmon.msh2"),
        joinpath(WORK_DIR, "single-transmon.msh"),
    ]
    mesh = find_first_existing(candidates)
    mesh === nothing && error("Expected a mesh file in $(WORK_DIR), but none of the known filenames were produced.")
    return mesh
end

function locate_gds()
    candidates = [
        joinpath(WORK_DIR, "single_transmon.gds"),
        joinpath(WORK_DIR, "single-transmon.gds"),
    ]
    return find_first_existing(candidates)
end

function patch_config!(config::AbstractDict)
    haskey(config, "Problem") || error("Palace config is missing the Problem section.")
    haskey(config, "Model") || error("Palace config is missing the Model section.")

    config["Problem"]["Output"] = RESULTS_DIR
    config["Model"]["Mesh"] = BUILD_MESH
    return config
end

function write_config(config::AbstractDict)
    open(BUILD_CONFIG, "w") do io
        JSON.print(io, config, 2)
        write(io, '\n')
    end
end

function build_reference_floorplan()
    reset_uniquename!()

    cpw_width = 10μm
    cpw_gap = 6μm
    path_style = Paths.SimpleCPW(cpw_width, cpw_gap)
    bridge_style = ExamplePDK.bridge_geometry(path_style)

    qubit = ExampleRectangleTransmon(;
        jj_template=ExampleSimpleJunction(),
        name="qubit",
        cap_length=620μm,
        cap_gap=30μm,
        cap_width=24μm
    )

    coupling_gap = 5μm
    hanger_length = 500μm
    bend_radius = 50μm
    total_length = 5000μm
    n_meander_turns = 5
    w_shield = 2μm
    w_claw = 34μm
    l_claw = 121μm
    w_grasp = 24μm + 2 * 30μm
    arm_length = 428μm
    total_height =
        arm_length +
        coupling_gap +
        Paths.extent(path_style) +
        hanger_length +
        (3 + n_meander_turns * 2) * bend_radius

    resonator = ExampleClawedMeanderReadout(;
        name="rres",
        coupling_length=400μm,
        coupling_gap=coupling_gap,
        total_length=total_length,
        w_shield=w_shield,
        w_claw=w_claw,
        l_claw=l_claw,
        claw_gap=6μm,
        w_grasp=w_grasp,
        n_meander_turns=n_meander_turns,
        total_height=total_height,
        hanger_length=hanger_length,
        bend_radius=bend_radius,
        bridge=bridge_style
    )

    readout_length = 2700μm
    readout = Path(Point(0μm, 0μm); α0=π / 2, name="p_ro", metadata=LayerVocabulary.METAL_NEGATIVE)
    straight!(readout, readout_length / 2, path_style)
    straight!(readout, readout_length / 2, path_style)

    port_cs = CoordinateSystem(uniquename("port"), nm)
    render!(port_cs, only_simulated(centered(Rectangle(cpw_width, cpw_width))), LayerVocabulary.PORT)
    attach!(readout, sref(port_cs), cpw_width, i=1)
    attach!(readout, sref(port_cs), readout_length / 2 - cpw_width, i=2)

    graph = SchematicGraph("single-transmon")
    qubit_node = add_node!(graph, qubit)
    resonator_node = fuse!(graph, qubit_node, resonator)
    readout_node = add_node!(graph, readout)
    attach!(graph, readout_node, resonator_node => :feedline, 0mm, location=1)

    schematic = plan(graph; log_dir=WORK_DIR)
    add_bridges!(schematic, bridge_style, spacing=300μm)

    substrate_x = 4mm
    substrate_y = 3.7mm
    center_xyz = DeviceLayout.center(schematic)
    chip = centered(Rectangle(substrate_x + 10μm, substrate_y + 10μm), on_pt=center_xyz)
    sim_area = centered(Rectangle(substrate_x, substrate_y), on_pt=center_xyz)
    render!(schematic.coordinate_system, sim_area, LayerVocabulary.SIMULATED_AREA)
    render!(schematic.coordinate_system, sim_area, LayerVocabulary.WRITEABLE_AREA)
    render!(schematic.coordinate_system, chip, LayerVocabulary.CHIP_AREA)

    check!(schematic)

    cell = Cell("single_transmon", nm)
    render!(cell, schematic, L1_TARGET, strict=:no, simulation=true)
    flatten!(cell)

    return (; graph, schematic, layout_cell=cell)
end

function build_case(; solver_order::Int=1)
    Base.include(Main, STAGED_EXAMPLE)
    isdefined(Main, :SingleTransmon) || error("Staged example did not define the SingleTransmon module.")

    transmon = Base.invokelatest(Main.SingleTransmon.single_transmon; save_mesh=true, save_gds=true)
    config = Base.invokelatest(Main.SingleTransmon.configfile, transmon; solver_order=solver_order)
    patch_config!(config)
    reference = build_reference_floorplan()

    mesh_path = locate_mesh()
    cp(mesh_path, BUILD_MESH; force=true)

    gds_path = locate_gds()
    gds_path === nothing || cp(gds_path, BUILD_GDS; force=true)
    write_schematic_graph_svg(BUILD_GRAPH, reference.schematic)
    write_layout_svg(BUILD_LAYOUT, reference.layout_cell)

    write_config(config)
end

function parse_solver_order(args)
    isempty(args) && return 1
    value = tryparse(Int, first(args))
    value === nothing && error("Solver order must be an integer. Received: $(first(args))")
    value > 0 || error("Solver order must be positive. Received: $(value)")
    return value
end

function main(args)
    solver_order = parse_solver_order(args)
    reset_workdir()
    stage_example()
    build_case(; solver_order)

    println("Generated mesh: $(BUILD_MESH)")
    println("Generated schematic graph: $(BUILD_GRAPH)")
    println("Generated layout SVG: $(BUILD_LAYOUT)")
    println("Generated Palace config: $(BUILD_CONFIG)")
    println("Palace results directory: $(RESULTS_DIR)")
end

main(ARGS)
