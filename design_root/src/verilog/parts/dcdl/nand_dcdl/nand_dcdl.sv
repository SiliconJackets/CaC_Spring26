(* dont_touch = "true" *)
module nand_dcdl #(
    parameter int N = 128
)(
    input  logic A,
    input  logic [N-1:0] Q,
    output logic Y
);

    // Internal chain signals
    (* keep = "true" *) logic [N-1:0] s;

    genvar i;
    generate
        for (i = 0; i < N; i++) begin : dcdl_chain

            if (i == N-1) begin
                // FIRST stage (top of chain)
                nand_dcdl_cell cell (
                    .in1(1'b0),
                    .in0(A),
                    .ctl(Q[i]),
                    .out(s[i])
                );
            end else begin
                // Remaining stages
                nand_dcdl_cell cell (
                    .in1(s[i+1]),
                    .in0(A),
                    .ctl(Q[i]),
                    .out(s[i])
                );
            end

        end
    endgenerate

    assign Y = s[0];

endmodule