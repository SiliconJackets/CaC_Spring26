`timescale 1ps/1ps



/* |======================================================================= */
/* | */                                                                          
/* | Author             : Mythri Muralikannan */                                                   
/* | Description        : Bang-Bang Phase detector BEHAVIORAL testbench*/                                       
/* | This detector does not measure the exact phase error but just outputs a 1-bit decision */                                                                     
/* | UP = 1 --> the reference clock is ahead and there must be a speed up*/                                                                      
/* | DOWN = 1 --> the feedback clock is ahead and there must be a slow down*/                                                                      
/* |  This is a behavioral testbench for a behavioral DUT, the current design style. 
/* |  Since the DUT uses $time, the testbench also uses scheduled delays in ps.
/* |======================================================================= */


module tb_bangbang_pd;

    reg  clk_in;
    reg  clk_out;
    reg  rst;
    wire up;
    wire down;

    // DUT
    bangbang_pd dut (
        .clk_in  (clk_in),
        .clk_out (clk_out),
        .rst     (rst),
        .up      (up),
        .down    (down)
    );

    integer errors;

    // ----------------------------------------
    // Self-check task
    // ----------------------------------------
    task check_outputs;
        input expected_up;
        input expected_down;
        input [8*80-1:0] test_name;
        begin
            #1; // allow combinational logic to settle
            if ((up !== expected_up) || (down !== expected_down)) begin
                $display("[%0t ps] ERROR: %0s | expected up=%0b down=%0b, got up=%0b down=%0b",
                         $time, test_name, expected_up, expected_down, up, down);
                errors = errors + 1;
            end else begin
                $display("[%0t ps] PASS : %0s | up=%0b down=%0b",
                         $time, test_name, up, down);
            end
        end
    endtask

    // ----------------------------------------
    // Stimulus
    // ----------------------------------------
    initial begin
        errors  = 0;
        clk_in  = 0;
        clk_out = 0;
        rst     = 1;

        $display("==========================================");
        $display("Starting self-checking testbench");
        $display("==========================================");

        // Reset check
        #5;
        check_outputs(1'b0, 1'b0, "reset active");

        // Release reset
        #5;
        rst = 0;
        #1;
        check_outputs(1'b0, 1'b0, "after reset release, no edges yet");

        // ------------------------------------
        // Test 1: clk_in edge happens last -> up=1
        // ------------------------------------
        #10 clk_out = 1;
        #1  check_outputs(1'b0, 1'b1, "clk_out edge more recent => down=1");
        #5  clk_out = 0;

        #10 clk_in = 1;
        #1  check_outputs(1'b1, 1'b0, "clk_in edge more recent => up=1");
        #5  clk_in = 0;

        // ------------------------------------
        // Test 2: clk_out edge happens last -> down=1
        // ------------------------------------
        #10 clk_in = 1;
        #1  check_outputs(1'b1, 1'b0, "clk_in edge more recent => up=1");
        #5  clk_in = 0;

        #10 clk_out = 1;
        #1  check_outputs(1'b0, 1'b1, "clk_out edge more recent => down=1");
        #5  clk_out = 0;

        // ------------------------------------
        // Test 3: multiple clk_in edges in a row
        // ------------------------------------
        #10 clk_in = 1;
        #1  check_outputs(1'b1, 1'b0, "clk_in still most recent");
        #5  clk_in = 0;

        #10 clk_in = 1;
        #1  check_outputs(1'b1, 1'b0, "clk_in updated again, still up=1");
        #5  clk_in = 0;

        // ------------------------------------
        // Test 4: multiple clk_out edges in a row
        // ------------------------------------
        #10 clk_out = 1;
        #1  check_outputs(1'b0, 1'b1, "clk_out updated, down=1");
        #5  clk_out = 0;

        #10 clk_out = 1;
        #1  check_outputs(1'b0, 1'b1, "clk_out updated again, still down=1");
        #5  clk_out = 0;

        // ------------------------------------
        // Test 5: reset in middle of operation
        // ------------------------------------
        #10 rst = 1;
        #1  check_outputs(1'b0, 1'b0, "mid-run reset clears outputs");

        #5 rst = 0;
        #1 check_outputs(1'b0, 1'b0, "after mid-run reset release");

        // ------------------------------------
        // Test 6: same-time edges after reset
        // If both timestamps are equal, expect up=0/down=0
        // ------------------------------------
        fork
            begin
                #10 clk_in = 1;
            end
            begin
                #10 clk_out = 1;
            end
        join

        #1 check_outputs(1'b0, 1'b0, "simultaneous edges => equal timestamps");

        #5 clk_in  = 0;
        #5 clk_out = 0;

        // ------------------------------------
        // Final report
        // ------------------------------------
        $display("==========================================");
        if (errors == 0) begin
            $display("TESTBENCH PASSED: no errors");
        end else begin
            $display("TESTBENCH FAILED: %0d error(s)", errors);
        end
        $display("==========================================");

        $finish;
    end

endmodule