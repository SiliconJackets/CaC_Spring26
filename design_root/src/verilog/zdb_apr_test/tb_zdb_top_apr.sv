`timescale 1ns/1ps

module tb_zdb;

    // ---------------------------------
    // Parameters
    // ---------------------------------
    // ENSURE TOTAL DELAY IS GREATER THAN THE CLOCK PERIOD!!!1
    localparam CLK_PERIOD = 4; // 100 MHz
    localparam CTRL_BITS  = 6;

    // ---------------------------------
    // DUT signals
    // ---------------------------------
    reg clk_in;
    reg rst;

    wire clk_out;
    wire locked;

    // ---------------------------------
    // Instantiate DUT
    // ---------------------------------
    zdb_top #(
        .CTRL_BITS(CTRL_BITS)
    ) dut (
        .clk_in (clk_in),
        .rst    (rst),
        .clk_out(clk_out),
        .locked (locked)
    );

    // ---------------------------------
    // Clock generation (with skew)
    // ---------------------------------
    initial begin
        clk_in = 0;
        #1;  // break symmetry
        forever #(CLK_PERIOD/2) clk_in = ~clk_in;
    end

    // ---------------------------------
    // Reset sequence
    // ---------------------------------
    initial begin
        rst = 1;
        #50;
        rst = 0;
    end

    // ---------------------------------
    // VCD dump
    // ---------------------------------
    initial begin
        $dumpfile("zdb.vcd");
        $dumpvars(0, tb_zdb);

        // Key signals
        $dumpvars(1, tb_zdb.clk_in);
        $dumpvars(1, tb_zdb.clk_out);
        $dumpvars(1, tb_zdb.dut.ctrl_dbg);
        $dumpvars(1, tb_zdb.dut.up);
        $dumpvars(1, tb_zdb.dut.down);
    end

    // ---------------------------------
    // Phase measurement (FIXED)
    // ---------------------------------
    real t_ref_last;
    real phase_error;

    function real abs_real;
        input real x;
        begin
            if (x < 0) abs_real = -x;
            else       abs_real = x;
        end
    endfunction

    always @(posedge clk_in) begin
        t_ref_last = $realtime;
    end

    always @(posedge clk_out) begin
        real t_fb;
        t_fb = $realtime;

        phase_error = t_fb - t_ref_last;

        // Wrap into [-T/2, T/2]
        if (phase_error > CLK_PERIOD/2.0)
            phase_error -= CLK_PERIOD;

        if (phase_error < -CLK_PERIOD/2.0)
            phase_error += CLK_PERIOD;
    end

    // ---------------------------------
    // Self-check lock detection
    // ---------------------------------
    integer stable_count = 0;
    integer print_div = 0;

    always @(posedge clk_in) begin
        print_div = print_div + 1;

        // Print every 10 cycles (cleaner output)
        if (print_div % 10 == 0) begin
            $display("t=%0t ctrl=%0d up=%b down=%b phase_err=%f",
                     $time, dut.ctrl_dbg, dut.up, dut.down, phase_error);
        end

        // 5% tolerance window
        if (abs_real(phase_error) < (CLK_PERIOD * 0.05)) begin
            stable_count = stable_count + 1;
        end else begin
            stable_count = 0;
        end

        // Declare lock
        if (stable_count > 20) begin
            $display("====================================");
            $display("✅ LOCK ACHIEVED at t=%0t", $time);
            $display("Final phase error = %f", phase_error);
            $display("Final ctrl = %0d", dut.ctrl_dbg);
            $display("====================================");
            #20;
            $finish;
        end
    end

    // ---------------------------------
    // Timeout (fail-safe)
    // ---------------------------------
    initial begin
        #50000;
        $display("====================================");
        $display("❌ FAIL: Did not lock");
        $display("====================================");
        $finish;
    end

endmodule