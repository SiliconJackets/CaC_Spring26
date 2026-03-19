`timescale 1ps/1ps

module tdc_top #(
    parameter integer N = 16,
    parameter integer CTRL_BITS = $clog2(N)
)(
    input  wire clk_ref,    // DLL reference clock
    input  wire rst,

    // TDC signals
    input  wire stop_clk,   // sampling clock

    // Outputs
    output wire clk_out,                    // DLL output
    output wire [N-1:0] clk_phases,         // multiphase taps
    output reg  [N-1:0] thermo_out,         // sampled thermometer code
    output wire [$clog2(N+1)-1:0] time_out, // encoded time

    // Debug
    output wire [CTRL_BITS-1:0] ctrl_dbg,
    output wire up_dbg,
    output wire down_dbg
);

    // -------------------------------------------------------------
    // Internal signals
    // -------------------------------------------------------------
    wire [CTRL_BITS-1:0] ctrl;
    wire up, down;

    // -------------------------------------------------------------
    // Phase Detector
    // -------------------------------------------------------------
    phase_detector u_pd (
        .clk_in  (clk_ref),
        .clk_out (clk_out),
        .rst     (rst),
        .up      (up),
        .down    (down)
    );

    // -------------------------------------------------------------
    // Controller
    // -------------------------------------------------------------
    controller #(
        .CTRL_BITS(CTRL_BITS),
        .INIT_CTRL(N/2)
    ) u_ctrl (
        .clk_in(clk_ref),
        .rst(rst),
        .up(up),
        .down(down),
        .ctrl(ctrl)
    );

    // -------------------------------------------------------------
    // DCDL (multiphase delay line)
    // -------------------------------------------------------------
    nand_dcdl_top #(
        .N(N)
    ) u_dcdl (
        .clk   (clk_ref),
        .rst_n (~rst),
        .ctrl  (ctrl),
        .A     (clk_ref),
        .Y     (clk_out),
        .taps  (clk_phases)
    );

    // -------------------------------------------------------------
    // TDC Sampling (THIS is the TDC part)
    // -------------------------------------------------------------
    always @(posedge stop_clk or posedge rst) begin
        if (rst)
            thermo_out <= 0;
        else
            thermo_out <= clk_phases;
    end

    // -------------------------------------------------------------
    // Thermometer → Binary encoder
    // -------------------------------------------------------------
    thermo_encoder #(
        .N(N)
    ) u_enc (
        .thermo(thermo_out),
        .binary(time_out)
    );

    // -------------------------------------------------------------
    // Debug
    // -------------------------------------------------------------
    assign ctrl_dbg = ctrl;
    assign up_dbg   = up;
    assign down_dbg = down;

endmodule