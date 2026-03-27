`timescale 1ps/1ps

module tb_nand_dcdl_top_viz;

    logic clk, rst_n, shift_left, shift_right, A, Y;

    nand_dcdl_top dut (
        .clk(clk), .rst_n(rst_n),
        .shift_left(shift_left), .shift_right(shift_right),
        .A(A), .Y(Y)
    );

    initial clk = 0;
    always #5000 clk = ~clk;

    reg [8*512-1:0] fsdbpath;
    integer i;

    task do_shift_left;
        begin
            @(negedge clk); shift_left = 1; shift_right = 0;
            @(posedge clk); @(negedge clk); shift_left = 0;
        end
    endtask

    task do_shift_right;
        begin
            @(negedge clk); shift_right = 1; shift_left = 0;
            @(posedge clk); @(negedge clk); shift_right = 0;
        end
    endtask

    initial begin
        if (!$value$plusargs("fsdbpath=%s", fsdbpath)) fsdbpath = "dump.fsdb";

        $fsdbDumpfile(fsdbpath);
        $fsdbDumpvars(0, dut);

        rst_n = 0; shift_left = 0; shift_right = 0; A = 0;
        repeat (2) @(posedge clk);
        rst_n = 1; @(posedge clk); A = 1;

        // Demo: shift left through all positions, then back — shows Q rotation
        for (i = 0; i < 3; i = i + 1) begin
            repeat (4) begin @(posedge clk); A = ~A; end
            do_shift_left;
        end
        repeat (4) begin @(posedge clk); A = ~A; end
        for (i = 0; i < 3; i = i + 1) begin
            do_shift_right;
            repeat (4) begin @(posedge clk); A = ~A; end
        end
        A = 0; repeat (2) @(posedge clk);

        $finish;
    end

endmodule
