"""Colab/Jupyter-friendly Streamlit frontend using streamlit-jupyter-supported APIs."""

from __future__ import annotations

from dataclasses import asdict

import sys
from pathlib import Path

import streamlit as st

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    from simulator.gui_common import DCDLS, CONTROLLERS, PHASE_DETECTORS, run_closed_loop_simulation
else:
    from .gui_common import DCDLS, CONTROLLERS, PHASE_DETECTORS, run_closed_loop_simulation


def _parse_float(label: str, value: str, min_value: float | None = None) -> float:
    try:
        parsed = float(value)
    except ValueError as exc:
        raise ValueError(f"{label} must be a number.") from exc

    if min_value is not None and parsed < min_value:
        raise ValueError(f"{label} must be at least {min_value}.")

    return parsed


def _parse_int(label: str, value: str, min_value: int | None = None, max_value: int | None = None) -> int:
    try:
        parsed = int(value)
    except ValueError as exc:
        raise ValueError(f"{label} must be an integer.") from exc

    if min_value is not None and parsed < min_value:
        raise ValueError(f"{label} must be at least {min_value}.")
    if max_value is not None and parsed > max_value:
        raise ValueError(f"{label} must be at most {max_value}.")

    return parsed


def render_streamlit_colab_app() -> None:
    """Render the simulator with Streamlit APIs supported by streamlit-jupyter."""

    st.title("DLL Simulator Frontend")
    st.caption("Notebook-friendly Streamlit version for streamlit-jupyter")
    st.caption("clk_in -> phase detector -> controller -> DCDL, with clk_out fed back into the phase detector")
    st.caption("phase_error_ps = clk_out - clk_in")

    phase_detector_name = st.selectbox("Phase Detector", list(PHASE_DETECTORS.keys()), index=0)
    controller_name = st.selectbox("Controller", list(CONTROLLERS.keys()), index=0)
    dcdl_name = st.selectbox("DCDL", list(DCDLS.keys()), index=0)

    defaults = DCDLS[dcdl_name]
    ctrl_max = (1 << defaults["ctrl_bits"]) - 1

    clk_period_ps_str = st.text_input(
        "Reference Clock Period (ps)",
        value=str(float(defaults["default_clk_period_ps"])),
    )
    init_ctrl_str = st.text_input(
        "Initial Controller Code",
        value=str(int(min(defaults["default_init_ctrl"], ctrl_max))),
    )
    clk_in_start_str = st.text_input(
        "clk_in Start (ps)",
        value="0.0",
    )

    use_auto_clk_out_start = st.checkbox("Auto clk_out Start", value=True)
    if use_auto_clk_out_start:
        clk_out_start = None
        st.caption("Using auto start: clk_out = clk_period - initial cell_delay")
        clk_out_start_str = None
    else:
        clk_out_start_str = st.text_input(
            "clk_out Start (ps)",
            value=str(float(defaults["default_clk_period_ps"] - 100.0)),
        )

    cycle_options = list(range(5, 101))
    default_cycle_index = cycle_options.index(20)
    num_cycles = st.selectbox("Number of Cycles", cycle_options, index=default_cycle_index)

    try:
        clk_period_ps = _parse_float("Reference Clock Period (ps)", clk_period_ps_str, min_value=1.0)
        init_ctrl = _parse_int("Initial Controller Code", init_ctrl_str, min_value=0, max_value=ctrl_max)
        clk_in_start = _parse_float("clk_in Start (ps)", clk_in_start_str)
        if use_auto_clk_out_start:
            clk_out_start = None
        else:
            clk_out_start = _parse_float("clk_out Start (ps)", clk_out_start_str)
    except ValueError as exc:
        st.write(f"Input error: {exc}")
        return

    trace = run_closed_loop_simulation(
        phase_detector_name=phase_detector_name,
        controller_name=controller_name,
        dcdl_name=dcdl_name,
        clk_period_ps=clk_period_ps,
        init_ctrl=init_ctrl,
        num_cycles=num_cycles,
        clk_in_start=clk_in_start,
        clk_out_start=clk_out_start,
    )

    first = trace[0]
    last = trace[-1]

    st.subheader("Closed-Loop Trace")
    st.dataframe([asdict(entry) for entry in trace])

    st.subheader("Summary")
    st.write(
        f"Start: ctrl_idx={first.ctrl_idx}, cell_delay={first.cell_delay_ps:.2f} ps, "
        f"phase_err={first.phase_error_ps:.2f} ps"
    )
    st.write(
        f"End: ctrl_idx={last.ctrl_idx}, cell_delay={last.cell_delay_ps:.2f} ps, "
        f"phase_err={last.phase_error_ps:.2f} ps"
    )


if __name__ == "__main__":
    render_streamlit_colab_app()
