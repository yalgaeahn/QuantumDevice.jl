using Pkg

const ROOT = normpath(joinpath(@__DIR__, ".."))
Pkg.activate(ROOT; io=devnull)

using JSON
using DeviceLayout

const BUILD_DIR = joinpath(ROOT, "build", "transmon")
const RESULTS_DIR = joinpath(ROOT, "results", "transmon")
const WORK_DIR = joinpath(BUILD_DIR, "work")
const STAGED_EXAMPLE = joinpath(WORK_DIR, "SingleTransmon.jl")
const BUILD_MESH = joinpath(BUILD_DIR, "device.msh")
const BUILD_GDS = joinpath(BUILD_DIR, "device.gds")
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

function build_case(; solver_order::Int=1)
    Base.include(Main, STAGED_EXAMPLE)
    isdefined(Main, :SingleTransmon) || error("Staged example did not define the SingleTransmon module.")

    transmon = Base.invokelatest(Main.SingleTransmon.single_transmon; save_mesh=true, save_gds=true)
    config = Base.invokelatest(Main.SingleTransmon.configfile, transmon; solver_order=solver_order)
    patch_config!(config)

    mesh_path = locate_mesh()
    cp(mesh_path, BUILD_MESH; force=true)

    gds_path = locate_gds()
    gds_path === nothing || cp(gds_path, BUILD_GDS; force=true)

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
    println("Generated Palace config: $(BUILD_CONFIG)")
    println("Palace results directory: $(RESULTS_DIR)")
end

main(ARGS)
