//**************************************************************************
// Author: Mythri Muralikannan
// Description: Delay Line Top with the taps for multiphase
//**************************************************************************
//**************************************************************************
// Description: Multiphase DLL delay line top
//**************************************************************************
module nand_dcdl_top #(
    parameter integer N = 16
)(
    input  logic clk,                         // control clock (not used internally here)
    input  logic rst_n,                       // unused (kept for interface compatibility)

    input  logic [$clog2(N)-1:0] ctrl,        // control word (tap select)

    input  logic A,                           // input clock
    output logic Y,                           // delayed output (for feedback)
    output logic [N-1:0] taps                 // multiphase outputs
);

    nand_dcdl #(
        .N(N)
    ) dcdl (
        .A    (A),
        .sel  (ctrl),
        .Y    (Y),
        .taps (taps)
    );

endmodule