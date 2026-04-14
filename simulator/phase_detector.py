"""Phase detector for DLL simulation.

All RTL variants (PFD, edge, FF1, XOR) share the same detection logic;
they differ only in propagation delay (from SPICE).

The up and down paths have different propagation delays because
they go through different flip-flop/gate paths in the physical design.
"""

from __future__ import annotations


class PhaseDetector:
    """Detects which edge arrives first.

    RTL ports: clk_in, clk_out, rst -> up, down

    Parameters
    ----------
    up_prop_delay_ps : float
        Propagation delay on the up output path (ps).
    down_prop_delay_ps : float
        Propagation delay on the down output path (ps).
    """

    def __init__(self, up_prop_delay_ps: float = 0.0,
                 down_prop_delay_ps: float = 0.0):
        self.up_prop_delay_ps = up_prop_delay_ps
        self.down_prop_delay_ps = down_prop_delay_ps

    @property
    def prop_delay_ps(self) -> float:
        """Worst-case (maximum) prop delay — used by controller pipeline."""
        return max(self.up_prop_delay_ps, self.down_prop_delay_ps)

    def detect(self, clk_in_edge: float, clk_out_edge: float) -> tuple[int, int, float]:
        """Compare rising-edge arrival times.

        Returns (up, down, output_valid_time).
            up=1   -> clk_in leads, need more delay
            down=1 -> clk_out leads, need less delay

        output_valid_time uses the delay of whichever path is active.
        """
        latest_edge = max(clk_in_edge, clk_out_edge)
        if clk_in_edge < clk_out_edge:
            return 1, 0, latest_edge + self.up_prop_delay_ps
        elif clk_out_edge < clk_in_edge:
            return 0, 1, latest_edge + self.down_prop_delay_ps
        return 0, 0, latest_edge
