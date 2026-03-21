"""
Interactive Pretty Graph Goes BRR

Usage in Jupyter Notebook:
    from bokeh.io import output_notebook
    output_notebook()

    from plot_framework import iplot, isweep, ioverlay, isweep_overlay

    iplot(x, y, ...)
    isweep({label: (x, y)}, ...)                              # 1 slider
    isweep(nested_dict, ...)                                   # N sliders
    ioverlay({label: (x, y)}, ...)                             # legend toggle
    isweep_overlay({label: {trace: (x, y)}}, ...)              # 1 slider + legend
    isweep_overlay(deep_nested_dict_with_trace_leaves, ...)    # N sliders + legend

GitHub Rendering:
    Plots are saved as static PNG images in notebook outputs so GitHub can
    display them. When opened in VSCode or Colab the interactive Bokeh plot
    is also shown below the static preview.
"""


import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from IPython.display import display as _ipy_display

from bokeh.plotting import figure, show
from bokeh.models import (
    ColumnDataSource, CustomJS, Slider,
    HoverTool, CrosshairTool, Div,
)
from bokeh.layouts import column


COLORS = [
    "#1f77b4", "#ff7f0e", "#2ca02c", "#d62728",
    "#9467bd", "#8c564b", "#e377c2", "#7f7f7f",
    "#bcbd22", "#17becf",
]

# Matplotlib equivalents for static rendering
_MPL_COLORS = COLORS  # hex strings work for both


# ---------------------------------------------------------------------------
# Environment detection
# ---------------------------------------------------------------------------

def _is_live_kernel():
    """True when running inside an actual Jupyter kernel (VSCode, Colab, …)."""
    try:
        from IPython import get_ipython
        shell = get_ipython()
        return shell is not None and hasattr(shell, "kernel")
    except Exception:
        return False


# ---------------------------------------------------------------------------
# Matplotlib static helpers
# ---------------------------------------------------------------------------

def _mpl_figure(title, xlabel, ylabel, width, height, x_log=False, y_log=False):
    fig, ax = plt.subplots(figsize=(width / 100, height / 100), dpi=100)
    ax.set_title(title, fontsize=14)
    ax.set_xlabel(xlabel, fontsize=12)
    ax.set_ylabel(ylabel, fontsize=12)
    ax.grid(alpha=0.3)
    if x_log:
        ax.set_xscale("log")
    if y_log:
        ax.set_yscale("log")
    return fig, ax


def _mpl_add_trace(ax, x, y, kind, color, label, lw=2, size=20):
    kind = kind.lower().strip()
    if kind == "line":
        ax.plot(x, y, color=color, linewidth=lw, label=label)
    elif kind == "scatter":
        ax.scatter(x, y, color=color, s=size, label=label)
    elif kind == "line+scatter":
        ax.plot(x, y, color=color, linewidth=lw, label=label)
        ax.scatter(x, y, color=color, s=size)
    elif kind == "step":
        ax.step(x, y, color=color, linewidth=lw, where="post", label=label)
    elif kind == "area":
        ax.plot(x, y, color=color, linewidth=lw, label=label)
        ax.fill_between(x, 0, y, color=color, alpha=0.2)
    elif kind == "bar":
        ax.bar(x, y, color=color, alpha=0.7, width=0.7, label=label)
    elif kind in ("histogram", "hist"):
        ax.hist(y, bins="auto", color=color, alpha=0.65,
                edgecolor="white", label=label)
    elif kind in ("bell", "bell curve", "kde"):
        from scipy.stats import gaussian_kde
        samples = np.asarray(y, dtype=float)
        kde = gaussian_kde(samples)
        xs = np.linspace(samples.min() - 3 * samples.std(),
                         samples.max() + 3 * samples.std(), 500)
        ys = kde(xs)
        ax.plot(xs, ys, color=color, linewidth=lw, label=label)
        ax.fill_between(xs, 0, ys, color=color, alpha=0.15)
    else:
        raise ValueError(
            f"Unknown kind '{kind}'. Choose from: line, scatter, "
            f"line+scatter, step, area, bar, histogram, bell/kde"
        )


def _mpl_style_legend(ax):
    handles, labels = ax.get_legend_handles_labels()
    if handles:
        ax.legend(fontsize=10, framealpha=0.7, loc="best")


def _show_static(fig):
    """Display matplotlib figure as PNG (saved into notebook output for GitHub)."""
    _ipy_display(fig)
    plt.close(fig)


# ---------------------------------------------------------------------------
# Bokeh helpers (unchanged from original)
# ---------------------------------------------------------------------------

def _make_figure(title, xlabel, ylabel, width, height,
                 x_axis_type="linear", y_axis_type="linear"):
    hover = HoverTool(tooltips=[("x", "$x{0.000}"), ("y", "$y{0.000}")])
    crosshair = CrosshairTool()
    p = figure(
        title=title,
        x_axis_label=xlabel,
        y_axis_label=ylabel,
        width=width,
        height=height,
        x_axis_type=x_axis_type,
        y_axis_type=y_axis_type,
        tools=[hover, crosshair, "box_zoom", "reset", "save", "pan", "wheel_zoom"],
        active_drag=None,
        active_scroll=None,
    )
    p.title.text_font_size = "14px"
    p.xaxis.axis_label_text_font_size = "12px"
    p.yaxis.axis_label_text_font_size = "12px"
    p.grid.grid_line_alpha = 0.3
    return p


def _add_trace(p, source, kind, color, label, line_width=2, size=6):
    kind = kind.lower().strip()
    if kind == "line":
        return [p.line("x", "y", source=source, color=color,
                        line_width=line_width, legend_label=label)]
    elif kind == "scatter":
        return [p.scatter("x", "y", source=source, color=color,
                           size=size, legend_label=label)]
    elif kind == "line+scatter":
        r1 = p.line("x", "y", source=source, color=color,
                    line_width=line_width, legend_label=label)
        r2 = p.scatter("x", "y", source=source, color=color, size=size)
        return [r1, r2]
    elif kind == "step":
        return [p.step("x", "y", source=source, color=color,
                        line_width=line_width, mode="after",
                        legend_label=label)]
    elif kind == "area":
        r1 = p.line("x", "y", source=source, color=color,
                    line_width=line_width, legend_label=label)
        r2 = p.varea(x="x", y1=0, y2="y", source=source,
                     color=color, alpha=0.2)
        return [r1, r2]
    elif kind == "bar":
        return [p.vbar(x="x", top="y", source=source, color=color,
                        width=0.7, alpha=0.7, legend_label=label)]
    elif kind in ("histogram", "hist"):
        y_data = np.array(source.data["y"])
        counts, edges = np.histogram(y_data, bins="auto")
        hist_source = ColumnDataSource(data=dict(
            top=counts, left=edges[:-1], right=edges[1:],
        ))
        return [p.quad(top="top", bottom=0, left="left", right="right",
                        source=hist_source, color=color, alpha=0.65,
                        line_color="white", legend_label=label)]
    elif kind in ("bell", "bell curve", "kde"):
        from scipy.stats import gaussian_kde
        y_data = np.array(source.data["y"])
        kde = gaussian_kde(y_data)
        xs = np.linspace(y_data.min() - 3 * y_data.std(),
                         y_data.max() + 3 * y_data.std(), 500)
        ys = kde(xs)
        kde_source = ColumnDataSource(data=dict(x=xs, y=ys))
        r1 = p.line("x", "y", source=kde_source, color=color,
                    line_width=line_width, legend_label=label)
        r2 = p.varea(x="x", y1=0, y2="y", source=kde_source,
                     color=color, alpha=0.15)
        return [r1, r2]
    else:
        raise ValueError(
            f"Unknown kind '{kind}'. Choose from: line, scatter, "
            f"line+scatter, step, area, bar, histogram, bell/kde"
        )


def _style_legend(p, location="top_right"):
    if p.legend:
        p.legend.click_policy = "hide"
        p.legend.location = location
        p.legend.label_text_font_size = "10px"
        p.legend.background_fill_alpha = 0.7
        p.legend.border_line_alpha = 0.3


def _is_xy_tuple(v):
    """Check if v looks like an (x, y) data pair."""
    return (isinstance(v, (tuple, list))
            and len(v) == 2
            and not isinstance(v[0], str))


def _parse_sweep_tree(tree):
    """
    Recursively walk a nested dict and return:
        levels  : list of lists-of-labels, one per nesting level (= slider)
        flat    : list of leaf values in row-major order

    Leaf values are whatever sits at the bottom of the nesting — either
    (x, y) tuples (for isweep) or dicts of {trace: (x, y)} (for isweep_overlay).
    """
    # Base case: value is a leaf (x, y) tuple
    first_val = next(iter(tree.values()))
    if _is_xy_tuple(first_val):
        labels = list(tree.keys())
        return [labels], list(tree.values())

    # Recursive case: this level is a sweep dimension
    labels = list(tree.keys())
    sub_levels = None
    flat = []
    for key in labels:
        child_levels, child_flat = _parse_sweep_tree(tree[key])
        if sub_levels is None:
            sub_levels = child_levels
        flat.extend(child_flat)
    return [labels] + sub_levels, flat


def _parse_sweep_overlay_tree(tree):
    """
    Like _parse_sweep_tree but the leaf is a dict {trace_label: (x,y)}.
    Returns:
        levels      : list of lists-of-labels (one per slider)
        trace_names : list of trace labels (consistent across all leaves)
        flat        : list of dicts {trace: (x,y)} in row-major order
    """
    first_val = next(iter(tree.values()))

    # Check if this level is the overlay-leaf level:
    # it's a dict whose values are all (x,y) tuples
    if isinstance(first_val, dict):
        inner_first = next(iter(first_val.values()))
        if _is_xy_tuple(inner_first):
            labels = list(tree.keys())
            return [labels], list(first_val.keys()), list(tree.values())

    # Otherwise recurse
    labels = list(tree.keys())
    sub_levels = None
    trace_names = None
    flat = []
    for key in labels:
        child_levels, child_traces, child_flat = _parse_sweep_overlay_tree(tree[key])
        if sub_levels is None:
            sub_levels = child_levels
            trace_names = child_traces
        flat.extend(child_flat)
    return [labels] + sub_levels, trace_names, flat


def _flat_index(indices, dims):
    """Row-major flat index from a list of per-dimension indices."""
    idx = 0
    for i, d in zip(indices, dims):
        idx = idx * d + i
    return idx


'''
PUBLIC FUNCTIONS TO USE
'''

def iplot(
    x, y, *,
    title="", xlabel="x", ylabel="y",
    kind="line", color=None,
    width=800, height=450,
    x_log=False, y_log=False,
):
    """Plot a single dataset."""
    x, y = np.asarray(x, dtype=float), np.asarray(y, dtype=float)

    # Static matplotlib output — always shown; GitHub renders this PNG
    fig, ax = _mpl_figure(title, xlabel, ylabel, width, height, x_log, y_log)
    _mpl_add_trace(ax, x, y, kind, color or COLORS[0], title or "data")
    _show_static(fig)

    # Interactive Bokeh — only rendered in live kernels (VSCode / Colab)
    if _is_live_kernel():
        source = ColumnDataSource(data=dict(x=x, y=y))
        p = _make_figure(
            title, xlabel, ylabel, width, height,
            x_axis_type="log" if x_log else "linear",
            y_axis_type="log" if y_log else "linear",
        )
        _add_trace(p, source, kind, color or COLORS[0], label=title or "data")
        if p.legend:
            p.legend.visible = False
        show(p)


def ioverlay(
    datasets, *,
    title="", xlabel="x", ylabel="y",
    kind="line", width=800, height=450,
    x_log=False, y_log=False,
):
    """Overlay multiple datasets. Click legend to hide/show."""

    # Static matplotlib output
    fig, ax = _mpl_figure(title, xlabel, ylabel, width, height, x_log, y_log)
    for i, (label, (x, y)) in enumerate(datasets.items()):
        _mpl_add_trace(ax, np.asarray(x, dtype=float), np.asarray(y, dtype=float),
                       kind, COLORS[i % len(COLORS)], label)
    _mpl_style_legend(ax)
    _show_static(fig)

    # Interactive Bokeh
    if _is_live_kernel():
        p = _make_figure(
            title, xlabel, ylabel, width, height,
            x_axis_type="log" if x_log else "linear",
            y_axis_type="log" if y_log else "linear",
        )
        for i, (label, (x, y)) in enumerate(datasets.items()):
            source = ColumnDataSource(
                data=dict(x=np.asarray(x, dtype=float),
                          y=np.asarray(y, dtype=float))
            )
            _add_trace(p, source, kind, COLORS[i % len(COLORS)], label=label)
        _style_legend(p)
        show(p)


def isweep(
    datasets, *,
    title="", xlabel="x", ylabel="y",
    kind="line", width=800, height=450,
    x_log=False, y_log=False,
):
    """
    N-dimensional sweep with one slider per nesting level.

    Parameters
    ----------
    datasets : nested dict
        Any depth of {label: ...} nesting. Leaves are (x, y) tuples.
        1 level  → 1 slider.   2 levels → 2 sliders.   N levels → N sliders.

    Examples
    --------
    # 1-slider
    isweep({"a": (x, y), "b": (x, y)})

    # 2-slider
    isweep({"T=25": {"VDD=0.9": (x,y), "VDD=1.1": (x,y)},
            "T=85": {"VDD=0.9": (x,y), "VDD=1.1": (x,y)}})
    """
    levels, flat_data = _parse_sweep_tree(datasets)
    dims = [len(lvl) for lvl in levels]

    # Pre-process KDE / histogram data for Bokeh sweep
    render_kind = kind
    processed_flat = flat_data
    if kind in ("bell", "kde"):
        from scipy.stats import gaussian_kde
        processed = []
        for _, y_raw in flat_data:
            samples = np.asarray(y_raw, dtype=float)
            kde_fn = gaussian_kde(samples)
            xs = np.linspace(samples.min() - 3 * samples.std(),
                             samples.max() + 3 * samples.std(), 500)
            ys = kde_fn(xs)
            processed.append((xs, ys))
        processed_flat = processed
        render_kind = "area"
    elif kind in ("histogram", "hist"):
        processed = []
        for _, y_raw in flat_data:
            samples = np.asarray(y_raw, dtype=float)
            counts, edges = np.histogram(samples, bins="auto")
            centers = (edges[:-1] + edges[1:]) / 2
            processed.append((centers, counts))
        processed_flat = processed
        render_kind = "bar"

    # --- Static matplotlib: overlay all sweep datasets ---
    fig, ax = _mpl_figure(title, xlabel, ylabel, width, height, x_log, y_log)
    flat_labels = [
        "  ·  ".join(lvl[i] for lvl, i in
                     zip(levels, _flat_idx_to_indices(n, dims)))
        for n in range(len(flat_data))
    ]
    for n, (xy, label) in enumerate(zip(processed_flat, flat_labels)):
        x, y = xy
        color = COLORS[n % len(COLORS)]
        _mpl_add_trace(ax, np.asarray(x, dtype=float), np.asarray(y, dtype=float),
                       render_kind if render_kind != "area" else "line",
                       color, label)
    _mpl_style_legend(ax)
    # Add subtitle noting this is a static view of all sweep values
    ax.set_title(f"{title}\n(static: all sweep values overlaid)", fontsize=12)
    _show_static(fig)

    # --- Interactive Bokeh sweep ---
    if _is_live_kernel():
        all_sources = []
        for xy in processed_flat:
            x, y = xy
            all_sources.append(ColumnDataSource(
                data=dict(x=np.asarray(x, dtype=float),
                          y=np.asarray(y, dtype=float))
            ))

        first_x, first_y = processed_flat[0]
        active_source = ColumnDataSource(
            data=dict(x=np.asarray(first_x, dtype=float),
                      y=np.asarray(first_y, dtype=float))
        )

        p = _make_figure(
            title, xlabel, ylabel, width, height,
            x_axis_type="log" if x_log else "linear",
            y_axis_type="log" if y_log else "linear",
        )
        _add_trace(p, active_source, render_kind, COLORS[0],
                   label=levels[0][0] if levels else "data")
        if p.legend:
            p.legend.visible = False

        init_label = "  &middot;  ".join(lvl[0] for lvl in levels)
        label_div = Div(
            text=f"<b style='font-size:13px;'>{init_label}</b>",
            width=width,
            styles={"text-align": "center"},
        )

        n_dims = len(levels)
        sliders = []
        for d in range(n_dims):
            s = Slider(start=0, end=dims[d] - 1, value=0, step=1,
                       title="", show_value=False, width=width - 60)
            sliders.append(s)

        slider_idx_code = " ".join(
            f"indices.push(s{d}.value);" for d in range(n_dims)
        )
        js_code = f"""
            const indices = [];
            {slider_idx_code}
            let flat_idx = 0;
            for (let d = 0; d < dims.length; d++) {{
                flat_idx = flat_idx * dims[d] + indices[d];
            }}
            active.data = {{...all_sources[flat_idx].data}};
            active.change.emit();

            let parts = [];
            for (let d = 0; d < dims.length; d++) {{
                parts.push(levels[d][indices[d]]);
            }}
            label_div.text = "<b style='font-size:13px;'>" + parts.join("  &middot;  ") + "</b>";

            const color = colors[flat_idx % colors.length];
            for (const r of renderers) {{
                if (r.glyph && r.glyph.line_color !== undefined)
                    r.glyph.line_color = color;
                if (r.glyph && r.glyph.fill_color !== undefined)
                    r.glyph.fill_color = color;
            }}
        """

        cb_args = dict(
            active=active_source,
            all_sources=all_sources,
            levels=levels,
            dims=dims,
            label_div=label_div,
            renderers=p.renderers,
            colors=COLORS,
        )
        for d, s in enumerate(sliders):
            cb_args[f"s{d}"] = s

        for s in sliders:
            s.js_on_change("value", CustomJS(args=cb_args, code=js_code))

        layout = column(p, label_div, *sliders, sizing_mode="fixed")
        show(layout)


def isweep_overlay(
    sweep_groups, *,
    title="", xlabel="x", ylabel="y",
    kind="line", width=800, height=450,
    x_log=False, y_log=False,
):
    """
    N-dimensional sweep + overlaid traces with legend hide/show.

    Parameters
    ----------
    sweep_groups : nested dict
        Any depth of {label: ...} nesting. Innermost dict maps
        trace labels to (x, y) tuples.

    Examples
    --------
    # 1-slider + overlay
    isweep_overlay({
        "VDD=0.9": {"trace_a": (x,y), "trace_b": (x,y)},
        "VDD=1.1": {"trace_a": (x,y), "trace_b": (x,y)},
    })

    # 2-slider + overlay
    isweep_overlay({
        "T=25": {
            "VDD=0.9": {"trace_a": (x,y), "trace_b": (x,y)},
            "VDD=1.1": {"trace_a": (x,y), "trace_b": (x,y)},
        },
        "T=85": { ... },
    })
    """
    levels, trace_names, flat_data = _parse_sweep_overlay_tree(sweep_groups)
    dims = [len(lvl) for lvl in levels]
    n_traces = len(trace_names)

    # --- Static matplotlib: show first sweep position with all overlaid traces ---
    first_cell = flat_data[0]
    sweep_label = "  ·  ".join(lvl[0] for lvl in levels)
    fig, ax = _mpl_figure(title, xlabel, ylabel, width, height, x_log, y_log)
    for i, tname in enumerate(trace_names):
        x, y = first_cell[tname]
        _mpl_add_trace(ax, np.asarray(x, dtype=float), np.asarray(y, dtype=float),
                       kind, COLORS[i % len(COLORS)], tname)
    _mpl_style_legend(ax)
    ax.set_title(f"{title}\n(static: {sweep_label})", fontsize=12)
    _show_static(fig)

    # --- Interactive Bokeh ---
    if _is_live_kernel():
        active_sources = []
        for tname in trace_names:
            x, y = first_cell[tname]
            active_sources.append(ColumnDataSource(
                data=dict(x=np.asarray(x, dtype=float),
                          y=np.asarray(y, dtype=float))
            ))

        all_cells = []
        for cell_dict in flat_data:
            cell_srcs = []
            for tname in trace_names:
                x, y = cell_dict[tname]
                cell_srcs.append(ColumnDataSource(
                    data=dict(x=np.asarray(x, dtype=float),
                              y=np.asarray(y, dtype=float))
                ))
            all_cells.append(cell_srcs)

        p = _make_figure(
            title, xlabel, ylabel, width, height,
            x_axis_type="log" if x_log else "linear",
            y_axis_type="log" if y_log else "linear",
        )

        for i, tname in enumerate(trace_names):
            _add_trace(p, active_sources[i], kind,
                       COLORS[i % len(COLORS)], label=tname)

        _style_legend(p)

        init_label = "  &middot;  ".join(lvl[0] for lvl in levels)
        label_div = Div(
            text=f"<b style='font-size:13px;'>{init_label}</b>",
            width=width,
            styles={"text-align": "center"},
        )

        n_dims = len(levels)
        sliders = []
        for d in range(n_dims):
            s = Slider(start=0, end=dims[d] - 1, value=0, step=1,
                       title="", show_value=False, width=width - 60)
            sliders.append(s)

        slider_idx_code = " ".join(
            f"indices.push(s{d}.value);" for d in range(n_dims)
        )
        js_code = f"""
            const indices = [];
            {slider_idx_code}
            let flat_idx = 0;
            for (let d = 0; d < dims.length; d++) {{
                flat_idx = flat_idx * dims[d] + indices[d];
            }}
            const cell = all_cells[flat_idx];
            for (let t = 0; t < active_sources.length; t++) {{
                active_sources[t].data = {{...cell[t].data}};
                active_sources[t].change.emit();
            }}
            let parts = [];
            for (let d = 0; d < dims.length; d++) {{
                parts.push(levels[d][indices[d]]);
            }}
            label_div.text = "<b style='font-size:13px;'>" + parts.join("  &middot;  ") + "</b>";
        """

        cb_args = dict(
            active_sources=active_sources,
            all_cells=all_cells,
            levels=levels,
            dims=dims,
            label_div=label_div,
        )
        for d, s in enumerate(sliders):
            cb_args[f"s{d}"] = s

        for s in sliders:
            s.js_on_change("value", CustomJS(args=cb_args, code=js_code))

        layout = column(p, label_div, *sliders, sizing_mode="fixed")
        show(layout)


# ---------------------------------------------------------------------------
# Internal utility
# ---------------------------------------------------------------------------

def _flat_idx_to_indices(flat_idx, dims):
    """Convert a flat row-major index back to per-dimension indices."""
    indices = []
    for d in reversed(dims):
        indices.append(flat_idx % d)
        flat_idx //= d
    return list(reversed(indices))
