"""The Death's Gambit opener (everyone, ~4 s, before the writing): the bell, the lamp, and a close look at a
suit-sleeved hand writing a name in Death's Manual, open on a desk (never anyone's cosmetic, never anyone in
particular: a faceless figure at the study's desk, seen only from the sleeve down).

The study (maps/venues/sets/study.py, Sets scene space): the desk at (0, -5.4) (x -3.3..3.3, z -7.0..-3.8,
top 2.7), its lamp at the west end; the chair behind it at (0, -8.0). The writer faces south (+z)."""

from animlib import J
from cinema.acting import perched, soft, strike
from cinema.shot import Shot
from motion import Motion

NAME = "GambitOpener"
LENGTH = 4.0
TOP = 2.7
HIP = 2.15
WRITER = (0.0, -7.8)
MANUAL = 0.55
BOOK = (-0.85, -6.3)  # its open page, under the right hand; the board lies over to the writer's left
BOOK_Y = TOP + 0.215 * MANUAL

WRITE_R = J((86, -14, -20), (-0.14, 0.04, -0.3))
REST_L = J((88, 8, 16), (0.1, 0.04, -0.3))

w = Motion("GambitOpener_writer", LENGTH, note="The Death's Gambit opener: a hand writing a name.")
perched(w, 0.0, hip=HIP, lean=-9, neck=(-14, 0, 0), rShoulder=WRITE_R, lShoulder=REST_L)
for k, t in enumerate((0.9, 1.25, 1.6, 2.05, 2.4, 2.75, 3.2, 3.55)):  # the name, in hard quick strokes
    up = J((96, -14 + 4 * (k % 3), -20), (-0.14, 0.12, -0.3))
    strike(w, t, {"rShoulder": up}, {"rShoulder": WRITE_R}, antic=0.08, travel=0.05, over=0.15, settle=0.12)
perched(w, LENGTH, hip=HIP, lean=-9, neck=(-14, 0, 0), rShoulder=WRITE_R, lShoulder=REST_L)
soft(w, arms=3.0, arm_damp=0.6)
w.build()

shot = Shot(NAME, "Sets", LENGTH, note="The Death's Gambit opener: the bell, a hand writing in Death's Manual.")
shot.room = (-12.0, -10.0, 12.0, 10.0, 14.0)
shot.allow = {"writer": ["OfficeChair"]}

# A: the dark desk under the one lamp, the Manual open on it: a slow push in.
shot.subjects.append((0.0, 1.6, None, True))
shot.cam(0.0, (2.6, 5.8, -0.8), (BOOK[0], BOOK_Y, BOOK[1]), fov=42)
shot.cam(1.6, (1.9, 5.3, -2.4), (BOOK[0], BOOK_Y, BOOK[1]), fov=38, ease="linear")
# B: the pen on the page, very close, pushing in.
shot.subjects.append((1.6, LENGTH, None, True))
shot.cam(1.6, (-1.6, 6.3, -4.5), (BOOK[0] - 0.1, BOOK_Y, BOOK[1]), fov=32, cut=True)
shot.cam(LENGTH, (-1.4, 5.6, -5.0), (BOOK[0] - 0.1, BOOK_Y, BOOK[1]), fov=27, ease="in")

hand = shot.actor("writer", w, extra=True)
hand.mark(0.0, (WRITER[0], 0.0, WRITER[1]), 180.0)
hand.hold("Pen", "Right Arm", (0, -1.0, -0.15), (60, 0, 0))

book = shot.prop("Grimoire", scale=MANUAL, open=1.0)  # the page's head away from the writer
book.at(0.0, (BOOK[0], BOOK_Y, BOOK[1]), (0, 0, 0))
book.at(LENGTH, (BOOK[0], BOOK_Y, BOOK[1]), (0, 0, 0))

shot.event(0.15, "sfx", slot="bell")
shot.event(0.9, "sfx", slot="penScratch")
shot.event(0.6, "card", key="gambit", dur=3.0)
