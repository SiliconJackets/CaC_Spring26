`timescale 1ps/1ps

module tb_bangbang_pd;

    logic clk_in;
    logic clk_out;
    logic rst;
    logic up;
    logic down;

    int errors;

    // DUT
    bangbang_pd dut (
        .clk_in  (clk_in),
        .clk_out (clk_out),
        .rst     (rst),
        .up      (up),
        .down    (down)
    );

    // ------------------------------------------------------------
    // Check task
    // ------------------------------------------------------------
    task automatic check_outputs(
        input logic exp_up,
        input logic exp_down,
        input string name
    );
        begin
            #1;
            if ((up !== exp_up) || (down !== exp_down)) begin
                $display("[%0t ps] ERROR: %s | expected up=%0b down=%0b, got up=%0b down=%0b",
                         $time, name, exp_up, exp_down, up, down);
                errors++;
            end else begin
                $display("[%0t ps] PASS : %s | up=%0b down=%0b",
                         $time, name, up, down);
            end
        end
    endtask

    // ------------------------------------------------------------
    // Drive a clean posedge on clk_in
    // ------------------------------------------------------------
    task automatic pulse_clk_in;
        begin
            clk_in = 1'b0;
            #5;
            clk_in = 1'b1;
            #5;
            clk_in = 1'b0;
        end
    endtask

    // ------------------------------------------------------------
    // Drive a clean posedge on clk_out
    // ------------------------------------------------------------
    task automatic pulse_clk_out;
        begin
            clk_out = 1'b0;
            #5;
            clk_out = 1'b1;
            #5;
            clk_out = 1'b0;
        end
    endtask

    // ------------------------------------------------------------
    // Main stimulus
    // ------------------------------------------------------------
    initial begin
        errors  = 0;
        clk_in  = 1'b0;
        clk_out = 1'b0;
        rst     = 1'b1;

        $display("==========================================");
        $display("Starting synthesizable BBPD self-checking testbench");
        $display("==========================================");

        // --------------------------------------------------------
        // Test 0: reset
        // --------------------------------------------------------
        #2;
        check_outputs(1'b0, 1'b0, "reset asserted clears outputs");

        rst = 1'b0;
        #2;
        check_outputs(1'b0, 1'b0, "after reset release, outputs remain cleared");

        // --------------------------------------------------------
        // Test 1:
        // clk_out is LOW when clk_in rises -> UP=1, DOWN=0
        // --------------------------------------------------------
        clk_out = 1'b0;
        pulse_clk_in();
        check_outputs(1'b1, 1'b0, "clk_out low at posedge clk_in -> UP");

        // --------------------------------------------------------
        // Test 2:
        // clk_out is HIGH when clk_in rises -> UP=0, DOWN=1
        // --------------------------------------------------------
        clk_out = 1'b1;
        #5;
        clk_in = 1'b1;
        #1;
        check_outputs(1'b0, 1'b1, "clk_out high at posedge clk_in -> DOWN");
        #4;
        clk_in = 1'b0;

        // --------------------------------------------------------
        // Test 3:
        // clk_out edge alone should not change outputs immediately
        // --------------------------------------------------------
        // First force known state = UP
        clk_out = 1'b0;
        pulse_clk_in();
        check_outputs(1'b1, 1'b0, "precondition: UP state established");

        // Now toggle clk_out only
        #5;
        clk_out = 1'b1;
        #1;
        check_outputs(1'b1, 1'b0, "clk_out toggle alone does not update outputs");

        #4;
        clk_out = 1'b0;
        #1;
        check_outputs(1'b1, 1'b0, "clk_out falling edge alone also does not update outputs");

        // --------------------------------------------------------
        // Test 4:
        // After clk_out goes high, next clk_in edge should produce DOWN
        // --------------------------------------------------------
        #5;
        clk_out = 1'b1;
        #5;
        clk_in = 1'b1;
        #1;
        check_outputs(1'b0, 1'b1, "next clk_in samples clk_out=1 -> DOWN");
        #4;
        clk_in = 1'b0;

        // --------------------------------------------------------
        // Test 5:
        // Multiple clk_in samples while clk_out stays low -> stay UP
        // --------------------------------------------------------
        clk_out = 1'b0;
        pulse_clk_in();
        check_outputs(1'b1, 1'b0, "sample 1 with clk_out low -> UP");

        pulse_clk_in();
        check_outputs(1'b1, 1'b0, "sample 2 with clk_out low -> still UP");

        // --------------------------------------------------------
        // Test 6:
        // Multiple clk_in samples while clk_out stays high -> stay DOWN
        // --------------------------------------------------------
        clk_out = 1'b1;
        #2;
        pulse_clk_in();
        check_outputs(1'b0, 1'b1, "sample 1 with clk_out high -> DOWN");

        pulse_clk_in();
        check_outputs(1'b0, 1'b1, "sample 2 with clk_out high -> still DOWN");

        // --------------------------------------------------------
        // Test 7:
        // Reset in the middle of operation
        // --------------------------------------------------------
        rst = 1'b1;
        #1;
        check_outputs(1'b0, 1'b0, "mid-run reset clears outputs");

        rst = 1'b0;
        #2;
        check_outputs(1'b0, 1'b0, "after mid-run reset release");

        // --------------------------------------------------------
        // Test 8:
        // Near-coincident event check
        // Set clk_out before clk_in edge => DOWN
        // --------------------------------------------------------
        clk_in  = 1'b0;
        clk_out = 1'b0;
        #4;
        clk_out = 1'b1;
        #1;
        clk_in  = 1'b1;
        #1;
        check_outputs(1'b0, 1'b1, "clk_out high just before clk_in edge -> DOWN");
        #4;
        clk_in = 1'b0;

        // --------------------------------------------------------
        // Test 9:
        // clk_out low just before clk_in edge => UP
        // --------------------------------------------------------
        clk_in  = 1'b0;
        clk_out = 1'b1;
        #4;
        clk_out = 1'b0;
        #1;
        clk_in  = 1'b1;
        #1;
        check_outputs(1'b1, 1'b0, "clk_out low just before clk_in edge -> UP");
        #4;
        clk_in = 1'b0;

        // --------------------------------------------------------
        // Final report
        // --------------------------------------------------------
        $display("==========================================");
        if (errors == 0)
            $display("TESTBENCH PASSED: no errors");
        else
            $display("TESTBENCH FAILED: %0d error(s)", errors);
        $display("==========================================");

        $finish;
    end

endmodule