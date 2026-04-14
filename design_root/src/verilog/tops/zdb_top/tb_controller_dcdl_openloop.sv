`timescale 1ps/1ps

module tb_controller_dcdl_openloop;

    parameter int CTRL_BITS    = 7;
    parameter int INIT_CTRL    = 0;
    parameter int N            = 128;
    parameter time HALF_PERIOD = 5000; // 10 ns clock

    logic clk_in;
    logic rst;

    logic up;
    logic down;

    logic [CTRL_BITS-1:0] ctrl;
    logic [CTRL_BITS-1:0] ctrl_d;

    logic shift_left;
    logic shift_right;

    logic A;
    logic Y;

    time t_in;
    time delay_ps;

    // -------------------------
    // Clock
    // -------------------------
    initial clk_in = 1'b0;
    always #(HALF_PERIOD) clk_in = ~clk_in;

    // -------------------------
    // Controller
    // -------------------------
    controller #(
        .CTRL_BITS(CTRL_BITS),
        .INIT_CTRL(INIT_CTRL)
    ) u_controller (
        .clk_in (clk_in),
        .rst    (rst),
        .up     (up),
        .down   (down),
        .ctrl   (ctrl)
    );

    // -------------------------
    // ctrl -> shift pulse adapter
    // -------------------------
    always_ff @(posedge clk_in or posedge rst) begin
        if (rst)
            ctrl_d <= INIT_CTRL[CTRL_BITS-1:0];
        else
            ctrl_d <= ctrl;
    end

    assign shift_left  = (ctrl > ctrl_d);
    assign shift_right = (ctrl < ctrl_d);

    // -------------------------
    // DCDL
    // -------------------------
    nand_dcdl_top #(
        .N(N)
    ) u_dcdl (
        .clk         (clk_in),
        .rst_n       (~rst),
        .shift_left  (shift_left),
        .shift_right (shift_right),
        .A           (A),
        .Y           (Y)
    );

    // -------------------------
    // Helpers
    // -------------------------
    task automatic settle_after_control;
    begin
        @(posedge clk_in);
        @(negedge clk_in);
    end
    endtask

    task automatic pulse_up_once;
    begin
        @(negedge clk_in);
        up   = 1'b1;
        down = 1'b0;
        @(posedge clk_in);
        @(negedge clk_in);
        up = 1'b0;
        settle_after_control();
    end
    endtask

    task automatic pulse_down_once;
    begin
        @(negedge clk_in);
        up   = 1'b0;
        down = 1'b1;
        @(posedge clk_in);
        @(negedge clk_in);
        down = 1'b0;
        settle_after_control();
    end
    endtask

    task automatic measure_delay(input string tag);
    begin
        A = 1'b0;
        #(4*HALF_PERIOD);

        t_in = $time;
        A = 1'b1;

        @(posedge Y);
        delay_ps = $time - t_in;

        $display("%s | t=%0t | ctrl=%0d | SL=%b SR=%b | Q=%b | delay=%0t ps",
                 tag, $time, ctrl, shift_left, shift_right, u_dcdl.Q, delay_ps);

        A = 1'b0;
        #(4*HALF_PERIOD);
    end
    endtask

    task automatic move_to_midrange;
    begin
        // Start from max tap after reset, walk downward to a useful middle region
        repeat (20) pulse_down_once();
    end
    endtask

    task automatic move_back_to_max;
    begin
        repeat (20) pulse_up_once();
    end
    endtask

    // -------------------------
    // Main stimulus
    // -------------------------
    initial begin
        rst  = 1'b1;
        up   = 1'b0;
        down = 1'b0;
        A    = 1'b0;

        #20000;
        rst = 1'b0;

        @(posedge clk_in);
        @(negedge clk_in);
        settle_after_control();

        $display("\n==============================");
        $display(" INITIAL");
        $display("==============================");
        measure_delay("INIT");

        // ---------------------------------
        // Move into middle region
        // ---------------------------------
        $display("\n==============================");
        $display(" MOVE TO MIDRANGE");
        $display("==============================");
        move_to_midrange();
        measure_delay("MID START");

        // ---------------------------------
        // Regular UP test in middle region
        // ---------------------------------
        $display("\n==============================");
        $display(" MIDRANGE 6x UP");
        $display("==============================");
        repeat (6) begin
            pulse_up_once();
            measure_delay("MID UP");
        end

        // ---------------------------------
        // Regular DOWN test in middle region
        // ---------------------------------
        $display("\n==============================");
        $display(" MIDRANGE 6x DOWN");
        $display("==============================");
        repeat (6) begin
            pulse_down_once();
            measure_delay("MID DOWN");
        end

        // ---------------------------------
        // Alternating in middle region
        // ---------------------------------
        $display("\n==============================");
        $display(" MIDRANGE ALTERNATING");
        $display("==============================");
        repeat (6) begin
            pulse_up_once();
            measure_delay("ALT UP");

            pulse_down_once();
            measure_delay("ALT DOWN");
        end

        // ---------------------------------
        // Return near max and prove saturation
        // ---------------------------------
        $display("\n==============================");
        $display(" BACK TO MAX");
        $display("==============================");
        move_back_to_max();
        measure_delay("MAX AGAIN");

        $display("\n==============================");
        $display(" 4x UP AT MAX");
        $display("==============================");
        repeat (4) begin
            pulse_up_once();
            measure_delay("SAT UP");
        end

        #10000;
        $finish;
    end

endmodule