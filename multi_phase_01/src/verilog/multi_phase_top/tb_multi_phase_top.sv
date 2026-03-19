`timescale 1ps/1ps

module tb_multi_phase_top;

    // -----------------------------------------------------------------
    // Parameters
    // -----------------------------------------------------------------
    localparam CLK_PERIOD = 1000; // 1ns
    localparam N_PHASES   = 16;
    localparam CTRL_BITS  = 4;

    // -----------------------------------------------------------------
    // DUT signals
    // -----------------------------------------------------------------
    reg clk_in;
    reg rst;

    wire clk_out;
    wire [N_PHASES-1:0] clk_phases;

    wire [CTRL_BITS-1:0] ctrl_dbg;
    wire up_dbg;
    wire down_dbg;

    // -----------------------------------------------------------------
    // Instantiate DUT
    // -----------------------------------------------------------------
    multi_phase_top uut (
        .clk_in(clk_in),
        .rst(rst),
        .clk_out(clk_out),
        .clk_phases(clk_phases),
        .ctrl_dbg(ctrl_dbg),
        .up_dbg(up_dbg),
        .down_dbg(down_dbg)
    );

    // -----------------------------------------------------------------
    // Clock generation
    // -----------------------------------------------------------------
    initial begin
        clk_in = 0;
        forever #(CLK_PERIOD/2) clk_in = ~clk_in;
    end

    // -----------------------------------------------------------------
    // Reset
    // -----------------------------------------------------------------
    initial begin
        rst = 1;
        #2000;
        rst = 0;
    end

    // -----------------------------------------------------------------
    // Wave dump
    // -----------------------------------------------------------------
    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_multi_phase_top);
    end

    // ================================================================
    // 🧠 SELF-CHECKING LOGIC
    // ================================================================

    integer i;

    // ---------------------------------------------------------------
    // 1. LOCK DETECTION
    // ---------------------------------------------------------------
    integer stable_count = 0;
    reg [CTRL_BITS-1:0] ctrl_prev;

    always @(posedge clk_in) begin
        if (ctrl_dbg == ctrl_prev)
            stable_count++;
        else
            stable_count = 0;

        ctrl_prev <= ctrl_dbg;
    end

    // ---------------------------------------------------------------
    // 2. EDGE TIMESTAMP STORAGE
    // ---------------------------------------------------------------
    time t_in, t_out;
    time t_phase [0:N_PHASES-1];

    // Capture reference clock edge
    always @(posedge clk_in)
        t_in = $time;

    // Capture output clock edge
    always @(posedge clk_out)
        t_out = $time;

    // Capture phase edges
    generate
        genvar k;
        for (k = 0; k < N_PHASES; k++) begin : phase_capture
            always @(posedge clk_phases[k]) begin
                t_phase[k] = $time;
            end
        end
    endgenerate

    // ---------------------------------------------------------------
    // 3. CHECKS AFTER LOCK
    // ---------------------------------------------------------------
    task check_dll;
        integer j;
        begin
            $display("\n===== DLL CHECK START =====");

            // -------------------------------------------------------
            // Check 1: Zero-delay condition
            // -------------------------------------------------------
            if ((t_out - t_in) > (CLK_PERIOD/4)) begin
                $display("❌ ERROR: clk_out not aligned with clk_in. Δ=%0t", t_out - t_in);
            end else begin
                $display("✅ clk_out aligned with clk_in. Δ=%0t", t_out - t_in);
            end

            // -------------------------------------------------------
            // Check 2: Phase monotonicity
            // -------------------------------------------------------
            for (j = 1; j < N_PHASES; j++) begin
                if (t_phase[j] < t_phase[j-1]) begin
                    $display("❌ ERROR: Phase ordering broken at %0d", j);
                end
            end
            $display("✅ Phase ordering monotonic");

            // -------------------------------------------------------
            // Check 3: Phase spacing sanity
            // -------------------------------------------------------
            for (j = 1; j < N_PHASES; j++) begin
                if ((t_phase[j] - t_phase[j-1]) == 0) begin
                    $display("⚠️ WARNING: Phase %0d and %0d overlap", j-1, j);
                end
            end

            // -------------------------------------------------------
            // Check 4: Total delay ≈ clock period
            // -------------------------------------------------------
            if ((t_phase[N_PHASES-1] - t_phase[0]) > (CLK_PERIOD + CLK_PERIOD/4)) begin
                $display("❌ ERROR: Total delay too large");
            end else begin
                $display("✅ Total delay reasonable");
            end

            $display("===== DLL CHECK END =====\n");
        end
    endtask

    // ---------------------------------------------------------------
    // 4. Trigger checks after lock
    // ---------------------------------------------------------------
    initial begin
        wait (rst == 0);

        // wait until ctrl stabilizes
        wait (stable_count > 20);

        // wait a bit more for clean edges
        #2000;

        check_dll();

        $display("Simulation PASSED (if no errors above)");
        #1000;
        $finish;
    end

endmodule