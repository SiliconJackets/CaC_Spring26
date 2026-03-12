module tb_ring_oscillator;

logic [1:0] sel;
logic clk_out;

ring_oscillator dut (
    .sel(sel),
    .clk_out(clk_out)
);

initial begin
    $vcdplusfile("ring_oscillator.vpd");
    $vcdpluson();
    sel = 2'b00;
    #100;

    sel = 2'b01;
    #100;

    sel = 2'b10;
    #100;

    sel = 2'b11;
    #100;

    $finish;
end

endmodule