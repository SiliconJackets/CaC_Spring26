`timescale 1ps/1ps

module tb_phase_detector_viz;

    reg  clk_in, clk_out, rst;
    wire up, down;

    phase_detector dut (
        .clk_in(clk_in), .clk_out(clk_out), .rst(rst),
        .up(up), .down(down)
    );

    reg [8*512-1:0] fsdbpath;

    initial begin
        if (!$value$plusargs("fsdbpath=%s", fsdbpath)) fsdbpath = "dump.fsdb";

        $fsdbDumpfile(fsdbpath);
        $fsdbDumpvars(0, dut);

        clk_in = 0; clk_out = 0; rst = 1;
        #10000; rst = 0; #5000;

        // Demo: clk_out lags clk_in by 2ns — typical PD usage showing UP dominance
        begin : lag_demo
            integer ii, half, phase;
            half = 5000;   // 10ns period
            phase = 2000;  // 2ns lag
            for (ii = 0; ii < 16; ii = ii + 1) begin
                clk_in = 1; #(phase); clk_out = 1; #(half - phase);
                clk_in = 0; #(phase); clk_out = 0; #(half - phase);
            end
        end

        clk_in = 0; clk_out = 0; #5000;
        $finish;
    end

endmodule
