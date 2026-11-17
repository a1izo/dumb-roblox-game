"""The Operative's role cutscene (the briefing, seen only by that Operative), rebuilt from nothing on 2026-11-17 for the
owner's "redo the operative cutscene completely and make the badge way more high quality" (item 1b of
docs/handoff/animation-cutscene-plan-2026-11-13.md; reference art/refs/cinema/RoleOperative.toml). The old module
(role_taskforce.py) is kept, no longer imported.

What it is about: a Bureau agent alone in the locker room before the night's work takes each thing from the open locker,
checks it and puts it on (the badge first, then the cuffs, the earpiece, the tie), and every one makes them a little more
the Bureau; then they turn and walk out through the door. The one big action: take, check, wear, with weight on every
item, ending on the walk to the lit doorway. A quiet scene: slow long-lens cameras, no strikes. The captions (YOU ARE /
YOUR RULES / YOUR ALIAS, the "card" events) sit low left, so the subject lives on the right and high.

A  0.0-2.8   Wide and low from the room's corner, behind and to the left, creeping in: the open locker, the still figure
             facing it, hands low. The head lifts to the shelf; the left hand starts up.
B  2.8-5.2   From the east flank at head height on a long lens: the left hand takes the badge case off the shelf and brings
             it down to the chest; the head follows it and reads.
C  5.2-8.0   The badge insert: the case turned in the hand, leather first, then over to the shield; the light rakes across
             the metal as it tilts; THE BUREAU and the number read.
D  8.0-10.4  From the west flank past the open door: the case goes inside the jacket with a pat, the lapel is tugged.
E  10.4-13.0 From behind on the right: the cuffs taken off the shelf's lip, looked at, clipped on behind the left hip.
F  13.0-15.4 Close from the front: the turn to the room, the head tilts to the earpiece, the tie squared, the last look at
             the locker.
G  15.4-19.0 Wide and low from the west, the benches in front: the walk the length of the room to the lit doorway, out;
             the empty doorway, a cut to black.

The locker room (maps/venues/sets/locker.py, Sets scene space, origin x 360): x 349..371, z -7..7; the eighth locker (its
middle at x 361.5) stands open, its door swung out on the west edge (a plate from (360.79, -4.87) to (360.44, -3.58));
shelf at 6.0 (z -6.4..-4.96, x 360.84..362.16), hook at 5.4 on the back; the door in the south wall (x 359.5..363.5)."""

import math

import numpy as np

import posekit
from animlib import J
from cinema import footwork, framing
from cinema.acting import beat, body_reach, facing, hold, local_of, soft, walking
from cinema.shot import Shot
from motion import Motion

NAME = "RoleOperative"
LENGTH = 19.0
LX = 360.0
P0 = (362.6, -3.0)  # where they stand: east of the open door plate, the lockers' front 1 stud ahead of the chest
P1 = (361.75, -1.9)  # where they stand once they have stepped back from the lockers to turn to the room (a body facing west puts its arm in them)
Y0 = 12.0  # turned a little towards the open locker's mouth (yaw 0 faces -z, +90 faces -x)
SHELF_Y = 6.03
DOOR = (361.45, 7.6)  # past the doorway in the south wall
ROOM = 180.0  # facing the room
LOOKUP = 24.0  # the head back to see the shelf
CASE_SHELF_YAW = 40.0  # the case lying on the shelf, its face up


def world(p, yaw=Y0, place=P0):
    """A point in the actor's frame (the floor under the root, facing -z) in the set's space."""
    a = math.radians(yaw)
    return (place[0] + math.cos(a) * p[0] + math.sin(a) * p[2], p[1], place[1] - math.sin(a) * p[0] + math.cos(a) * p[2])


def char(p, yaw=Y0, place=P0):
    """A point in the set's space in the actor's frame."""
    return local_of(place, yaw, p)


# The things in the locker (the set's space): the badge case lies on the shelf's lip at the left, the cuffs hang over the
# lip at the right (the shelf is 6 studs up: a stretch, the arm nearly straight)
CASE_SHELF = (361.2, SHELF_Y + 0.05, -5.02)
CUFFS_SHELF = (361.95, SHELF_Y - 0.36, -4.9)
CUFF_SCALE = 0.6

REF_HIP = posekit.fk({})["Torso"] @ np.array([0.0, -1.0, 0.0, 1.0])


def body(lean, turn=0.0, roll=0.0):
    """A standing body leaning `lean` (- forward) about its hips (the hips stay over the feet)."""
    joints = dict(root=(lean, turn, roll))
    hip = posekit.fk(joints)["Torso"] @ np.array([0.0, -1.0, 0.0, 1.0])
    off = tuple(round(float(v), 3) for v in (REF_HIP[:3] - hip[:3]))
    return joints, off


def pt(part, joints, off, local):
    m = posekit.fk(joints, off)[part]
    return tuple(float(v) for v in (m @ np.array([*local, 1.0]))[:3])


class Hand:
    """A fist put on a target found from the body of its own key (body_reach)."""

    def __init__(self, side, target, direction=None, slide=0.55):
        self.side, self.target, self.direction, self.slide = side, target, direction, slide

    def __call__(self, j, o, n):
        return body_reach(self.side, j, o, self.target(j, o, n), self.direction, max_slide=self.slide)

    def shift(self, dx=0.0, dy=0.0, dz=0.0):
        return Hand(self.side, lambda j, o, n, f=self.target: tuple(np.array(f(j, o, n)) + np.array([dx, dy, dz])),
                    self.direction, self.slide)


def shoulder(side, joints, off):
    return np.array(pt("Torso", joints, off, (side * 1.0, 0.5, 0.0)))


class Held(Hand):
    """A fist that holds something of radius r whose middle is at center(j, o, n): the arm points straight at it and its
    end touches it (the object's middle is r past the arm's end, along the arm)."""

    def __init__(self, side, center, r, slide=0.55, bend=(0.0, 0.0, 0.0)):
        self.side, self.center, self.r, self.slide, self.bend = side, center, r, slide, np.array(bend, float)

    def axis(self, j, o, n):
        d = np.array(self.center(j, o, n), float) - shoulder(self.side, j, o) + self.bend
        return d / np.linalg.norm(d)

    def target(self, j, o, n):
        return tuple(np.array(self.center(j, o, n), float) - (0.15 + self.r) * self.axis(j, o, n))

    def __call__(self, j, o, n):
        return body_reach(self.side, j, o, self.target(j, o, n), tuple(self.axis(j, o, n)), max_slide=self.slide)

    def shift(self, dx=0.0, dy=0.0, dz=0.0):
        return Held(self.side, lambda j, o, n, f=self.center: tuple(np.array(f(j, o, n)) + np.array([dx, dy, dz])), self.r,
                    self.slide, tuple(self.bend))


CHECKS = []  # (time, hand, joints, offset, neck): every placed hand, for the lab's numbers

op = Motion("RoleOperative_self", LENGTH, note="The Operative's role cutscene: the badge, the cuffs, the earpiece, the tie, out.")


def key(t, ease, lean, turn=0.0, roll=0.0, neck=(0.0, 0.0, 0.0), right=None, left=None, yaw=Y0):
    """A key: the body, the head, and each arm as a function of the body (or a value, or None for the arm at rest)."""
    joints, off = body(lean, turn, roll)
    values = {}
    for name, arm, side in (("rShoulder", right, 1), ("lShoulder", left, -1)):
        if arm is None:
            arm = rest_arm(name, lean)
        elif isinstance(arm, tuple):  # ("rest", pitch, roll): the resting arm moved a little (the free arm is never dead)
            base = rest_arm(name, lean)
            arm = J((base["r"][0] + arm[1], base["r"][1], base["r"][2] + arm[2]), base["p"])
        if callable(arm):
            values[name] = arm(joints, off, neck)
            if isinstance(arm, Hand):
                CHECKS.append((round(t, 3), name, arm, {**joints, **values}, off, neck, yaw))
        else:
            values[name] = arm
    op.key(round(t, 4), ease, offset=off, neck=neck, **values, **joints)


REST = dict(rShoulder=J((9, 0, -4), (0, 0, 0)), lShoulder=J((3, 0, 7), (0, 0, 0)))


def rest_arm(name, lean):
    """An arm at rest, hanging straight down in the room whatever the lean of the torso (a body leaned 25 degrees would swing it
    into the lockers)."""
    base = REST[name]
    return J((base["r"][0] + 0.9 * min(0.0, lean + 4.0), base["r"][1], base["r"][2]), base["p"])


def smooth_(u):
    u = max(0.0, min(1.0, u))
    return u * u * (3 - 2 * u)
SIDE_R = J((14, 0, -8), (0, 0, 0))  # the right arm a little forward of the hip, hanging

# ---- the hand targets: all in the actor's frame at yaw Y0 (char(...) of a set point) -----------------------------------


def _at(point, yaw=Y0):
    return lambda j, o, n, p=point, y=yaw: char(p, y)


CASE_C = (CASE_SHELF[0], CASE_SHELF[1] + 0.04, CASE_SHELF[2])
L_CASE = Held(-1, _at(CASE_C), 0.3, slide=1.0)  # closed on the case on the shelf (a stretch)
L_CASE_HOVER = Held(-1, _at((CASE_C[0] + 0.05, CASE_C[1] + 0.05, CASE_C[2] + 0.2)), 0.3, slide=1.0)

# the case held at the chest, the locker's mouth in front: the actor's frame
READ = (-0.25, 3.2, -1.8)
L_READ = Held(-1, lambda j, o, n: READ, 0.3, bend=(0.0, 0.0, 0.0))
L_READ_B = Held(-1, lambda j, o, n: (READ[0] + 0.12, READ[1] + 0.12, READ[2] - 0.05), 0.3)
L_READ_C = Held(-1, lambda j, o, n: (READ[0] - 0.05, READ[1] + 0.22, READ[2] - 0.1), 0.3)
L_UP = Held(-1, lambda j, o, n: (READ[0] + 0.1, READ[1] + 0.3, READ[2] - 0.05), 0.3)  # lifted a little, the light on it

# the left chest (the jacket's inside pocket) and the lapel
POCKET = (-0.45, 3.55, -0.78)
L_POCKET = Hand(-1, lambda j, o, n: POCKET, (0.45, -0.25, -0.85))
L_POCKET_IN = Hand(-1, lambda j, o, n: (POCKET[0], POCKET[1] - 0.04, POCKET[2] + 0.06), (0.45, -0.25, -0.85))
R_LAPEL = Hand(1, lambda j, o, n: (-0.6, 3.65, -0.8), (-0.9, 0.0, -0.45))
R_LAPEL_OUT = Hand(1, lambda j, o, n: (-0.8, 3.45, -1.0), (-0.9, -0.1, -0.45))

# the cuffs on the shelf's lip
L_CUFFS = Held(-1, _at(CUFFS_SHELF), 0.25, slide=1.0)
L_CUFFS_HOVER = Held(-1, _at((CUFFS_SHELF[0] - 0.1, CUFFS_SHELF[1] + 0.15, CUFFS_SHELF[2] + 0.35)), 0.25, slide=1.0)
CUFFS_LOOK = (-0.2, 3.7, -1.8)
L_CUFFS_LOOK = Held(-1, lambda j, o, n: CUFFS_LOOK, 0.25)
L_CUFFS_LOOK_B = Held(-1, lambda j, o, n: (CUFFS_LOOK[0] + 0.1, CUFFS_LOOK[1] + 0.12, CUFFS_LOOK[2] - 0.05), 0.25)
# behind the left hip: the clip on the belt, at the back
BELT_L = (-1.0, 2.35, 0.75)
L_BELT = Hand(-1, lambda j, o, n: BELT_L, (0.15, -0.55, 0.8), slide=0.7)
L_BELT_OUT = Hand(-1, lambda j, o, n: (BELT_L[0] - 0.1, BELT_L[1] + 0.3, BELT_L[2] + 0.1), (0.15, -0.5, 0.8), slide=0.7)

# the earpiece and the tie, the actor now facing the room (yaw ROOM): the frame is the actor's own
L_MIC = Hand(-1, lambda j, o, n: (-0.35, 3.85, -0.85), (0.5, 0.0, -0.8))  # at the lapel: pressed to talk
R_TIE = Hand(1, lambda j, o, n: (0.25, 3.55, -0.85), (-0.8, -0.2, -0.55))
R_TIE_OUT = Hand(1, lambda j, o, n: (0.3, 3.25, -0.95), (-0.7, -0.2, -0.6))
L_HEM = Hand(-1, lambda j, o, n: (-1.1, 2.55, -0.55), (-0.1, -0.7, -0.7), slide=0.7)
R_HEM = Hand(1, lambda j, o, n: (1.1, 2.55, -0.55), (0.1, -0.7, -0.7), slide=0.7)

# ---- the key poses (blocked first; the timing between them is worked out afterwards) --------------------------------------
# The order: facing the open locker (A, B): the cuffs off the shelf's lip, looked at, clipped on behind; the case taken off
# the shelf (E); the turn to the room with the case at the chest; the case read and turned in the light (C, the insert), put
# inside the jacket (D); the earpiece and the tie (F); the last look at the locker; the walk to the door (G).
T_SEE = 1.6  # the head to the shelf
T_CUFF = 2.9  # the fist closes on the cuffs
T_CLIP = 4.85  # the cuffs on the belt
T_SEE2 = 5.4
T_TAKE = 6.25  # the fist closes on the case
T_TURN0, T_TURN1 = 6.6, 7.7  # the turn to the room
T_READ = 7.9
T_FLIP = 8.75  # the case turned over to the shield
T_AWAY = 10.35  # the case at the pocket
T_MIC = 12.0
T_TIE = 13.15
T_HEM = 13.95
T_LOOK = 14.55
T_WALK = 15.3

# 0.0 standing square to the locker, the head a little down, the arms low
key(0.0, "smooth", -2, neck=(-10, 4, 0), right=("rest", 8, 12))
key(1.15, "sine", -2, neck=(-10, 4, 0), right=("rest", 8, 12))
# 1.6 the head comes up to the shelf; the body draws in a little first (a breath)
key(T_SEE, "sine", -5, neck=(LOOKUP, 0, 0), right=("rest", 10, 4))
# 2.1 the left hand draws back a hair, then up to hang under the cuffs; the body leans into the stretch
key(2.1, "sine", -6, neck=(LOOKUP, 0, 0), left=L_CUFFS_HOVER.shift(0.0, -0.35, 0.5), right=("rest", 10, 4))
key(2.55, "sine", -9, turn=-2, neck=(LOOKUP, 0, 0), left=L_CUFFS_HOVER, right=("rest", -8, -4))
key(T_CUFF, "out", -10, turn=-2, neck=(LOOKUP, 0, 0), left=L_CUFFS, right=("rest", -8, -4))
key(T_CUFF + 0.2, "sine", -10, turn=-2, neck=(LOOKUP, 0, 0), left=L_CUFFS, right=("rest", -8, -4))
# 3.2 the cuffs come down out of the locker and are looked at (they swing): the weight of them; the free hand goes out a little
key(3.55, "sine", -10, turn=2, neck=(-10, -3, 0), left=L_CUFFS_LOOK, right=("rest", 10, 6))
key(4.1, "sine", -8, turn=2, neck=(-14, -3, 0), left=L_CUFFS_LOOK_B, right=("rest", 10, 6))
# 4.5 the left arm goes down and behind to the belt, the body turning a little with it
key(T_CLIP - 0.35, "sine", -9, turn=4, neck=(-8, 6, 0), left=L_BELT_OUT, right=("rest", 6, 2))
key(T_CLIP, "out", -10, turn=4, neck=(-4, 8, 0), left=L_BELT, right=("rest", -12, -3))
key(5.2, "sine", -4, turn=0, neck=(2, 0, 0), right=("rest", 4, 0))
# 5.4 the head to the shelf again; the left hand up for the case
key(T_SEE2, "sine", -4, neck=(LOOKUP - 2, 0, 0), right=("rest", 14, 3))
key(5.85, "sine", -9, turn=-2, neck=(LOOKUP + 2, 0, 0), left=L_CASE_HOVER, right=("rest", -10, -4))
key(T_TAKE, "out", -11, turn=-2, neck=(LOOKUP + 4, 0, 0), left=L_CASE, right=("rest", -10, -4))
key(T_TAKE + 0.1, "sine", -11, turn=-2, neck=(LOOKUP + 4, 0, 0), left=L_CASE, right=("rest", -10, -4))
# 6.5 the case comes down out of the locker and the body turns to the room with it, the head following it down
key(T_TURN0, "sine", -12, turn=2, neck=(-8, -4, 0), left=L_READ_B, right=("rest", 6, 4))
key(T_READ, "smooth", -8, turn=4, neck=(-24, 0, 3), left=L_READ)
key(8.4, "sine", -8, turn=4, neck=(-26, 0, 4), left=L_READ)
# 8.5 the case lifted to the light (the insert)
key(T_FLIP, "out", -9, turn=3, neck=(-26, -4, 4), left=L_UP, right=SIDE_R)
key(9.35, "sine", -8, turn=3, neck=(-24, -4, 3), left=L_UP, right=SIDE_R)
key(9.85, "sine", -8, turn=3, neck=(-26, 0, 4), left=L_READ_C, right=SIDE_R)
# 10.0 a breath, the case drawn in to the chest, patted in
key(10.05, "sine", -7, turn=2, neck=(-20, 0, 2), left=L_READ_C.shift(0.1, -0.2, 0.3), right=None)
key(T_AWAY, "sine", -6, turn=2, neck=(-16, 0, 0), left=L_POCKET, right=None)
key(10.65, "out", -9, turn=2, neck=(-14, 0, 0), left=L_POCKET_IN, right=None)  # the pat: a little sink
key(10.95, "sine", -5, turn=0, neck=(-8, 0, 0), left=L_POCKET, right=None)
key(11.35, "sine", -4, turn=0, neck=(-4, 0, 0), left=None, right=None)  # (the jacket settled)
key(T_MIC - 0.25, "sine", -3, turn=0, neck=(4, 0, 0))
# 12.0 a hand to the lapel, the head tilting to listen
key(T_MIC, "out", -3, turn=-2, roll=2, neck=(3, -14, 12), left=L_MIC)
key(T_MIC + 0.6, "sine", -3, turn=-2, roll=2, neck=(3, -14, 12), left=L_MIC)
# 13.15 the tie squared with the right hand, the left hand down; the head level
key(T_TIE - 0.25, "sine", -3, turn=0, neck=(2, -4, 4), left=None, right=R_TIE_OUT)
key(T_TIE, "out", -4, turn=0, neck=(-4, 0, 2), right=R_TIE)
key(13.6, "sine", -2, turn=0, neck=(-2, 0, 0), right=R_TIE_OUT)
# 13.95 both hands tug the jacket hem; the chest comes up
key(T_HEM, "out", -1, turn=0, neck=(2, 0, 0), left=L_HEM, right=R_HEM)
# 14.55 the last look at the locker: the shoulders and the head turn back to it, then away
key(T_LOOK, "sine", -2, turn=-26, neck=(2, -48, 2), right=("rest", 14, 9))
key(T_WALK - 0.15, "sine", -2, turn=-26, neck=(2, -48, 2), right=("rest", 14, 9))
key(T_WALK + 0.35, "sine", -3, turn=0, neck=(2, 0, 0))
key(LENGTH, "sine", -4, turn=0, neck=(2, 0, 0))
# The big arm moves drawn back a little first (the motion report wants a wind-up before them): each one lands at `t`
def _cur(joint, t):
    v = op.channels[joint].value(t)
    return J(tuple(float(x) for x in v[:3]), tuple(float(x) for x in v[3:6]))



for t_a, t_b in ((1.62, 2.17), (2.17, 2.55), (4.28, 4.6), (5.05, 5.85), (6.37, 7.18), (10.2, 11.4), (11.82, 12.03)):
    beat(op, t_b, t_b - t_a, antic=0.4, over=0.0, lShoulder=_cur("lShoulder", t_b))
for t_a, t_b in ((12.62, 12.95), (12.95, 13.15), (10.4, 10.95)):
    beat(op, t_b, t_b - t_a, antic=0.4, over=0.0, rShoulder=_cur("rShoulder", t_b))
beat(op, 7.75, 1.37, antic=0.3, over=0.0, neck=_cur("neck", 7.75))
soft(op, head=3.2, arms=3.6, head_damp=0.6, arm_damp=0.55)
op.plant(None, T_WALK - 0.1, stance=0.06)
walking(op, T_WALK, LENGTH + 1.0, speed=3.8, arms=0.25)
op.build()

# ---- the lab: every placed hand against its target (DG_LAB=1) ------------------------------------------------------------
import os  # noqa: E402

if os.environ.get("DG_LAB"):
    for t_, name_, arm_, joints_, off_, neck_, yaw_ in CHECKS:
        parts_ = posekit.fk(joints_, off_)
        arm_part = "Right Arm" if name_ == "rShoulder" else "Left Arm"
        fist_ = (parts_[arm_part] @ np.array([0.0, -0.85, 0.0, 1.0]))[:3]
        tgt_ = np.array(arm_.target(joints_, off_, neck_))
        sh_ = shoulder(1 if name_ == "rShoulder" else -1, joints_, off_)
        print("[reach] t=%5.2f %s fist-to-target %.2f, shoulder-to-target %.2f, fist at %s" % (
            t_, name_[0], np.linalg.norm(fist_ - tgt_), np.linalg.norm(tgt_ - sh_), tuple(round(float(v), 2) for v in fist_)))

# The shot --------------------------------------------------------------------------------------------------

shot = Shot(NAME, "Sets", LENGTH, note="The Operative's role cutscene: the locker room, gearing up.")
shot.room = (LX - 11.0, -7.0, LX + 11.0, 7.0, 11.0)

FACING = ROOM - 8.0
me = shot.actor("self", op)
me.mark(0.0, (P0[0], 0.0, P0[1]), Y0)
me.mark(T_TAKE + 0.05, (P0[0], 0.0, P0[1]), Y0)
me.mark(T_TURN0 + 0.45, (P1[0], 0.0, P1[1]), Y0)  # (a step back from the lockers first: turning in front of them swung an arm in)
me.mark(T_TURN1, (P1[0], 0.0, P1[1]), FACING)  # (turned to the room, a little off square)
me.mark(T_WALK - 0.1, (P1[0], 0.0, P1[1]), FACING)
# the walk: eased up and down, along the room to the doorway and out (no pivot after a stop)
START = (P1[0], P1[1] + 0.7)
STEPS = 40
for i in range(1, STEPS + 1):
    u = i / STEPS
    s = u * u * (3 - 2 * u)  # (eased at both ends)
    x = START[0] + (DOOR[0] - START[0]) * smooth_(min(1.0, s / 0.14))  # (over to the doorway first: the left arm clears the bench and the jamb)
    z = START[1] + (DOOR[1] - START[1]) * s
    me.mark(round(T_WALK + 0.3 + (LENGTH - T_WALK - 0.3) * u, 3), (x, 0.0, z), ROOM, "linear")
footwork.apply(shot)

# The things -----------------------------------------------------------------------------------------------------


def sampled(m, t0, t1, step=1 / 30):
    """(t, {part: matrix}) every frame as the baked clip plays (the springs run, the feet planned)."""
    count = int(round((t1 - t0) / step))
    times = [t0 + i * step for i in range(count + 1)]
    sprung = m._sprung(times) if m.springs else None
    out = []
    for i, t in enumerate(times):
        pose, off = m.sample(t, sprung, i)
        joints = {j: J(v[:3], v[3:]) if np.any(np.abs(v[3:]) > 1e-4) else tuple(v[:3]) for j, v in pose.items()}
        out.append((t, posekit.fk(joints, off)))
    return out


def smooth(u):
    u = max(0.0, min(1.0, u))
    return u * u * (3 - 2 * u)


def piecewise(keys, t):
    """keys: [(t, value)]: eased between."""
    if t <= keys[0][0]:
        return keys[0][1]
    for (a, va), (b, vb) in zip(keys, keys[1:]):
        if t <= b:
            return va + (vb - va) * smooth((t - a) / max(1e-6, b - a))
    return keys[-1][1]


def yaw_at(t):
    return float(me.path.value(t)[3])


def place_at(t):
    v = me.path.value(t)
    return (float(v[0]), float(v[2]))


FIST = np.array([0.0, -0.85, 0.0, 1.0])

# the badge case: lies on the shelf, taken, brought round to the room, read (its leather to the lens), turned over to the shield
# and tilted in the light, put away. Its face is the model's -z; yaw theta faces it along (-sin, -cos).
PITCH_KEYS = [(0.0, 90.0), (T_TAKE, 90.0), (T_TAKE + 0.4, 8.0), (T_READ, 0.0), (T_FLIP - 0.1, 0.0), (T_FLIP + 0.4, 20.0), (9.2, 12.0),
              (9.6, 30.0), (10.0, 18.0), (T_AWAY, 0.0)]
# (the shield's yaw once turned: FACING + 180 faces the room, the camera; then a tilt either way as the light moves across it)
# (the camera of the insert stands along the holding forearm's own line, a little out to his right: the arm is behind the
# case, never in front of it; the case is turned to face that camera)
ARM_LINE = np.array([1.1, 0.0, -1.0]) / np.linalg.norm([1.1, 0.0, -1.0])
_hold = sampled(op, 9.0, 9.0)[0][1]
# (where the case really is in the insert: on the left fist as it is baked, 0.72 above it)
CASE_HELD = np.array(world(tuple((_hold["Left Arm"] @ FIST)[:3]), FACING, P1)) + np.array([0.0, 0.72, 0.0])


def _vec(c):
    """A vector in the actor's frame (facing the room) in the set's space."""
    return np.array(world(tuple(c), FACING, (0.0, 0.0)))


# (from above the arm: its end face is no backdrop, the dark suit and the tie are)
CAM_C0 = tuple(CASE_HELD + _vec(3.0 * ARM_LINE + np.array([0.0, 0.75, 0.0])))
CAM_C1 = tuple(CASE_HELD + _vec((2.1, 0.55, -2.1)))
TILT_KEYS = [(T_FLIP - 0.1, 0.0), (T_FLIP + 0.3, 0.0), (9.2, 24.0), (9.6, -22.0), (10.0, 14.0), (T_AWAY, 0.0)]
case = shot.prop("BureauBadge", show=(0.0, T_AWAY + 0.15))
for t, parts in sampled(op, 0.0, T_AWAY + 0.15):
    yaw = yaw_at(t)
    fist = world(tuple((parts["Left Arm"] @ FIST)[:3]), yaw, place_at(t))
    in_hand = np.array(fist) + np.array([0.0, 0.72, 0.0])
    u = smooth((t - T_TAKE) / 0.35)
    center = np.array(CASE_SHELF) if t < T_TAKE else np.array(CASE_SHELF) * (1 - u) + in_hand * u
    # the leather side to the lens: facing him (yaw + 180); the flip turns it half way round to the room (yaw) over 0.4 s
    face_him = (CASE_SHELF_YAW if t < T_TAKE else yaw + 180.0)
    flip = smooth((t - T_FLIP) / 0.4)
    cam = np.array(CAM_C0) * (1 - flip) + np.array(CAM_C1) * flip
    to_cam = math.degrees(math.atan2(-(cam[0] - center[0]), -(cam[2] - center[2])))
    turn = (to_cam - face_him + 180.0) % 360.0 - 180.0
    theta = face_him + ((turn * flip + piecewise(TILT_KEYS, t)) if t >= T_FLIP else 0.0)
    # (turned about its own width first (the tilt back towards the lens), then about the vertical: CFrame.Angles(x, y, z))
    rot = posekit.euler(posekit.ry(theta) @ posekit.rx(piecewise(PITCH_KEYS, t)))
    case.at(round(t, 4), tuple(round(float(v), 3) for v in center), tuple(round(float(v), 2) for v in rot), "linear")

# the cuffs: hang over the shelf's lip, taken, looked at (they swing), clipped on behind the left hip (welded after)
CUFF_BELT = ((-0.82, -0.95, 0.66), (90.0, 0.0, 0.0))
cuffs = shot.prop("Handcuffs", show=(0.0, T_CLIP + 0.12), scale=CUFF_SCALE)
for t, parts in sampled(op, 0.0, T_CLIP + 0.12):
    fist = world(tuple((parts["Left Arm"] @ FIST)[:3]), yaw_at(t), place_at(t))
    in_hand = np.array(fist) + np.array([0.0, 0.3, 0.0])
    if t < T_CUFF:
        center, swing = np.array(CUFFS_SHELF), 0.0
    else:
        u = smooth((t - T_CUFF) / 0.3)
        center = np.array(CUFFS_SHELF) * (1 - u) + in_hand * u
        swing = 28.0 * math.exp(-2.6 * (t - T_CUFF)) * math.cos(8.5 * (t - T_CUFF))
    cuffs.at(round(t, 4), tuple(round(float(v), 3) for v in center), (90.0, 0.0, round(swing, 2)), "linear")
me.hold("Handcuffs", "Torso", CUFF_BELT[0], CUFF_BELT[1], t0=T_CLIP + 0.1, scale=CUFF_SCALE)

# The cameras: every one held by a person's hand and creeping; a long lens from far enough that a raised arm is a shape beside
# the face; the subject kept right and high (the captions sit low left)
# A: low from the room's west corner, wide: the open locker and the figure facing it, creeping in
framing.dolly(shot, 0.0, 2.8, (353.4, 3.7, 1.9), (355.4, 3.9, 0.6), (361.3, 4.4, -3.3), (361.7, 4.9, -3.5), fov0=46, fov1=40,
              shake=0.7, seed=1, cut=False)
# B: from the east flank at head height: the cuffs taken off the lip, looked at, clipped on behind
shot.pan(2.8, 5.2, "self", (369.6, 5.2, 0.8), aim="Head", dy=-0.5, fov=42, cut=True, drift=(-0.5, 0.0, -0.4), operator=True, seed=2,
         shake=0.5, fov_to=37, ease_move=True)
# E: from behind on the right: the case taken off the shelf and the turn to the room
shot.pan(5.2, 7.7, "self", (367.4, 4.6, 2.2), aim="Torso", dy=0.5, fov=46, cut=True, drift=(-0.8, 0.0, 0.9), operator=True, seed=5,
         shake=0.5, fov_to=42, ease_move=True)
# C: the badge insert, from the room on his right (the holding arm is the far one), a slow arc round the case under a raking light
framing.dolly(shot, 7.7, 10.1, CAM_C0, CAM_C1, (CASE_HELD[0], CASE_HELD[1] + 0.05, CASE_HELD[2]),
              (CASE_HELD[0], CASE_HELD[1], CASE_HELD[2]), fov0=24, fov1=18, shake=0.3, seed=3)
# D: from the front, straight on: the case goes inside the jacket, the jacket settled
shot.pan(10.1, 11.9, "self", (361.9, 4.8, 4.9), aim="Torso", dy=1.3, fov=38, cut=True, drift=(0.6, 0.0, 0.3), operator=True, seed=4,
         shake=0.5, fov_to=34, ease_move=True)
# F: close from the front right, on a long lens: the head tilting to the earpiece
shot.pan(11.9, 13.7, "self", (363.1, 5.1, 6.7), aim="Head", dy=-0.15, fov=27, cut=True, drift=(-0.3, 0.0, -0.2), operator=True, seed=6,
         shake=0.45, fov_to=23, ease_move=True)
# F2: from the front left and low: the tie squared, the jacket tugged, the last look at the locker
shot.pan(13.7, 15.3, "self", (358.8, 4.0, 5.2), aim="Torso", dy=0.8, fov=37, cut=True, drift=(0.4, 0.0, 0.0), operator=True, seed=8,
         shake=0.45, fov_to=33, ease_move=True)
# G: wide and low from the north-west: the walk the length of the room to the lit doorway
shot.pan(15.3, LENGTH, "self", (352.0, 3.5, -1.6), aim="Torso", dy=0.7, fov=44, cut=True, drift=(0.5, 0.0, 0.2), operator=True,
         seed=7, shake=0.4, fov_to=38, ease_move=True)

# The light: the set's own cold fluorescent pools; a warm lamp in the open locker that the case and the cuffs catch; a cool key
# from the east and a back light from the room so the figure stands out of the dark steel; a grazing light across the case
# during the insert; the door's cold light for the last shot
shot.grade = (0.18, -0.12, 0.0, (214, 226, 246))
shot.light("point", (361.55, 5.4, -5.5), color=(255, 196, 130), brightness=1.5, range=7, shadows=False)
shot.light("spot", (369.0, 9.5, -1.0), (P0[0], 4.4, P0[1]), color=(190, 215, 255), brightness=2.0, range=18, angle=55,
           show=(0.0, 7.7))
shot.light("spot", (357.0, 9.0, 3.5), (P0[0], 4.5, P0[1]), color=(160, 190, 255), brightness=1.5, range=18, angle=60,
           show=(0.0, 7.7))
shot.light("spot", (CASE_HELD[0] + 3.4, CASE_HELD[1] + 0.2, CASE_HELD[2] + 0.6), tuple(CASE_HELD), color=(255, 232, 196), brightness=1.25,
           range=9, angle=22, shadows=False, show=(7.6, 10.2))
shot.light("spot", (P0[0] + 1.0, 9.0, P0[1] + 5.5), (P0[0], 4.4, P0[1]), color=(215, 228, 255), brightness=1.9, range=18, angle=50,
           show=(7.6, 15.5))
shot.light("spot", (P0[0] - 3.0, 8.5, P0[1] + 4.0), (P0[0], 4.6, P0[1]), color=(150, 185, 255), brightness=1.3, range=16, angle=50,
           show=(7.6, 15.5))
shot.light("point", (361.5, 6.0, 9.6), color=(235, 242, 255), brightness=2.6, range=10, shadows=False, show=(14.8, LENGTH))

# Sound and effects on the beats (the slots are the game's; new ones wanted are in the report)
shot.event(0.0, "sfx", slot="mapOfficeHum")
shot.event(T_CUFF + 0.05, "sfx", slot="handcuffs")
shot.event(T_CLIP, "sfx", slot="handcuffs")
shot.event(T_TAKE, "sfx", slot="pageTurn")  # (the leather lifted off the shelf)
shot.event(T_FLIP, "fx", name="flash", r=255, g=236, b=196, strength=0.14, dur=0.35)  # (the metal catches the light)
shot.event(T_FLIP, "sfx", slot="pageTurn")
shot.event(T_FLIP + 0.1, "fx", name="pulse", punch=0.03, dur=0.7)
shot.event(T_AWAY - 0.2, "sfx", slot="bookShut")  # (the case snapped shut)
shot.event(T_MIC, "sfx", slot="flashChime")  # (the earpiece's tone)
shot.event(T_MIC + 0.1, "fx", name="pulse", punch=0.02, dur=0.5)
shot.event(LENGTH - 0.4, "fx", name="black")  # (out: the role card comes up on the dark)
# (the captions: the role card's own timings, kept exactly as they were)
for t_, key_, dur_ in ((1.0, "role", 4.86), (6.141, "win", 5.08), (11.506, "move", 4.21), (15.714, "names", 3.29)):
    shot.event(t_, "card", key=key_, dur=dur_)
shot.audio(music="musicOperative")

if os.environ.get("DG_LAB"):
    for t_ in (8.1, 8.9, 9.4):
        print("[lab] t=%.1f head %s torso %s lhand %s" % (t_, np.round(framing.part(shot, "self", t_, "Head"), 2),
                                                          np.round(framing.part(shot, "self", t_, "Torso"), 2),
                                                          np.round(framing.part(shot, "self", t_, "lhand"), 2)))
    print("[lab] CASE_HELD", np.round(CASE_HELD, 2), "CAM_C0", np.round(CAM_C0, 2), "CAM_C1", np.round(CAM_C1, 2))
    print("[lab] camera at 8.1", shot.camera_at(8.1))
