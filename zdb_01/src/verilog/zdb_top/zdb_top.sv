`timescale 1ps/1ps

/*
|=======================================================================
| Module      : zdb_top
| Author      : Mythri Muralikannan
| Description : Zero-Delay Buffer (ZDB) top-level wrapper
|
| Diagram mapping:
|   CLKin --> Phase Detector --> Controller --> DCDL --> DIST --> CLKOUT
|                ^                                          |
|                |__________________________________________|
|
| Function:
|   Connects the phase detector, digital controller, and delay line
|   to form a digital DLL / zero-delay buffer loop.
|
| Implementation notes:
|   - The phase detector compares clk_in and clk_out
|   - The controller updates the digital control word ctrl
|   - Since nand_dcdl_top expects shift_left / shift_right instead of
|     a multi-bit control word, a small adapter converts ctrl changes
|     into one-cycle shift pulses
|   - The distribution block (DIST) is modeled here as a pass-through
|
| Inputs:
|   clk_in : Reference input clock
|   rst    : Asynchronous active-high reset
|
| Outputs:
|   clk_out        : Buffered / delayed output clock
|   ctrl_dbg       : Controller output word (for debug/observation)
|   up_dbg         : Phase detector UP output
|   down_dbg       : Phase detector DOWN output
|   shift_left_dbg : Shift-left pulse into DCDL control
|   shift_right_dbg: Shift-right pulse into DCDL control
|=======================================================================
*/

module zdb_top #(
    parameter integer CTRL_BITS = 6,
    parameter integer INIT_CTRL = 32
)(
    input  wire                 clk_in,
    input  wire                 rst,
    output wire                 clk_out,

    // Debug / visibility signals
    output wire [CTRL_BITS-1:0] ctrl_dbg,
    output wire                 up_dbg,
    output wire                 down_dbg,
    output wire                 shift_left_dbg,
    output wire                 shift_right_dbg
);

    // -----------------------------------------------------------------
    // Internal signals
    // -----------------------------------------------------------------
    wire [CTRL_BITS-1:0] ctrl;
    wire up;
    wire down;

    reg  [CTRL_BITS-1:0] ctrl_d;
    wire shift_left;
    wire shift_right;

    wire dcdl_clk;

    // -----------------------------------------------------------------
    // Phase detector
    // -----------------------------------------------------------------
    phase_detector u_pd (
        .clk_in  (clk_in),
        .clk_out (clk_out),
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
    // Control-word to shift-pulse adapter
    //
    // If ctrl increased relative to previous cycle, generate shift_left.
    // If ctrl decreased, generate shift_right.
    // -----------------------------------------------------------------
    always @(posedge clk_in or posedge rst) begin
        if (rst)
            ctrl_d <= INIT_CTRL[CTRL_BITS-1:0];
        else
            ctrl_d <= ctrl;
    end

    assign shift_left  = (ctrl > ctrl_d);
    assign shift_right = (ctrl < ctrl_d);

    // -----------------------------------------------------------------
    // Digitally Controlled Delay Line (DCDL)
    //
    // CLKin is the signal being delayed, while clk_in is also used as the
    // control/update clock for the internal shift register.
    // -----------------------------------------------------------------
    nand_dcdl_top u_dcdl_top (
        .clk         (clk_in),
        .rst_n       (~rst),
        .shift_left  (shift_left),
        .shift_right (shift_right),
        .A           (clk_in),
        .Y           (dcdl_clk)
    );

    // -----------------------------------------------------------------
    // Distribution block (DIST)
    //
    // Modeled as a simple pass-through for now.
    // -----------------------------------------------------------------
    assign clk_out = dcdl_clk;

    // -----------------------------------------------------------------
    // Debug outputs
    // -----------------------------------------------------------------
    assign ctrl_dbg        = ctrl;
    assign up_dbg          = up;
    assign down_dbg        = down;
    assign shift_left_dbg  = shift_left;
    assign shift_right_dbg = shift_right;

endmodule