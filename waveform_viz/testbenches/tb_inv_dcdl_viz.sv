`timescale 1ps/1ps

module tb_inv_dcdl_viz;

    logic A;
    logic [1:0] Q;
    logic Y;

    inv_dcdl dut (.A(A), .Q(Q), .Y(Y));

    reg [8*512-1:0] fsdbpath;
    integer i;

    initial begin
        if (!$value$plusargs("fsdbpath=%s", fsdbpath)) fsdbpath = "dump.fsdb";

        $fsdbDumpfile(fsdbpath);
        $fsdbDumpvars(0, dut);

        A = 0; Q = 2'b00;

        // Demo: sweep Q while toggling A — shows tap selection behavior
        for (i = 0; i < 4; i = i + 1) begin
            Q = i[1:0];
            repeat (8) #5000 A = ~A;
        end
        A = 0; #5000;

        $finish;
    end

endmodule
