//**************************************************************************
// Author: Alfi Misha Antony Selvin Raj
// Description: Sanity check shift register (NOT INCLUDED IN TOP)
//**************************************************************************
//not in the include this is for debug
`timescale 1ns/1ps
module tb_dll_shift_register;
logic clk;
logic rst_n;
logic shift_left;
logic shift_right;
logic [3:0] Q;

int errors;

dll_shift_register dut (
    .clk(clk),
    .rst_n(rst_n),
    .shift_left(shift_left),
    .shift_right(shift_right),
    .Q(Q)
);

initial clk = 0;
always #5 clk = ~clk;

// -------------------------------------------------------
// Self-check task: check Q matches expected value
// Call after posedge clk + small settling time
// -------------------------------------------------------
task automatic check_Q(input logic [3:0] expected, input string label);
    begin
        #1;
        if (Q !== expected) begin
            $display("[%0t] ERROR: %s | expected Q=%04b, got Q=%04b",
                     $time, label, expected, Q);
            errors++;
        end else begin
            $display("[%0t] PASS : %s | Q=%04b", $time, label, Q);
        end
    end
endtask

// Verify Q is one-hot (exactly one bit set)
task automatic check_onehot(input string label);
    begin
        if (Q !== 4'b0001 && Q !== 4'b0010 &&
            Q !== 4'b0100 && Q !== 4'b1000) begin
            $display("[%0t] ERROR: one-hot violation @ %s | Q=%04b", $time, label, Q);
            errors++;
        end
    end
endtask

// Apply shift_left for one clock cycle
task automatic do_shift_left;
    begin
        @(negedge clk);      // change inputs between posedges
        shift_left  = 1'b1;
        shift_right = 1'b0;
        @(posedge clk);
        @(negedge clk);
        shift_left  = 1'b0;
    end
endtask

// Apply shift_right for one clock cycle
task automatic do_shift_right;
    begin
        @(negedge clk);
        shift_right = 1'b1;
        shift_left  = 1'b0;
        @(posedge clk);
        @(negedge clk);
        shift_right = 1'b0;
    end
endtask

initial begin
    $display("====== dll_shift_register testbench ======");
    errors      = 0;
    shift_left  = 0;
    shift_right = 0;
    rst_n       = 0;

    // --------------------------------------------------
    // TEST 1: Reset initializes Q to 4'b0001
    // --------------------------------------------------
    $display("\n=== TEST 1: Reset initializes Q ===");
    #20;
    @(posedge clk); #1;
    if (Q !== 4'b0001) begin
        $display("[%0t] ERROR: reset Q=%04b, expected 4'b0001", $time, Q);
        errors++;
    end else
        $display("[%0t] PASS : reset Q=%04b (correct)", $time, Q);
    check_onehot("after reset");

    rst_n = 1;

    // --------------------------------------------------
    // TEST 2: Full left rotation — 4 shifts returns to start
    //   0001 -> 0010 -> 0100 -> 1000 -> 0001
    // --------------------------------------------------
    $display("\n=== TEST 2: Full left rotation ===");
    do_shift_left;
    check_Q(4'b0010, "left1: 0001->0010"); check_onehot("after left1");
    do_shift_left;
    check_Q(4'b0100, "left2: 0010->0100"); check_onehot("after left2");
    do_shift_left;
    check_Q(4'b1000, "left3: 0100->1000"); check_onehot("after left3");
    do_shift_left;
    check_Q(4'b0001, "left4: 1000->0001 (wrap)"); check_onehot("after left4");

    // --------------------------------------------------
    // TEST 3: Full right rotation — 4 shifts returns to start
    //   0001 -> 1000 -> 0100 -> 0010 -> 0001
    // --------------------------------------------------
    $display("\n=== TEST 3: Full right rotation ===");
    do_shift_right;
    check_Q(4'b1000, "right1: 0001->1000"); check_onehot("after right1");
    do_shift_right;
    check_Q(4'b0100, "right2: 1000->0100"); check_onehot("after right2");
    do_shift_right;
    check_Q(4'b0010, "right3: 0100->0010"); check_onehot("after right3");
    do_shift_right;
    check_Q(4'b0001, "right4: 0010->0001 (wrap)"); check_onehot("after right4");

    // --------------------------------------------------
    // TEST 4: No-op (neither shift asserted) does not change Q
    // --------------------------------------------------
    $display("\n=== TEST 4: No-op preserves Q ===");
    // Q should be 4'b0001
    @(posedge clk); #1;
    check_Q(4'b0001, "no-op cycle 1");
    @(posedge clk); #1;
    check_Q(4'b0001, "no-op cycle 2");
    @(posedge clk); #1;
    check_Q(4'b0001, "no-op cycle 3");

    // --------------------------------------------------
    // TEST 5: Reset mid-operation restores Q=4'b0001
    // --------------------------------------------------
    $display("\n=== TEST 5: Reset mid-operation ===");
    do_shift_left;  // 0001->0010
    do_shift_left;  // 0010->0100
    @(posedge clk); #1;
    $display("[%0t] INFO: Q before mid-reset = %04b", $time, Q);
    rst_n = 0;
    @(posedge clk); #1;
    check_Q(4'b0001, "mid-reset restores Q");
    rst_n = 1;

    // --------------------------------------------------
    // TEST 6: Simultaneous shift_left and shift_right — shift_left wins
    //   (shift_left is checked first in the always_ff)
    // --------------------------------------------------
    $display("\n=== TEST 6: Simultaneous shifts (left wins) ===");
    // Q is 0001 after reset
    @(negedge clk);
    shift_left  = 1'b1;
    shift_right = 1'b1;
    @(posedge clk);
    @(negedge clk);
    shift_left  = 1'b0;
    shift_right = 1'b0;
    check_Q(4'b0010, "simultaneous: left wins, 0001->0010");
    check_onehot("after simultaneous");

    // --------------------------------------------------
    // TEST 7: Interleaved left-right sequence
    //   L R L R sequence from a known state
    // --------------------------------------------------
    $display("\n=== TEST 7: Interleaved L/R sequence ===");
    // Reset to known state
    @(negedge clk); rst_n = 0; @(posedge clk); #1; rst_n = 1;
    // Q=0001: L->0010, R->0001, L->0010, R->0001
    do_shift_left;
    check_Q(4'b0010, "interleave L1: 0001->0010");
    do_shift_right;
    check_Q(4'b0001, "interleave R1: 0010->0001");
    do_shift_left;
    check_Q(4'b0010, "interleave L2: 0001->0010");
    do_shift_right;
    check_Q(4'b0001, "interleave R2: 0010->0001");

    // --------------------------------------------------
    // TEST 8: Back-to-back active-low reset pulses
    // --------------------------------------------------
    $display("\n=== TEST 8: Repeated resets always restore Q=0001 ===");
    begin : test8_block
        int k;
        for (k = 0; k < 3; k++) begin
            do_shift_left;  // move away from reset value
            @(negedge clk); rst_n = 0; @(posedge clk); #1; rst_n = 1;
            check_Q(4'b0001, $sformatf("repeated reset %0d restores Q", k));
        end
    end

    // --------------------------------------------------
    // TEST 9: Full left rotation starting from each position
    // --------------------------------------------------
    $display("\n=== TEST 9: Full left rotation from each starting position ===");
    begin : test9_block
        logic [3:0] expected_seq [0:3];
        int p;
        // Starting from 0001, do 8 left shifts (2 full rotations)
        @(negedge clk); rst_n = 0; @(posedge clk); #1; rst_n = 1;
        expected_seq[0] = 4'b0010;
        expected_seq[1] = 4'b0100;
        expected_seq[2] = 4'b1000;
        expected_seq[3] = 4'b0001;
        for (p = 0; p < 8; p++) begin
            do_shift_left;
            check_Q(expected_seq[p % 4],
                    $sformatf("full left rotation, step %0d", p+1));
            check_onehot($sformatf("one-hot check step %0d", p+1));
        end
    end

    // --------------------------------------------------
    // Summary
    // --------------------------------------------------
    #20;
    $display("\n============================");
    if (errors == 0)
        $display("TESTBENCH PASSED: 0 errors");
    else
        $display("TESTBENCH FAILED: %0d error(s)", errors);
    $display("============================");
    $finish;
end

endmodule
