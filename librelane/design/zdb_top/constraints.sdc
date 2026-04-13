create_clock -name clk_in \
             -period 10 \
             -waveform {0 1.125} \
             [get_ports clk_in]