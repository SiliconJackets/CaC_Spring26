`timescale 1ns/1ps

module tb_inv_dcdl_glitch_free;

    logic clk;
    logic rst_n;
    logic A;
    logic [1:0] Q;
    logic Y;

    // DUT (FIXED NAME)
    inv_dcdl_glitch_free dut (
        .clk(clk),
        .rst_n(rst_n),
        .A(A),
        .Q(Q),
        .Y(Y)
    );

    // Clock: 10ns period
    always #5 clk = ~clk;

    // Task to apply one test case (clean + reusable)
    task apply_test(input [1:0] q_val);
    begin
        Q = q_val;

        // wait for select to register
        @(posedge clk);

        // apply input toggle
        A = 1;
        @(posedge clk);

        A = 0;
        @(posedge clk);
    end
    endtask

    initial begin
        // Init
        clk   = 0;
        rst_n = 0;
        A     = 0;
        Q     = 2'b00;

        // Reset
        repeat (2) @(posedge clk);
        rst_n = 1;

        // Wait one cycle after reset
        @(posedge clk);

        // Run test cases
        apply_test(2'b00); // smallest delay
        apply_test(2'b01); // medium
        apply_test(2'b10); // larger
        apply_test(2'b11); // largest

        // Finish
        #20;
        $finish;
    end

    // Waveform dump
    initial begin
        $dumpfile("dcdl_simple.vcd");
        $dumpvars(0, tb_inv_dcdl_glitch_free);
    end

endmodule