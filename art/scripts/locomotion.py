"""The movement set (rebuilt 2026-10-14): what every body plays standing, walking, running, in the air
and landing. Style: noir restraint, sharpened. Grounded weight, little bounce, compact arms, a steady
head and clean silhouettes that read from the game's camera (behind, up to 18 studs off); the anime
flair is kept for the air and the landings. Nothing here depends on a player's role.

How an R6 leg walks here. The leg is one rigid box hanging from the hip, so a planted leg rolls over
its bottom edges like a foot: it lands on the heel edge, rolls flat, and pushes off from the toe edge
(the other way round going backwards), and the edge on the ground never moves. A leg reaches its edge
by sliding along its own length only (R6's bent knee); when that would pull it out of the hip (a gap
under the torso) the body sinks instead, which is also where a body is lowest in life: just after a
foot lands. A swinging foot travels in the world from where it left the ground to where it lands
next, starting and ending at rest, so it lifts before it moves (no scuffed toes) and comes down at
ground speed (no skating heels).

Every cycle starts with the right foot landing (phase 0; the left lands at 0.5) and moves the body
the same distance over a planted foot (TRAVEL), so the game can blend walk and run, and the four
directions, at the same phase without sliding feet. Each clip exports its stride (studs per cycle)
and stance (the part of the cycle a foot is down).

Angles follow the game's joint convention (animlib.py); positions are studs in the character's frame
(x right, y up, z back: forward is -z), the floor at y = 0.
"""

import math

import numpy as np

import posekit
from animlib import J, clip
from motion import Motion
from posekit import LEG_LENGTH, R, euler, hip_world

HALF_FOOT = 0.5  # the heel and toe edges of a leg's bottom face, from its middle (studs)
TRAVEL = 2.4  # studs the body moves over each planted foot, in every cycle (a rigid 2-stud leg reaches no more
# without the body dropping into a crouch: a short, quick contact and a long flight read as running)
MAX_GAP = 0.012  # studs a swinging leg may slide out of its hip (more shows as a gap under the torso)
PLANTED_GAP = 0.04  # a planted leg (it moves with the body over it, so a hair more does not show)
LANDING_GAP = 0.05  # and a little more for the frames a heel lands at the edge of its reach
MAX_SINK = 0.55  # studs a leg may slide up into the torso (a bent knee)
UP = np.array([0.0, 1.0, 0.0])


def smoothstep(u):
    u = min(1.0, max(0.0, u))
    return u * u * (3 - 2 * u)


def smootherstep(u):
    u = min(1.0, max(0.0, u))
    return u * u * u * (u * (6 * u - 15) + 10)


def cyc(phase, lag=0.0):
    """cos over a cycle, delayed by `lag` (a fraction of it)."""
    return math.cos(2 * math.pi * (phase - lag))


def twice(phase, lag=0.0):
    """cos twice a cycle (once per step)."""
    return math.cos(4 * math.pi * (phase - lag))


# Legs ------------------------------------------------------------------------------------------------


def leg_world(yaw, pitch, roll=0.0):
    """A leg's turn in the character's frame: pointed `yaw` degrees round (its toes that way), then swung
    by `pitch` (forward +) and `roll` (out +, right leg) about its own axes."""
    return posekit.ry(yaw) @ posekit.rx(pitch) @ posekit.rz(roll)


def edge(side, z):
    """A point on the bottom of a leg, relative to its hip pivot, in the leg's frame (z +0.5: the heel
    edge, -0.5: the toe edge, 0: the middle of the sole)."""
    return np.array([-side * 0.5, -LEG_LENGTH, z])


def _place(side, root, offset, W, point, local):
    rot = R(*root)
    pivot = np.asarray(point, float) - W @ local
    slide = pivot - hip_world(side, root, offset)
    return euler(rot.T @ W), rot.T @ slide, slide


def solve_leg(side, root, offset, yaw, target, guess=(0.0, 0.0)):
    """The hip angles and slide that put a leg-local point on a world point, the leg sliding only along
    its own length. target(W) -> (world point, leg-local point) for the leg turned W. Returns (angles,
    slide in the torso's frame, axial slide: + out of the hip, - up into it, pitch, roll)."""
    pitch, roll = guess

    def residual(p, r):
        W = leg_world(yaw, p, r)
        point, local = target(W)
        _, _, s = _place(side, root, offset, W, point, local)
        return np.array([s @ (W @ np.array([0.0, 0.0, 1.0])), s @ (W @ np.array([1.0, 0.0, 0.0]))])

    for _ in range(30):
        f = residual(pitch, roll)
        if np.max(np.abs(f)) < 1e-6:
            break
        h = 0.02
        jac = np.column_stack(((residual(pitch + h, roll) - f) / h, (residual(pitch, roll + h) - f) / h))
        try:
            step = np.linalg.solve(jac, -f)
        except np.linalg.LinAlgError:
            break
        pitch += float(np.clip(step[0], -10, 10))
        roll += float(np.clip(step[1], -10, 10))
    W = leg_world(yaw, pitch, roll)
    point, local = target(W)
    angles, slide, s = _place(side, root, offset, W, point, local)
    axial = float(s @ (W @ np.array([0.0, -1.0, 0.0])))
    return angles, tuple(float(v) for v in slide), axial, pitch, roll


SOLE_CORNERS = [np.array([x, 0.0, z]) for x in (-HALF_FOOT, HALF_FOOT) for z in (-HALF_FOOT, HALF_FOOT)]


def sole_point(yaw, direction, sharp=24.0):
    """The point of a leg's sole (from its middle, in the leg's own frame) furthest in a direction (the
    character's frame): the middle of an edge when the leg points along it, a corner when it points across.
    Smoothed, so it moves from one to the other without a jump."""
    local = posekit.ry(yaw).T @ np.asarray(direction, float)
    dots = np.array([c @ local for c in SOLE_CORNERS])
    w = np.exp(sharp * (dots - dots.max()))
    w /= w.sum()
    return sum(wi * c for wi, c in zip(w, SOLE_CORNERS))


def planted_target(side, footprint, yaw, travel):
    """A planted leg rolls over its sole like a foot: while it leans the way the body travels it rests on
    the trailing edge (the heel going forwards), once it leans back on the leading one (the toe); the
    footprint (the middle of the sole when flat) never moves."""
    footprint = np.asarray(footprint, float)
    turn = posekit.ry(yaw)
    trailing, leading = sole_point(yaw, -travel), sole_point(yaw, travel)
    bottom = edge(side, 0.0)

    def target(W):
        lean = float((W @ np.array([0.0, -1.0, 0.0])) @ travel)  # + the sole is ahead of the hip
        corner = trailing if lean >= 0 else leading
        return footprint + turn @ corner, bottom + corner

    return target


# Cycles ----------------------------------------------------------------------------------------------


class Cycle:
    """One looping movement cycle. heading: the way the body travels (degrees, 0 forward, 90 left);
    torso: how far the torso turns that way (degrees); lead: +1 when the legs step out the way they
    point, -1 for a backpedal; upper(phase) -> dict(root=(x, y, z), neck_world=(x, y, z), rShoulder,
    lShoulder, offset=(x, y, z)), the body's designed motion (the height is lowered where a planted leg
    could not reach)."""

    def __init__(self, name, period, stance, lift, heading=0.0, torso=0.0, lead=1, width=0.0, note="",
                 upper=None, samples=64):
        self.name = name
        self.period = period
        self.stance = stance
        self.stride = TRAVEL / stance
        self.lift = lift
        self.heading = heading
        self.torso = torso
        self.lead = lead
        self.width = width
        self.note = note
        self.upper = upper
        self.samples = samples
        # The legs point the way the torso faces: an R6 leg turns about the outer edge of its hip, so a leg
        # turned far from its torso would swing half out of the torso's silhouette. A sideways run turns the
        # whole body into it instead, and the legs step a little across.
        self.leg_yaw = torso
        self.travel_dir = posekit.ry(heading) @ np.array([0.0, 0.0, -1.0])

    @property
    def speed(self):
        return self.stride / self.period

    def home(self, side):
        """Where a leg's sole rests (the floor point under its hip) with the torso turned its way."""
        hip = hip_world(side, (0.0, self.torso, 0.0), (0.0, 0.0, 0.0))
        bottom = hip + posekit.ry(self.leg_yaw) @ (edge(side, 0.0) + np.array([side * self.width, 0.0, 0.0]))
        return np.array([bottom[0], 0.0, bottom[2]])

    def footprint(self, side, u):
        """The planted footprint at stance progress u (0 landing, 1 pushing off), in the body's frame."""
        return self.home(side) + self.travel_dir * TRAVEL * (0.5 - u)

    def lift_at(self, u):
        """A swinging foot's height: up quickly, highest a little before halfway, down onto the edge."""
        w = u**0.8
        return self.lift * math.sin(math.pi * w) ** 0.85

    def swing_point(self, side, own):
        """Where a swinging foot is aimed (character frame) and the point of its sole that is aimed there:
        from the leading edge it pushed off from to the trailing edge it lands on."""
        s = self.stance
        u = (own - s) / (1 - s)
        turn = posekit.ry(self.leg_yaw)
        off, on = sole_point(self.leg_yaw, self.travel_dir), sole_point(self.leg_yaw, -self.travel_dir)
        start = self.footprint(side, 1.0) + turn @ off
        land = self.footprint(side, 0.0) + turn @ on
        swing_travel = self.travel_dir * self.stride * (1 - s)  # the body moves on meanwhile
        world_move = land - start + swing_travel
        point = start + world_move * smoothstep(u) - swing_travel * u + UP * self.lift_at(u)
        k = smoothstep(u)
        return point, edge(side, 0.0) + off * (1 - k) + on * k

    def leg(self, side, own, root, offset, raised=0.0, fade=False, guess=(0.0, 0.0)):
        """(angles, slide, axial, pitch, roll, planted) for one leg at its own phase; a swinging foot aimed
        `raised` studs higher (see raises), eased in and out at the ends of the swing when `fade`."""
        if own < self.stance:
            u = own / self.stance
            target = planted_target(side, self.footprint(side, u), self.leg_yaw, self.travel_dir)
            return (*solve_leg(side, root, offset, self.leg_yaw, target, guess), True)
        point, local = self.swing_point(side, own)
        if fade:
            u = (own - self.stance) / (1 - self.stance)
            raised *= smoothstep(u / 0.1) * smoothstep((1 - u) / 0.1)
        point = point + UP * raised

        def target(_W):
            return point, local

        return (*solve_leg(side, root, offset, self.leg_yaw, target, guess), False)

    def needed_raise(self, side, own, root, offset):
        """How much higher a swinging foot must go so its leg stays in its hip (+: just after it leaves the
        ground, the body already moving away, it peels up) and does not fold deeper than MAX_SINK into the
        torso (-: held lower)."""
        raised = 0.0
        for _ in range(8):
            axial = self.leg(side, own, root, offset, raised)[2]
            if axial > MAX_GAP:
                raised += (axial - MAX_GAP * 0.5) * 1.1
            elif axial < -MAX_SINK:
                raised -= (-axial - MAX_SINK) * 1.1
            else:
                break
        return raised

    def frame(self, phase, height=None, raised=(0.0, 0.0)):
        """Every joint at this phase, with the body at its designed height or at `height`, and the swinging
        feet raised by (right, left)."""
        body = self.upper(phase)
        root = body["root"]
        ox, oy, oz = body["offset"]
        offset = (ox, oy if height is None else height, oz)
        joints = {"root": root}
        neck = R(*root).T @ R(*body["neck_world"])
        joints["neck"] = euler(neck)
        joints["rShoulder"] = body["rShoulder"]
        joints["lShoulder"] = body["lShoulder"]
        gaps = []  # how far each planted leg is out of its hip beyond what it may be
        for side, key, own, lift in ((1, "rHip", phase, raised[0]), (-1, "lHip", (phase + 0.5) % 1, raised[1])):
            angles, slide, axial, _, _, planted = self.leg(side, own, root, offset, lift, fade=True)
            joints[key] = J(angles, slide)
            if planted:
                landing = 1 - smoothstep(own / self.stance / 0.15)  # the frames a heel comes down
                gaps.append(axial - PLANTED_GAP - LANDING_GAP * landing)
        return joints, offset, gaps

    def reach(self, phase, low=-1.2, high=0.4):
        """The highest the body can be at this phase with no planted leg pulled out of its hip."""
        _, _, gaps = self.frame(phase, high)
        if not gaps or max(gaps) <= 0:
            return high
        for _ in range(28):
            mid = (low + high) / 2
            _, _, gaps = self.frame(phase, mid)
            if max(gaps) > 0:
                high = mid
            else:
                low = mid
        return low

    def heights(self):
        """The body's height over the cycle: the designed bob, lowered (smoothly) wherever a planted leg
        could not reach the floor without leaving the hip."""
        n = self.samples
        phases = [i / n for i in range(n)]
        design = np.array([self.upper(p)["offset"][1] for p in phases])
        reach = np.array([self.reach(p) for p in phases])
        k = 0.025
        height = -k * np.log(np.exp(-design / k) + np.exp(-(reach - 0.004) / k))
        # A smooth curve under the reach: the lowest of each few samples, blurred no wider than that, can never
        # rise above the reach, and the body eases down into a landing instead of dropping at its frame.
        r = 3
        low = np.array([min(height[(i + d) % n] for d in range(-r, r + 1)) for i in range(n)])
        weights = [math.exp(-0.5 * (d / 1.3) ** 2) for d in range(-r, r + 1)]
        total = sum(weights)
        height = np.array([sum(w * low[(i + d) % n] for w, d in zip(weights, range(-r, r + 1))) / total for i in range(n)])
        return phases, np.minimum(height, reach)

    def raises(self, phases, heights):
        """For each leg, how much higher its foot goes at each sample of its swing: what it needs (see
        needed_raise), widened and blurred over the cycle so the foot eases up and down instead of
        snapping onto the limit."""
        n = len(phases)
        out = {}
        for side in (1, -1):
            need = np.zeros(n)
            for i, phase in enumerate(phases):
                own = phase if side > 0 else (phase + 0.5) % 1
                if own >= self.stance:
                    body = self.upper(phase)
                    ox, _, oz = body["offset"]
                    need[i] = self.needed_raise(side, own, body["root"], (ox, float(heights[i]), oz))
            up, down = np.maximum(need, 0.0), np.minimum(need, 0.0)
            widen = 2
            up = np.array([max(up[(i + d) % n] for d in range(-widen, widen + 1)) for i in range(n)])
            down = np.array([min(down[(i + d) % n] for d in range(-widen, widen + 1)) for i in range(n)])
            weights = [math.exp(-0.5 * (d / 1.5) ** 2) for d in range(-4, 5)]
            blur = np.zeros(n)
            for i in range(n):
                blur[i] = sum(w * (up[(i + d) % n] + down[(i + d) % n]) for w, d in zip(weights, range(-4, 5))) / sum(weights)
            out[side] = blur
        return out

    def build(self):
        c = clip(self.name, self.period, loop=True, note=self.note)
        c.stride = self.stride
        c.stance = self.stance
        c.heading = self.heading
        phases, heights = self.heights()
        raised = self.raises(phases, heights)
        for i, (phase, height) in enumerate(zip(phases, heights)):
            joints, offset, _ = self.frame(phase, float(height), (raised[1][i], raised[-1][i]))
            c.pose(phase * self.period, "linear", offset=offset, **joints)
        return c


# The upper body of each cycle ------------------------------------------------------------------------
# Arms: shoulder x 0 hangs, + swings forward; z out (right +, left -). A slide forward and up while an
# arm swings forward reads as a bent elbow. Root: -x leans forward; y turns left; z tilts left.


def arms(phase, swing, base, out, arc, lift, forward, lag, across=0.0, rest_slide=(0.0, 0.0, 0.0)):
    """Both arms swinging against the legs: the right arm is back when the right foot lands."""
    s = cyc(phase, lag)  # +1: right arm back, left arm forward
    out_r = {}
    for side, key, sign in ((1, "rShoulder", 1), (-1, "lShoulder", -1)):
        a = s * sign  # +1: this arm is back
        fwd = 0.5 * (1 - a)  # 0 back .. 1 forward
        x = base - swing * a
        z = side * (out + arc * abs(a) ** 1.5)
        y = -side * across * fwd
        slide = (
            -side * 0.03 * fwd + rest_slide[0] * side,
            lift * fwd + rest_slide[1],
            -forward * fwd + rest_slide[2],
        )
        out_r[key] = J((x, y, z), slide)
    return out_r


def run_forward(phase):
    bob = twice(phase, 0.33)  # +1 high in the air between steps, -1 just after a foot lands
    yaw = -6.0 * cyc(phase, 0.02)  # the shoulders turn against the leading leg
    body = dict(
        root=(-9.5 - 1.0 * bob, yaw, 1.2 * cyc(phase, 0.12)),
        neck_world=(-3.0, 0.25 * yaw, 0.0),
        offset=(0.035 * cyc(phase, 0.1), -0.1 + 0.06 * bob, 0.0),
    )
    body.update(arms(phase, swing=32, base=12, out=6, arc=7, lift=0.06, forward=0.14, lag=0.05, across=6))
    return body


def run_back(phase):
    bob = twice(phase, 0.33)
    yaw = 4.0 * cyc(phase, 0.02)
    body = dict(
        root=(-3.0 - 0.6 * bob, yaw, 1.0 * cyc(phase, 0.12)),
        neck_world=(-5.0, 0.2 * yaw, 0.0),
        offset=(0.03 * cyc(phase, 0.1), -0.11 + 0.05 * bob, 0.0),
    )
    body.update(arms(phase, swing=-20, base=10, out=8, arc=6, lift=0.04, forward=0.1, lag=0.05))
    return body


def run_side(sign):
    """Running sideways (sign +1 left, -1 right): the torso turned half way into the run, the head kept
    to the front, a lean into the way it goes."""

    def pose(phase):
        bob = twice(phase, 0.33)
        torso = SIDE_RUN_TURN * sign
        yaw = torso - 4.0 * cyc(phase, 0.02)
        body = dict(
            root=(-6.0 - 0.8 * bob, yaw, 4.0 * sign),
            neck_world=(-3.0, 0.0, 0.0),
            offset=(0.03 * cyc(phase, 0.1), -0.11 + 0.055 * bob, 0.0),
        )
        body.update(arms(phase, swing=26, base=12, out=7, arc=6, lift=0.05, forward=0.12, lag=0.05, across=4))
        return body

    return pose


def walk_forward(phase):
    bob = twice(phase, 0.31)  # +1 passing over the planted leg, -1 with both feet down
    yaw = -4.0 * cyc(phase, 0.03)
    body = dict(
        root=(-5.5 + 0.6 * bob, yaw, 1.4 * cyc(phase, 0.15)),  # slouched forward, as the noir walk was
        neck_world=(-1.0, 0.3 * yaw, 0.0),
        offset=(0.05 * cyc(phase, 0.12), -0.06 + 0.035 * bob, 0.0),
    )
    body.update(arms(phase, swing=14, base=5, out=3, arc=3, lift=0.02, forward=0.06, lag=0.08,
                     rest_slide=(-0.04, -0.03, -0.06)))
    return body


def walk_back(phase):
    bob = twice(phase, 0.31)
    yaw = 3.0 * cyc(phase, 0.03)
    body = dict(
        root=(-3.0 + 0.4 * bob, yaw, 1.2 * cyc(phase, 0.15)),
        neck_world=(-3.0, 0.25 * yaw, 0.0),
        offset=(0.045 * cyc(phase, 0.12), -0.06 + 0.03 * bob, 0.0),
    )
    body.update(arms(phase, swing=-10, base=5, out=4, arc=2, lift=0.02, forward=0.05, lag=0.08,
                     rest_slide=(-0.04, -0.03, -0.05)))
    return body


def walk_side(sign):
    def pose(phase):
        bob = twice(phase, 0.31)
        yaw = SIDE_WALK_TURN * sign - 3.0 * cyc(phase, 0.03)
        body = dict(
            root=(-5.0 + 0.4 * bob, yaw, 2.0 * sign),
            neck_world=(-1.5, 0.0, 0.0),
            offset=(0.04 * cyc(phase, 0.12), -0.06 + 0.03 * bob, 0.0),
        )
        body.update(arms(phase, swing=12, base=5, out=3, arc=3, lift=0.02, forward=0.06, lag=0.08,
                         rest_slide=(-0.04, -0.03, -0.06)))
        return body

    return pose


SIDE_RUN_TURN = 60.0  # how far a body running sideways turns into it (degrees)
SIDE_WALK_TURN = 40.0
RUN_PERIOD = 0.64  # 16 studs/s: the speed every body runs at in the game
RUN_STANCE = TRAVEL / (16.0 * RUN_PERIOD)
WALK_PERIOD = 1.05
WALK_STANCE = 0.6

RUNS = [
    Cycle("run", RUN_PERIOD, RUN_STANCE, 0.5, upper=run_forward,
          note="Run, 16 studs/s: leaning in, compact arms arcing out a little, the head steady; heel to toe."),
    Cycle("runBack", RUN_PERIOD, RUN_STANCE, 0.42, heading=180.0, lead=-1, upper=run_back,
          note="Backpedal at full speed: upright, short quick steps landing on the toe edge."),
    Cycle("runLeft", RUN_PERIOD, RUN_STANCE, 0.46, heading=90.0, torso=SIDE_RUN_TURN, upper=run_side(1),
          note="Running left: the body turned well into it, the head to the front, a lean."),
    Cycle("runRight", RUN_PERIOD, RUN_STANCE, 0.46, heading=-90.0, torso=-SIDE_RUN_TURN, upper=run_side(-1),
          note="Running right: the body turned well into it, the head to the front, a lean."),
]
WALKS = [
    Cycle("walk", WALK_PERIOD, WALK_STANCE, 0.26, upper=walk_forward, samples=96,
          note="Walk: the serious, slouched walk, long heel-to-toe steps, arms low and close."),
    Cycle("walkBack", WALK_PERIOD, WALK_STANCE, 0.22, heading=180.0, lead=-1, upper=walk_back, samples=96,
          note="Stepping backwards, careful, toe first."),
    Cycle("walkLeft", WALK_PERIOD, WALK_STANCE, 0.24, heading=90.0, torso=SIDE_WALK_TURN, upper=walk_side(1), samples=96,
          note="Walking left, turned into it, the head to the front."),
    Cycle("walkRight", WALK_PERIOD, WALK_STANCE, 0.24, heading=-90.0, torso=-SIDE_WALK_TURN, upper=walk_side(-1), samples=96,
          note="Walking right, turned into it, the head to the front."),
]


# Standing --------------------------------------------------------------------------------------------

ARMS = ("rShoulder", "lShoulder")


def soft(m, head=2.6, arms_hz=2.2, head_damp=0.8, arm_damp=0.7):
    """Follow-through: the head and arms trail the body a little (softer than the actions' springs)."""
    m.follow("neck", head, head_damp)
    m.follow(ARMS, arms_hz, arm_damp)
    return m


def breath_shape(u):
    """One breath, 0 to 1 and back: in faster than out."""
    if u < 0.4:
        return 0.5 - 0.5 * math.cos(math.pi * u / 0.4)
    return 0.5 + 0.5 * math.cos(math.pi * (u - 0.4) / 0.6)


def breathing(t, period, depths):
    k = int(t // period) % len(depths)
    return depths[k] * breath_shape((t % period) / period)


def track(points, t, length):
    """A value eased from point to point ((time, value) pairs, the first repeated at the loop's end)."""
    pts = sorted(points) + [(length, sorted(points)[0][1])]
    t = t % length
    for (t0, v0), (t1, v1) in zip(pts, pts[1:]):
        if t0 <= t <= t1:
            return v0 + (v1 - v0) * smootherstep((t - t0) / (t1 - t0) if t1 > t0 else 1.0)
    return pts[0][1]


IDLE_LENGTH = 24.0


def standing(name, note, breath_period, depths, weight, glances, nods, lean, low, arm_x, arm_z, arm_slide, stance,
             shift, head_drop):
    """A long standing loop of slow rhythms that do not line up (breathing, the weight moving between the
    feet and back, the head drifting and glancing), so it never visibly repeats; the soles stay put."""
    m = Motion(name, IDLE_LENGTH, loop=True, note=note)
    step = 0.25
    for i in range(int(IDLE_LENGTH / step)):
        t = i * step
        b = breathing(t, breath_period, depths)
        w = track(weight, t, IDLE_LENGTH)
        look = track(glances, t, IDLE_LENGTH)
        nod = track(nods, t, IDLE_LENGTH)
        root = (lean + 0.7 * b, 0.25 * look + 0.6 * w, -0.9 * w)
        head = (head_drop - 0.5 * b + nod, look, 0.3 * w)
        neck = euler(R(*root).T @ R(*head))
        m.key(
            t,
            offset=(shift * w, low + 0.012 * b, 0.0),
            root=root,
            neck=neck,
            rShoulder=J((arm_x + 0.8 * b, -1.0, arm_z + 0.6 * b), (arm_slide[0], arm_slide[1] + 0.018 * b, arm_slide[2])),
            lShoulder=J((arm_x + 0.8 * b, 1.0, -arm_z - 0.6 * b), (-arm_slide[0], arm_slide[1] + 0.018 * b, arm_slide[2])),
        )
    soft(m).plant(stance=stance)
    return m


def build_standing():
    standing(
        "idle",
        "Standing at ease: slow breaths of different depths, the weight settling on one foot and then the "
        "other, the head drifting and now and then looking round.",
        breath_period=4.0,
        depths=(1.0, 0.85, 1.15, 0.9, 1.3, 0.8),
        weight=[(0.0, -1.0), (5.5, -1.0), (7.5, 1.0), (14.5, 1.0), (16.2, 0.2), (19.5, 0.2), (21.2, -1.0)],
        glances=[(0.0, 0.0), (2.5, 0.0), (3.6, -7.0), (5.2, -6.0), (6.4, -1.0), (10.0, 0.0), (11.2, 6.0), (13.6, 6.5),
                 (14.6, 2.0), (19.0, 1.0), (20.2, -2.5), (22.6, -1.0)],
        nods=[(0.0, 0.0), (17.2, 0.0), (18.0, -3.0), (19.4, -0.5), (23.0, 0.0)],
        lean=-2.0,
        low=-0.02,
        arm_x=2.0,
        arm_z=4.0,
        arm_slide=(0.0, 0.0, -0.02),
        stance=0.05,
        shift=0.055,
        head_drop=-2.0,
    ).build()
    standing(
        "idleGuarded",
        "Standing guarded (in a case): the weight centred, the stance a little wider, hands a little "
        "forward and in, quicker breaths, the eyes going round the room.",
        breath_period=24.0 / 7,
        depths=(1.0, 0.8, 1.1, 0.75, 1.0, 0.9, 1.2),
        weight=[(0.0, 0.0), (6.0, 0.25), (9.0, 0.25), (12.0, -0.2), (18.0, -0.2), (21.0, 0.0)],
        glances=[(0.0, 0.0), (1.5, 0.0), (2.3, -12.0), (3.6, -11.0), (4.3, 0.0), (8.0, 0.0), (8.7, 14.0), (10.1, 13.0),
                 (10.9, 2.0), (15.0, 0.0), (15.6, -6.0), (17.1, -5.0), (17.7, 0.0), (21.5, 0.0), (22.1, 8.0), (23.1, 6.0)],
        nods=[(0.0, 0.0), (12.2, 0.0), (12.8, -2.0), (13.8, 0.0)],
        lean=-3.5,
        low=-0.05,
        arm_x=7.0,
        arm_z=2.0,
        arm_slide=(0.04, 0.03, -0.07),
        stance=0.12,
        shift=0.045,
        head_drop=-3.0,
    ).build()


# Fidgets: played now and then over a standing body. They move the upper body only; the game keeps the
# soles planted under whatever the root does (LocomotionController), so they work over both idles.
# Lobby (at ease): idleLook, idleWatch, idleTie, idleNeck, idleSleeve, idleHandsBack.
# Case (guarded): idleLook, idleWatch, idleGlance, idleArmsCross, idleHand, idleRoom.

LOBBY_FIDGETS = ("idleLook", "idleWatch", "idleTie", "idleNeck", "idleSleeve", "idleHandsBack")
CASE_FIDGETS = ("idleLook", "idleWatch", "idleGlance", "idleArmsCross", "idleHand", "idleRoom")


def r_chest(x=68, across=-40):
    return J((x, 0, across), (-0.3, 0.14, -0.22))


def l_chest(x=60, across=36):
    return J((x, 0, across), (0.3, 0.12, -0.22))


HANG_R, HANG_L = J((2, -1, 4)), J((2, 1, -4))


def build_fidgets():
    look = Motion("idleLook", 3.4, note="A fidget: a look over one shoulder, then the other.")
    look.key(0.0, root=(0, 0, 0), neck=(0, 0, 0))
    look.key(0.9, root=(0, 9, 0), neck=(-2, 30, 2))
    look.key(1.6, root=(0, 9, 0), neck=(-3, 32, 2))
    look.key(2.4, root=(0, -5, 0), neck=(-1, -24, -2))
    look.key(3.4, root=(0, 0, 0), neck=(0, 0, 0))
    look.follow("neck", 2.2, 0.8)
    look.build()

    watch = Motion("idleWatch", 3.2, note="A fidget: the wrist comes up and the head bends to the watch.")
    watch.key(0.0, root=(0, 0, 0), neck=(0, 0, 0), rShoulder=HANG_R)
    watch.key(0.7, root=(-3, 6, 0), neck=(-24, 8, 0), rShoulder=J((62, 0, -42), (-0.25, 0.16, -0.25)))
    watch.key(2.1, root=(-3, 6, 0), neck=(-25, 9, 0), rShoulder=J((63, 0, -42), (-0.25, 0.16, -0.25)))
    watch.key(3.2, root=(0, 0, 0), neck=(0, 0, 0), rShoulder=HANG_R)
    soft(watch).build()

    tie = Motion("idleTie", 2.8, note="A fidget: a tug at the knot of the tie, chin up.")
    tie.key(0.0, root=(0, 0, 0), neck=(0, 0, 0), rShoulder=HANG_R, lShoulder=HANG_L)
    tie.key(0.6, root=(-2, 0, 0), neck=(6, 0, 4), rShoulder=J((96, 0, -42), (-0.3, 0.3, -0.18)),
            lShoulder=J((22, 0, 20), (0.15, 0.05, -0.1)))
    for t, d in ((0.9, 0.06), (1.2, -0.02), (1.5, 0.05)):
        tie.key(t, root=(-2, 0, 0), neck=(7, 0, 5), rShoulder=J((96, 0, -42), (-0.3, 0.3 + d, -0.18)),
                lShoulder=J((22, 0, 20), (0.15, 0.05, -0.1)))
    tie.key(2.8, root=(0, 0, 0), neck=(0, 0, 0), rShoulder=HANG_R, lShoulder=HANG_L)
    soft(tie).build()

    neck = Motion("idleNeck", 3.0, note="A fidget: a slow roll of the neck, one side to the other, a breath out.")
    neck.key(0.0, root=(0, 0, 0), neck=(0, 0, 0))
    neck.key(0.8, root=(-1, 0, 0), neck=(-14, 4, 12))
    neck.key(1.6, root=(-1, 0, 0), neck=(-16, -4, -12))
    neck.key(2.2, root=(0.6, 0, 0), neck=(4, 0, -2))
    neck.key(3.0, root=(0, 0, 0), neck=(0, 0, 0))
    neck.follow("neck", 1.8, 0.9)
    neck.build()

    sleeve = Motion("idleSleeve", 2.6, note="A fidget: the left hand tugs the right cuff straight.")
    sleeve.key(0.0, root=(0, 0, 0), neck=(0, 0, 0), rShoulder=HANG_R, lShoulder=HANG_L)
    sleeve.key(0.55, root=(-3, -4, 0), neck=(-18, -8, 0), rShoulder=J((38, 0, -18), (-0.1, 0.05, -0.12)),
               lShoulder=J((46, 0, 30), (0.22, 0.06, -0.2)))
    for t, d in ((0.85, 0.04), (1.15, -0.02), (1.45, 0.03)):
        sleeve.key(t, root=(-3, -4, 0), neck=(-19, -8, 0), rShoulder=J((38, 0, -18), (-0.1, 0.05, -0.12)),
                   lShoulder=J((46 + 4 * d * 10, 0, 30), (0.22, 0.06 + d, -0.2)))
    sleeve.key(2.6, root=(0, 0, 0), neck=(0, 0, 0), rShoulder=HANG_R, lShoulder=HANG_L)
    soft(sleeve).build()

    back = Motion("idleHandsBack", 4.2, note="A fidget: hands clasped behind the back, the chest up, a slow look round.")
    behind_r, behind_l = J((-24, 0, -14), (-0.18, 0.02, 0.18)), J((-24, 0, 14), (0.18, 0.02, 0.18))
    back.key(0.0, root=(0, 0, 0), neck=(0, 0, 0), rShoulder=HANG_R, lShoulder=HANG_L)
    back.key(0.7, root=(1.5, 0, 0), neck=(-2, 0, 0), rShoulder=behind_r, lShoulder=behind_l)
    back.key(1.9, root=(1.5, 6, 0), neck=(-2, 14, 0), rShoulder=behind_r, lShoulder=behind_l)
    back.key(3.2, root=(1.5, -3, 0), neck=(-3, -8, 0), rShoulder=behind_r, lShoulder=behind_l)
    back.key(4.2, root=(0, 0, 0), neck=(0, 0, 0), rShoulder=HANG_R, lShoulder=HANG_L)
    soft(back).build()

    glance = Motion("idleGlance", 2.2, note="A fidget in a case: a quick glance over the right shoulder, held, then away.")
    glance.key(0.0, root=(0, 0, 0), neck=(0, 0, 0))
    glance.key(0.35, "out", root=(0, -12, 0), neck=(-4, -46, 0))
    glance.key(1.2, root=(0, -12, 0), neck=(-4, -48, 0))
    glance.key(2.2, root=(0, 0, 0), neck=(0, 0, 0))
    glance.follow("neck", 3.0, 0.85)
    glance.build()

    cross = Motion("idleArmsCross", 4.0, note="A fidget in a case: the arms fold across the chest for a while.")
    cross.key(0.0, root=(0, 0, 0), neck=(0, 0, 0), rShoulder=HANG_R, lShoulder=HANG_L)
    cross.key(0.8, root=(-1, 0, 0), neck=(-3, 0, 0), rShoulder=r_chest(70, -44), lShoulder=l_chest(62, 40))
    cross.key(3.1, root=(-1, 3, 0), neck=(-3, 8, 0), rShoulder=r_chest(71, -44), lShoulder=l_chest(63, 40))
    cross.key(4.0, root=(0, 0, 0), neck=(0, 0, 0), rShoulder=HANG_R, lShoulder=HANG_L)
    soft(cross).build()

    hand = Motion("idleHand", 2.8, note="A fidget in a case: the right hand comes up and the eyes go to it, thinking.")
    hand.key(0.0, root=(0, 0, 0), neck=(0, 0, 0), rShoulder=HANG_R)
    hand.key(0.7, root=(-2, 3, 0), neck=(-20, 6, 0), rShoulder=J((54, 0, -24), (-0.16, 0.1, -0.18)))
    hand.key(1.9, root=(-2, 3, 0), neck=(-21, 7, 0), rShoulder=J((56, -8, -24), (-0.16, 0.1, -0.18)))
    hand.key(2.8, root=(0, 0, 0), neck=(0, 0, 0), rShoulder=HANG_R)
    soft(hand).build()

    room = Motion("idleRoom", 4.4, note="A fidget in a case: a slow look round the room, left to right.")
    room.key(0.0, root=(0, 0, 0), neck=(0, 0, 0))
    room.key(1.2, root=(0, 10, 0), neck=(1, 24, 0))
    room.key(2.4, root=(0, 2, 0), neck=(2, 2, 0))
    room.key(3.5, root=(0, -9, 0), neck=(1, -22, 0))
    room.key(4.4, root=(0, 0, 0), neck=(0, 0, 0))
    room.follow("neck", 1.6, 0.9)
    room.build()


# In the air ------------------------------------------------------------------------------------------
# The game plays jump from the moment the body leaves the ground (Roblox jumps at once, so the crouch of
# an anticipation would come too late: the first frame is already the push off), eases into jumpApex
# near the top and into fall on the way down; fallLong takes over a long drop.


def build_air():
    jump = Motion("jump", 0.5, note="Take-off: pushed off, one knee driving up, the arms swinging up, then tucking into the rise.")
    jump.key(0.0, "snap", root=(-7, 0, 0), neck=(4, 0, 0), rShoulder=J((-16, 0, 8)), lShoulder=J((46, 0, -10), (0.03, 0.05, -0.12)),
             rHip=J((-16, 0, 2), (0, 0.04, 0)), lHip=J((42, 0, -3), (0, 0.42, -0.05)))
    jump.key(0.12, "out", root=(-3, 0, 0), neck=(2, 0, 0), rShoulder=J((34, 0, 14), (0, 0.06, -0.08)),
             lShoulder=J((52, 0, -14), (0, 0.06, -0.1)), rHip=J((22, 0, 3), (0, 0.34, -0.04)), lHip=J((34, 0, -3), (0, 0.48, -0.05)))
    jump.key(0.5, root=(-2, 0, 0), neck=(0, 0, 0), rShoulder=J((26, 0, 20), (0, 0.05, -0.06)),
             lShoulder=J((30, 0, -20), (0, 0.05, -0.06)), rHip=J((20, 0, 4), (0, 0.28, -0.03)), lHip=J((12, 0, -4), (0, 0.18, 0)))
    soft(jump, head=3.4, arms_hz=3.2)
    jump.build()

    apex = Motion("jumpApex", 1.2, loop=True, note="The top of a jump: a moment of hang, knees up a little, arms easing out.")
    for t, s in ((0.0, 1.0), (0.6, -1.0)):
        apex.key(t, root=(-2 + 0.6 * s, 0, 0.8 * s), neck=(0, 0, -0.5 * s), rShoulder=J((22, 0, 24 + 2 * s), (0, 0.04, -0.05)),
                 lShoulder=J((24, 0, -24 + 2 * s), (0, 0.04, -0.05)), rHip=J((18 + 2 * s, 0, 4), (0, 0.24, -0.03)),
                 lHip=J((10 - 2 * s, 0, -4), (0, 0.16, 0)))
    soft(apex, arms_hz=1.6)
    apex.build()

    fall = Motion("fall", 1.6, loop=True, note="Falling: arms out for balance, legs apart and drifting, the head watching the ground.")
    for t, s in ((0.0, 1.0), (0.8, -1.0)):
        fall.key(t, root=(3, 0, 1.2 * s), neck=(-12, 0, -0.6 * s), rShoulder=J((26 + 3 * s, 0, 42 + 4 * s), (0, 0.06, 0)),
                 lShoulder=J((26 - 3 * s, 0, -42 + 4 * s), (0, 0.06, 0)), rHip=J((14 + 6 * s, 0, 5), (0, 0.16, -0.03)),
                 lHip=J((-6 + 6 * s, 0, -5), (0, 0.06, 0)))
    soft(fall, head=2.0, arms_hz=1.4)
    fall.build()

    long = Motion("fallLong", 1.0, loop=True, note="A long drop: arms up and wide, legs flung apart, the body leaning back.")
    for t, s in ((0.0, 1.0), (0.5, -1.0)):
        long.key(t, root=(7, 0, 2 * s), neck=(-16, 0, -1 * s), rShoulder=J((36 + 6 * s, 0, 70 + 6 * s), (0, 0.1, 0)),
                 lShoulder=J((36 - 6 * s, 0, -70 + 6 * s), (0, 0.1, 0)), rHip=J((18 + 10 * s, 0, 8), (0, 0.18, -0.03)),
                 lHip=J((-12 + 10 * s, 0, -8), (0, 0.08, 0)))
    soft(long, head=2.4, arms_hz=2.6)
    long.build()


# Landings: played on top of whatever the body does next (additive, from their first frame, a body standing
# at rest), so landing into a run keeps the legs running and the upper body takes the blow; standing, the
# soles stay planted and the knees give. The strength comes from how fast the body hit the ground.

REST = dict(root=(0, 0, 0), neck=(0, 0, 0), rShoulder=J((2, 0, 4)), lShoulder=J((2, 0, -4)))


def landing(name, length, note, low, lean, head, arms_out, arms_fwd, hold, extra=None):
    m = Motion(name, length, note=note)
    m.additive = True
    m.key(0.0, offset=(0, 0, 0), **REST)
    hit = 0.06
    pose = dict(root=(lean, 0, 0), neck=(head, 0, 0), rShoulder=J((2 + arms_fwd, 0, 4 + arms_out), (0, -0.03, 0)),
                lShoulder=J((2 + arms_fwd, 0, -4 - arms_out), (0, -0.03, 0)))
    if extra:
        pose.update(extra)
    m.key(hit, "out", offset=(0, low, 0), **pose)
    m.key(hit + hold, offset=(0, low * 0.92, 0), **pose)
    m.key(length, "sine", offset=(0, 0, 0), **REST)
    soft(m, head=3.0, arms_hz=2.8)
    m.plant(stance=0.05)
    m.build()


def build_landings():
    landing("landLight", 0.3, "A light landing (a hop, a step off a ledge): the knees give a little, the arms dip.",
            low=-0.12, lean=-4, head=2, arms_out=4, arms_fwd=5, hold=0.02)
    landing("landNormal", 0.45, "A landing from a jump: the body sinks, leans in, the arms come forward, and rises again.",
            low=-0.3, lean=-10, head=5, arms_out=10, arms_fwd=16, hold=0.06)
    landing("landHeavy", 0.8, "A hard landing from a long drop: a deep crouch, one hand reaching for the ground, then up.",
            low=-0.52, lean=-20, head=13, arms_out=12, arms_fwd=20, hold=0.18,
            extra=dict(rShoulder=J((62, 0, 10), (0, -0.1, -0.18)), lShoulder=J((-16, 0, -32), (0, -0.02, 0.06))))


# Starting and stopping -------------------------------------------------------------------------------


STEP = (0.1, 0.32)  # when the trailing foot of a stop steps up (seconds)


def build_start_stop():
    start = Motion("startStep", 0.36, note="Setting off: the body tips into the first step and the arms answer (additive).")
    start.additive = True
    start.key(0.0, offset=(0, 0, 0), **REST)
    start.key(0.09, "out", offset=(0, -0.03, -0.04), root=(-7, 0, 0), neck=(4, 0, 0), rShoulder=J((-10, 0, 6)),
              lShoulder=J((18, 0, -6), (0, 0.02, -0.05)))
    start.key(0.36, "sine", offset=(0, 0, 0), **REST)
    start.build()

    for name, side in (("stopRight", 1), ("stopLeft", -1)):
        # side: the foot that is down when the body stops; the other steps up beside it
        lead, trail = ("rHip", "lHip") if side > 0 else ("lHip", "rHip")
        front_arm, back_arm = ("lShoulder", "rShoulder") if side > 0 else ("rShoulder", "lShoulder")
        m = Motion(name, 0.62, note="Stopping from a run: the weight catches over the planted foot, the other steps up "
                                     "beside it, and the body settles upright.")
        arm = lambda x, s: J((x, 0, 4 * s))  # noqa: E731
        sgn = {"rShoulder": 1, "lShoulder": -1}
        m.key(0.0, offset=(0, -0.08, 0), root=(-10, 0, 0), neck=(6, 0, 0),
              **{front_arm: arm(24, sgn[front_arm]), back_arm: arm(-16, sgn[back_arm])})
        m.key(0.12, "out", offset=(0, -0.14, -0.1), root=(-13, 0, 0), neck=(9, 0, 0),
              **{front_arm: arm(16, sgn[front_arm]), back_arm: arm(-4, sgn[back_arm])})
        m.key(0.28, offset=(0, -0.08, -0.04), root=(-6, 0, 0), neck=(4, 0, 0),
              **{front_arm: arm(6, sgn[front_arm]), back_arm: arm(2, sgn[back_arm])})
        m.key(0.44, offset=(0, -0.03, 0), root=(-2.5, 0, 0), neck=(1, 0, 0), rShoulder=J((2, 0, 4)), lShoulder=J((2, 0, -4)))
        m.key(0.62, "sine", offset=(0, -0.02, 0), root=(-2, 0, 0), neck=(0, 0, 0), rShoulder=J((2, 0, 4)),
              lShoulder=J((2, 0, -4)))
        # The planted foot stays a little ahead all through; the other leaves the ground behind and steps up
        # beside it between STEP[0] and STEP[1], its toe lifting first.
        ahead, behind, beside = 0.18, -0.75, 0.02
        m.plant(stance=0.05, forward=(ahead, behind) if side > 0 else (behind, ahead))
        trail_side = -side

        def step(t, pose, off, trail=trail, trail_side=trail_side):
            u = (t - STEP[0]) / (STEP[1] - STEP[0])
            if u <= 0:
                return
            u = min(1.0, u)
            k = smoothstep(u)
            foot = (trail_side * (0.5 + 0.05), 0.24 * math.sin(math.pi * u) ** 0.8, -(behind + (beside - behind) * k))
            root = tuple(pose["root"][:3]) if "root" in pose else (0.0, 0.0, 0.0)
            pitch = -12.0 * (1 - k) + 6.0 * math.sin(math.pi * u)
            angles, slide = posekit.planted_slide(trail_side, foot, root, tuple(off), pitch=pitch)
            pose[trail] = np.array([*angles, *slide])

        m.extra(step)
        soft(m, head=3.2, arms_hz=2.6)
        m.build()


# Deathsingers in flight (and spectators): hovering, gliding forward, rising and diving, blended by speed.


def build_flight():
    hover = Motion("flyHover", 4.0, loop=True, note="Hovering: upright, legs hanging loose, arms drifting, a slow float.")
    for i in range(8):
        t = i * 0.5
        f = math.sin(2 * math.pi * t / 4.0)
        g = math.sin(2 * math.pi * t / 4.0 + 1.3)
        hover.key(t, offset=(0, 0.12 * f, 0), root=(-2 + 1.2 * g, 0, 1.5 * g), neck=(-6 - 1.0 * f, 0, -1.0 * g),
                  rShoulder=J((6 + 3 * g, 0, 12 + 2 * f), (0, 0.03, 0)), lShoulder=J((6 - 3 * g, 0, -12 + 2 * f), (0, 0.03, 0)),
                  rHip=J((8 + 3 * f, 0, 4), (0, 0.12, 0)), lHip=J((-2 - 3 * f, 0, -4), (0, 0.06, 0)))
    soft(hover, arms_hz=1.2).build()

    glide = Motion("flyGlide", 2.4, loop=True, note="Gliding forward: leaning far into it, legs trailing, arms swept back.")
    for i in range(6):
        t = i * 0.4
        f = math.sin(2 * math.pi * t / 2.4)
        glide.key(t, offset=(0, 0.08 * f, 0), root=(-30 + 1.5 * f, 0, 1.2 * f), neck=(24, 0, -0.8 * f),
                  rShoulder=J((-28 + 2 * f, 0, 12), (0, 0.04, 0.04)), lShoulder=J((-28 - 2 * f, 0, -12), (0, 0.04, 0.04)),
                  rHip=J((-20 + 4 * f, 0, 3), (0, 0.08, 0)), lHip=J((-28 - 4 * f, 0, -3), (0, 0.1, 0)))
    soft(glide, arms_hz=1.6).build()

    rise = Motion("flyRise", 2.0, loop=True, note="Rising: upright and a little back, arms down and out, legs hanging straight.")
    for i in range(4):
        t = i * 0.5
        f = math.sin(2 * math.pi * t / 2.0)
        rise.key(t, offset=(0, 0.05 * f, 0), root=(5, 0, 0.8 * f), neck=(-4, 0, 0),
                 rShoulder=J((-8, 0, 24 + 3 * f)), lShoulder=J((-8, 0, -24 + 3 * f)),
                 rHip=J((-4 + 2 * f, 0, 3)), lHip=J((-4 - 2 * f, 0, -3)))
    soft(rise, arms_hz=1.4).build()

    dive = Motion("flyDive", 2.0, loop=True, note="Diving: head first and down, arms reaching ahead, legs up behind.")
    for i in range(4):
        t = i * 0.5
        f = math.sin(2 * math.pi * t / 2.0)
        dive.key(t, offset=(0, 0.04 * f, 0), root=(-44, 0, 0.8 * f), neck=(26, 0, 0),
                 rShoulder=J((40 + 3 * f, 0, 14)), lShoulder=J((40 - 3 * f, 0, -14)),
                 rHip=J((-32 + 3 * f, 0, 3), (0, 0.06, 0)), lHip=J((-36 - 3 * f, 0, -3), (0, 0.08, 0)))
    soft(dive, arms_hz=1.4).build()


# Seated (a Seat: the lobby's dice stools; the throne's stone champion holds a moment of it) --------------
# R6 legs do not bend at the knee: level thighs stick 2.5 studs straight out and go through whatever is in
# front (the dice rock, a desk). Sloped down they reach 0.6 less and pass under a table's edge.


def build_sit():
    sit = Motion("sit", 8.0, loop=True, note="Seated: perched, thighs sloping down, hands on the knees; slow breaths, a "
                                              "shift of weight, a look round.")
    weight = [(0.0, 0.0), (2.5, 0.0), (3.5, 1.0), (6.0, 1.0), (7.2, 0.0)]
    glances = [(0.0, 0.0), (4.4, 0.0), (5.2, 14.0), (6.4, 12.0), (7.3, 0.0)]
    for i in range(32):
        t = i * 0.25
        b = breathing(t, 4.0, (1.0, 0.85))
        w = track(weight, t, 8.0)
        look = track(glances, t, 8.0)
        root = (-6 + 0.8 * b, 0.25 * look, -1.2 * w)
        neck = euler(R(*root).T @ R(-8 - 0.5 * b, look, 0.3 * w))
        sit.key(t, root=root, neck=neck, rHip=J((52, 0, 6)), lHip=J((50, 0, -6)),
                rShoulder=J((30 + b, 0, -8), (-0.05, 0.02 * b, -0.15)), lShoulder=J((30 + b, 0, 8), (0.05, 0.02 * b, -0.15)))
    soft(sit).build()


GROUPS = {
    "standing": (("idle", "idleGuarded"), build_standing),
    "fidgets": (tuple(sorted(set(LOBBY_FIDGETS + CASE_FIDGETS))), build_fidgets),
    "air": (("jump", "jumpApex", "fall", "fallLong"), build_air),
    "landings": (("landLight", "landNormal", "landHeavy"), build_landings),
    "startstop": (("startStep", "stopRight", "stopLeft"), build_start_stop),
    "flight": (("flyHover", "flyGlide", "flyRise", "flyDive"), build_flight),
    "sit": (("sit",), build_sit),
}


def build(names=None):
    """Builds the movement set (or only the groups holding `names`)."""
    for cycle in RUNS + WALKS:
        if names is None or cycle.name in names:
            cycle.build()
    for clip_names, fn in GROUPS.values():
        if names is None or set(clip_names) & set(names):
            fn()


__all__ = ["build", "RUNS", "WALKS", "Cycle", "solve_leg", "TRAVEL"]
