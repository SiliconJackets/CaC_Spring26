`timescale 1ns/1ps

module tb_inv_dcdl_simple;

    logic clk;
    logic rst_n;
    logic A;
    logic [1:0] Q;
    logic Y;

    // DUT
    inv_dcdl dut (
        .clk(clk),
        .rst_n(rst_n),
        .A(A),
        .Q(Q),
        .Y(Y)
    );

    // Clock
    always #5 clk = ~clk;

    initial begin
        // Init
        clk   = 0;
        rst_n = 0;
        A     = 0;
        Q     = 2'b00;

        // Reset
        #10;
        rst_n = 1;

        // Case 1: small delay
        Q = 2'b00;
        #10 A = 1;
        #20 A = 0;

        // Case 2: medium delay
        Q = 2'b01;
        #10 A = 1;
        #20 A = 0;

        // Case 3: larger delay
        Q = 2'b10;
        #10 A = 1;
        #20 A = 0;

        // Case 4: largest delay
        Q = 2'b11;
        #10 A = 1;
        #20 A = 0;

        #50;
        $finish;
    end

    // Dump waveform
    initial begin
        $dumpfile("dcdl_simple.vcd");
        $dumpvars(0, tb_inv_dcdl_simple);
    end

endmodule