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

`ifdef SIM
            assign #(0.17) delay[i+1] = delay[i];  //increased delay
`else
            wire n1;
            assign n1         = ~(delay[i] & 1'b1);
            assign delay[i+1] = ~(n1 & 1'b1);
`endif

        end
    endgenerate

    // REGISTERED CONTROL
    reg [CTRL_BITS-1:0] ctrl_r;

    always @(posedge clk_in) begin
        ctrl_r <= ctrl;
    end

    assign clk_out = delay[ctrl_r];

endmodule