package fsm_pkg;
typedef enum logic[2:0] {
    RESET = 3'b000,
    READ = 3'b001,
    WAIT = 3'b010,
    DONE = 3'b100,
    STATEX    = 3'bxxx
} state_struct;
endpackage
