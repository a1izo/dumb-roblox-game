"""The Death's Gambit opener (everyone, ~4 s, before the writing): the bell, the lamp, and a close look at a
suit-sleeved hand writing in a plain black notebook (never anyone's cosmetic, never anyone in
particular: a faceless figure at Diavolo's desk in the study set, seen only from the sleeve down).

The study (maps/venues/sets/study.py, Sets scene space): the desk at (0, -3.6), top at y 3.23, the banker
lamp at its west end (-2.2, -3.9), the chair behind at (0, -6.2) (seat about 2 high)."""

from animlib import J
from cinema.acting import seated, soft
from cinema.shot import Shot
from motion import Motion

NAME = "GambitOpener"
LENGTH = 4.0
TOP = 3.23
WRITER = (0.0, -5.6)
PAGE = (0.2, -4.4)

w = Motion("GambitOpener_writer", LENGTH, note="The Death's Gambit opener: a hand writing a name.")
for k in range(9):
    t = 0.5 * k
    swing = 1.0 if k % 2 else -1.0
    r = J((58 + 3 * swing, -4 + 6 * swing, -16 + 4 * swing), (-0.12 + 0.12 * swing, 0.04, -0.34))
    left = J((50, 0, 24), (0.22, 0.04, -0.3))
    seated(w, min(t, LENGTH), seat=2.0, lean=-24, legs=86, neck=(-36, 0, 0), rShoulder=r, lShoulder=left)
soft(w, arms=4.0, arm_damp=0.7)
w.build()

shot = Shot(NAME, "Sets", LENGTH, note="The Death's Gambit opener: the bell, a hand writing in the notebook.")

# A: the dark desk under the one lamp, a slow push in.
shot.cam(0.0, (3.6, 6.4, 1.4), (0.0, 3.4, -4.4), fov=42)
shot.cam(1.6, (2.8, 5.6, -0.2), (0.0, 3.4, -4.4), fov=38, ease="linear")
# B: the pen on the page, very close.
shot.cam(1.6, (-1.8, 4.8, -1.8), (PAGE[0], TOP + 0.3, PAGE[1]), fov=38, cut=True)
shot.cam(LENGTH, (-1.4, 4.5, -2.3), (PAGE[0], TOP + 0.3, PAGE[1]), fov=32, ease="in")

hand = shot.actor("writer", w, extra=True)
hand.mark(0.0, (WRITER[0], 0.0, WRITER[1]), 180.0)
hand.hold("Pen", "Right Arm", (0, -1.0, -0.15), (60, 0, 0))

book = shot.prop("Notebook")
book.at(0.0, (PAGE[0] - 0.9, TOP + 0.11, PAGE[1]), (0, 4, 0))
book.at(LENGTH, (PAGE[0] - 0.9, TOP + 0.11, PAGE[1]), (0, 4, 0))
page = shot.prop("PaperSheet")
page.at(0.0, (PAGE[0], TOP + 0.02, PAGE[1]), (0, -6, 0))
page.at(LENGTH, (PAGE[0], TOP + 0.02, PAGE[1]), (0, -6, 0))

shot.event(0.15, "sfx", slot="bell")
shot.event(1.7, "sfx", slot="penScratch")
shot.event(0.6, "card", key="gambit", dur=3.0)
