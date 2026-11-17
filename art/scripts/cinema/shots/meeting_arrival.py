"""The meeting intro, rebuilt from nothing on 2026-11-17 (item 6 of docs/handoff/list-2026-11-16.md, note 1d of
docs/handoff/animation-cutscene-plan-2026-11-13.md; the old module meeting_intro.py is kept, no longer imported).
Reference and the one sentence: art/refs/cinema/MeetingIntro.toml.

The scene: twelve people hurry into a dark war room one after another, each by a way of their own and each with a bit of
business (a collar tugged, a watch looked at, a cuff pulled, a case file skidded across the table), and by the time the
last one is in, every one stands at their own place round the table under the one light, facing the middle.

Seat k ("seat:k", 0-based like plan.seats()) is the player at place k. In a match the cast is the living players in order:
seats 0..n-1 (n is 6 to 12), and any seat nobody is cast in shows a faceless stand-in (ShotPlayer). So the close cuts stay
on seats 0..5, which are always real, and the other six are in the wide. MeetingService.gather() has already put the real
bodies standing at their places (radius 17, facing the middle) when this plays, and gather(true) sits them after it, so the
last frame is every actor standing exactly there.

The war room (maps/venues/meeting/plan.py, its own origin): 60 x 60 studs, the round table (radius 13.05, top 3.3) in the
middle, twelve places at 17, a chair behind each at 19.6, the records door (closed) in the east wall at z -23. The room is
dark but for the ring chandelier over the table, so the arrivals come out of the dark at the room's edge, between the
chairs (a gap every 30 degrees, at the odd multiples of 15), and the pairs of seats that share a gap come in one behind
the other.

Cuts (cut on the action, none under 1.4 s):
  A  0.0-1.9  from over the table's north-east, long lens: seat 4 comes in by the gap near the records door tugging his collar
  B  1.9-4.1  low over the table's top at the east side: seat 3 stops at his place, swings his arm and skids a case file
              across the table (it lands and slides at the lens)
  C  4.1-5.5  from over the table's south side, looking south: seats 11, 0 and 1 come in (a cuff pulled, a tie touched)
  D  5.5-7.8  high and wide from the south-west corner: the last ones come in and the ring is full, heads turning

Eight walk in (seats 4, 3, 5, 2, 11, 0, 8, 1: the first six are the ones always played by real players, so the close cuts are
on them); seats 6, 7, 9 and 10 wait in their places in the dark and watch. Ten walkers took the acting file to 201,605
characters, past Roblox's limit of about 200,000, hence eight."""

import math

import numpy as np

import posekit
from animlib import J
from cinema import footwork, framing
from cinema.acting import beat, body_reach, facing, soft, strike, walking
from cinema.shot import Shot
from motion import Motion

NAME = "MeetingIntro"
LENGTH = 7.8
SEAT_R = 17.0  # the places (maps/venues/meeting/plan.py SEAT_R; MeetingService.gather() puts the real bodies there)
CHAIR_R = 19.6
LANE_R = 15.8  # the lane just inside the chairs' fronts: a body walking along it has its outer arm 2 studs out, at 17.8
STEP = 0.5  # the last step back from the lane into the place, after the turn to the table
SPEED = 4.7  # the cruise of the walk (late for an emergency meeting: they hurry, but they are not running)
STAND = dict(rShoulder=J((4, 0, 2)), lShoulder=J((4, 0, -2)))
LEAN = -5.0  # the hurried body leans a little forward
CENTRE = (0.0, 0.0)


def seat(k):
    a = math.radians(k * 30.0)
    return math.sin(a) * SEAT_R, math.cos(a) * SEAT_R


def ring(angle, r):
    a = math.radians(angle)
    return math.sin(a) * r, math.cos(a) * r


def gap_of(k):
    """The gap between the chairs that seat k comes in by: seats 2j and 2j+1 share the one at 30 * (2j) + 15."""
    return (k // 2) * 60.0 + 15.0


# k: (when they stop at the place, the angle off the gap line they start from, the radius they start at)
ARRIVE = {
    4: (2.9, -9.0, 25.0),
    3: (3.2, 9.0, 24.6),
    5: (4.2, 8.0, 25.0),
    2: (4.5, -10.0, 25.0),
    11: (4.7, 9.0, 25.0),
    0: (5.1, -9.0, 25.0),
    8: (5.5, -11.0, 25.0),
    1: (6.3, 10.0, 25.0),
}
STANDING = (6, 7, 9, 10)  # already in their places when the shot opens (north and west, in the dark): they watch the rest come in


def catmull(points, per=10):
    """A smooth line through the points (centripetal Catmull-Rom), as a dense polyline."""
    p = [np.array(q, float) for q in points]
    p = [2 * p[0] - p[1]] + p + [2 * p[-1] - p[-2]]
    out = [p[1]]
    for i in range(1, len(p) - 2):
        p0, p1, p2, p3 = p[i - 1], p[i], p[i + 1], p[i + 2]
        t0 = 0.0
        t1 = t0 + max(1e-6, np.linalg.norm(p1 - p0)) ** 0.5
        t2 = t1 + max(1e-6, np.linalg.norm(p2 - p1)) ** 0.5
        t3 = t2 + max(1e-6, np.linalg.norm(p3 - p2)) ** 0.5
        for s in range(1, per + 1):
            t = t1 + (t2 - t1) * s / per
            a1 = (t1 - t) / (t1 - t0) * p0 + (t - t0) / (t1 - t0) * p1
            a2 = (t2 - t) / (t2 - t1) * p1 + (t - t1) / (t2 - t1) * p2
            a3 = (t3 - t) / (t3 - t2) * p2 + (t - t2) / (t3 - t2) * p3
            b1 = (t2 - t) / (t2 - t0) * a1 + (t - t0) / (t2 - t0) * a2
            b2 = (t3 - t) / (t3 - t1) * a2 + (t - t1) / (t3 - t1) * a3
            out.append((t2 - t) / (t2 - t1) * b1 + (t - t1) / (t2 - t1) * b2)
    return out


def way(k):
    """The line the walk follows: from out in the dark, to the gap between the chairs, through it and in to the place."""
    ta, off, r0 = ARRIVE[k]
    g, pa = gap_of(k), k * 30.0
    delta = pa - g
    # (through the middle of the gap to the lane just inside the chairs' fronts, then along it to the place: the chairs are
    # 3.2 across and a body with its arms 4, so a way nearer the chairs than the gap's middle puts an arm into one)
    pts = [ring(g + off, r0), ring(g + off * 0.3, 23.2), ring(g, 19.0), ring(g + delta * 0.3, 15.7),
           ring(g + delta * 0.75, 15.8), ring(pa, LANE_R)]
    return catmull(pts)


def travel(points, speed, accel=0.55, decel=0.95, yaw_end=None, turn_end=1.1):
    """A walk along a polyline eased up over `accel` and down over `decel`: ([(t, x, z, yaw)] every 0.1 s from 0, T). The
    heading is the line's own, turned into `yaw_end` over the last `turn_end` seconds."""
    pts = [np.array(p, float) for p in points]
    seg = [float(np.linalg.norm(b - a)) for a, b in zip(pts, pts[1:])]
    total = sum(seg)
    d_acc, d_dec = speed * accel / 2, speed * decel / 2
    cruise = max(0.0, total - d_acc - d_dec)
    t_cruise = cruise / speed
    T = accel + t_cruise + decel

    def s_of(t):
        if t <= accel:
            return speed * t * t / (2 * accel)
        if t <= accel + t_cruise:
            return d_acc + speed * (t - accel)
        u = t - accel - t_cruise
        return min(total, d_acc + cruise + speed * u - speed * u * u / (2 * decel))

    def at(sd):
        sd = max(0.0, min(total, sd))
        for i, ln in enumerate(seg):
            if sd <= ln + 1e-9 or i == len(seg) - 1:
                u = sd / max(ln, 1e-9)
                return pts[i] + (pts[i + 1] - pts[i]) * min(1.0, u)
            sd -= ln
        return pts[-1]

    def wrap(a):
        return (a + 180.0) % 360.0 - 180.0

    out = []
    n = int(math.ceil(T / 0.1))
    for i in range(n + 1):
        t = min(i * 0.1, T)
        sd = s_of(t)
        pos, ahead, behind = at(sd), at(sd + 1.0), at(sd - 1.0)
        d = ahead - behind
        yaw = facing((0.0, 0.0), (float(d[0]), float(d[1]))) if np.linalg.norm(d) > 1e-6 else (out[-1][3] if out else 0.0)
        if yaw_end is not None:
            u = max(0.0, min(1.0, 1.0 - (T - t) / turn_end))
            yaw = yaw + wrap(yaw_end - yaw) * (u * u * (3 - 2 * u))
        out.append((t, float(pos[0]), float(pos[1]), yaw))
    return out, T


ROUTES = {}  # k: ([(shot time, x, z, yaw)] from the first moment the actor is in the shot, the time it is in its place, start)
for _k, (_ta, _off, _r0) in ARRIVE.items():
    _pa = _k * 30.0
    _line, _T = travel(way(_k), SPEED, yaw_end=facing(ring(_pa, LANE_R), CENTRE), turn_end=0.8)
    _tl = _ta - STEP  # (stopped at the lane's end, turned to the table; now the step back into the place)
    _t0 = _tl - _T
    _samples = [(_t0 + t, x, z, yaw) for t, x, z, yaw in _line]
    if _t0 < 0.0:  # (already walking when the shot opens: the sample at 0 is interpolated on the line)
        _before = [s for s in _samples if s[0] <= 0.0][-1]
        _after = [s for s in _samples if s[0] > 0.0][0]
        _u = (0.0 - _before[0]) / (_after[0] - _before[0])
        _first = (0.0, _before[1] + (_after[1] - _before[1]) * _u, _before[2] + (_after[2] - _before[2]) * _u, _before[3])
        _samples = [_first] + [s for s in _samples if s[0] > 0.0]
    ROUTES[_k] = (_samples, _ta, _t0)


# --- the hands --------------------------------------------------------------------------------------------------------

def hand(side, joints, target, direction=None):
    """The arm value that puts this side's fist on `target` (the character's frame) for a body posed by `joints`."""
    return body_reach(side, joints, (0.0, 0.0, 0.0), target, direction)


WALK_BODY = dict(root=(LEAN, 0, 0), neck=(4, 0, 0))
HOLD_BODY = dict(root=(-1.5, 0, 0), neck=(0, 0, 0))

# Where a fist goes, in the character's frame (the floor under the root, facing -z, +x his right); each is 1.6 to 2.3
# studs from the shoulder's pivot (r6-reach-limits.md) and was checked as fist against target.
TARGETS = {
    "collar_r": (1, (0.55, 3.75, -1.35)),
    "collar_l": (-1, (-0.55, 3.7, -1.35)),
    "chest_l": (-1, (-0.5, 3.2, -1.35)),
    "pocket_r": (1, (1.2, 2.35, -0.6)),
    "pocket_l": (-1, (-1.2, 2.35, -0.6)),
    "belly_r": (1, (0.5, 2.7, -1.45)),
    "belly_l": (-1, (-0.5, 2.5, -1.45)),
    "hem_r": (1, (1.05, 2.5, -1.0)),
    "wrist_l": (1, (-0.3, 2.75, -1.45)),  # the right fist on the left wrist, the left forearm across the belly
    "watch_l": (-1, (-0.35, 3.45, -1.5)),  # the left wrist raised to read
}


def arm(name, joints=WALK_BODY):
    side, target = TARGETS[name]
    return hand(side, joints, target)


def to(local, point, yaw):
    """Yaw (degrees, + to his left) a head turns to look at a point in the set, from a place and a heading."""
    a = math.radians(yaw)
    dx, dz = point[0] - local[0], point[1] - local[1]
    lx, lz = math.cos(a) * dx - math.sin(a) * dz, math.sin(a) * dx + math.cos(a) * dz
    return math.degrees(math.atan2(-lx, -lz))


def clip(k, style):
    """One seat's clip: its body at the walk and at the place; `style(m, k, ta, t0)` adds its business."""
    m = Motion(f"MeetingIntro_seat{k}", LENGTH, note="The meeting intro: arriving at the table.")
    if k in ROUTES:
        samples, ta, ts = ROUTES[k]
        t0 = max(0.0, ts)
        done = ta + 0.45  # (the turn to the table is finished and the weight has settled)
        m.key(0.0, **WALK_BODY, **STAND)
        m.key(ta - 0.2, root=(LEAN * 0.6, 0, 0), neck=(2, 0, 0))
        m.key(done, **HOLD_BODY)
        m.key(LENGTH, root=(-1.0, 0, 0), neck=(-1, 0, 0))
        soft(m)
        if ts > 0.0:
            m.plant(None, ts - 0.05, stance=0.05)
        m.plant(done + 0.15, None, stance=0.05)
        walking(m, t0, done, speed=SPEED, arms=0.55)
    else:
        m.key(0.0, root=(-1, 0, 0), neck=(0, 0, 0), **STAND)
        m.key(LENGTH, root=(-1, 0, 0), neck=(0, 0, 0))
        soft(m).plant(stance=0.05)
        ta, ts = 0.0, 0.0
    style(m, k, ta, ts)
    m.build()
    return m


# --- the business -------------------------------------------------------------------------------------------------------

def arms_at(m, t, r=None, l=None, ease="smooth"):
    """Key one or both arms at t (the other keeps going)."""
    kw = {}
    if r is not None:
        kw["rShoulder"] = r
    if l is not None:
        kw["lShoulder"] = l
    m.key(t, ease, **kw)


def look(m, t, yaw, pitch=0.0, ease="smooth"):
    m.key(t, ease, neck=(pitch, yaw, 0))


def settle_arms(m, k, ta, r, l, at=0.5):
    """The arms arrive in their resting pose `at` seconds after the stop, a short move with a little overshoot."""
    if r is not None:
        beat(m, ta + at, dur=0.4, antic=0.1, over=0.12, rShoulder=r)
    if l is not None:
        beat(m, ta + at + 0.12, dur=0.4, antic=0.1, over=0.1, lShoulder=l)


def glance(m, k, t, yaw, back=0.6, pitch=0.0):
    """The head leads: a quick look at `yaw`, held a moment, then back to the table."""
    look(m, t - 0.34, 0.0)
    look(m, t - 0.17, -0.16 * yaw, 0.0)  # (drawn back the other way first)
    look(m, t, yaw, pitch, "out")
    look(m, t + back, yaw * 0.9, pitch)
    look(m, t + back + 0.3, 0.0)


def s4(m, k, ta, ts):
    # tugs his collar as he hurries in, then a look back at the one behind him, then the left hand to the pocket
    arms_at(m, 0.55, arm("collar_r"))
    arms_at(m, 0.95, arm("collar_r"))
    arms_at(m, 1.2, J((6, 0, 2)), J((6, 0, -10)))
    glance(m, k, 0.9, -38.0, back=0.5)
    settle_arms(m, k, ta, None, arm("pocket_l", HOLD_BODY), at=0.2)
    glance(m, k, ta + 1.4, 32.0, back=0.8)
    root_shift(m, ta + 1.2, -6.0, 3.0)
    beat(m, ta + 2.6, dur=0.4, antic=0.1, over=0.1, rShoulder=arm("belly_r", HOLD_BODY))


def s5(m, k, ta, ts):
    # a left wrist raised to read a watch while still walking, the head dipped to it; then the hands drop, one low; late on
    # a look across the table and the right hand into the pocket
    t = ta - 2.0
    arms_at(m, t - 0.5, None, J((5, 0, -2)))
    arms_at(m, t, None, arm("watch_l"))
    arms_at(m, t + 0.6, None, arm("watch_l"))
    look(m, t + 0.1, 0.0, -14.0)
    look(m, t + 0.65, 0.0, -14.0)
    look(m, t + 0.9, 14.0, 4.0)
    arms_at(m, t + 0.85, None, J((6, 0, -3)))
    settle_arms(m, k, ta, arm("belly_r", HOLD_BODY), None, at=0.2)
    glance(m, k, ta + 1.6, -34.0, back=0.7)
    beat(m, ta + 2.2, dur=0.4, antic=0.1, over=0.1, rShoulder=arm("pocket_r", HOLD_BODY))
    root_shift(m, ta + 1.9, 5.0, -2.5)


def s3(m, k, ta, ts):
    # carries a case file in the right hand and, as he stops, swings the arm and skids it across the table
    carry = arm("hem_r")
    arms_at(m, 0.0, carry)
    arms_at(m, ta - 0.5, carry)
    strike(m, ta + 0.28, wind=dict(rShoulder=J((-6, 0, 10)), root=(-1.5, -6, 2)),
           hit=dict(rShoulder=J((90, 0, -6)), root=(-15, 7, -2)), antic=0.2, travel=0.07, over=0.18, settle=0.35)
    beat(m, ta + 1.5, dur=0.55, antic=0.05, over=0.05, root=(-1.5, 0, 0))
    arms_at(m, ta + 1.0, J((8, 0, 2)))
    settle_arms(m, k, ta + 0.6, None, arm("pocket_l", HOLD_BODY), at=0.2)
    glance(m, k, ta + 0.7, 30.0, back=0.5)


def s2(m, k, ta, ts):
    # shrugs his coat off the shoulders as he stops (both arms drawn back, the right first, by different amounts), then
    # looks across at the one who threw the file
    arms_at(m, ta - 0.55, J((4, 0, 2)), J((4, 0, -2)))
    arms_at(m, ta - 0.1, J((-22, 0, 14)), None)
    arms_at(m, ta + 0.12, None, J((-12, 0, -12)))
    arms_at(m, ta + 0.5, J((9, 0, 4)), J((2, 0, -3)))
    m.key(ta - 0.1, "smooth", root=(-1, 2, 0))
    glance(m, k, ta + 0.5, -42.0, back=0.7)
    settle_arms(m, k, ta + 0.3, arm("pocket_r", HOLD_BODY), None, at=0.3)


def s11(m, k, ta, ts):
    # a hand through the front of the jacket as he comes in (a hand on the lapel), then looks about the room
    arms_at(m, 0.0, STAND["rShoulder"], arm("chest_l"))
    arms_at(m, ta - 0.4, None, arm("chest_l"))
    arms_at(m, ta + 0.05, None, J((6, 0, -3)))
    glance(m, k, ta + 0.25, 26.0, back=0.7)
    settle_arms(m, k, ta, arm("belly_r", HOLD_BODY), None, at=0.3)


def s10(m, k, ta, ts):
    # hands at his sides as he comes in, one to the pocket as he stops, the head to the others already there
    arms_at(m, ta + 0.1, None, J((7, 0, -3)))
    glance(m, k, ta - 0.6, -34.0, back=0.5)
    settle_arms(m, k, ta, None, arm("pocket_l", HOLD_BODY), at=0.15)
    arms_at(m, ta + 1.3, J((12, 0, 1)))


def s0(m, k, ta, ts):
    # pulls a cuff: the right fist across to the left wrist, the left forearm across the belly, then drops the right hand
    arms_at(m, 0.0, STAND["rShoulder"], STAND["lShoulder"])
    arms_at(m, ta - 0.9, None, arm("belly_l"))
    arms_at(m, ta - 0.5, arm("wrist_l"), arm("belly_l"))
    arms_at(m, ta + 0.1, arm("wrist_l"), arm("belly_l"))
    arms_at(m, ta + 0.5, J((6, 0, 2)), arm("belly_l"))
    glance(m, k, ta + 0.55, -30.0, back=0.5)
    beat(m, ta + 1.3, dur=0.4, antic=0.1, over=0.1, lShoulder=arm("pocket_l", HOLD_BODY))
    beat(m, ta + 1.6, dur=0.4, antic=0.1, over=0.1, rShoulder=J((16, 0, 1)))


def s1(m, k, ta, ts):
    # touches his tie with the left hand, a look up at the table's light, the right hand into the pocket
    arms_at(m, ta - 0.7, None, J((4, 0, -2)))
    arms_at(m, ta - 0.3, None, arm("collar_l"))
    arms_at(m, ta + 0.25, None, arm("collar_l"))
    arms_at(m, ta + 0.55, None, J((6, 0, -3)))
    look(m, ta + 0.2, 0.0, 6.0)
    settle_arms(m, k, ta, arm("pocket_r", HOLD_BODY), None, at=0.35)


def s8(m, k, ta, ts):
    # arms folded across the belly as he stops, one fist tucked into the elbow, then a look at the others
    arms_at(m, ta - 0.3, None, J((4, 0, -2)))
    settle_arms(m, k, ta, arm("wrist_l", HOLD_BODY), arm("belly_l", HOLD_BODY), at=0.25)
    glance(m, k, ta + 0.5, 28.0, back=0.6)


def root_shift(m, t, yaw, roll, pitch=-1.5, dur=0.45):
    """The weight moves: the shoulders turn `yaw` degrees and the body rolls `roll`, in a quick move that settles."""
    beat(m, t, dur=dur, antic=0.12, over=0.15, root=(pitch, yaw, roll))


def waiting(m, k, script):
    """Someone already in their place, in the dark, watching the others come in: `script` is a list of (time, what, ...)."""
    x, z = seat(k)
    heading = facing((x, z), CENTRE)
    for step in script:
        t, what = step[0], step[1]
        if what == "look":
            glance(m, k, t, to((x, z), step[2], heading), back=step[3] if len(step) > 3 else 0.8)
        elif what == "shift":
            root_shift(m, t, step[2], step[3])
        elif what == "arms":
            r, left = step[2], step[3]
            if r is not None:
                beat(m, t, dur=0.42, antic=0.22, over=0.12, rShoulder=arm(r, HOLD_BODY) if isinstance(r, str) else r)
            if left is not None:
                beat(m, t + 0.1, dur=0.42, antic=0.22, over=0.1, lShoulder=arm(left, HOLD_BODY) if isinstance(left, str) else left)


def s6(m, k, ta, ts):
    # north side, under the screen: a hand in the pocket, watches the east side come in, then the west
    waiting(m, k, [(0.9, "arms", "pocket_r", J((6, 0, -2))), (1.9, "look", (15.0, -8.0)), (2.6, "shift", 6.0, 2.5),
                   (3.9, "look", (-8.0, 15.0)), (4.9, "arms", J((10, 0, 3)), "belly_l"), (5.6, "shift", -6.0, -2.0),
                   (6.4, "look", (8.0, 15.0), 0.7)])


def s7(m, k, ta, ts):
    # next to him: arms folded, the head turned the other way at first; a long look at the south side coming in
    m.key(0.0, "smooth", neck=(0, -10, 0))
    waiting(m, k, [(0.7, "arms", "wrist_l", "belly_l"), (2.2, "look", (15.0, -8.0)), (3.2, "shift", 7.0, 2.0),
                   (4.5, "look", (-5.0, 16.0), 1.0), (5.4, "arms", "belly_r", J((7, 0, -2))), (6.2, "shift", -5.0, -2.5)])


def s9(m, k, ta, ts):
    # the west side: a hand at the lapel from the start; watches the others come round, a nod, weight to the other foot
    waiting(m, k, [(0.5, "arms", J((5, 0, 2)), "chest_l"), (1.2, "shift", 7.0, -2.5), (1.8, "look", (-14.0, -8.0)),
                   (2.9, "shift", -6.0, 2.0), (4.0, "look", (-8.0, 15.0)), (4.7, "shift", 8.0, -2.0),
                   (5.2, "arms", "pocket_r", J((10, 0, -16))), (6.0, "look", (8.0, 15.0), 0.8)])


def s10(m, k, ta, ts):
    # beside him: the right hand on the belly, the left hanging; looks across the table, then to the door side
    waiting(m, k, [(0.8, "arms", "belly_r", J((5, 0, -2))), (2.1, "look", (15.0, 8.0)), (3.3, "shift", 6.0, -2.5),
                   (4.4, "look", (-8.0, -15.0), 0.9), (5.3, "arms", J((12, 0, 2)), "pocket_l"), (6.1, "shift", -5.0, 2.0)])


STYLES = {0: s0, 1: s1, 2: s2, 3: s3, 4: s4, 5: s5, 6: s6, 7: s7, 8: s8, 9: s9, 10: s10, 11: s11}

shot = Shot(NAME, "Meeting", LENGTH, note="The meeting intro: the survivors arrive at the war room.")
shot.room = None
CLIPS = {}
for k in range(12):
    motion = clip(k, STYLES[k])
    CLIPS[k] = motion
    x, z = seat(k)
    centre = facing((x, z), CENTRE)
    if k in ROUTES:
        samples, ta, ts = ROUTES[k]
        a = shot.actor(f"seat:{k}", motion, show=(0.0 if ts <= 0.0 else max(0.0, ts - 0.1), None))
        for t, px, pz, yaw in samples:
            a.mark(round(t, 3), (round(px, 3), 0.0, round(pz, 3)), round(yaw, 2), "linear")
        a.mark(ta, (round(x, 3), 0.0, round(z, 3)), round(centre, 2), "smooth")
        if ta < LENGTH:
            a.mark(LENGTH, (round(x, 3), 0.0, round(z, 3)), round(centre, 2), "linear")
    else:
        a = shot.actor(f"seat:{k}", motion)
        a.mark(0.0, (round(x, 3), 0.0, round(z, 3)), round(centre, 2))
footwork.apply(shot)  # (the feet planted where they come down, stepping after the body: cinema/footwork.py)

# --- the case file --------------------------------------------------------------------------------------------------------

T_THROW = ARRIVE[3][0] + 0.28 + 0.07  # the arm's snap lands here: the file leaves the fist
FOLDER = shot.prop("CaseFolder", scale=0.8)
_pos = None
for _i in range(int(round(T_THROW * 30)) + 1):  # carried flat in the right fist
    _t = _i / 30.0
    _h = framing.part(shot, "seat:3", _t, "hand")
    _pos = (round(float(_h[0]), 3), round(float(_h[1]) - 0.35, 3), round(float(_h[2]), 3))
    _yaw = framing.actor(shot, "seat:3").path.value(_t)[3]
    FOLDER.at(round(_t, 3), _pos, (0, round(float(_yaw) + 90.0, 1), 0), "linear")
_start = np.array(_pos)
_dir = np.array([-_start[0], 0.0, -_start[2]])
_dir = _dir / np.linalg.norm(_dir)
_land = _dir * (np.linalg.norm([_start[0], _start[2]]) - 12.4) + _start
_land[1] = 3.36
_stop = _dir * (np.linalg.norm([_start[0], _start[2]]) - 8.9) + _start
_stop[1] = 3.36
_spin = 14.0
FOLDER.at(round(T_THROW + 0.16, 3), tuple(round(float(v), 3) for v in _land), (0, round(float(_yaw) + 90.0 + 6, 1), 0), "out")
for _u, _w in ((0.25, 0.55), (0.5, 0.82), (0.75, 0.95), (1.0, 1.0)):
    _p = _land + (_stop - _land) * _w
    FOLDER.at(round(T_THROW + 0.16 + 0.75 * _u, 3), tuple(round(float(v), 3) for v in _p),
              (0, round(float(_yaw) + 90.0 + 6 + _spin * _w, 1), 0), "linear")
FOLDER.at(LENGTH, tuple(round(float(v), 3) for v in _stop), (0, round(float(_yaw) + 90.0 + 6 + _spin, 1), 0), "linear")


# --- the cameras ---------------------------------------------------------------------------------------------------------
# Every one held by a hand (a locked frame is a tripod) and kept long: the actors are 5 studs tall and the hair is blocky.
# The table is the foreground of A, B and C (a bright band under the people, the depth the old locked frames lacked); its far
# edge hides the legs of whoever stands at a place, so A looks down over it to see the walkers whole.
CUT_A, CUT_B, CUT_C = 1.9, 4.1, 5.5
# A: from over the table's north-east, looking at the gap by the records door: the first one comes in out of the dark between
# the chairs, tugging at his collar, the case wall of photographs behind him.
shot.pan(0.0, CUT_A, "seat:4", (5.0, 8.4, -2.0), aim="Torso", dy=0.5, fov=38, operator=True, seed=11, shake=0.5,
         drift=(-1.5, 0.2, 1.5), fov_to=32, ease_move=True)
# B: low over the table's top at its east side: seat 3 stops, swings his arm, the file skids across the lit wood at us.
shot.pan(CUT_A, CUT_B, "seat:3", (6.0, 5.3, 0.7), aim="Torso", dy=0.9, fov=36, cut=True, operator=True, seed=12, shake=0.4,
         drift=(0.9, 0.0, 0.2), fov_to=33, ease_move=True)
# C: from over the table's south side, looking south: seats 11, 0 and 1 come in to their places.
shot.pan(CUT_B, CUT_C, "seat:0", (1.5, 5.8, 2.5), aim="Torso", dy=0.6, fov=40, cut=True, operator=True, seed=13, shake=0.45,
         drift=(-1.2, 0.0, 0.3), fov_to=34, ease_move=True)
# D: high and wide from the south-west corner: the last ones come in and the ring is full under the chandelier.
framing.dolly(shot, CUT_C, LENGTH, (-12.0, 11.2, 24.0), (-9.5, 10.6, 21.0), (0.0, 3.0, -3.0), (0.0, 3.2, -2.0), fov0=52.0,
              fov1=46.0, shake=0.4, seed=14, cut=True)

# --- the light -------------------------------------------------------------------------------------------------------------
# The set is lit by the ring chandelier over the table and nothing else: a body out at its edge is a cut-out. Each cut gets a
# cold key from above and in front and a warm rim from behind, on the people it films (skin never glows); the lift of the
# grade is the shot's own, the game's meeting look is another ticket's.
shot.grade = (0.18, -0.2, 0.05, (226, 232, 255))
LIGHTS = (
    # (window, key's place, key's aim, rim's place, rim's aim)
    ((0.0, CUT_A + 0.1), (-1.0, 12.0, 4.0), (17.0, 3.0, -4.0), (28.0, 10.0, -16.0), (14.0, 3.5, -6.0)),
    ((CUT_A - 0.1, CUT_B + 0.1), (-2.0, 11.0, 2.0), (16.5, 3.0, -1.0), (30.0, 9.0, 8.0), (16.0, 3.5, 0.0)),
    ((CUT_B - 0.1, CUT_C + 0.1), (-3.0, 12.0, -9.0), (4.0, 3.0, 15.5), (6.0, 10.0, 30.0), (3.0, 3.5, 16.0)),
    ((CUT_C - 0.1, LENGTH), (-12.0, 17.0, 14.0), (-2.0, 3.0, -4.0), (4.0, 16.0, -26.0), (-2.0, 3.5, 2.0)),
)
for (window, key, kaim, rim, raim) in LIGHTS:
    wide = window[0] >= CUT_C - 0.2
    shot.light("spot", key, kaim, color=(200, 215, 255), brightness=2.0 if wide else 2.4, range=44 if wide else 34,
               angle=80 if wide else 62, shadows=False, show=window)
    shot.light("spot", rim, raim, color=(255, 196, 140), brightness=1.6 if wide else 1.8, range=44 if wide else 24,
               angle=75 if wide else 58, shadows=False, show=window)

# --- effects and sound ----------------------------------------------------------------------------------------------------
shot.event(0.0, "sfx", slot="mapRainGlass")
shot.event(T_THROW, "fx", name="pulse", punch=0.03, dur=0.4)
shot.event(T_THROW + 0.2, "fx", name="focus", slot="seat:3", part="Torso", radius=9.0, far=0.08, near=0.04, rack=0.0)
shot.event(LENGTH - 1.0, "sfx", slot="gavel")
