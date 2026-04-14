"""Comprehensive tests for the DLL simulator."""
import sys
from simulator import (
    PhaseDetector,
    SaturateController, FilteredController, LockedController,
    TwoModeController, VariableStepController,
    BehavioralDCDL, InverterDCDL, InverterCondDCDL,
    InverterGlitchFreeDCDL, NandDCDL, VernierDCDL,
    simulate,
)

fails = []

def check(name, cond, msg=""):
    if not cond:
        fails.append(f"FAIL: {name} -- {msg}")
        print(f"  FAIL: {name} -- {msg}")
    else:
        print(f"  ok: {name}")


def first_zero(r):
    return next((i for i, e in enumerate(r["phase_error"]) if e == 0.0), None)


# =====================================================================
# PART 1: PhaseDetector
# =====================================================================
print("--- PhaseDetector ---")
pd_t = PhaseDetector(up_prop_delay_ps=80.0, down_prop_delay_ps=120.0)
u, d, vt = pd_t.detect(0, 500)
check("PD: clk_in leads -> up", u == 1 and d == 0)
check("PD: up uses up_delay", vt == 500.0 + 80.0)

u, d, vt = pd_t.detect(500, 0)
check("PD: clk_out leads -> down", u == 0 and d == 1)
check("PD: down uses down_delay", vt == 500.0 + 120.0)

u, d, vt = pd_t.detect(100, 100)
check("PD: aligned", u == 0 and d == 0)
check("PD: aligned valid_time (no path delay)", vt == 100.0)

check("PD: prop_delay_ps = max", pd_t.prop_delay_ps == 120.0)

pd0 = PhaseDetector()
u, d, vt = pd0.detect(0, 1)
check("PD: zero prop delay", vt == 1.0)

# =====================================================================
# PART 2: Controllers standalone
# =====================================================================
print("\n--- SaturateController ---")
c = SaturateController(ctrl_bits=4, init_ctrl=8)
check("Sat: init", c.ctrl == 8)
c.update(1, 0); check("Sat: up", c.ctrl == 9)
c.update(0, 1); check("Sat: down", c.ctrl == 8)
c.update(1, 1); check("Sat: both=hold", c.ctrl == 8)
c.update(0, 0); check("Sat: neither=hold", c.ctrl == 8)
c2 = SaturateController(ctrl_bits=3, init_ctrl=7)
c2.update(1, 0); check("Sat: max clamp", c2.ctrl == 7)
c3 = SaturateController(ctrl_bits=3, init_ctrl=0)
c3.update(0, 1); check("Sat: min clamp", c3.ctrl == 0)
c.reset(); check("Sat: reset", c.ctrl == 8)

print("\n--- FilteredController ---")
fc = FilteredController(ctrl_bits=6, init_ctrl=32, filter_len=3)
for _ in range(2):
    fc.update(1, 0)
check("Filt: 2 ups < threshold", fc.ctrl == 32)
fc.update(1, 0)
check("Filt: 3 ups = threshold", fc.ctrl == 33)
fc.update(0, 1)  # direction change resets
fc.update(1, 0)
fc.update(1, 0)
check("Filt: dir change resets count", fc.ctrl == 33)
fc.update(1, 0)
check("Filt: completes after reset", fc.ctrl == 34)
# Idle resets counters
fc2 = FilteredController(ctrl_bits=6, init_ctrl=32, filter_len=2)
fc2.update(1, 0)
fc2.update(0, 0)  # idle
fc2.update(1, 0)
check("Filt: idle resets count", fc2.ctrl == 32)
fc2.update(1, 0)
check("Filt: fresh streak works", fc2.ctrl == 33)
fc2.reset(); check("Filt: reset", fc2.ctrl == 32)

print("\n--- LockedController ---")
lc = LockedController(ctrl_bits=6, init_ctrl=10, acquire_step=5,
                      track_step=1, quiet_cycles=3)
check("Lock: init mode", lc.mode == "acquire")
lc.update(1, 0); check("Lock: acquire +5", lc.ctrl == 15)
lc.update(0, 1); check("Lock: acquire -5", lc.ctrl == 10)
for _ in range(3):
    lc.update(0, 0)
check("Lock: track mode", lc.mode == "track")
lc.update(1, 0); check("Lock: track +1", lc.ctrl == 11)
lc.update(0, 1); check("Lock: track -1", lc.ctrl == 10)
# Saturate
lc2 = LockedController(ctrl_bits=3, init_ctrl=6, acquire_step=4)
lc2.update(1, 0); check("Lock: acquire clamp max", lc2.ctrl == 7)
lc.reset()
check("Lock: reset mode", lc.mode == "acquire")
check("Lock: reset ctrl", lc.ctrl == 10)

print("\n--- TwoModeController ---")
tc = TwoModeController(ctrl_bits=6, init_ctrl=0, coarse_bits=3,
                       fine_bits=3, switch_quiet=2)
check("2Mode: init", tc.coarse == 0 and tc.fine == 0)
tc.update(1, 0)
check("2Mode: coarse +1", tc.coarse == 1 and tc.ctrl == 8)
tc.update(0, 1)
check("2Mode: coarse -1", tc.coarse == 0 and tc.ctrl == 0)
tc.update(1, 0)  # coarse=1
for _ in range(2):
    tc.update(0, 0)
check("2Mode: switch to fine", tc.mode == "fine")
tc.update(1, 0)
check("2Mode: fine +1", tc.fine == 1 and tc.coarse == 1)
check("2Mode: fine ctrl value", tc.ctrl == (1 << 3) | 1)
# Coarse saturation
tc2 = TwoModeController(ctrl_bits=6, init_ctrl=0b111000,
                        coarse_bits=3, fine_bits=3)
tc2.update(1, 0)
check("2Mode: coarse max clamp", tc2.coarse == 7)
tc.reset()
check("2Mode: reset", tc.mode == "coarse" and tc.ctrl == 0)

print("\n--- VariableStepController ---")
vc = VariableStepController(ctrl_bits=6, init_ctrl=32, big_step=4,
                            med_step=2, big_thresh=4, med_thresh=2)
vc.update(1, 0); check("VStep: count=1 step=1", vc.ctrl == 33)
vc.update(1, 0); check("VStep: count=2 step=2", vc.ctrl == 35)
vc.update(1, 0); check("VStep: count=3 step=2", vc.ctrl == 37)
vc.update(1, 0); check("VStep: count=4 step=4", vc.ctrl == 41)
vc.update(0, 1); check("VStep: dir change", vc.ctrl == 40)
vc.update(0, 0)  # idle resets
vc.update(0, 1); check("VStep: fresh down step=1", vc.ctrl == 39)
vc.reset(); check("VStep: reset", vc.ctrl == 32)

# =====================================================================
# PART 3: DCDLs
# =====================================================================
print("\n--- BehavioralDCDL ---")
bd = BehavioralDCDL(num_cells=10, first_cell_delay_ps=200,
                    remaining_cell_delay_ps=150)
check("Behav: ctrl=0", bd.delay(0) == 0.0)
check("Behav: ctrl=1", bd.delay(1) == 200.0)
check("Behav: ctrl=2", bd.delay(2) == 350.0)
check("Behav: ctrl=10", bd.delay(10) == 200 + 9 * 150)
check("Behav: ctrl>max clamped", bd.delay(20) == bd.delay(10))

print("\n--- InverterDCDL ---")
id4 = InverterDCDL(4, 50, 40, mux_delay_ps=25)
check("Inv4: mux_levels=2", id4.mux_levels == 2)
check("Inv4: tap0", id4.delay(0) == 50 + 50)
check("Inv4: tap3", id4.delay(3) == (50 + 3 * 40) + 50)
id6 = InverterDCDL(6, 50, 40, mux_delay_ps=25)
check("Inv6: mux_levels=3", id6.mux_levels == 3)
id1 = InverterDCDL(1, 50, 40, mux_delay_ps=25)
check("Inv1: mux_levels=0", id1.mux_levels == 0)
check("Inv1: tap0", id1.delay(0) == 50)
id8 = InverterDCDL(8, 50, 40, mux_delay_ps=25)
check("Inv8: mux_levels=3", id8.mux_levels == 3)
check("Inv8: monotonic", all(id8.delay(k) < id8.delay(k + 1) for k in range(7)))

print("\n--- InverterCondDCDL ---")
ic = InverterCondDCDL(4, 50, 40, mux_delay_ps=25, xnor_delay_ps=15)
check("InvCond: tap0", ic.delay(0) == 50 + 50 + 15)
check("InvCond: tap3", ic.delay(3) == 170 + 50 + 15)

print("\n--- InverterGlitchFreeDCDL ---")
gf = InverterGlitchFreeDCDL(4, 50, 40, nand_delay_ps=20)
check("GF: nand_tree_depth=2", gf.nand_tree_depth == 2)
check("GF: tap0", gf.delay(0) == 0 + 40 + 3 * 20)      # 100
check("GF: tap1", gf.delay(1) == 50 + 40 + 60)          # 150
check("GF: tap3", gf.delay(3) == (50 + 2 * 40) + 40 + 60)  # 230
gf8 = InverterGlitchFreeDCDL(8, 50, 40, nand_delay_ps=20)
check("GF8: nand_tree_depth=3", gf8.nand_tree_depth == 3)
check("GF8: tap0", gf8.delay(0) == 40 + 4 * 20)         # 120

print("\n--- NandDCDL ---")
nd = NandDCDL(4, 60, 45)
check("NAND: Q=0001", nd.delay(0b0001) == 60.0)
check("NAND: Q=0010", nd.delay(0b0010) == 60 + 45)
check("NAND: Q=0100", nd.delay(0b0100) == 60 + 2 * 45)
check("NAND: Q=1000", nd.delay(0b1000) == 60 + 3 * 45)
nd8 = NandDCDL(8, 70, 50)
check("NAND8: Q=bit7", nd8.delay(1 << 7) == 70 + 7 * 50)

print("\n--- VernierDCDL ---")
vd = VernierDCDL(4, 50, 40, fast_cell_delay_ps=15, mux_delay_ps=10)
check("Vern: cross@0", vd.delay(0b0001) == 0 + 10 + 4 * 15)
check("Vern: cross@1", vd.delay(0b0010) == 50 + 10 + 3 * 15)
check("Vern: cross@3", vd.delay(0b1000) == (50 + 2 * 40) + 10 + 1 * 15)
check("Vern: no cross", vd.delay(0b0000) == 50 + 3 * 40)
check("Vern: multi-bit uses lowest", vd.delay(0b1010) == vd.delay(0b0010))

# =====================================================================
# PART 4: DLL simulate — all controllers x Behavioral DCDL
# =====================================================================
T = 5000.0
pd = PhaseDetector()
dcdl_b = BehavioralDCDL(63, 100, 100)  # ctrl=50 -> 5000ps

print("\n--- DLL: Saturate x Behavioral ---")
r = simulate(pd, SaturateController(6, 0), dcdl_b, T, 70)
check("Sat+Behav: locks", r["phase_error"][-1] == 0.0)
check("Sat+Behav: ctrl=50", r["ctrl"][-1] == 50)
fz_sat = first_zero(r)

print("\n--- DLL: Saturate x Behavioral (from above) ---")
r2 = simulate(pd, SaturateController(6, 63), dcdl_b, T, 70)
check("Sat+Behav above: locks", r2["phase_error"][-1] == 0.0)
check("Sat+Behav above: ctrl=50", r2["ctrl"][-1] == 50)

print("\n--- DLL: Filtered x Behavioral ---")
r3 = simulate(pd, FilteredController(6, 0, filter_len=3), dcdl_b, T, 200)
check("Filt+Behav: locks", r3["phase_error"][-1] == 0.0)
check("Filt+Behav: ctrl=50", r3["ctrl"][-1] == 50)
fz_filt = first_zero(r3)
check("Filt slower than Sat", fz_filt > fz_sat)
print(f"  Filtered locks at cycle {fz_filt}")

print("\n--- DLL: Locked x Behavioral ---")
# init=2, step=4 -> 2,6,10,...,50 (12 steps in acquire)
r4 = simulate(pd, LockedController(6, 2, acquire_step=4, track_step=1,
              quiet_cycles=4), dcdl_b, T, 40)
check("Lock+Behav: locks", r4["phase_error"][-1] == 0.0)
check("Lock+Behav: ctrl=50", r4["ctrl"][-1] == 50)
fz_lock = first_zero(r4)
check("Lock faster than Sat", fz_lock < fz_sat)
print(f"  Locked locks at cycle {fz_lock}")

print("\n--- DLL: VariableStep x Behavioral ---")
r5 = simulate(pd, VariableStepController(6, 0), dcdl_b, T, 70)
check("VStep+Behav: locks", r5["phase_error"][-1] == 0.0)
check("VStep+Behav: ctrl=50", r5["ctrl"][-1] == 50)
fz_vs = first_zero(r5)
check("VStep faster than Sat", fz_vs < fz_sat)
print(f"  VarStep locks at cycle {fz_vs}")

print("\n--- DLL: TwoMode x Behavioral ---")
# coarse step=8 in ctrl space, fine step=1. Target ctrl=50=0b110010
# Coarse: 0,8,16,24,32,40,48,56 -> overshoots between 48 and 56
# After quiet -> fine mode adjusts from coarse=6 (48) upward
# coarse=6 (48) can't reach 50 with step=8 oscillation.
# Use a target divisible by coarse granularity (8): 100ps/cell, T=4800
# ctrl=48=coarse6,fine0 -> 4800. Locks exactly.
dcdl_2m = BehavioralDCDL(63, 100, 100)
r6 = simulate(pd, TwoModeController(6, 0, coarse_bits=3, fine_bits=3,
              switch_quiet=3), dcdl_2m, 4800, 60)
final_err = abs(r6["phase_error"][-1])
check("2Mode+Behav: converges", final_err == 0,
      f"err={r6['phase_error'][-1]}")
print(f"  TwoMode final ctrl={r6['ctrl'][-1]}, err={r6['phase_error'][-1]}")

# =====================================================================
# PART 5: DLL with gate-level DCDLs
# =====================================================================
print("\n--- DLL: Saturate x InverterDCDL ---")
# 8 taps: delay = (200+k*150) + 3*50 = 350+150k
# T=1250 -> 350+150k=1250 -> k=6
id_dcdl = InverterDCDL(8, 200, 150, mux_delay_ps=50)
r7 = simulate(pd, SaturateController(3, 0), id_dcdl, 1250, 30)
check("Sat+Inv: locks", r7["phase_error"][-1] == 0.0)
check("Sat+Inv: ctrl=6", r7["ctrl"][-1] == 6)

print("\n--- DLL: Saturate x InverterCondDCDL ---")
# 4 taps: delay = (200+k*150) + 2*50 + 30 = 330+150k
# T=780 -> k=3
ic_dcdl = InverterCondDCDL(4, 200, 150, mux_delay_ps=50, xnor_delay_ps=30)
r8 = simulate(pd, SaturateController(2, 0), ic_dcdl, 780, 20)
check("Sat+InvCond: locks", r8["phase_error"][-1] == 0.0)
check("Sat+InvCond: ctrl=3", r8["ctrl"][-1] == 3)

print("\n--- DLL: Saturate x InverterGlitchFreeDCDL ---")
# 4 taps: tap k = cells_delay(k) + 40 + 60
# tap0: 0+100=100, tap1: 50+100=150, tap2: 90+100=190, tap3: 130+100=230
gf_dcdl = InverterGlitchFreeDCDL(4, 50, 40, nand_delay_ps=20)
r9 = simulate(pd, SaturateController(2, 0), gf_dcdl, 190, 20)
check("Sat+GF: locks", r9["phase_error"][-1] == 0.0)
check("Sat+GF: ctrl=2", r9["ctrl"][-1] == 2)

# =====================================================================
# PART 6: Pipeline latency
# =====================================================================
print("\n--- Pipeline latency ---")
dcdl_u = BehavioralDCDL(63, 100, 100)

r_l0 = simulate(PhaseDetector(), SaturateController(6, 0), dcdl_u, T, 70)
fz0 = first_zero(r_l0)

# pipeline = 1500 < T -> extra=0 (use worst-case pd delay = 500)
r_l1 = simulate(PhaseDetector(up_prop_delay_ps=500, down_prop_delay_ps=400),
                SaturateController(6, 0, prop_delay_ps=1000), dcdl_u, T, 70)
fz1 = first_zero(r_l1)
check("Pipe: <T same speed", fz0 == fz1)

# pipeline = 7000 -> extra=1 (worst-case pd = 3000)
r_l2 = simulate(PhaseDetector(up_prop_delay_ps=3000, down_prop_delay_ps=2500),
                SaturateController(6, 0, prop_delay_ps=4000), dcdl_u, T, 70)
fz2 = first_zero(r_l2)
check("Pipe: 1 extra slower", fz2 is not None and fz2 > fz0)
print(f"  No latency: {fz0}, +1 extra: {fz2}")

# pipeline = 13000 -> extra=2 (worst-case pd = 5000)
r_l3 = simulate(PhaseDetector(up_prop_delay_ps=5000, down_prop_delay_ps=4500),
                SaturateController(6, 0, prop_delay_ps=8000), dcdl_u, T, 80)
fz3 = first_zero(r_l3)
check("Pipe: 2 extra even slower", fz3 is not None and fz3 > fz2)
print(f"  +2 extra: {fz3}")

# =====================================================================
# PART 7: Edge cases
# =====================================================================
print("\n--- Edge cases ---")

# 1 cycle
r_1c = simulate(pd, SaturateController(6, 0), dcdl_u, T, 1)
check("1 cycle runs", len(r_1c["ctrl"]) == 1)

# init_ctrl overflow/underflow clamped
check("init_ctrl > max clamped", SaturateController(3, 100).ctrl == 7)
check("init_ctrl < 0 clamped", SaturateController(3, -5).ctrl == 0)

# Reset after simulation restores state
c_rs = SaturateController(6, 10)
c_rs.update(1, 0)
c_rs.update(1, 0)
check("pre-reset", c_rs.ctrl == 12)
c_rs.reset()
check("post-reset", c_rs.ctrl == 10)

# Filtered with filter_len=1 acts like saturate
fc1 = FilteredController(6, 32, filter_len=1)
fc1.update(1, 0)
check("Filt len=1: instant", fc1.ctrl == 33)

# All trace arrays same length
r_len = simulate(pd, SaturateController(6, 0), dcdl_u, T, 42)
lens = {k: len(v) for k, v in r_len.items() if isinstance(v, list)}
check("Trace lengths", all(v == 42 for v in lens.values()), str(lens))

# Simulate is repeatable (reset works)
c_rep = SaturateController(6, 0)
r_a = simulate(pd, c_rep, dcdl_u, T, 50)
r_b = simulate(pd, c_rep, dcdl_u, T, 50)
check("Repeatable", r_a["ctrl"] == r_b["ctrl"])

# =====================================================================
# SUMMARY
# =====================================================================
print()
if fails:
    print(f"=== {len(fails)} FAILURES ===")
    for f in fails:
        print(f)
    sys.exit(1)
else:
    print("=== ALL TESTS PASSED ===")
