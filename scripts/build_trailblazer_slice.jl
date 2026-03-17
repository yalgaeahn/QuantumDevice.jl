using Pkg

const ROOT = normpath(joinpath(@__DIR__, ".."))
Pkg.activate(ROOT; io=devnull)

include(joinpath(ROOT, "src", "QuantumDevice.jl"))
using .QuantumDevice

target_qubit = isempty(ARGS) ? "Q_1" : ARGS[1]
solver_order = length(ARGS) >= 2 ? something(tryparse(Int, ARGS[2]), 1) : 1

spec = QuantumDevice.load_trailblazer_spec()
result = QuantumDevice.build_slice(spec, target_qubit; solver_order=solver_order)

println("$(result.target_qubit) local-context slice build complete")
println("  Mesh: $(result.mesh_path)")
println("  GDS: $(result.gds_path)")
println("  Schematic Graph: $(result.graph_svg_path)")
!isnothing(result.layout_svg_path) && println("  Layout SVG: $(result.layout_svg_path)")
println("  Config: $(result.config_path)")
println("  Routes: $(result.route_registry_path)")
