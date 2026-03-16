module QuantumDevice

using JSON
using FileIO
using DeviceLayout
using DeviceLayout.SchematicDrivenLayout
using DeviceLayout.PreferredUnits

import DeviceLayout.SchematicDrivenLayout.ExamplePDK
import DeviceLayout.SchematicDrivenLayout: AbstractComponent
import DeviceLayout.SchematicDrivenLayout.ExamplePDK: LayerVocabulary
import DeviceLayout.SchematicDrivenLayout.ExamplePDK.SimpleJunctions: ExampleSimpleJunction

const ROOT = normpath(joinpath(@__DIR__, ".."))

include("TrailBlazer.jl")

end
