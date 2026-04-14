`timescale 1ps/1ps

/*
|=======================================================================
| Module      : controller
| Author      : Mythri Muralikannan
| Description : Saturating up/down DLL controller
|
| Function:
|   Updates the delay-control word based on the phase detector outputs.
|
| Inputs:
|   clk_in : Reference/control clock
|   rst    : Asynchronous active-high reset
|   up     : Increment control request
|   down   : Decrement control request
|
| Output:
|   ctrl   : Delay control word
|
| Operation:
|   - On reset, ctrl is initialized to INIT_CTRL, clamped to the valid
|     range [0, 2^CTRL_BITS - 1]
|   - up=1, down=0   -> increment ctrl by 1, saturating at MAX_CTRL
|   - up=0, down=1   -> decrement ctrl by 1, saturating at 0
|   - up=down        -> hold current ctrl value
|
| Notes:
|   - Fully synthesizable
|   - Baseline digital controller for DLL / ZDB applications
|=======================================================================
*/

module controller #(
    parameter integer CTRL_BITS = 7,
    parameter integer INIT_CTRL = 1
)(
    input  wire                 clk_in,
    input  wire                 rst,
    input  wire                 up,
    input  wire                 down,
    output reg  [CTRL_BITS-1:0] ctrl
);

    localparam integer MAX_CTRL = (1 << CTRL_BITS) - 1;
    localparam [CTRL_BITS-1:0] MAX_CTRL_VEC = MAX_CTRL[CTRL_BITS-1:0];
    localparam [CTRL_BITS-1:0] ZERO_CTRL    = {CTRL_BITS{1'b0}};

    always @(posedge clk_in or posedge rst) begin
        if (rst) begin
            if (INIT_CTRL < 0)
                ctrl <= ZERO_CTRL;
            else if (INIT_CTRL > MAX_CTRL)
                ctrl <= MAX_CTRL_VEC;
            else
                ctrl <= INIT_CTRL[CTRL_BITS-1:0];
        end
        else begin
            case ({up, down})
                2'b10: begin
                    if (ctrl < MAX_CTRL_VEC)
                        ctrl <= ctrl + 1'b1;
                end

                2'b01: begin
                    if (ctrl > ZERO_CTRL)
                        ctrl <= ctrl - 1'b1;
                end

                default: begin
                    ctrl <= ctrl;
                end
            endcase
        end
    end

endmodule