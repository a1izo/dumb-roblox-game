"""Ace's role cutscene (the briefing, seen only by Ace), rebuilt from nothing on 2026-11-14 as the pilot of
docs/handoff/animation-cutscene-plan-2026-11-13.md. The line: "I had to test this just in case, but I, I never thought it
would actually happen. Kira... it seems you can kill people without having to be there in person."

What the scene is about (art/refs/cinema/RoleAce.toml, after L in the anime's episode 6 and its sweet-eating scenes):
Ace sits curled up alone in the dark, as still as furniture, doing small exact odd things without looking (a sugar cube
taken off a tower and eaten, a cup taken by its rim from the Butler's tray) while he hears that Kira can kill from afar;
on the last words, "in person", his head snaps round to the lens: he knows he is being watched. The one big physical
action is the stillness broken by small precise movements, then that one sharp turn of the head, and the stare held.
It is a mystery scene: slow cameras that creep in on a still figure, the screens the only light, no strikes.

A  0.0-3.4   Low, from the door's side, creeping in: the whole room, the wall of screens, Ace small and still in the
             armchair with the table's edge in front. The first small odd move: a slow tilt of the head.
B  3.4-6.8   Close and a little low from the screens' side: the eyes (the head) jump from screen to screen with long
             holds while the right hand drifts up from the knee, hangs over the tower of sugar cubes, drops onto the top
             cube without a look, lifts it and takes it to the lips.
C  6.8-9.4   From behind Ace's shoulder, low, to the door: the pantry's warm light, the Butler comes in with the tray.
D  9.4-13.0  From the door's side: the Butler holds out the tray; the right fist takes a cup by its rim without a look and
             brings it to the lips; and on "in person" the head snaps round to the lens, the cup still at the chin.
E  13.0-15.2 Extreme close, low, creeping in: the stare.
F  15.2-17.5 Wide again from the door's side, pulling back: Ace small in the screens' light with his face turned to us.

Ace's room (maps/venues/sets/ace.py, Sets scene space, origin x 240): x 228..250, z -9..9, 12 high; the screens and CRT
banks along the north wall (the banks reach out to z -5.7); the armchair at (238, -1.8) facing north (its cushion 2 high);
the low table at (241.6, -1.4) (top 1.375); the door in the east wall at z 0 into the pantry (x 251..265)."""

import math

import numpy as np

import posekit
from animlib import J
from cinema import footwork, framing
from cinema.acting import beat, body_reach, facing, hold, keep_arm, soft, walking
from cinema.shot import Shot
from motion import Motion

NAME = "RoleAce"
LENGTH = 17.5
AX = 240.0
SEAT = 2.0  # the armchair's cushion
ACE = (AX - 2.0, -1.6)  # (x, z) of the root on the cushion; he faces north (-z), the screens
PANTRY = (AX + 13.0, 0.0)
SAID = 2.5  # the line starts (word times: shot.line)
TURN = SAID + 9.47  # "in" of "in person": the head starts round
SHEET = {"cube": 0.42}


def world(p):
    """A point in Ace's frame (the floor under his root, facing -z) in the set's space."""
    return (ACE[0] + p[0], SEAT + p[1], ACE[1] + p[2])


# Ace: crouched on the cushion the R6 way (the owner's drawing, 2026-10-20: the thighs out in front, the torso upright on
# their back ends), the right thigh level so a tower of sugar cubes stands on it, the left drawn up -------------------

RIGHT, LEFT = 90.0, 85.0  # the thighs' pitch in the room (the right level: the tower stands on it; the left a little lower)


def body(lean, turn=0.0, roll=0.0, right=RIGHT, left=LEFT):
    """The crouch: the hips on the cushion, the torso leaning `lean` (- forward), turned `turn` (+ to his left) and
    rolled `roll`; the thighs keep their pitch in the room whatever the torso does."""
    joints = dict(root=(lean, turn, roll), rHip=J((right - lean, -turn, 4), (0, -0.05, 0)),
                  lHip=J((left - lean, -turn, -6), (0, -0.05, 0)))
    return joints, posekit.on_seat(joints, (0.0, 0.0, 0.1), 0.0)


def pt(part, joints, off, local):
    """A point given in a part's own frame, in Ace's frame."""
    m = posekit.fk(joints, off)[part]
    return tuple(float(v) for v in (m @ np.array([*local, 1.0]))[:3])


def thigh(side, joints, off, along, across=0.0, up=0.0):
    """A point over a thigh's top face: `along` studs from the hip, `across` studs outward... (+ his right), `up` above it."""
    part = "Right Leg" if side > 0 else "Left Leg"
    return pt(part, joints, off, (across, 1.0 - along, -0.5 - up))


def mouth(joints, off, neck):
    """His mouth, for a head turned by `neck`."""
    return pt("Head", {**joints, "neck": neck}, off, (0.0, -0.3, -0.6))


REF = body(-16.0)  # the pose the tower is built on
TOWER = (1.65, 0.0)  # (studs from the right hip along the thigh, studs across)
CUBE = 0.42
CUBES = 2


def cube_base(k, joints, off):
    """The bottom middle of the tower's k-th cube (0 lowest)."""
    return thigh(1, joints, off, TOWER[0], TOWER[1] + (0.02, -0.025, 0.03)[k % 3], CUBE * k)


def reach_to(side, joints, off, target, direction=None):
    return body_reach(side, joints, off, target, direction=direction)


CHECKS = []  # (time, side, target, fist) of every placed hand, for the lab's numbers


class Hand:
    """A fist put on a target found from the body of its own key (body_reach), the forearm leaning `direction`."""

    def __init__(self, side, target, direction):
        self.side, self.target, self.direction = side, target, direction

    def __call__(self, j, o, n):
        return reach_to(self.side, j, o, self.target(j, o, n), self.direction)

    def shift(self, dx=0.0, dy=0.0, dz=0.0):
        """The same hand a little way off: a wind-up, drawn back the way the move will not go."""
        return Hand(self.side, lambda j, o, n, f=self.target: tuple(np.array(f(j, o, n)) + np.array([dx, dy, dz])),
                    self.direction)


# The Butler's tray, and where its cup is when he holds it out to Ace ------------------------------------------------

TRAY = dict(rShoulder=J((62, 0, -10), (0, 0.06, -0.16)), lShoulder=J((50, 0, 7), (0, 0.06, -0.16)))  # (the left steadies it lower: never mirrored)
CARRYING, BOWING = dict(root=(-2, 0, 0)), dict(root=(-9, 0, 0))
HELD = {key_: keep_arm(side, CARRYING, TRAY[key_], BOWING, shift=(0.0, -0.05, -0.35), with_shoulder=True)
        for key_, side in (("rShoulder", 1), ("lShoulder", -1))}
_arm = posekit.fk({**CARRYING, "rShoulder": TRAY["rShoulder"]})["Right Arm"]
TRAY_GRIP = ((-1.0, -1.05, 0.0), tuple(round(float(v), 2) for v in posekit.euler(_arm[:3, :3].T)))

OFFER = (AX + 1.5, 1.6)  # where the Butler stops: south-east of the armchair, the tray at Ace's right hip, within his reach
WAYPOINTS = [PANTRY, (AX + 8.0, 0.0), OFFER]
SPEED = 4.0
WALK_T0 = 5.8
legs = [float(np.linalg.norm(np.array(b) - np.array(a))) for a, b in zip(WAYPOINTS, WAYPOINTS[1:])]
WALK_T1 = WALK_T0 + sum(legs) / SPEED
BOWED_AT = WALK_T1 + 0.5

# the tray's origin when he dips and holds it out (his frame), and each cup's place on it (the prop's frame is level,
# the model's axes: x right, y up, z back, where Blender's x is -x)
_bowed = (posekit.fk({**BOWING, "rShoulder": HELD["rShoulder"]})["Right Arm"] @ np.vstack(
    [np.hstack([posekit.R(*TRAY_GRIP[1]), np.array(TRAY_GRIP[0], float)[:, None]]), [0, 0, 0, 1.0]]))[:3, 3]
_yaw = facing(OFFER, ACE)


def _turn(deg):
    a = math.radians(deg)
    return np.array([[math.cos(a), 0, math.sin(a)], [0, 1, 0], [-math.sin(a), 0, math.cos(a)]])


TRAY_AT = np.array([OFFER[0], 0.0, OFFER[1]]) + _turn(_yaw) @ _bowed  # (the set's space)
CUPS = {name: TRAY_AT + _turn(_yaw) @ np.array([-bx, 0.04, by]) for name, (bx, by) in (("A", (0.25, 0.3)), ("B", (0.62, -0.2)))}
# the cup nearer his right hand (the shoulder: 1.5 right of the root, the set's space)
_shoulder = np.array([ACE[0] + 1.5, SEAT + 1.2, ACE[1]])
CUP_WHICH = min(CUPS, key=lambda c: float(np.linalg.norm(CUPS[c] - _shoulder)))
CUP_AT = CUPS[CUP_WHICH]  # (the set's space) where the cup stands on the tray, its bottom
CUP_C = (CUP_AT[0] - ACE[0], CUP_AT[1] - SEAT, CUP_AT[2] - ACE[1])  # (Ace's frame)
CUP_H = 0.29  # the cup's height
T_TAKE = 10.2  # the cup leaves the tray in his fist


def shoulder(side, joints, off):
    """The shoulder's pivot in Ace's frame."""
    return np.array(pt("Torso", joints, off, (side * 1.0, 0.5, 0.0)))


class Held(Hand):
    """A fist that holds something of radius `r` whose middle is at `center(j, o, n)`: the arm points straight at it and
    its end touches it (the object's middle is `r` past the arm's end, along the arm: how the prop paths below place it)."""

    def __init__(self, side, center, r, bend=(0.0, 0.0, 0.0)):
        self.side, self.center, self.r, self.bend = side, center, r, np.array(bend, float)

    def axis(self, j, o, n):
        d = np.array(self.center(j, o, n), float) - shoulder(self.side, j, o) + self.bend
        return d / np.linalg.norm(d)

    def target(self, j, o, n):
        """The fist's middle (0.15 before the arm's end)."""
        return tuple(np.array(self.center(j, o, n), float) - (0.15 + self.r) * self.axis(j, o, n))

    def __call__(self, j, o, n):
        return reach_to(self.side, j, o, self.target(j, o, n), tuple(self.axis(j, o, n)))

    def shift(self, dx=0.0, dy=0.0, dz=0.0):
        return Held(self.side, lambda j, o, n, f=self.center: tuple(np.array(f(j, o, n)) + np.array([dx, dy, dz])), self.r,
                    tuple(self.bend))


ace = Motion("RoleAce_self", LENGTH, note="Ace's role cutscene: the stillness, the cube, the cup, the turn.")


def key(t, ease, lean, turn=0.0, roll=0.0, neck=(0.0, 0.0, 0.0), right=None, left=None, **leg):
    """A key: the body, the head, and each arm as a function of the body (or a value)."""
    joints, off = body(lean, turn, roll, **leg)
    values = {}
    for name, arm in (("rShoulder", right), ("lShoulder", left)):
        if arm is not None:
            values[name] = arm(joints, off, neck) if callable(arm) else arm
            if isinstance(arm, Hand):
                CHECKS.append((t, arm.side, arm.target(joints, off, neck), {**joints, **values}, off))
    ace.key(round(t, 4), ease, offset=off, neck=neck, **values, **joints)


# (each pose: a fist and the place it is put)
R_REST = Hand(1, lambda j, o, n: thigh(1, j, o, 1.2, 0.1, 0.72), (0.1, -0.5, -0.85))  # on the thigh behind the tower
L_REST = Hand(-1, lambda j, o, n: thigh(-1, j, o, 1.7, -0.15, 0.7), (-0.1, -0.4, -0.9))  # along the drawn-up thigh
L_KNEE = Hand(-1, lambda j, o, n: thigh(-1, j, o, 1.85, 0.0, 0.72), (0.05, -0.55, -0.8))  # hooked over the knee


L_KNEE_B = Hand(-1, lambda j, o, n: thigh(-1, j, o, 1.7, -0.12, 0.72), (0.0, -0.5, -0.85))  # the fingers shifted along the knee
L_HEAD = Hand(-1, lambda j, o, n: pt("Head", {**j, "neck": n}, o, (-0.35, 0.3, 0.72)), (0.35, 0.9, 0.2))  # a hand at the back of his head

CUBE_R, CUP_R = CUBE / 2, 0.45


def _top_cube(j, o, n):
    base = cube_base(CUBES - 1, j, o)
    return (base[0], base[1] + CUBE / 2, base[2])


def _lips_at(back):
    def f(j, o, n):
        m = mouth(j, o, n)
        return (m[0] + 0.02, m[1] - 0.03, m[2] - back)
    return f


def _cup_on_tray(j, o, n):
    return (CUP_C[0], CUP_C[1] + CUP_H / 2, CUP_C[2])


R_HOVER = Held(1, lambda j, o, n: tuple(np.array(_top_cube(j, o, n)) + [0.0, 0.55, 0.0]), CUBE_R)  # hangs over the top cube
R_CUBE = Held(1, _top_cube, CUBE_R)  # closed on the top cube
R_LIPS = Held(1, _lips_at(0.36), CUBE_R)  # the cube at his lips
R_CUPHOVER = Held(1, lambda j, o, n: tuple(np.array(_cup_on_tray(j, o, n)) + [0.0, 0.6, 0.0]), CUP_R)
R_CUPRIM = Held(1, _cup_on_tray, CUP_R)  # on the cup standing on the tray
R_CUPARC = Held(1, lambda j, o, n: (1.4, 2.0, -0.55), CUP_R)  # carried over the knee
R_SIP = Held(1, _lips_at(0.46), CUP_R, bend=(0.0, 0.25, 0.0))  # the cup's rim at his lips
R_HOLD = Held(1, lambda j, o, n: (0.7, 2.15, -1.55), CUP_R, bend=(0.0, 0.2, 0.0))  # the cup held at his chest



# ---- the key poses (blocked; the timing between them is worked out afterwards) ----------------------------------------
# 0.0 still: bowed over the knees, the head up to the screens, both hands resting
key(0.0, "smooth", -17, neck=(8, 0, 0), right=R_REST, left=L_KNEE)
key(0.9, "sine", -17, neck=(8, 0, 0), right=R_REST, left=L_KNEE)
# 1.0 the left hand shifts along the knee: small, exact
key(1.5, "sine", -17, neck=(8, 0, 0), right=R_REST, left=L_KNEE_B)
key(2.3, "sine", -17, neck=(8, 0, 0), right=R_REST, left=L_KNEE_B)
# 2.3 the head tilts, slowly, to one side
key(3.1, "sine", -17, neck=(6, 3, 9), right=R_REST, left=L_KNEE_B)
# 3.9 the right hand draws back a hair... and drifts up to hang over the tower (the head still on the screens)
key(3.95, "sine", -17, neck=(6, 3, 9), right=R_REST.shift(0.0, -0.05, 0.3), left=L_KNEE_B)
key(4.7, "sine", -19, turn=-3, neck=(6, 6, 6), right=R_HOVER, left=L_KNEE_B)
# 5.0 it drops onto the top cube without a look
key(5.15, "out", -20, turn=-3, neck=(6, 6, 6), right=R_CUBE, left=L_KNEE_B)
key(5.5, "sine", -20, turn=-3, neck=(6, 6, 6), right=R_CUBE, left=L_KNEE_B)
# 6.1 the cube at the lips
key(6.3, "sine", -16, turn=0, neck=(8, 4, 6), right=R_LIPS, left=L_KNEE_B)
key(6.75, "sine", -16, turn=0, neck=(8, 4, 6), right=R_LIPS, left=L_KNEE_B)
# 7.0 the hand goes back to rest (a nudge towards the mouth first)
key(6.95, "sine", -16, turn=0, neck=(8, 4, 6), right=R_LIPS.shift(0.0, 0.1, -0.12), left=L_KNEE_B)
key(7.8, "sine", -17, neck=(8, 0, 4), right=R_REST, left=L_KNEE_B)
# 8.0 the left hand goes up behind his head, as if the thought itched; held while the tray comes
key(8.1, "sine", -17, neck=(8, 0, 4), right=R_REST, left=L_KNEE_B.shift(0.0, -0.15, 0.2))
key(8.7, "sine", -17, neck=(7, 2, 5), right=R_REST, left=L_HEAD)
key(9.2, "sine", -17, neck=(7, 2, 5), right=R_REST, left=L_HEAD)
# 9.3 the Butler is there: the right hand draws back, then drifts up to the tray without a look (the body turns to it,
# the head stays on the screens), and the left comes down
key(9.35, "sine", -17, turn=-6, neck=(7, 8, 5), right=R_REST.shift(0.0, -0.05, 0.3), left=L_KNEE)
key(9.7, "sine", -18, turn=-14, neck=(7, 14, 4), right=R_CUPHOVER, left=L_KNEE)
key(10.05, "out", -19, turn=-14, neck=(7, 14, 4), right=R_CUPRIM, left=L_KNEE)
key(T_TAKE + 0.1, "sine", -19, turn=-14, neck=(7, 14, 4), right=R_CUPRIM, left=L_KNEE)
# the cup swings up and round over his knee (never through the thigh)
key(10.72, "sine", -18, turn=-10, neck=(9, 10, 4), right=R_CUPARC, left=L_KNEE)
# 11.2 the cup at his lips, the head tipped back for the sip
key(11.2, "sine", -15, turn=-6, neck=(13, 6, 3), right=R_SIP, left=L_KNEE)
key(11.65, "sine", -15, turn=-6, neck=(13, 6, 3), right=R_SIP, left=L_KNEE)
# the head comes level and goes still: he has stopped breathing
key(11.82, "sine", -17, turn=-6, neck=(5, 4, 3), right=R_HOLD, left=L_KNEE)
key(TURN - 0.07, "sine", -17, turn=-6, neck=(5, 4, 3), right=R_HOLD, left=L_KNEE)
# 11.97 on "in person" the head draws back a hair to the left... and snaps round to the lens; the torso follows a beat later
key(TURN + 0.1, "sine", -17, turn=-6, neck=(5, -12, 3), right=R_HOLD, left=L_KNEE)
key(TURN + 0.22, "snap", -17, turn=14, neck=(-5, 84, 2), right=R_HOLD, left=L_KNEE)
key(TURN + 0.55, "smooth", -17, turn=28, neck=(-4, 68, 2), right=R_HOLD, left=L_KNEE)
# the stare is held; at the end one last small tilt, and the cup drawn a little in
key(14.4, "sine", -17, turn=28, neck=(-4, 68, 2), right=R_HOLD, left=L_KNEE)
key(15.8, "sine", -17, turn=28, neck=(-3, 68, 11), right=R_HOLD, left=L_KNEE)
key(LENGTH, "smooth", -17, turn=28, neck=(-3, 68, 11), right=R_HOLD, left=L_KNEE)
soft(ace, head=4.2, arms=5.0, head_damp=0.55, arm_damp=0.55)
ace.build()
T_PICK, T_EAT = 5.45, 6.55  # the top cube leaves the tower in his fist; it is eaten at the lips

b = Motion("RoleAce_butler", LENGTH, note="Ace's role cutscene: the Butler brings the tea.")
b.key(0.0, root=(0, 0, 0), neck=(-2, 0, 0), **TRAY)
b.key(WALK_T1, root=(-2, 0, 0), neck=(-2, 0, 0), **TRAY)
beat(b, BOWED_AT, 0.5, antic=0.15, root=(-9, 0, 0), neck=(-4, 0, 0), **HELD)  # a small dip, the tray held out
beat(b, 10.6, 0.6, antic=0.1, neck=(-7, 9, 0))  # his eyes follow the cup up
beat(b, 11.7, 0.7, antic=0.1, root=(-9, 3, 0), neck=(-3, 3, 0))  # a breath of weight, the tray still
hold(b, 12.4)
beat(b, 13.0, 0.4, antic=0.1, neck=(2, 18, 0))  # a glance at Ace: he has turned his head
hold(b, 14.2)
beat(b, 14.9, 0.6, root=(-3, 6, 0), neck=(-8, 6, 0), rShoulder=J((56, 0, -14), (0, 0.06, -0.16)), lShoulder=J((58, 0, 9), (0, 0.06, -0.16)))
b.key(LENGTH, root=(-3, 6, 0), neck=(-8, 6, 0))
soft(b, arms=2.6).plant(None, WALK_T0 - 0.1, stance=0.04).plant(WALK_T1 + 0.1, None, stance=0.04)
walking(b, WALK_T0, WALK_T1, arms=0.35)
b.build()

# The shot --------------------------------------------------------------------------------------------------

shot = Shot(NAME, "Sets", LENGTH, note="Ace's role cutscene: the screens, the cube, the tea, the turn.")
shot.room = (228.0, -9.0, 250.0, 9.0, 12.0)
shot.allow = {"self": ["ClubChair"]}

me = shot.actor("self", ace, silhouette=None)
me.mark(0.0, (ACE[0], SEAT, ACE[1]), 0.0)

bu = shot.actor("butler", b)
marks = [WALK_T0]
for a_, b_ in zip(WAYPOINTS, WAYPOINTS[1:]):
    marks.append(marks[-1] + float(np.linalg.norm(np.array(b_) - np.array(a_))) / SPEED)
heads = [facing(a_, b_) for a_, b_ in zip(WAYPOINTS, WAYPOINTS[1:])]
bu.mark(0.0, (PANTRY[0], 0.0, PANTRY[1]), heads[0])
bu.mark(WALK_T0, (PANTRY[0], 0.0, PANTRY[1]), heads[0], "linear")
for i in range(1, len(WAYPOINTS) - 1):
    yaw = heads[i - 1] + ((heads[i] - heads[i - 1] + 180.0) % 360.0 - 180.0) / 2
    bu.mark(marks[i], (WAYPOINTS[i][0], 0.0, WAYPOINTS[i][1]), yaw, "linear")
bu.mark(marks[-1], (OFFER[0], 0.0, OFFER[1]), heads[-1], "linear")
bu.mark(marks[-1] + 0.5, (OFFER[0], 0.0, OFFER[1]), facing(OFFER, ACE))
bu.mark(LENGTH, (OFFER[0], 0.0, OFFER[1]), facing(OFFER, ACE))
bu.hold("TeaTray", "Right Arm", *TRAY_GRIP)
footwork.apply(shot)

# The sugar cubes: a tower welded to the right thigh (the top cube until it is taken), the top cube on the fist's path ---
HAND = np.array([0.0, -0.85, 0.0, 1.0])
_leg = posekit.fk(*REF)["Right Leg"]


def cube_local(k):
    return (TOWER[1] + (0.02, -0.025, 0.03)[k % 3], 1.0 - TOWER[0], -0.5 - CUBE * k)


for k in range(CUBES):
    yaw = (8, -6, 14)[k % 3]
    rot = tuple(round(float(v), 2) for v in posekit.euler(_leg[:3, :3].T @ posekit.ry(yaw)))
    me.hold("SugarCube", "Right Leg", tuple(round(v, 3) for v in cube_local(k)), rot, t0=0.0,
            t1=T_PICK if k == CUBES - 1 else LENGTH)


def sampled(m, t0, t1, step=1 / 30):
    """(t, {part: matrix}) every frame as the baked clip plays (the springs run, the feet planned)."""
    n = int(round((t1 - t0) / step))
    times = [t0 + i * step for i in range(n + 1)]
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


cube = shot.prop("SugarCube", show=(T_PICK, T_EAT))
for t, parts in sampled(ace, T_PICK, T_EAT):
    on_tower = (parts["Right Leg"] @ np.array([*cube_local(CUBES - 1), 1.0]))[:3] + np.array([0.0, CUBE / 2, 0.0])
    in_fist = (parts["Right Arm"] @ np.array([0.0, -1.0 - CUBE / 2, 0.0, 1.0]))[:3]
    u = smooth((t - T_PICK) / 0.3)
    centre = on_tower * (1 - u) + in_fist * u
    cube.at(round(t, 4), tuple(round(v, 3) for v in world(centre - np.array([0.0, CUBE / 2, 0.0]))), (0, 0, 0), "linear")

cup = shot.prop("Teacup", show=(T_TAKE, LENGTH))
TILT = [(T_TAKE, 0.0), (10.75, 0.0), (11.2, 10.0), (11.85, 10.0), (TURN + 0.1, 0.0), (LENGTH, 0.0)]


def tilt_at(t):
    for (a, va), (b_, vb) in zip(TILT, TILT[1:]):
        if t <= b_:
            return va + (vb - va) * smooth((t - a) / max(1e-6, b_ - a))
    return TILT[-1][1]


for t, parts in sampled(ace, T_TAKE, LENGTH):
    on_tray = np.array(CUP_C)
    in_fist = (parts["Right Arm"] @ np.array([0.0, -1.0 - CUP_R, 0.0, 1.0]))[:3] - np.array([0.0, CUP_H / 2, 0.0])
    u = smooth((t - T_TAKE) / 0.3)
    bottom = on_tray * (1 - u) + in_fist * u
    cup.at(round(t, 4), tuple(round(v, 3) for v in world(bottom)), (round(-tilt_at(t) * u, 2), 0, 0), "linear")

# The cameras: every one held by a person's hand and creeping (a locked camera is a tripod), a long lens from far enough that
# a raised arm is a shape beside the face and not a wall in front of it.
# A: low, from the door's side, the whole room and the small still figure, creeping in.
shot.pan(0.0, 3.4, "self", (AX + 8.2, 3.2, 3.0), aim="Torso", dy=0.5, fov=48, drift=(-2.2, 0.2, -1.6), operator=True, seed=1,
         shake=0.5, fov_to=40, ease_move=True)
# B: from his right, low: the head jumps from screen to screen while the right hand rises over the tower and takes a cube.
shot.pan(3.4, 6.8, "self", (AX - 11.1, 4.8, -2.2), aim="Head", dy=-0.2, fov=36, cut=True, drift=(0.5, 0.0, 0.2), operator=True,
         seed=2, shake=0.45, fov_to=30, ease_move=True)
# C: over his shoulder, low, to the door: the Butler and the pantry's warm light.
shot.pan(6.8, 9.4, "butler", (AX - 5.8, 3.6, -0.2), aim="Torso", dy=0.9, fov=40, cut=True, operator=True, seed=3, shake=0.5,
         drift=(0.5, 0.0, 0.2))
# D: from the door's side, in the line he will turn along: the tea, the sip, the turn, the stare, creeping in all the way.
shot.pan(9.4, 15.2, "self", (AX - 11.1, 5.0, -1.0), aim="Head", dy=-0.2, fov=34, cut=True, operator=True, seed=4, shake=0.45,
         drift=(2.4, 0.0, -0.3), fov_to=15, ease_move=True)
# E: wide again from the door's side, pulling back: Ace small in the screens' light, his face turned to us.
shot.pan(15.2, LENGTH, "self", (AX - 9.8, 3.2, 0.2), aim="Torso", dy=0.6, fov=40, cut=True, drift=(-1.2, 0.2, 1.2), operator=True,
         seed=6, shake=0.5, fov_to=46, ease_move=True)

# The light: the screens' cold glow is the only light (the set's own); a flickering key on his face from the screens, a cold
# rim from behind him, and a warm spill through the pantry door from the moment the Butler is there to be seen.
HEAD = world((0.0, 3.0, -0.3))
shot.grade = (0.22, -0.18, -0.02, (212, 228, 255))
shot.light("spot", (AX - 1.6, 8.0, ACE[1] - 5.6), HEAD, color=(150, 200, 255), brightness=2.2, range=14, angle=60, flicker=0.3)
shot.light("spot", (AX + 3.0, 7.5, ACE[1] + 4.2), HEAD, color=(130, 175, 255), brightness=2.4, range=15, angle=55)
shot.light("point", (AX + 8.6, 5.0, 0.0), color=(255, 196, 130), brightness=1.6, range=11, shadows=False, show=(WALK_T0 - 0.3, LENGTH))
shot.light("point", (AX - 7.0, 5.4, ACE[1] - 1.0), color=(160, 195, 255), brightness=1.1, range=10, shadows=False, show=(TURN - 0.1, LENGTH))  # (the face turned to the lens is never the darkest thing in the frame)

# Sound and effects on the beats: a soft focus that goes where the eye should (the head, the hand, the Butler), the cube's
# tick, the cup's, and on the turn a pulse of the lens, a heartbeat and a low swell; then the colour drains.
shot.event(0.0, "sfx", slot="mapServerHum")
for t, slot, part, radius, rack in ((0.0, "self", "Torso", 7.0, 0.0), (3.4, "self", "Head", 3.2, 0.0),
                                    (4.9, "self", "Right Arm", 2.6, 0.6), (6.3, "self", "Head", 3.2, 0.6),
                                    (6.8, "butler", "Torso", 5.0, 0.0), (9.4, "self", "Right Arm", 3.0, 0.0),
                                    (11.0, "self", "Head", 3.0, 0.7), (12.4, "self", "Head", 2.4, 0.5),
                                    (15.2, "self", "Torso", 8.0, 0.0)):
    shot.event(t, "fx", name="focus", slot=slot, part=part, radius=radius, far=0.12, near=0.06, rack=rack)
shot.event(T_PICK, "sfx", slot="clockTick")
shot.event(T_TAKE, "sfx", slot="clockTick")
shot.event(TURN - 0.6, "sfx", slot="introTokyoDrone")
shot.event(TURN, "sfx", slot="eyesOpen")
shot.event(TURN + 0.05, "sfx", slot="heartbeat")
shot.event(TURN + 0.05, "fx", name="pulse", punch=0.06, dur=0.8)
shot.event(TURN + 0.2, "fx", name="drain", strength=0.5, dur=2.5)

shot.audio(voice="voiceAce", voice_at=SAID, bed="bedAce")
shot.line(SAID, "I had to test this just in case, but I, I never thought it would actually happen. {Hand}... it seems you "
                "can kill people without having to be there in person.")
