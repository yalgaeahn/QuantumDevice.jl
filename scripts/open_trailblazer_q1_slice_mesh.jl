using Pkg

const ROOT = normpath(joinpath(@__DIR__, ".."))
Pkg.activate(ROOT; io=devnull)

include(joinpath(ROOT, "src", "QuantumDevice.jl"))
using .QuantumDevice

spec = QuantumDevice.load_trailblazer_spec()
println("Rendering the TrailBlazer Q1 slice into Gmsh for live inspection...")
QuantumDevice.inspect_slice_solidmodel(spec, :q1_purcell)
