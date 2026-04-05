`timescale 1ps/1ps

module tb_zdb_top_with_ro;

    // ----------------------------------------
    // Inputs
    // ----------------------------------------
    logic clk_in;
    logic rst;
    logic [1:0] ro_sel;

    // ----------------------------------------
    // Outputs
    // ----------------------------------------
    wire clk_out;
    wire [5:0] ctrl_dbg;
    wire up_dbg;
    wire down_dbg;
    wire shift_left_dbg;
    wire shift_right_dbg;

    // ----------------------------------------
    // DUT
    // ----------------------------------------
    zdb_top_with_ro dut (
        .clk_in(clk_in),
        .rst(rst),
        .ro_sel(ro_sel),
        .clk_out(clk_out),
        .ctrl_dbg(ctrl_dbg),
        .up_dbg(up_dbg),
        .down_dbg(down_dbg),
        .shift_left_dbg(shift_left_dbg),
        .shift_right_dbg(shift_right_dbg)
    );

    // ----------------------------------------
    // Input signal (THIS is what gets delayed)
    // ----------------------------------------
    always #7000 clk_in = ~clk_in;   // ~14ns period

    // ----------------------------------------
    // DISPLAY / MONITOR
    // ----------------------------------------
    initial begin
        $display("TIME\tRO_SEL\tclk_in\tclk_out\tCTRL\tUP\tDOWN\tSL\tSR");
        $monitor("%0t\t%b\t%b\t%b\t%0d\t%b\t%b\t%b\t%b",
            $time, ro_sel, clk_in, clk_out,
            ctrl_dbg, up_dbg, down_dbg,
            shift_left_dbg, shift_right_dbg
        );
    end

    // ----------------------------------------
    // Phase Error Measurement
    // ----------------------------------------
    time t_in, t_out;

    always @(posedge clk_in) begin
        t_in = $time;
    end

    always @(posedge clk_out) begin
        t_out = $time;
        $display(">>> Phase Error = %0t ps (RO_SEL=%b)", t_out - t_in, ro_sel);
    end

    // ----------------------------------------
    // Stimulus
    // ----------------------------------------
    initial begin
        // Init
        clk_in = 0;
        rst    = 1;
        ro_sel = 2'b00;

        // Reset
        #20000;
        rst = 0;

        // Let system settle
        #100000;

        // ------------------------------------
        // Test 1: FAST RO (few stages)
        // ------------------------------------
        $display("\n========== TEST 1: FAST RO (sel=00) ==========\n");
        ro_sel = 2'b00;
        #150000;

        // ------------------------------------
        // Test 2: MEDIUM RO
        // ------------------------------------
        $display("\n========== TEST 2: MEDIUM RO (sel=01) ==========\n");
        ro_sel = 2'b01;
        #150000;

        // ------------------------------------
        // Test 3: SLOW RO
        // ------------------------------------
        $display("\n========== TEST 3: SLOW RO (sel=10) ==========\n");
        ro_sel = 2'b10;
        #150000;

        // ------------------------------------
        // Test 4: SLOWEST RO
        // ------------------------------------
        $display("\n========== TEST 4: SLOWEST RO (sel=11) ==========\n");
        ro_sel = 2'b11;
        #150000;

        // ------------------------------------
        // Change input signal frequency
        // ------------------------------------
        $display("\n========== TEST 5: INPUT FREQ CHANGE ==========\n");

        fork
            begin
                forever #4000 clk_in = ~clk_in;  // faster signal
            end
        join_none

        #200000;

        $finish;
    end

    // ----------------------------------------
    // Waveform dump
    // ----------------------------------------
    initial begin
        $dumpfile("zdb_with_ro.vcd");
        $dumpvars(0, tb_zdb_top_with_ro);
    end

endmodule