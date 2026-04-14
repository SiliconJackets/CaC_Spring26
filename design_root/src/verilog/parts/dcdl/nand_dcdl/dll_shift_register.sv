//**************************************************************************
// Author: Alfi Misha Antony Selvin Raj
// Description: Shift register for one hot encoding
//**************************************************************************
module dll_shift_register #(
    parameter int N = 64
)(
    input  logic clk,
    input  logic rst_n,
    input  logic shift_left,
    input  logic shift_right,
    output logic [N-1:0] Q
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            Q <= {{(N-1){1'b0}}, 1'b1};   // 000...0001
        end
        else if (shift_left) begin
            Q <= {Q[N-2:0], Q[N-1]};
        end
        else if (shift_right) begin
            Q <= {Q[0], Q[N-1:1]};
        end
    end

endmodule