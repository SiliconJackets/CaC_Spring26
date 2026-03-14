`timescale 1ps/1ps

module tb_zdb_top;
    localparam integer CTRL_BITS     = 6;
    localparam integer DELAY_STEP    = 20;   // ps
    localparam integer MIN_DELAY     = 0;
    localparam integer INIT_CTRL     = 20;
    localparam integer TREE_DELAY_PS = 200;  // ps

    // Clock: 1 GHz -> 1000 ps period
    localparam real CLK_PERIOD   = 1000.0;  // ps
    localparam real CLK_HALF     = CLK_PERIOD / 2.0;

    // Convergence check: allow up to 512 cycles (??)
    localparam integer SIM_CYCLES = 512;

    // DUT ports
    logic clk_in;
    logic rst;
    wire  clk_out;
    wire  [CTRL_BITS-1:0] ctrl_mon;

    // Testname support (matches lab Makefile +testname flow)
    logic [1000:0] testname;
    integer        returnval;

    // DUT instantiation
    zdb_top #(
        .CTRL_BITS     (CTRL_BITS),
        .DELAY_STEP    (DELAY_STEP),
        .MIN_DELAY     (MIN_DELAY),
        .INIT_CTRL     (INIT_CTRL),
        .TREE_DELAY_PS (TREE_DELAY_PS)
    ) dut (
        .clk_in  (clk_in),
        .rst     (rst),
        .clk_out (clk_out),
        .ctrl_mon(ctrl_mon)
    );

    // Reference clock generation
    initial clk_in = 1'b0;
    always #(CLK_HALF) clk_in = ~clk_in;

    // Phase measurement helper
    time last_clkin_edge;
    time last_clkout_edge;
    real phase_err_ps;

    always @(posedge clk_in)  last_clkin_edge  = $time;
    always @(posedge clk_out) last_clkout_edge = $time;

    // Convergence monitor: watch ctrl_mon stabilize
    integer stable_count;
    logic   [CTRL_BITS-1:0] prev_ctrl;
    logic   locked;

    initial begin
        stable_count = 0;
        prev_ctrl    = {CTRL_BITS{1'b0}};
        locked       = 1'b0;
    end

    always @(posedge clk_in) begin
        if (!rst) begin
            if (ctrl_mon === prev_ctrl) begin
                stable_count <= stable_count + 1;
            end else begin
                stable_count <= 0;
                prev_ctrl    <= ctrl_mon;
            end

            // Declare lock after ctrl has been stable for 16 consecutive cycles
            if (stable_count >= 16 && !locked) begin
                locked <= 1'b1;
                phase_err_ps = $signed(last_clkout_edge - last_clkin_edge);
                $display("[%0t ps] DLL LOCKED: ctrl_mon = %0d  (delay = %0d ps)  phase_err ~ %0.0f ps",
                         $time, ctrl_mon,
                         MIN_DELAY + ctrl_mon * DELAY_STEP,
                         phase_err_ps);
            end
        end
    end

    // Main stimulus
    initial begin : TEST_CASE
        // Waveform dump
        $fsdbDumpfile("zdb_top_default.fsdb");
        $fsdbDumpon;
        $fsdbDumpvars(0, dut);

        // Testname dispatch
        returnval = $value$plusargs("testname=%s", testname);
        $display("[%0t ps] testname = %s", $time, testname);

        // Reset
        rst = 1'b1;
        repeat (8) @(posedge clk_in);
        @(negedge clk_in);
        rst = 1'b0;
        $display("[%0t ps] Reset released. INIT_CTRL=%0d, CLK_PERIOD=%0.0f ps",
                 $time, INIT_CTRL, CLK_PERIOD);

        // Run and dispatch to test task
        case (testname)
            "lock_check" : test_lock_check();
            "ctrl_sweep"  : test_ctrl_sweep();
            default       : test_lock_check();
        endcase

        $finish;
    end

    // Task: test_lock_check
    // Releases reset and waits for the DLL to lock; reports ctrl and phase.
    task automatic test_lock_check();
        integer cyc;
        $display("[%0t ps] [test_lock_check] Waiting up to %0d cycles for lock...",
                 $time, SIM_CYCLES);

        for (cyc = 0; cyc < SIM_CYCLES; cyc++) begin
            @(posedge clk_in);
            if (locked) begin
                $display("[%0t ps] [test_lock_check] Lock achieved after ~%0d cycles.",
                         $time, cyc);
                // Run a few more cycles to confirm stability
                repeat (32) @(posedge clk_in);
                return;
            end
        end

        $display("[%0t ps] [test_lock_check] WARNING: DLL did not lock within %0d cycles. Final ctrl_mon = %0d",
                 $time, SIM_CYCLES, ctrl_mon);
    endtask

    // Task: test_ctrl_sweep
    // After locking, verifies ctrl stays within legal [0, 2^CTRL_BITS-1].
    // Also exercises a brief re-reset to confirm ctrl returns to INIT_CTRL.
    task automatic test_ctrl_sweep();
        localparam integer MAX_CTRL = (1 << CTRL_BITS) - 1;
        integer cyc;

        $display("[%0t ps] [test_ctrl_sweep] Running convergence + re-reset check...", $time);

        // Wait for lock (or timeout)
        for (cyc = 0; cyc < SIM_CYCLES; cyc++) begin
            @(posedge clk_in);
            if (locked) break;
        end

        // Check ctrl within bounds
        if (ctrl_mon > MAX_CTRL)
            $display("[%0t ps] [test_ctrl_sweep] FAIL: ctrl_mon=%0d exceeds MAX_CTRL=%0d",
                     $time, ctrl_mon, MAX_CTRL);
        else
            $display("[%0t ps] [test_ctrl_sweep] PASS: ctrl_mon=%0d within [0,%0d]",
                     $time, ctrl_mon, MAX_CTRL);

        // Re-reset: ctrl should snap back to INIT_CTRL
        repeat (4) @(posedge clk_in);
        rst = 1'b1;
        repeat (4) @(posedge clk_in);
        if (ctrl_mon !== INIT_CTRL[CTRL_BITS-1:0])
            $display("[%0t ps] [test_ctrl_sweep] FAIL: after re-reset ctrl_mon=%0d, expected %0d",
                     $time, ctrl_mon, INIT_CTRL);
        else
            $display("[%0t ps] [test_ctrl_sweep] PASS: after re-reset ctrl_mon=%0d == INIT_CTRL",
                     $time, ctrl_mon);

        // Release reset and let it re-lock
        @(negedge clk_in);
        rst = 1'b0;
        locked = 1'b0;
        stable_count = 0;
        $display("[%0t ps] [test_ctrl_sweep] Re-released reset; waiting for re-lock...", $time);
        repeat (SIM_CYCLES) @(posedge clk_in);
        $display("[%0t ps] [test_ctrl_sweep] Done. Final ctrl_mon = %0d", $time, ctrl_mon);
    endtask

endmodule