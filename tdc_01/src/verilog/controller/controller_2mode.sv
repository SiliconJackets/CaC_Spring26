/*
|=======================================================================
| Module      : dll_controller_coarse_fine
| Author      : Mythri Muralikannan
| Description : Coarse/fine DLL controller
|
| Function:
|   Splits the delay-control word into coarse and fine fields to allow
|   fast initial tuning and precise final adjustment.
|
| Operation:
|   - On reset, ctrl is initialized to INIT_CTRL
|   - During coarse mode, the coarse field is updated to move quickly
|     toward lock
|   - After sufficient quiet cycles, the controller switches to fine
|     mode
|   - During fine mode, only the fine field is adjusted for precise
|     edge alignment
|
| Notes:
|   - Fully synthesizable
|   - Common practical architecture for digitally controlled delay lines
|   - Provides fast acquisition and high final resolution
|=======================================================================
*/

`timescale 1ps/1ps

module controller #(
    parameter integer CTRL_BITS     = 6,
    parameter integer INIT_CTRL     = 32,
    parameter integer COARSE_BITS   = 3,
    parameter integer FINE_BITS     = 3,
    parameter integer SWITCH_QUIET  = 8
)(
    input  wire                 clk_in,
    input  wire                 rst,
    input  wire                 up,
    input  wire                 down,
    output wire [CTRL_BITS-1:0] ctrl
);

    localparam integer MAX_COARSE = (1 << COARSE_BITS) - 1;
    localparam integer MAX_FINE   = (1 << FINE_BITS) - 1;

    reg [COARSE_BITS-1:0] coarse;
    reg [FINE_BITS-1:0]   fine;

    reg mode; // 0 = coarse acquire, 1 = fine track
    reg [$clog2(SWITCH_QUIET + 1)-1:0] quiet_count;

    assign ctrl = {coarse, fine};

    always @(posedge clk_in or posedge rst) begin
        if (rst) begin
            coarse <= INIT_CTRL[CTRL_BITS-1:FINE_BITS];
            fine   <= INIT_CTRL[FINE_BITS-1:0];
            mode   <= 1'b0;
            quiet_count <= 0;
        end else begin
            case ({up, down})
                2'b10: begin
                    quiet_count <= 0;
                    if (!mode) begin
                        if (coarse < MAX_COARSE[COARSE_BITS-1:0])
                            coarse <= coarse + 1'b1;
                    end else begin
                        if (fine < MAX_FINE[FINE_BITS-1:0])
                            fine <= fine + 1'b1;
                    end
                end

                2'b01: begin
                    quiet_count <= 0;
                    if (!mode) begin
                        if (coarse > {COARSE_BITS{1'b0}})
                            coarse <= coarse - 1'b1;
                    end else begin
                        if (fine > {FINE_BITS{1'b0}})
                            fine <= fine - 1'b1;
                    end
                end

                default: begin
                    if (quiet_count < SWITCH_QUIET)
                        quiet_count <= quiet_count + 1'b1;
                end
            endcase

            if (quiet_count == SWITCH_QUIET - 1)
                mode <= 1'b1;
        end
    end

endmodule