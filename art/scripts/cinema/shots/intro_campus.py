"""The Campus intro (everyone, 22.6 s; the intro phase follows it): the exam hall at midnight. Rebuilt from scratch
(2026-10-28) after the notebook's fall in Death Note, episode 1 (art/refs/cinema/IntroCampus.toml): Light, bored at
his desk by the window while the class writes, sees a black notebook drop past outside. Ours: the whole hall bent
over the entrance exam, each candidate at their own rhythm; one player (picked at random by the server, never by
role) has finished, chin in hand; out in the night a black book falls past the lamp over the side door, and only he
turns; it lands in the snow; nobody else looked up.

Re-acted 2026-11-15 (the owner: "yes to all": every pose, camera and light redone; the story, the cuts, their lengths and
the set are as they were, since a re-paced version was once called ruined): the noticer is acted through (writing fast,
the page turned, the clock, the last stop, sitting back and tapping, sinking onto his arm, the snap, the lean to the door),
every candidate writes with the shoulders as well as the hand, every close shot of him is a long lens from the door's side
with a key and a cold rim on him, the first two shots have a rim from the stage end along the rows, the book is lit as it
turns. One sentence and the one big action are at the top of art/refs/cinema/IntroCampus.toml.

A  0.0-4.0   High from the back corner of the hall, craning down and in: the candidates writing under the lamps, a desk apart.
B  4.0-6.8   Low down the aisle between the blocks, creeping forward: pencils going on both sides, each their own.
C  6.8-9.6   The one by the side door, from the aisle in front on his right, a long lens pushing in: finished, sat back
             tapping his pencil with an eye on the clock, then sinking onto the arm laid along his desk, his eyes drifting
             to the door.
D  9.6-11.0  Outside, low, looking up the lit wall: something black drops fast out of the dark.
F  11.0-12.6 Time all but stops: a black book hanging in the air, turning over slowly in the lamp's light.
E  12.6-13.6 Inside, close from the aisle: he stills, then his head and body whip round to the door, into the lens.
G  13.6-15.8 Low in the snow outside: fast again, it lands under the lamp, the snow bursting; beyond the arch, the lit hall.
H  15.8-17.8 From the door's side at his eye line, a long lens creeping in and tilting: he stares into it.
I  17.8-19.6 From the doorway, rising and pulling right out: him, then the whole hall: everyone writing; only he is turned to the door.
   19.6-22.6 Black, then the case's card.

The exam hall (maps/venues/campus/auditorium.py, Campus scene space): desks (ExamDesk: the top 2.66 high, 1.7 deep,
its seat 1.35 behind it, 1.61 high) in five blocks of three, west edges at x -55.8 + 15.2k, rows at z -95, -90, -85,
all facing the stage (-z); the east wall at x 24.6 with the arched side door at z -94 and its lamp outside at
(26.3, 13, -94); outside, the snowy passage between the hall and the next building."""

import math
import random

from animlib import J
from cinema import footwork, framing
from cinema.acting import body_reach, soft, to_torso
from cinema.shot import Shot
from emotes.kit import CHIN, basis_angles, hold, reach
from motion import Motion

NAME = "IntroCampus"
BLACK = 19.6
LENGTH = BLACK + 3.0
TOP = 2.66  # an exam desk's top
HIP = 1.85  # the hips on its seat
LEGS = 56  # the thighs sloping down under the desk's rack (R6 legs do not bend)
SEAT_BACK = 1.4  # from a desk to the floor under the sitter's hips
PAPER = (0.1, -1.65)  # (the character's frame) the exam paper: across, forward
ABOVE = 0.78  # the fist this far over the paper puts the pencil's point on it (PEN_GRIP)
# (candidates sit every other desk, as an exam seats them: the two ends of each block of three; a body with its arms
# is 4 studs across and the desks stand 3.6 apart)
NOTICER_DESK = (14.0, -95.0)  # the front row's end, by the side door
NEAR = [(6.8, -95.0), (14.0, -90.0), (6.8, -90.0), (14.0, -85.0), (6.8, -85.0), (-1.2, -95.0), (-1.2, -90.0),
        (-8.4, -95.0), (-8.4, -90.0), (-1.2, -85.0), (-8.4, -85.0)]  # the players' desks, nearest him first
LAMP = (26.3, 13.0, -94.0)
BOOK_X, BOOK_Z = 28.8, -94.4
LANDING = (BOOK_X, 0.25, BOOK_Z)
# (t, y): out of the dark fast, then (the owner, 2026-10-28: "speed it down and then slow it down, anime-esque") nearly
# stopped in the air, tumbling slowly over the lamp's light, then fast again into the snow
FALL = [(9.4, 31.0), (10.9, 19.0), (11.1, 18.2), (12.45, 16.4), (12.6, 15.6), (13.72, 0.25)]
SLOW = (11.0, 12.5)
LANDS = FALL[-1][0]

# Bodies at the desks -------------------------------------------------------------------------------------


def body(lean, turn=0.0, roll=0.0):
    """Sitting at an exam desk: the hips on its seat, the thighs sloping under it, leaning `lean` (- forward)."""
    joints = dict(root=(lean, turn, roll), rHip=J((LEGS - lean * 0.5, -turn, 4)), lHip=J((LEGS - lean * 0.5, -turn, -4)))
    return joints, (0.0, HIP - 2.0, 0.0)


def paper(x, d, above=ABOVE):
    return (PAPER[0] + x, TOP + 0.01 + above, PAPER[1] + d)


def pencil(joints, off, x, d, above=ABOVE):
    return body_reach(1, joints, off, paper(x, d, above), direction=(-0.3, -0.6, -0.75))


def hold_paper(joints, off, x=0.0, d=0.0):
    return body_reach(-1, joints, off, paper(-0.95 + x, 0.15 + d, 0.55), direction=(0.25, -0.5, -0.85))


def key(m, t, ease="smooth", lean=-10.0, turn=0.0, roll=0.0, neck=(-22, 0, 0), right=None, left=None):
    joints, off = body(lean, turn, roll)
    r = right(joints, off) if callable(right) else (right if right is not None else pencil(joints, off, 0.0, 0.0))
    lv = left(joints, off) if callable(left) else (left if left is not None else hold_paper(joints, off))
    m.key(round(t, 4), ease, offset=off, neck=neck, rShoulder=r, lShoulder=lv, **joints)


# The candidates: every one their own (the owner, 2026-10-28: "don't reuse the same animation for the students in the
# background, or at least offset them"): VARIANTS looping clips, each with its own length (so no two ever line up),
# tempo, posture, handwriting and one habit; and every desk starts its clip at a different point.
VARIANTS = 16
HABITS = ["think", "clock", "erase", "stretch", "scratch", "flip", "rest", "tap"]


def candidate(v):
    rng = random.Random(1000 + v * 37)
    length = round(5.1 + 0.41 * v + rng.uniform(0.0, 0.2), 2)
    m = Motion(f"IntroCampus_w{v}", length, loop=True, note="The Campus intro: a candidate at the exam.")
    tempo = rng.uniform(0.17, 0.3)
    lean = rng.uniform(-15, -6)
    pitch = rng.uniform(-30, -18)
    tilt = rng.uniform(-6, 6)
    size = rng.uniform(0.05, 0.11)  # (how big their handwriting is)
    habit = HABITS[v % len(HABITS)]
    h0 = rng.uniform(1.0, length - 3.0)  # when the habit comes
    h1 = h0 + rng.uniform(1.3, 2.0)
    line = rng.uniform(-0.35, 0.3)

    def writing(t0, t1, line_d):
        t, x = t0, -0.35
        while t < t1 - 0.02:
            x += size * rng.uniform(0.7, 1.4)
            if x > 0.4:
                x, line_d = -0.35, line_d + 0.12
            yaw = tilt + 10 * x
            # (the whole body writes: the shoulders turn along the line with the hand, the weight comes forward as the
            # page fills)
            turn, lean_x = tilt * 0.3 + 5.0 * x, lean - 3.0 * (line_d + 0.35)
            key(m, t, "sine", lean_x, turn=turn, neck=(pitch, yaw, tilt * 0.5), right=lambda j, o, x=x, dd=line_d: pencil(j, o, x, dd))
            key(m, t + tempo * 0.5, "sine", lean_x, turn=turn, neck=(pitch, yaw, tilt * 0.5),
                right=lambda j, o, x=x, dd=line_d: pencil(j, o, x + size * 0.5, dd + 0.02, ABOVE + 0.06))
            t += tempo
        return line_d

    start = dict(lean=lean, neck=(pitch, tilt, tilt * 0.5), right=lambda j, o: pencil(j, o, -0.35, line))
    key(m, 0.0, "sine", **start)
    line_d = writing(tempo, h0, line)
    if habit == "think":  # the pencil to the chin, the eyes up and away
        key(m, h0 + 0.35, "sine", lean + 6, neck=(4, tilt + 14, 6), right=reach(1, (0.25, CHIN[1] - 0.05, CHIN[2] - 0.05)))
        key(m, h1 - 0.3, "sine", lean + 6, neck=(6, tilt + 18, 8), right=reach(1, (0.25, CHIN[1], CHIN[2] - 0.05)))
    elif habit == "clock":  # up at the clock over the stage, then back
        key(m, h0 + 0.3, "sine", lean + 5, neck=(14, tilt * 0.3, 0), right=lambda j, o: pencil(j, o, 0.2, line_d, ABOVE + 0.3))
        key(m, h1 - 0.35, "sine", lean + 5, neck=(12, tilt * 0.3, 2), right=lambda j, o: pencil(j, o, 0.2, line_d, ABOVE + 0.3))
    elif habit == "erase":  # rubbing out a mistake with the other hand, quick
        for k in range(7):
            key(m, h0 + 0.2 + 0.13 * k, "linear", lean - 2, neck=(pitch - 4, tilt, 0),
                right=lambda j, o: pencil(j, o, 0.35, line_d - 0.1, ABOVE + 0.35),
                left=lambda j, o, k=k: hold_paper(j, o, 0.65 + (0.1 if k % 2 else -0.1), -0.2))
    elif habit == "stretch":  # sitting back, the neck rolled
        key(m, h0 + 0.4, "sine", 4, neck=(18, tilt, 10), right=lambda j, o: pencil(j, o, 0.3, line_d, ABOVE + 0.6))
        key(m, h1 - 0.4, "sine", 3, neck=(14, tilt, -10), right=lambda j, o: pencil(j, o, 0.3, line_d, ABOVE + 0.6))
    elif habit == "scratch":  # a hand to the head, stuck
        key(m, h0 + 0.35, "sine", lean + 3, neck=(pitch + 10, tilt, -8), left=reach(-1, (-0.8, 1.7, -0.25)))
        key(m, h0 + 0.6, "sine", lean + 3, neck=(pitch + 10, tilt, -8), left=reach(-1, (-0.75, 1.8, -0.3)))
        key(m, h1 - 0.3, "sine", lean + 3, neck=(pitch + 8, tilt, -6), left=reach(-1, (-0.8, 1.7, -0.25)))
    elif habit == "flip":  # turning the page over
        key(m, h0 + 0.3, "sine", lean, turn=-4, neck=(pitch, tilt - 10, 0), left=lambda j, o: hold_paper(j, o, 1.2, -0.1),
            right=lambda j, o: pencil(j, o, 0.5, line_d, ABOVE + 0.4))
        key(m, h0 + 0.65, "sine", lean, turn=2, neck=(pitch, tilt + 6, 0), left=lambda j, o: hold_paper(j, o, 0.1, -0.2),
            right=lambda j, o: pencil(j, o, 0.5, line_d, ABOVE + 0.4))
        line_d = -0.35
    elif habit == "rest":  # the head on the other hand, writing slowly
        for k in range(int((h1 - h0) / 0.4)):
            key(m, h0 + 0.3 + 0.4 * k, "sine", lean - 3, neck=(pitch + 8, tilt - 6, -12), left=reach(-1, (-0.5, 1.15, -0.8)),
                right=lambda j, o, k=k: pencil(j, o, -0.2 + 0.08 * k, line_d))
    else:  # "tap": the pencil tapping on the paper, thinking
        for k in range(8):
            key(m, h0 + 0.2 + 0.15 * k, "linear", lean + 2, neck=(pitch + 8, tilt + 6, 4),
                right=lambda j, o, k=k: pencil(j, o, 0.1, line_d, ABOVE + (0.18 if k % 2 else 0.0)))
    writing(h1, length - 0.3, line_d)
    key(m, length, "sine", **start)
    soft(m, head=2.6, arms=3.0)
    m.build()


for v in range(VARIANTS):
    candidate(v)

# The noticer ------------------------------------------------------------------------------------------------
# Re-acted 2026-11-15 (the same story, cuts and lengths; art/refs/cinema/IntroCampus.toml): the one who has finished first.
# He writes fast and sure, turns his page over, glances at the clock, stabs the last full stop and throws the pencil up;
# sits back and taps; then sinks, his head laid on the arm that lies along his desk, the pencil's tapping slowing, his
# eyes drifting to the door; then, on the cut to the close shot, his head and body whip round to the door as one move
# (the wind-up, the snap, the overshoot), the arm off the desk, and he holds there, leaning towards it, as the others
# go on writing. (His left arm lies on the desk and carries his head: a straight R6 arm cannot prop a chin, the fist
# is nearer the cheek than the arm's own length; and from the camera on his right it is the far arm.)

SNAP = 12.74  # his body whips round to the door (the cut to E is at 12.6: the wind-up is seen, then the snap)
TURN = 12.6  # (the door's cold light comes on with the close shot)
rn = random.Random(61)


def lay_arm(j, o, x=-0.6, d=-1.5):
    """The left arm lying forward along the desk, the fist on it (the head rests on it)."""
    return body_reach(-1, j, o, (x, TOP + 0.5, d), direction=(0.0, -0.5, -0.85))


def tap(j, o, x, lift=0.0):
    """The right fist at the paper's near margin (the pencil tapped on it): nearer than the writing, so a body sat back
    reaches it."""
    return body_reach(1, j, o, paper(x, 0.38, ABOVE * 0.5 + lift), direction=(-0.3, -0.6, -0.75))


n = Motion("IntroCampus_noticer", LENGTH, note="The Campus intro: the one who sees the book fall.")


def write(t0, t1, line, x, k0=0):
    """Fast sure writing: the strokes' timing never the same twice, the body following the hand along the line and
    leaning in as the page fills."""
    t, k = t0, k0
    while t < t1 - 0.05:
        x += 0.11 * rn.uniform(0.75, 1.3)
        if x > 0.42:
            x, line = -0.35, line + 0.1
        dt = 0.2 + 0.035 * math.sin(1.9 * k) + rn.uniform(-0.015, 0.015)
        lean = -11.0 - 5.0 * line
        yaw, turn = 3 + 8 * x, 2.4 * x
        key(n, t, "sine", lean, turn=turn, neck=(-22, yaw, 2), right=lambda j, o, x=x, d=line: pencil(j, o, x, d))
        key(n, t + dt * 0.5, "sine", lean, turn=turn, neck=(-22, yaw, 2),
            right=lambda j, o, x=x, d=line: pencil(j, o, x + 0.05, d + 0.02, ABOVE + 0.06))
        t += dt
        k += 1
    return line, x, k


FLIP, CLOCK = 2.0, 4.0
line, x, k = write(0.0, FLIP - 0.35, 0.0, -0.35)
# the page turned over: the left hand sweeps to its far edge, lifts it and brings it across; the pencil waits in the air
key(n, FLIP - 0.2, "out", -12, turn=-3, neck=(-20, -6, 0), left=lambda j, o: hold_paper(j, o, 0.95, 0.0),
    right=lambda j, o: pencil(j, o, 0.3, line, ABOVE + 0.3))
key(n, FLIP + 0.3, "out", -11, turn=-6, neck=(-16, -12, -3), left=lambda j, o: hold_paper(j, o, 1.1, -0.2),
    right=lambda j, o: pencil(j, o, 0.3, line, ABOVE + 0.3))
key(n, FLIP + 0.75, "sine", -12, turn=1, neck=(-22, 4, 2), left=lambda j, o: hold_paper(j, o, 0.1, -0.1),
    right=lambda j, o: pencil(j, o, -0.35, 0.0, ABOVE + 0.1))
line, x, k = write(FLIP + 0.95, CLOCK, 0.0, -0.35, k)
# a quick look up at the clock over the stage (the pencil stops), then back down, faster
key(n, CLOCK + 0.1, "out", -8, neck=(16, 14, 2), right=lambda j, o: pencil(j, o, x, line, ABOVE + 0.2))
key(n, CLOCK + 0.55, "sine", -8, neck=(15, 15, 1), right=lambda j, o: pencil(j, o, x, line, ABOVE + 0.2))
line, x, k = write(CLOCK + 0.8, 5.45, line, x, k)
# the last full stop, pressed hard; the pencil thrown up off the page; he sits back
key(n, 5.6, "in", -16, neck=(-24, 2, 0), right=lambda j, o: pencil(j, o, 0.45, line + 0.1, ABOVE - 0.04))
key(n, 5.75, "out", -13, neck=(-14, 2, 0), right=lambda j, o: pencil(j, o, 0.55, line + 0.1, ABOVE + 0.5))
key(n, 6.3, "sine", 5, neck=(13, 11, 4), left=lambda j, o: hold_paper(j, o, 0.15, 0.3), right=lambda j, o: tap(j, o, 0.45, 0.3))
# C: sat back, looking up at the clock, the pencil tapping on the desk's edge (never at the same interval)
for tt, up in ((6.9, 0.0), (7.04, 0.3), (7.34, 0.0), (7.5, 0.3)):
    key(n, tt, "linear", 5, neck=(13, 11, 4), left=lambda j, o: hold_paper(j, o, 0.15, 0.3),
        right=lambda j, o, up=up: tap(j, o, 0.45, up))
# the slump: the shoulders go first and he sinks onto the arm laid along the desk; the head arrives after
key(n, 7.62, "sine", 0, neck=(8, 6, 8), left=lambda j, o: hold_paper(j, o, 0.15, 0.3), right=lambda j, o: tap(j, o, 0.45, 0.25))
key(n, 8.2, "out", -12, neck=(14, 0, 38), left=lay_arm, right=lambda j, o: tap(j, o, 0.5, 0.0))
# (propped, bored: the pencil taps slower and slower, then lies still; the head rolls round slowly to the door)
for tt, up in ((8.5, 0.28), (8.62, 0.0), (9.0, 0.22), (9.12, 0.0)):
    key(n, tt, "linear", -12, neck=(14, 0, 38), left=lay_arm, right=lambda j, o, up=up: tap(j, o, 0.5, up))
key(n, 9.5, "sine", -12, neck=(14, -16, 38), left=lay_arm, right=lambda j, o: tap(j, o, 0.5, 0.0))
# D, F: unseen; he sits as he was, his eyes on the door, the pencil lifting and dropping lazily a couple of times
for tt, up in ((10.4, 0.22), (10.52, 0.0), (11.45, 0.2), (11.57, 0.0)):
    key(n, tt, "linear", -12, neck=(14, -17, 38), left=lay_arm, right=lambda j, o, up=up: tap(j, o, 0.5, up))
key(n, 12.3, "sine", -12, neck=(14, -16, 38), left=lay_arm, right=lambda j, o: tap(j, o, 0.5, 0.0))
# the wind-up (seen at the cut): he stills, drawn back the other way a hair; then the snap: head and body whip round to
# the door, the left arm off the desk, the pencil dropped to the paper; the overshoot, and the settle into a lean
key(n, SNAP - 0.1, "out", -14, turn=5, roll=2, neck=(10, 10, 40), left=lay_arm, right=lambda j, o: tap(j, o, 0.5, 0.0))
key(n, SNAP + 0.1, "snap", -6, turn=-30, neck=(6, -50, -2), left=lambda j, o: hold_paper(j, o, 0.2, -0.2),
    right=lambda j, o: tap(j, o, 0.6, 0.12))
key(n, SNAP + 0.4, "out", -5, turn=-25, neck=(2, -43, 0), left=lambda j, o: hold_paper(j, o, 0.15, -0.25),
    right=lambda j, o: tap(j, o, 0.6, 0.06))
key(n, 13.55, "sine", -6, turn=-26, neck=(-3, -44, -2), left=lambda j, o: hold_paper(j, o, 0.15, -0.25),
    right=lambda j, o: tap(j, o, 0.6, 0.06))
# G, unseen: it lands; he flinches, then leans towards it
key(n, LANDS + 0.12, "snap", 0, turn=-26, neck=(-4, -45, 0), left=lambda j, o: hold_paper(j, o, 0.2, -0.2),
    right=lambda j, o: tap(j, o, 0.62, 0.15))
key(n, LANDS + 0.6, "sine", -5, turn=-27, neck=(-5, -45, -3), left=lambda j, o: hold_paper(j, o, 0.15, -0.25),
    right=lambda j, o: tap(j, o, 0.58, 0.0))
# H: the stare, creeping: leaning further, the head tilting
key(n, 15.8, "sine", -7, turn=-28, neck=(-5, -45, -5), left=lambda j, o: hold_paper(j, o, 0.15, -0.25),
    right=lambda j, o: tap(j, o, 0.58, 0.0))
key(n, 17.7, "sine", -10, turn=-30, neck=(-4, -46, -9), left=lambda j, o: hold_paper(j, o, 0.3, -0.3),
    right=lambda j, o: tap(j, o, 0.58, 0.0))
# I: still turned to the door; the left hand flat on the desk, the weight coming forward: he is about to rise
key(n, 18.6, "sine", -15, turn=-32, neck=(-3, -47, -10), left=lambda j, o: hold_paper(j, o, 0.5, -0.35),
    right=lambda j, o: tap(j, o, 0.55, 0.0))
key(n, LENGTH, "sine", -17, turn=-33, neck=(-2, -48, -11), left=lambda j, o: hold_paper(j, o, 0.5, -0.35),
    right=lambda j, o: tap(j, o, 0.55, 0.0))
soft(n, head=3.0, arms=3.0)
n.build()


def pen_grip():
    """The pencil in the right fist (solved writing on the paper's middle): its point (0.54 below its middle, along
    its -y) on the paper, its top leaning back towards the writer."""
    import numpy as np

    joints, off = body(-10)
    arm = pencil(joints, off, 0.0, 0.0)
    nib = np.array([0.15, -1.0, -0.5])
    nib = nib / np.linalg.norm(nib)
    middle = np.array(paper(0.0, 0.0, 0.0)) - nib * 0.54
    pos = to_torso(joints, off, tuple(middle))
    axis = to_torso(joints, off, direction=tuple(-nib))
    return hold("Right Arm", {"rShoulder": arm}, pos, basis_angles(axis, (0.0, 0.0, 1.0)))


PEN_GRIP = pen_grip()

# The shot -------------------------------------------------------------------------------------------------

shot = Shot(NAME, "Campus", LENGTH, note="Campus intro: the exam hall; one candidate sees the book fall.",
            skippable=True, mood="UniversityCampus_Inside")
shot.own = True  # players in their own avatars (the owner, 2026-10-28)
shot.allow = {}


def seat(a, desk, yaw=0.0):
    a.mark(0.0, (desk[0], 0.0, desk[1] + SEAT_BACK), yaw)
    a.hold("Pen", "Right Arm", PEN_GRIP[0]["p"], PEN_GRIP[1]["r"])
    shot.allow[a.slot] = ["ExamDesk"]  # (sat in their own desk's seat)


who = shot.actor("noticer", n)
seat(who, NOTICER_DESK)
rng = random.Random(28)
order = list(range(VARIANTS))
rng.shuffle(order)
used = 0
for k, desk in enumerate(NEAR):  # the players nearest him, each their own clip
    a = shot.actor(f"everyone:{k + 1}", clip=f"IntroCampus_w{order[used % VARIANTS]}", at=-rng.uniform(0.0, 5.0))
    seat(a, desk, rng.uniform(-3, 3))
    used += 1
# (only the match's players: twelve at most, the owner, 2026-10-28: "too many people otherwise")
footwork.apply(shot)  # (the feet planted where they come down, stepping after the body: cinema/footwork.py)

# The book: out of the dark, turning over, past the lamp, into the snow (a drift-limited fall, near 7 studs a second).
book = shot.prop("Grimoire", show=(FALL[0][0], LENGTH))
spins = [(20, 0, 10), (190, 80, 50), (205, 88, 54), (250, 112, 70), (262, 118, 74), (360, 25, 0)]
# (it lies still once down: its last key keeps the landing's turn, or it unwinds a whole turn on the ground)
for (t, y), rot in zip(FALL, spins):
    book.at(t, (BOOK_X + 0.4 * math.sin(t), y, BOOK_Z), rot, "linear" if t < LANDS else "in")
book.at(LENGTH, LANDING, spins[-1])

# The cameras, every one moving and held by hand (the owner, 2026-10-28).
# A: high from the back corner of the hall, craning down and in.
framing.dolly(shot, 0.0, 4.0, (21.5, 12.8, -79.2), (18.2, 8.8, -82.4), (-15.0, 2.0, -100.0), (0.0, 2.4, -95.0),
              fov0=54, fov1=44, shake=0.5, seed=1, cut=False)
# B: low down the aisle between the blocks, creeping forward.
framing.dolly(shot, 4.0, 6.8, (2.8, 3.7, -79.4), (2.9, 3.4, -84.6), (2.6, 3.2, -100.0), fov0=50, fov1=44, shake=0.5,
              seed=2)
# C: him, from almost straight in front (off the stage's edge): his face and the arm his head lies on, the wood-panelled
# wall behind him; a long lens from far enough that the head is half the frame, pushing in and drifting a little round
# to the left. (From his right the near arm covered the face; from his left the hair did.)
shot.pan(6.8, 9.6, "noticer", (16.4, 4.4, -103.2), aim="Head", dy=-0.15, fov=30, cut=True, drift=(-0.9, -0.1, 0.8),
         operator=True, seed=3, shake=0.4, fov_to=27, ease_move=True)
# D: outside, low in the passage looking up the lamp-lit wall into the night: something black drops out of the dark
# over it (seen against the lit brick, not the black sky).
framing.dolly(shot, 9.6, 11.0, (33.6, 4.5, -101.6), (33.4, 4.6, -101.2), (BOOK_X - 1.4, 24.0, BOOK_Z), (BOOK_X - 1.2, 20.0, BOOK_Z),
              fov0=58, fov1=54, shake=0.6, seed=4)
# F: with it as time all but stops: close on the book hanging in the air, turning over slowly in the lamp's light, the
# lens creeping in on its cover.
framing.dolly(shot, 11.0, 12.6, (31.9, 19.4, -98.0), (31.7, 17.0, -97.8), (BOOK_X - 0.5, 18.4, BOOK_Z), (BOOK_X - 0.5, 15.9, BOOK_Z),
              fov0=40, fov1=36, roll0=6.0, roll1=9.0, shake=0.4, seed=5, ease_move=True)
# E: the same side, nearer and tighter: he stills, then his head and body whip round to the door and into the lens; the
# hand-held frame jolts with it.
shot.pan(12.6, 13.6, "noticer", (19.4, 5.0, -100.0), aim="Head", dy=-0.1, fov=34, cut=True, drift=(-0.2, 0.0, 0.3),
         operator=True, seed=6, shake=0.9, fov_to=29)
# G: low in the snow outside: it lands under the lamp; beyond the arch, the lit hall.
framing.dolly(shot, 13.6, 15.8, (34.2, 1.1, -100.9), (33.3, 1.0, -100.0), (27.2, 2.4, -94.2), fov0=48, fov1=42, shake=0.4,
              seed=7)
# H: from the door's side, a long lens, level with his eyes, so he stares straight into it; creeping in, tilted.
shot.pan(15.8, 17.8, "noticer", (22.4, 5.0, -93.6), aim="Head", dy=-0.1, fov=33, cut=True, drift=(-0.6, 0.0, 0.1),
         roll=-6.0, operator=True, seed=8, shake=0.35, fov_to=28, ease_move=True)
# I: from the doorway, rising and pulling back all the way out: first on him, turned to the door, then the whole hall
# behind him still writing, and he the only one still. (The last shot: it ends on that wide, held to the black.)
framing.dolly(shot, 17.8, BLACK, (22.8, 5.2, -92.6), (23.6, 8.2, -90.2), (14.6, 4.6, -93.6), (7.0, 3.4, -94.6),
              fov0=40, fov1=54, shake=0.4, seed=9)
shot.subjects.append((BLACK, LENGTH, None, True))
shot.cam(BLACK, (3.0, 11.8, -100.4), (14.0, 3.0, -93.0), fov=64, cut=True)
shot.cam(LENGTH, (3.0, 11.8, -100.4), (14.0, 3.0, -93.0), fov=64, ease="linear")

# The lens: barely soft.
for t, slot, part, radius in ((6.8, "noticer", "Head", 3.0), (12.6, "noticer", "Head", 2.5), (15.8, "noticer", "Head", 2.0),
                              (17.8, "noticer", "Head", 8.0)):
    shot.event(t, "fx", name="focus", slot=slot, part=part, radius=radius, far=0.12, near=0.06)
for t in (0.0, 9.6, 13.6):
    shot.event(t, "fx", name="focus")

# The light: night; the hall warm under its lamps, the snow's cold light at the windows and through the door; a warm
# key on him from the lamp over his desk; once he turns, the cold light from the door on his face; outside, the
# lamp's warm pool on the snow and a cold fill on the night. The grade: cool, a little drained.
HEAD = (NOTICER_DESK[0], 4.9, NOTICER_DESK[1] + SEAT_BACK)
shot.grade = (0.18, -0.1, -0.02, (232, 238, 255))
shot.light("spot", (12.0, 10.0, -97.0), HEAD, color=(255, 214, 160), brightness=1.6, range=12, angle=45)
shot.light("spot", (23.8, 6.0, -94.0), HEAD, color=(190, 210, 255), brightness=1.5, range=14, angle=35,
           show=(TURN, BLACK))
# (a cold rim from behind him, opposite the lens in every close shot of him, so his head and shoulder come off the dark
# rows behind; on again for the stare and the last wide)
shot.light("spot", (8.0, 9.0, -87.0), HEAD, color=(170, 200, 255), brightness=1.5, range=14, angle=40, shadows=False,
           show=(6.8, 9.6))
shot.light("spot", (8.0, 9.0, -87.0), HEAD, color=(170, 200, 255), brightness=1.5, range=14, angle=40, shadows=False,
           show=(TURN, BLACK))
# (the candidates in the first two shots, seen from behind and above: a cold light from the stage end along the rows
# rims the tops of their heads and shoulders against the warm pools of the pendants)
shot.light("spot", (-3.0, 10.0, -105.0), (0.0, 3.0, -90.0), color=(160, 190, 255), brightness=1.2, range=26, angle=50,
           shadows=False, show=(0.0, 6.8))
shot.light("spot", (11.0, 10.0, -105.0), (9.0, 3.0, -90.0), color=(160, 190, 255), brightness=1.2, range=26, angle=50,
           shadows=False, show=(0.0, 6.8))
# (the book hanging in the air: the lamp's light on its cover as it turns)
shot.light("spot", (31.0, 17.8, -99.0), (BOOK_X - 0.5, 17.0, BOOK_Z), color=(255, 226, 180), brightness=2.0, range=12,
           angle=40, shadows=False, show=(SLOW[0], 12.6))
shot.light("spot", (LAMP[0] + 0.4, LAMP[1] - 0.6, LAMP[2]), LANDING, color=(255, 210, 150), brightness=2.2, range=20,
           angle=55)
shot.light("spot", (38.0, 14.0, -104.0), (BOOK_X, 8.0, BOOK_Z), color=(150, 170, 230), brightness=1.0, range=30, angle=45,
           shadows=False)
shot.light("spot", (31.5, 2.5, -98.5), (BOOK_X - 0.8, 20.0, BOOK_Z), color=(205, 220, 255), brightness=2.4, range=34,
           angle=24, shadows=False, show=(9.4, 13.6))  # (the snow's glow up the wall: the book black against lit brick)

# Sound: the hall's clock and the pencils; the wind outside; the book's thud; a heartbeat on his stare.
shot.event(0.0, "sfx", slot="clockTick")
shot.event(0.0, "sfx", slot="penScratch")
shot.event(0.4, "title", lines=["KAGEGAOKA UNIVERSITY", "Entrance exam, 23:58"], dur=3.2)
shot.event(FLIP + 0.3, "sfx", slot="pageTurn")  # (the page turned over)
shot.event(5.6, "sfx", slot="penStop")  # (the last full stop)
for tt in (6.9, 7.34, 8.62, 9.12):  # (the pencil tapping on the desk: the slot's own short tap)
    shot.event(tt, "sfx", slot="penStop")
shot.event(9.6, "sfx", slot="mapWindSnow")
shot.event(SLOW[0], "fx", name="pulse", punch=0.05, dur=1.4)  # (time slows: the lens breathes in)
shot.event(SLOW[0], "sfx", slot="wisp")
shot.event(SLOW[1], "fx", name="flash", r=230, g=236, b=255, strength=0.25, dur=0.25)  # (and snaps back)
shot.event(LANDS, "sfx", slot="bookImpact")
shot.event(LANDS, "fx", name="snowburst", pos=list(LANDING))
shot.event(LANDS, "fx", name="shake", strength=0.18, dur=0.2)
shot.event(SNAP + 0.1, "fx", name="shake", strength=0.2, dur=0.18)  # (the jolt of the turn)
shot.event(15.8, "sfx", slot="heartbeat")
shot.event(16.0, "fx", name="drain", strength=0.35, dur=2.6)  # (the colour slowly leaves while he stares)
shot.event(BLACK, "fx", name="black", hush=True)
shot.event(BLACK + 0.5, "card", key="case", dur=LENGTH - BLACK - 0.5)
