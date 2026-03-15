//**************************************************************************
// Author: Alfi Misha Antony Selvin Raj
// Description: Sanity check shift register (NOT INCLUDED IN TOP)
//**************************************************************************
//not in the include this is for debug
`timescale 1ns/1ps
module tb_dll_shift_register;
logic clk;
logic rst_n;
logic shift_left;
logic shift_right;
logic [3:0] Q;
dll_shift_register dut (
    .clk(clk),
    .rst_n(rst_n),
    .shift_left(shift_left),
    .shift_right(shift_right),
    .Q(Q)
);

initial clk = 0;
always #5 clk = ~clk;
initial begin
    $display("Starting shift register test");

    rst_n = 0;
    shift_left = 0;
    shift_right = 0;

    #20;
    rst_n = 1;

    // shift left sequence
    repeat (4) begin
        #5 shift_left = 1;
        #5 shift_left = 0;
    end

    // shift right sequence
    repeat (4) begin
        #5 shift_right = 1; //only changes at the posedge of the clock. 
        #5 shift_right = 0;
    end

    #20;
    $finish;
end
always @(posedge clk) begin
    $display("t=%0t  Q=%b", $time, Q);
end

endmodule