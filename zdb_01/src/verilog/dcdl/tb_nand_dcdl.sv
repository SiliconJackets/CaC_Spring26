//**************************************************************************
// Author: Alfi Misha Antony Selvin Raj
// Description: Sanity check for delay line (NOT INCLUDED IN TOP)
//**************************************************************************
//not in the include this is just for my debug purpose.
`timescale 1ns/1ps

module tb_nand_dcdl;

logic A;
logic [3:0] Q;
logic Y;

nand_dcdl dut (
    .A(A),
    .Q(Q),
    .Y(Y)
);

initial begin
    $display("Starting DCDL sanity test...");

    A = 0;
    Q = 4'b0001;

    #5 A = 1;

    // Sweep one-hot entries
    #10 Q = 4'b0001;
    #10 Q = 4'b0010;
    #10 Q = 4'b0100;
    #10 Q = 4'b1000;

    // Toggle A again
    #10 A = 0;
    #10 A = 1;

    #20 $finish;
end

// Monitor signals
initial begin
    $monitor("t=%0t  A=%b  Q=%b  Y=%b",
             $time, A, Q, Y);
end

endmodule
