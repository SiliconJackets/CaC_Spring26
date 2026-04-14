`timescale 1ps/1ps

module tb_dcdl_delay;

    parameter int N = 64;

    logic clk;
    logic rst_n;
    logic shift_left;
    logic shift_right;
    logic A;
    logic Y;

    time t_in, t_out;

    int stage;

    // DUT
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
    always #5000 clk = ~clk;

    // -------------------------
    // Timestamp capture
    // -------------------------
    always @(posedge A or negedge A)
        t_in = $time;

    always @(posedge Y or negedge Y) begin
        t_out = $time;
        $display("Stage=%0d | Q=%b | Delay = %0t ps",
                 stage, dut.Q, t_out - t_in);
    end

    // -------------------------
    // Shift helpers
    // -------------------------
    task do_shift_left;
        begin
            @(negedge clk);
            shift_left  = 1'b1;
            shift_right = 1'b0;

            @(posedge clk);
            @(negedge clk);

            shift_left  = 1'b0;
        end
    endtask

    // -------------------------
    // Stimulus
    // -------------------------
    initial begin
        $display("===== DCDL DELAY TEST (N=%0d) =====", N);

        rst_n       = 1'b0;
        shift_left  = 1'b0;
        shift_right = 1'b0;
        A           = 1'b0;
        stage       = 0;

        // Reset
        #2000;
        rst_n = 1'b1;
        @(posedge clk);

        // -------------------------
        // Sweep ALL stages
        // -------------------------
        $display("\n--- Measuring delay per stage ---");

        for (int i = 0; i < N; i++) begin
            stage = i;

            #1000;
            A = 1'b1;
            #2000;
            A = 1'b0;

            do_shift_left;
        end

        // -------------------------
        // Stability check
        // -------------------------
        $display("\n--- Second sweep (stability check) ---");

        repeat (8) begin
            #1000;
            A = ~A;
            #2000;
            A = ~A;

            do_shift_left;
        end

        #5000;
        $finish;
    end

endmodule