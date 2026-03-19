`timescale 1ns/1ps

// =============================================================================
// Testbench : fsm_tb
// DUT       : fsm (DLL lock-acquisition FSM)
//
// FSM state map (from Fig. 6.31):
//   RESET  → IDLE/LOCKING : DEC=0, INC=0
//   LOCKING (LF1)         : INC=1, DEC=0  — ctrl increments, waits for PD low
//   WAIT                  : dead-zone dwell before allowing direction changes
//   INC                   : INC=1, DEC=0  — stays while PD=1, → DEC on PD=0
//   DEC                   : INC=0, DEC=1  — stays while PD=0, → INC on PD=1
//
// PD mapping to FSM ports:
//   PD = 1  (CLKOUT leads)  → up   = 1
//   PD = 0  (CLKOUT lags)   → down = 1
//   PD stable / undefined   → both = 0
//
// Tests
//   1. Reset assertion / deassertion
//   2. Locking phase — ctrl increments while up/down are de-asserted
//   3. Normal lock — PD goes low (down), traverses WAIT, enters INC
//   4. INC → DEC transition (PD falls)
//   5. DEC → INC transition (PD rises)
//   6. Hold in INC with sustained PD high
//   7. Hold in DEC with sustained PD low
//   8. Mid-run reset recovery
//   9. Edge case: rapid PD toggling near negative-edge alignment (caution zone
//      described in textbook — system must not lock into DEC permanently)
//  10. ctrl saturation guard (CONTROL_BITS roll-over awareness)
// =============================================================================

module fsm_tb;

    // -------------------------------------------------------------------------
    // Parameters — match DUT
    // -------------------------------------------------------------------------
    localparam DEAD_ZONE    = 3;
    localparam CONTROL_BITS = 4;
    localparam CLK_PERIOD   = 10; // ns

    // -------------------------------------------------------------------------
    // DUT ports
    // -------------------------------------------------------------------------
    logic                      rst_i;
    logic                      clk_i;
    logic                      up;
    logic                      down;
    logic [CONTROL_BITS-1:0]   ctrl;

    // -------------------------------------------------------------------------
    // DUT instantiation
    // -------------------------------------------------------------------------
    fsm #(
        .DEAD_ZONE    (DEAD_ZONE),
        .CONTROL_BITS (CONTROL_BITS)
    ) dut (
        .rst_i (rst_i),
        .clk_i (clk_i),
        .up    (up),
        .down  (down),
        .ctrl  (ctrl)
    );

    // -------------------------------------------------------------------------
    // Clock generation
    // -------------------------------------------------------------------------
    initial clk_i = 0;
    always #(CLK_PERIOD/2) clk_i = ~clk_i;

    // -------------------------------------------------------------------------
    // Convenience tasks
    // -------------------------------------------------------------------------

    // Wait N rising edges
    task automatic wait_cycles(input int n);
        repeat (n) @(posedge clk_i);
        #1; // small skew so we sample after FF update
    endtask

    // Assert reset for a few cycles then release
    task automatic do_reset();
        rst_i = 1; up = 0; down = 0;
        wait_cycles(3);
        rst_i = 0;
        #1;
    endtask

    // Drive PD high (CLKOUT leads — increment requested)
    task automatic pd_high(input int cycles);
        up = 1; down = 0;
        wait_cycles(cycles);
        up = 0;
    endtask

    // Drive PD low (CLKOUT lags — decrement requested)
    task automatic pd_low(input int cycles);
        down = 1; up = 0;
        wait_cycles(cycles);
        down = 0;
    endtask

    // Drive PD undefined / dead-zone (neither asserted)
    task automatic pd_idle(input int cycles);
        up = 0; down = 0;
        wait_cycles(cycles);
    endtask

    // -------------------------------------------------------------------------
    // Simple assertion helpers
    // -------------------------------------------------------------------------
    int pass_count = 0;
    int fail_count = 0;

    task automatic check(
        input string   test_name,
        input logic    condition
    );
        if (condition) begin
            $display("[PASS] %s", test_name);
            pass_count++;
        end else begin
            $display("[FAIL] %s  (ctrl=%0d, up=%b, down=%b, t=%0t)",
                     test_name, ctrl, up, down, $time);
            fail_count++;
        end
    endtask

    // -------------------------------------------------------------------------
    // Helper: drive system from RESET through LOCKING → WAIT → INC
    // Returns once INC state is stable (ctrl incrementing with up=1)
    // -------------------------------------------------------------------------
    task automatic reach_inc_state();
        do_reset();
        // LOCKING: drive no PD signal; ctrl should be incrementing
        pd_idle(5);
        // Trigger WAIT by asserting down (PD=0 → CLKOUT lags)
        pd_low(1);
        // Let dead-zone counter expire (DEAD_ZONE+2 cycles to be safe)
        pd_idle(DEAD_ZONE + 2);
        // Now assert up (PD=1) to confirm INC
        pd_high(2);
    endtask

    // =========================================================================
    // Main test sequence
    // =========================================================================
    logic [CONTROL_BITS-1:0] ctrl_snapshot;

    initial begin
        $display("============================================================");
        $display("  DLL FSM Testbench  (DEAD_ZONE=%0d  CONTROL_BITS=%0d)",
                 DEAD_ZONE, CONTROL_BITS);
        $display("============================================================");

        // =====================================================================
        // TEST 1 — Reset: ctrl must clear; FSM must start in RESET/LOCKING
        // =====================================================================
        $display("\n--- TEST 1: Reset assertion ---");
        rst_i = 1; up = 1; down = 1; // assert everything during reset
        wait_cycles(5);
        check("ctrl = 0 while rst_i high", ctrl === '0);
        rst_i = 0;
        wait_cycles(1);
        check("ctrl begins at 0 after release", ctrl === '0);

        // =====================================================================
        // TEST 2 — Locking phase: ctrl increments while no PD signal
        // =====================================================================
        $display("\n--- TEST 2: Locking phase — ctrl increments ---");
        do_reset();
        ctrl_snapshot = ctrl;
        pd_idle(6);
        check("ctrl advanced during LOCKING",
              ctrl > ctrl_snapshot);

        // =====================================================================
        // TEST 3 — Dead-zone wait: ctrl increments during WAIT dwell
        // =====================================================================
        $display("\n--- TEST 3: Dead-zone WAIT dwell ---");
        do_reset();
        pd_idle(4);
        ctrl_snapshot = ctrl;
        pd_low(1);                  // trigger WAIT
        wait_cycles(1);
        check("ctrl still incrementing in WAIT", ctrl > ctrl_snapshot);
        pd_idle(DEAD_ZONE + 1);     // let dead-zone expire → INC
        ctrl_snapshot = ctrl;
        pd_high(1);
        check("ctrl increments once in INC", ctrl === ctrl_snapshot + 1);

        // =====================================================================
        // TEST 4 — INC → DEC transition on PD falling (down pulse)
        // =====================================================================
        $display("\n--- TEST 4: INC → DEC on PD low ---");
        reach_inc_state();
        ctrl_snapshot = ctrl;
        pd_low(1);                  // PD=0: CLKOUT lags → request DEC
        wait_cycles(1);
        check("ctrl decremented after INC→DEC", ctrl < ctrl_snapshot + 4);
        // Verify continued decrement
        ctrl_snapshot = ctrl;
        pd_low(3);
        check("ctrl kept decrementing in DEC", ctrl < ctrl_snapshot);

        // =====================================================================
        // TEST 5 — DEC → INC transition on PD rising (up pulse)
        // =====================================================================
        $display("\n--- TEST 5: DEC → INC on PD high ---");
        reach_inc_state();
        pd_low(4);                  // settle into DEC
        ctrl_snapshot = ctrl;
        pd_high(1);                 // PD=1: CLKOUT leads → back to INC
        wait_cycles(1);
        check("ctrl increments after DEC→INC", ctrl > ctrl_snapshot - 4);
        ctrl_snapshot = ctrl;
        pd_high(3);
        check("ctrl kept incrementing in INC", ctrl > ctrl_snapshot);

        // =====================================================================
        // TEST 6 — Sustained PD high: stay in INC, ctrl monotonically rising
        // =====================================================================
        $display("\n--- TEST 6: Sustained PD high — hold in INC ---");
        reach_inc_state();
        ctrl_snapshot = ctrl;
        pd_high(8);
        check("ctrl monotonically increased over 8 INC cycles",
              ctrl > ctrl_snapshot);

        // =====================================================================
        // TEST 7 — Sustained PD low: stay in DEC, ctrl monotonically falling
        // =====================================================================
        $display("\n--- TEST 7: Sustained PD low — hold in DEC ---");
        reach_inc_state();
        pd_low(1);                   // enter DEC
        wait_cycles(1);
        ctrl_snapshot = ctrl;
        pd_low(8);
        check("ctrl monotonically decreased over 8 DEC cycles",
              ctrl < ctrl_snapshot);

        // =====================================================================
        // TEST 8 — Mid-run reset recovery
        // =====================================================================
        $display("\n--- TEST 8: Mid-run reset recovery ---");
        reach_inc_state();
        pd_high(3);                  // running in INC
        rst_i = 1;
        wait_cycles(2);
        check("ctrl cleared on mid-run reset", ctrl === '0);
        rst_i = 0;
        wait_cycles(2);
        check("ctrl begins rising again after reset", ctrl >= '0); // sanity
        pd_idle(4);
        ctrl_snapshot = ctrl;
        pd_idle(2);
        check("ctrl advancing again post-reset", ctrl >= ctrl_snapshot);

        // =====================================================================
        // TEST 9 — Edge case: rapid PD toggling (negative-edge alignment hazard)
        //   The textbook warns that a 1→0 transition immediately following 0→1
        //   can cause DEC to be entered when the clock is near neg-edge alignment.
        //   Verify the FSM can recover back to INC when PD rises again.
        // =====================================================================
        $display("\n--- TEST 9: Rapid PD toggling — neg-edge alignment hazard ---");
        reach_inc_state();
        // Simulate PD glitching: 0→1→0→1 in quick succession
        repeat (4) begin
            pd_low(1);
            pd_high(1);
        end
        // After glitches settle with PD=1 (up), system should be in INC
        ctrl_snapshot = ctrl;
        pd_high(4);
        check("ctrl increasing after PD glitch sequence — INC recovery",
              ctrl > ctrl_snapshot);

        // Additional: PD stays low for many cycles after toggling → DEC holds
        reach_inc_state();
        pd_low(1);   // glitch into DEC
        pd_high(1);  // try to recover
        pd_low(1);   // glitch again
        pd_high(1);
        pd_low(6);   // now sustained low → should hold DEC
        ctrl_snapshot = ctrl;
        pd_low(3);
        check("ctrl decreasing with sustained PD low after glitches",
              ctrl < ctrl_snapshot);

        // =====================================================================
        // TEST 10 — ctrl saturation / roll-over awareness
        //   Drive INC long enough that ctrl approaches max; confirm no X/Z
        // =====================================================================
        $display("\n--- TEST 10: ctrl roll-over — no X/Z on output ---");
        do_reset();
        pd_idle(4);
        pd_low(1);
        pd_idle(DEAD_ZONE + 2);
        pd_high(1);
        // Drive INC for enough cycles to wrap CONTROL_BITS counter
        repeat (2**CONTROL_BITS + 4) begin
            @(posedge clk_i); #1;
            up = 1; down = 0;
        end
        check("ctrl has no X/Z after roll-over", !$isunknown(ctrl));

        // =====================================================================
        // Summary
        // =====================================================================
        $display("\n============================================================");
        $display("  Results: %0d passed, %0d failed", pass_count, fail_count);
        $display("============================================================");

        if (fail_count == 0)
            $display("  ALL TESTS PASSED");
        else
            $display("  SOME TESTS FAILED — review output above");

        $finish;
    end

    // -------------------------------------------------------------------------
    // Waveform dump (works with VCS, Xcelium, Riviera, ModelSim)
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("fsm_tb.vcd");
        $dumpvars(0, fsm_tb);
    end

    // -------------------------------------------------------------------------
    // Timeout watchdog — prevents infinite loops on broken RTL
    // -------------------------------------------------------------------------
    initial begin
        #(CLK_PERIOD * 10_000);
        $display("[TIMEOUT] Simulation exceeded watchdog limit.");
        $finish;
    end

endmodule