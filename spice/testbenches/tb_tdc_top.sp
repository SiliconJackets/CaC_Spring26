* ============================================================
* Testbench: TDC (tdc_top)
* Drive CLK_IN and EVENT_IN, observe TDC_OUT[0:2]
* ============================================================

.lib "/Users/phevos/.ciel/ciel/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.tech/ngspice/sky130.lib.spice" tt
.include "../netlists/tdc_top.spice"

* ============================================================
* Parameters
* ============================================================
.param vdd_val     = 1.8
.param clk_period  = 10n
.param half_period = {clk_period / 2}
.param rise_fall   = 50p
.param rst_width   = 30n

* ============================================================
* Power Supplies
* ============================================================
Vdd  VPWR 0 DC {vdd_val}
Vss  VGND 0 DC 0

* ============================================================
* Reset -- held high for 30ns then released
* ============================================================
Vrst RST 0 PWL(
+   0n                 {vdd_val}
+   {rst_width - 0.1n} {vdd_val}
+   {rst_width}        0
+ )

* ============================================================
* Input Clock
* ============================================================
Vclk_in CLK_IN 0 PULSE(
+   0           {vdd_val}
+   {rst_width} {rise_fall}
+   {rise_fall} {half_period} {half_period} {clk_period}
+ )

* ============================================================
* Event Input
* A single pulse event starting 35ns into the sim (5ns after
* reset releases and clock is stable), lasting 5ns.
* Adjust EVENT_DELAY and EVENT_WIDTH to test different phases.
* ============================================================
.param event_delay = 35n
.param event_width = 5n

Vevent EVENT_IN 0 PULSE(
+   0             {vdd_val}
+   {event_delay} {rise_fall}
+   {rise_fall}   {event_width} {clk_period}
+ )

* ============================================================
* DUT
* Port order from .subckt tdc_top:
*   VGND VPWR clk_in event_in rst tdc_out[0] tdc_out[1] tdc_out[2]
*
* tdc_out[0:2] are OUTPUTS — observe only, no drivers.
* ============================================================
Xdut
+   VGND VPWR
+   CLK_IN
+   EVENT_IN
+   RST
+   TDC_OUT_0 TDC_OUT_1 TDC_OUT_2
+   tdc_top

* ============================================================
* Simulation
* ============================================================
.tran 10p 100n

.control
run
shell mkdir -p ../results
wrdata ../results/tdc_top_results.csv
+   v(CLK_IN) v(EVENT_IN)
+   v(TDC_OUT_0) v(TDC_OUT_1) v(TDC_OUT_2)
quit
.endc
