//**************************************************************************
// Author: Alfi Misha Antony Selvin Raj
// Description: Single NAND based delay cell for 4 stage Nand Delay line
//**************************************************************************
(* dont_touch = "true" *) //telling synthesizer not to optimize this as nand gates can be changed to 2:1 MUX
module nand_dcdl_cell(
    input logic in1,
    input logic in0, 
    input logic ctl, 
    output logic out
);
    (* keep = "true" *) logic n1; //extra synthesis protection
    (* keep = "true" *) logic n2;
    assign n1 = ~(in1 & ~ctl);
    assign n2 = ~(in0 & ctl);
    assign out = ~(n1 & n2);
endmodule