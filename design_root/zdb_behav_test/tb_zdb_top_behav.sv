`timescale 1ns/1ps

module tb_zdb;

    localparam CLK_PERIOD        = 4;
    localparam CTRL_BITS         = 6;

    localparam INIT_CTRL         = 32;
    localparam DELAY_PS          = 700;
    localparam UPDATE_DIV_BITS   = 2; //MN 2
    localparam RESET_DELAY_PS    = 20;
    localparam LOCK_COUNT_MAX    = 32;

    reg clk_in;
    reg rst;

    wire clk_out;
    wire locked;

    zdb_top #(
        .CTRL_BITS       (CTRL_BITS),
        .INIT_CTRL       (INIT_CTRL),
        .DELAY_PS        (DELAY_PS),
        .UPDATE_DIV_BITS (UPDATE_DIV_BITS),
        .RESET_DELAY_PS  (RESET_DELAY_PS),
        .LOCK_COUNT_MAX  (LOCK_COUNT_MAX)
    ) dut (
        .clk_in (clk_in),
        .rst    (rst),
        .clk_out(clk_out),
        .locked (locked),
        .ctrl_dbg()
    );

    initial begin
        clk_in = 0;
        #1.3;
        forever #(CLK_PERIOD/2.0) clk_in = ~clk_in;
    end

    initial begin
        rst = 1;
        #50;
        rst = 0;
    end

    initial begin
        $dumpfile("zdb.vcd");
        $dumpvars(0, tb_zdb);
    end

    real t_ref_last;
    real phase_error;

    function real abs_real(input real x);
        abs_real = (x < 0) ? -x : x;
    endfunction

    always @(posedge clk_in)
        t_ref_last = $realtime;

    always @(posedge clk_out) begin
        real t_fb;
        t_fb = $realtime;

        phase_error = t_fb - t_ref_last;

        if (phase_error > CLK_PERIOD/2.0)
            phase_error -= CLK_PERIOD;

        if (phase_error < -CLK_PERIOD/2.0)
            phase_error += CLK_PERIOD;
    end

    integer stable_count = 0;
    integer print_div    = 0;

    // convert ps → ns
    real delay_ns = DELAY_PS * 1e-3;

    always @(posedge clk_in) begin
        print_div = print_div + 1;

        if (print_div % 10 == 0) begin
            $display("t=%0t ctrl=%0d phase_err=%0.3f",
                     $time, dut.ctrl_dbg, phase_error);
        end

        if (abs_real(phase_error) < (delay_ns * 1.5)) begin
            stable_count = stable_count + 1;
        end else begin
            stable_count = 0;
        end

        if (stable_count > LOCK_COUNT_MAX) begin
            $display("====================================");
            $display("LOCK ACHIEVED at t=%0t", $time);
            $display("Final phase error = %0.3f ns", phase_error);
            $display("Final ctrl = %0d", dut.ctrl_dbg);
            $display("====================================");
            #20;
            $finish;
        end
    end

    initial begin
        #100000;
        $display("====================================");
        $display("FAIL: Did not lock");
        $display("====================================");
        $finish;
    end

endmodule