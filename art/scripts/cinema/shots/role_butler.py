"""The Butler's role cutscene (the briefing, seen only by the Butler), rebuilt from nothing on 2026-11-17 (item 4 of
docs/handoff/list-2026-11-16.md, step 1c of the animation plan). The line, kept as it was: "Is something the matter?
Hmm? ... What's wrong?" (voiceButler).

What the scene is about (art/refs/cinema/RoleButler.toml, after Watari in the anime, episode 6): the old servant sets
his tea tray straight with small exact movements in his pantry, carries it level and unhurried through the door into
the dark room of the one he serves, and, seeing the crouched shape among the screens so still and silent, asks
gently, with his hand flat on his chest and his head inclined, what is the matter. Nothing answers. The one big
physical action is the tray: taken up with exact hands, carried level on a still upper body, held through the
question. It is a quiet scene: slow held cameras, the warm pantry against the screens' cold glow, nothing sudden.

A  0.0-3.3   Low from the door's end of the pantry, creeping in: the old man at the counter, bent over the tray, a
             fist touching a cup straight, then upright with his hands joined at his belt, then both fists taking the
             tray's ends and lifting it, level, as he turns to go.
B  3.4-6.4   He comes towards us across the pantry with the tray, the camera drawing back before him to the door.
C  6.4-8.5   From the dark room, past the faceless one in the chair, to the lit door: he comes in with the tray and
             the question begins ("Is something the matter? Hmm? ...").
D  8.5-10.4  From the screens' side, close, a little below: he has stopped; on "What's wrong?" his left hand goes flat
             to his chest and his head inclines.
E  10.4-12.3 Wide from behind him, hardly moving: the faceless one does not answer; he looks to the screens; black.

The pantry (maps/venues/sets/ace.py, Sets scene space, origin x 258): x 251..265, z -6..6, the counter along the north
wall (its front at z -3.4, top 3.5), the trolley at (260, 1.5), the doorway in the west wall (z -2..2) and, 1 stud on,
Ace's door in the east wall of his room (x 228..250, z -9..9) with the armchair at (238, -1.8) facing the screens."""

import math

import numpy as np

import posekit
from animlib import J
from cinema import footwork
from cinema.acting import beat, body_reach, facing, keep_arm, soft, walking
from cinema.shot import Shot
from emotes.kit import reach
from motion import Motion

NAME = "RoleButler"
PX = 258.0
TOP = 3.5
COUNTER = (PX + 0.5, -1.9)  # where he stands at the counter, 1.6 from its front edge (at 1.1 his arms went into the cupboards)
TRAY_AT = (PX + 0.5, TOP, -4.1)  # the tray on the counter: its bottom middle
STOP = (246.0, 0.9)  # where he stops in the dark room, a respectful way from the chair
ACE = (238.0, 2.0, -1.6)  # the crouched shape in the chair (the root, on the cushion)
SEAT = 2.0
SPEED = 3.0  # a butler with a tray: slower than the game's walk (4), eased in and out
LEFT_COUNTER = 3.3  # he sets off from the counter

# The way: out along the counter, across the pantry and through the doorway, then a curve to the stop (never a pivot
# on the spot after it): the pantry's gap and Ace's door are 4 wide, he is 2.
IN_WAY = [COUNTER, (PX - 0.7, -2.0), (PX - 2.8, -1.0), (PX - 5.2, 0.1), (PX - 7.4, 0.0), (PX - 9.8, 0.0), STOP]
DOOR_X = PX - 7.0  # the pantry's gap is the line the question starts at


def travel(points, t0, speed, accel=0.6, decel=0.8, yaw_start=None, turn_start=1.0, yaw_end=None, turn_end=1.3):
    """A walk along a polyline: eased up to `speed` over `accel`, eased down over `decel`, the heading the path's own
    (smoothed over a stud either side), blended into `yaw_start` over the first `turn_start` seconds and into `yaw_end`
    over the last `turn_end` (the way role_ace.py walks the Butler, measured in the game 2026-11-15: a constant speed
    that began and stopped dead, and a pivot after it, were what read as off). Returns ([(t, x, z, yaw)] every 0.1 s, the
    time it ends, the distance covered)."""
    pts = [np.array(p, float) for p in points]
    seg = [float(np.linalg.norm(b_ - a_)) for a_, b_ in zip(pts, pts[1:])]
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
        for k, ln in enumerate(seg):
            if sd <= ln + 1e-9 or k == len(seg) - 1:
                u = sd / max(ln, 1e-9)
                return pts[k] + (pts[k + 1] - pts[k]) * min(1.0, u)
            sd -= ln
        return pts[-1]

    def wrap(a):
        return (a + 180.0) % 360.0 - 180.0

    def blend(a, b_, u):
        u = max(0.0, min(1.0, u))
        u = u * u * (3 - 2 * u)
        return a + wrap(b_ - a) * u

    out = []
    n = int(math.ceil(T / 0.1))
    for i in range(n + 1):
        t = min(i * 0.1, T)
        sd = s_of(t)
        pos = at(sd)
        d = at(sd + 1.0) - at(sd - 1.0)
        yaw = facing((0.0, 0.0), (float(d[0]), float(d[1]))) if np.linalg.norm(d) > 1e-6 else (out[-1][3] if out else 0.0)
        if yaw_start is not None:
            yaw = blend(yaw_start, yaw, t / turn_start)
        if yaw_end is not None:
            yaw = blend(yaw, yaw_end, 1.0 - (T - t) / turn_end)
        out.append((round(t0 + t, 3), float(pos[0]), float(pos[1]), yaw))
    return out, t0 + T, total


def time_at(walk, x):
    """When the walk's x first passes `x` (walking west)."""
    for (t0, x0, *_), (t1, x1, *_) in zip(walk, walk[1:]):
        if x0 >= x >= x1:
            return t0 + (t1 - t0) * (x0 - x) / max(1e-9, x0 - x1)
    return walk[-1][0]


WALK, WALK_END, _ = travel(IN_WAY, LEFT_COUNTER, SPEED, yaw_start=0.0, turn_start=1.5, yaw_end=facing(STOP, ACE[::2]), turn_end=1.8)
T_DOOR = time_at(WALK, DOOR_X)  # in the doorway
SAID = round(T_DOOR - 0.3, 2)  # the line starts as he reaches it
HAND_UP = round(SAID + 2.75, 2)  # "What's wrong?": the left hand goes flat to his chest
LINE_END = SAID + 3.65
LENGTH = round(LINE_END + 2.4, 1)

# Acting ---------------------------------------------------------------------------------------------

# (the fists are put on marks, never on guessed angles: body_reach for a mark in the room, reach for one on the body)
CHECKS = []  # (what, side, target, joints, values, offset): the lab's numbers


def put(t, side, joints, off, target, direction=None):
    arm = body_reach(side, joints, off, target, direction=direction)
    CHECKS.append((t, side, target, joints, arm, off))
    return arm


UPRIGHT = dict(root=(-1, 0, 0))
TRAY_LOCAL = (0.0, TOP, TRAY_AT[2] - COUNTER[1])  # the tray's bottom middle at the counter, in his frame (z negative: in front of him)
TRAY_GRIP = 0.78  # how far from the tray's middle each fist takes it (the tray is 2.45 across)
BENT = dict(root=(-14, 0, 0))  # over the counter


def tray_marks(joints, lift=(0.0, 0.0, 0.0)):
    """The two fists' marks on the tray at the counter (over its rim, never under it)."""
    return [(side, (TRAY_LOCAL[0] + side * TRAY_GRIP + lift[0], TRAY_LOCAL[1] + 0.86 + lift[1], TRAY_LOCAL[2] + 0.5 + lift[2]))
            for side in (1, -1)]


GRAB = {key: put(2.7, side, BENT, (0, 0, 0), target)
        for key, (side, target) in zip(("rShoulder", "lShoulder"), tray_marks(BENT))}
OVER = {key: put("over", side, BENT, (0, 0, 0), (side * TRAY_GRIP, TOP + 1.2, TRAY_LOCAL[2] + 0.55))
        for key, side in (("rShoulder", 1), ("lShoulder", -1))}
# Lifted level: both arms keep their turn in the room as the body straightens, the tray drawn 0.35 in and down to the collar
# (a rigid arm turning with the torso would tip it): carried at the belt, flat.
LIFT = (0.0, -0.55, 0.35)  # (the tray carried at the collar: higher hid his chin from a camera in front)
CARRY = {key: keep_arm(side, BENT, GRAB[key], UPRIGHT, LIFT) for key, side in (("rShoulder", 1), ("lShoulder", -1))}
INCLINED = dict(root=(-9, 0, 0))  # the small bow for the question
BOW = {key: keep_arm(side, UPRIGHT, CARRY[key], INCLINED, with_shoulder=True)
       for key, side in (("rShoulder", 1), ("lShoulder", -1))}
BOW2 = {key: keep_arm(side, UPRIGHT, CARRY[key], dict(root=(-4, 0, 0)), with_shoulder=True)
        for key, side in (("rShoulder", 1), ("lShoulder", -1))}

# Once he is walking the tray rides on his right hand alone and the left arm is let go (hanging a little forward, as a
# butler carries it); the two arms were mirror images through the whole carry (motion report: symmetry).
LEFT_FREE = J((12, 0, 1), (0.0, 0.0, 0.0))
# (raised a hand's breadth first, off the counter, and lowered to the belt once he is away from it: carried low from the start the
# tray and the arm went 0.8 into the counter as it came up)
HIGH = {key: keep_arm(side, BENT, GRAB[key], dict(root=(-3, 0, 0)), (0.0, 0.4, 0.3)) for key, side in (("rShoulder", 1), ("lShoulder", -1))}  # (the left lets go with the lift, not through the counter)
CARRY = {"rShoulder": CARRY["rShoulder"], "lShoulder": LEFT_FREE}
BOW2 = {"rShoulder": BOW2["rShoulder"], "lShoulder": LEFT_FREE}

# The tray welded to the right forearm where it lies on the counter at the moment the hands close on it (no jump).
_arm = posekit.fk({**BENT, "rShoulder": GRAB["rShoulder"]})["Right Arm"]
_tray = np.identity(4)
_tray[:3, 3] = TRAY_LOCAL
_local = np.linalg.inv(_arm) @ _tray
TRAY_HELD = (tuple(round(float(v), 3) for v in _local[:3, 3]), tuple(round(float(v), 2) for v in posekit.euler(_local[:3, :3])))

# hands on the body (torso frame): joined low at the belt, the left flat on the chest (a fist on the mark, the forearm across)
BELT_R = reach(1, (0.3, -0.3, -0.9), direction=(-0.5, 0.2, -0.85))
BELT_L = reach(-1, (-0.35, -0.38, -0.95), direction=(0.45, 0.2, -0.85))
UP_R = reach(1, (0.55, 0.75, -0.85), direction=(-0.2, -0.3, -0.9))
UP_L = reach(-1, (-0.5, 0.7, -0.9), direction=(0.25, -0.3, -0.9))
CHEST_L = reach(-1, (-0.35, 0.5, -0.8), direction=(0.75, -0.1, -0.65))
EDGE_L = J((-8, 0, 3), (0.0, 0.0, 0.0))  # the left hangs at his side (resting a fist on the counter's rim was out of reach: it went 0.5 into the cupboards)
HOVER_R = put("hover", 1, BENT, (0, 0, 0), (TRAY_LOCAL[0] + 1.0, TOP + 0.85, TRAY_LOCAL[2] + 0.4), direction=(-0.3, -0.35, -0.9))
TOUCH_R = put("touch", 1, BENT, (0, 0, 0), (TRAY_LOCAL[0] + 1.0, TOP + 0.72, TRAY_LOCAL[2] + 0.35), direction=(-0.3, -0.35, -0.9))
NUDGE_R = put("nudge", 1, BENT, (0, 0, 0), (TRAY_LOCAL[0] + 0.85, TOP + 0.72, TRAY_LOCAL[2] + 0.45), direction=(-0.3, -0.35, -0.9))

b = Motion("RoleButler_self", LENGTH, note="The Butler's role cutscene: the tray, the door, the question.")
# at the counter: bent over the tray, a fist touching the cup straight
b.key(0.0, root=(-13, 0, 0), neck=(-20, 4, 0), rShoulder=HOVER_R, lShoulder=EDGE_L)
b.key(0.75, root=(-14, 0, 0), neck=(-22, 6, 0), rShoulder=HOVER_R, lShoulder=EDGE_L)
b.key(1.1, root=(-14, 0, 0), neck=(-23, 6, 0), rShoulder=TOUCH_R, lShoulder=EDGE_L)  # the fist touches the cup
b.key(1.35, root=(-14, 0, 0), neck=(-23, 4, 0), rShoulder=NUDGE_R, lShoulder=EDGE_L)  # ... and turns it a little
b.key(1.7, root=(-13, 0, 0), neck=(-20, 2, 0), rShoulder=HOVER_R, lShoulder=EDGE_L)
# upright, the hands joined at the belt, a glance to the door; a breath
b.key(2.1, root=(0, 0, 0), neck=(-3, 34, 0), rShoulder=BELT_R, lShoulder=BELT_L)
b.key(2.3, root=(0, 0, 0), neck=(-3, 34, 0), rShoulder=BELT_R, lShoulder=BELT_L)
# both fists to the tray's two ends
b.key(2.6, root=(-6, 0, 0), neck=(-10, 12, 0), rShoulder=UP_R, lShoulder=UP_L)  # (the hands rise to the chest first: swung low from the belt they went through the counter)
b.key(2.85, root=(-13, 0, 0), neck=(-14, 0, 0), **OVER)  # (then come down onto the tray from above)
b.key(3.05, root=(-14, 0, 0), neck=(-18, 0, 0), **GRAB)
# the tray lifted, level, and carried
b.key(3.6, root=(-3, 0, 0), neck=(-4, 0, 0), **HIGH)
b.key(4.9, root=(-2, 0, 0), neck=(-3, 0, 0), **HIGH)  # (held up till he is past the counter's end: it runs along his way)
b.key(5.7, root=(-1, 0, 0), neck=(-3, 0, 0), **CARRY)
b.key(HAND_UP - 0.6, root=(-1, 0, 0), neck=(-3, 0, 0), **CARRY)
b.key(HAND_UP - 0.2, root=(-6, 0, 0), neck=(-3, 0, 0), **BOW2)  # a breath drawn
b.key(HAND_UP + 0.3, root=(-9, 0, 0), neck=(0, 0, 0), rShoulder=BOW["rShoulder"], lShoulder=CHEST_L)  # on "What's wrong?"
b.key(LINE_END + 0.2, root=(-9, 0, 0), neck=(0, 0, 0), rShoulder=BOW["rShoulder"], lShoulder=CHEST_L)
b.key(LINE_END + 0.9, root=(-8, 0, 0), neck=(2, -48, 0), rShoulder=BOW["rShoulder"], lShoulder=CHEST_L)  # his eyes go to the screens
b.key(LENGTH, root=(-8, 0, 0), neck=(2, -52, 0), rShoulder=BOW["rShoulder"], lShoulder=CHEST_L)
# the big moves acted: the lift taking the tray's weight low first, the bow dipping past and settling
beat(b, 3.6, 0.55, antic=0.03, over=0.05, root=(-3, 0, 0), neck=(-4, 0, 0), **HIGH)
soft(b, arms=2.6).plant(None, LEFT_COUNTER - 0.1, stance=0.04).plant(WALK_END + 0.1, None, stance=0.04)
walking(b, LEFT_COUNTER, WALK_END, speed=SPEED, arms=0.3)  # (the tray carried: a small swing)
b.build()

# The faceless one, crouched in the chair as in Ace's own scene (art/scripts/cinema/shots/role_ace.py): the R6 way, the
# thighs out in front, the torso upright on their back ends; he does not answer, only his head turns a little to the voice.
RIGHT, LEFT = 90.0, 85.0


def body(lean, turn=0.0, roll=0.0):
    joints = dict(root=(lean, turn, roll), rHip=J((RIGHT - lean, -turn, 4), (0, -0.05, 0)),
                  lHip=J((LEFT - lean, -turn, -6), (0, -0.05, 0)))
    return joints, posekit.on_seat(joints, (0.0, 0.0, 0.1), 0.0)


def pt(part, joints, off, local):
    m = posekit.fk(joints, off)[part]
    return tuple(float(v) for v in (m @ np.array([*local, 1.0]))[:3])


def thigh(side, joints, off, along, across=0.0, up=0.0):
    part = "Right Leg" if side > 0 else "Left Leg"
    return pt(part, joints, off, (across, 1.0 - along, -0.5 - up))


shape = Motion("RoleButler_ace", LENGTH, note="The Butler's role cutscene: the faceless one in the chair.")


def ace_key(t, ease, lean, turn=0.0, neck=(0.0, 0.0, 0.0)):
    joints, off = body(lean, turn)
    shape.key(round(t, 3), ease, offset=off, neck=neck,
              rShoulder=body_reach(1, joints, off, thigh(1, joints, off, 1.2, 0.1, 0.72), direction=(0.1, -0.5, -0.85)),
              lShoulder=body_reach(-1, joints, off, thigh(-1, joints, off, 1.85, 0.0, 0.72), direction=(0.05, -0.55, -0.8)),
              **joints)


ace_key(0.0, "smooth", -16, neck=(8, 0, 0))
ace_key(HAND_UP - 0.3, "sine", -16, neck=(8, 2, 3))
ace_key(HAND_UP + 1.1, "sine", -16, turn=-3, neck=(8, -18, 4))  # the head turns a little to the voice, the answer never comes
ace_key(LENGTH, "sine", -16, turn=-3, neck=(8, -18, 4))
soft(shape, head=4.2, arms=5.0, head_damp=0.55, arm_damp=0.55)
shape.build()

# The shot -------------------------------------------------------------------------------------------------

shot = Shot(NAME, "Sets", LENGTH, note="The Butler's role cutscene: the pantry, the tray, the faceless one.")
shot.allow = {"ace": ["ClubChair"]}  # crouched on its seat

me = shot.actor("self", b)
me.mark(0.0, (COUNTER[0], 0.0, COUNTER[1]), 0.0)
me.mark(LEFT_COUNTER, (COUNTER[0], 0.0, COUNTER[1]), 0.0, "linear")
for t, x, z, yaw in WALK[1:]:
    me.mark(t, (x, 0.0, z), yaw, "linear")
me.hold("TeaTray", "Right Arm", TRAY_HELD[0], TRAY_HELD[1], t0=3.05)

tray = shot.prop("TeaTray", show=(0.0, 3.05))
tray.at(0.0, TRAY_AT, (0, 0, 0))
tray.at(3.05, TRAY_AT, (0, 0, 0))

ace = shot.actor("ace", shape, extra=True, silhouette=(0.0, LENGTH))
ace.mark(0.0, ACE, 0.0)
footwork.apply(shot)  # (the feet planted where they come down, stepping after the body: cinema/footwork.py)

# The cameras ------------------------------------------------------------------------------------------------
CUT_A2, CUT_B = 1.7, 3.3  # the hands: an insert on the tray, then the walk
# A: wide from beyond the counter's west end, his left (the hanging, idle) side to us so the working arm is the far one: the old man bent over the
# tray in profile, the marble and the pantry round him, a fist straightening a cup.
shot.pan(0.0, CUT_A2, "self", (PX - 6.2, 4.9, -3.9), aim="Torso", dy=1.1, fov=52, drift=(0.4, 0.0, 0.2), operator=True, seed=1,
         shake=0.5, fov_to=48, ease_move=True)
# A2: from over the counter's west end, high and to the tray's side (the tray and its cups in the frame beside his head, his near arm a small shape): the hands rise, come down on the tray, lift it.
shot.pan(CUT_A2, CUT_B, "self", (PX - 4.0, 6.1, -5.4), aim="Torso", dy=0.8, fov=52, cut=True, drift=(0.4, 0.0, 0.1), operator=True,
         seed=6, shake=0.5, fov_to=48, ease_move=True)
# B: from the pantry's far corner, high behind him as he goes, down its length to the lit door and the dark beyond.
shot.pan(CUT_B, T_DOOR, "self", (PX + 6.4, 5.8, 2.0), aim="Torso", dy=0.3, fov=46, cut=True, back=True, drift=(-1.2, -0.2, -0.4),
         operator=True, seed=2, shake=0.5, ease_move=True)
# C: from the dark room, low, past the faceless one in the chair, back along the line to the lit door.
shot.pan(T_DOOR, HAND_UP - 0.25, "self", (ACE[0] - 3.0, 3.4, ACE[2] + 4.2), aim="Torso", dy=0.6, fov=38, cut=True, drift=(1.4, 0.2, -0.3),
         operator=True, seed=3, shake=0.5, fov_to=32, ease_move=True)
# D: from the front-left, a little above, from far enough that his head is a head: the old man's face as he asks.
shot.pan(HAND_UP - 0.25, LINE_END + 0.55, "self", (STOP[0] - 6.4, 4.5, STOP[1] + 3.6), aim="Torso", dy=0.85, fov=40, cut=True,
         drift=(0.5, 0.1, 0.3), operator=True, seed=4, shake=0.4, fov_to=36, ease_move=True)
# E: from the pantry through its two doorways: him small and still in the dark room, the faceless one beyond; then black.
shot.pan(LINE_END + 0.55, LENGTH, "self", (PX - 0.5, 4.8, 0.6), aim="Torso", dy=0.5, fov=44, cut=True, back=True,
         drift=(-0.4, 0.0, 0.1), operator=True, seed=5, shake=0.35, ease_move=True)

# The light: the pantry's own warm pendant for A and B (a key from the counter's side), the screens' cold glow for the
# room, a key on the old man's face from the screens' side and a warm rim from the door behind him.
HEAD = (STOP[0], 4.6, STOP[1])
shot.light("point", (PX - 1.5, 6.3, 0.8), color=(255, 205, 150), brightness=1.5, range=11, shadows=False, show=(0.0, T_DOOR + 0.4))
shot.light("spot", (STOP[0] - 1.0, 8.5, STOP[1] - 5.5), HEAD, color=(150, 200, 255), brightness=2.0, range=14, angle=55,
           show=(T_DOOR - 0.3, LENGTH))
shot.light("point", (PX - 7.5, 5.2, 0.4), color=(255, 196, 130), brightness=1.5, range=9, shadows=False, show=(T_DOOR - 0.5, LENGTH))
shot.light("spot", (ACE[0] + 2.0, 8.2, ACE[2] + 5.4), (ACE[0], 3.6, ACE[2]), color=(140, 180, 255), brightness=2.0, range=14, angle=60,
           show=(T_DOOR - 0.5, LENGTH))

# Sound and effects on the beats: a soft focus that goes where the eye should (the fist on the cup, the tray, his face, the
# hand on his chest), the cup's tick, the room's hum as he comes in, a heartbeat as nothing answers, the colour draining a
# little on the silence, and out to black (the role card comes up on the dark).
shot.event(0.9, "sfx", slot="clockTick")
shot.event(T_DOOR - 0.2, "sfx", slot="mapServerHum")
for t, slot, part, radius, rack in ((0.0, "self", "Torso", 7.0, 0.0), (0.85, "self", "Right Arm", 3.0, 0.5),
                                    (2.6, "self", "Torso", 6.0, 0.0), (T_DOOR, "self", "Torso", 9.0, 0.0),
                                    (HAND_UP - 0.25, "self", "Head", 3.2, 0.0), (HAND_UP + 0.2, "self", "Left Arm", 3.0, 0.5),
                                    (LINE_END + 0.55, "self", "Torso", 8.0, 0.0)):
    shot.event(t, "fx", name="focus", slot=slot, part=part, radius=radius, far=0.12, near=0.06, rack=rack)
shot.event(LINE_END + 0.2, "sfx", slot="heartbeat")
shot.event(LINE_END + 0.3, "fx", name="drain", strength=0.3, dur=2.0)
shot.event(LENGTH - 0.35, "fx", name="black")

shot.audio(voice="voiceButler", voice_at=SAID, bed="bedButler")
shot.line(SAID, "Is something the matter? Hmm? ... What's wrong?")
