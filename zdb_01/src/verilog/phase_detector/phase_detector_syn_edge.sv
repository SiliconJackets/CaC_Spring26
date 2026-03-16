`timescale 1ps/1ps

/*
|=======================================================================
| Module      : edge_order_phase_detector
| Author      : Mythri Muralikannan
| Description : Edge-order bang-bang phase detector
|
| Function:
|   Determines which clock edge arrives first by detecting rising
|   edges of the reference clock (clk_in) and feedback clock (clk_out).
|
| Output meaning:
|   up   = 1 -> reference clock leads feedback clock -> speed up loop
|   down = 1 -> feedback clock leads reference clock -> slow down loop
|
| Operation:
|   - Rising edges of both clocks are detected using delayed versions
|     of the signals.
|   - If a reference edge occurs before a feedback edge -> up = 1
|   - If a feedback edge occurs before a reference edge -> down = 1
|
| Notes:
|   - Fully synthesizable
|   - Detects edge arrival order (binary phase detection)
|=======================================================================
*/

module phase_detector (
    input  wire clk_in,    // Reference clock
    input  wire clk_out,   // Feedback clock
    input  wire rst,       // Asynchronous active-high reset
    output reg  up,        // Request to speed up
    output reg  down       // Request to slow down
);

    reg clk_in_d;
    reg clk_out_d;

    // Rising edge detection
    wire rise_in;
    wire rise_out;

    assign rise_in  = clk_in  & ~clk_in_d;
    assign rise_out = clk_out & ~clk_out_d;

    // Phase decision logic
    always @(posedge clk_in or posedge clk_out or posedge rst) begin
        if (rst) begin
            up   <= 1'b0;
            down <= 1'b0;
        end
        else begin
            if (rise_in && !rise_out) begin
                // Reference edge arrived first
                up   <= 1'b1;
                down <= 1'b0;
            end
            else if (rise_out && !rise_in) begin
                // Feedback edge arrived first
                up   <= 1'b0;
                down <= 1'b1;
            end
        end
    end

    // Store previous clock values for edge detection
    always @(posedge clk_in)
        clk_in_d <= clk_in;

    always @(posedge clk_out)
        clk_out_d <= clk_out;

endmodule