import numpy as np
import matplotlib.pyplot as plt
from vcdvcd import VCDVCD
import imageio

VCD_FILE = "zdb.vcd"
CLK_PERIOD = 4.0   # ns (match your TB)
DELAY_PS = 700     # ps

# ================= LOAD VCD =================
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

print("1. WHAT IS HAPPENING?")
print("- You have a reference clock (clk_in)")
print("- The DLL creates a delayed version (clk_out)")
print("- The goal: align clk_out edges with clk_in edges\n")

print("2. HOW DOES IT DO THIS?")
print("- A delay line adds delay in discrete steps")
print(f"- Each step = {DELAY_PS} ps")
print("- A controller adjusts how many steps are used (ctrl)\n")

print("3. TOTAL DELAY:")
print("   total_delay = ctrl × delay_per_stage")
print(f"   Example: ctrl=32 → delay ≈ {32 * DELAY_PS / 1000:.2f} ns\n")

print("4. WHAT IS PHASE ERROR?")
print("   phase_error = clk_out_edge - clk_in_edge")
print("- If positive → clk_out is LATE")
print("- If negative → clk_out is EARLY\n")

print("5. LOCK CONDITION:")
tol = CLK_PERIOD * 0.1
print(f"- We consider it LOCKED when |phase_error| < {tol:.3f} ns")
print("- And this stays stable for many cycles\n")

print("6. WHAT YOU SHOULD SEE:")
print("- Initially: large phase error")
print("- Controller adjusts delay")
print("- Phase error shrinks toward 0")
print("- Eventually stays within tolerance → LOCK\n")

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
plt.plot(phase_t, phase_v)
plt.axhline(0, linestyle='--')
plt.axhline(tol, linestyle=':', color='green', label="lock tolerance")
plt.axhline(-tol, linestyle=':', color='green')
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

    # Highlight "locked region"
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