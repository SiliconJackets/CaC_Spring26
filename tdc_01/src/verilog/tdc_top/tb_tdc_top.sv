`timescale 1ps/1ps

module tb_tdc_top;

    // -------------------------------------------------------------
    // Parameters
    // -------------------------------------------------------------
    localparam N = 16;
    localparam CTRL_BITS = $clog2(N);
    localparam CLK_PERIOD = 1000; // 1ns

    // -------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------
    reg clk_ref;
    reg stop_clk;
    reg rst;

    wire clk_out;
    wire [N-1:0] clk_phases;
    wire [N-1:0] thermo_out;
    wire [$clog2(N+1)-1:0] time_out;

    wire [CTRL_BITS-1:0] ctrl_dbg;
    wire up_dbg, down_dbg;

    // -------------------------------------------------------------
    // Instantiate DUT
    // -------------------------------------------------------------
    tdc_top #(
        .N(N)
    ) uut (
        .clk_ref(clk_ref),
        .rst(rst),
        .stop_clk(stop_clk),

        .clk_out(clk_out),
        .clk_phases(clk_phases),
        .thermo_out(thermo_out),
        .time_out(time_out),

        .ctrl_dbg(ctrl_dbg),
        .up_dbg(up_dbg),
        .down_dbg(down_dbg)
    );

    // -------------------------------------------------------------
    // Clock generation
    // -------------------------------------------------------------
    initial begin
        clk_ref = 0;
        forever #(CLK_PERIOD/2) clk_ref = ~clk_ref;
    end

    // STOP clock (slightly offset)
    initial begin
        stop_clk = 0;
        forever #(CLK_PERIOD/2 + 137) stop_clk = ~stop_clk;
    end

    // -------------------------------------------------------------
    // Reset
    // -------------------------------------------------------------
    initial begin
        rst = 1;
        #2000;
        rst = 0;
    end

    // -------------------------------------------------------------
    // Wave dump
    // -------------------------------------------------------------
    initial begin
        $dumpfile("dll_tdc.vcd");
        $dumpvars(0, tb_dll_tdc_top);
    end

    // =============================================================
    // 🧠 SELF-CHECKING LOGIC
    // =============================================================

    // -------------------------------------------------------------
    // 1. DLL LOCK DETECTION
    // -------------------------------------------------------------
    integer stable_count = 0;
    reg [CTRL_BITS-1:0] ctrl_prev;

    always @(posedge clk_ref) begin
        if (ctrl_dbg == ctrl_prev)
            stable_count++;
        else
            stable_count = 0;

        ctrl_prev <= ctrl_dbg;
    end

    // -------------------------------------------------------------
    // 2. Thermometer correctness check
    // -------------------------------------------------------------
    function integer count_ones(input [N-1:0] val);
        integer i;
        begin
            count_ones = 0;
            for (i = 0; i < N; i = i + 1)
                if (val[i]) count_ones++;
        end
    endfunction

    // -------------------------------------------------------------
    // 3. Check thermometer monotonicity
    // -------------------------------------------------------------
    task check_thermo;
        integer i;
        begin
            for (i = 1; i < N; i = i + 1) begin
                if (thermo_out[i] && !thermo_out[i-1]) begin
                    $display("❌ ERROR: Bubble detected at index %0d", i);
                end
            end
        end
    endtask

    // -------------------------------------------------------------
    // 4. Phase ordering check
    // -------------------------------------------------------------
    time t_phase [0:N-1];

    generate
        genvar k;
        for (k = 0; k < N; k++) begin : phase_capture
            always @(posedge clk_phases[k])
                t_phase[k] = $time;
        end
    endgenerate

    task check_phase_order;
        integer i;
        begin
            for (i = 1; i < N; i = i + 1) begin
                if (t_phase[i] < t_phase[i-1]) begin
                    $display("❌ ERROR: Phase ordering broken at %0d", i);
                end
            end
        end
    endtask

    // -------------------------------------------------------------
    // 5. Main check sequence
    // -------------------------------------------------------------
    initial begin
        wait (rst == 0);

        // wait for DLL to lock
        wait (stable_count > 20);

        $display("\n✅ DLL LOCK DETECTED\n");

        repeat (20) begin
            @(posedge stop_clk);

            // Check thermometer correctness
            check_thermo();

            // Check encoder correctness
            if (time_out !== count_ones(thermo_out)) begin
                $display("❌ ERROR: Encoder mismatch. Thermo=%b Count=%0d Encoded=%0d",
                         thermo_out,
                         count_ones(thermo_out),
                         time_out);
            end else begin
                $display("✅ OK: Thermo=%b Time=%0d", thermo_out, time_out);
            end
        end

        // Check phase ordering once
        #1000;
        check_phase_order();

        $display("\n🎉 TEST PASSED (if no errors above)\n");

        #2000;
        $finish;
    end

endmodule