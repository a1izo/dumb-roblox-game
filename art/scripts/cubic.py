"""The curve the game plays a clip's keys on (src/shared/Anim/ClipPlayer.luau, sampleTrack and sampleOffset), and the
key thinning that keeps that curve on the sampled motion (2026-11-09, "not choppy and stiff").

The game used to draw a straight line between keys, and the export kept the fewest keys a straight line stays within
0.6 degrees of: every slow move became a polyline whose speed jumped at each key. Now each value (a quaternion's four
numbers, a slide's three, the body offset's three) runs on a monotone cubic through the keys (Fritsch-Carlson, as
motion.py's "smooth": no overshoot, a flat span stays flat, a snap lands on its frame), and the export keeps the fewest
keys that curve stays within tolerance of.

    values = evaluate(key_times, key_values, times, period=None, quat=False)
    keep = reduce(times, [(values, quat, tolerance), ...], period=None)

No Blender needed (numpy only): export_anims.py thins with it and rbxsim.py plays clips back with it."""

import numpy as np


def evaluate(key_times, key_values, times, period=None, quat=False):
    """The curve through the keys (times (n,), values (n, c)) at `times`; `period` (the clip's length) when the track
    loops (keys at 0 and at the length); `quat` normalises each result (a quaternion's four numbers)."""
    kt = np.asarray(key_times, float)
    kv = np.array(key_values, float)
    if kv.ndim == 1:
        kv = kv[:, None]
    ts = np.atleast_1d(np.asarray(times, float))
    n = len(kt)
    if n == 1:
        return np.repeat(kv[:1], len(ts), axis=0)
    if quat:
        for i in range(1, n):
            if np.dot(kv[i], kv[i - 1]) < 0:
                kv[i] = -kv[i]
    loops = period is not None and n > 2
    span = np.diff(kt)
    d = np.diff(kv, axis=0) / span[:, None]
    # the neighbour spans' slopes (the span before the first and after the last: round the loop, or none)
    if n > 2:
        before = np.vstack([np.zeros((1, kv.shape[1])), d[:-1]])
        after = np.vstack([d[1:], np.zeros((1, kv.shape[1]))])
    else:
        before = np.zeros_like(d)
        after = np.zeros_like(d)
    has_before = np.ones(n - 1, bool)
    has_after = np.ones(n - 1, bool)
    has_before[0] = False
    has_after[-1] = False
    if loops:
        prev = kv[n - 2] * (1.0 if not quat or np.dot(kv[n - 2], kv[0]) >= 0 else -1.0)
        before[0] = (kv[0] - prev) / (kt[0] - (kt[n - 2] - period))
        has_before[0] = True
        nxt = kv[1] * (1.0 if not quat or np.dot(kv[1], kv[n - 1]) >= 0 else -1.0)
        after[-1] = (nxt - kv[n - 1]) / ((kt[1] + period) - kt[n - 1])
        has_after[-1] = True
    m0 = np.where(has_before[:, None], np.where(before * d <= 0, 0.0, (before + d) * 0.5), d)
    m1 = np.where(has_after[:, None], np.where(after * d <= 0, 0.0, (d + after) * 0.5), d)
    cap = 3 * np.abs(d)
    m0 = np.where(d == 0, 0.0, np.clip(m0, -cap, cap))
    m1 = np.where(d == 0, 0.0, np.clip(m1, -cap, cap))

    seg = np.clip(np.searchsorted(kt, ts, side="right") - 1, 0, n - 2)
    u = np.clip((ts - kt[seg]) / span[seg], 0.0, 1.0)
    u2, u3 = u * u, u * u * u
    h00, h10, h01, h11 = 2 * u3 - 3 * u2 + 1, u3 - 2 * u2 + u, -2 * u3 + 3 * u2, u3 - u2
    sp = span[seg][:, None]
    out = (h00[:, None] * kv[seg] + (h10[:, None] * sp) * m0[seg] + h01[:, None] * kv[seg + 1]
           + (h11[:, None] * sp) * m1[seg])
    out[ts >= kt[-1]] = kv[-1]
    out[ts <= kt[0]] = kv[0]
    if quat:
        out /= np.linalg.norm(out, axis=1, keepdims=True)
    return out


def _error(curve, truth, quat):
    if quat:
        dots = np.clip(np.abs(np.sum(curve * truth, axis=1)), 0.0, 1.0)
        return 2 * np.arccos(dots)
    return np.linalg.norm(curve - truth, axis=1)


def reduce(times, series, period=None, keep=None):
    """The fewest sample indices whose curve keeps every series within its tolerance at every sample.
    series: [(values (m, c), quat, tolerance)], all sampled at `times` (m,). Greedy: starting from the ends (and any
    `keep`), each pass adds the worst sample of every span still out of tolerance."""
    ts = np.asarray(times, float)
    m = len(ts)
    chosen = {0, m - 1} | set(keep or ())
    arrays = [(np.array(v, float).reshape(m, -1), q, tol) for v, q, tol in series]
    for _ in range(400):
        idx = np.array(sorted(chosen))
        worst = np.zeros(m)
        for values, quat, tol in arrays:
            curve = evaluate(ts[idx], values[idx], ts, period if len(idx) > 2 else None, quat)
            worst = np.maximum(worst, _error(curve, values, quat) / tol)
        if worst.max() <= 1.0:
            break
        # the worst sample of each span between chosen keys that strays too far
        added = False
        for a, b in zip(idx[:-1], idx[1:]):
            if b - a < 2:
                continue
            k = a + 1 + int(np.argmax(worst[a + 1:b]))
            if worst[k] > 1.0:
                chosen.add(k)
                added = True
        if not added:
            break
    return sorted(chosen)


def sample(key_times, key_values, t, period=None, quat=False):
    """One value of the curve at t (rbxsim's playback)."""
    return evaluate(key_times, key_values, [t], period, quat)[0]


__all__ = ["evaluate", "reduce", "sample"]
