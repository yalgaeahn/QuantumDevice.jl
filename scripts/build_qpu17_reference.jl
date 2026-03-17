using Pkg

const ROOT = normpath(joinpath(@__DIR__, ".."))
Pkg.activate(ROOT; io=devnull)

using DeviceLayout, DeviceLayout.SchematicDrivenLayout, DeviceLayout.PreferredUnits
using FileIO

include(joinpath(ROOT, "src", "SourceAlignedArtifacts.jl"))

const CASE_NAME = "qpu17-reference"
const BUILD_DIR = joinpath(ROOT, "build", CASE_NAME)
const WORK_DIR = joinpath(BUILD_DIR, "work")
const STAGED_DIR = joinpath(WORK_DIR, "DemoQPU17")
const BUILD_GDS = joinpath(BUILD_DIR, "device.gds")
const BUILD_GRAPH = joinpath(BUILD_DIR, "schematic_graph.svg")
const BUILD_LAYOUT = joinpath(BUILD_DIR, "layout.svg")

function package_root(pkg::AbstractString)
    src = Base.find_package(pkg)
    src === nothing && error("Package $(pkg) is not available in the active Julia environment.")
    return dirname(dirname(src))
end

function example_dir()
    return joinpath(package_root("DeviceLayout"), "examples", "DemoQPU17")
end

function reset_workdir()
    mkpath(BUILD_DIR)
    rm(WORK_DIR; recursive=true, force=true)
    mkpath(WORK_DIR)
end

function stage_example()
    cp(example_dir(), STAGED_DIR; force=true)
end

function build_case()
    Base.include(Main, joinpath(STAGED_DIR, "DemoQPU17.jl"))
    isdefined(Main, :DemoQPU17) || error("Staged example did not define the DemoQPU17 module.")

    schematic, artwork = Base.invokelatest(Main.DemoQPU17.qpu17_demo; savegds=false, dir=WORK_DIR)
    save(BUILD_GDS, artwork)
    write_schematic_graph_svg(BUILD_GRAPH, schematic)
    write_layout_svg(BUILD_LAYOUT, artwork; options=default_layout_svg_options(wide=true))
end

function main()
    reset_workdir()
    stage_example()
    build_case()

    println("Generated GDS: $(BUILD_GDS)")
    println("Generated schematic graph: $(BUILD_GRAPH)")
    println("Generated layout SVG: $(BUILD_LAYOUT)")
end

main()
