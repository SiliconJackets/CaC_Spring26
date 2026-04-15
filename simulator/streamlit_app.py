"""Streamlit frontend for the DLL simulator."""

from __future__ import annotations

from dataclasses import asdict, dataclass

import streamlit as st

import sys
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    from simulator import (
        EdgeLevelPhaseDetector,
        FilteredController,
        InverterCondDCDL,
        InverterDCDL,
        InverterGlitchFreeDCDL,
        LockedController,
        NandDCDL,
        PFDPhaseDetector,
        SaturateController,
        SingleFlipFlopPhaseDetector,
        VariableStepController,
    )
else:
    from . import (
        EdgeLevelPhaseDetector,
        FilteredController,
        InverterCondDCDL,
        InverterDCDL,
        InverterGlitchFreeDCDL,
        LockedController,
        NandDCDL,
        PFDPhaseDetector,
        SaturateController,
        SingleFlipFlopPhaseDetector,
        VariableStepController,
    )


@dataclass(frozen=True)
class TraceEntry:
    cycle: int
    clk_in: float
    clk_out: float
    up: int
    down: int
    valid_time_ps: float
    ctrl_idx: int
    ctrl_word: str
    cell_delay_ps: float
    phase_error_ps: float
    lead_state: str


class IndexedNandDCDL:
    """Map scalar controller output to prefix-clear NAND DCDL words."""

    def __init__(self, inner: NandDCDL):
        self.inner = inner
        self.num_cells = inner.num_cells
        self.full_mask = (1 << self.num_cells) - 1

    def ctrl_word(self, ctrl_index: int) -> int:
        active_stages = max(0, min(ctrl_index, self.num_cells))
        if active_stages == 0:
            return self.full_mask
        return self.full_mask ^ ((1 << active_stages) - 1)

    def delay(self, ctrl_index: int) -> float:
        return self.inner.delay(self.ctrl_word(ctrl_index))


class BinaryTapDCDLAdapter:
    """Use the controller output directly as the DCDL control/tap."""

    def __init__(self, inner):
        self.inner = inner
        self.num_cells = inner.num_cells

    def ctrl_word(self, ctrl_index: int) -> int:
        return max(0, min(ctrl_index, self.num_cells - 1))

    def delay(self, ctrl_index: int) -> float:
        return self.inner.delay(self.ctrl_word(ctrl_index))


PHASE_DETECTORS = {
    "FF1": SingleFlipFlopPhaseDetector,
    "EdgeLevel": EdgeLevelPhaseDetector,
    "PFD": PFDPhaseDetector,
}

CONTROLLERS = {
    "Saturate": lambda bits, init: SaturateController(ctrl_bits=bits, init_ctrl=init),
    "Filtered": lambda bits, init: FilteredController(ctrl_bits=bits, init_ctrl=init, filter_len=3),
    "Locked": lambda bits, init: LockedController(
        ctrl_bits=bits,
        init_ctrl=init,
        acquire_step=2,
        track_step=1,
        quiet_cycles=4,
    ),
    "VariableStep": lambda bits, init: VariableStepController(
        ctrl_bits=bits,
        init_ctrl=init,
        big_step=2,
        med_step=1,
        big_thresh=4,
        med_thresh=2,
    ),
}

DCDLS = {
    "NandDCDL": {
        "factory": lambda: IndexedNandDCDL(NandDCDL()),
        "ctrl_bits": 6,
        "default_init_ctrl": 50,
        "default_clk_period_ps": 3013.87,
    },
    "InverterDCDL": {
        "factory": lambda: BinaryTapDCDLAdapter(
            InverterDCDL(
                num_cells=8,
                first_cell_delay_ps=200.0,
                remaining_cell_delay_ps=150.0,
                mux_delay_ps=50.0,
            )
        ),
        "ctrl_bits": 3,
        "default_init_ctrl": 6,
        "default_clk_period_ps": 950.0,
    },
    "InverterCondDCDL": {
        "factory": lambda: BinaryTapDCDLAdapter(
            InverterCondDCDL(
                num_cells=8,
                first_cell_delay_ps=200.0,
                remaining_cell_delay_ps=150.0,
                mux_delay_ps=50.0,
                xnor_delay_ps=30.0,
            )
        ),
        "ctrl_bits": 3,
        "default_init_ctrl": 6,
        "default_clk_period_ps": 980.0,
    },
    "InverterGlitchFreeDCDL": {
        "factory": lambda: BinaryTapDCDLAdapter(
            InverterGlitchFreeDCDL(
                num_cells=8,
                first_cell_delay_ps=50.0,
                remaining_cell_delay_ps=40.0,
                nand_delay_ps=20.0,
            )
        ),
        "ctrl_bits": 3,
        "default_init_ctrl": 6,
        "default_clk_period_ps": 290.0,
    },
}


def run_closed_loop_simulation(
    phase_detector_name: str,
    controller_name: str,
    dcdl_name: str,
    clk_period_ps: float,
    init_ctrl: int,
    num_cycles: int,
    clk_in_start: float,
    clk_out_start: float | None,
) -> list[TraceEntry]:
    pd = PHASE_DETECTORS[phase_detector_name]()
    dcdl = DCDLS[dcdl_name]["factory"]()
    controller = CONTROLLERS[controller_name](DCDLS[dcdl_name]["ctrl_bits"], init_ctrl)

    controller.reset()
    controller.configure_pipeline(pd.prop_delay_ps, clk_period_ps)

    prev_delay_ps = dcdl.delay(controller.ctrl)
    if clk_out_start is None:
        # Match ff1_saturate_nand_testbench default initialization.
        clk_out = clk_period_ps - prev_delay_ps
    else:
        clk_out = clk_out_start
    trace: list[TraceEntry] = []

    for cycle in range(num_cycles):
        clk_in = clk_in_start + cycle * clk_period_ps

        # Match the polarity used by the simulator DLL loop.
        up, down, valid_time_ps = pd.detect(clk_out, clk_in)
        controller.update(up, down)

        ctrl_idx = controller.ctrl
        ctrl_word = dcdl.ctrl_word(ctrl_idx)
        current_delay_ps = dcdl.delay(ctrl_idx)
        phase_error_ps = clk_out - clk_in
        eps = 1e-9
        if abs(phase_error_ps) <= eps:
            phase_error_ps = 0.0
            lead_state = "aligned"
        elif clk_in > clk_out:
            lead_state = "clk_in_gt_clk_out"
        else:
            lead_state = "clk_out_gt_clk_in"

        trace.append(
            TraceEntry(
                cycle=cycle,
                clk_in=round(clk_in, 2),
                clk_out=round(clk_out, 2),
                up=up,
                down=down,
                valid_time_ps=round(valid_time_ps, 2),
                ctrl_idx=ctrl_idx,
                ctrl_word=hex(ctrl_word),
                cell_delay_ps=round(current_delay_ps, 2),
                phase_error_ps=round(phase_error_ps, 2),
                lead_state=lead_state,
            )
        )

        delay_delta_ps = current_delay_ps - prev_delay_ps
        clk_out = clk_out + clk_period_ps + delay_delta_ps
        prev_delay_ps = current_delay_ps

    return trace


st.set_page_config(page_title="DLL Simulator", layout="wide")
st.title("DLL Simulator Frontend")
st.caption("clk_in -> phase detector -> controller -> DCDL, with clk_out fed back into the phase detector")
st.caption("phase_error_ps = clk_out - clk_in")

col1, col2, col3 = st.columns(3)
with col1:
    phase_detector_name = st.selectbox("Phase Detector", list(PHASE_DETECTORS.keys()), index=0)
with col2:
    controller_name = st.selectbox("Controller", list(CONTROLLERS.keys()), index=0)
with col3:
    dcdl_name = st.selectbox("DCDL", list(DCDLS.keys()), index=0)

defaults = DCDLS[dcdl_name]

col4, col5 = st.columns(2)
with col4:
    clk_period_ps = st.number_input(
        "Reference Clock Period (ps)",
        min_value=1.0,
        value=float(defaults["default_clk_period_ps"]),
        step=10.0,
    )
with col5:
    init_ctrl = st.number_input(
        "Initial Controller Code",
        min_value=0,
        max_value=(1 << defaults["ctrl_bits"]) - 1,
        value=int(min(defaults["default_init_ctrl"], (1 << defaults["ctrl_bits"]) - 1)),
        step=1,
    )

col6, col7 = st.columns(2)
with col6:
    clk_in_start = st.number_input(
        "clk_in Start (ps)",
        value=0.0,
        step=10.0,
    )
with col7:
    use_auto_clk_out_start = st.checkbox("Auto clk_out Start", value=True)
    if use_auto_clk_out_start:
        clk_out_start = None
        st.caption("Using auto start: clk_out = clk_period - initial cell_delay")
    else:
        clk_out_start = st.number_input(
            "clk_out Start (ps)",
            value=float(clk_period_ps - 100.0),
            step=10.0,
        )

num_cycles = st.slider("Number of Cycles", min_value=5, max_value=100, value=20, step=1)

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
st.dataframe([asdict(entry) for entry in trace], use_container_width=True)

st.subheader("Summary")
st.write(
    f"Start: ctrl_idx={first.ctrl_idx}, cell_delay={first.cell_delay_ps:.2f} ps, "
    f"phase_err={first.phase_error_ps:.2f} ps"
)
st.write(
    f"End: ctrl_idx={last.ctrl_idx}, cell_delay={last.cell_delay_ps:.2f} ps, "
    f"phase_err={last.phase_error_ps:.2f} ps"
)
