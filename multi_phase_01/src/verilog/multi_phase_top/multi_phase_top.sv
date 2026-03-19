`timescale 1ps/1ps

module multi_phase_top #(
    parameter integer CTRL_BITS = 4,   // MUST match log2(N)
    parameter integer INIT_CTRL = 8
)(
    input  wire                 clk_in,
    input  wire                 rst,
    output wire                 clk_out,

    // Multiphase outputs
    output wire [15:0]          clk_phases,

    // Debug
    output wire [CTRL_BITS-1:0] ctrl_dbg,
    output wire                 up_dbg,
    output wire                 down_dbg
);

    // -----------------------------------------------------------------
    // Internal signals
    // -----------------------------------------------------------------
    wire [CTRL_BITS-1:0] ctrl;
    wire up;
    wire down;

    wire dcdl_clk;

    // -----------------------------------------------------------------
    // Phase detector
    // -----------------------------------------------------------------
    phase_detector u_pd (
        .clk_in  (clk_in),
        .clk_out (dcdl_clk),   // cleaner
        .rst     (rst),
        .up      (up),
        .down    (down)
    );

    // -----------------------------------------------------------------
    // Controller
    // -----------------------------------------------------------------
    controller #(
        .CTRL_BITS (CTRL_BITS),
        .INIT_CTRL (INIT_CTRL)
    ) u_controller (
        .clk_in (clk_in),
        .rst    (rst),
        .up     (up),
        .down   (down),
        .ctrl   (ctrl)
    );

    // -----------------------------------------------------------------
    // DCDL (multiphase)
    // -----------------------------------------------------------------
    nand_dcdl_top #(
        .N(16)
    ) u_dcdl_top (
        .clk   (clk_in),
        .rst_n (~rst),

        .ctrl  (ctrl),

        .A     (clk_in),
        .Y     (dcdl_clk),
        .taps  (clk_phases)
    );

    // -----------------------------------------------------------------
    // Output
    // -----------------------------------------------------------------
    assign clk_out = dcdl_clk;

    // -----------------------------------------------------------------
    // Debug
    // -----------------------------------------------------------------
    assign ctrl_dbg = ctrl;
    assign up_dbg   = up;
    assign down_dbg = down;

endmodule