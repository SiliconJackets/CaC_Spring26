//**************************************************************************
// Author: Alfi Misha Antony Selvin Raj
// Description: Conditional inv dcdl
//**************************************************************************
(* dont_touch = "true" *)
module inv_dcdl_cond (
    input  logic A,
    input  logic [1:0] Q,
    output logic Y
);

    // delay chain
    logic tap0, tap1, tap2, tap3;

    assign tap0 = ~A;
    assign tap1 = ~tap0;
    assign tap2 = ~tap1;
    assign tap3 = ~tap2;

    // mux tree
    logic mux0, mux1, mux2;

    assign mux0 = Q[0] ? tap1 : tap0;
    assign mux1 = Q[0] ? tap3 : tap2;
    assign mux2 = Q[1] ? mux1 : mux0;

    // final XNOR 
    assign Y = ~(mux2 ^ Q[1]);

endmodule
