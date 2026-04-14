//**************************************************************************
// Author: Alfi Misha Antony Selvin Raj
// Description: Single NAND based delay cell for 4 stage Nand Delay line
//**************************************************************************
(* dont_touch = "true" *) //telling synthesizer not to optimize this as nand gates can be changed to 2:1 MUX
`timescale 1ps/1ps
module nand_dcdl_cell(
    input logic in1,
    input logic in0, 
    input logic ctl, 
    output logic out
);
    parameter real D_NAND = 0.100ns;
    parameter real D_INV  = 0.094ns;

    (* keep = "true" *) logic inv1_output;
    (* keep = "true" *) logic nand_cell_1;
    (* keep = "true" *) logic nand_cell_2;
    assign #(D_INV) inv1_output = ~ctl;
    assign #(D_NAND) nand_cell_1 = ~(in1 & inv1_output);
    assign #(D_NAND) nand_cell_2 = ~(in0 & ctl);
    assign #(D_NAND) out = ~(nand_cell_1 & nand_cell_2);
    //assign n2 = ~(in0 & ctl);
    //assign out = ~(n1 & n2);
endmodule