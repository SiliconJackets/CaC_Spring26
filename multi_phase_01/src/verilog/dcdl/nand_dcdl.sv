//**************************************************************************
// Author: Mythri Muralikannan
// Description: 4-NAND Delay line (DCDL) Rewritten for Multiphase Taps
//**************************************************************************
//**************************************************************************
// Description: N-stage delay line with tap outputs
//**************************************************************************
(* dont_touch = "true" *)
module nand_dcdl #(
    parameter integer N = 16  // number of delay stages (phases)
)(
    input  logic A,                      // input clock
    input  logic [$clog2(N)-1:0] sel,    // select output tap
    output logic Y,                      // selected delayed output
    output logic [N-1:0] taps            // multiphase outputs
);

    // Internal chain nodes
    (* keep = "true" *) logic [N:0] chain;

    assign chain[0] = A;

    genvar i;
    generate
        for (i = 0; i < N; i++) begin : gen_delay_chain
            nand_dcdl_cell cell (
                .in  (chain[i]),
                .out (chain[i+1])
            );
        end
    endgenerate

    // Expose taps (skip input node)
    assign taps = chain[N:1];

    // Select which tap is the "output clock" for DLL feedback
    assign Y = taps[sel];

endmodule