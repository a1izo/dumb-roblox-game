"""The Campus intro: the exam hall at midnight, everyone bent over their papers. One player (picked at
random by the server, never by role) stops writing, turns to the glazed side door, and alone sees a
black notebook fall out of the night into the snow under the lamp outside.

The exam hall (maps/venues/campus/auditorium.py): desks in five blocks of three across, rows at
z -95, -90, -85, facing the stage (-z). Each desk's seat sits 1.35 studs behind it, 1.6 high. The
arched side door in the east wall (x 24.6, z -94) has its lamp outside."""

import math
import random

from animlib import J
from cinema.acting import alive, desk_arms, seated, soft
from cinema.shot import Shot
from motion import Motion

NAME = "IntroCampus"
LENGTH = 15.0
SEAT_BACK = 1.55  # from a desk to the body above its seat
DOOR = (24.6, -94.0)
LANDING = (29.0, 0.25, -94.6)

# The noticer's desk (by the east side, nearest the door), and the others' (nearest the camera's way first).
NOTICER_DESK = (14.0, -95.0)
DESKS = [(10.4, -95.0), (14.0, -90.0), (6.8, -95.0), (10.4, -90.0), (-1.2, -95.0), (6.8, -90.0), (-1.2, -90.0),
         (14.0, -85.0), (-4.8, -95.0), (10.4, -85.0), (-4.8, -90.0)]

# Acting ---------------------------------------------------------------------------------------------


def writer(name, length, pause=None):
    """A seated student writing; `pause` = (t0, t1) when the pen stops and the head comes up a little."""
    m = Motion(name, length, loop=True, note="Intro: a candidate writing the exam.")
    steps = int(length / 0.2)
    for i in range(steps):
        t = i * 0.2
        along = math.sin(i * 1.7) * 0.8
        thinking = pause is not None and pause[0] <= t <= pause[1]
        r, left = desk_arms(0.0 if thinking else along)
        neck = (-12, 6, 4) if thinking else (-30, 3 - 4 * along, 0)
        seated(m, t, seat=1.6, lean=-14 if not thinking else -9, neck=neck, rShoulder=r, lShoulder=left)
    return soft(m, arms=4.0)


writer("IntroCampus_writer", 2.4).build()
writer("IntroCampus_thinker", 4.0, pause=(2.2, 3.4)).build()

noticer = Motion("IntroCampus_noticer", LENGTH, note="Intro: the one who sees the notebook fall.")
for i in range(35):  # writing until 7 s
    t = i * 0.2
    along = math.sin(i * 1.7) * 0.8
    r, left = desk_arms(along)
    seated(noticer, t, seat=1.6, lean=-14, neck=(-30, 3 - 4 * along, 0), rShoulder=r, lShoulder=left)
r, left = desk_arms(0.3)
seated(noticer, 7.0, seat=1.6, lean=-13, neck=(-24, 0, 0), rShoulder=r, lShoulder=left)  # the pen stops
seated(noticer, 7.9, seat=1.6, lean=-6, turn=-12, neck=(4, -46, 0),
       rShoulder=J((60, 0, -10), (-0.1, 0.04, -0.28)), lShoulder=left)  # the head turns to the door
seated(noticer, 9.3, seat=1.6, lean=-4, turn=-14, neck=(14, -50, 0), rShoulder=J((56, 0, -8), (-0.1, 0.04, -0.26)),
       lShoulder=left)  # looking up: something above the lamp
seated(noticer, 10.1, "in", seat=1.6, lean=-2, turn=-16, neck=(-10, -52, 0), rShoulder=J((52, 0, -6), (-0.1, 0.04, -0.24)),
       lShoulder=left)  # following it down
seated(noticer, 10.3, "snap", seat=1.6, lean=2, turn=-18, neck=(-6, -54, 0), rShoulder=J((44, 0, -4), (-0.08, 0.06, -0.2)),
       lShoulder=J((58, 0, 20), (0.2, 0.06, -0.28)))  # a start at the impact
seated(noticer, 15.0, seat=1.6, lean=0, turn=-18, neck=(-8, -56, 0), rShoulder=J((42, 0, -4), (-0.08, 0.06, -0.2)),
       lShoulder=J((58, 0, 20), (0.2, 0.06, -0.28)))
soft(noticer, head=3.2, arms=3.0)
alive(noticer, 0.4, seed=31, t1=7.0)
alive(noticer, 0.5, seed=32, t0=10.6)
noticer.build()

# The shot -------------------------------------------------------------------------------------------

shot = Shot(NAME, "Campus", LENGTH, note="Campus intro: the exam hall; one candidate sees the notebook fall.",
            skippable=True, mood="UniversityCampus_Inside")
shot.own = True  # players in their own avatars (the owner, 2026-10-28)

# A: wide and high from the back of the hall, a slow push in.
shot.cam(0.0, (22.0, 15.0, -79.0), (-14.0, 3.0, -99.0), fov=44)
shot.cam(3.2, (19.0, 13.0, -81.0), (-14.0, 3.0, -99.0), fov=40, ease="linear")
# B: low down the aisle between the desks, pencils moving on both sides.
shot.cam(3.2, (2.8, 6.2, -79.5), (2.6, 3.2, -98.0), fov=44, cut=True)
shot.cam(6.0, (2.8, 5.6, -85.5), (3.0, 3.0, -100.0), fov=40, ease="linear")
# C: the noticer, from in front and to the left; still writing, then the pen stops and the head turns.
shot.cam(6.0, (18.6, 5.2, -100.2), (14.0, 4.4, -93.4), fov=30, cut=True)
shot.cam(8.6, (18.0, 5.0, -99.4), (14.0, 4.5, -93.4), fov=27, ease="linear")
# D: over the shoulder, through the glass door: the notebook drops past the lamp into the snow.
shot.cam(8.6, (12.2, 4.9, -91.2), (25.0, 5.8, -94.6), fov=34, cut=True)
shot.cam(11.2, (12.6, 4.8, -91.4), (25.0, 4.6, -94.6), fov=31, ease="linear")
# E: the face: nobody else looked up.
shot.cam(11.2, (19.6, 4.9, -94.6), (14.1, 4.6, -93.5), fov=30, cut=True)
shot.cam(13.2, (18.8, 4.8, -94.4), (14.1, 4.6, -93.5), fov=26, ease="linear")
# F: outside, low in the snow: the notebook lies under the lamp, the lit hall behind.
shot.cam(13.2, (33.0, 0.9, -99.5), (29.0, 0.6, -94.6), fov=34, cut=True)
shot.cam(15.0, (32.4, 0.8, -99.0), (29.0, 0.5, -94.6), fov=30, ease="linear")

who = shot.actor("noticer", noticer)
who.mark(0.0, (NOTICER_DESK[0], 0, NOTICER_DESK[1] + SEAT_BACK), 0)
who.hold("Pen", "Right Arm", (0, -1.0, -0.15), (60, 0, 0), t0=0.0)

rng = random.Random(7)
for k, (dx, dz) in enumerate(DESKS):
    clip = "IntroCampus_thinker" if k % 3 == 2 else "IntroCampus_writer"
    a = shot.actor(f"everyone:{k + 1}", clip=clip, at=-rng.uniform(0, 3.0))
    a.mark(0.0, (dx, 0, dz + SEAT_BACK), rng.uniform(-3, 3))
    a.hold("Pen", "Right Arm", (0, -1.0, -0.15), (60, 0, 0))

# The notebook: out of the dark above the lamp, turning over, into the snow.
book = shot.prop("Grimoire", show=(9.2, LENGTH))
book.at(9.2, (29.8, 34.0, -94.2), (20, 0, 10))
book.at(9.7, (29.5, 17.0, -94.4), (140, 90, 40), "in")
book.at(10.1, LANDING, (0, 25, 0), "in")
book.at(LENGTH, LANDING, (0, 25, 0))

shot.event(0.4, "title", lines=["KAGEGAOKA UNIVERSITY", "The entrance exam, 23:58"], dur=2.6)
shot.event(0.0, "sfx", slot="clockTick")
shot.event(7.0, "sfx", slot="penStop")
shot.event(10.1, "sfx", slot="bookImpact")
shot.event(10.1, "fx", name="snowburst", pos=list(LANDING))
shot.event(11.2, "sfx", slot="heartbeat")
shot.event(13.4, "card", key="case", dur=1.6)
