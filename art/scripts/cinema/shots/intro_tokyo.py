"""The Tokyo intro (everyone, 24.6 s; the intro phase follows it): the platform. After Raye Penber's death in the
subway (Death Note; art/refs/cinema/IntroTokyo.toml): a man seizes up at the train's door while the one inside the
car watches. Ours: both are random players and nobody dies; the one in the car writes the last stroke of a name in
the Manual, the man on the platform's heart seizes on the cut, and the writer watches him go down and shuts the book.

A  0.0-5.0   Wide on the platform: people waiting here and there, a pair talking, someone walking through; the car
             brakes in behind the glass screen doors. The victim waits a little back from the glass.
B  5.0-7.4   On the platform over his shoulder, up into the doorway: the doors open on a man writing in a black book.
W  7.4-8.2   Insert over his shoulder: the pen finishes the name and lifts off the page.
C  8.2-10.9  Hard cut on the jolt, three-quarter front from the east: both hands to his chest, folded over, gasping;
             the head lifts once to the car; the knees give (the reference's straight drop, 0.7 s).
D  10.9-14.6 Low from the side: he tips forward over his feet, the legs give under him, and over onto his face (a body tipping about
             its knees), the chest bouncing once, the limp arm landing a beat late.
E  14.6-16.0 Low behind him, along his body, dutch: the writer looks down at him.
I  16.0-17.2 Insert: the other hand comes over and shuts the book.
F  17.2-18.6 Close on the writer, dutch the other way: his head comes up from the body to look out at us, smiling.
H  18.6-21.6 Low on the car's floor, out through the doorway: the victim in the middle, reaching out a hand; the doors
             slide shut over a riser and the instant they meet: black.
   21.6-24.6 Black: half a second of silence, then the case's card.

Acting reference (art/refs/cinema/IntroTokyo.toml): the knee drop from "How to Faint Safely on Stage"
(youtube.com/watch?v=LBxUsAzjL84, 212.1-214.0 s, side view): the knees buckle and the body drops straight down,
upright, in 0.7 s, then settles back onto the heels, the head drooping. Nothing thrashes.

The metro (maps/venues/tokyo/plan.py, Tokyo scene space): the island platform at y -20 (x -140..-30, z -73..-51), its
north edge's glass screen doors at z -51.4 in 6-stud bays centred at x -136 + 6k, the yellow tactile strip at
z -52.1..-53.1, the stairwell at its west end (x -146..-121); the north track's middle at z -46.5. The car
(TrainCarOpen) runs along x with its open doorway facing the platform, its floor level with it."""

import math

from animlib import J
from cinema import framing
from cinema.acting import alive, facing, kneel, seated, soft, strike, walking
from cinema.shot import Shot
from emotes.kit import CHEST, hold, reach
from motion import Motion

NAME = "IntroTokyo"
BLACK = 21.6  # the doors meet: cut to black
LENGTH = BLACK + 3.0  # the black, the silence and the case's card
FLOOR = -20.0
GLASS_Z = -51.4
DOOR_X = -88.0  # the car's open doorway, in line with a screen-door bay
TRACK_Z = -46.5
CAR_DOOR = 6.4  # the doorway's middle from the car's pivot, along x (the prop's DOOR_Y, turned)
CAR_Y = FLOOR - 1.5  # the car's floor is 1.5 over its pivot: level with the platform
STOP = DOOR_X - CAR_DOOR
ARRIVE, STOPPED = (0.0, STOP + 52.0), (4.6, STOP)
DOORS_OPEN, DOORS_SHUT = (5.0, 5.7), (BLACK - 1.0, BLACK)

VICTIM = (DOOR_X, -55.2)  # waiting a little back from the glass, behind the yellow strip, facing it
WATCHER = (DOOR_X - 1.0, -47.6)  # in the car, in the doorway's west half, 2 back (clear of the closing leaves)
WRITE = (5.4, 8.05)  # the writer's pen on the page; the last stroke ends it
JOLT = 8.2  # on the cut
INCLINE = 10.9  # he tips forward over his feet
KNEES = (11.45, 11.95)  # the legs give .. the knees on the floor
TIP, TIP_LEAN = 11.97, 52.0  # and straight on over, from that lean
SHUT = (16.25, 16.85)  # the book shut


def ride(actor, x_in_car, z, yaw, y=FLOOR + 0.1):
    """Everyone in the car rides it in and stays: their marks keep their place in it."""
    for t, x, ease in ((ARRIVE[0], ARRIVE[1], "smooth"), (STOPPED[0], STOPPED[1], "out"), (LENGTH, STOPPED[1], "smooth")):
        actor.mark(t, (x + x_in_car, y, z), yaw, ease)


def prone(m, t, ease="smooth", lean=-90.0, head=12.0, **upper):
    """A key lying face down: the legs straight out along the floor (not the kneel's folded ones, which held the
    body up off it), the body resting on the floor."""
    m.key(t, ease, floor=True, root=(lean, 0, 0), neck=(head, 0, 6), rHip=J((-2, 0, 3)), lHip=J((-2, 0, -3)), **upper)


def mix(a, b, u):
    """A joint value u of the way from a to b."""
    return J(tuple(x + (y - x) * u for x, y in zip(a["r"], b["r"])), tuple(x + (y - x) * u for x, y in zip(a["p"], b["p"])))


def topple(t0, lean0, spin0=0.35, g=35.0, length=3.6, give=0.12):
    """A body on its knees tipping forward under gravity: a stick of `length` studs pivoting about its foot
    (theta'' = 3g/2L sin theta; g in studs/s², 35 being the real 9.8 m/s²), from `lean0` degrees with a nudge of
    `spin0` rad/s, until it lies at 88 degrees; there the chest bounces back by `give` of its speed and falls again.
    Returns ([(t, lean degrees)] at 30 a second, the moment it hits)."""
    k = 1.5 * g / length
    th, om, t, dt = math.radians(lean0), spin0, t0, 1 / 600
    flat = math.radians(88.0)
    out, hit, nxt = [(t0, lean0)], None, t0 + 1 / 30
    bounced = 0
    while bounced < 2:
        om += k * math.sin(th) * dt
        th += om * dt
        t += dt
        if th >= flat:
            th = flat
            if hit is None:
                hit = t
            om = -give * om if bounced == 0 else 0.0
            bounced += 1
        if t >= nxt:
            out.append((round(t, 4), math.degrees(th)))
            nxt += 1 / 30
    out.append((round(t + 1 / 30, 4), 88.0))
    return out, hit


# The victim -----------------------------------------------------------------------------------------------
# Facing the glass (+z); his left is +x, where the car comes from.

HANG_R = J((4, 0, 4), (0, 0.02, 0))
HANG_L = J((4, 0, -4), (0, 0.02, 0))
CLUTCH = reach(1, CHEST, direction=(-0.55, 0.15, -0.8))  # the right hand clawed into the chest
OVER_L = reach(-1, (0.1, 0.25, -0.85), direction=(0.6, 0.2, -0.75))  # the left hand over the right, both at the heart
PLEA_L = reach(-1, (-0.7, 0.6, -1.7), direction=(0.15, 0.1, -0.95))  # one weak reach towards the car
SIDE_R, SIDE_L = J((0, 0, 8)), J((0, 0, -10))  # lying: the arms straight along his sides (tilted either way, an end of the arm props him up)

v = Motion("IntroTokyo_victim", LENGTH, note="The Tokyo intro: the heart attack on the platform.")
# The car comes in from his left: his head follows it, slowly, as it brakes.
v.key(0.0, root=(0, 6, 0), neck=(-4, 46, 0), rShoulder=HANG_R, lShoulder=HANG_L)
v.key(2.4, "sine", root=(0, 4, 0), neck=(-4, 24, 0), rShoulder=HANG_R, lShoulder=HANG_L)
v.key(4.6, "out", root=(0, 0, 0), neck=(-6, 0, 0), rShoulder=HANG_R, lShoulder=HANG_L)
# The doors open on the man inside, writing: he looks up at him, and holds the look.
v.key(5.9, "sine", root=(1, 0, 0), neck=(4, -6, 0), rShoulder=HANG_R, lShoulder=HANG_L)
v.key(6.6, root=(1, 0, 0), neck=(5, -8, 4), rShoulder=HANG_R, lShoulder=HANG_L)  # a tilt: what is he writing?
v.key(7.9, "sine", root=(1, 0, 0), neck=(3, -8, 6), rShoulder=HANG_R, lShoulder=HANG_L)
# The jolt: one hard contraction where he stands (no thrashing): a catch of breath, then folded over with both
# hands at his heart, the shoulders up.
strike(v, JOLT, {"root": J((3, 0, 0)), "neck": J((6, 0, 0)), "rShoulder": J((14, 0, 6))},
       {"root": J((-24, 0, 2)), "neck": J((-20, 0, 0)), "rShoulder": CLUTCH, "lShoulder": OVER_L,
        "offset": (0.0, -0.18, 0.0)}, antic=0.12, travel=0.06, over=0.18, settle=0.3)
# Fighting for breath where he stands: gasps that pull him up and crumple him again, the weight rolling from one
# foot to the other (the feet stay put), the hand at his heart clawing tighter on each.
for k, t in enumerate((JOLT + 0.6, JOLT + 1.05, JOLT + 1.45)):
    side = 1 if k % 2 else -1
    v.key(t, "out", offset=(0.0, -0.08, 0.0), root=(-15, 2 * side, 3 * side), neck=(-6, -4 * side, 2 * side),
          rShoulder=CLUTCH, lShoulder=OVER_L)  # a gasp: up, the shoulders lifting
    v.key(t + 0.28, "in", offset=(0.0, -0.22, 0.0), root=(-27, -side, 4 * side), neck=(-24, 3 * side, 3 * side),
          rShoulder=J((CLUTCH["r"][0] + 6, CLUTCH["r"][1], CLUTCH["r"][2]), CLUTCH["p"]), lShoulder=OVER_L)
# The head comes up once, to the car; the left hand leaves the chest towards it, and gives up.
v.key(9.9, "sine", offset=(0.0, -0.16, 0.0), root=(-18, 0, 2), neck=(12, -6, 0), rShoulder=CLUTCH, lShoulder=OVER_L)
v.key(10.4, "sine", offset=(0.0, -0.16, 0.0), root=(-16, 0, 2), neck=(16, -6, 2), rShoulder=CLUTCH, lShoulder=PLEA_L)
# A knee gives a little, he catches it...
v.key(10.62, "in", offset=(0.0, -0.3, 0.0), root=(-18, 3, -6), neck=(8, -6, -2), rShoulder=CLUTCH,
      lShoulder=mix(PLEA_L, HANG_L, 0.4))
# ...then he goes, in one movement (the owner, 2026-10-28: "incline first, fall with the torso a bit, then bend the
# legs and fall"): the body tips forward over his feet, the head dropping, the weight going over the toes...
v.key(INCLINE, "sine", offset=(0.0, -0.2, 0.0), root=(-28, 0, 2), neck=(-20, -4, 2), rShoulder=CLUTCH,
      lShoulder=J((16, 0, -8)))
v.key(INCLINE + 0.35, "in", offset=(0.0, -0.14, 0.0), root=(-40, 0, 2), neck=(-28, 0, 2), rShoulder=CLUTCH,
      lShoulder=J((24, 0, -8)))
# ...the torso falls further and the legs give under it, swinging back as he drops (an R6 leg cannot bend at the
# knee: it swings back under the hip; every key rests on the floor, so he is never in the air)...
v.key(KNEES[0], "in", floor=True, root=(-46, 0, 2), neck=(-30, 0, 2), rShoulder=CLUTCH, lShoulder=J((32, 0, -8)),
      rHip=J((46, 0, 0)), lHip=J((46, 0, 0)))
v.key(KNEES[0] + 0.25, "in", floor=True, root=(-50, 0, 2), neck=(-28, 0, 2), rShoulder=CLUTCH,
      lShoulder=J((55, 0, -8)), rHip=J((8, 0, 2), (0, 0.06, 0.12)), lHip=J((8, 0, -2), (0, 0.06, 0.12)))
kneel(v, KNEES[1], "in", lean=-TIP_LEAN, head=-24, rShoulder=CLUTCH, lShoulder=J((90, 0, -8)))
# ...the knees hit and he keeps going, over onto his face under gravity, with the speed he came down with: the
# clutching arm slips out to his side as he goes (R6 lies flat only face down, and not on an arm); the other
# swings out ahead of him and slaps down on the floor; the head snaps at the hit.
REACH_L = J((180, 0, -8))  # lying: the arm out ahead along the floor, to the car (at 180 it lies flat; less and the hand props him up)
FALL_KEYS, HIT = topple(TIP, TIP_LEAN, spin0=1.6)
for t, lean in FALL_KEYS[1:]:
    u = min(1.0, (lean - TIP_LEAN) / (88.0 - TIP_LEAN))
    # (the arm has to lead the body down or the hand meets the floor first: at least 104 degrees out by 60, 143 by
    # 75, 176 when he is down)
    ahead = 176.0 * math.sqrt(max(0.0, (lean - 38.0) / 50.0))
    head = -24 + 36 * u if t < HIT else 18
    kneel(v, t, "linear", lean=-lean, head=head, rShoulder=mix(CLUTCH, SIDE_R, min(1.0, u * 1.8)),
          lShoulder=J((max(90.0, ahead), 0, -4 - 4 * min(1.0, ahead / 176.0))))
prone(v, HIT + 0.12, "in", head=26, rShoulder=SIDE_R, lShoulder=J((184, 0, -8)))  # the arm lands; the head whips up...
prone(v, HIT + 0.35, "sine", head=12, rShoulder=SIDE_R, lShoulder=REACH_L)  # ...and drops
# On the floor: hard breaths heaving his back; the fingers of the outstretched hand clawing at the floor towards
# the car, the head lifting to it; at the end the hand comes up off the floor, stretched at the closing doors.
LIFT_L = J((196, 0, -6))  # the hand up off the floor, stretched at the doors
breaths = [HIT + 0.9 + 0.55 * k for k in range(int((BLACK - HIT - 0.9) / 0.55) + 1)]
for k, t in enumerate(breaths):
    up = k % 2
    lift = min(1.0, max(0.0, (t - 19.4) / 1.4))
    left = mix(J((180 + 4 * up, 0, -8)), LIFT_L, lift)
    head = 14 + 26 * min(1.0, max(0.0, (t - (HIT + 1.5)) / 2.0)) + 10 * lift
    prone(v, min(t, LENGTH), "sine", lean=-90 + 1.5 * up, head=head + 3 * up, rShoulder=SIDE_R, lShoulder=left)
soft(v, head=3.0, arms=3.0, arm_damp=0.55)
v.plant(0.0, KNEES[0], stance=0.06)
alive(v, 0.6, seed=3, t1=JOLT - 0.3)
v.build()

# The writer -----------------------------------------------------------------------------------------------
# In the car, facing out at him, Death's Manual open in his left hand, low, the pages turned up to him; the pen
# in his right. Reading as the car pulls in; writing as the doors open; the last stroke, the pen lifted, the eyes
# coming up slowly to the man on the platform; watching him go down; the right hand folds the book shut.

MANUAL_SCALE = 0.6
MANUAL_W = 1.955 * MANUAL_SCALE  # its board's width: open, the board lies over on its +x side
TILT = 25.0  # the pages tilted up towards his face
UP = (0.0, math.cos(math.radians(TILT)), math.sin(math.radians(TILT)))  # the book's up (torso frame)
DEPTH = (0.0, -UP[2], UP[1])  # along the page, towards him
STAND_R = J((2, 0, 3))
HAND = (-0.15, -0.55, -1.45)  # (torso frame) the left fist under the open book, low in front of the middle of him
READ_L = reach(-1, HAND, direction=(0.3, -0.55, -0.75))
LOW_L = reach(-1, (-0.75, -0.95, -1.0), direction=(0.2, -0.8, -0.55))  # the shut book lowered to his side
BOOK_AT = (HAND[0] - MANUAL_W / 2, HAND[1] + 0.6 * UP[1], HAND[2] + 0.6 * UP[2])  # the spread centred over the fist


def on_page(x, d, above=0.5):
    """(torso frame) the right fist over the right-hand page at x (across) and d (down it), the pen's tip on it."""
    return (BOOK_AT[0] + MANUAL_W / 2 + x, BOOK_AT[1] + UP[1] * above + DEPTH[1] * d,
            BOOK_AT[2] + UP[2] * above + DEPTH[2] * d)


def pen_at(x, d, above=0.5):
    return reach(1, on_page(x, d, above), direction=(-0.35, -0.6, -0.7))


OVER_R = reach(1, on_page(MANUAL_W / 2, 0.0, 0.45), direction=(-0.6, -0.35, -0.7))  # the hand over the open board
SHUT_R = reach(1, (BOOK_AT[0] + 0.3, BOOK_AT[1] + 0.55, BOOK_AT[2] + 0.2), direction=(-0.8, -0.2, -0.6))  # pressing it
READING = dict(root=(-3, 0, 0), neck=(-30, 4, 0))
WRITING = dict(root=(-5, 0, 0), neck=(-34, 6, 0))

w = Motion("IntroTokyo_watcher", LENGTH, note="The Tokyo intro: the one in the car, writing in the Manual.")
w.key(0.0, rShoulder=STAND_R, lShoulder=READ_L, **READING)
w.key(WRITE[0] - 0.5, rShoulder=STAND_R, lShoulder=READ_L, **READING)
w.key(WRITE[0], "sine", rShoulder=pen_at(0.15, -0.35, 0.8), lShoulder=READ_L, **WRITING)  # the pen to the page
# A name, unhurried: short strokes along two lines...
strokes = [(0.12, -0.3), (0.3, -0.31), (0.46, -0.29), (0.62, -0.3), (0.14, -0.05), (0.32, -0.06), (0.5, -0.04)]
t = WRITE[0] + 0.35
for x, d in strokes:
    w.key(t, "sine", rShoulder=pen_at(x, d), lShoulder=READ_L, **WRITING)
    w.key(t + 0.14, "sine", rShoulder=pen_at(x + 0.08, d + 0.03, 0.56), lShoulder=READ_L, **WRITING)
    t += 0.3
# ...and the last: one long, deliberate stroke, then the pen lifted clean off the page.
w.key(WRITE[1] - 0.32, "sine", rShoulder=pen_at(0.12, 0.2), lShoulder=READ_L, **WRITING)
w.key(WRITE[1], "in", rShoulder=pen_at(0.78, 0.2), lShoulder=READ_L, **WRITING)
w.key(WRITE[1] + 0.12, "out", rShoulder=pen_at(0.8, 0.12, 1.05), lShoulder=READ_L, **WRITING)
# The eyes come up, slowly, to him.
w.key(WRITE[1] + 0.35, rShoulder=pen_at(0.8, 0.12, 1.05), lShoulder=READ_L, **WRITING)
w.key(WRITE[1] + 1.2, "sine", root=(-1, 0, 0), neck=(-14, -10, 0), rShoulder=pen_at(0.75, 0.1, 1.1), lShoulder=READ_L)
w.key(TIP - 0.3, root=(-2, 0, 0), neck=(-18, -10, 0), rShoulder=pen_at(0.75, 0.1, 1.1), lShoulder=READ_L)
w.key(HIT + 0.5, "sine", root=(-5, 0, 0), neck=(-34, -8, 0), rShoulder=pen_at(0.75, 0.1, 1.1), lShoulder=READ_L)
# The book shut: the right hand comes over the open board and folds it down onto the pages.
w.key(SHUT[0] - 0.55, root=(-5, 0, 0), neck=(-34, -8, 2), rShoulder=pen_at(0.75, 0.1, 1.1), lShoulder=READ_L)
w.key(SHUT[0], "sine", root=(-5, 0, 0), neck=(-34, -8, 4), rShoulder=OVER_R, lShoulder=READ_L)
w.key(SHUT[1], "sine", root=(-6, 0, 2), neck=(-36, -8, 12), rShoulder=SHUT_R, lShoulder=READ_L)  # shut; the head tilts
w.key(SHUT[1] + 0.4, "sine", root=(-6, 0, 2), neck=(-36, -8, 12), rShoulder=SHUT_R, lShoulder=READ_L)
# Then the head comes up from him, slowly, to look straight out (at us), the smile on.
w.key(SHUT[1] + 0.7, "sine", root=(-5, 0, 2), neck=(-35, -8, 12), rShoulder=STAND_R, lShoulder=LOW_L)
w.key(17.9, "sine", root=(-2, 0, 1), neck=(-8, -2, 8), rShoulder=STAND_R, lShoulder=LOW_L)
w.key(LENGTH, root=(-2, 0, 1), neck=(-7, -2, 8), rShoulder=STAND_R, lShoulder=LOW_L)
soft(w, head=2.4, arms=2.0)
w.plant(stance=0.06)
alive(w, 0.25, seed=5)
w.build()
MANUAL_GRIP = hold("Left Arm", {"lShoulder": READ_L}, BOOK_AT, (TILT, 0.0, 0.0))


# The others -----------------------------------------------------------------------------------------------
# Two on the car's long seat; on the platform people waiting where people wait, a pair talking, one walking through.

PHONE = J((96, 0, -16), (-0.1, 0.18, -0.25))
for k in range(2):
    m = Motion(f"IntroTokyo_seat{k}", LENGTH, note="The Tokyo intro: a passenger.")
    head = -36 if k == 0 else -22
    for t in (0.0, LENGTH):
        seated(m, t, seat=1.85, lean=-6, legs=84, neck=(head - (2 if t else 0), 0, 6 * (1 - 2 * k)),
               rShoulder=PHONE if k == 1 else J((30, 0, -6)), lShoulder=J((30, 0, 6)))
    alive(m, 0.4, seed=10 + k)
    m.build()

# (x, z, yaw, what they do)
WAITING = [
    (-107.0, -55.6, 180.0, "phone"),  # a few bays west, behind the strip
    (-99.0, -70.4, 60.0, "phone"),  # over by the far wall, turned half away
    (-68.6, -57.6, None, "talk"),  # a pair talking, east of him
    (-65.6, -58.4, None, "talk"),
    (-110.0, -66.8, 0.0, "watch"),  # waiting for the other track, checking the time
]
TALK = ((-68.6, -57.6), (-65.6, -58.4))


def waiting(k, kind):
    m = Motion(f"IntroTokyo_wait{k}", LENGTH, note="The Tokyo intro: someone on the platform.")
    if kind == "phone":
        poses = [(0.0, dict(neck=(-30, 0, 0), rShoulder=PHONE)), (LENGTH, dict(neck=(-30, 0, 0), rShoulder=PHONE))]
    elif kind == "watch":
        wrist = J((92, 0, 26), (0.12, 0.16, -0.22))
        poses = [(0.0, dict(neck=(-8, 0, 0), lShoulder=J((4, 0, -4)))), (6.0, dict(neck=(-8, 0, 0), lShoulder=J((4, 0, -4)))),
                 (6.6, dict(neck=(-26, 0, 0), lShoulder=wrist)), (8.4, dict(neck=(-26, 0, 0), lShoulder=wrist)),
                 (9.0, dict(neck=(-8, 0, 0), lShoulder=J((4, 0, -4)))), (LENGTH, dict(neck=(-6, 0, 0), lShoulder=J((4, 0, -4))))]
    else:  # talking: the head nodding, a hand coming up as they make a point, now and then a laugh
        poses = []
        for i in range(12):
            t = i * 2.0 + (0.6 if k % 2 else 0.0)
            gesture = (i + k) % 3 == 0
            poses.append((min(t, LENGTH), dict(neck=(-2 + (4 if i % 2 else 0), 0, 3 if i % 2 else -2),
                                              rShoulder=J((46, 0, -10), (-0.1, 0.1, -0.15)) if gesture else J((4, 0, 4)))))
    for t, pose in poses:
        base = dict(root=(0, 0, 0), rShoulder=J((4, 0, 4)), lShoulder=J((4, 0, -4)))
        base.update(pose)
        m.key(t, "sine", **base)
    soft(m, head=2.4, arms=2.6)
    m.plant(stance=0.06)
    alive(m, 0.7, seed=20 + k)
    return m


for k, (_, _, _, kind) in enumerate(WAITING):
    waiting(k, kind).build()

# Someone walking the length of the platform behind it all, from the stairs towards the east end.
WALK_FROM, WALK_TO, WALK_T = (-116.0, -63.2), (-62.0, -63.2), (2.0, 20.0)
walk_speed = (WALK_FROM[0] - WALK_TO[0]) * -1 / (WALK_T[1] - WALK_T[0])
walker = Motion("IntroTokyo_walker", LENGTH, note="The Tokyo intro: someone walking through.")
walker.key(0.0, root=(0, 0, 0), neck=(-6, 0, 0), rShoulder=J((4, 0, 4)), lShoulder=J((4, 0, -4)))
walker.key(LENGTH, root=(0, 0, 0), neck=(-6, 0, 0), rShoulder=J((4, 0, 4)), lShoulder=J((4, 0, -4)))
walking(walker, WALK_T[0], WALK_T[1], speed=walk_speed)
walker.plant(None, WALK_T[0], stance=0.06)
walker.plant(WALK_T[1], None, stance=0.06)
walker.build()

# Faceless commuters further off, for the station's depth (nobody's avatar).
EXTRAS = [(-126.0, -57.0, 200.0), (-122.5, -68.5, 10.0), (-58.0, -66.0, 330.0), (-52.0, -56.0, 160.0)]
for k in range(len(EXTRAS)):
    m = Motion(f"IntroTokyo_extra{k}", LENGTH, note="The Tokyo intro: a commuter far off.")
    for t in (0.0, LENGTH):
        m.key(t, root=(0, 0, 0), neck=(-20 if k % 2 else -6, 0, 0), rShoulder=PHONE if k % 2 else J((4, 0, 4)),
              lShoulder=J((4, 0, -4)))
    m.plant(stance=0.06)
    alive(m, 0.6, seed=40 + k)
    m.build()


# The shot -------------------------------------------------------------------------------------------------

shot = Shot(NAME, "Tokyo", LENGTH, note="The Tokyo intro: the platform.")
shot.own = True  # players in their own avatars (the owner, 2026-10-28)

victim = shot.actor("victim", v)
victim.mark(0.0, (VICTIM[0], FLOOR, VICTIM[1]), 180.0)
# (going over, the root moves forward with the fall so the legs stay where the knees were: nothing slides)
SLIDE = 0.0  # (from his lean the hips hardly move over the knees: nothing to make up)
for t, lean in FALL_KEYS:
    u = min(1.0, (lean - TIP_LEAN) / (88.0 - TIP_LEAN))
    victim.mark(t, (VICTIM[0], FLOOR, VICTIM[1] + SLIDE * u), 180.0, "linear")
watcher = shot.actor("watcher", w)
watcher.hold("Grimoire", "Left Arm", MANUAL_GRIP[0]["p"], MANUAL_GRIP[1]["r"], scale=MANUAL_SCALE,
             open=[(0.0, 1.0), (SHUT[0], 1.0), (SHUT[1], 0.0)])
watcher.hold("Pen", "Right Arm", (0, -1.0, -0.15), (60, 0, 0))
ride(watcher, CAR_DOOR + WATCHER[0] - DOOR_X, WATCHER[1], 0.0)
for k, dx in enumerate((-4.6, 4.6)):  # the long seat's two halves either side of the doorway, along the far wall
    p = shot.actor(f"everyone:{k + 1}", clip=f"IntroTokyo_seat{k}")
    ride(p, CAR_DOOR + dx, -43.6, 0.0)
for k, (x, z, yaw, kind) in enumerate(WAITING):
    p = shot.actor(f"everyone:{k + 3}", clip=f"IntroTokyo_wait{k}")
    if yaw is None:  # the pair face each other
        other = TALK[1] if (x, z) == TALK[0] else TALK[0]
        yaw = facing((x, z), other)
    p.mark(0.0, (x, FLOOR, z), yaw)
    if kind == "phone":
        p.hold("Smartphone", "Right Arm", (0.0, -1.05, -0.2), (-14, 0, 0))
pw = shot.actor(f"everyone:{len(WAITING) + 3}", clip="IntroTokyo_walker")
pw.mark(0.0, (WALK_FROM[0], FLOOR, WALK_FROM[1]), -90.0)
pw.mark(WALK_T[0], (WALK_FROM[0], FLOOR, WALK_FROM[1]), -90.0)
pw.mark(WALK_T[1], (WALK_TO[0], FLOOR, WALK_TO[1]), -90.0, "linear")
for k, (x, z, yaw) in enumerate(EXTRAS):
    e = shot.actor(f"extra:{k + 1}", clip=f"IntroTokyo_extra{k}", extra=True)
    e.mark(0.0, (x, FLOOR, z), yaw)
    if k % 2:
        e.hold("Smartphone", "Right Arm", (0.0, -1.05, -0.2), (-14, 0, 0))

# The car, turned to run along x with its doorway facing the platform, and its two door leaves. It stays.
car = shot.prop("TrainCarOpen")
for t, x, ease in ((ARRIVE[0], ARRIVE[1], "smooth"), (STOPPED[0], STOPPED[1], "out"), (LENGTH, STOPPED[1], "smooth")):
    car.at(t, (x, CAR_Y, TRACK_Z), (0, -90, 0), ease)
LEAF_Z = TRACK_Z - 4.1  # just inside the car's side
for side in (-1, 1):
    leaf = shot.prop("TrainDoorLeaf")
    closed, opened = side * 1.1, side * 3.3
    # (riding in with the car on the car's own keys, or they drift along its side as it brakes)
    keys = [(ARRIVE, closed, "smooth"), (STOPPED, closed, "out"), ((DOORS_OPEN[0], STOP), closed, "smooth"),
            ((DOORS_OPEN[1], STOP), opened, "out"),
            ((DOORS_SHUT[0], STOP), opened, "smooth"), ((DOORS_SHUT[1], STOP), closed, "in"), ((LENGTH, STOP), closed, "smooth")]
    for (t, x), dx, ease in keys:
        leaf.at(t, (x + CAR_DOOR + dx, FLOOR + 3.7, LEAF_Z), (0, -90, 0), ease)

# A: wide on the platform from the west: the people, the car braking in behind the glass, him waiting.
shot.subjects.append((0.0, 5.0, None, True))
shot.cam(0.0, (DOOR_X - 20.0, FLOOR + 7.6, -66.5), (DOOR_X + 1.0, FLOOR + 2.6, -54.0), fov=48)
shot.cam(5.0, (DOOR_X - 17.5, FLOOR + 6.8, -65.0), (DOOR_X + 0.5, FLOOR + 2.8, -54.4), fov=44, ease="linear")
# B: on the platform behind his shoulder, up into the open doors: the man there is writing.
shot.pan(5.0, 7.4, "watcher", (DOOR_X - 2.6, FLOOR + 4.6, -59.4), aim="Head", dy=-0.6, fov=38, cut=True,
         drift=(0.3, -0.1, 0.3), operator=True, seed=1)
# W: the insert, high from the doorway on his left (his writing arm on the far side), down onto the page: the pen
# finishes the name and lifts.
page = framing.part(shot, "watcher", WRITE[1] - 0.2, "lhand")
look_w = (float(page[0]) + 0.8, float(page[1]) + 0.45, float(page[2]) + 0.1)
shot.subjects.append((7.4, JOLT, None, True))
shot.cam(7.4, (look_w[0] - 0.85, look_w[1] + 2.5, look_w[2] - 1.3), look_w, fov=34, cut=True)
shot.cam(JOLT, (look_w[0] - 0.8, look_w[1] + 2.3, look_w[2] - 1.15), look_w, fov=32, ease="linear")
# C: hard cut on the jolt, three-quarter front from the east by the glass: frozen, the look up, the knees.
shot.pan(JOLT, INCLINE, "victim", (DOOR_X + 9.4, FLOOR + 4.0, -53.8), aim="Torso", dy=-0.4, fov=52, cut=True,
         drift=(0.3, 0.0, -0.3), operator=True, seed=2)
# D: low from the side: rocking on his knees, then over onto his face.
shot.pan(INCLINE, 14.6, "victim", (DOOR_X + 7.6, FLOOR + 2.6, -55.6), aim="Torso", dy=0.1, fov=54, cut=True,
         drift=(-0.3, -0.2, 0.0), operator=True, seed=3)
# E: low behind him on the platform, along his body to the writer looking down at him; tilted.
shot.pan(14.6, 16.0, "watcher", (DOOR_X + 1.8, FLOOR + 3.8, -60.6), aim="Head", dy=-1.4, fov=40, cut=True,
         drift=(-0.2, 0.1, 0.3), roll=-7.0)
# I: the insert, from the doorway down over the book in his hand: the other hand comes over and shuts it.
book = framing.part(shot, "watcher", SHUT[0] + 0.3, "lhand")
look = (float(book[0]) - 0.2, float(book[1]) + 0.45, float(book[2]) + 0.1)
shot.subjects.append((16.0, 17.2, None, True))
shot.cam(16.0, (look[0] + 0.3, look[1] + 2.6, look[2] - 1.35), look, fov=36, roll=4.0, cut=True)
shot.cam(17.2, (look[0] + 0.25, look[1] + 2.35, look[2] - 1.2), look, fov=36, roll=4.0, ease="linear")
# F: close on the writer through the doorway, tilted the other way: his head comes up from the body to us, smiling.
shot.pan(17.2, 18.6, "watcher", (DOOR_X - 0.3, FLOOR + 4.3, -54.2), aim="Head", dy=-0.3, fov=36, cut=True,
         drift=(-0.1, 0.0, 0.35), roll=5.0)
# H: low on the car's floor, out through the doorway at him lying there reaching; the doors close; black.
shot.pan(18.6, BLACK, "victim", (DOOR_X + 1.3, FLOOR + 0.6, -47.8), aim="Head", dy=0.5, fov=46, cut=True,
         drift=(0.0, -0.05, -0.6), back=True)
shot.subjects.append((BLACK, LENGTH, None, True))
shot.cam(BLACK, (DOOR_X + 1.3, FLOOR + 0.55, -48.4), (DOOR_X, FLOOR + 1.6, -53.4), fov=46, cut=True)
shot.cam(LENGTH, (DOOR_X + 1.3, FLOOR + 0.55, -48.4), (DOOR_X, FLOOR + 1.6, -53.4), fov=46, ease="linear")

# The lens: sharp on whoever the cut is about, the rest soft; low along the body it racks from him to the writer.
for t, slot, part, radius, far, near in (
        (0.0, "victim", "Head", 12.0, 0.1, 0.0),  # A: the platform, the far end barely soft
        (5.0, "watcher", "Head", 4.0, 0.15, 0.18),  # B: the writer sharp, the victim's shoulder a little soft
        (7.4, "watcher", "Left Arm", 2.5, 0.2, 0.1),  # W: the page
        (JOLT, "victim", "Head", 5.0, 0.15, 0.05),  # C: him; the walker and the platform a little soft
        (10.9, "victim", "Head", 5.0, 0.15, 0.05),  # D
        (14.6, "victim", "Head", 3.0, 0.2, 0.05),  # E: on him lying there...
        (16.0, "watcher", "Left Arm", 2.5, 0.2, 0.1),  # I: the book
        (17.2, "watcher", "Head", 3.5, 0.2, 0.05),  # F: the smile
        (18.6, "victim", "Head", 3.5, 0.15, 0.2)):  # H: him, the closing doors a little soft in front
    shot.event(t, "fx", name="focus", slot=slot, part=part, radius=radius, far=far, near=near)
shot.event(15.15, "fx", name="focus", slot="watcher", part="Head", radius=3.5, far=0.15, near=0.2, rack=0.6)  # ...to him

# Faces
shot.face(0.0, "victim", "Stern")
shot.face(JOLT, "victim", "Shock")
shot.face(JOLT + 0.9, "victim", "Fear")
shot.face(0.0, "watcher", "Stern")
shot.face(SHUT[1], "watcher", "Grin")
for k in range(len(WAITING) + 3):
    shot.face(0.0, f"everyone:{k + 1}", "Stern")

# Sound: the station under it all; the pen; the heart, slowing; the drone from the jolt; the riser to the doors.
shot.event(0.0, "sfx", slot="tokyoStationBed", loop=True)
shot.event(0.0, "sfx", slot="mapTrainArrive")
shot.event(DOORS_OPEN[0], "sfx", slot="trainDoors")
shot.event(DOORS_OPEN[0] + 0.4, "sfx", slot="mapStationChime")
shot.event(WRITE[0] + 0.3, "sfx", slot="penScratch")
shot.event(WRITE[1] - 0.32, "sfx", slot="penScratch")
shot.event(WRITE[1] + 0.1, "sfx", slot="penStop")
shot.event(JOLT, "sfx", slot="introTokyoDrone")
# The anime's beat when the heart stops (the owner, 2026-10-28): on the cut to him, a breath into the jolt, the frame
# freezes black and white, he blinks red once, and his heart beats once, loud; then the colour comes back and the
# scene plays on (the freeze holds the shot 1.3 s longer: RoundService.introLength counts it).
FREEZE = JOLT + 0.24
shot.event(FREEZE, "fx", name="freeze", dur=1.3, blink="victim")
shot.event(FREEZE, "sfx", slot="heartbeat")
shot.event(FREEZE, "fx", name="pulse", punch=0.06, dur=0.8)
shot.event(HIT, "sfx", slot="bodyFall")
shot.event(HIT, "fx", name="shake", strength=0.22, dur=0.25)
shot.event(SHUT[1], "sfx", slot="bookShut")
shot.event(18.8, "sfx", slot="doorRiser")
shot.event(DOORS_SHUT[0], "sfx", slot="trainDoors")
# the doors meet: black, and silence; then the case's card
shot.event(BLACK, "fx", name="black", hush=True)
shot.event(BLACK + 0.5, "card", key="case", dur=LENGTH - BLACK - 0.5)
