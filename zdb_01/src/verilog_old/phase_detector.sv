`timescale 1ps/1ps

    // Behavioral bang-bang detector:
    //   up   = input/reference edge arrived more recently than feedback edge
    //   down = feedback edge arrived more recently than input/reference edge
    // This avoids multi-driver race conditions on the detector state.


module bangbang_pd (
    input  wire clk_in,
    input  wire clk_out,
    input  wire rst,
    output reg  up,
    output reg  down
);

    time last_clk_in;
    time last_clk_out;

    always @(posedge clk_in or posedge rst) begin
        if (rst) begin
            last_clk_in <= 0;
        end else begin
            last_clk_in <= $time;
        end
    end

    always @(posedge clk_out or posedge rst) begin
        if (rst) begin
            last_clk_out <= 0;
        end else begin
            last_clk_out <= $time;
        end
    end


    always @(*) begin
        if (rst) begin
            up   = 1'b0;
            down = 1'b0;
        end else if (last_clk_in > last_clk_out) begin
            up   = 1'b1;
            down = 1'b0;
        end else if (last_clk_out > last_clk_in) begin
            up   = 1'b0;
            down = 1'b1;
        end else begin
            up   = 1'b0;
            down = 1'b0;
        end
    end

endmodule
