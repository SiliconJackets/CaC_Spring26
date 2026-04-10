`timescale 1ps/1ps

module nand_dcdl #(
    parameter integer STAGES = 8
)(
    input  logic A,
    input  logic [STAGES-1:0] Q,
    output logic [STAGES-1:0] taps
);

    logic [STAGES:0] stage;
    logic [STAGES-1:0] delayed;

    assign stage[0] = A;

    genvar i;
    generate
        for (i = 0; i < STAGES; i++) begin : dcdl_chain

            // -------------------------------------------------
            // Create intrinsic delay (this is critical)
            // -------------------------------------------------
            // You can replace this with a real inverter chain
            (* keep = "true" *) logic inv_out;

            inverter inv_delay (
                .in(stage[i]),
                .out(inv_out)
            );
            
            assign delayed[i] = inv_out;

            // -------------------------------------------------
            // Your NAND-based delay cell (MUX behavior)
            // -------------------------------------------------
            nand_dcdl_cell cell (
                .in1(stage[i]),     // fast path
                .in0(delayed[i]),   // delayed path
                .ctl(Q[i]),
                .out(stage[i+1])
            );

            // -------------------------------------------------
            // Multiphase taps
            // -------------------------------------------------
            assign taps[i] = stage[i+1];

        end
    endgenerate

endmodule