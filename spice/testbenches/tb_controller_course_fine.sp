* ============================================================
* Testbench: controller (coarse/fine) post-layout characterization
* ============================================================

* --- Technology models ---
* UPDATE THIS PATH to your local sky130 install
.lib "/home/xtoml/.ciel/sky130A/libs.tech/ngspice/sky130.lib.spice" tt

* --- Sky130 standard cell transistor-level models ---
* This is CRITICAL: the extracted netlist has black-boxed cells.
* You must include the actual transistor-level cell definitions
* so ngspice knows what's inside each standard cell.
*
* UPDATE THIS PATH - typical locations:
*   ~/.ciel/sky130A/libs.ref/sky130_fd_sc_hd/spice/sky130_fd_sc_hd.spice
*   $PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/spice/sky130_fd_sc_hd.spice
*   or for the ef cells:
*   $PDK_ROOT/sky130A/libs.ref/sky130_ef_sc_hd/spice/sky130_ef_sc_hd.spice
*
* Include the cell models BEFORE the extracted netlist so that
* the transistor-level definitions override the black-box stubs.
.include "/home/xtoml/.ciel/ciel/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.ref/sky130_fd_sc_hd/spice/sky130_fd_sc_hd.spice"

* --- Post-layout extracted netlist ---
* The black-box subckt definitions in this file will be ignored
* because the real ones were already loaded above.
.include "/home/xtoml/CaC_Spring26/spice/netlists/controller_course_fine.spice"

* ============================================================
* Parameters & Supplies
* ============================================================
.param vdd_val = 1.8
Vdd  VPWR 0 DC vdd_val
Vss  VGND 0 DC 0

* Clock: 100ns period (10 MHz)
Vclk clk_node VGND PULSE(0 vdd_val 0 50p 50p 5n 10n)

* Reset: assert for 20ns, then release
Vrst rst_node VGND PWL(0 vdd_val 19.9n vdd_val 20n 0)

* ============================================================
* Stimulus: UP/DOWN sequences
*   Phase 1  (20ns  - 220ns):  UP=1, DOWN=0  — coarse acquisition
*   Phase 2  (220ns - 420ns):  UP=0, DOWN=0  — idle (triggers mode switch)
*   Phase 3  (420ns - 620ns):  UP=1, DOWN=0  — fine mode response
*   Phase 4  (620ns - 820ns):  UP=0, DOWN=1  — fine mode reverse
*   Phase 5  (820ns - 900ns):  UP=0, DOWN=0  — idle
* ============================================================
Vup   up_node   VGND PWL(0 0  19.9n 0  20n vdd_val  219.9n vdd_val
+                         220n 0  419.9n 0  420n vdd_val  619.9n vdd_val
+                         620n 0)

Vdown down_node VGND PWL(0 0  619.9n 0  620n vdd_val  819.9n vdd_val
+                         820n 0)

* ============================================================
* DUT Instantiation
*
* Port order from extracted netlist:
*   .subckt controller VGND VPWR clk_in ctrl[0] ctrl[1] ctrl[2]
*                      ctrl[3] ctrl[4] ctrl[5] down rst up
*
* We map bracketed port names to bracket-free node names.
* ============================================================
Xdut VGND VPWR clk_node ctrl0 ctrl1 ctrl2 ctrl3 ctrl4 ctrl5 down_node rst_node up_node controller

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

* Propagation delay: clk rising edge -> ctrl0 changes
.meas tran tpd_clk_ctrl0 TRIG v(clk_node) VAL=0.9 RISE=5
+                         TARG v(ctrl0)    VAL=0.9 RISE=1

* Average supply current over the active region
.meas tran avg_idd AVG i(Vdd) FROM=100n TO=800n

* ============================================================
* Interactive control block
* ============================================================
.control
run

* Access measurements using the $& prefix to avoid "vector not found" warnings
echo ""
echo "========================================================="
echo "        COARSE/FINE CONTROLLER CHARACTERIZATION"
echo "========================================================="
echo ""
echo " Propagation Delay (clk->ctrl0):  $&tpd_clk_ctrl0 seconds"
echo " Average Supply Current (IDD):    $&avg_idd Amperes"

* Compute average power (let creates a vector, echo prints the scalar value)
let power_uw = abs(avg_idd) * 1.8 * 1e6
echo " Estimated Average Power:         $&power_uw uW"
echo ""
echo "========================================================="

* --- Plotting section ---
set color0=white
set color1=blue
set color2=red

* Plot Stimulus
plot v(clk_node) v(rst_node)+2 v(up_node)+4 v(down_node)+6 title "Stimulus: clk/rst/up/down"

* Plot Outputs
plot v(ctrl0) v(ctrl1)+2 v(ctrl2)+4 v(ctrl3)+6 v(ctrl4)+8 v(ctrl5)+10 title "ctrl[5:0] outputs"

* --- Save waveform data to CSV ---
* Note: This will create a 14-column file (Time/Value pairs for each signal)
wrdata controller_cf_results.csv v(clk_node) v(ctrl0) v(ctrl1) v(ctrl2) v(ctrl3) v(ctrl4) v(ctrl5)

.endc
.end
