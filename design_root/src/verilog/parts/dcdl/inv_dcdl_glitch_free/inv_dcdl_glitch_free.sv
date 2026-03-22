module inv_dcdl_glitch_free(
    input logic clk, 
    input logic rst_n, 
    input logic A, 
    input logic[1:0] Q,  //this is user input
    output logic Y
)
    logic tap0, tap1, tap2, tap3;
    assign tap0 = A;
    assign tap1 = ~tap0;
    assign tap2 = ~tap1;
    assign tap3 = ~tap2;
    //this is the big change from the inv_dcdl.
    //when the output is driven by the tap mux directly by the wire input that comes from Q, 
    //we are risking glitches as the wire voltages might not change immediately. The intermediate 
    //steps may insert erroneous delay. So we change the user input to a one
    logic [3:0] sel;
    always_comb begin
        sel = 4'b0000;
        sel[Q] = 1'b1;
    end
    //using register for extra glitch protection
    logic [3:0] sel_reg;
    always_ff(@posedge clk or negedge rst_n) begin
        if (!rst_n)
            sel_reg <= 4'b0001;
        else
            sel_reg <= sel;
    end
    logic y0, y1, y2, y3;
    assign y0 = ~(~tap0 & sel_reg[0]);
    assign y1 = ~(~tap1 & sel_reg[1]);
    assign y2 = ~(~tap2 & sel_reg[2]);
    assign y3 = ~(~tap3 & sel_reg[3]);
    assign Y = ~(y0 & y1 & y2 & y3);
endmodule