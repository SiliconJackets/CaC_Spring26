/* |======================================================================= */                                                            
/* | Author             : Shreyas Angadi                                                  
/* | Description        : Phase Detector based off of 3 RS-latches                                                                      
/* |======================================================================= */

module latch_detector (
    input logic clk_in, 
    input logic clk_out,
    
);
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
always_comb begin
    case (sel)
        2'b00: clk_out = n2;
        2'b01: clk_out = n4;
        2'b10: clk_out = n6;
        2'b11: clk_out = n8;
    endcase
end
endmodule