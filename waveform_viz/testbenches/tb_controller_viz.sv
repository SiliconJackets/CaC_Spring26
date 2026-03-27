`timescale 1ps/1ps

module tb_controller_viz;

    parameter integer CTRL_BITS = 6;
    parameter integer INIT_CTRL = 32;

    reg clk_in, rst, up, down;
    wire [CTRL_BITS-1:0] ctrl;

    controller #(
        .CTRL_BITS(CTRL_BITS),
        .INIT_CTRL(INIT_CTRL)
    ) dut (
        .clk_in(clk_in), .rst(rst), .up(up), .down(down), .ctrl(ctrl)
    );

    initial clk_in = 1'b0;
    always #5000 clk_in = ~clk_in;

    reg [8*512-1:0] fsdbpath;

    initial begin
        if (!$value$plusargs("fsdbpath=%s", fsdbpath)) fsdbpath = "dump.fsdb";

        $fsdbDumpfile(fsdbpath);
        $fsdbDumpvars(0, dut);

        // Reset
        rst = 1; up = 0; down = 0;
        repeat (2) @(posedge clk_in);
        rst = 0;
        @(posedge clk_in);

        // Demo: ramp up, hold, ramp down — shows typical controller behavior
        up = 1; down = 0;
        repeat (40) @(posedge clk_in);

        up = 0; down = 0;
        repeat (8) @(posedge clk_in);

        up = 0; down = 1;
        repeat (40) @(posedge clk_in);

        up = 0; down = 0;
        repeat (4) @(posedge clk_in);

        $finish;
    end

endmodule
