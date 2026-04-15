"""Closed-loop testbench for FF1 PD + Saturate controller + NAND DCDL.

The output clock edge from the NAND DCDL is fed back into the FF1 phase
detector on every cycle:

    clk_in -> FF1 PD -> SaturateController -> NandDCDL -> clk_out -> FF1 PD
"""

from __future__ import annotations

import sys
from dataclasses import dataclass
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
    from simulator import NandDCDL, SaturateController, SingleFlipFlopPhaseDetector
else:
    from . import NandDCDL, SaturateController, SingleFlipFlopPhaseDetector


@dataclass(frozen=True)
class TraceEntry:
    cycle: int
    clk_in_edge_ps: float
    clk_out_edge_ps: float
    up: int
    down: int
    valid_time_ps: float
    ctrl_idx: int
    ctrl_word: int
    dcdl_delay_ps: float
    phase_error_ps: float


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


def run_testbench(
    clk_period_ps: float = 3013.87,
    init_ctrl: int = 50,
    num_cycles: int = 20,
) -> list[TraceEntry]:
    """Run the closed-loop FF1/controller/NAND-DCDL testbench."""
    pd = SingleFlipFlopPhaseDetector()
    controller = SaturateController(ctrl_bits=6, init_ctrl=init_ctrl)
    dcdl = IndexedNandDCDL(NandDCDL())

    controller.reset()
    controller.configure_pipeline(pd.prop_delay_ps, clk_period_ps)

    prev_delay_ps = dcdl.delay(controller.ctrl)
    trace: list[TraceEntry] = []

    for cycle in range(num_cycles):
        clk_in_edge_ps = cycle * clk_period_ps
        clk_out_edge_ps = (cycle - 1) * clk_period_ps + prev_delay_ps

        # Match the control polarity used by the DLL simulator:
        # the feedback/output edge is presented as the first timing input.
        up, down, valid_time_ps = pd.detect(clk_out_edge_ps, clk_in_edge_ps)
        controller.update(up, down)

        ctrl_idx = controller.ctrl
        ctrl_word = dcdl.ctrl_word(ctrl_idx)
        current_delay_ps = dcdl.delay(ctrl_idx)
        phase_error_ps = prev_delay_ps - clk_period_ps

        trace.append(
            TraceEntry(
                cycle=cycle,
                clk_in_edge_ps=clk_in_edge_ps,
                clk_out_edge_ps=clk_out_edge_ps,
                up=up,
                down=down,
                valid_time_ps=valid_time_ps,
                ctrl_idx=ctrl_idx,
                ctrl_word=ctrl_word,
                dcdl_delay_ps=current_delay_ps,
                phase_error_ps=phase_error_ps,
            )
        )

        prev_delay_ps = current_delay_ps

    return trace


def print_trace(trace: list[TraceEntry], clk_period_ps: float) -> None:
    print("FF1 + SaturateController + NandDCDL closed-loop testbench")
    print(f"Reference clock period: {clk_period_ps:.2f} ps")
    print()
    print(
        "cycle  clk_in_edge  clk_out_edge  up  down  phase_err  "
        "ctrl_idx  ctrl_word            dcdl_delay"
    )

    for entry in trace:
        print(
            f"{entry.cycle:5d}  {entry.clk_in_edge_ps:11.2f}  {entry.clk_out_edge_ps:12.2f}  "
            f"{entry.up:2d}  {entry.down:4d}  {entry.phase_error_ps:9.2f}  "
            f"{entry.ctrl_idx:8d}  0x{entry.ctrl_word:016x}  {entry.dcdl_delay_ps:10.2f}"
        )

    first = trace[0]
    last = trace[-1]
    print()
    print(
        f"Start: ctrl_idx={first.ctrl_idx}, delay={first.dcdl_delay_ps:.2f} ps, "
        f"phase_err={first.phase_error_ps:.2f} ps"
    )
    print(
        f"End:   ctrl_idx={last.ctrl_idx}, delay={last.dcdl_delay_ps:.2f} ps, "
        f"phase_err={last.phase_error_ps:.2f} ps"
    )


if __name__ == "__main__":
    clk_period_ps = 3013.87
    trace = run_testbench(clk_period_ps=clk_period_ps, init_ctrl=50)
    print_trace(trace, clk_period_ps)
