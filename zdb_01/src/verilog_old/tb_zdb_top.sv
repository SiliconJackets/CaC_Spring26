`timescale 1ps/1ps

// Feedback path: clk_in -> DCDL -> dcdl_clk --(#TREE_DELAY_PS)--> clk_fb -> PD
// Clock source (pick one at compile time):
//   +define+USE_RO   -> ring_oscillator drives clk_in  (sel via RO_SEL parameter)
//   (default)        -> behavioral always-block at CLK_HALF_PS

module tb_zdb_top;
    // Parameters
    parameter integer CTRL_BITS     = 6;
    parameter integer DELAY_STEP    = 20;   // ps per DCDL step
    parameter integer MIN_DELAY     = 0;    // ps
    parameter integer INIT_CTRL     = 20;
    parameter integer TREE_DELAY_PS = 200;  // ps — simulated clock tree / feedback path delay
    parameter real    CLK_HALF_PS   = 500.0; // ps — used in behavioral clock mode only
    parameter logic [1:0] RO_SEL    = 2'b11; // ring oscillator tap — used in USE_RO mode only

    parameter integer RUN_CYCLES = 400;     // how many clk_in cycles to observe

    // Signals
    logic clk_in;
    logic rst;
    wire  dcdl_clk;   // DCDL output
    wire  clk_fb;     // delayed feedback to PD
    wire  up, down;
    wire  [CTRL_BITS-1:0] ctrl;

    // Clock source
`ifdef USE_RO
    // Ring oscillator drives clk_in
    ring_oscillator ro (
        .sel    (RO_SEL),
        .clk_out(clk_in)
    );
`else
    // Behavioral clock
    initial clk_in = 1'b0;
    always #(CLK_HALF_PS) clk_in = ~clk_in;
`endif

    // Feedback path: add clock-tree delay before returning to PD
    assign #(TREE_DELAY_PS) clk_fb = dcdl_clk;

    // Sub-module instances
    bangbang_pd pd (
        .clk_in (clk_in),
        .clk_out(clk_fb),
        .rst    (rst),
        .up     (up),
        .down   (down)
    );

    dll_controller #(
        .CTRL_BITS(CTRL_BITS),
        .INIT_CTRL(INIT_CTRL)
    ) ctrl_1 (
        .clk_in(clk_in),
        .rst   (rst),
        .up    (up),
        .down  (down),
        .ctrl  (ctrl)
    );

    dcdl_behavioral #(
        .CTRL_BITS (CTRL_BITS),
        .DELAY_STEP(DELAY_STEP),
        .MIN_DELAY (MIN_DELAY)
    ) dcdl (
        .clk_in (clk_in),
        .ctrl   (ctrl),
        .clk_out(dcdl_clk)
    );

    // Logger: print ctrl / up / down every rising edge after reset
    always @(posedge clk_in) begin
        if (!rst)
            $display("%0t ps | ctrl=%0d (delay=%0d ps) | up=%b down=%b",
                     $time, ctrl, MIN_DELAY + ctrl * DELAY_STEP, up, down);
    end

    // Stimuli
    initial begin
        $fsdbDumpfile("zdb_top.fsdb");
        $fsdbDumpon;
        $fsdbDumpvars(0, tb_zdb_top);

        rst = 1'b1;
        repeat (8) @(posedge clk_in);
        @(negedge clk_in);
        rst = 1'b0;

        repeat (RUN_CYCLES) @(posedge clk_in);
        $finish;
    end

endmodule
