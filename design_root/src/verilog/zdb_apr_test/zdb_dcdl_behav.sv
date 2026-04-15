module dcdl #(
    parameter integer CTRL_BITS = 6
)(
    input  wire                 clk_in,
    input  wire [CTRL_BITS-1:0] ctrl,
    output wire                 clk_out
);

    localparam integer STAGES = (1 << CTRL_BITS);

    wire [STAGES:0] delay;

    assign delay[0] = clk_in;

    genvar i;
    generate
        for (i = 0; i < STAGES; i = i + 1) begin : delay_chain

            assign #(0.1) delay[i+1] = delay[i];  //increased delay


        end
    endgenerate

    // REGISTERED CONTROL
    reg [CTRL_BITS-1:0] ctrl_r;

    always @(posedge clk_in) begin
        ctrl_r <= ctrl;
    end

    assign clk_out = delay[ctrl_r];

endmodule