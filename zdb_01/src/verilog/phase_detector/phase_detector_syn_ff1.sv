`timescale 1ps/1ps

/* |======================================================================= */
/* | */                                                                          
/* | Author             : Mythri Muralikannan */                                                   
/* | Description        : Bang-Bang Phase detector */                                       
/* | This detector does not measure the exact phase error but just outputs a 1-bit decision */                                                                     
/* | UP = 1 --> the reference clock is ahead and there must be a speed up*/                                                                      
/* | DOWN = 1 --> the feedback clock is ahead and there must be a slow down*/                                                                      
/* | SYNTHESIZEABLE!
/* | 1 Flip Flop Version
/* |======================================================================= */


module bangbang_pd (
    input  wire clk_in,    //Reference input clock
    input  wire clk_out,   //Feedback output clock
    input  wire rst,       //Posedge asynchronous reset
    output reg  up,        //Speed Up if 1
    output reg  down       //Slow Down if 1
);

    always @(posedge clk_in or posedge rst) begin
        if (rst) begin
            up   <= 1'b0;
            down <= 1'b0;
        end else begin
            // Sample clk_out at the reference edge
            if (clk_out == 1'b0) begin
                // feedback has not risen yet -> reference is ahead
                up   <= 1'b1;
                down <= 1'b0;
            end else if (clk_out == 1'b1) begin
                // feedback already rose -> feedback is ahead
                up   <= 1'b0;
                down <= 1'b1;
            end else begin
                // unknown clock out
                up   <= 1'b0;
                down <= 1'b0;
            end
        end
    end

endmodule
