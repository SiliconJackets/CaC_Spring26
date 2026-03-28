//**************************************************************************
// Glitch-free inv DCDL (gate-level style)
//**************************************************************************
(* dont_touch = "true" *)
module inv_dcdl_glitch_free(
    input  logic clk, 
    input  logic rst_n, 
    input  logic A, 
    input  logic [1:0] Q,
    output logic Y
);

    // delay chain
    logic tap0, tap1, tap2, tap3;

    assign tap0 = A;
    inverter inv1 (.in(tap0), .out(tap1));
    inverter inv2 (.in(tap1), .out(tap2));
    inverter inv3 (.in(tap2), .out(tap3));

    // one-hot decoder
    logic [3:0] sel;
    always_comb begin
        sel = 4'b0000;
        sel[Q] = 1'b1;
    end

    // registered select (glitch protection)
    logic [3:0] sel_reg;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            sel_reg <= 4'b0001;
        else
            sel_reg <= sel;
    end

    // gated taps using NAND
    logic ntap0, ntap1, ntap2, ntap3;
    logic y0, y1, y2, y3;

    inverter inv_t0 (.in(tap0), .out(ntap0));
    inverter inv_t1 (.in(tap1), .out(ntap1));
    inverter inv_t2 (.in(tap2), .out(ntap2));
    inverter inv_t3 (.in(tap3), .out(ntap3));

    nand2 n0 (.a(ntap0), .b(sel_reg[0]), .out(y0));
    nand2 n1 (.a(ntap1), .b(sel_reg[1]), .out(y1));
    nand2 n2 (.a(ntap2), .b(sel_reg[2]), .out(y2));
    nand2 n3 (.a(ntap3), .b(sel_reg[3]), .out(y3));

    // final NAND tree
    logic n01, n23;

    nand2 n4 (.a(y0), .b(y1), .out(n01));
    nand2 n5 (.a(y2), .b(y3), .out(n23));
    nand2 n6 (.a(n01), .b(n23), .out(Y));

endmodule