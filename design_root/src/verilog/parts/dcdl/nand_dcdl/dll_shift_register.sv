module dll_shift_register #(
    parameter int N = 128,
    parameter int INIT_TAP = N-1
)(
    input  logic clk,
    input  logic rst_n,
    input  logic shift_left,
    input  logic shift_right,
    output logic [N-1:0] Q
);

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        Q <= ({ {(N-1){1'b0}}, 1'b1 } << INIT_TAP);
    end
    else if (shift_left) begin
        // move toward larger delay, but do not wrap
        if (Q != ({{(N-1){1'b0}}, 1'b1} << (N-1)))
            Q <= Q << 1;
        else
            Q <= Q;
    end
    else if (shift_right) begin
        // move toward smaller delay, but do not wrap
        if (Q != {{(N-1){1'b0}}, 1'b1})
            Q <= Q >> 1;
        else
            Q <= Q;
    end
end

endmodule