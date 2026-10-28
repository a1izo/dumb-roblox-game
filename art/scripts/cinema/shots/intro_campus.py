"""The Campus intro (everyone, 22.6 s; the intro phase follows it): the exam hall at midnight. Rebuilt from scratch
(2026-10-28) after the notebook's fall in Death Note, episode 1 (art/refs/cinema/IntroCampus.toml): Light, bored at
his desk by the window while the class writes, sees a black notebook drop past outside. Ours: the whole hall bent
over the entrance exam, each candidate at their own rhythm; one player (picked at random by the server, never by
role) has finished, chin in hand; out in the night a black book falls past the lamp over the side door, and only he
turns; it lands in the snow; nobody else looked up.

Re-paced (2026-10-28, the owner: "the pacing is kinda bad and generally boring"): to him sooner, the fall longer and
slower, and a payoff: he gets up and goes to it.

A  0.0-2.4   High from the back corner of the hall, craning down and in: the candidates writing under the lamps.
B  2.4-4.4   The one by the side door, from in front: finished, sat back, twirling his pencil, an eye on the clock.
B2 4.4-5.4   Close: his pencil tapping on the finished paper.
C  5.4-6.4   His face from the door's side: the eyes drifting to the dark... catching something.
D  6.4-7.4   Outside, low, looking up the lit wall: something black drops fast out of the dark.
F  7.4-10.2  Time all but stops: a black book hanging in the air, turning over slowly in the lamp's light.
G  10.2-11.2 Low in the snow: fast again, it hits under the lamp as the clock strikes midnight.
H  11.2-12.8 His face, pushing in: he stares.
I  12.8-16.4 From the hall's front corner: he gets up, leaves his pencil, and walks to the door between the writing
             candidates; nobody else looks up.
J  16.4-19.6 Outside, low behind the book: he comes into the lit archway and stops, looking down at it.
   19.6-22.6 Black, then the case's card.

The exam hall (maps/venues/campus/auditorium.py, Campus scene space): desks (ExamDesk: the top 2.66 high, 1.7 deep,
its seat 1.35 behind it, 1.61 high) in five blocks of three, west edges at x -55.8 + 15.2k, rows at z -95, -90, -85,
all facing the stage (-z); the east wall at x 24.6 with the arched side door at z -94 and its lamp outside at
(26.3, 13, -94); outside, the snowy passage between the hall and the next building."""

import math
import random

from animlib import J
from cinema import framing
import posekit
from cinema.acting import body_reach, soft, to_torso, walking
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
FALL = [(6.3, 31.0), (7.4, 20.6), (7.6, 19.7), (9.8, 16.6), (10.0, 15.6), (10.45, 0.25)]
SLOW = (7.5, 9.9)
LANDS = FALL[-1][0]
CUTS = (2.4, 4.4, 5.4, 6.4, 7.4, 10.2, 11.2, 12.8, 16.4)  # B, B2, C, D, F, G, H, I, J
TAP = (4.5, 5.4)  # his pencil tapping (B2)
CATCH = 6.0  # his eyes catch it
RISE = (12.9, 13.6)  # up out of the desk
WALK = (13.9, 16.2)  # to the door
DOOR = (23.3, -93.9)  # where he stops, in the doorway
WALK_FROM = (15.5, -93.4)  # (stepped out of his seat to its right)
WALK_SPEED = math.hypot(DOOR[0] - WALK_FROM[0], DOOR[1] - WALK_FROM[1]) / (WALK[1] - WALK[0])

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
            key(m, t, "sine", lean, neck=(pitch, yaw, tilt * 0.5), right=lambda j, o, x=x, dd=line_d: pencil(j, o, x, dd))
            key(m, t + tempo * 0.5, "sine", lean, neck=(pitch, yaw, tilt * 0.5),
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
# Finished, sat back, bored: the pencil twirled, an eye on the clock, a sigh, the pencil tapping; his eyes drifting to
# the door's dark... they catch something; he follows it down; flinches as it lands; stares. Then he gets up, leaves
# his pencil on the desk, and walks between the writing candidates to the open door, and stops there, looking down
# at it in the snow. Nobody else looks up.

n = Motion("IntroCampus_noticer", LENGTH, note="The Campus intro: the one who sees the book fall, and goes to it.")
TWIRL = [(0.62, 0.15), (0.55, 0.05), (0.66, 0.0), (0.58, 0.12)]
k = 0
for tt in [round(0.35 * i, 2) for i in range(12)]:  # (0 .. 3.85)
    x, d = TWIRL[k % 4]
    look = (10, -2, 6) if 2.3 <= tt <= 3.0 else (-2, -16 - 4 * math.sin(tt), 12)  # (up at the clock once)
    key(n, tt, "sine", 1, neck=look, left=lambda j, o: hold_paper(j, o, 0.15, 0.25),
        right=lambda j, o, x=x, d=d: pencil(j, o, x, d + 0.2, ABOVE + 0.2))
    k += 1
key(n, 4.0, "sine", 3.5, neck=(-4, -14, 12), left=lambda j, o: hold_paper(j, o, 0.15, 0.25),
    right=lambda j, o: pencil(j, o, 0.5, 0.3, ABOVE + 0.25))  # (the sigh)
for k in range(7):  # the pencil tapping on the finished paper, bored
    key(n, TAP[0] + 0.15 * k, "linear", 1, neck=(-8, -12, 12), left=lambda j, o: hold_paper(j, o, 0.15, 0.25),
        right=lambda j, o, k=k: pencil(j, o, 0.45, 0.3, ABOVE + (0.22 if k % 2 else 0.02)))
key(n, CATCH, "sine", 1, neck=(-2, -20, 10), left=lambda j, o: hold_paper(j, o, 0.15, 0.25),
    right=lambda j, o: pencil(j, o, 0.45, 0.3, ABOVE + 0.15))
# something past the door's dark: the head round to it, the body after
key(n, CATCH + 0.25, "out", -1, turn=-12, neck=(8, -42, 0), left=lambda j, o: hold_paper(j, o, 0.15, 0.2),
    right=lambda j, o: pencil(j, o, 0.5, 0.3, ABOVE + 0.15))
key(n, SLOW[0], "sine", -2, turn=-20, neck=(10, -42, 0), left=lambda j, o: hold_paper(j, o, 0.15, 0.2),
    right=lambda j, o: pencil(j, o, 0.5, 0.3, ABOVE + 0.15))
key(n, SLOW[1], "sine", -3, turn=-22, neck=(4, -43, 0), left=lambda j, o: hold_paper(j, o, 0.15, 0.2),
    right=lambda j, o: pencil(j, o, 0.5, 0.3, ABOVE + 0.15))
key(n, LANDS - 0.02, "in", -3, turn=-24, neck=(-10, -43, 0), left=lambda j, o: hold_paper(j, o, 0.15, 0.2),
    right=lambda j, o: pencil(j, o, 0.5, 0.3, ABOVE + 0.15))
key(n, LANDS + 0.12, "snap", 2, turn=-25, neck=(-4, -44, 0), left=lambda j, o: hold_paper(j, o, 0.2, 0.15),
    right=lambda j, o: pencil(j, o, 0.6, 0.25, ABOVE + 0.35))  # (the flinch)
key(n, LANDS + 0.5, "sine", -4, turn=-25, neck=(-7, -44, 0), left=lambda j, o: hold_paper(j, o, 0.15, 0.2),
    right=lambda j, o: pencil(j, o, 0.55, 0.3, ABOVE + 0.05))
key(n, RISE[0], "sine", -6, turn=-26, neck=(-7, -45, -6), left=lambda j, o: hold_paper(j, o, 0.15, 0.2),
    right=lambda j, o: pencil(j, o, 0.55, 0.3, ABOVE + 0.05))
# up out of the desk: the hands pushing on its edge, the weight forward and up, stepping back out of the seat
key(n, RISE[0] + 0.3, "sine", -18, turn=-14, neck=(-14, -30, 0), left=lambda j, o: hold_paper(j, o, 0.1, 0.5),
    right=lambda j, o: body_reach(1, j, o, paper(0.7, 0.55, 0.45), direction=(-0.1, -0.6, -0.8)))
STAND = {"rHip": J((0, 0, 2)), "lHip": J((0, 0, -2))}
up = posekit.on_floor({"root": J((-10, -10, 0)), **STAND}, (0.0, 0.0, 0.0), floor=0.0)
n.key(RISE[1], "out", offset=up, root=(-10, -10, 0), neck=(-16, -34, 0), rShoulder=J((10, 0, 6)),
      lShoulder=J((10, 0, -6)), **STAND)
# turned to the door (the path turns him), and walking to it, the head up and fixed on the door
n.key(WALK[0], "sine", offset=up, root=(-4, 0, 0), neck=(-4, 0, 0), rShoulder=J((6, 0, 5)), lShoulder=J((6, 0, -5)),
      **STAND)
for k, tt in enumerate([WALK[0] + 0.25 + 0.42 * i for i in range(int((WALK[1] - WALK[0]) / 0.42))]):
    s = 1 if k % 2 else -1  # (the arms swinging against the stride)
    n.key(tt, "sine", offset=up, root=(-6, 2 * s, 0), neck=(-6, -2 * s, 0), rShoulder=J((14 * s, 0, 5)),
          lShoulder=J((-14 * s, 0, -5)), **STAND)
# in the doorway: stopped, looking down at it in the snow
n.key(WALK[1] + 0.3, "out", offset=up, root=(-6, 0, 0), neck=(-30, 0, 0), rShoulder=J((4, 0, 6)), lShoulder=J((4, 0, -6)),
      **STAND)
n.key(LENGTH, "sine", offset=up, root=(-8, 0, 0), neck=(-34, 0, 7), rShoulder=J((4, 0, 6)), lShoulder=J((4, 0, -6)),
      **STAND)
walking(n, WALK[0], WALK[1], speed=WALK_SPEED)
n.plant(RISE[1], WALK[0], stance=0.06)
n.plant(WALK[1], None, stance=0.06)
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
who.held[-1] = who.held[-1][:5] + (RISE[0] + 0.3,) + who.held[-1][6:]  # (the pencil left on the desk as he gets up)
# getting up: a step out to the right of his seat, turned to the door, and walking to it
who.mark(RISE[0] + 0.1, (NOTICER_DESK[0], 0.0, NOTICER_DESK[1] + SEAT_BACK), 0.0)
who.mark(RISE[1], (WALK_FROM[0], 0.0, WALK_FROM[1]), -20.0)
who.mark(WALK[0], (WALK_FROM[0], 0.0, WALK_FROM[1]), -88.0)
who.mark(WALK[1], (DOOR[0], 0.0, DOOR[1]), -90.0, "linear")
who.mark(LENGTH, (DOOR[0], 0.0, DOOR[1]), -90.0)
rng = random.Random(28)
order = list(range(VARIANTS))
rng.shuffle(order)
used = 0
for k, desk in enumerate(NEAR):  # the players nearest him, each their own clip
    a = shot.actor(f"everyone:{k + 1}", clip=f"IntroCampus_w{order[used % VARIANTS]}", at=-rng.uniform(0.0, 5.0))
    seat(a, desk, rng.uniform(-3, 3))
    used += 1
# (only the match's players: twelve at most, the owner, 2026-10-28: "too many people otherwise")

# The book: out of the dark fast, all but stopped in the air turning over in the lamp's light, then fast again into
# the snow as the clock strikes midnight.
book = shot.prop("Grimoire", show=(FALL[0][0], LENGTH))
spins = [(20, 0, 10), (190, 80, 50), (205, 88, 54), (250, 112, 70), (262, 118, 74), (360, 25, 0)]
# (it lies still once down: its last key keeps the landing's turn, or it unwinds a whole turn on the ground)
for (t, y), rot in zip(FALL, spins):
    book.at(t, (BOOK_X + 0.4 * math.sin(t), y, BOOK_Z), rot, "linear" if t < LANDS else "in")
book.at(LENGTH, LANDING, spins[-1])
pencil_left = shot.prop("Pen", show=(RISE[0] + 0.3, LENGTH))  # (his pencil, left on the desk)
pencil_left.at(0.0, (NOTICER_DESK[0] + 0.5, TOP + 0.06, NOTICER_DESK[1] - 0.1), (0, 0, 90))
pencil_left.at(LENGTH, (NOTICER_DESK[0] + 0.5, TOP + 0.06, NOTICER_DESK[1] - 0.1), (0, 0, 90))

# The cameras, every one moving and held by hand (the owner, 2026-10-28; then "the pacing is bad, boring": to him
# sooner, the fall longer and slower, and a payoff: he goes to it).
# A: high from the back corner of the hall, craning down and in.
framing.dolly(shot, 0.0, CUTS[0], (21.0, 13.0, -79.6), (19.6, 11.0, -81.4), (-15.0, 2.0, -100.0), (-12.0, 2.6, -98.0),
              fov0=56, fov1=50, shake=0.4, seed=1, cut=False)
# B: him, from in front on his right, pushing in: bored.
shot.pan(CUTS[0], CUTS[1], "noticer", (16.7, 5.3, -99.6), aim="Head", dy=-0.1, fov=42, cut=True, drift=(0.4, 0.1, 0.9),
         operator=True, seed=3, shake=0.4, fov_to=35, ease_move=True)
# B2: his pencil tapping on the finished paper, close.
framing.dolly(shot, CUTS[1], CUTS[2], (15.9, 4.4, -97.6), (15.6, 4.2, -97.2), (NOTICER_DESK[0] + 0.4, TOP + 0.3, -95.2),
              fov0=40, fov1=36, roll0=-5.0, roll1=-7.0, shake=0.4, seed=10)
# C: his face from the door's side: the eyes drifting to the dark... and catching something.
shot.pan(CUTS[2], CUTS[3], "noticer", (18.6, 5.3, -94.2), aim="Head", dy=-0.1, fov=38, cut=True, drift=(-0.3, 0.0, 0.1),
         roll=-5.0, operator=True, seed=11, shake=0.4, fov_to=32, ease_move=True)
# D: outside, low, looking up the lit wall: it drops fast out of the dark.
framing.dolly(shot, CUTS[3], CUTS[4], (33.6, 4.5, -101.6), (33.4, 4.6, -101.2), (BOOK_X - 1.4, 26.0, BOOK_Z),
              (BOOK_X - 1.2, 20.0, BOOK_Z), fov0=58, fov1=54, shake=0.7, seed=4)
# F: time all but stops: close on the book hanging in the air, turning over slowly in the lamp's light.
framing.dolly(shot, CUTS[4], CUTS[5], (31.9, 20.6, -98.0), (31.7, 17.0, -97.8), (BOOK_X - 0.5, 19.6, BOOK_Z),
              (BOOK_X - 0.5, 16.2, BOOK_Z), fov0=42, fov1=36, roll0=6.0, roll1=10.0, shake=0.4, seed=5, ease_move=True)
# G: low in the snow: fast again, it hits under the lamp; beyond the arch, the lit hall.
framing.dolly(shot, CUTS[5], CUTS[6], (34.2, 1.1, -100.9), (33.8, 1.05, -100.5), (27.4, 2.2, -94.2), fov0=48, fov1=44,
              shake=0.9, seed=7)
# H: his face, from between him and the door, pushing in: he stares.
shot.pan(CUTS[6], CUTS[7], "noticer", (18.6, 5.3, -94.2), aim="Head", dy=-0.1, fov=36, cut=True, drift=(-0.5, 0.0, 0.1),
         roll=-7.0, operator=True, seed=8, shake=0.35, fov_to=29, ease_move=True)
# I: from the hall's front corner: he gets up and walks between the writing candidates to the door, towards us;
# nobody else looks up.
shot.pan(CUTS[7], CUTS[8], "noticer", (21.6, 6.2, -101.2), aim="Torso", dy=0.6, fov=46, cut=True,
         drift=(0.6, -0.2, 0.4), operator=True, seed=12, shake=0.5, fov_to=40, ease_move=True)
# J: outside, low in the snow behind the book: he comes into the lit archway and stops, looking down at it.
framing.dolly(shot, CUTS[8], BLACK, (34.6, 1.3, -99.6), (33.9, 1.25, -99.0), (26.8, 2.3, -94.3), (26.7, 2.4, -94.3),
              fov0=50, fov1=46, shake=0.4, seed=13)  # (the book in the snow in front, him in the arch beyond)
shot.subjects.append((BLACK, LENGTH, None, True))
shot.cam(BLACK, (33.9, 1.25, -99.0), (26.7, 2.4, -94.3), fov=46, cut=True)
shot.cam(LENGTH, (33.9, 1.25, -99.0), (26.7, 2.4, -94.3), fov=46, ease="linear")

# The lens: barely soft.
for t, part, radius in ((CUTS[0], "Head", 3.0), (CUTS[2], "Head", 2.5), (CUTS[6], "Head", 2.0), (CUTS[7], "Torso", 5.0)):
    shot.event(t, "fx", name="focus", slot="noticer", part=part, radius=radius, far=0.12, near=0.06)
for t in (0.0, CUTS[1], CUTS[3], CUTS[8]):
    shot.event(t, "fx", name="focus")

# The light: night; the hall warm under its lamps, the snow's cold light at the windows and through the door; a warm
# key on him from the lamp over his desk; once he turns, the cold light from the door on his face; outside, the
# lamp's warm pool on the snow and a cold fill on the night; and in the doorway at the end, the hall's warm light
# behind him and the snow's cold glow up into his face. The grade: cool, a little drained.
HEAD = (NOTICER_DESK[0], 4.9, NOTICER_DESK[1] + SEAT_BACK)
shot.grade = (0.18, -0.1, -0.02, (232, 238, 255))
shot.light("spot", (12.0, 10.0, -97.0), HEAD, color=(255, 214, 160), brightness=1.6, range=12, angle=45, show=(0.0, CUTS[7]))
shot.light("spot", (23.8, 6.0, -94.0), HEAD, color=(190, 210, 255), brightness=1.5, range=14, angle=35,
           show=(CATCH, CUTS[7]))
shot.light("spot", (LAMP[0] + 0.4, LAMP[1] - 0.6, LAMP[2]), LANDING, color=(255, 210, 150), brightness=2.2, range=20,
           angle=55)
shot.light("spot", (38.0, 14.0, -104.0), (BOOK_X, 8.0, BOOK_Z), color=(150, 170, 230), brightness=1.0, range=30, angle=45,
           shadows=False)
shot.light("spot", (31.5, 2.5, -98.5), (BOOK_X - 0.8, 20.0, BOOK_Z), color=(205, 220, 255), brightness=2.4, range=34,
           angle=24, shadows=False, show=(FALL[0][0], LANDS + 0.4))  # (the snow's glow up the wall: the book black against lit brick)
shot.light("spot", (31.0, 17.2, -97.2), (BOOK_X, 18.0, BOOK_Z), color=(255, 220, 170), brightness=2.6, range=10, angle=30,
           shadows=False, show=SLOW)  # (the lamp's warmth on the book as it hangs there: its cover read)
shot.light("spot", (28.6, 1.2, -95.6), (DOOR[0] - 1.2, 4.8, DOOR[1]), color=(200, 216, 255), brightness=1.8, range=12,
           angle=40, show=(CUTS[8], LENGTH))  # (the snow's glow up into his face in the doorway)

# Sound: the hall's clock and the pencils; the tap of his pencil; the wind outside; the book's thud as the clock strikes
# midnight; a heartbeat on his stare; his steps.
shot.event(0.0, "sfx", slot="clockTick")
shot.event(0.0, "sfx", slot="penScratch")
shot.event(0.4, "title", lines=["KAGEGAOKA UNIVERSITY", "Entrance exam, 23:59"], dur=2.6)
shot.event(CUTS[3], "sfx", slot="mapWindSnow")
shot.event(SLOW[0], "fx", name="pulse", punch=0.05, dur=1.6)  # (time slows: the lens breathes in)
shot.event(SLOW[0], "sfx", slot="wisp")
shot.event(SLOW[1], "fx", name="flash", r=230, g=236, b=255, strength=0.25, dur=0.25)  # (and snaps back)
shot.event(LANDS, "sfx", slot="bookImpact")
shot.event(LANDS, "fx", name="snowburst", pos=list(LANDING))
shot.event(LANDS, "fx", name="shake", strength=0.25, dur=0.25)
shot.event(LANDS + 0.05, "sfx", slot="bell")  # (midnight)
shot.event(CUTS[6], "sfx", slot="heartbeat")
shot.event(BLACK, "fx", name="black", hush=True)
shot.event(BLACK + 0.5, "card", key="case", dur=LENGTH - BLACK - 0.5)
