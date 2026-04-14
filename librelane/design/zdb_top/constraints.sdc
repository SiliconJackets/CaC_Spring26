create_clock -name clk_in \
             -period 10 \
             -waveform {0 5} \
             [get_ports clk_in]
