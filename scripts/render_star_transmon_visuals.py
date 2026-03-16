from pathlib import Path
import csv
import math

from paraview.simple import (
    _DisableFirstRenderCameraReset,
    Clip,
    ColorBy,
    GetAnimationScene,
    GetColorTransferFunction,
    GetLayout,
    GetMaterialLibrary,
    GetOpacityTransferFunction,
    GetParaViewVersion,
    GetScalarBar,
    Hide,
    OpenDataFile,
    Render,
    RenderAllViews,
    SaveScreenshot,
    SetActiveSource,
    Show,
    Slice,
    Threshold,
    UpdatePipeline,
    CreateRenderView,
)


ROOT = Path(__file__).resolve().parents[1]
CASE_DIR = ROOT / "results" / "star-transmon"
FIG_DIR = ROOT / "figures" / "star-transmon"
FIG_DIR.mkdir(parents=True, exist_ok=True)

EIGENMODE_PVD = CASE_DIR / "paraview" / "eigenmode" / "eigenmode.pvd"
BOUNDARY_PVD = CASE_DIR / "paraview" / "eigenmode_boundary" / "eigenmode_boundary.pvd"
EIG_CSV = CASE_DIR / "eig.csv"
DOMAIN_E_CSV = CASE_DIR / "domain-E.csv"


def parse_eig_csv(path: Path):
    rows = []
    with path.open(newline="") as handle:
        reader = csv.reader(handle)
        next(reader)
        for row in reader:
            if not row:
                continue
            rows.append(
                {
                    "mode": int(float(row[0])),
                    "freq": float(row[1]),
                    "imag": float(row[2]),
                    "q": float(row[3]),
                }
            )
    return rows


def parse_named_csv(path: Path):
    rows = []
    with path.open(newline="") as handle:
        reader = csv.reader(handle)
        header = [entry.strip() for entry in next(reader)]
        for row in reader:
            if not row:
                continue
            rows.append({header[idx]: float(value) for idx, value in enumerate(row)})
    return rows


def write_summary_svg(path: Path, rows):
    width = 960
    height = 520
    margin_left = 90
    margin_right = 60
    margin_top = 90
    margin_bottom = 90
    plot_width = width - margin_left - margin_right
    plot_height = height - margin_top - margin_bottom

    freqs = [row["freq"] for row in rows]
    qvals = [row["q"] for row in rows]
    max_freq = max(freqs) * 1.08
    max_logq = math.ceil(max(math.log10(value) for value in qvals))

    def x_from_index(idx):
        if len(rows) == 1:
            return margin_left + plot_width / 2
        return margin_left + idx * plot_width / (len(rows) - 1)

    def y_from_freq(freq):
        return margin_top + plot_height * (1.0 - freq / max_freq)

    def radius_from_q(q):
        return 16 + 10 * math.log10(q)

    grid_lines = []
    label_lines = []
    for step in range(6):
        freq = max_freq * step / 5
        y = y_from_freq(freq)
        grid_lines.append(
            f'<line x1="{margin_left}" y1="{y:.1f}" x2="{width - margin_right}" y2="{y:.1f}" '
            'stroke="#d8dee7" stroke-width="1"/>'
        )
        label_lines.append(
            f'<text x="{margin_left - 14}" y="{y + 5:.1f}" font-size="16" text-anchor="end" '
            f'fill="#4b5b6b">{freq:.1f}</text>'
        )

    mode_lines = []
    point_lines = []
    text_lines = []
    for idx, row in enumerate(rows):
        x = x_from_index(idx)
        y = y_from_freq(row["freq"])
        r = radius_from_q(row["q"])
        mode_lines.append(
            f'<line x1="{x:.1f}" y1="{y:.1f}" x2="{x:.1f}" y2="{margin_top + plot_height:.1f}" '
            'stroke="#b8c3cf" stroke-width="2" stroke-dasharray="6 6"/>'
        )
        point_lines.append(
            f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r:.1f}" fill="#c24d2c" fill-opacity="0.78" '
            'stroke="#842d17" stroke-width="2"/>'
        )
        text_lines.append(
            f'<text x="{x:.1f}" y="{y - r - 14:.1f}" font-size="18" text-anchor="middle" '
            f'fill="#18222d">Mode {row["mode"]}: {row["freq"]:.3f} GHz</text>'
        )
        text_lines.append(
            f'<text x="{x:.1f}" y="{margin_top + plot_height + 34:.1f}" font-size="18" text-anchor="middle" '
            f'fill="#3a4754">Q = {row["q"]:.1f}</text>'
        )

    x_labels = []
    for idx, row in enumerate(rows):
        x = x_from_index(idx)
        x_labels.append(
            f'<text x="{x:.1f}" y="{height - 30}" font-size="18" text-anchor="middle" fill="#18222d">'
            f'Mode {row["mode"]}</text>'
        )

    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">
<rect width="{width}" height="{height}" fill="#f7f5ef"/>
<rect x="{margin_left}" y="{margin_top}" width="{plot_width}" height="{plot_height}" rx="18" fill="#fffdf8" stroke="#d8dee7"/>
<text x="{margin_left}" y="46" font-size="30" font-weight="700" fill="#18222d">Star-Transmon Eigenmode Summary</text>
<text x="{margin_left}" y="72" font-size="17" fill="#556474">Bubble size scales with log10(Q), vertical position shows frequency.</text>
<text x="30" y="{margin_top + plot_height / 2:.1f}" font-size="18" fill="#18222d" transform="rotate(-90 30 {margin_top + plot_height / 2:.1f})">Frequency (GHz)</text>
<text x="{margin_left + plot_width / 2:.1f}" y="{height - 8}" font-size="18" text-anchor="middle" fill="#18222d">Eigenmode</text>
{''.join(grid_lines)}
{''.join(label_lines)}
{''.join(mode_lines)}
{''.join(point_lines)}
{''.join(text_lines)}
{''.join(x_labels)}
</svg>'''
    path.write_text(svg)


def write_energy_svg(path: Path, rows):
    width = 960
    height = 560
    margin_left = 110
    margin_right = 60
    margin_top = 90
    margin_bottom = 100
    plot_width = width - margin_left - margin_right
    plot_height = height - margin_top - margin_bottom

    bar_width = 120
    gap = 180
    start_x = margin_left + 90
    max_energy = max(max(row["E_elec (J)"], row["E_mag (J)"]) for row in rows) * 1.15

    def y_from_energy(value):
        return margin_top + plot_height * (1.0 - value / max_energy)

    grid_lines = []
    labels = []
    for step in range(6):
        energy = max_energy * step / 5
        y = y_from_energy(energy)
        grid_lines.append(
            f'<line x1="{margin_left}" y1="{y:.1f}" x2="{width - margin_right}" y2="{y:.1f}" stroke="#d8dee7" stroke-width="1"/>'
        )
        labels.append(
            f'<text x="{margin_left - 14}" y="{y + 5:.1f}" font-size="16" text-anchor="end" fill="#4b5b6b">{energy:.3e}</text>'
        )

    bars = []
    annotations = []
    legend = (
        '<rect x="700" y="56" width="18" height="18" fill="#2f7a63"/>'
        '<text x="728" y="70" font-size="17" fill="#18222d">Electric energy</text>'
        '<rect x="700" y="86" width="18" height="18" fill="#d17c2f"/>'
        '<text x="728" y="100" font-size="17" fill="#18222d">Magnetic energy</text>'
    )

    for idx, row in enumerate(rows):
        x = start_x + idx * (2 * bar_width + gap)
        elec_h = plot_height * (row["E_elec (J)"] / max_energy)
        mag_h = plot_height * (row["E_mag (J)"] / max_energy)
        elec_y = margin_top + plot_height - elec_h
        mag_y = margin_top + plot_height - mag_h

        bars.append(
            f'<rect x="{x}" y="{elec_y:.1f}" width="{bar_width}" height="{elec_h:.1f}" fill="#2f7a63" rx="12"/>'
        )
        bars.append(
            f'<rect x="{x + bar_width + 24}" y="{mag_y:.1f}" width="{bar_width}" height="{mag_h:.1f}" fill="#d17c2f" rx="12"/>'
        )

        mode = int(row["m"])
        annotations.append(
            f'<text x="{x + bar_width / 2:.1f}" y="{height - 58}" font-size="18" text-anchor="middle" fill="#18222d">Mode {mode} E</text>'
        )
        annotations.append(
            f'<text x="{x + bar_width + 24 + bar_width / 2:.1f}" y="{height - 58}" font-size="18" text-anchor="middle" fill="#18222d">Mode {mode} H</text>'
        )
        annotations.append(
            f'<text x="{x + bar_width + 12:.1f}" y="{height - 24}" font-size="17" text-anchor="middle" fill="#556474">'
            f'substrate frac: E {row["p_elec[1]"] * 100:.1f}% / H {row["p_mag[1]"] * 100:.1f}%</text>'
        )

    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">
<rect width="{width}" height="{height}" fill="#f7f5ef"/>
<rect x="{margin_left}" y="{margin_top}" width="{plot_width}" height="{plot_height}" rx="18" fill="#fffdf8" stroke="#d8dee7"/>
<text x="{margin_left}" y="46" font-size="30" font-weight="700" fill="#18222d">Star-Transmon Energy Breakdown</text>
<text x="{margin_left}" y="72" font-size="17" fill="#556474">Total electric vs magnetic energy per eigenmode, with substrate participation underneath.</text>
<text x="32" y="{margin_top + plot_height / 2:.1f}" font-size="18" fill="#18222d" transform="rotate(-90 32 {margin_top + plot_height / 2:.1f})">Energy (J)</text>
{legend}
{''.join(grid_lines)}
{''.join(labels)}
{''.join(bars)}
{''.join(annotations)}
</svg>'''
    path.write_text(svg)


def configure_view():
    view = CreateRenderView()
    view.ViewSize = [1600, 1000]
    view.Background = [0.973, 0.965, 0.937]
    view.Background2 = [0.89, 0.91, 0.94]
    view.UseColorPaletteForBackground = 0
    view.OrientationAxesVisibility = 1
    view.AxesGrid = "GridAxes3DActor"
    view.CameraParallelProjection = 0
    layout = GetLayout()
    if layout is not None:
        layout.AssignView(0, view)
    GetMaterialLibrary()
    return view


def style_lut(name, rgb_points):
    lut = GetColorTransferFunction(name)
    lut.RGBPoints = rgb_points
    lut.ColorSpace = "Lab"
    lut.NanColor = [0.6, 0.6, 0.6]
    return lut


def bounds_center(bounds):
    return (
        0.5 * (bounds[0] + bounds[1]),
        0.5 * (bounds[2] + bounds[3]),
        0.5 * (bounds[4] + bounds[5]),
    )


def render_volume_snapshot():
    _DisableFirstRenderCameraReset()
    view = configure_view()
    source = OpenDataFile(str(EIGENMODE_PVD))
    scene = GetAnimationScene()
    scene.UpdateAnimationUsingDataTimeSteps()
    if scene.TimeKeeper.TimestepValues:
        scene.AnimationTime = scene.TimeKeeper.TimestepValues[0]
    UpdatePipeline()

    clip = Clip(Input=source)
    clip.ClipType = "Plane"
    clip.HyperTreeGridClipper = "Plane"
    clip.ClipType.Origin = [-0.0010, 0.0012, 0.0]
    clip.ClipType.Normal = [0.0, 0.0, 1.0]
    UpdatePipeline()

    slice_filter = Slice(Input=clip)
    slice_filter.SliceType = "Plane"
    slice_filter.HyperTreeGridSlicer = "Plane"
    slice_filter.SliceType.Origin = [-0.0010, 0.0012, 0.0]
    slice_filter.SliceType.Normal = [0.0, 0.0, 1.0]
    UpdatePipeline()

    display = Show(slice_filter, view)
    display.Representation = "Surface"
    ColorBy(display, ("POINTS", "U_e"))
    lut = style_lut(
        "U_e",
        [
            0.0, 0.176, 0.251, 0.392,
            0.25, 0.337, 0.600, 0.737,
            0.5, 0.926, 0.894, 0.784,
            0.75, 0.935, 0.549, 0.196,
            1.0, 0.690, 0.157, 0.118,
        ],
    )
    pwf = GetOpacityTransferFunction("U_e")
    pwf.Points = [0.0, 0.05, 0.5, 0.0, 1.0, 1.0, 0.5, 0.0]
    display.LookupTable = lut
    display.RescaleTransferFunctionToDataRange(False, True)
    display.SetScalarBarVisibility(view, True)
    colorbar = GetScalarBar(lut, view)
    colorbar.Title = "U_e"
    colorbar.ComponentTitle = "Electric energy density"
    colorbar.WindowLocation = "Upper Right Corner"

    bounds = slice_filter.GetDataInformation().GetBounds()
    cx, cy, cz = bounds_center(bounds)
    xspan = bounds[1] - bounds[0]
    yspan = bounds[3] - bounds[2]
    view.CameraParallelProjection = 1
    view.CameraPosition = [cx, cy, cz + 0.02]
    view.CameraFocalPoint = [cx, cy, cz]
    view.CameraViewUp = [0.0, 1.0, 0.0]
    view.CameraParallelScale = 0.6 * max(xspan, yspan)
    RenderAllViews()
    SaveScreenshot(str(FIG_DIR / "mode1_u_e_clip.png"), view, ImageResolution=[1600, 1000])


def render_boundary_snapshot(field_name, component_title, output_name, rgb_points):
    _DisableFirstRenderCameraReset()
    view = configure_view()
    source = OpenDataFile(str(BOUNDARY_PVD))
    scene = GetAnimationScene()
    scene.UpdateAnimationUsingDataTimeSteps()
    if scene.TimeKeeper.TimestepValues:
        scene.AnimationTime = scene.TimeKeeper.TimestepValues[0]
    UpdatePipeline()

    threshold = Threshold(Input=source)
    threshold.Scalars = ["CELLS", "attribute"]
    threshold.LowerThreshold = 4.0
    threshold.UpperThreshold = 7.0
    UpdatePipeline()

    display = Show(threshold, view)
    display.Representation = "Surface"
    ColorBy(display, ("POINTS", field_name, "Magnitude"))
    lut = style_lut(field_name, rgb_points)
    display.LookupTable = lut
    display.RescaleTransferFunctionToDataRange(False, True)
    display.SetScalarBarVisibility(view, True)
    colorbar = GetScalarBar(lut, view)
    colorbar.Title = f"|{field_name}|"
    colorbar.ComponentTitle = component_title
    colorbar.WindowLocation = "Upper Right Corner"

    bounds = threshold.GetDataInformation().GetBounds()
    cx, cy, cz = bounds_center(bounds)
    xspan = bounds[1] - bounds[0]
    yspan = bounds[3] - bounds[2]
    view.CameraParallelProjection = 1
    view.CameraPosition = [cx, cy, cz + 0.01]
    view.CameraFocalPoint = [cx, cy, cz]
    view.CameraViewUp = [0.0, 1.0, 0.0]
    view.CameraParallelScale = 0.6 * max(xspan, yspan)
    RenderAllViews()
    SaveScreenshot(str(FIG_DIR / output_name), view, ImageResolution=[1600, 1000])


def main():
    rows = parse_eig_csv(EIG_CSV)
    energy_rows = parse_named_csv(DOMAIN_E_CSV)
    write_summary_svg(FIG_DIR / "eig_summary.svg", rows)
    write_energy_svg(FIG_DIR / "energy_breakdown.svg", energy_rows)
    render_volume_snapshot()
    render_boundary_snapshot(
        "J_s_real",
        "Surface current",
        "mode1_surface_current.png",
        [
            0.0, 0.103, 0.141, 0.192,
            0.25, 0.137, 0.349, 0.466,
            0.5, 0.251, 0.682, 0.682,
            0.75, 0.969, 0.792, 0.384,
            1.0, 0.800, 0.231, 0.141,
        ],
    )
    render_boundary_snapshot(
        "Q_s_real",
        "Surface charge",
        "mode1_surface_charge.png",
        [
            0.0, 0.129, 0.200, 0.341,
            0.25, 0.275, 0.482, 0.714,
            0.5, 0.741, 0.886, 0.965,
            0.75, 0.984, 0.733, 0.349,
            1.0, 0.686, 0.121, 0.145,
        ],
    )
    print(f"Rendered visualizations to {FIG_DIR}")
    print(f"ParaView version: {GetParaViewVersion()}")


if __name__ == "__main__":
    main()
