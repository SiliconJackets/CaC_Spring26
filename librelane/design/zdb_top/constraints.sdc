create_clock -name clk_in \
             -period 10 \
             -waveform {0 1.125} \
             [get_ports clk_in]

# up_dbg → down_dbg register (path 1)
set_false_path -hold \
    -from [get_pins _186_/CLK] \
    -to   [get_pins _185_/D]

# shift register ctl outputs → DCDL NAND inputs (paths 2-5)
set_false_path -hold \
    -from [get_pins _181_/CLK] \
    -to   [get_pins _155_/A]

set_false_path -hold \
    -from [get_pins _184_/CLK] \
    -to   [get_pins _147_/A]

set_false_path -hold \
    -from [get_pins _182_/CLK] \
    -to   [get_pins _152_/A]

set_false_path -hold \
    -from [get_pins _183_/CLK] \
    -to   [get_pins _149_/A]