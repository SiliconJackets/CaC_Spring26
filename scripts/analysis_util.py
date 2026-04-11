import numpy as np


def find_switching_time(
    trace,
    t_start,
    t_end,
    vdd=1.8,
    edge="rising",
    occurrence=1
):
    """
    Find the time at which a signal crosses 50% VDD within an interval.

    Parameters
    ----------
    trace      : (x, y) tuple of numpy arrays (time, voltage)
    t_start    : start of search window (in ns)
    t_end      : end of search window (in ns)
    vdd        : supply voltage (threshold = vdd / 2)
    edge       : "rising" or "falling"
    occurrence : which crossing to return (1-based)

    Returns
    -------
    Crossing time in ns, or None if not found.
    """
    t, v = np.asarray(trace[0], dtype=float), np.asarray(trace[1], dtype=float)
    threshold = vdd / 2

    mask = (t >= t_start) & (t <= t_end)
    t_w = t[mask]
    v_w = v[mask]

    count = 0
    for i in range(len(t_w) - 1):
        if edge == "rising" and v_w[i] < threshold <= v_w[i + 1]:
            count += 1
        elif edge == "falling" and v_w[i] >= threshold > v_w[i + 1]:
            count += 1
        else:
            continue

        if count == occurrence:
            frac = (threshold - v_w[i]) / (v_w[i + 1] - v_w[i])
            return t_w[i] + frac * (t_w[i + 1] - t_w[i])

    return None


def get_sample(
    trace,
    t_start,
    t_end
):
    """
    Returns the sample of a given trace in the specified interval.

    Parameters
    ----------
    trace      : (x, y) tuple of numpy arrays (time, voltage)
    t_start    : start of sample window
    t_end      : end of sample window

    Returns
    -------
    A sample of the given trace
    """
    t, v = trace
    mask = (t >= t_start) & (t < t_end)
    t_w = t[mask]
    v_w = v[mask]

    return (t_w, v_w)


def apply_time_shift(
    trace,
    time_shift
):
    """
    Returns the trace but with a time phase applied to the time data.

    Parameters
    ----------
    trace       : (x, y) tuple of numpy arrays (time, voltage)
    time_shift  : Amount to shift the time by

    Returns
    -------
    A shifted trace
    """
    t, v = trace
    t_shifted = t + time_shift

    return (t_shifted, v)