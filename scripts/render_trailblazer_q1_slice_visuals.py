from pathlib import Path
import csv
import math
import os

from paraview.simple import (
    _DisableFirstRenderCameraReset,
    ColorBy,
    CreateRenderView,
    GetAnimationScene,
    GetColorTransferFunction,
    GetLayout,
    GetMaterialLibrary,
    GetOpacityTransferFunction,
    GetParaViewVersion,
    GetScalarBar,
    OpenDataFile,
    RenderAllViews,
    SaveScreenshot,
    Show,
    Slice,
    UpdatePipeline,
)


ROOT = Path(__file__).resolve().parents[1]
CASE_DIR = Path(os.environ.get("TRAILBLAZER_RESULTS_DIR", ROOT / "results" / "trailblazer-q1-purcell-slice"))
FIG_DIR = Path(os.environ.get("TRAILBLAZER_FIG_DIR", ROOT / "figures" / "trailblazer-q1-purcell-slice"))
FIG_DIR.mkdir(parents=True, exist_ok=True)

EIGENMODE_PVD = CASE_DIR / "paraview" / "eigenmode" / "eigenmode.pvd"
BOUNDARY_PVD = CASE_DIR / "paraview" / "eigenmode_boundary" / "eigenmode_boundary.pvd"
EIG_CSV = CASE_DIR / "eig.csv"


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


def write_summary_svg(path: Path, rows):
    width = 980
    height = 540
    margin_left = 90
    margin_right = 70
    margin_top = 90
    margin_bottom = 90
    plot_width = width - margin_left - margin_right
    plot_height = height - margin_top - margin_bottom

    freqs = [row["freq"] for row in rows]
    qvals = [max(row["q"], 1.0) for row in rows]
    max_freq = max(freqs) * 1.08

    def x_from_index(idx):
        if len(rows) == 1:
            return margin_left + plot_width / 2
        return margin_left + idx * plot_width / (len(rows) - 1)

    def y_from_freq(freq):
        return margin_top + plot_height * (1.0 - freq / max_freq)

    def radius_from_q(q):
        return 15 + 9 * math.log10(max(q, 1.0))

    grid = []
    labels = []
    for step in range(6):
        freq = max_freq * step / 5
        y = y_from_freq(freq)
        grid.append(
            f'<line x1="{margin_left}" y1="{y:.1f}" x2="{width - margin_right}" y2="{y:.1f}" '
            'stroke="#d9e0e8" stroke-width="1"/>'
        )
        labels.append(
            f'<text x="{margin_left - 14}" y="{y + 5:.1f}" font-size="16" text-anchor="end" '
            f'fill="#4a5a69">{freq:.1f}</text>'
        )

    bubbles = []
    annotations = []
    for idx, row in enumerate(rows):
        x = x_from_index(idx)
        y = y_from_freq(row["freq"])
        r = radius_from_q(row["q"])
        bubbles.append(
            f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r:.1f}" fill="#c8582a" fill-opacity="0.78" '
            'stroke="#7e2d16" stroke-width="2"/>'
        )
        annotations.append(
            f'<text x="{x:.1f}" y="{y - r - 12:.1f}" font-size="17" text-anchor="middle" fill="#16202a">'
            f'{row["freq"]:.3f} GHz</text>'
        )
        annotations.append(
            f'<text x="{x:.1f}" y="{height - 28}" font-size="18" text-anchor="middle" fill="#16202a">'
            f'Mode {row["mode"]} | Q={row["q"]:.1f}</text>'
        )

    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">
<rect width="{width}" height="{height}" fill="#f7f4ec"/>
<rect x="{margin_left}" y="{margin_top}" width="{plot_width}" height="{plot_height}" rx="18" fill="#fffdf8" stroke="#d9e0e8"/>
<text x="{margin_left}" y="44" font-size="30" font-weight="700" fill="#16202a">TrailBlazer Q1 Slice Eigenmode Summary</text>
<text x="{margin_left}" y="72" font-size="17" fill="#536372">Bubble size scales with log10(Q); vertical position shows frequency.</text>
<text x="30" y="{margin_top + plot_height / 2:.1f}" font-size="18" fill="#16202a" transform="rotate(-90 30 {margin_top + plot_height / 2:.1f})">Frequency (GHz)</text>
{''.join(grid)}
{''.join(labels)}
{''.join(bubbles)}
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
    view.CameraParallelProjection = 1
    layout = GetLayout()
    if layout is not None:
        layout.AssignView(0, view)
    GetMaterialLibrary()
    return view


def bounds_center(bounds):
    return (
        0.5 * (bounds[0] + bounds[1]),
        0.5 * (bounds[2] + bounds[3]),
        0.5 * (bounds[4] + bounds[5]),
    )


def style_lut(name, rgb_points):
    lut = GetColorTransferFunction(name)
    lut.RGBPoints = rgb_points
    lut.ColorSpace = "Lab"
    lut.NanColor = [0.6, 0.6, 0.6]
    return lut


def render_mode_field():
    _DisableFirstRenderCameraReset()
    view = configure_view()
    source = OpenDataFile(str(EIGENMODE_PVD))
    scene = GetAnimationScene()
    scene.UpdateAnimationUsingDataTimeSteps()
    if scene.TimeKeeper.TimestepValues:
        scene.AnimationTime = scene.TimeKeeper.TimestepValues[0]
    UpdatePipeline()

    slice_filter = Slice(Input=source)
    slice_filter.SliceType = "Plane"
    slice_filter.HyperTreeGridSlicer = "Plane"
    bounds = source.GetDataInformation().GetBounds()
    cx, cy, cz = bounds_center(bounds)
    slice_filter.SliceType.Origin = [cx, cy, cz]
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
    opacity = GetOpacityTransferFunction("U_e")
    opacity.Points = [0.0, 0.05, 0.5, 0.0, 1.0, 1.0, 0.5, 0.0]
    display.LookupTable = lut
    display.RescaleTransferFunctionToDataRange(False, True)
    display.SetScalarBarVisibility(view, True)
    colorbar = GetScalarBar(lut, view)
    colorbar.Title = "U_e"
    colorbar.ComponentTitle = "Electric energy density"
    colorbar.WindowLocation = "Upper Right Corner"

    slice_bounds = slice_filter.GetDataInformation().GetBounds()
    cx, cy, cz = bounds_center(slice_bounds)
    xspan = slice_bounds[1] - slice_bounds[0]
    yspan = slice_bounds[3] - slice_bounds[2]
    view.CameraPosition = [cx, cy, cz + 0.02]
    view.CameraFocalPoint = [cx, cy, cz]
    view.CameraViewUp = [0.0, 1.0, 0.0]
    view.CameraParallelScale = 0.62 * max(xspan, yspan)
    RenderAllViews()
    SaveScreenshot(str(FIG_DIR / "mode1_field.png"), view, ImageResolution=[1600, 1000])


def render_boundary_overview():
    _DisableFirstRenderCameraReset()
    view = configure_view()
    source = OpenDataFile(str(BOUNDARY_PVD))
    scene = GetAnimationScene()
    scene.UpdateAnimationUsingDataTimeSteps()
    if scene.TimeKeeper.TimestepValues:
        scene.AnimationTime = scene.TimeKeeper.TimestepValues[0]
    UpdatePipeline()

    display = Show(source, view)
    display.Representation = "Surface"
    ColorBy(display, ("CELLS", "attribute"))
    lut = style_lut(
        "attribute",
        [
            0.0, 0.174, 0.250, 0.392,
            2.0, 0.282, 0.533, 0.713,
            4.0, 0.161, 0.612, 0.455,
            6.0, 0.917, 0.533, 0.184,
            8.0, 0.741, 0.231, 0.125,
        ],
    )
    display.LookupTable = lut
    display.RescaleTransferFunctionToDataRange(False, True)
    display.SetScalarBarVisibility(view, True)
    colorbar = GetScalarBar(lut, view)
    colorbar.Title = "attribute"
    colorbar.ComponentTitle = "Boundary / port group"
    colorbar.WindowLocation = "Upper Right Corner"

    bounds = source.GetDataInformation().GetBounds()
    cx, cy, cz = bounds_center(bounds)
    xspan = bounds[1] - bounds[0]
    yspan = bounds[3] - bounds[2]
    view.CameraPosition = [cx, cy, cz + 0.02]
    view.CameraFocalPoint = [cx, cy, cz]
    view.CameraViewUp = [0.0, 1.0, 0.0]
    view.CameraParallelScale = 0.62 * max(xspan, yspan)
    RenderAllViews()
    SaveScreenshot(str(FIG_DIR / "mode1_boundary.png"), view, ImageResolution=[1600, 1000])


def main():
    for path in [EIGENMODE_PVD, BOUNDARY_PVD, EIG_CSV]:
        if not path.exists():
            raise SystemExit(f"Missing TrailBlazer visualization input: {path}")

    rows = parse_eig_csv(EIG_CSV)
    write_summary_svg(FIG_DIR / "eigenmode_summary.svg", rows)
    render_mode_field()
    render_boundary_overview()
    print(f"Rendered TrailBlazer visualizations to {FIG_DIR}")
    print(f"ParaView version: {GetParaViewVersion()}")


if __name__ == "__main__":
    main()
