module inv_dcdl (
    input  logic A,
    input  logic [1:0] Q,
    output logic Y
);

logic tap0, tap1, tap2, tap3;


logic d0;
assign d0   = ~A;
assign tap0 = ~d0;

logic d1;
assign d1   = ~tap0;
assign tap1 = ~d1;

logic d2;
assign d2   = ~tap1;
assign tap2 = ~d2;

logic d3;
assign d3   = ~tap2;
assign tap3 = ~d3;


logic mux0;
logic mux1;


assign mux0 = Q[0] ? tap1 : tap0;
assign mux1 = Q[0] ? tap3 : tap2;


assign Y = Q[1] ? mux1 : mux0;

endmodule