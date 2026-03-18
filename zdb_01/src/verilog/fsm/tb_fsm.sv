/* |======================================================================= */
/* | */
/* | Created by         :PSyLab */
/* | Filename           :tb_fsm.sv */
/* | Author             :sathe(UW) */
/* | Created On         :2022-08-31 09:54 */
/* | Last Modified      : */
/* | Update Count       :2022-08-31 09:54 */
/* | Description        : Basic testbench file for verilog simulation. Tasks have been introduced. No signal logging*/
/* | */
/* | */
/* |======================================================================= */

module tb_dut;

    logic rst_i;
    logic clk_i;
    logic go_i;
    logic wb_i;


    logic rd_o;
    logic ds_o;

    logic [1000:0] testname;
    integer returnval;
    integer errors;
    // string testname, returnval;

    parameter PERIODCLK2 = 10;
    parameter real DUTY_CYCLE = 0.5;
    parameter real OFFSET_SAMPLE = 0;
    parameter real OFFSET = 2.5;




    initial begin
    #OFFSET;
    forever
    begin
        clk_i = 1'b0;
        #(PERIODCLK2-(PERIODCLK2*DUTY_CYCLE)) clk_i = 1'b1;
        #(PERIODCLK2*DUTY_CYCLE);
        end
    end


    parameter DLL_N_DELAY_CELL = 30;


    fsm fsm0 (
        .clk_i(clk_i)
        ,.*); //Why does this work?

    // tests
    initial begin : TEST_CASE
        $fsdbDumpfile("fsm_default.fsdb");
        $fsdbDumpon;            //What is this for? Look this up online.
        $fsdbDumpvars(0, fsm0); //What is this for? Do I need this now? Look this up online.
        `ifdef SDF //Why is this compiler directive here? See below
            $sdf_annotate("./syn_dll.sdf", dll0);
        `endif
        errors = 0;
        returnval= $value$plusargs("testname=%s", testname);
        $display ("testname is %s", testname);
        initialize_signals();
 	repeat (10) @(posedge clk_i);
	case(testname)
		"toggle_go_i":        toggle_go_i();
		"toggle_wb_i":        toggle_wb_i();
		"full_state_sequence":test_full_state_sequence();
		"wait_bypass":        test_wait_bypass();
		"reset_during_wait":  test_reset_during_wait();
		"no_go_stays_reset":  test_no_go_stays_reset();
		"multiple_cycles":    test_multiple_full_cycles();
		"all": begin
                    test_full_state_sequence();
                    test_wait_bypass();
                    test_reset_during_wait();
                    test_no_go_stays_reset();
                    test_multiple_full_cycles();
                end
		default: begin
                    $display("Running default: all self-checking tests");
                    test_full_state_sequence();
                    test_wait_bypass();
                    test_reset_during_wait();
                    test_no_go_stays_reset();
                    test_multiple_full_cycles();
                end
	endcase

        // Final report
        #20;
        $display("\n======================================");
        if (errors == 0)
            $display("TESTBENCH PASSED: 0 errors");
        else
            $display("TESTBENCH FAILED: %0d error(s)", errors);
        $display("======================================");

        #1000 $finish;
    end

//Include scan tasks within the testbench module to be able to access
//all of the variables within the module without having to pass them
//as arguments.
`include "./tasks.sv"


endmodule

/********************* NOTES **************************/
// Q: What is SDF and what is the file doing?
// A: SDF is Standard Delay Format.
//
// - Why do I need it?
// At some point, you'll proceed past behavioural simulation and
// rely on a tool to convert that behavioural verilog into a synthesized netlist.
// This netlist is designed by the tool with complete awareness of timing
// targets, fanout, and even estimated wire loading that will be encountered.
// As such, with an SDF file to accompany (not replace) your structural verilog file,
// you can annotate a delay to each gate (actually each input-output timing arc of a gate).
// Think of it as the output of the gate being assigned a #DELAY value assignment to it
// so that input signal transitions cause an output transition after a determine delay.
// Now, you can simulate your *structural* verilog netlist (cmos gates and flip-flops and
// latches and all) with these delays so you have a sense of how fast your system can run.
// In behavioural simulations, you can pick pretty much any cycle time you want, but with
// post-synthesis or post APR netlists, with SDF, you're modeling delays and the SDF
// contains syntax on setup and hold time checks for flip flops. If you fail to meet timing,
// your simulation will reflect that (more on this in a couple of weeks)
/********************* NOTES **************************/
