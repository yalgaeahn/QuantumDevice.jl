using Pkg

const ROOT = normpath(joinpath(@__DIR__, ".."))
Pkg.activate(ROOT; io=devnull)

include(joinpath(ROOT, "src", "QuantumDevice.jl"))
using .QuantumDevice

spec = QuantumDevice.load_trailblazer_spec()
result = QuantumDevice.build_fullchip(spec)

println("trailblazer-fullchip build complete")
println("  GDS: $(result.gds_path)")
!isnothing(result.layout_svg_path) && println("  Layout SVG: $(result.layout_svg_path)")
!isnothing(result.layout_png_path) && println("  Layout PNG: $(result.layout_png_path)")
println("  Placement Graph SVG: $(result.placement_graph_svg_path)")
println("  Placement Registry: $(result.placement_registry_path)")
println("  Connectivity: $(result.connectivity_path)")
println("  Hooks: $(result.hooks_path)")
