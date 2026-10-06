"""Fluid motion for the R6 clips: a few strong key poses, smooth curves through them, follow-through
from springs, and feet that stay planted by sliding the legs (R6's way of faking knees).

    m = Motion("wave", 2.4)
    m.key(0.0, root=(0, 0, 0), rShoulder=(0, 0, 2))
    m.key(0.5, "out", rShoulder=J((150, 0, 20), (0, 0.15, -0.1)))
    m.follow("neck", 3.0, 0.75)          # the head drags a little behind the body
    m.follow(("rShoulder", "lShoulder"), 2.6, 0.7)
    m.plant()                            # both soles stay where they stand
    m.build()                            # bakes it into an animlib clip, 30 keys a second

Keys use the game's joint convention (animlib.py). A joint value is angles, or animlib.J(angles,
slide) for a part that also slides (studs, in its parent's frame: x right, y up, z backwards).

Curves: "smooth" keys flow through each other on a monotone cubic (no overshoot, no stop at every
key); "sine", "in", "out", "linear", "snap" and "hold" shape just the move into that key.
Springs (follow) give overlapping action: a joint chases its keyed value with a natural frequency
(Hz) and a damping ratio (1 = no overshoot; 0.6 = a small, soft settle).
"""

import math

import numpy as np

import posekit
from animlib import J, clip, split

JOINTS = ("root", "neck", "rShoulder", "lShoulder", "rHip", "lHip")
LEGS = {"rHip": 1, "lHip": -1}
SOLE_X = 0.5  # the middle of a sole, from the body's middle line


def _ease(name, u):
    u = max(0.0, min(1.0, u))
    if name == "linear":
        return u
    if name == "in":
        return u * u * u
    if name == "out":
        return 1 - (1 - u) ** 3
    if name == "snap":
        return 1 - 2 ** (-10 * u) if u < 1 else 1.0
    if name == "hold":
        return 0.0 if u < 1 else 1.0
    return 0.5 - 0.5 * math.cos(math.pi * u)  # sine


def _vec(value):
    angles, pos = split(value)
    return np.array([*angles, *(pos or (0.0, 0.0, 0.0))], float)


class Channel:
    """Keys of one joint (or the body offset) and their curve."""

    def __init__(self, length, loop):
        self.keys = []  # (t, vector, ease)
        self.length = length
        self.loop = loop

    def add(self, t, vec, ease):
        self.keys = [k for k in self.keys if abs(k[0] - t) > 1e-9]
        self.keys.append((t, vec, ease))
        self.keys.sort(key=lambda k: k[0])

    def _points(self):
        keys = list(self.keys)
        if self.loop:
            first = keys[0]
            if keys[-1][0] < self.length - 1e-6:
                keys.append((self.length, first[1], first[2]))
            # one key either side of the loop, so the curve is smooth across the seam
            before = (keys[-2][0] - self.length, keys[-2][1], keys[-2][2])
            after = (keys[1][0] + self.length, keys[1][1], keys[1][2])
            return [before] + keys + [after], 1
        return keys, 0

    def value(self, t):
        if self.loop and self.length > 0:
            t = t % self.length
        pts, lead = self._points()
        real = pts[lead : len(pts) - lead] if lead else pts
        if t <= real[0][0]:
            return real[0][1].copy()
        if t >= real[-1][0]:
            return real[-1][1].copy()
        i = max(k for k in range(len(pts) - 1) if pts[k][0] <= t)
        t0, v0, _ = pts[i]
        t1, v1, ease = pts[i + 1]
        span = t1 - t0
        u = (t - t0) / span if span > 0 else 1.0
        if ease != "smooth":
            return v0 + (v1 - v0) * _ease(ease, u)
        # monotone cubic Hermite (Fritsch-Carlson): flows through keys, never overshoots them
        def slope(a, b):
            ta, va, _ = pts[a]
            tb, vb, _ = pts[b]
            return (vb - va) / (tb - ta) if tb > ta else np.zeros_like(va)

        d = slope(i, i + 1)
        m0 = (slope(i - 1, i) + d) / 2 if i > 0 else d
        m1 = (d + slope(i + 1, i + 2)) / 2 if i + 2 < len(pts) else d
        prev = slope(i - 1, i) if i > 0 else d
        nxt = slope(i + 1, i + 2) if i + 2 < len(pts) else d
        m0 = np.where(np.sign(prev) * np.sign(d) <= 0, 0.0, m0)
        m1 = np.where(np.sign(nxt) * np.sign(d) <= 0, 0.0, m1)
        m0 = np.where(d == 0, 0.0, np.clip(m0, -3 * np.abs(d), 3 * np.abs(d)))
        m1 = np.where(d == 0, 0.0, np.clip(m1, -3 * np.abs(d), 3 * np.abs(d)))
        h00 = 2 * u**3 - 3 * u**2 + 1
        h10 = u**3 - 2 * u**2 + u
        h01 = -2 * u**3 + 3 * u**2
        h11 = u**3 - u**2
        return h00 * v0 + h10 * span * m0 + h01 * v1 + h11 * span * m1


class Motion:
    def __init__(self, name, length, loop=False, note="", floor=False, rate=30):
        self.name = name
        self.length = float(length)
        self.loop = loop
        self.note = note
        self.floor = floor
        self.rate = rate
        self.channels = {}
        self.offset = Channel(self.length, loop)
        self.springs = {}
        self.plants = []  # (t0, t1, stance, forward, tilt)
        self.extras = []  # f(t, pose, offset) -> None, edits in place
        self.stride = None

    def key(self, t, ease="smooth", offset=None, floor=False, **joints):
        """A key pose. floor=True works out the body's height so it rests on the floor (offset gives
        only x and z then)."""
        for joint, value in joints.items():
            if joint not in JOINTS:
                raise ValueError(f"{self.name}: unknown joint {joint}")
            self.channels.setdefault(joint, Channel(self.length, self.loop)).add(t, _vec(value), ease)
        if floor:
            ox, _, oz = offset if offset is not None else (0.0, 0.0, 0.0)
            pose = {j: J(v[:3], v[3:]) for j, v in ((j, _vec(val)) for j, val in joints.items())}
            offset = posekit.on_floor(pose, (ox, 0.0, oz))
        if offset is not None:
            self.offset.add(t, np.array(offset, float), ease)
        return self

    def follow(self, joints, freq=2.5, damping=0.75):
        """Overlapping action: these joints chase their keyed values like a soft spring."""
        for joint in (joints,) if isinstance(joints, str) else joints:
            self.springs[joint] = (freq, damping)
        return self

    def plant(self, t0=None, t1=None, stance=0.0, forward=(0.0, 0.0), tilt=(0.0, 0.0)):
        """Both soles stay put between t0 and t1 (the whole clip by default), however the body moves:
        the legs keep upright (tilted by `tilt` degrees forward, right then left) and slide up into
        the hips or down out of them as the body sinks and rises."""
        self.plants.append((t0 if t0 is not None else -1e9, t1 if t1 is not None else 1e9, stance, forward, tilt))
        return self

    def extra(self, fn):
        self.extras.append(fn)
        return self

    # --- evaluation --------------------------------------------------------------------------------

    def _primary(self, t):
        pose = {j: ch.value(t) for j, ch in self.channels.items()}
        off = self.offset.value(t) if self.offset.keys else np.zeros(3)
        return pose, off

    def _sprung(self, times):
        """The keyed curves run through the springs (a few loops first, so a loop starts settled)."""
        dt = 1.0 / 240
        warm = 3 * self.length if self.loop else 0.0
        state = {}
        out = {j: [] for j in self.springs if j in self.channels}
        t = -warm
        targets = {j: self.channels[j].value(t) for j in self.springs if j in self.channels}
        for j, v in targets.items():
            state[j] = [v.copy(), np.zeros_like(v)]
        k = 0
        while k < len(times):
            if t >= times[k] - 1e-9:
                for j in state:
                    out[j].append(state[j][0].copy())
                k += 1
                continue
            for j in state:
                freq, zeta = self.springs[j]
                w = 2 * math.pi * freq
                target = self.channels[j].value(t)
                x, v = state[j]
                a = w * w * (target - x) - 2 * zeta * w * v
                v = v + a * dt
                x = x + v * dt
                state[j] = [x, v]
            t += dt
        return out

    def _planted(self, t):
        for t0, t1, stance, forward, tilt in self.plants:
            if t0 - 1e-9 <= t <= t1 + 1e-9:
                return stance, forward, tilt
        return None

    def sample(self, t, sprung=None, index=None):
        pose, off = self._primary(t)
        if sprung is not None:
            for j, values in sprung.items():
                pose[j] = values[index]
        plant = self._planted(t)
        if plant is not None:
            stance, forward, tilt = plant
            root = tuple(pose["root"][:3]) if "root" in pose else (0.0, 0.0, 0.0)
            for key, side in LEGS.items():
                ahead = forward[0] if side > 0 else forward[1]
                lean = tilt[0] if side > 0 else tilt[1]
                foot = (side * (SOLE_X + stance), 0.0, -ahead)
                angles, slide = posekit.planted_slide(side, foot, root, tuple(off), pitch=lean)
                pose[key] = np.array([*angles, *slide])
        for fn in self.extras:
            fn(t, pose, off)
        return pose, off

    def build(self):
        c = clip(self.name, self.length, loop=self.loop, note=self.note, floor=self.floor)
        c.stride = self.stride
        count = max(2, int(round(self.length * self.rate)))
        times = [self.length * i / count for i in range(count + (0 if self.loop else 1))]
        sprung = self._sprung(times) if self.springs else None
        for i, t in enumerate(times):
            pose, off = self.sample(t, sprung, i)
            joints = {j: J(v[:3], v[3:]) if np.any(np.abs(v[3:]) > 1e-4) else tuple(v[:3]) for j, v in pose.items()}
            c.pose(t, "linear", offset=tuple(off) if (self.offset.keys or self.plants) else None, **joints)
        return c


__all__ = ["Motion", "J"]
