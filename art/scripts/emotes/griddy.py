"""Griddy (clips griddy + griddyWalk, item emote_griddy), rebuilt 2026-11-16 (the owner: "rework griddy to be more
accurate, bouncing on one leg, hands thrown up every 2 seconds"). The notes and the beats watched are in
art/refs/emotes/griddy.toml ("rebuild"). The first build (a motion capture of Justin Jefferson, heel taps on both
feet) is kept in emotes/griddy_mocap.py and is no longer imported.

One bar is 2.0 s: four hops, a hop every 0.5 s. The LEFT leg takes all the weight and bounces; the RIGHT foot is
lifted and kicked out in front, bent, and drawn back under at each landing. The bent arms swing across the body,
trading at each landing. On the fourth hop the body gathers low, arms swung back, then springs and throws BOTH
arms up and open, leaning back, held, and lets them fall into the swing.

`griddy` plays standing (time); `griddyWalk` is the same bar as a cycle the game plays by the ground covered
(LocomotionController): 4 hops of 4.5 studs, so at the stroll's pace of 9 studs a second it is the same two
seconds. Its right foot lands at phase 0 and 0.5 (where the game fires its Footfall), and its stance is the part
of a cycle the standing foot is down.
"""

import math

import numpy as np

import locomotion
import posekit
from animlib import J
from motion import Channel, Motion
from posekit import R, euler

BAR = 2.0
BEAT = 0.5
HOPS = 4
STAND = -1  # the left leg takes the weight
FREE = 1  # the right foot is the one lifted
STAND_KEY, FREE_KEY = "lHip", "rHip"
HOP_STRIDE = 4.5  # studs the body moves each hop (2 hops a second at the stroll's pace of 9)
HOP_STANCE = locomotion.TRAVEL / HOP_STRIDE  # the part of a hop the foot is on the ground
ARMS = ("rShoulder", "lShoulder")

# ---- the arms ----------------------------------------------------------------------------------------------
# Bent arms swung across the body (an arm slid forward and up reads as a bent elbow), back, and thrown up open.
R_ACROSS = J((66, -18, 14), (0.0, 0.12, -0.16))
L_ACROSS = J((62, 20, -14), (0.0, 0.12, -0.16))
R_BACK = J((-28, 0, 18))
L_BACK = J((-24, 0, -20))
R_MID = J((22, -6, 16), (0.0, 0.04, -0.06))
L_MID = J((20, 6, -16), (0.0, 0.04, -0.06))
R_LOW = J((-40, 0, 16))
L_LOW = J((-36, 0, -18))
R_UP = J((152, 0, 34), (0.0, 0.18, 0.0))
L_UP = J((144, 0, -40), (0.0, 0.2, 0.0))
R_UP2 = J((142, 0, 40), (0.0, 0.16, 0.0))
L_UP2 = J((150, 0, -32), (0.0, 0.18, 0.0))
R_DOWN = J((98, -10, 26), (0.0, 0.08, -0.1))
L_DOWN = J((92, 10, -28), (0.0, 0.08, -0.1))

# ---- the free foot (right): forward and drop below the hip, studs, by time in the bar ------------------------
FOOT = [
    (0.00, 1.75, 0.88),
    (0.14, 1.70, 0.90),
    (0.34, 0.72, 1.26),
    (0.50, 0.46, 1.34),
    (0.78, 1.30, 0.98),
    (1.00, 0.52, 1.32),
    (1.28, 1.30, 0.98),
    (1.50, 0.40, 1.36),
    (1.70, 0.40, 1.36),
    (1.92, 1.75, 0.88),
]


def _foot_channels():
    fwd, drop = Channel(BAR, True), Channel(BAR, True)
    for t, f, d in FOOT:
        fwd.add(t, np.array([f]), "smooth")
        drop.add(t, np.array([d]), "smooth")
    return fwd, drop


_FWD, _DROP = _foot_channels()


def free_leg(root, offset, t):
    """The right leg for time t in the bar: the sole aimed at a point in front of and below its hip, the leg
    sliding up into the hip as the knee folds. Returns J(angles, slide)."""
    side = FREE
    hip = posekit.hip_world(side, root, offset)
    point = hip + R(*root) @ np.array([side * 0.2, -float(_DROP.value(t)[0]), -float(_FWD.value(t)[0])])
    local = locomotion.edge(side, 0.0)
    angles, slide, _axial, _p, _r = locomotion.solve_leg(side, root, offset, 0.0, lambda _W: (point, local))
    return J(angles, slide)


# ---- the body: one Motion, the standing clip and the upper half of the cycle --------------------------------
motion = Motion("griddy", BAR, loop=True, note="Griddy: bouncing on one leg, the other foot kicked out, arms swinging, "
                "and every two seconds both arms thrown up and open.")


def _k(t, y, root, neck, r_arm, l_arm, x=-0.16, ease="smooth"):
    motion.key(t, ease, offset=(x, y, 0.0), root=root, neck=neck, rShoulder=r_arm, lShoulder=l_arm)


# hop 0 lands at t=0 with the arms still up from the throw
_k(0.00, -0.12, (8, -3, 3), (8, 0, 0), R_UP, L_UP, ease="snap")
_k(0.14, -0.20, (4, -4, 4), (4, 4, 0), R_UP2, L_UP2)
_k(0.30, 0.02, (-4, -2, 4), (-6, 8, 0), R_DOWN, L_DOWN)
_k(0.40, 0.18, (-8, 4, 3), (-6, 8, 0), R_MID, L_ACROSS)
# hop 1: the left arm across
_k(0.50, -0.10, (-10, 7, 4), (-6, 6, 0), R_BACK, L_ACROSS)
_k(0.62, -0.18, (-10, 7, 4), (-8, 4, 0), R_BACK, L_ACROSS)
_k(0.88, 0.20, (-6, 0, 3), (-4, -4, 0), R_MID, L_MID)
# hop 2: the right arm across
_k(1.00, -0.10, (-10, -7, 2), (-6, -6, 0), R_ACROSS, L_BACK)
_k(1.12, -0.18, (-10, -7, 2), (-8, -4, 0), R_ACROSS, L_BACK)
_k(1.36, 0.18, (-8, 0, 3), (-4, 4, 0), R_MID, L_MID)
# hop 3: gather low, arms swung back (the anticipation), spring and throw
_k(1.50, -0.18, (-14, 4, 5), (-8, 0, 0), R_LOW, L_LOW)
_k(1.64, -0.32, (-17, 6, 5), (-10, 0, 0), R_LOW, L_LOW)
_k(1.78, 0.02, (0, -2, 3), (2, 0, 0), J((66, 0, 26), (0, 0.08, -0.06)), J((60, 0, -30), (0, 0.08, -0.06)), ease="in")
_k(1.90, 0.34, (15, -3, 2), (16, 0, 0), R_UP, L_UP, ease="out")
motion.follow(ARMS, 3.4, 0.85)


def _legs(t, pose, off):
    """Both legs at time t of the standing clip: the left foot on the floor while the hop is down (rolling
    through the sole to push off), a hair in the air while it is up; the right foot aimed (free_leg)."""
    root = tuple(float(v) for v in pose["root"][:3])
    offset = tuple(float(v) for v in off)
    foot_y = max(0.0, offset[1] - 0.02)
    angles, slide = posekit.planted_slide(STAND, (STAND * 0.5, foot_y, 0.0), root, offset)
    pose[STAND_KEY] = np.array([*angles, *slide])
    j = free_leg(root, offset, t)
    pose[FREE_KEY] = np.array([*j["r"], *j["p"]])


motion.extra(_legs)
motion.build()


# ---- the cycle ---------------------------------------------------------------------------------------------
SAMPLES = 120
_TIMES = [BAR * i / SAMPLES for i in range(SAMPLES)]
_SPRUNG = motion._sprung(_TIMES)


def _table():
    rows = []
    for i, t in enumerate(_TIMES):
        pose, off = motion._primary(t)
        for joint, values in _SPRUNG.items():
            pose[joint] = values[i]
        root = tuple(float(v) for v in pose["root"][:3])
        neck_world = euler(R(*root) @ R(*[float(v) for v in pose["neck"][:3]]))
        rows.append(
            dict(
                root=root,
                neck_world=neck_world,
                offset=(float(off[0]), float(off[1]), float(off[2])),
                rShoulder=J(tuple(float(v) for v in pose["rShoulder"][:3]), tuple(float(v) for v in pose["rShoulder"][3:])),
                lShoulder=J(tuple(float(v) for v in pose["lShoulder"][:3]), tuple(float(v) for v in pose["lShoulder"][3:])),
            )
        )
    return rows


_ROWS = _table()


def griddy_upper(phase):
    return _ROWS[int(round(phase * SAMPLES)) % SAMPLES]


class _Hop(locomotion.Cycle):
    """Four hops on the left leg (the standing foot lands at phase 0, .25, .5, .75), the right foot held out."""

    def __init__(self):
        super().__init__("griddyWalk", BAR, HOP_STANCE, 0.3, upper=griddy_upper, samples=SAMPLES,
                         note="Griddy on the move: four hops on the left leg, the right foot kicked out, arms "
                              "swinging, then both arms thrown up and open.")
        self.stride = locomotion.TRAVEL / HOP_STANCE  # one hop's; the clip's own is four of them (build)
        self.hop = 0

    def lift_at(self, u):
        big = 1.45 if self.hop == HOPS - 1 else 1.0
        return big * super().lift_at(u)

    def _own(self, phase):
        h = int(math.floor(phase * HOPS + 1e-9)) % HOPS
        self.hop = h
        return (phase * HOPS) % 1

    def frame(self, phase, height=None, raised=(0.0, 0.0)):
        body = self.upper(phase)
        root = body["root"]
        ox, oy, oz = body["offset"]
        offset = (ox, oy if height is None else height, oz)
        joints = {"root": root}
        joints["neck"] = euler(R(*root).T @ R(*body["neck_world"]))
        joints["rShoulder"] = body["rShoulder"]
        joints["lShoulder"] = body["lShoulder"]
        own = self._own(phase)
        angles, slide, axial, _, _, planted = self.leg(STAND, own, root, offset, raised[1], fade=True)
        joints[STAND_KEY] = J(angles, slide)
        joints[FREE_KEY] = free_leg(root, offset, phase * BAR)
        gaps = []
        if planted:
            landing = 1 - locomotion.smoothstep(own / self.stance / 0.15)
            gaps.append(axial - locomotion.PLANTED_GAP - locomotion.LANDING_GAP * landing)
        return joints, offset, gaps

    def raises(self, phases, heights):
        n = len(phases)
        need = np.zeros(n)
        for i, phase in enumerate(phases):
            own = self._own(phase)
            if own >= self.stance:
                body = self.upper(phase)
                ox, _, oz = body["offset"]
                need[i] = self.needed_raise(STAND, own, body["root"], (ox, float(heights[i]), oz))
        up, down = np.maximum(need, 0.0), np.minimum(need, 0.0)
        widen = 2
        up = np.array([max(up[(i + d) % n] for d in range(-widen, widen + 1)) for i in range(n)])
        down = np.array([min(down[(i + d) % n] for d in range(-widen, widen + 1)) for i in range(n)])
        weights = [math.exp(-0.5 * (d / 1.5) ** 2) for d in range(-4, 5)]
        blur = np.zeros(n)
        for i in range(n):
            blur[i] = sum(w * (up[(i + d) % n] + down[(i + d) % n]) for w, d in zip(weights, range(-4, 5))) / sum(weights)
        return {1: np.zeros(n), -1: blur}

    def build(self):
        c = super().build()
        # the clip is the whole bar: four hops of ground covered, and the standing foot's stance is a quarter of it
        c.stride = HOPS * self.stride
        c.stance = self.stance / HOPS
        return c


# the right foot of the base class would be `phase`, the left `phase + .5`: both are replaced above, so the
# cycle's left (standing) leg is the one this class poses and `raised` for it is index 1.
_Hop().build()
