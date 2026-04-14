`timescale 1ps/1ps

module tb_dcdl_delay;

    parameter int N = 64;

    logic clk;
    logic rst_n;
    logic shift_left;
    logic shift_right;
    logic A;
    logic Y;

    time t_in;
    time delay_ps;

    int stage;
    int fd;

    // -------------------------
    // DUT
    // -------------------------
    nand_dcdl_top #(
        .N(N)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .shift_left(shift_left),
        .shift_right(shift_right),
        .A(A),
        .Y(Y)
    );

    // -------------------------
    // Clock
    // -------------------------
    initial clk = 1'b0;
    always #5000 clk = ~clk;   // 10ns period

    // -------------------------
    // Shift helper
    // -------------------------
    task automatic do_shift_left;
    begin
        @(negedge clk);
        shift_left  = 1'b1;
        shift_right = 1'b0;

        @(posedge clk);
        @(negedge clk);

        shift_left = 1'b0;
    end
    endtask

    // -------------------------
    // Measure one stage
    // -------------------------
    task automatic measure_stage(input int idx);
    begin
        stage = idx;

        // force clean start
        A = 1'b0;
        #1000;

        // launch edge
        t_in = $time;
        A = 1'b1;

        // wait for propagated output edge
        @(posedge Y);

        delay_ps = $time - t_in;

        $display("Stage=%0d | Q=%b | Delay=%0t ps",
                 stage, dut.Q, delay_ps);

        $fdisplay(fd, "%0d,%0t", stage, delay_ps);

        // reset input for next measurement
        #1000;
        A = 1'b0;

        // allow settle time
        #15000;
    end
    endtask

    // -------------------------
    // Main stimulus
    // -------------------------
    initial begin
        fd = $fopen("dcdl_delay.csv", "w");
        $fdisplay(fd, "stage,delay_ps");

        $display("===== DCDL CHARACTERIZATION TEST =====");

        rst_n       = 1'b0;
        shift_left  = 1'b0;
        shift_right = 1'b0;
        A           = 1'b0;
        stage       = 0;

        // Reset
        #2000;
        rst_n = 1'b1;
        @(posedge clk);
        @(negedge clk);

        // Sweep all stages
        for (int i = 0; i < N; i++) begin
            measure_stage(i);

            if (i != N-1)
                do_shift_left();
        end

        $display("-----------------------------------");
        $display("Characterization complete.");
        $display("CSV file: dcdl_delay.csv");
        $display("-----------------------------------");

        $fclose(fd);

        #5000;
        $finish;
    end

endmodule