//nand2 gate
(* dont_touch = "true", keep_hierarchy = "yes" *)
module nand2(
    input logic a, 
    input logic b, 
    output logic out
);
    assign out = ~(a & b);
endmodule