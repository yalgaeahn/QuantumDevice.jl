using Pkg

const ROOT = normpath(joinpath(@__DIR__, ".."))
Pkg.activate(ROOT; io=devnull)

include(joinpath(ROOT, "src", "QuantumDevice.jl"))
using .QuantumDevice

solver_order = isempty(ARGS) ? 1 : something(tryparse(Int, ARGS[1]), 1)

spec = QuantumDevice.load_trailblazer_spec()
result = QuantumDevice.build_slice(spec, :q1_purcell; solver_order=solver_order)

println("trailblazer-q1-purcell-slice build complete")
println("  Mesh: $(result.mesh_path)")
println("  GDS: $(result.gds_path)")
!isnothing(result.layout_svg_path) && println("  Layout SVG: $(result.layout_svg_path)")
!isnothing(result.layout_png_path) && println("  Layout PNG: $(result.layout_png_path)")
println("  Placement Graph SVG: $(result.placement_graph_svg_path)")
println("  Placement Registry: $(result.placement_registry_path)")
println("  Connectivity: $(result.connectivity_path)")
println("  Config: $(result.config_path)")
