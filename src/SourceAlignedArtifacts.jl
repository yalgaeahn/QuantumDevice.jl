export source_graph_hidden
export source_graph_role
export write_schematic_graph_svg
export write_layout_svg
export default_layout_svg_options

source_graph_hidden(::Any) = false
source_graph_role(::Any) = :component
source_graph_role(::RouteComponent) = :route

function _μm_value(x)
    return Float64(DeviceLayout.Unitful.ustrip(DeviceLayout.Unitful.uconvert(μm, x)))
end

function _xml_escape(text::AbstractString)
    escaped = replace(text, "&" => "&amp;")
    escaped = replace(escaped, "<" => "&lt;")
    escaped = replace(escaped, ">" => "&gt;")
    escaped = replace(escaped, "\"" => "&quot;")
    return replace(escaped, "'" => "&apos;")
end

function _try_native_graph_svg(obj)
    io = IOBuffer()
    try
        show(io, MIME("image/svg+xml"), obj)
        svg = String(take!(io))
        occursin("<svg", svg) || return nothing
        return svg
    catch
        return nothing
    end
end

function _visible_nodes(g::SchematicGraph)
    return [node for node in nodes(g) if !source_graph_hidden(component(node))]
end

function _graph_positions(g::SchematicGraph)
    visible = _visible_nodes(g)
    n = length(visible)
    positions = Dict{ComponentNode, Tuple{Float64, Float64}}()
    if n == 0
        return visible, positions
    end
    for (idx, node) in enumerate(visible)
        θ = 2π * (idx - 1) / max(n, 1)
        positions[node] = (cos(θ), sin(θ))
    end
    return visible, positions
end

function _graph_positions(sch::Schematic)
    g = sch.graph
    visible = _visible_nodes(g)
    positions = Dict{ComponentNode, Tuple{Float64, Float64}}()
    for node in visible
        pt = center(sch, node)
        positions[node] = (_μm_value(pt.x), _μm_value(pt.y))
    end
    return visible, positions
end

function _project_point(
    x::Float64,
    y::Float64,
    minx::Float64,
    maxx::Float64,
    miny::Float64,
    maxy::Float64,
    width::Float64,
    height::Float64,
    margin::Float64
)
    xrange = max(maxx - minx, 1.0)
    yrange = max(maxy - miny, 1.0)
    scale = min((width - 2 * margin) / xrange, (height - 2 * margin) / yrange)
    xpad = (width - scale * xrange) / 2
    ypad = (height - scale * yrange) / 2
    sx = xpad + (x - minx) * scale
    sy = height - (ypad + (y - miny) * scale)
    return sx, sy
end

function _edge_label(g::SchematicGraph, edge)
    src_node = g[SchematicDrivenLayout.Graphs.src(edge)]
    dst_node = g[SchematicDrivenLayout.Graphs.dst(edge)]
    hook1 = SchematicDrivenLayout.get_prop(g, edge, src_node)
    hook2 = SchematicDrivenLayout.get_prop(g, edge, dst_node)
    return "$(string(hook1)) <> $(string(hook2))"
end

function _graph_svg_text(path::AbstractString, obj)
    visible, positions = _graph_positions(obj)
    g = obj isa Schematic ? obj.graph : obj
    width = 1600.0
    height = 1100.0
    margin = 90.0

    if isempty(visible)
        svg = """
        <svg xmlns="http://www.w3.org/2000/svg" width="$width" height="$height" viewBox="0 0 $width $height">
          <rect width="$width" height="$height" fill="#fcfbf7"/>
          <text x="$(width / 2)" y="$(height / 2)" text-anchor="middle" font-family="Helvetica, Arial, sans-serif" font-size="24" fill="#475467">No visible nodes</text>
        </svg>
        """
        write(path, svg)
        return path
    end

    xs = first.(values(positions))
    ys = last.(values(positions))
    minx, maxx = extrema(xs)
    miny, maxy = extrema(ys)

    node_xy = Dict{ComponentNode, Tuple{Float64, Float64}}()
    for node in visible
        x, y = positions[node]
        node_xy[node] = _project_point(x, y, minx, maxx, miny, maxy, width, height, margin)
    end

    io = IOBuffer()
    println(io, "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"$width\" height=\"$height\" viewBox=\"0 0 $width $height\">")
    println(io, "  <rect width=\"$width\" height=\"$height\" fill=\"#fcfbf7\"/>")
    println(io, "  <text x=\"$(width / 2)\" y=\"44\" text-anchor=\"middle\" font-family=\"Helvetica, Arial, sans-serif\" font-size=\"24\" fill=\"#1f2937\">Schematic Graph</text>")

    for edge in SchematicDrivenLayout.Graphs.edges(g.graph)
        src_node = g[SchematicDrivenLayout.Graphs.src(edge)]
        dst_node = g[SchematicDrivenLayout.Graphs.dst(edge)]
        if source_graph_hidden(component(src_node)) || source_graph_hidden(component(dst_node))
            continue
        end
        x1, y1 = node_xy[src_node]
        x2, y2 = node_xy[dst_node]
        mx = (x1 + x2) / 2
        my = (y1 + y2) / 2
        label = _xml_escape(_edge_label(g, edge))
        println(io, "  <line x1=\"$x1\" y1=\"$y1\" x2=\"$x2\" y2=\"$y2\" stroke=\"#98a2b3\" stroke-width=\"2.5\" stroke-linecap=\"round\"/>")
        println(io, "  <text x=\"$mx\" y=\"$(my - 8)\" text-anchor=\"middle\" font-family=\"Helvetica, Arial, sans-serif\" font-size=\"11\" fill=\"#667085\">$label</text>")
    end

    for node in visible
        x, y = node_xy[node]
        label = _xml_escape(node.id)
        role = source_graph_role(component(node))
        fill = role == :route ? "#f79009" : "#155eef"
        stroke = role == :route ? "#b54708" : "#1849a9"
        if role == :route
            println(io, "  <rect x=\"$(x - 52)\" y=\"$(y - 18)\" width=\"104\" height=\"36\" rx=\"14\" ry=\"14\" fill=\"$fill\" fill-opacity=\"0.92\" stroke=\"$stroke\" stroke-width=\"2\"/>")
        else
            println(io, "  <circle cx=\"$x\" cy=\"$y\" r=\"28\" fill=\"$fill\" fill-opacity=\"0.92\" stroke=\"$stroke\" stroke-width=\"2.5\"/>")
        end
        println(io, "  <text x=\"$x\" y=\"$(y + 52)\" text-anchor=\"middle\" font-family=\"Helvetica, Arial, sans-serif\" font-size=\"14\" fill=\"#101828\">$label</text>")
    end

    println(io, "</svg>")
    write(path, String(take!(io)))
    return path
end

function write_schematic_graph_svg(path::AbstractString, obj)
    mkpath(dirname(path))
    native = _try_native_graph_svg(obj)
    if !isnothing(native)
        write(path, native)
        return path
    end
    return _graph_svg_text(path, obj)
end

function default_layout_svg_options(; wide::Bool=false)
    return wide ? (; width=2200, height=1400) : (; width=1600, height=1100)
end

function write_layout_svg(path::AbstractString, cell::Cell; options=default_layout_svg_options())
    mkpath(dirname(path))
    save(path, cell; options...)
    return path
end
