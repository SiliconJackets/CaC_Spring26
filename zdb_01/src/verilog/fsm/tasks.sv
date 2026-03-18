//File containing simple verification tasks
//The tasknames in this example are unimaginative and undescriptive.
//Please use meaningful task names in your work :)

task initialize_signals();
    begin
        rst_i=1'b1;
        clk_i=1'b0;
        go_i=1'b0;
        wb_i=1'b0;
    end
endtask

task toggle_go_i();
    begin
        @(posedge clk_i);
        rst_i=1'b0;
        repeat (5) begin
            @(posedge clk_i);
            go_i=~go_i;
        end
    end
endtask

task toggle_wb_i();
    begin
        @(posedge clk_i);
        rst_i=1'b0;
        repeat (5) begin
            @(posedge clk_i);
            wb_i=~wb_i;
        end
    end
endtask

// -------------------------------------------------------
// check_outputs: self-checking task for rd_o / ds_o.
// Outputs are registered so check #1 after posedge.
// -------------------------------------------------------
task automatic check_outputs(
    input logic exp_rd,
    input logic exp_ds,
    input string label
);
    begin
        #1;
        if (rd_o !== exp_rd || ds_o !== exp_ds) begin
            $display("[%0t] ERROR: %s | expected rd=%b ds=%b, got rd=%b ds=%b",
                     $time, label, exp_rd, exp_ds, rd_o, ds_o);
            errors = errors + 1;
        end else begin
            $display("[%0t] PASS : %s | rd=%b ds=%b", $time, label, rd_o, ds_o);
        end
    end
endtask

// -------------------------------------------------------
// test_full_state_sequence:
//   Exercises RESET -> READ -> WAIT(x3) -> DONE -> RESET
//   with wait_cycle=3 (the default parameter).
//   Checks rd_o and ds_o at each stage.
// -------------------------------------------------------
task test_full_state_sequence();
    begin
        $display("\n=== test_full_state_sequence ===");

        // Apply reset
        rst_i = 1'b1;
        go_i  = 1'b0;
        wb_i  = 1'b0;
        @(posedge clk_i); check_outputs(1'b0, 1'b0, "RESET: rst asserted");

        // Release reset — still no go_i, should stay in RESET
        @(posedge clk_i);
        rst_i = 1'b0;
        @(posedge clk_i); check_outputs(1'b0, 1'b0, "RESET: rst released, no go");

        // Assert go_i for one cycle to move from RESET -> READ
        go_i = 1'b1;
        @(posedge clk_i); check_outputs(1'b1, 1'b0, "READ: rd_o=1 after go_i");
        go_i = 1'b0;

        // READ -> WAIT: rd_o stays 1
        @(posedge clk_i); check_outputs(1'b1, 1'b0, "WAIT cycle 1: rd_o=1");

        // WAIT: two more cycles (wait_cycle=3 means 3 total WAIT evaluations)
        @(posedge clk_i); check_outputs(1'b1, 1'b0, "WAIT cycle 2: rd_o=1");
        @(posedge clk_i); check_outputs(1'b1, 1'b0, "WAIT cycle 3: rd_o=1");

        // WAIT -> DONE on this clock: ds_o=1, rd_o=0
        @(posedge clk_i); check_outputs(1'b0, 1'b1, "DONE: ds_o=1, rd_o=0");

        // DONE -> RESET: both 0
        @(posedge clk_i); check_outputs(1'b0, 1'b0, "RESET: back to idle");
    end
endtask

// -------------------------------------------------------
// test_wait_bypass:
//   Exercises wb_i shortcut: WAIT -> DONE in 1 cycle
//   instead of the full wait_cycle count.
// -------------------------------------------------------
task test_wait_bypass();
    begin
        $display("\n=== test_wait_bypass ===");

        // Reset
        rst_i = 1'b1;
        go_i  = 1'b0;
        wb_i  = 1'b0;
        @(posedge clk_i);
        rst_i = 1'b0;

        // RESET -> READ via go_i
        go_i = 1'b1;
        @(posedge clk_i); check_outputs(1'b1, 1'b0, "WB: READ rd_o=1");
        go_i = 1'b0;

        // READ -> WAIT
        @(posedge clk_i); check_outputs(1'b1, 1'b0, "WB: entered WAIT rd_o=1");

        // Assert wb_i in WAIT — should jump to DONE immediately
        wb_i = 1'b1;
        @(posedge clk_i); check_outputs(1'b0, 1'b1, "WB: wb_i bypasses WAIT -> DONE ds_o=1");
        wb_i = 1'b0;

        // DONE -> RESET
        @(posedge clk_i); check_outputs(1'b0, 1'b0, "WB: back to RESET");
    end
endtask

// -------------------------------------------------------
// test_reset_during_wait:
//   Asserts rst_i while in WAIT state — should immediately
//   clear outputs and return to RESET.
// -------------------------------------------------------
task test_reset_during_wait();
    begin
        $display("\n=== test_reset_during_wait ===");

        // Start from reset
        rst_i = 1'b1;
        go_i  = 1'b0;
        wb_i  = 1'b0;
        @(posedge clk_i);
        rst_i = 1'b0;

        // Move to WAIT
        go_i = 1'b1;
        @(posedge clk_i);   // READ
        go_i = 1'b0;
        @(posedge clk_i);   // WAIT cycle 1

        // Now assert asynchronous reset while in WAIT
        rst_i = 1'b1;
        check_outputs(1'b0, 1'b0, "RESET during WAIT: outputs clear immediately");

        // Hold reset for a cycle then release
        @(posedge clk_i);
        check_outputs(1'b0, 1'b0, "still in RESET: outputs 0");
        rst_i = 1'b0;

        // After release, should be back in RESET with no go_i
        @(posedge clk_i); check_outputs(1'b0, 1'b0, "post-reset-release: idle");
    end
endtask

// -------------------------------------------------------
// test_no_go_stays_reset:
//   Without go_i, the FSM must not leave RESET state.
// -------------------------------------------------------
task test_no_go_stays_reset();
    begin
        $display("\n=== test_no_go_stays_reset ===");
        rst_i = 1'b1;
        go_i  = 1'b0;
        wb_i  = 1'b0;
        @(posedge clk_i);
        rst_i = 1'b0;
        begin : no_go_loop
            int k;
            for (k = 0; k < 8; k++) begin
                @(posedge clk_i); check_outputs(1'b0, 1'b0, "no-go: still RESET");
            end
        end
    end
endtask

// -------------------------------------------------------
// test_multiple_full_cycles:
//   Runs 3 complete RESET->READ->WAIT->DONE->RESET loops
//   back-to-back to verify there are no sticky state issues.
// -------------------------------------------------------
task test_multiple_full_cycles();
    begin
        $display("\n=== test_multiple_full_cycles ===");
        rst_i = 1'b1;
        go_i  = 1'b0;
        wb_i  = 1'b0;
        @(posedge clk_i);
        rst_i = 1'b0;

        begin : multi_cycle_loop
            int cycle;
            for (cycle = 0; cycle < 3; cycle++) begin
                $display("  -- Full cycle %0d --", cycle);

                go_i = 1'b1;
                @(posedge clk_i); check_outputs(1'b1, 1'b0,
                    $sformatf("cycle%0d READ", cycle));
                go_i = 1'b0;

                @(posedge clk_i); check_outputs(1'b1, 1'b0,
                    $sformatf("cycle%0d WAIT-1", cycle));
                @(posedge clk_i); check_outputs(1'b1, 1'b0,
                    $sformatf("cycle%0d WAIT-2", cycle));
                @(posedge clk_i); check_outputs(1'b1, 1'b0,
                    $sformatf("cycle%0d WAIT-3", cycle));
                @(posedge clk_i); check_outputs(1'b0, 1'b1,
                    $sformatf("cycle%0d DONE", cycle));
                @(posedge clk_i); check_outputs(1'b0, 1'b0,
                    $sformatf("cycle%0d RESET", cycle));
            end
        end
    end
endtask
