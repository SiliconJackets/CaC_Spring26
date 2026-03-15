//**************************************************************************
// Author: Alfi Misha Antony Selvin Raj
// Description: Sanity check for top (INCLUDED IN INCLUDE)
//**************************************************************************
`timescale 1ns/1ps

module tb_nand_dcdl_top;

logic clk;
logic rst_n;
logic shift_left;
logic shift_right;
logic A;
logic Y;

nand_dcdl_top dut (
    .clk(clk),
    .rst_n(rst_n),
    .shift_left(shift_left),
    .shift_right(shift_right),
    .A(A),
    .Y(Y)
);

//
// clock generation
//
initial clk = 0;
always #5 clk = ~clk;

//
// stimulus
//
initial begin
    $display("Starting nand_dcdl_top test");

    rst_n = 0;
    shift_left = 0;
    shift_right = 0;
    A = 0;

    #20;
    rst_n = 1;

    // drive the input signal into the delay line
    #10 A = 1;

    // move delay forward
    repeat (4) begin
        @(posedge clk);
        shift_left = 1;
        @(posedge clk);
        shift_left = 0;
    end

    // move delay backward
    repeat (4) begin
        @(posedge clk);
        shift_right = 1;
        @(posedge clk);
        shift_right = 0;
    end

    #40;
    $finish;
end

//
// monitor behavior
//
always @(posedge clk) begin
    $display("t=%0t  A=%b  Q=%b  Y=%b",
        $time, A, dut.Q, Y);
end

endmodule
