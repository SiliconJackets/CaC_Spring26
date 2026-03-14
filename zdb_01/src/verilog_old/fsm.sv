/* |======================================================================= */
/* | */  
/* | Created by         :PSyLab */                                           
/* | Filename           :fsm.sv */                                  
/* | Author             :sathe(UW) */                                    
/* | Created On         :2022-07-14 07:38 */                   
/* | Last Modified      : */                                                 
/* | Update Count       :2022-07-14 07:38 */                   
/* | Description        : Basic FSM description*/                                            
/* | */                                                                      
/* | */                                                                      
/* |======================================================================= */

/* Using parameters is a great (and sometimes absolutely critical) way to provide */
/* flexibility to your code. This  approach not only lets you  setup MWEs with low */ 
/* bitwidth, or lower tile-counts etc. for trailblazing your sapr flow, it will also */ 
/* help promote the re-usability of your solution. */
module fsm 
    #(
        parameter    wait_cycle = 3,
        parameter    unused_for_demo_only = 0
    )
    (
        input logic rst_i, //reset
        input logic clk_i,   //clock
        input logic go_i,    //go signal
        input logic wb_i,    //wait_bypass
        output logic rd_o,   //read output signal
        output logic ds_o    //done output signal
    );


    /* Import the fsm package where you have encoded your state variables to integer values */
    /* using typedef enum. This approach will help with readability of your code, and your */
    /* waveforms during debug. */
    import fsm_pkg::*;
    state_struct state_r, next_state_r;  //Define state and next of type state_struct
    
    //Use $clog2 to derive the bitwidth of the wait cycle counter since it 
    //can be changed by the calling module at a higher level.
    logic [$clog2(wait_cycle)-1:0] wait_cycle_count_r, count_next_state_r;

    //always statement for defining FSM state related update
    //Why did i do postedge clk_i or posedge rst_i? Why not exclude rst_i? 
    //Why not posedge clk_i or rst_i? What do those alternatives do?
	always_ff @(posedge clk_i or posedge rst_i) 
        if(rst_i) begin
            state_r<=RESET;
            wait_cycle_count_r<='0;
        end
        else begin
            state_r<=next_state_r;
            wait_cycle_count_r<=count_next_state_r;
        end

//always statement for defining next_state_r state
	always_comb begin
		next_state_r = STATEX;  //default state to X for debug. I prefer lining up the "<=".
        count_next_state_r='0;
        case (state_r)
	    RESET: next_state_r=(go_i)? READ:RESET;
	    READ: next_state_r=WAIT; //after read state, automatically go into wait state  
            WAIT: begin 
                    next_state_r=(wait_cycle_count_r==wait_cycle-1 || wb_i==1'b1)? DONE:WAIT;
                    count_next_state_r = (wait_cycle_count_r == wait_cycle-1)? '0 : wait_cycle_count_r+1'b1;
                  end
            DONE: next_state_r = RESET;
            default: next_state_r=STATEX;
        endcase
    end

//always statement for outputs.
    always_ff @(posedge clk_i or posedge rst_i)
        if(rst_i) begin //Default assignments
		    ds_o<=1'b0;
		    rd_o<=1'b0;
        end
        else begin
                  rd_o<=1'b0;//Assign defaults
                  ds_o<=1'b0;//Assign defaults
        case (next_state_r)
            RESET: ; //Why do I need this?
            READ: rd_o<=1'b1;
            WAIT: rd_o<=1'b1;
            DONE: ds_o<=1'b1;
            default: {rd_o,ds_o} <='x; //What does 'x syntax do? 
        endcase
        end

endmodule

////////////////////Some points to ponder and try out////////////
//1. Why did I need to use the $clog2 function? Why not just hard_o code the width of the counter
//2. What's the benefit of going through all the trouble to define typedefs for the state? 
//3. Why not just go with `define statements which look like they will do the same thing?
//4. I want to build a design based on a "double-edged" flop, i.e. it will trigger on rising and falling edges of the clock. Will it work for me to do always_ff @(clk or posedge rst_i)? What happens in simulation? What happens in Synthesis? Try it!! 
