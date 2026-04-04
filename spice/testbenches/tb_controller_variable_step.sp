* ============================================================
* Testbench: controller (variable-step) post-layout characterization
* ============================================================

* --- Technology models ---
* UPDATE THIS PATH to your local sky130 install
.lib "/home/xtoml/.ciel/sky130A/libs.tech/ngspice/sky130.lib.spice" tt

* --- Sky130 standard cell transistor-level models ---
.include "/home/xtoml/.ciel/ciel/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.ref/sky130_fd_sc_hd/spice/sky130_fd_sc_hd.spice"
* Uncomment if your netlist uses ef cells (decap_12 filler):
* .include "/path/to/sky130A/libs.ref/sky130_ef_sc_hd/spice/sky130_ef_sc_hd.spice"

* --- Post-layout extracted netlist ---
.include "/home/xtoml/CaC_Spring26/spice/netlists/controller_variable.spice"

* ============================================================
* Parameters & Supplies
* ============================================================
.param vdd_val = 1.8
Vdd  VPWR 0 DC vdd_val
Vss  VGND 0 DC 0

* Clock: 10ns period (100 MHz)
Vclk clk_node VGND PULSE(0 vdd_val 0 50p 50p 5n 10n)

* Reset: assert for 20ns, then release
Vrst rst_node VGND PWL(0 vdd_val 19.9n vdd_val 20n 0)

* ============================================================
* Stimulus: UP/DOWN sequences designed to exercise all 3 step sizes
*
* Variable-step controller behavior (default params):
*   same_dir_count < 4  (MED_THRESH) => step = 1
*   same_dir_count >= 4 (MED_THRESH) => step = 2
*   same_dir_count >= 8 (BIG_THRESH) => step = 4
*   Direction change resets same_dir_count to 1
*
* Phase 1 (20-220ns):   UP=1   — 20 cycles of sustained UP
*   Expect: cycles 1-3 step=1, cycles 4-7 step=2, cycles 8+ step=4
*   ctrl: 32->33->34->35->37->39->41->43->47->51->55->59->63(sat)
*
* Phase 2 (220-320ns):  IDLE   — 10 cycles, resets same_dir_count
*
* Phase 3 (320-520ns):  DOWN=1 — 20 cycles of sustained DOWN
*   Expect same acceleration pattern downward from 63
*
* Phase 4 (520-570ns):  IDLE   — 5 cycles, resets count
*
* Phase 5 (570-670ns):  Alternating UP/DOWN every 3 cycles
*   Tests direction-change reset behavior — steps should stay at 1
*
* Phase 6 (670-870ns):  UP=1   — 20 cycles sustained UP again
*   Confirm acceleration restarts from step=1
*
* Phase 7 (870-900ns):  IDLE
* ============================================================
Vup   up_node   VGND PWL(
+   0      0
+   19.9n  0
+   20n    vdd_val
+   219.9n vdd_val
+   220n   0
+   319.9n 0
+   320n   0
+   569.9n 0
+   570n   vdd_val
+   599.9n vdd_val
+   600n   0
+   629.9n 0
+   630n   vdd_val
+   659.9n vdd_val
+   660n   0
+   669.9n 0
+   670n   vdd_val
+   869.9n vdd_val
+   870n   0 )

Vdown down_node VGND PWL(
+   0      0
+   319.9n 0
+   320n   vdd_val
+   519.9n vdd_val
+   520n   0
+   569.9n 0
+   570n   0
+   599.9n 0
+   600n   vdd_val
+   629.9n vdd_val
+   630n   0
+   659.9n 0
+   660n   vdd_val
+   669.9n vdd_val
+   670n   0 )

* ============================================================
* DUT Instantiation
*
* IMPORTANT: You MUST check the .subckt line in your extracted
* controller.spice and match the port order EXACTLY.
*
* If the port order is the same as the coarse/fine controller:
*   .subckt controller VGND VPWR clk_in ctrl[0] ctrl[1] ctrl[2]
*                      ctrl[3] ctrl[4] ctrl[5] down rst up
* Then use:
Xdut VGND VPWR clk_node ctrl0 ctrl1 ctrl2 ctrl3 ctrl4 ctrl5 down_node rst_node up_node controller
*
* If the port order differs, comment the line above and fix it.
* Run this command to check:
*   grep "^\.subckt controller" controller.spice
* ============================================================

* Small load caps on each output bit
Cload0 ctrl0 VGND 5f
Cload1 ctrl1 VGND 5f
Cload2 ctrl2 VGND 5f
Cload3 ctrl3 VGND 5f
Cload4 ctrl4 VGND 5f
Cload5 ctrl5 VGND 5f

* ============================================================
* Simulation
* ============================================================
.tran 10p 900n

* ============================================================
* Measurements
* ============================================================

* Propagation delay: clk rising edge -> ctrl0 first transition
.meas tran tpd_clk_ctrl0 TRIG v(clk_node) VAL=0.9 RISE=5
+                         TARG v(ctrl0)    VAL=0.9 RISE=1

* Average supply current over the active region
.meas tran avg_idd AVG i(Vdd) FROM=100n TO=800n

* ============================================================
* Interactive control block
* ============================================================
.control
run

echo ""
echo "=============================================="
echo " VARIABLE-STEP CONTROLLER CHARACTERIZATION"
echo "=============================================="
echo ""

print tpd_clk_ctrl0
print avg_idd

let power_uw = abs(avg_idd) * 1.8 * 1e6
echo "Estimated average power (uW):"
print power_uw

echo ""
echo "=============================================="

* --- Plot 1: Stimulus signals ---
plot v(clk_node) v(rst_node)+2 v(up_node)+4 v(down_node)+6
+    title "Stimulus: clk / rst / up / down"

* --- Plot 2: All 6 ctrl output bits ---
plot v(ctrl0) v(ctrl1)+2 v(ctrl2)+4 v(ctrl3)+6 v(ctrl4)+8 v(ctrl5)+10
+    title "ctrl[5:0] outputs"

* --- Plot 3: Supply current ---
plot i(Vdd) title "Supply current"

* --- Save waveform data ---
wrdata controller_vs_results.csv v(clk_node) v(ctrl0) v(ctrl1) v(ctrl2) v(ctrl3) v(ctrl4) v(ctrl5)

.endc
.end
