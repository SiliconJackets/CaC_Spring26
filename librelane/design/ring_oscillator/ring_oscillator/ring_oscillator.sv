/* |======================================================================= */
/* | */                                                                          
/* | Author             :Alfi Misha Antony Selvin Raj */                                                   
/* | Description        : Ring oscillator for variable clock generation                                            
/* | */                                                                      
/* | */                                                                      
/* |======================================================================= */
`ifndef RING_OSCILLATOR_V
`define RING_OSCILLATOR_V
(* dont_touch = "true" *)
module ring_oscillator (
    input logic [1:0] sel, 
    output logic clk_out
);
(* dont_touch = "true", keep = "true" *)
logic n0,n1,n2,n3,n4,n5,n6,n7,n8;
inverter inv0 (.in(clk_out), .out(n0));
inverter inv1 (.in(n0), .out(n1));
inverter inv2 (.in(n1), .out(n2));
inverter inv3 (.in(n2), .out(n3));
inverter inv4 (.in(n3), .out(n4));
inverter inv5 (.in(n4), .out(n5));
inverter inv6 (.in(n5), .out(n6));
inverter inv7 (.in(n6), .out(n7));
inverter inv8 (.in(n7), .out(n8));

logic mux0_out, mux1_out;
mux mux0 (.x0(n2), .x1(n4), .s(sel[0]), .Y(mux0_out));
mux mux1 (.x0(n6), .x1(n8), .s(sel[0]), .Y(mux1_out));
mux mux2 (.x0(mux0_out), .x1(mux1_out), .s(sel[1]), .Y(clk_out));

endmodule
`endif