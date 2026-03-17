using Pkg

const ROOT = normpath(joinpath(@__DIR__, ".."))
Pkg.activate(ROOT; io=devnull)

include(joinpath(ROOT, "src", "QuantumDevice.jl"))
using .QuantumDevice

target_qubit = isempty(ARGS) ? "Q_1" : ARGS[1]

spec = QuantumDevice.load_trailblazer_spec()
println("Rendering the TrailBlazer $(target_qubit) local-context slice into Gmsh for live inspection...")
QuantumDevice.inspect_slice_solidmodel(spec, target_qubit)
