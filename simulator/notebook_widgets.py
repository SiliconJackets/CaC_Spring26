"""Notebook-native ipywidgets frontend for the DLL simulator."""

from __future__ import annotations

from dataclasses import asdict
import sys
from pathlib import Path
import importlib.util

from IPython.display import HTML, display
from bokeh.io import output_notebook
from bokeh.embed import file_html
from bokeh.resources import CDN

try:
    import pandas as pd
except ImportError:  # pragma: no cover - optional dependency in notebooks
    pd = None

try:
    import ipywidgets as widgets
except ImportError:  # pragma: no cover - optional dependency in notebooks
    widgets = None

MODULE_ROOT = Path(__file__).resolve().parents[1]

if __package__ in (None, ""):
    sys.path.insert(0, str(MODULE_ROOT))
    from simulator.gui_common import DCDLS, CONTROLLERS, PHASE_DETECTORS, run_closed_loop_simulation
else:
    from .gui_common import DCDLS, CONTROLLERS, PHASE_DETECTORS, run_closed_loop_simulation

_plot_framework_spec = importlib.util.spec_from_file_location(
    "cac_plot_framework",
    MODULE_ROOT / "scripts" / "plot_framework.py",
)
if _plot_framework_spec is None or _plot_framework_spec.loader is None:
    raise ImportError("Could not load plot_framework.py from the scripts directory.")
_plot_framework = importlib.util.module_from_spec(_plot_framework_spec)
_plot_framework_spec.loader.exec_module(_plot_framework)
_make_figure = _plot_framework._make_figure
_add_trace = _plot_framework._add_trace
_style_legend = _plot_framework._style_legend
COLORS = _plot_framework.COLORS

DISPLAY_COLUMNS = ["cycle", "clk_in", "clk_out", "up", "down", "phase_error_ps"]
_BOKEH_READY = False


def _styled_caption(text: str):
    if widgets is None:
        raise ImportError("ipywidgets is required to render the notebook GUI.")
    return widgets.HTML(
        value=(
            "<div style='color:#666; font-size:0.95em; margin:2px 0 10px 0;'>"
            f"{text}"
            "</div>"
        )
    )


def _render_table(trace):
    rows = [{key: asdict(entry)[key] for key in DISPLAY_COLUMNS} for entry in trace]
    if pd is not None:
        display(pd.DataFrame(rows))
    else:
        display(rows)


def _ensure_bokeh_ready() -> None:
    global _BOKEH_READY
    if not _BOKEH_READY:
        output_notebook(hide_banner=True)
        _BOKEH_READY = True


def _render_clk_plot(trace) -> None:
    _ensure_bokeh_ready()
    cycles = [entry.cycle for entry in trace]
    clk_in_values = [entry.clk_in for entry in trace]
    clk_out_values = [entry.clk_out for entry in trace]
    figure = _make_figure(
        "clk_in vs clk_out",
        "Cycle",
        "Edge Time (ps)",
        900,
        350,
    )
    for index, (label, y_values) in enumerate(
        (("clk_in", clk_in_values), ("clk_out", clk_out_values))
    ):
        source = _plot_framework.ColumnDataSource(
            data=dict(x=cycles, y=y_values)
        )
        _add_trace(
            figure,
            source,
            "line+scatter",
            COLORS[index % len(COLORS)],
            label=label,
        )
    _style_legend(figure)
    html = file_html(figure, CDN, "clk_in vs clk_out")
    display(HTML(html))


def display_dll_simulator():
    """Render the simulator controls and outputs inside a notebook cell."""
    if widgets is None:
        raise ImportError(
            "ipywidgets is not installed. Install it with `pip install ipywidgets` "
            "in the notebook environment, then rerun this cell."
        )

    phase_detector = widgets.Dropdown(
        options=list(PHASE_DETECTORS.keys()),
        value="FF1",
        description="Phase Detector",
        style={"description_width": "initial"},
        layout=widgets.Layout(width="100%"),
    )
    controller = widgets.Dropdown(
        options=list(CONTROLLERS.keys()),
        value="Saturate",
        description="Controller",
        style={"description_width": "initial"},
        layout=widgets.Layout(width="100%"),
    )
    dcdl = widgets.Dropdown(
        options=list(DCDLS.keys()),
        value="NandDCDL",
        description="DCDL",
        style={"description_width": "initial"},
        layout=widgets.Layout(width="100%"),
    )

    defaults = DCDLS[dcdl.value]

    clk_period_ps = widgets.BoundedFloatText(
        value=float(defaults["default_clk_period_ps"]),
        min=1.0,
        step=10.0,
        description="Reference Clock Period (ps)",
        style={"description_width": "initial"},
        layout=widgets.Layout(width="100%"),
    )
    clk_in_start = widgets.FloatText(
        value=0.0,
        step=10.0,
        description="clk_in Start (ps)",
        style={"description_width": "initial"},
        layout=widgets.Layout(width="100%"),
    )
    auto_clk_out_start = widgets.Checkbox(
        value=True,
        description="Auto clk_out Start",
        indent=False,
        layout=widgets.Layout(width="100%"),
    )
    auto_caption = _styled_caption(
        "Using auto start: clk_out = clk_period - initial cell_delay"
    )
    clk_out_start = widgets.FloatText(
        value=float(clk_period_ps.value - 100.0),
        step=10.0,
        description="clk_out Start (ps)",
        style={"description_width": "initial"},
        layout=widgets.Layout(width="100%", display="none"),
    )
    num_cycles = widgets.IntSlider(
        value=20,
        min=5,
        max=100,
        step=1,
        description="Number of Cycles",
        style={"description_width": "initial"},
        layout=widgets.Layout(width="100%"),
    )

    output = widgets.Output()

    def sync_dcdl_defaults(*_args) -> None:
        selected = DCDLS[dcdl.value]
        clk_period_ps.value = float(selected["default_clk_period_ps"])
        if auto_clk_out_start.value:
            clk_out_start.value = float(clk_period_ps.value - 100.0)

    def sync_clk_out_visibility(*_args) -> None:
        if auto_clk_out_start.value:
            auto_caption.layout.display = ""
            clk_out_start.layout.display = "none"
        else:
            auto_caption.layout.display = "none"
            clk_out_start.layout.display = ""

    def sync_clk_out_default(*_args) -> None:
        if auto_clk_out_start.value:
            clk_out_start.value = float(clk_period_ps.value - 100.0)

    def render(*_args) -> None:
        trace = run_closed_loop_simulation(
            phase_detector_name=phase_detector.value,
            controller_name=controller.value,
            dcdl_name=dcdl.value,
            clk_period_ps=float(clk_period_ps.value),
            init_ctrl=0,
            num_cycles=int(num_cycles.value),
            clk_in_start=float(clk_in_start.value),
            clk_out_start=None if auto_clk_out_start.value else float(clk_out_start.value),
        )
        first = trace[0]
        last = trace[-1]

        with output:
            output.clear_output(wait=True)
            display(
                HTML(
                    "<div>clk_in -> phase detector -> controller -> DCDL, "
                    "with clk_out fed back into the phase detector</div>"
                )
            )
            display(HTML("<div>phase_error_ps = clk_out - clk_in</div>"))
            display(HTML("<h3>Closed-Loop Trace</h3>"))
            _render_table(trace)
            display(HTML("<h3>Clock Plot</h3>"))
            _render_clk_plot(trace)
            display(HTML("<h3>Summary</h3>"))
            display(
                HTML(
                    f"<div>Start: clk_out={first.clk_out:.2f} ps, "
                    f"phase_err={first.phase_error_ps:.2f} ps</div>"
                )
            )
            display(
                HTML(
                    f"<div>End: clk_out={last.clk_out:.2f} ps, "
                    f"phase_err={last.phase_error_ps:.2f} ps</div>"
                )
            )

    dcdl.observe(sync_dcdl_defaults, names="value")
    auto_clk_out_start.observe(sync_clk_out_visibility, names="value")
    clk_period_ps.observe(sync_clk_out_default, names="value")

    for control in (
        phase_detector,
        controller,
        dcdl,
        clk_period_ps,
        clk_in_start,
        auto_clk_out_start,
        clk_out_start,
        num_cycles,
    ):
        control.observe(render, names="value")

    sync_clk_out_visibility()
    render()

    ui = widgets.VBox(
        [
            widgets.HTML("<h2>DLL Simulator Frontend</h2>"),
            _styled_caption(
                "clk_in -> phase detector -> controller -> DCDL, with clk_out fed back "
                "into the phase detector"
            ),
            _styled_caption("phase_error_ps = clk_out - clk_in"),
            widgets.HBox(
                [phase_detector, controller, dcdl],
                layout=widgets.Layout(width="100%"),
            ),
            widgets.HBox(
                [clk_period_ps],
                layout=widgets.Layout(width="100%"),
            ),
            widgets.HBox(
                [
                    clk_in_start,
                    widgets.VBox([auto_clk_out_start, auto_caption, clk_out_start]),
                ],
                layout=widgets.Layout(width="100%"),
            ),
            num_cycles,
            output,
        ]
    )
    return ui
