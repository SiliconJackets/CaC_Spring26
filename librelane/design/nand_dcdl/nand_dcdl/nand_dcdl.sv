(* dont_touch = "true" *)
module nand_dcdl #(
    parameter int N = 32
)(
    input  logic A,
    input  logic [N-1:0] Q,
    output logic Y
);

    (* keep = "true" *) logic [N-1:0] s;

    genvar i;
    generate
        for (i = 0; i < N; i++) begin : dcdl_chain

            if (i == N-1) begin
                nand_dcdl_cell cell_instance0 (
                    .in1(1'b0),
                    .in0(A),
                    .ctl(Q[i]),
                    .out(s[i])
                );
            end else begin
                nand_dcdl_cell cell_instance1 (
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