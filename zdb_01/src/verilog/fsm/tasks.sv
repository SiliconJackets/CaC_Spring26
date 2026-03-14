//File containing simple verification tasks
//The tasknames in this example are unimaginative and undescriptive.
//Please use meaningful task names in your work :)

task initialize_signals();
    begin
        rst_i=1'b1;
        clk_i=1'b0;
        go_i=1'b0;
        wb_i=1'b0;
    end
endtask

task toggle_go_i();
    begin
        @(posedge clk_i);
        rst_i=1'b0;
        repeat (5) begin
            @(posedge clk_i);
            go_i=~go_i;
        end
    end
endtask

task toggle_wb_i();
    begin
        @(posedge clk_i);
        rst_i=1'b0;
        repeat (5) begin
            @(posedge clk_i);
            wb_i=~wb_i;
        end
    end
endtask
