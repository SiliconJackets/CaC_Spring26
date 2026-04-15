#!/usr/bin/env python3
import numpy as np
import matplotlib.pyplot as plt
from vcdvcd import VCDVCD
import imageio
import argparse

# ================= ARGPARSE =================
parser = argparse.ArgumentParser()
parser.add_argument("--clk", type=float, required=True)
parser.add_argument("--delay", type=int, required=True)
args = parser.parse_args()

CLK_PERIOD = args.clk
DELAY_PS = args.delay

# ================= DERIVED =================
delay_ns = DELAY_PS * 1e-3
tol = min(1.5 * delay_ns, 0.25 * CLK_PERIOD)

# ================= LOAD VCD =================
VCD_FILE = "zdb.vcd"
vcd = VCDVCD(VCD_FILE, signals=[])

def get_signal(name):
    for k in vcd.signals:
        if name in k:
            return vcd[k].tv
    raise ValueError(f"Signal {name} not found")

clk_in = get_signal("clk_in")
clk_out = get_signal("clk_out")
phase = get_signal("phase_error")

# ================= EDGE EXTRACTION =================
def edges(tv):
    return [t for t, v in tv if v == '1']

clk_in_edges = np.array(edges(clk_in)) / 1000
clk_out_edges = np.array(edges(clk_out)) / 1000

phase_t = np.array([t for t, _ in phase]) / 1000
phase_v = np.array([float(v) for _, v in phase])

# ================= EXPLANATION =================

print("\n====================================")
print("🧠 DLL LOCKING EXPLANATION")
print("====================================\n")

print(f"Clock period = {CLK_PERIOD:.3f} ns")
print(f"Delay per stage = {delay_ns:.3f} ns\n")

print("1. WHAT IS HAPPENING?")
print("- clk_in is the reference")
print("- clk_out is delayed")
print("- DLL adjusts delay until edges align\n")

print("2. QUANTIZATION LIMIT")
min_err = delay_ns / 2
print(f"- Minimum possible error ≈ ±{min_err:.3f} ns")
print("- Perfect alignment is impossible due to discrete steps\n")

print("3. TOLERANCE SELECTION")

tol_delay = 1.5 * delay_ns
tol_clk = 0.25 * CLK_PERIOD

print(f"- Hardware limit (1.5×delay) = {tol_delay:.3f} ns")
print(f"- Clock limit (0.25×clk)     = {tol_clk:.3f} ns")

print(f"\n👉 Final tolerance = {tol:.3f} ns")

if tol == tol_delay:
    print("→ Limited by delay resolution")
else:
    print("→ Limited by clock requirement")

print("\n4. LOCK CONDITION")
print(f"- LOCK when |phase_error| < {tol:.3f} ns\n")

print("5. EXPECTED BEHAVIOR")
print("- Phase error starts large")
print("- Decreases step-by-step")
print("- Cannot reach zero")
print("- Settles inside tolerance → LOCK\n")

print("====================================\n")

# ================= STATIC PLOT =================

plt.figure(figsize=(10,6))

plt.subplot(2,1,1)
plt.title("Clock Edge Alignment")
plt.scatter(clk_in_edges, np.zeros_like(clk_in_edges), label="clk_in", marker='|')
plt.scatter(clk_out_edges, np.ones_like(clk_out_edges), label="clk_out", marker='|')
plt.yticks([0,1], ["clk_in", "clk_out"])
plt.legend()

plt.subplot(2,1,2)
plt.title("Phase Error Convergence")
plt.plot(phase_t, phase_v, label="phase_error")

# zero line
plt.axhline(0, linestyle='--')

# tolerance
plt.axhline(tol, linestyle=':', color='green', label="lock tolerance")
plt.axhline(-tol, linestyle=':', color='green')

# quantization limit
plt.axhline(delay_ns/2, linestyle='--', color='orange', label="quantization limit")
plt.axhline(-delay_ns/2, linestyle='--', color='orange')

plt.xlabel("Time (ns)")
plt.ylabel("Phase Error (ns)")
plt.legend()
plt.grid()

plt.tight_layout()
plt.savefig("waveform_explained.jpg")
plt.close()

# ================= ANIMATION =================

frames = []
window = 50

for i in range(window, len(phase_t), 10):
    plt.figure(figsize=(8,5))

    plt.plot(phase_t[:i], phase_v[:i], label="phase_error")
    plt.axhline(0, linestyle='--')

    plt.axhline(tol, linestyle=':', color='green')
    plt.axhline(-tol, linestyle=':', color='green')

    plt.axhline(delay_ns/2, linestyle='--', color='orange')
    plt.axhline(-delay_ns/2, linestyle='--', color='orange')

    if i > 100 and np.all(np.abs(phase_v[i-20:i]) < tol):
        plt.text(phase_t[i-1], 0, "LOCKED", color="green")

    plt.title("DLL Locking Process")
    plt.xlabel("Time (ns)")
    plt.ylabel("Phase Error (ns)")
    plt.legend()

    fname = f"_frame_{i}.png"
    plt.savefig(fname)
    plt.close()

    frames.append(imageio.imread(fname))

imageio.mimsave("locking_animation.gif", frames, duration=0.2)

# ================= FINAL SUMMARY =================

final_err = phase_v[-1]

print("====================================")
print("📊 FINAL RESULT")
print("====================================")

print(f"Final phase error = {final_err:.4f} ns")

if abs(final_err) < tol:
    print("✅ SYSTEM LOCKED SUCCESSFULLY")
else:
    print("❌ SYSTEM DID NOT FULLY LOCK")

print("\nGenerated:")
print("- waveform_explained.jpg")
print("- locking_animation.gif")
print("====================================")