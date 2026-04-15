`timescale 1ps/1ps

//**************************************************************************
// Module      : sampled_xor_phase_detector
// Author      : Mythri Muralikannan
// Description : XOR-based sampled bang-bang phase detector
//**************************************************************************

module phase_detector (
    input  wire clk_in,    // Reference clock
    input  wire clk_out,   // Feedback clock
    input  wire rst,       // Asynchronous active-high reset
    output reg  up,        // Request to speed up
    output reg  down       // Request to slow down
);

    // Phase mismatch indicator
    wire phase_error;
    assign phase_error = clk_in ^ clk_out;

    always @(posedge clk_in or posedge rst) begin
        if (rst) begin
            up   <= 1'b0;
            down <= 1'b0;
        end
        else begin
            if (phase_error) begin
                // Determine which clock leads by sampling clk_out
                if (clk_out == 1'b0) begin
                    // Reference edge arrived first
                    up   <= 1'b1;
                    down <= 1'b0;
                end
                else begin
                    // Feedback already high -> feedback leads
                    up   <= 1'b0;
                    down <= 1'b1;
                end
            end
            else begin
                // No detectable phase difference
                up   <= 1'b0;
                down <= 1'b0;
            end
        end
    end

endmodule