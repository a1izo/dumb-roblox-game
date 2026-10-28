"""The Agency intro (everyone, 22.6 s; the intro phase follows it): the Bureau's operations deck at midnight. Rebuilt
from scratch (2026-10-28) after the task force's first night with L in Death Note (art/refs/cinema/IntroAgency.toml):
a dark room, the case's evidence spread out, the investigators gathered round, and one strange figure crouched on a
chair, thumb at his lip, staring at it. Ours: the match's players (twelve at most) round the map table in a pool of
light, the recovered Manual in the middle; one crouched on a chair at its end; another lifts the cover... and the
deck's lights stutter and the wall of the dead across the atrium flares, every head snapping up to it; the crouched
one rises; the camera comes down into the open page. Both named parts are random players, never by role.

A  0.0-3.6   High over the desks, craning down and in: the group round the table under its one light, rain on the
             glass behind them.
B  3.6-6.2   At eye height round the table, tracking: faces lit from the papers; arms folded, hands flat on the
             table, a hand at a chin, a whisper.
C  6.2-8.2   Over the table: the evidence (reports, photographs) and at its end the black book.
D  8.2-10.2  The one crouched on a chair at the far end, close, pushing in: thumb at the lip, eyes down the table
             on the book.
E  10.2-11.6 Low across the table at the book: a hand lifts its cover.
F  11.6-13.0 Behind the group, wide: the lights stutter, and every head snaps up to the wall across the atrium.
G  13.0-15.2 Low at the deck's rail, looking up across the atrium: the wall of the dead, pushing in.
H  15.2-17.4 Low on the crouched one as he unfolds off the chair and stands, his eyes going back to the book.
I  17.4-19.6 Straight down on the table, everyone round it, the camera coming down into the open page.
   19.6-22.6 Black, then the case's card.

The operations deck (maps/venues/agency/upper.py, Agency scene space): 39F's floor at y 14; the map table's middle at
(17, 62), x 12..22, z 59..65, its top at y 16.8; the deck's own chairs at x 14.5 / 19.5 on both long sides
(z 57.8, 66.2); the video wall on the core's south face (z -5.5), x -6..40, screens y 22..32, across the atrium
(x -4..38, z 4..34)."""

import math
import random

import posekit
from animlib import J
from cinema import framing
from cinema.acting import alive, body_reach, facing, soft
from cinema.shot import Shot
from emotes.kit import CHIN, reach
from motion import Motion

NAME = "IntroAgency"
BLACK = 19.6
LENGTH = BLACK + 3.0
Y = 14.0
TABLE = (17.0, 62.0)
TOP = 2.8  # the table top over the deck's floor
WALL = (17.0, -5.5)
BOOK = (20.6, 62.0)  # the Manual, at the reader's end of the table
OPEN = (10.7, 11.25)  # the cover lifted .. lying open
LOOK_UP = 11.7  # the lights stutter; the heads snap up to the wall
BACK_DOWN = 15.0  # ..and come back down to the book
RISE = (15.4, 16.6)  # the crouched one unfolds off the chair and stands

READER = (23.2, 62.0)  # the table's east end, facing down it (-x)
CHAIR = (9.6, 62.0)  # the crouched one's chair at the west end, facing down it (+x): the length of the table between them
# (x, z, how they stand): the others at the corners, and behind the deck's own chairs (the table is solid to the
# floor and its chairs leave no room along its long sides; a body with its arms is 4 studs across)
OTHERS = [(10.6, 57.6, "chin"), (23.3, 57.3, "fold"), (10.6, 66.4, "pockets"), (23.3, 66.7, "fold"),
          (14.5, 54.9, "back"), (19.5, 54.9, "pockets"), (14.5, 69.1, "lean_one"), (19.5, 69.1, "chin")]


def turn_to(yaw, frm, to):
    return max(-80.0, min(80.0, (facing(frm, to) - yaw + 180) % 360 - 180))


# Standing at the table ---------------------------------------------------------------------------------

POCKET_R, POCKET_L = J((10, 0, -4), (-0.08, 0.12, -0.02)), J((10, 0, 4), (0.08, 0.12, -0.02))
FOLDED = dict(rShoulder=J((40, 0, -38), (-0.3, 0.1, -0.22)), lShoulder=J((38, 0, 36), (0.3, 0.1, -0.22)))
BEHIND = dict(rShoulder=J((-18, 0, 10), (0.0, 0.05, 0.12)), lShoulder=J((-18, 0, -10), (0.0, 0.05, 0.12)))


def flat(side, lean, gap, x=0.9):
    """A hand flat on the table, `gap` studs in front of the feet's line."""
    return body_reach(side, dict(root=(lean, 0, 0)), (0, 0, 0), (side * x, TOP + 0.35, -gap - 0.6),
                      direction=(-side * 0.1, -0.6, -0.8))


def arms_for(style, lean, gap):
    if style == "lean":
        return dict(rShoulder=flat(1, lean, gap), lShoulder=flat(-1, lean, gap))
    if style == "lean_one":
        return dict(rShoulder=flat(1, lean, gap, 0.6), lShoulder=POCKET_L)
    if style == "fold":
        return dict(FOLDED)
    if style == "chin":
        return dict(rShoulder=reach(1, (0.2, CHIN[1] - 0.05, CHIN[2] - 0.05), direction=(-0.3, 0.7, -0.6)),
                    lShoulder=J((38, 0, 36), (0.3, 0.1, -0.22)))
    if style == "back":
        return dict(BEHIND)
    return dict(rShoulder=POCKET_R, lShoulder=POCKET_L)


def member(k, x, z, style):
    """Someone round the table: their own stance and rhythm (a glance at a neighbour, a shift of weight, a nod),
    then the heads snap up to the wall at a slightly different moment each, and come back down to the book."""
    rng = random.Random(500 + k * 13)
    yaw = facing((x, z), TABLE)
    gap = max(0.4, min(1.4, math.hypot(max(12.0 - x, 0.0, x - 22.0), max(59.0 - z, 0.0, z - 65.0))))  # (to the table's edge)
    lean = {"lean": -20, "lean_one": -14}.get(style, rng.uniform(-6, -2))
    arms = arms_for(style, lean, gap)
    m = Motion(f"IntroAgency_member{k}", LENGTH, note="The Agency intro: someone round the map table.")
    down = -24 - 6 * (lean < -10)
    look = rng.uniform(-10, 10)
    m.key(0.0, root=(lean, 0, 0), neck=(down, look, 0), **arms)
    t = rng.uniform(1.2, 2.4)
    while t < LOOK_UP - 1.2:  # small life: a glance to a neighbour, a nod, the weight shifting
        what = rng.choice(("glance", "nod", "shift"))
        if what == "glance":
            side = rng.choice((-1, 1))
            m.key(t, "sine", root=(lean, 4 * side, 0), neck=(down + 14, 34 * side, 0), **arms)
            m.key(t + rng.uniform(0.7, 1.2), "sine", root=(lean, 0, 0), neck=(down, look, 0), **arms)
        elif what == "nod":
            m.key(t, "sine", root=(lean, 0, 0), neck=(down - 8, look, 0), **arms)
            m.key(t + 0.35, "sine", root=(lean, 0, 0), neck=(down + 2, look, 0), **arms)
            m.key(t + 0.7, "sine", root=(lean, 0, 0), neck=(down, look, 0), **arms)
        else:
            m.key(t, "sine", root=(lean + 2, 0, 3 * rng.choice((-1, 1))), neck=(down, -look, 0), **arms)
        t += rng.uniform(1.8, 3.0)
    m.key(LOOK_UP + 0.05, root=(lean, 0, 0), neck=(down, look, 0), **arms)
    # the snap up to the wall, the body half turning after the head
    turn = turn_to(yaw, (x, z), WALL)
    up = LOOK_UP + 0.12 + rng.uniform(0.0, 0.3)
    m.key(up, "out", root=(lean * 0.4, turn * 0.15, 0), neck=(18, turn * 0.7, 0), **arms)
    m.key(up + 0.6, "sine", root=(min(0, lean * 0.3), turn * 0.35, 0), neck=(14, turn * 0.6, 0), **arms)
    m.key(BACK_DOWN + rng.uniform(0.0, 0.5), "sine", root=(min(0, lean * 0.3), turn * 0.35, 0), neck=(12, turn * 0.6, 2), **arms)
    m.key(BACK_DOWN + 1.2 + rng.uniform(0.0, 0.4), "sine", root=(lean, 0, 0), neck=(down - 4, 0, 0), **arms)
    m.key(LENGTH, root=(lean, 0, 0), neck=(down - 5, 0, 0), **arms)
    soft(m, head=2.8, arms=2.6)
    m.plant(stance=0.06)
    alive(m, 0.5, seed=60 + k)
    m.build()
    return yaw


YAWS = [member(k, x, z, style) for k, (x, z, style) in enumerate(OTHERS)]

# The reader: leaning over the table, a hand by the book; reaches for its cover, lifts it, lays it open; looks up to
# the wall with the others; back down to the open page.


def char(x, y, z):
    """The set's space as the reader's own frame (he faces -x, his right to -z)."""
    return (-(z - READER[1]), y - Y, x - READER[0])


r = Motion("IntroAgency_reader", LENGTH, note="The Agency intro: the one who opens the Manual.")
LEAN_R = -24
JR = dict(root=(LEAN_R, 0, 0))
REST_R = body_reach(1, JR, (0, 0, 0), char(21.9, 17.25, 60.4), direction=(0.1, -0.6, -0.8))
FLAT_L = body_reach(-1, JR, (0, 0, 0), char(21.8, 17.35, 63.7), direction=(-0.1, -0.6, -0.8))
EDGE = body_reach(1, JR, (0, 0, 0), char(21.55, 17.45, 61.6), direction=(0.0, -0.7, -0.7))  # (the cover's near edge)
UP = body_reach(1, JR, (0, 0, 0), char(20.8, 18.3, 61.7), direction=(0.0, 0.2, -1.0))
OVER = body_reach(1, JR, (0, 0, 0), char(19.9, 17.6, 61.8), direction=(0.0, -0.3, -0.95))
r.key(0.0, root=(LEAN_R, 0, 0), neck=(-30, 0, 0), rShoulder=REST_R, lShoulder=FLAT_L)
r.key(3.4, "sine", root=(LEAN_R + 2, -3, 0), neck=(-26, -18, 0), rShoulder=REST_R, lShoulder=FLAT_L)  # (to a neighbour)
r.key(4.4, "sine", root=(LEAN_R, 0, 0), neck=(-32, 0, 0), rShoulder=REST_R, lShoulder=FLAT_L)
r.key(OPEN[0] - 0.45, "sine", root=(LEAN_R, 0, 0), neck=(-34, 0, 0), rShoulder=REST_R, lShoulder=FLAT_L)
r.key(OPEN[0], "sine", root=(LEAN_R - 2, 0, 0), neck=(-36, 0, 0), rShoulder=EDGE, lShoulder=FLAT_L)
r.key((OPEN[0] + OPEN[1]) / 2, "sine", root=(LEAN_R - 2, 0, 0), neck=(-34, 0, 0), rShoulder=UP, lShoulder=FLAT_L)
r.key(OPEN[1], "in", root=(LEAN_R - 2, 0, 0), neck=(-38, 0, 0), rShoulder=OVER, lShoulder=FLAT_L)
r.key(LOOK_UP + 0.1, root=(LEAN_R - 2, 0, 0), neck=(-38, 0, 0), rShoulder=OVER, lShoulder=FLAT_L)
rturn = turn_to(90.0, READER, WALL)
r.key(LOOK_UP + 0.3, "out", root=(LEAN_R * 0.4, rturn * 0.2, 0), neck=(16, rturn * 0.6, 0), rShoulder=J((20, 0, 4)),
      lShoulder=FLAT_L)
r.key(BACK_DOWN + 0.2, "sine", root=(LEAN_R * 0.4, rturn * 0.25, 0), neck=(12, rturn * 0.6, 0), rShoulder=J((16, 0, 4)),
      lShoulder=FLAT_L)
r.key(BACK_DOWN + 1.1, "sine", root=(LEAN_R, 0, 0), neck=(-36, 0, 0), rShoulder=REST_R, lShoulder=FLAT_L)
r.key(LENGTH, root=(LEAN_R, 0, 0), neck=(-38, 0, 0), rShoulder=REST_R, lShoulder=FLAT_L)
soft(r, head=2.8, arms=2.6)
r.plant(stance=0.05)
alive(r, 0.4, seed=71)
r.build()

# The crouched one: the R6 crouch on a chair (the legs out in front along the seat, the torso upright on their back
# ends), the thumb at the lip, the other arm over the knees, rocking a little; eyes on the book; up to the wall with
# the others; then he unfolds off the chair and stands, the eyes going back to the book.

SEAT = 2.07  # an OfficeChair's seat at full size
CROUCH_R, CROUCH_L = J((80, 0, 5)), J((80, 0, -5))
THUMB_LIP = reach(1, (0.12, 0.85, -0.85), direction=(-0.45, 0.75, -0.5))
OVER_KNEES = reach(-1, (-0.35, -0.55, -1.5), direction=(0.3, -0.35, -0.9))
c = Motion("IntroAgency_thinker", LENGTH, note="The Agency intro: the one crouched on a chair, staring at the Manual.")


def crouch(t, ease="sine", lean=2.0, neck=(-22, 0, 0), right=THUMB_LIP, left=OVER_KNEES):
    pose = {"root": J((lean, 0, 0)), "rHip": CROUCH_R, "lHip": CROUCH_L}
    off = posekit.on_seat(pose, (0.0, 0.0, 0.25), seat=SEAT)
    c.key(round(t, 4), ease, offset=off, root=(lean, 0, 0), neck=neck, rShoulder=right, lShoulder=left, rHip=CROUCH_R,
          lHip=CROUCH_L)


for k, t in enumerate((0.0, 1.6, 3.2, 4.8, 6.4, 8.0, 9.6, 11.2)):  # rocking a little, the thumb at the lip
    crouch(t, lean=2 + (2 if k % 2 else 0), neck=(-22 + (2 if k % 2 else 0), 2 * math.sin(k), 4 + (3 if k % 3 == 0 else 0)))
cturn = turn_to(-90.0, CHAIR, WALL)
crouch(LOOK_UP + 0.2, "out", lean=4, neck=(14, cturn * 0.6, 4))  # (up to the wall)
crouch(BACK_DOWN - 0.2, lean=4, neck=(12, cturn * 0.6, 6))
crouch(RISE[0], lean=2, neck=(-14, 0, 6))
# unfolding: the feet down off the seat's front, the weight forward... and up, standing in front of the chair
mid = {"root": J((-24, 0, 0)), "rHip": J((52, 0, 3)), "lHip": J((52, 0, -3))}
off = posekit.on_seat(mid, (0.0, 0.0, -0.3), seat=SEAT - 0.2)
c.key(RISE[0] + 0.5, "sine", offset=off, root=(-24, 0, 0), neck=(-6, 0, 0), rShoulder=J((20, 0, 8)), lShoulder=J((20, 0, -8)),
      rHip=J((52, 0, 3)), lHip=J((52, 0, -3)))
stand = {"root": J((-6, 0, 0)), "rHip": J((0, 0, 2)), "lHip": J((0, 0, -2))}
off = posekit.on_floor(stand, (0.0, 0.0, -1.1), floor=0.0)
c.key(RISE[1], "out", offset=off, root=(-6, 0, 0), neck=(-24, 0, 4), rShoulder=J((6, 0, 6)), lShoulder=J((6, 0, -6)),
      rHip=J((0, 0, 2)), lHip=J((0, 0, -2)))
c.key(LENGTH, "sine", offset=off, root=(-8, 0, 0), neck=(-30, 0, 6), rShoulder=J((6, 0, 6)), lShoulder=J((6, 0, -6)),
      rHip=J((0, 0, 2)), lHip=J((0, 0, -2)))
soft(c, head=2.6, arms=2.4)
alive(c, 0.35, seed=73, t1=RISE[0])
c.build()

# The shot -------------------------------------------------------------------------------------------------

shot = Shot(NAME, "Agency", LENGTH, note="Agency intro: the Bureau round the Manual on the operations deck.",
            skippable=True, mood="TaskForceHQ")
shot.own = True  # players in their own avatars (the owner, 2026-10-28)

ra = shot.actor("reader", r)
ra.mark(0.0, (READER[0], Y, READER[1]), 90.0)
th = shot.actor("thinker", c)
th.mark(0.0, (CHAIR[0], Y, CHAIR[1]), -90.0)
shot.allow = {"thinker": ["OfficeChair"]}
for k, ((x, z, _), yaw) in enumerate(zip(OTHERS, YAWS)):
    a = shot.actor(f"everyone:{k + 1}", clip=f"IntroAgency_member{k}")
    a.mark(0.0, (x, Y, z), yaw)

chair = shot.prop("OfficeChair")
chair.at(0.0, (CHAIR[0], Y, CHAIR[1]), (0, -90, 0))
chair.at(LENGTH, (CHAIR[0], Y, CHAIR[1]), (0, -90, 0))
book = shot.prop("Grimoire", open=[(0.0, 0.0), (OPEN[0], 0.0), (OPEN[1], 1.0)])
book.at(0.0, (BOOK[0], Y + TOP + 0.22, BOOK[1]), (0, 180, 0))  # (its cover's free edge towards the reader)
book.at(LENGTH, (BOOK[0], Y + TOP + 0.22, BOOK[1]), (0, 180, 0))
PAGE = (BOOK[0], Y + TOP + 0.3, BOOK[1])
for k, (dx, dz, rot) in enumerate(((-3.4, -1.6, 20), (-0.6, 1.6, -30), (-2.4, 1.8, 70), (0.8, -1.8, 5), (-4.2, 0.6, -12))):
    sheet = shot.prop("PaperSheet")
    sheet.at(0.0, (TABLE[0] + dx, Y + TOP + 0.02, TABLE[1] + dz), (0, rot, 0))
    sheet.at(LENGTH, (TABLE[0] + dx, Y + TOP + 0.02, TABLE[1] + dz), (0, rot, 0))

# The cameras, every one moving and held by hand.
# A: high over the desks, craning down and in on the group under the table's light.
framing.dolly(shot, 0.0, 3.6, (17.0, 26.0, 38.0), (17.0, 21.8, 45.5), (17.0, 16.0, 62.0), (17.0, 16.6, 62.0), fov0=52,
              fov1=46, shake=0.4, seed=1, cut=False)
# B: just over their heads from the north side, between the two behind the chairs, tracking along the table: the
# crouched one at one end, the reader and the book at the other.
framing.dolly(shot, 3.6, 6.2, (15.4, 22.6, 50.6), (18.8, 22.3, 50.9), (16.0, 17.4, 62.0), (18.0, 17.4, 62.0), fov0=50,
              fov1=46, shake=0.5, seed=2)
# C: over the table: the evidence, and the black book at its end.
framing.dolly(shot, 6.2, 8.2, (17.8, 20.2, 64.8), (18.8, 19.3, 63.8), (20.4, Y + TOP, 62.2), (20.6, Y + TOP, 62.0), fov0=50,
              fov1=44, roll0=-4.0, roll1=-6.0, shake=0.5, seed=3)
# D: the crouched one, close, from over the table, pushing in.
shot.pan(8.2, 10.2, "thinker", (14.2, 19.8, 60.0), aim="Head", dy=-0.2, fov=48, cut=True, drift=(-0.3, -0.2, 0.4),
         roll=-6.0, operator=True, seed=4, shake=0.4, fov_to=40, ease_move=True)
# E: low along the table at the book: the reader's hand lifts its cover, his face beyond.
framing.dolly(shot, 10.2, 11.6, (18.0, 19.0, 63.6), (18.6, 18.8, 63.2), (20.9, 17.1, 62.0), fov0=46, fov1=40, shake=0.5,
              seed=5)
# F: behind the group, wide: the lights stutter and every head snaps up to the wall across the atrium.
shot.subjects.append((11.6, 13.0, None, True))
framing.dolly(shot, 11.6, 13.0, (18.0, 20.6, 70.6), (18.0, 20.4, 69.6), (17.0, 21.0, 30.0), (17.0, 22.5, 20.0), fov0=50,
              fov1=46, shake=0.9, seed=6)
# G: low at the deck's rail, looking up across the atrium at the wall of the dead, pushing in.
framing.dolly(shot, 13.0, 15.2, (17.0, 18.2, 37.5), (17.0, 18.8, 33.5), (17.0, 27.0, -5.5), fov0=56, fov1=44, shake=0.5,
              seed=7)
# H: low on the crouched one as he unfolds off the chair and stands.
shot.pan(15.2, 17.4, "thinker", (15.0, 17.6, 64.0), aim="Head", dy=-0.2, fov=50, cut=True, drift=(-0.3, 0.6, 0.2),
         roll=5.0, operator=True, seed=8, shake=0.5, fov_to=40, ease_move=True)
# I: straight down on the table, everyone round it, coming down into the open page.
framing.dolly(shot, 17.4, BLACK, (17.0, 33.0, 62.1), (BOOK[0] - 0.3, Y + TOP + 2.6, BOOK[1] + 0.06), PAGE, fov0=56,
              fov1=40, roll0=0.0, roll1=12.0, shake=0.3, seed=9)
shot.subjects.append((BLACK, LENGTH, None, True))
shot.cam(BLACK, (17.0, 30.0, 62.1), PAGE, fov=50, cut=True)
shot.cam(LENGTH, (17.0, 30.0, 62.1), PAGE, fov=50, ease="linear")

# The lens: barely soft.
for t, slot, part, radius in ((3.6, "reader", "Head", 5.0), (8.2, "thinker", "Head", 2.5), (10.2, "reader", "Right Arm", 2.5),
                              (15.2, "thinker", "Head", 3.0)):
    shot.event(t, "fx", name="focus", slot=slot, part=part, radius=radius, far=0.12, near=0.06)
for t in (0.0, 6.2, 11.6, 17.4):
    shot.event(t, "fx", name="focus")

# The light: the deck dark and red; one cold light hung over the table (the evidence lit, the faces lit from below by
# the papers); the crouched one lit from the table, from below; when the cover lifts, the lights stutter and the
# wall's cold glow washes over the faces turned to it. The grade: dark, cold, the reds held.
OVER_T = (TABLE[0], Y + 10.0, TABLE[1])
shot.grade = (0.22, -0.08, -0.04, (226, 234, 255))
shot.light("spot", OVER_T, (TABLE[0], Y + TOP, TABLE[1]), color=(215, 228, 255), brightness=2.4, range=16, angle=55)
shot.light("spot", (TABLE[0], Y + TOP + 0.4, TABLE[1]), (TABLE[0], Y + 6.0, TABLE[1]), color=(240, 236, 220),
           brightness=0.7, range=7, angle=100, shadows=False)  # (the papers' bounce up into the faces)
shot.light("spot", (11.8, Y + TOP + 0.3, 62.0), (CHAIR[0], Y + 5.2, CHAIR[1]), color=(220, 230, 255), brightness=1.4,
           range=6, angle=60, show=(8.2, BLACK))
shot.light("spot", (17.0, Y + 10.0, 48.0), (17.0, Y + 4.0, 62.0), color=(160, 195, 255), brightness=2.0, range=24, angle=50,
           flicker=0.6, show=(LOOK_UP, BACK_DOWN + 1.0))  # (the wall's glow on the faces)
shot.light("spot", (17.0, 19.0, 30.0), (17.0, 27.0, -5.5), color=(200, 220, 255), brightness=2.6, range=50, angle=40,
           flicker=0.5, show=(LOOK_UP, 15.2))  # (the wall flaring)

# Sound and effects: the rain; the cover; the stutter; the heartbeat as he stands.
shot.event(0.0, "sfx", slot="mapRainGlass")
shot.event(0.0, "sfx", slot="mapOfficeHum")
shot.event(0.4, "title", lines=["BUREAU HEADQUARTERS, 39F", "Operations, 00:04"], dur=3.0)
shot.event(OPEN[0], "sfx", slot="pageTurn")
for k, t in enumerate((LOOK_UP, LOOK_UP + 0.18, LOOK_UP + 0.34)):  # (the lights stutter: dark, back, dark, back)
    shot.event(t, "fx", name="flash", r=0, g=0, b=0, strength=0.8 - 0.15 * k, dur=0.12)
shot.event(LOOK_UP, "sfx", slot="hauntFlicker")
shot.event(LOOK_UP + 0.1, "sfx", slot="screenStatic")
shot.event(13.0, "fx", name="pulse", punch=0.05, dur=1.0)
shot.event(RISE[0], "sfx", slot="heartbeat")
shot.event(BLACK, "fx", name="black", hush=True)
shot.event(BLACK + 0.5, "card", key="case", dur=LENGTH - BLACK - 0.5)
