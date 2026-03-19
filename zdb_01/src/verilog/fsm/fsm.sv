module fsm
    #(
        parameter DEAD_ZONE = 3, // DEAD_ZONE * d_r << d_sw and DEAD_ZONE * d_r >> 0.5T
        parameter CONTROL_BITS = 4
    )
    (
        input logic rst_i,
        input logic clk_i,
        input logic up, // Asserted to speed up
        input logic down, // Asserted to slow down
        output logic [CONTROL_BITS-1:0] ctrl
    );


    typedef enum logic[2:0] {
        RESET,
        LOCKING,
        WAIT,
        INC,
        DEC
    } state_struct;

    state_struct state, next_state;

    logic [$clog2(DEAD_ZONE)-1:0] current_wait_count, next_wait_count;
    
	always_ff @(posedge clk_i or posedge rst_i) 
        if(rst_i) begin
            state <= RESET;
            current_wait_count <= 0;
        end
        else begin
            state <= next_state;
            current_wait_count <= next_wait_count;
        end

	always_comb begin
        next_state = state;
        next_wait_count = current_wait_count;

        case (state)
	        RESET: next_state = LOCKING;
	        LOCKING: begin
                if (down) begin 
                    next_state = WAIT;
                end else begin
                    next_state = LOCKING;
                end
                next_wait_count = 0;
            end
            WAIT: begin
                next_wait_count = current_wait_count + 1;
                next_state = (current_wait_count < DEAD_ZONE - 1) ? WAIT : INC;
            end
            INC: begin
                if (up) begin 
                    next_state = INC;
                end else if (down) begin
                    next_state = DEC;
                end 
            end
            DEC: begin
                if (up) begin 
                    next_state = INC;
                end else if (down) begin
                    next_state = DEC;
                end 
            end
            default: next_state = state;
        endcase
    end

    always_ff @(posedge clk_i or posedge rst_i)
        if(rst_i) begin
            ctrl <= 0;
        end else begin
            case (state)
                LOCKING: ctrl <= ctrl + 1;
                WAIT: begin
                    ctrl <= ctrl + 1;
                end
                INC: ctrl <= ctrl + 1;
                DEC: ctrl <= ctrl - 1;
                default: ctrl <= ctrl;
            endcase
        end
endmodule