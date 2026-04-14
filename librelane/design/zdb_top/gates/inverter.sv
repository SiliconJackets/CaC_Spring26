//inverter gate
(* dont_touch = "true", keep_hierarchy = "yes" *)
module inverter (
    input logic in, 
    output logic out
);
    assign out = ~in;
endmodule