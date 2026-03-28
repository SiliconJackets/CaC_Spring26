#!/usr/bin/env python3
"""
Generate animated waveform GIFs from VCD waveform files.

Usage:
    python3 generate_gifs.py <vcd_dir> <gif_dir>
"""

import sys
import os
import re
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from PIL import Image


# Aesthetics
SIGNAL_COLORS = {
    'clk_in':       '#1565C0',
    'clk_out':      '#E65100',
    'clk':          '#1565C0',
    'up':           '#2E7D32',
    'down':         '#6A1B9A',
    'ctrl':         '#D84315',
    'A':            '#1565C0',
    'Y':            '#2E7D32',
    'Q':            '#E65100',
    'sel':          '#E65100',
    'shift_left':   '#00695C',
    'shift_right':  '#4E342E',
}
BUS_FILL_COLORS = {
    'ctrl':  '#FFCCBC',
    'Q':     '#FFE0B2',
    'sel':   '#FFE0B2',
}
DEFAULT_COLOR = '#455A64'
DEFAULT_BUS_FILL = '#E0E0E0'

MULTI_BIT_SIGNALS = {'ctrl', 'Q', 'sel'}

FIGURE_WIDTH   = 14
SUBPLOT_HEIGHT = 1.0
FPS            = 20
DRAW_SECONDS   = 5
FREEZE_SECONDS = 5

# Signal selection per module type
SIGNAL_MAP = {
    'controller': ['clk_in', 'up', 'down', 'ctrl'],
    'pd':              ['clk_in', 'clk_out', 'up', 'down'],
    'phase_detector':  ['clk_in', 'clk_out', 'up', 'down'],
    'inv_dcdl_cond':         ['A', 'Q', 'Y'],
    'inv_dcdl_glitch_free':  ['clk', 'A', 'Q', 'Y'],
    'inv_dcdl':              ['A', 'Q', 'Y'],
    'nand_dcdl':  ['clk', 'shift_left', 'shift_right', 'A', 'Q', 'Y'],
    'ring_osc':   ['sel', 'clk_out'],
}


# VCD Parser
def parse_vcd(vcd_path, wanted_signals=None):
    """Parse a VCD file. Returns (timescale_str, signals_dict)."""
    id_to_name = {}
    id_to_width = {}
    in_header = True
    raw_changes = {}
    current_time = 0
    timescale = '1ps'
    in_dumpvars = False

    with open(vcd_path, 'r') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue

            if line.startswith('$timescale'):
                m = re.search(r'(\d+\s*\w+)', line)
                if m:
                    timescale = m.group(1).strip()
                continue

            if line.startswith('$scope'):
                continue
            if line.startswith('$upscope'):
                continue

            if line.startswith('$var'):
                parts = line.split()
                if len(parts) >= 5:
                    width = int(parts[2])
                    identifier = parts[3]
                    name = parts[4]
                    if name.endswith(']') and '[' in name:
                        name = name[:name.index('[')]
                    if wanted_signals is None or name in wanted_signals:
                        id_to_name[identifier] = name
                        id_to_width[identifier] = width
                        if identifier not in raw_changes:
                            raw_changes[identifier] = []
                continue

            if line.startswith('$enddefinitions'):
                in_header = False
                continue

            if line.startswith('$dumpvars'):
                in_dumpvars = True
                continue

            if line == '$end' and in_dumpvars:
                in_dumpvars = False
                continue

            if line.startswith('$'):
                continue

            if in_header and not in_dumpvars:
                continue

            if line.startswith('#'):
                current_time = int(line[1:])
                continue

            # Single-bit value
            if len(line) >= 2 and line[0] in '01xXzZ':
                val_char = line[0]
                identifier = line[1:]
                if identifier in id_to_name:
                    val = 0 if val_char in ('x', 'X', 'z', 'Z') else int(val_char)
                    raw_changes[identifier].append((current_time, val))
                continue

            # Multi-bit value
            if line.startswith('b') or line.startswith('B'):
                parts = line.split()
                if len(parts) == 2:
                    binary_str = parts[0][1:]
                    identifier = parts[1]
                    if identifier in id_to_name:
                        clean = binary_str.replace('x', '0').replace('X', '0')
                        clean = clean.replace('z', '0').replace('Z', '0')
                        try:
                            val = int(clean, 2)
                        except ValueError:
                            val = 0
                        raw_changes[identifier].append((current_time, val))
                continue

    signals = {}
    for identifier, changes in raw_changes.items():
        if identifier not in id_to_name or not changes:
            continue
        name = id_to_name[identifier]
        width = id_to_width[identifier]
        times = np.array([c[0] for c in changes], dtype=np.float64)
        values = np.array([c[1] for c in changes], dtype=np.float64)
        signals[name] = {'times': times, 'values': values, 'width': width}

    return timescale, signals


def resample_signals(signals, t_start=None, t_end=None):
    """Build unified time array with sample-and-hold values."""
    if not signals:
        return np.array([]), {}

    all_times = set()
    for sig in signals.values():
        all_times.update(sig['times'].tolist())
    all_times = sorted(all_times)

    if not all_times:
        return np.array([]), {}

    if t_start is None:
        t_start = all_times[0]
    if t_end is None:
        t_end = all_times[-1]

    times = np.array([t for t in all_times if t_start <= t <= t_end],
                     dtype=np.float64)

    resampled = {}
    for name, sig in signals.items():
        vals = np.zeros(len(times), dtype=np.float64)
        sig_times = sig['times']
        sig_vals = sig['values']
        idx = 0
        current_val = sig_vals[0] if len(sig_vals) > 0 else 0
        for i, t in enumerate(times):
            while idx < len(sig_times) - 1 and sig_times[idx + 1] <= t:
                idx += 1
            if idx < len(sig_times) and sig_times[idx] <= t:
                current_val = sig_vals[idx]
            vals[i] = current_val
        resampled[name] = vals

    return times, resampled


# Signal Selection
def get_wanted_signals(filename):
    name = filename.replace('.vcd', '')
    for prefix in sorted(SIGNAL_MAP.keys(), key=len, reverse=True):
        if name.startswith(prefix):
            return SIGNAL_MAP[prefix]
    return None


# Title Formatting
def format_title(filename):
    name = filename.replace('.vcd', '')
    parts = name.split('_')
    title = ' '.join(p.capitalize() for p in parts)
    title = title.replace('Pd ', 'Phase Detector ')
    title = title.replace('Inv ', 'Inverter ')
    title = title.replace('Dcdl', 'DCDL')
    title = title.replace('Nand', 'NAND')
    title = title.replace('Osc', 'Oscillator')
    title = title.replace('2Mode', '2-Mode')
    title = title.replace('2Ns', '2ns')
    title = title.replace('Pfd', 'PFD')
    title = title.replace('Ff1', 'FF1')
    title = title.replace('Xor1', 'XOR1')
    return title


# Bus Waveform Drawing
def draw_bus_waveform(ax, times, vals, n_show, color, fill_color):
    """
    Draw a bus waveform in Verdi/GTKWave style:
    - Filled blocks between transitions
    - Diagonal X crossovers at value changes (when space allows)
    - Value labels centered in each block (when space allows)
    Adapts to signal density: dense signals get clean outlines,
    sparse signals get full crossovers and labels.
    """
    # Remove previous bus drawing elements without resetting axis
    for artist in list(ax.patches):
        artist.remove()
    for line in list(ax.lines):
        line.remove()
    for txt in list(ax.texts):
        txt.remove()

    t = times[:n_show]
    v = vals[:n_show]

    if len(t) == 0:
        return

    y_lo, y_hi = 0.15, 0.85
    t_range = times[-1] - times[0]
    if t_range == 0:
        t_range = 1

    # Figure width in data units per pixel (approximate)
    fig_width_px = FIGURE_WIDTH * 100  # DPI=100
    plot_frac = 0.85  # approximate fraction of figure that is plot area
    data_per_px = t_range / (fig_width_px * plot_frac)

    # Find constant-value segments
    segments = []
    seg_start = 0
    for i in range(1, len(t)):
        if v[i] != v[seg_start]:
            segments.append((t[seg_start], t[i], int(v[seg_start])))
            seg_start = i
    segments.append((t[seg_start], t[-1], int(v[seg_start])))

    # Crossover width scales with segment size, capped
    min_seg_width = min((s[1] - s[0]) for s in segments if s[1] > s[0]) \
                    if any(s[1] > s[0] for s in segments) else t_range * 0.01
    cross_w = min(min_seg_width * 0.3, t_range * 0.008)

    for seg_t0, seg_t1, seg_val in segments:
        if seg_t1 <= seg_t0:
            continue

        seg_px = (seg_t1 - seg_t0) / data_per_px  # segment width in pixels

        # Fill rectangle
        poly = plt.Polygon(
            [[seg_t0 + cross_w, y_lo], [seg_t1, y_lo],
             [seg_t1, y_hi], [seg_t0 + cross_w, y_hi]],
            closed=True, facecolor=fill_color, edgecolor='none', alpha=0.5)
        ax.add_patch(poly)

        # Top and bottom bus lines
        ax.plot([seg_t0 + cross_w, seg_t1], [y_hi, y_hi],
                color=color, linewidth=1.5)
        ax.plot([seg_t0 + cross_w, seg_t1], [y_lo, y_lo],
                color=color, linewidth=1.5)

        # Crossover X at transition (only if segment wide enough)
        if seg_t0 > times[0] and seg_px > 6:
            ax.plot([seg_t0, seg_t0 + cross_w], [y_lo, y_hi],
                    color=color, linewidth=1.5)
            ax.plot([seg_t0, seg_t0 + cross_w], [y_hi, y_lo],
                    color=color, linewidth=1.5)
        elif seg_t0 > times[0]:
            # Narrow segment: just draw vertical transition line
            ax.plot([seg_t0, seg_t0], [y_lo, y_hi],
                    color=color, linewidth=0.8, alpha=0.5)

        # Value label (only if wide enough to be readable)
        if seg_px > 35:
            mid_t = (seg_t0 + cross_w + seg_t1) / 2
            label = '0x{:X}'.format(seg_val)
            # Shrink font if label won't fit, skip if still too tight
            fsize = 7
            if seg_px < 50:
                fsize = 6
            if seg_px < 40:
                label = '{:X}'.format(seg_val)  # drop 0x prefix
            if seg_px >= 25:
                ax.text(mid_t, 0.5, label, ha='center', va='center',
                        fontsize=fsize, color='#424242', fontweight='bold',
                        clip_on=True)

    # Close the bus at the start
    if len(segments) > 0:
        ax.plot([segments[0][0], segments[0][0] + cross_w], [y_lo, y_hi],
                color=color, linewidth=1.5)
        ax.plot([segments[0][0], segments[0][0] + cross_w], [y_hi, y_lo],
                color=color, linewidth=1.5)

    ax.set_ylim(-0.05, 1.05)
    ax.set_yticks([])


# GIF Generation
def generate_gif(vcd_path, gif_path, title=""):
    filename = os.path.basename(vcd_path)
    wanted = get_wanted_signals(filename)

    timescale, raw_signals = parse_vcd(vcd_path, set(wanted) if wanted else None)

    if not raw_signals:
        print("  WARNING: no signals found in VCD, skipping")
        return

    if wanted:
        signal_names = [s for s in wanted if s in raw_signals]
    else:
        signal_names = sorted(raw_signals.keys())

    if not signal_names:
        print("  WARNING: none of the wanted signals found, skipping")
        return

    filtered = {n: raw_signals[n] for n in signal_names}
    times, values = resample_signals(filtered)

    if len(times) == 0:
        print("  WARNING: empty time range, skipping")
        return

    n_signals = len(signal_names)

    # Classify signals
    is_bus = {}
    for name in signal_names:
        w = raw_signals[name]['width']
        is_bus[name] = (w > 1 or name in MULTI_BIT_SIGNALS)

    # Create figure
    fig_height = 0.8 + 0.6 + n_signals * SUBPLOT_HEIGHT
    fig, axes = plt.subplots(n_signals, 1,
                             figsize=(FIGURE_WIDTH, fig_height),
                             sharex=True)
    if n_signals == 1:
        axes = [axes]

    fig.patch.set_facecolor('white')
    fig.suptitle(title, fontsize=13, fontweight='bold', y=0.98,
                 color='#212121')

    t_min, t_max = times[0], times[-1]
    if t_max == t_min:
        t_max = t_min + 1

    time_unit = 'ps'
    if 'ns' in timescale:
        time_unit = 'ns'

    # Compute consistent left margin based on longest signal name
    max_name_len = max(len(n) for n in signal_names)
    left_margin = 0.06 + max_name_len * 0.008  # scale with name length
    label_pad = 10  # tight padding, alignment via figure margin

    # Set up single-bit signal lines (bus signals drawn per-frame)
    lines = {}
    for i, name in enumerate(signal_names):
        ax = axes[i]
        ax.set_facecolor('white')
        color = SIGNAL_COLORS.get(name, DEFAULT_COLOR)

        if not is_bus[name]:
            ax.set_ylim(-0.15, 1.35)
            ax.set_yticks([0, 1])
            ax.set_yticklabels(['0', '1'], fontsize=8, color='#616161')
            line, = ax.step([], [], where='post', color=color,
                            linewidth=2.0, solid_capstyle='butt')
            lines[name] = line
        else:
            ax.set_yticks([])

        ax.set_ylabel(name, fontsize=10, rotation=0,
                      labelpad=label_pad, va='center', ha='right',
                      fontweight='bold', color='#424242')
        ax.set_xlim(t_min, t_max)
        ax.grid(True, alpha=0.2, linestyle='-', color='#9E9E9E')
        ax.tick_params(labelsize=8, colors='#616161')
        ax.spines['top'].set_visible(False)
        ax.spines['right'].set_visible(False)
        ax.spines['left'].set_color('#BDBDBD')
        ax.spines['bottom'].set_color('#BDBDBD')

    axes[-1].set_xlabel('Time ({})'.format(time_unit),
                        fontsize=10, color='#424242')
    plt.tight_layout(rect=[left_margin, 0.02, 1, 0.95])
    fig.align_ylabels(axes)

    # Render one frame per data point at fixed FPS.
    # Draw duration scales with data size; rate of reveal is the same
    # across all GIFs. Still freezes for FREEZE_SECONDS at the end.
    n_points = len(times)
    frame_duration = 1000 // FPS  # fixed ms per frame (e.g. 50ms at 20fps)

    fig.canvas.draw()

    rgb_frames = []
    for frame_idx in range(n_points):
        n_show = frame_idx + 1

        for j, name in enumerate(signal_names):
            ax = axes[j]
            color = SIGNAL_COLORS.get(name, DEFAULT_COLOR)

            if is_bus[name]:
                fill_color = BUS_FILL_COLORS.get(name, DEFAULT_BUS_FILL)
                draw_bus_waveform(ax, times, values[name], n_show,
                                 color, fill_color)
            else:
                lines[name].set_data(times[:n_show],
                                     values[name][:n_show])

        fig.canvas.draw()
        w, h = fig.canvas.get_width_height()
        buf = fig.canvas.tostring_rgb()
        img = Image.frombytes('RGB', (w, h), buf)
        rgb_frames.append(img)

    plt.close(fig)

    # Build GIF with single global palette
    ref_palette = rgb_frames[-1].quantize(colors=256, dither=0)
    q_frames = [fr.quantize(palette=ref_palette, dither=0)
                for fr in rgb_frames]

    durations = [frame_duration] * len(q_frames)
    durations[-1] = FREEZE_SECONDS * 1000

    q_frames[0].save(gif_path, save_all=True,
                     append_images=q_frames[1:],
                     duration=durations, loop=0)

    print("  Generated: {}".format(gif_path))


# Main
def main():
    if len(sys.argv) < 3:
        print("Usage: python3 generate_gifs.py <vcd_dir> <gif_dir>")
        sys.exit(1)

    vcd_dir = sys.argv[1]
    gif_dir = sys.argv[2]

    if not os.path.isdir(vcd_dir):
        print("ERROR: VCD directory not found: {}".format(vcd_dir))
        sys.exit(1)

    if not os.path.isdir(gif_dir):
        os.makedirs(gif_dir)

    vcd_files = sorted(f for f in os.listdir(vcd_dir) if f.endswith('.vcd'))

    if not vcd_files:
        print("No VCD files found in {}".format(vcd_dir))
        sys.exit(0)

    print("Found {} VCD files in {}".format(len(vcd_files), vcd_dir))
    print("Output directory: {}\n".format(gif_dir))

    for vcd_file in vcd_files:
        vcd_path = os.path.join(vcd_dir, vcd_file)
        gif_name = vcd_file.replace('.vcd', '.gif')
        gif_path = os.path.join(gif_dir, gif_name)
        title = format_title(vcd_file)

        print("Processing: {} -> {}".format(vcd_file, gif_name))
        try:
            generate_gif(vcd_path, gif_path, title=title)
        except Exception as e:
            print("  ERROR: {}".format(e))
            import traceback
            traceback.print_exc()

    print("\nDone! Generated GIFs in: {}".format(gif_dir))


if __name__ == '__main__':
    main()
