`timescale 1ps/1ps

module tb_bangbang_pd_industry;

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
    // Utility: check current outputs
    // ------------------------------------------------------------
    task automatic check_now(
        input logic exp_up,
        input logic exp_down,
        input string msg
    );
        begin
            #1;
            if ((up !== exp_up) || (down !== exp_down)) begin
                $display("[%0t ps] ERROR: %s | expected up=%0b down=%0b, got up=%0b down=%0b",
                         $time, msg, exp_up, exp_down, up, down);
                errors++;
            end else begin
                $display("[%0t ps] PASS : %s | up=%0b down=%0b",
                         $time, msg, up, down);
            end
        end
    endtask

    // ------------------------------------------------------------
    // Utility: generate a posedge on clk_in
    // ------------------------------------------------------------
    task automatic pulse_clk_in;
        begin
            clk_in = 1'b0;
            #5;
            clk_in = 1'b1;
            #1;
            clk_in = 1'b0;
        end
    endtask

    // ------------------------------------------------------------
    // Utility: generate a posedge on clk_out
    // ------------------------------------------------------------
    task automatic pulse_clk_out;
        begin
            clk_out = 1'b0;
            #5;
            clk_out = 1'b1;
            #1;
            clk_out = 1'b0;
        end
    endtask

    // ------------------------------------------------------------
    // Main test sequence
    // ------------------------------------------------------------
    initial begin
        errors  = 0;
        clk_in  = 1'b0;
        clk_out = 1'b0;
        rst     = 1'b1;

        $display("==================================================");
        $display("Starting industry 2-FF auto-reset BBPD testbench");
        $display("==================================================");

        // --------------------------------------------------------
        // Test 0: reset behavior
        // --------------------------------------------------------
        check_now(1'b0, 1'b0, "reset asserted -> outputs cleared");

        rst = 1'b0;
        check_now(1'b0, 1'b0, "after reset release -> outputs remain cleared");

        // --------------------------------------------------------
        // Test 1: clk_in edge alone should assert UP
        // --------------------------------------------------------
        pulse_clk_in();
        check_now(1'b1, 1'b0, "clk_in edge alone -> UP asserted");

        // --------------------------------------------------------
        // Test 2: clk_out edge after UP should cause auto-reset
        // --------------------------------------------------------
        pulse_clk_out();
        check_now(1'b0, 1'b0, "clk_out edge after UP -> both set then auto-reset");

        // --------------------------------------------------------
        // Test 3: clk_out edge alone should assert DOWN
        // --------------------------------------------------------
        pulse_clk_out();
        check_now(1'b0, 1'b1, "clk_out edge alone -> DOWN asserted");

        // --------------------------------------------------------
        // Test 4: clk_in edge after DOWN should cause auto-reset
        // --------------------------------------------------------
        pulse_clk_in();
        check_now(1'b0, 1'b0, "clk_in edge after DOWN -> both set then auto-reset");

        // --------------------------------------------------------
        // Test 5: two clk_in edges in a row should keep UP high
        // --------------------------------------------------------
        pulse_clk_in();
        check_now(1'b1, 1'b0, "first clk_in edge -> UP asserted");

        pulse_clk_in();
        check_now(1'b1, 1'b0, "second clk_in edge -> UP remains asserted");

        // complete the cycle with clk_out -> reset
        pulse_clk_out();
        check_now(1'b0, 1'b0, "clk_out completes pair -> auto-reset");

        // --------------------------------------------------------
        // Test 6: two clk_out edges in a row should keep DOWN high
        // --------------------------------------------------------
        pulse_clk_out();
        check_now(1'b0, 1'b1, "first clk_out edge -> DOWN asserted");

        pulse_clk_out();
        check_now(1'b0, 1'b1, "second clk_out edge -> DOWN remains asserted");

        // complete the cycle with clk_in -> reset
        pulse_clk_in();
        check_now(1'b0, 1'b0, "clk_in completes pair -> auto-reset");

        // --------------------------------------------------------
        // Test 7: reset in middle of UP state
        // --------------------------------------------------------
        pulse_clk_in();
        check_now(1'b1, 1'b0, "UP asserted before reset");

        rst = 1'b1;
        check_now(1'b0, 1'b0, "reset clears UP");

        rst = 1'b0;
        check_now(1'b0, 1'b0, "after reset release from UP state");

        // --------------------------------------------------------
        // Test 8: reset in middle of DOWN state
        // --------------------------------------------------------
        pulse_clk_out();
        check_now(1'b0, 1'b1, "DOWN asserted before reset");

        rst = 1'b1;
        check_now(1'b0, 1'b0, "reset clears DOWN");

        rst = 1'b0;
        check_now(1'b0, 1'b0, "after reset release from DOWN state");

        // --------------------------------------------------------
        // Test 9: near-coincident edges, clk_in first then clk_out
        // Expect UP briefly, then reset after clk_out
        // --------------------------------------------------------
        clk_in  = 1'b0;
        clk_out = 1'b0;

        #5  clk_in  = 1'b1;
        #1;
        check_now(1'b1, 1'b0, "near-coincident case: clk_in first -> UP");

        clk_in = 1'b0;
        #1  clk_out = 1'b1;
        #1;
        check_now(1'b0, 1'b0, "near-coincident case: clk_out second -> auto-reset");

        clk_out = 1'b0;

        // --------------------------------------------------------
        // Test 10: near-coincident edges, clk_out first then clk_in
        // Expect DOWN briefly, then reset after clk_in
        // --------------------------------------------------------
        #5  clk_out = 1'b1;
        #1;
        check_now(1'b0, 1'b1, "near-coincident case: clk_out first -> DOWN");

        clk_out = 1'b0;
        #1  clk_in = 1'b1;
        #1;
        check_now(1'b0, 1'b0, "near-coincident case: clk_in second -> auto-reset");

        clk_in = 1'b0;

        // --------------------------------------------------------
        // Final report
        // --------------------------------------------------------
        $display("==================================================");
        if (errors == 0)
            $display("TESTBENCH PASSED: no errors");
        else
            $display("TESTBENCH FAILED: %0d error(s)", errors);
        $display("==================================================");

        $finish;
    end

endmodule