module pfd (
    input  wire clk_ref,
    input  wire clk_fb,
    input  wire rst_n,
    output wire up,
    output wire down
);

    reg up_ff, down_ff;
    wire rst_int;

    // reset when both asserted
    assign rst_int = up_ff & down_ff;

    // UP path
    always @(posedge clk_ref or negedge rst_n) begin
        if (!rst_n)
            up_ff <= 1'b0;
        else if (rst_int)
            up_ff <= 1'b0;
        else
            up_ff <= 1'b1;
    end

    // DOWN path
    always @(posedge clk_fb or negedge rst_n) begin
        if (!rst_n)
            down_ff <= 1'b0;
        else if (rst_int)
            down_ff <= 1'b0;
        else
            down_ff <= 1'b1;
    end

    assign up   = up_ff;
    assign down = down_ff;

endmodule