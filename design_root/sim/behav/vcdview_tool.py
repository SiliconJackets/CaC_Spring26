import sys
import matplotlib.pyplot as plt

def parse_vcd(filename):
    signals = {}
    id_to_name = {}
    current_time = 0

    with open(filename, 'r') as f:
        for line in f:
            line = line.strip()

            if line.startswith("$var"):
                parts = line.split()
                var_id = parts[3]
                name = parts[4]
                id_to_name[var_id] = name
                signals[var_id] = []

            elif line.startswith("#"):
                current_time = int(line[1:])

            elif line and (line[0] in "01xz"):
                value = line[0]
                var_id = line[1:]
                if var_id in signals:
                    signals[var_id].append((current_time, value))

    return signals, id_to_name


def get_signal(signals, id_to_name, target):
    for var_id, name in id_to_name.items():
        if target in name:
            return signals[var_id], name
    return None, None


def to_digital(tv):
    times, values = [], []
    for t, v in tv:
        times.append(t)
        values.append(1 if v == '1' else 0)
    return times, values


def get_rising_edges(tv):
    edges = []
    prev = '0'
    for t, v in tv:
        if prev == '0' and v == '1':
            edges.append(t)
        prev = v
    return edges


def compute_phase_error(edges_ref, edges_fb):
    errors = []
    times = []

    for e in edges_fb:
        # find closest reference edge
        closest = min(edges_ref, key=lambda x: abs(x - e))
        error = e - closest
        times.append(e)
        errors.append(error)

    return times, errors


def plot(vcd_file, output="waveform.jpg"):
    signals, names = parse_vcd(vcd_file)

    clk_tv, clk_name = get_signal(signals, names, "clk")
    fb_tv, fb_name = get_signal(signals, names, "clk_fb")
    lock_tv, lock_name = get_signal(signals, names, "locked")

    if clk_tv is None or fb_tv is None:
        print("Missing clk or clk_fb")
        return

    # Convert
    t1, v1 = to_digital(clk_tv)
    t2, v2 = to_digital(fb_tv)

    # Edge detection
    edges_clk = get_rising_edges(clk_tv)
    edges_fb = get_rising_edges(fb_tv)

    # Phase error
    err_t, err_v = compute_phase_error(edges_clk, edges_fb)

    fig, axes = plt.subplots(3, 1, sharex=True, figsize=(12, 8))

    # --- Waveforms ---
    axes[0].step(t1, v1, where='post', label=clk_name)
    axes[0].step(t2, [x + 1.2 for x in v2], where='post', label=fb_name)

    # Mark edges
    axes[0].scatter(edges_clk, [1]*len(edges_clk), marker='|')
    axes[0].scatter(edges_fb, [2.2]*len(edges_fb), marker='|')

    axes[0].legend()
    axes[0].set_ylabel("CLK overlay")
    axes[0].grid(True)

    # --- Locked ---
    if lock_tv:
        t3, v3 = to_digital(lock_tv)
        axes[1].step(t3, v3, where='post')
        axes[1].set_ylabel(lock_name)
        axes[1].grid(True)

    # --- Phase error ---
    axes[2].plot(err_t, err_v, marker='o')
    axes[2].axhline(0)
    axes[2].set_ylabel("Phase Error (time)")
    axes[2].set_xlabel("Time")
    axes[2].grid(True)

    plt.tight_layout()
    plt.savefig(output)
    print("Saved to", output)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python vcdview_tool.py <file.vcd>")
        sys.exit(1)

    plot(sys.argv[1])