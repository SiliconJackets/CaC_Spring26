"""Notebook-native ipywidgets frontend for the DLL simulator."""

from __future__ import annotations

from dataclasses import asdict
import sys
from pathlib import Path

from IPython.display import HTML, display

try:
    import pandas as pd
except ImportError:  # pragma: no cover - optional dependency in notebooks
    pd = None

try:
    import ipywidgets as widgets
except ImportError:  # pragma: no cover - optional dependency in notebooks
    widgets = None

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    from simulator.gui_common import DCDLS, CONTROLLERS, PHASE_DETECTORS, run_closed_loop_simulation
else:
    from .gui_common import DCDLS, CONTROLLERS, PHASE_DETECTORS, run_closed_loop_simulation


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
    rows = [asdict(entry) for entry in trace]
    if pd is not None:
        display(pd.DataFrame(rows))
    else:
        display(rows)


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
    ctrl_max = (1 << defaults["ctrl_bits"]) - 1

    clk_period_ps = widgets.BoundedFloatText(
        value=float(defaults["default_clk_period_ps"]),
        min=1.0,
        step=10.0,
        description="Reference Clock Period (ps)",
        style={"description_width": "initial"},
        layout=widgets.Layout(width="100%"),
    )
    init_ctrl = widgets.BoundedIntText(
        value=int(min(defaults["default_init_ctrl"], ctrl_max)),
        min=0,
        max=ctrl_max,
        step=1,
        description="Initial Controller Code",
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
        max_ctrl = (1 << selected["ctrl_bits"]) - 1
        init_ctrl.max = max_ctrl
        init_ctrl.value = int(min(selected["default_init_ctrl"], max_ctrl))
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
            init_ctrl=int(init_ctrl.value),
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
            display(HTML("<h3>Summary</h3>"))
            display(
                HTML(
                    f"<div>Start: ctrl_idx={first.ctrl_idx}, "
                    f"cell_delay={first.cell_delay_ps:.2f} ps, "
                    f"phase_err={first.phase_error_ps:.2f} ps</div>"
                )
            )
            display(
                HTML(
                    f"<div>End: ctrl_idx={last.ctrl_idx}, "
                    f"cell_delay={last.cell_delay_ps:.2f} ps, "
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
        init_ctrl,
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
                [clk_period_ps, init_ctrl],
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
    display(ui)
    return ui
