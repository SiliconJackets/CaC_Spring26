//**************************************************************************
// Author: Alfi Misha Antony Selvin Raj
// Description: Delay Line Top with the shift register generating Q
//**************************************************************************
module nand_dcdl_top #(
    parameter int N = 128
)(
    input  logic clk,
    input  logic rst_n,
    input  logic shift_left,
    input  logic shift_right,
    input  logic A,
    output logic Y
);

    logic [N-1:0] Q;

    // Shift register
    dll_shift_register #(
        .N(N), 
        .INIT_TAP(N-1)

    ) sr (
        .clk(clk),
        .rst_n(rst_n),
        .shift_left(shift_left),
        .shift_right(shift_right),
        .Q(Q)
    );

    // DCDL
    nand_dcdl #(
        .N(N)
    ) dcdl (
        .A(A),
        .Q(Q),
        .Y(Y)
    );

endmodule