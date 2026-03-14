`timescale 1ps/1ps

module zdb_top #(
    parameter integer CTRL_BITS      = 6,
    parameter integer DELAY_STEP     = 20,   // ps
    parameter integer MIN_DELAY      = 0,
    parameter integer INIT_CTRL      = 20,
    parameter integer TREE_DELAY_PS  = 200   // simulated clock tree delay THIS NEEDS TO BE REMOVED AFTER USING A RING OSCILLATOR
)(
    input  wire clk_in,
    input  wire rst,
    output wire clk_out,
    output wire clk_out,
    output wire [CTRL_BITS-1:0] ctrl_mon
);

    wire up, down;
    wire [CTRL_BITS-1:0] ctrl;
    wire dcdl_clk;

    // Phase detector compares input clock and feedback clock
    bangbang_pd pd_1 (
        .clk_in(clk_in),
        .clk_out (clk_out),
        .rst    (rst),
        .up     (up),
        .down   (down)
    );

    // Controller adjusts delay code
    dll_controller #(
        .CTRL_BITS(CTRL_BITS),
        .INIT_CTRL(INIT_CTRL)
    ) ctrl_1 (
        .clk_in(clk_in),
        .rst    (rst),
        .up     (up),
        .down   (down),
        .ctrl   (ctrl)
    );

    // Programmable delay line
    dcdl_behavioral #(
        .CTRL_BITS (CTRL_BITS),
        .DELAY_STEP(DELAY_STEP),
        .MIN_DELAY (MIN_DELAY)
    ) dcdl_1 (
        .clk_in (clk_in),
        .ctrl   (ctrl),
        .clk_out(dcdl_clk)
    );

    // Buffered output clock
    assign clk_out = dcdl_clk;

    // Simulated clock tree / distribution delay 
    // NEED TO INTEGRATE RING OSCILLATOR INSTEAD
    assign #(TREE_DELAY_PS) clk_out = clk_out;

    assign ctrl_mon = ctrl;

endmodule
