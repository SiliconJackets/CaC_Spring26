"""Notebook-native ipywidgets frontend for the DLL simulator."""

from __future__ import annotations

from dataclasses import asdict
from io import BytesIO
import sys
from pathlib import Path

from IPython.display import HTML, Image, display
import matplotlib.pyplot as plt

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

DISPLAY_COLUMNS = ["cycle", "clk_in", "clk_out", "up", "down", "phase_error_ps"]


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


def _render_clk_plot(trace) -> None:
    cycles = [entry.cycle for entry in trace]
    clk_in_values = [entry.clk_in for entry in trace]
    clk_out_values = [entry.clk_out for entry in trace]
    fig, ax = plt.subplots(figsize=(10, 4))
    ax.plot(cycles, clk_in_values, marker="o", linewidth=2, label="clk_in")
    ax.plot(cycles, clk_out_values, marker="o", linewidth=2, label="clk_out")
    ax.set_title("clk_in vs clk_out")
    ax.set_xlabel("Cycle")
    ax.set_ylabel("Edge Time (ps)")
    ax.grid(True, alpha=0.3)
    ax.legend()
    fig.tight_layout()
    buffer = BytesIO()
    fig.savefig(buffer, format="png", dpi=150, bbox_inches="tight")
    buffer.seek(0)
    display(Image(data=buffer.getvalue()))
    plt.close(fig)


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

    trace_output = widgets.Output()
    plot_output = widgets.Output()

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

        with trace_output:
            trace_output.clear_output(wait=True)
            display(
                HTML(
                    "<div>clk_in -> phase detector -> controller -> DCDL, "
                    "with clk_out fed back into the phase detector</div>"
                )
            )
            display(HTML("<div>phase_error_ps = clk_out - clk_in</div>"))
            display(HTML("<h3>Closed-Loop Trace</h3>"))
            _render_table(trace)
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

        with plot_output:
            plot_output.clear_output(wait=True)
            display(HTML("<h3>Clock Plot</h3>"))
            _render_clk_plot(trace)

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
            trace_output,
            plot_output,
        ]
    )
    return ui
