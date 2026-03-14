`timescale 1ps/1ps

/* |======================================================================= |
   | Author      : Mythri Muralikannan
   | Description : Bang-Bang Phase Detector (DLL)
   |
   | UP   = 1 -> reference clock is ahead  -> speed up
   | DOWN = 1 -> feedback clock is ahead   -> slow down
   |
   | Implementation:
   | Classic 2-flip-flop phase detector with auto-reset.
   |
   | When both UP and DOWN become 1, the detector resets itself.
   | This prevents lock-up and produces pulses proportional to
   | the phase difference.
   |
   | Fully Synthesizable
   |======================================================================= */

module bangbang_pd (
    input  wire clk_in,     // Reference clock
    input  wire clk_out,    // Feedback clock
    input  wire rst,        // Asynchronous reset
    output wire up,
    output wire down
);

    reg up_ff;
    reg down_ff;

    // Auto-reset when both outputs are high
    wire clr;
    assign clr = rst | (up_ff & down_ff);

    // Reference clock edge
    always @(posedge clk_in or posedge clr) begin
        if (clr)
            up_ff <= 1'b0;
        else
            up_ff <= 1'b1;
    end

    // Feedback clock edge
    always @(posedge clk_out or posedge clr) begin
        if (clr)
            down_ff <= 1'b0;
        else
            down_ff <= 1'b1;
    end

    assign up   = up_ff;
    assign down = down_ff;

endmodule