`timescale 1ps/1ps

module tb_inv_dcdl_glitch_free_viz;

    logic clk, rst_n, A;
    logic [1:0] Q;
    logic Y;

    inv_dcdl_glitch_free dut (
        .clk(clk), .rst_n(rst_n), .A(A), .Q(Q), .Y(Y)
    );

    initial clk = 0;
    always #5000 clk = ~clk;

    reg [8*512-1:0] fsdbpath;
    integer i;

    initial begin
        if (!$value$plusargs("fsdbpath=%s", fsdbpath)) fsdbpath = "dump.fsdb";

        $fsdbDumpfile(fsdbpath);
        $fsdbDumpvars(0, dut);

        rst_n = 0; A = 0; Q = 2'b00;
        repeat (2) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        // Demo: sweep Q with A toggling — shows glitch-free registered selection
        for (i = 0; i < 4; i = i + 1) begin
            Q = i[1:0];
            @(posedge clk);
            repeat (8) #5000 A = ~A;
        end
        A = 0; repeat (2) @(posedge clk);

        $finish;
    end

endmodule
