//**************************************************************************
// Author: Oliver Lee
// Description: Wrapper for SKY130 PDK NAND and INV
//**************************************************************************

module nand2 (
    input logic a,
    input logic b,
    output logic out
);
    (* dont_touch = "true" *) sky130_fd_sc_hd__nand2_1 core_nand (
        .A(a), .B(b), .Y(out)
    );
endmodule

module inverter (
    input logic in,
    output logic out
);
    (* dont_touch = "true" *) sky130_fd_sc_hd__inv_2 core_inv (
        .A(in), .Y(out)
    );
endmodule