//**************************************************************************
// Author: Mythri Muralikannan
// Description: Rewritten zdb delay to implement taps (multiphase generation)
//**************************************************************************
//**************************************************************************
// Description: Simple delay cell (inverter-based)
//**************************************************************************
(* dont_touch = "true" *)
module nand_dcdl_cell(
    input  logic in,
    output logic out
);
    // Simple inverter as delay element
    // In real silicon, this would map to a characterized delay cell
    (* keep = "true" *) logic n;

    // SIM ONLY
    assign n   = #10 ~in;
    assign out = #10 ~n;  // buffer (2 inversions → non-inverting delay)

    // assign n   = ~in;
    // assign out = ~n;  // buffer (2 inversions → non-inverting delay)

endmodule