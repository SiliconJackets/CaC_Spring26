import pandas as pd
import matplotlib.pyplot as plt
from pathlib import Path

# 1. Load the result CSV
result_path = Path(__file__).parent / "results" / "nand_dcdl_results.csv"
df = pd.read_csv(result_path, sep='\s+', header=None)

# Extract time (col 0), Input A (col 1), and Output Y (col 3)
# Column 1 and 3 because for each value, ngspice outputs to columns, left being time, right being value
time = df[0]
v_a = df[1]
v_y = df[3]

# 2. Function to find the 50% VDD (0.9V) crossing time for rising edges
def find_first_rise(t, v, t_start, t_end):
    mask = (t >= t_start) & (t <= t_end)
    t_sub = t[mask].values
    v_sub = v[mask].values
    for i in range(len(v_sub)-1):
        if v_sub[i] < 0.9 and v_sub[i+1] >= 0.9:
            # Linear interpolation for sub-picosecond accuracy
            return t_sub[i] + (t_sub[i+1]-t_sub[i]) * (0.9-v_sub[i])/(v_sub[i+1]-v_sub[i])
    return None

# 3. Define the time windows where each pulse occurs
# Based on a 10ns period and pulses starting at 1ns, 11ns, 21ns...
windows = [
    (10.5e-9, 12e-9, "d1 (Q=0001)"),
    (40.5e-9, 42e-9, "d2 (Q=0010)"),
    (70.5e-9, 72e-9, "d3 (Q=0100)"),
    (90.5e-9, 92e-9, "d4 (Q=1000)")
]

# 4. Generate the Comparison Plot
plt.figure(figsize=(10, 6))
colors = ['blue', 'green', 'orange', 'red']

print("Verification from CSV:")
for i, (start, end, label) in enumerate(windows):
    t_a = find_first_rise(time, v_a, start, end)
    t_y = find_first_rise(time, v_y, start, end)
    
    if t_a and t_y:
        delay = (t_y - t_a) * 1e12
        print(f"{label}: {delay:.2f} ps")
        
        # Plotting logic: Align all pulses to T=0 (A's rising edge) 
        # so the delay difference is visually obvious
        mask_plot = (time >= start - 0.5e-9) & (time <= end + 0.5e-9)
        plt.plot((time[mask_plot] - t_a) * 1e12, v_y[mask_plot], label=label, color=colors[i])

# 5. Formatting the plot
plt.axvline(0, color='black', linestyle='--', label='Input A (50%)')
plt.axhline(0.9, color='gray', linestyle=':', label='50% Vdd')
plt.xlim(-50, 400) # Show 50ps before and 400ps after the edge
plt.title('Final Verified DCDL Tuning Characterization')
plt.xlabel('Time relative to Input A (ps)')
plt.ylabel('Voltage (V)')
plt.legend()
plt.grid(True)
plt.savefig('final_tuning_verified.png')