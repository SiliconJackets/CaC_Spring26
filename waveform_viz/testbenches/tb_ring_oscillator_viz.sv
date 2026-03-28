`timescale 1ns/1ps

module tb_ring_oscillator_viz;

    logic [1:0] sel;
    logic clk_out;

    ring_oscillator dut (.sel(sel), .clk_out(clk_out));

    reg [8*512-1:0] fsdbpath;

    initial begin
        if (!$value$plusargs("fsdbpath=%s", fsdbpath)) fsdbpath = "dump.fsdb";

        $fsdbDumpfile(fsdbpath);
        $fsdbDumpvars(0, dut);

        // Demo: sweep sel values — shows frequency selection
        sel = 2'b00; #200;
        sel = 2'b01; #200;
        sel = 2'b10; #200;
        sel = 2'b11; #200;
        sel = 2'b00; #50;

        $finish;
    end

endmodule
