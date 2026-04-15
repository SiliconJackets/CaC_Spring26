module zdb_top #(
    parameter integer CTRL_BITS = 6
)(
    input  wire clk_in,
    input  wire rst,

    output wire clk_out,
    output wire locked,
    output wire [CTRL_BITS-1:0] ctrl_dbg
);

    // ---------------------------------
    // Internal signals
    // ---------------------------------
    wire up, down;
    wire [CTRL_BITS-1:0] ctrl;

    wire clk_delayed;

    // ---------------------------------
    // DCDL
    // ---------------------------------
    dcdl #(
        .CTRL_BITS(CTRL_BITS)
    ) u_dcdl (
        .clk_in  (clk_in),
        .ctrl    (ctrl),
        .clk_out (clk_delayed)
    );

    // Single source of truth
    assign clk_out = clk_delayed;

    // ---------------------------------
    // Phase Detector
    // ---------------------------------
    pfd u_pfd (
        .clk_ref (clk_in),
        .clk_fb  (clk_out),
        .rst_n   (~rst),
        .up      (up),
        .down    (down)
    );

    // ---------------------------------
    // Update rate control (CRITICAL)
    // ---------------------------------
    reg update_div;

    always @(posedge clk_in or posedge rst) begin
        if (rst)
            update_div <= 0;
        else
            update_div <= update_div + 1;
    end

    wire update_en = (update_div == 0);

    // ---------------------------------
    // Controller
    // ---------------------------------
    controller #(
        .CTRL_BITS (CTRL_BITS),
        .INIT_CTRL (1 << (CTRL_BITS-1))
    ) u_ctrl (
        .clk_in    (clk_in),
        .rst       (rst),
        .up        (up),
        .down      (down),
        .update_en (update_en),
        .ctrl      (ctrl)
    );

    // ---------------------------------
    // Lock detector (robust)
    // ---------------------------------
    reg [7:0] lock_cnt;
    reg locked_r;

    always @(posedge clk_in or posedge rst) begin
        if (rst) begin
            lock_cnt <= 8'd0;
            locked_r <= 1'b0;
        end else begin
            if (~(up | down)) begin
                if (lock_cnt != 8'hFF)
                    lock_cnt <= lock_cnt + 1;
            end else begin
                lock_cnt <= 8'd0;
            end

            locked_r <= (lock_cnt > 20);
        end
    end

    assign locked   = locked_r;
    assign ctrl_dbg = ctrl;

endmodule