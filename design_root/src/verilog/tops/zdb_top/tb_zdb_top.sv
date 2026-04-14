`timescale 1ps/1ps

module tb_zdb_top;

    parameter integer CTRL_BITS = 6;
    parameter integer INIT_CTRL = 32;
    localparam integer MAX_CTRL = (1 << CTRL_BITS) - 1;

    // ---------------------------------------------
    // Signals
    // ---------------------------------------------
    reg clk_in;
    reg rst;

    wire clk_out;
    wire [CTRL_BITS-1:0] ctrl_dbg;
    wire up_dbg;
    wire down_dbg;
    wire shift_left_dbg;
    wire shift_right_dbg;

    integer errors;

    // ---------------------------------------------
    // Phase measurement
    // ---------------------------------------------
    time t_in_edge, t_out_edge;
    time phase_error, prev_phase_error;

    integer stable_phase_cycles;
    integer stable_ctrl_cycles;
    integer last_ctrl;

    // ---------------------------------------------
    // DUT
    // ---------------------------------------------
    zdb_top #(
        .CTRL_BITS (CTRL_BITS),
        .INIT_CTRL (INIT_CTRL)
    ) dut (
        .clk_in          (clk_in),
        .rst             (rst),
        .clk_out         (clk_out),
        .ctrl_dbg        (ctrl_dbg),
        .up_dbg          (up_dbg),
        .down_dbg        (down_dbg),
        .shift_left_dbg  (shift_left_dbg),
        .shift_right_dbg (shift_right_dbg)
    );

    // ---------------------------------------------
    // Clock (10ns)
    // ---------------------------------------------
    initial clk_in = 0;
    always #5000 clk_in = ~clk_in;

    // ---------------------------------------------
    // Phase tracking
    // ---------------------------------------------
    always @(posedge clk_in)
        t_in_edge = $time;

    always @(posedge clk_out) begin
        t_out_edge = $time;
        phase_error = t_out_edge - t_in_edge;

        $display("t=%0t | PHASE_ERR=%0t ps | ctrl=%0d | UP=%b DOWN=%b",
                 $time, phase_error, ctrl_dbg, up_dbg, down_dbg);

        // Phase stability tracking
        if (phase_error == prev_phase_error)
            stable_phase_cycles++;
        else
            stable_phase_cycles = 0;

        prev_phase_error = phase_error;
    end

    // ---------------------------------------------
    // Control convergence tracking
    // ---------------------------------------------
    always @(posedge clk_in) begin
        if (ctrl_dbg == last_ctrl)
            stable_ctrl_cycles++;
        else
            stable_ctrl_cycles = 0;

        last_ctrl = ctrl_dbg;
    end

    // ---------------------------------------------
    // Basic checks
    // ---------------------------------------------
    task expect_known;
        begin
            if ((^clk_out === 1'bx) ||
                (^ctrl_dbg === 1'bx)) begin
                $display("ERROR: Unknown detected @ %0t", $time);
                errors++;
            end
        end
    endtask

    task expect_ctrl_range;
        begin
            if (ctrl_dbg > MAX_CTRL) begin
                $display("ERROR: ctrl out of range @ %0t", $time);
                errors++;
            end
        end
    endtask

    task wait_cycles(input int n);
        for (int i = 0; i < n; i++) begin
            @(posedge clk_in);
            #1;
            expect_known();
            expect_ctrl_range();
        end
    endtask

    // ---------------------------------------------
    // Lock detection
    // ---------------------------------------------
    task check_lock;
        begin
            if (stable_phase_cycles > 5 && stable_ctrl_cycles > 5) begin
                $display("\n🔥 LOCK ACHIEVED 🔥");
                $display("Time        = %0t", $time);
                $display("Final ctrl  = %0d", ctrl_dbg);
                $display("Phase error = %0t ps\n", phase_error);
            end else begin
                $display("\n⚠️ NO LOCK DETECTED");
                $display("Phase stable cycles = %0d", stable_phase_cycles);
                $display("Ctrl stable cycles  = %0d\n", stable_ctrl_cycles);
            end
        end
    endtask

    // ---------------------------------------------
    // Monitor
    // ---------------------------------------------
    initial begin
        $display("time   rst clk_in clk_out | ctrl");
        $monitor("%6t  %b    %b      %b    | %0d",
                 $time, rst, clk_in, clk_out, ctrl_dbg);
    end

    // ---------------------------------------------
    // TEST SEQUENCE
    // ---------------------------------------------
    initial begin
        errors = 0;
        stable_phase_cycles = 0;
        stable_ctrl_cycles  = 0;
        prev_phase_error    = 0;
        last_ctrl           = INIT_CTRL;

        // -----------------------------------------
        // RESET
        // -----------------------------------------
        rst = 1;
        #10000;
        rst = 0;

        @(posedge clk_in); #1;
        if (ctrl_dbg !== INIT_CTRL)
            $display("ERROR: Reset failed, ctrl=%0d", ctrl_dbg);

        // -----------------------------------------
        // RUN DLL
        // -----------------------------------------
        $display("\n=== RUNNING DLL LOOP ===");
        wait_cycles(100);

        // -----------------------------------------
        // CHECK LOCK
        // -----------------------------------------
        check_lock();

        // -----------------------------------------
        // DISTURB SYSTEM (important test)
        // -----------------------------------------
        $display("\n=== DISTURBANCE TEST ===");

        rst = 1;   // reset loop mid-run
        #5000;
        rst = 0;

        wait_cycles(60);
        check_lock();

        // -----------------------------------------
        // SUMMARY
        // -----------------------------------------
        $display("\n==============================");
        if (errors == 0)
            $display("TEST PASSED");
        else
            $display("TEST FAILED: %0d errors", errors);
        $display("==============================");

        $finish;
    end

endmodule