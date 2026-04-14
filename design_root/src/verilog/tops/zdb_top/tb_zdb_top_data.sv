`timescale 1ps/1ps

module tb_zdb_top_data;

    // -------------------------------------------------
    // Parameters
    // -------------------------------------------------
    parameter integer CTRL_BITS = 7;

    // Start far from target (max delay)
    parameter integer INIT_CTRL = 0;

    // 10 ns clock period
    parameter time HALF_PERIOD = 5000;

    // -------------------------------------------------
    // Signals
    // -------------------------------------------------
    reg clk_in;
    reg rst;

    wire clk_out;
    wire [CTRL_BITS-1:0] ctrl_dbg;
    wire up_dbg;
    wire down_dbg;
    wire shift_left_dbg;
    wire shift_right_dbg;

    integer fd;

    time t_in_edge;
    time t_out_edge;
    time phase_err;

    // -------------------------------------------------
    // DUT
    // -------------------------------------------------
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

    // -------------------------------------------------
    // Clock Generator (10 ns period)
    // -------------------------------------------------
    initial clk_in = 1'b0;
    always #(HALF_PERIOD) clk_in = ~clk_in;

    // -------------------------------------------------
    // Track rising edges
    // -------------------------------------------------
    always @(posedge clk_in) begin
        t_in_edge = $time;
    end

    always @(posedge clk_out) begin
        t_out_edge = $time;
        phase_err  = t_out_edge - t_in_edge;
    end

    // -------------------------------------------------
    // CSV Open
    // -------------------------------------------------
    initial begin
        fd = $fopen("dll_data.csv", "w");

        $fdisplay(fd,
"time_ps,clk_in,clk_out,t_in_edge_ps,t_out_edge_ps,up,down,shift_left,shift_right,ctrl,phase_err_ps");
    end

    // -------------------------------------------------
    // Log once per reference clock cycle
    // -------------------------------------------------
    always @(posedge clk_in) begin
        if (!rst) begin
            $fdisplay(fd,
                "%0t,%0b,%0b,%0t,%0t,%0b,%0b,%0b,%0b,%0d,%0t",
                $time,
                clk_in,
                clk_out,
                t_in_edge,
                t_out_edge,
                up_dbg,
                down_dbg,
                shift_left_dbg,
                shift_right_dbg,
                ctrl_dbg,
                phase_err
            );
        end
    end

    // -------------------------------------------------
    // Terminal prints both clocks
    // -------------------------------------------------
    always @(posedge clk_in) begin
        if (!rst) begin
            $display("CLK_IN  edge @ %0t", $time);
        end
    end

    always @(posedge clk_out) begin
        if (!rst) begin
            $display("CLK_OUT edge @ %0t | ERR=%0t ps | CTRL=%0d | SL=%b SR=%b",
                     $time,
                     phase_err,
                     ctrl_dbg,
                     shift_left_dbg,
                     shift_right_dbg);
        end
    end

    // -------------------------------------------------
    // Stimulus
    // -------------------------------------------------
    initial begin
        phase_err  = 0;
        t_in_edge  = 0;
        t_out_edge = 0;

        // Reset
        rst = 1'b1;
        #20000;
        rst = 1'b0;

        // Run
        #500000;

        $fclose(fd);
        $display("Simulation complete. Data saved to dll_data.csv");
        $finish;
    end

endmodule