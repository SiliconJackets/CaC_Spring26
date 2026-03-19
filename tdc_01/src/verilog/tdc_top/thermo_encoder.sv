module thermo_encoder #(
    parameter integer N = 16,
    parameter integer OUT_BITS = $clog2(N+1)
)(
    input  wire [N-1:0] thermo,
    output reg  [OUT_BITS-1:0] binary
);

    integer i;

    always @(*) begin
        binary = 0;
        for (i = 0; i < N; i = i + 1) begin
            if (thermo[i])
                binary = binary + 1;
        end
    end

endmodule