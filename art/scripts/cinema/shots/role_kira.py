"""Diavolo's role cutscene (the briefing, seen only by Diavolo), 15 s, four shots: writing the name.

A  0.0-4.0   Night, the desk lamp, rain on the window behind. From the television's corner, high and wide,
             drifting in: Diavolo at the desk writing in the notebook, fast and hard. In the dark along the
             bookcases the Muertos kneel.
B  4.0-8.0   Close on the page: the pen scratching a name; behind, the television: the news, a man has
             collapsed live on air. A flatline. Then the face over the page, as the pen stops.
C  8.0-11.2  Lower and closer: Diavolo slowly lifts their head to the television. A grin. Behind them the
             Deathsinger rises and leans over their shoulder; their shoulders shake.
D  11.2-13.4 Low, from the desk's corner, pulling back: the hand slams the book shut; Diavolo rises, arms flung
             wide, and laughs, the Deathsinger with them.
E  13.4-15.0 Over Diavolo's shoulder, high: the room, the Muertos bowing to the floor before them.

The study (maps/venues/sets/study.py, Sets scene space): the room x -12..12, z -10..10, 14 high; the window
in the north wall (x -3..3, from 5.4 up); the desk before it at (0, -5.4) (x -3.3..3.3, z -7.0..-3.8, top
2.7), its lamp at the west end; the office chair behind it at (0, -8.0); the television across the room at
(0, 6.6) facing the desk; bookcases along both side walls (fronts at x -9.5 / 9.5)."""

from animlib import J
from cinema.acting import PRAY, alive, facing, kneel, seated, soft, writing
from cinema.shot import Shot
from motion import Motion

NAME = "RoleDiavolo"
LENGTH = 15.0
TOP = 2.7  # the desk top
SEAT = 2.0
DESK_SIDE = (0.0, -7.5)  # where Diavolo sits (on the floor under the hips), facing the desk
BOOK = (0.2, -6.3)
SINGER = (-2.6, -10.0)  # behind Diavolo's right shoulder (it is 4.6 deep), leaning its head over it
KNEEL = [(-6.3, -2.8), (6.3, -2.8), (-5.8, 1.4), (5.8, 1.4)]

# Diavolo ---------------------------------------------------------------------------------------------

LOOK_UP = (-2, 0, 0)
WIDE = dict(rShoulder=J((40, -14, 72), (0.1, 0.18, -0.04)), lShoulder=J((40, 14, -72), (-0.1, 0.18, -0.04)))
STILL_R = J((70, 0, -10), (-0.02, 0.06, -0.3))
STILL_L = J((54, 0, 24), (0.2, 0.04, -0.3))
LIFTED = J((78, 0, -10), (-0.02, 0.1, -0.3))

d = Motion("RoleDiavolo_self", LENGTH, note="Diavolo's role cutscene: writing the name.")
# Eyes on the page rather than nose to it: real avatars' hair hides a face bent any lower.
writing(d, 0.0, 7.4, seat=SEAT, lean=-18, head=-12, speed=1.1, seed=3)
seated(d, 7.55, "out", seat=SEAT, lean=-19, legs=86, neck=(-13, 0, 0), rShoulder=LIFTED, lShoulder=STILL_L)  # pen up
seated(d, 8.3, seat=SEAT, lean=-19, legs=86, neck=(-14, 0, 0), rShoulder=LIFTED, lShoulder=STILL_L)  # still...
seated(d, 9.2, "sine", seat=SEAT, lean=-12, legs=86, neck=LOOK_UP, rShoulder=STILL_R, lShoulder=STILL_L)  # up, slowly
seated(d, 9.6, seat=SEAT, lean=-14, legs=86, neck=(-2, 0, 8), rShoulder=STILL_R, lShoulder=STILL_L)  # the head tilts
for k in range(6):  # a silent laugh shakes the shoulders
    t = 10.0 + 0.17 * k
    seated(d, t, "sine", seat=SEAT, lean=-14 + (3 if k % 2 else -1), legs=86, neck=(-2 + (3 if k % 2 else 0), 0, 8),
           rShoulder=STILL_R, lShoulder=STILL_L)
seated(d, 11.15, seat=SEAT, lean=-10, legs=86, neck=(4, 0, 4),  # the hand comes up...
       rShoulder=J((118, 0, -14), (-0.04, 0.2, -0.3)), lShoulder=STILL_L)
seated(d, 11.42, "in", seat=SEAT, lean=-30, legs=86, neck=(-22, 0, 0),  # ...and slams the book shut
       rShoulder=J((56, 0, -8), (-0.02, 0.04, -0.34)), lShoulder=STILL_L)
seated(d, 11.65, seat=SEAT, lean=-28, legs=86, neck=(-18, 0, 0), rShoulder=J((58, 0, -8), (-0.02, 0.04, -0.34)),
       lShoulder=STILL_L)
d.key(12.2, "out", offset=(0, 0, 0), root=(6, 0, 0), neck=(14, 0, 0), rHip=(0, 0, 0), lHip=(0, 0, 0), **WIDE)  # up
d.key(12.6, root=(10, 0, 0), neck=(24, 0, 0))
for k in range(9):  # and laughs, head back
    t = 12.8 + 0.24 * k
    d.key(t, "sine", root=(12 + (3 if k % 2 else 0), 0, (2 if k % 2 else -2)), neck=(30 + (6 if k % 2 else 0), 0, 0))
soft(d, head=2.6, arms=3.0, arm_damp=0.55).plant(12.25, None, stance=0.06)
alive(d, 0.8, seed=1, t0=7.6)
d.build()

# The Muertos -----------------------------------------------------------------------------------------


def kneeler(k):
    m = Motion(f"RoleDiavolo_kneel{k}", LENGTH, note="Diavolo's role cutscene: a Muerto in the dark.")
    lag = 0.1 * k
    kneel(m, 0.0, lean=-14, head=-32, **PRAY)
    kneel(m, 9.6 + lag, lean=-14, head=-30, **PRAY)
    kneel(m, 10.1 + lag, "out", lean=-26, head=-38, **PRAY)  # the Deathsinger: they cower
    kneel(m, 11.4, lean=-26, head=-38, **PRAY)
    kneel(m, 11.6, "out", lean=-8, head=-4, **PRAY)  # the slam: heads jerk up
    kneel(m, 12.6 + lag, lean=-6, head=0, **PRAY)
    kneel(m, 13.3 + lag, "out", lean=-46, head=-40, **PRAY)  # and down to the floor
    kneel(m, LENGTH, lean=-47, head=-42, **PRAY)
    soft(m, head=2.8, arms=2.4)
    return alive(m, 0.6, seed=k + 5)


for k in range(len(KNEEL)):
    kneeler(k).build()

# The shot --------------------------------------------------------------------------------------------

shot = Shot(NAME, "Sets", LENGTH, note="Diavolo's role cutscene: writing the name.")
shot.room = (-12.0, -10.0, 12.0, 10.0, 14.0)
shot.allow = {"self": ["ExecutiveDesk", "OfficeChair"]}  # sat at the desk, in the chair

me = shot.actor("self", d)
me.mark(0.0, (DESK_SIDE[0], 0.0, DESK_SIDE[1]), 180.0)
me.hold("Pen", "Right Arm", (0, -1.0, -0.15), (60, 0, 0), t1=11.3)
for k, (x, z) in enumerate(KNEEL):
    a = shot.actor(f"ally:{k + 1}", clip=f"RoleDiavolo_kneel{k}")
    a.mark(0.0, (x, 0.0, z), facing((x, z), DESK_SIDE))

book = shot.prop("NotebookOpen", show=(0.0, 11.42))
book.at(0.0, (BOOK[0], TOP, BOOK[1]), (0, 180, 0))
book.at(LENGTH, (BOOK[0], TOP, BOOK[1]), (0, 180, 0))
shut = shot.prop("Notebook", show=(11.42, None))
shut.at(11.42, (BOOK[0] - 0.6, TOP + 0.11, BOOK[1]), (0, 176, 0))
shut.at(LENGTH, (BOOK[0] - 0.6, TOP + 0.11, BOOK[1]), (0, 176, 0))

singer = shot.prop("Specter", show=(8.6, None))
singer.at(8.6, (SINGER[0], -11.0, SINGER[1]), (0, 180, 0))
singer.at(8.9, (SINGER[0], -9.6, SINGER[1]), (0, 180, 0), "in")
singer.at(10.4, (SINGER[0], 0.2, SINGER[1]), (10, 174, 0), "out")  # up behind the chair, leaning over the shoulder
singer.at(11.4, (SINGER[0], 0.2, SINGER[1] + 0.3), (12, 170, 4))
for k in range(8):  # it laughs with them
    t = 12.6 + 0.3 * k
    singer.at(t, (SINGER[0], 0.4 + (0.25 if k % 2 else 0.0), SINGER[1] + 0.3), (12 - (5 if k % 2 else 0), 170, 4))

# A: from the television's corner, high and wide, drifting in (the room matters more than the face).
shot.pan(0.0, 4.0, "self", (2.6, 8.0, 7.2), aim="Torso", dy=0.6, fov=44, drift=(-0.8, -0.6, -2.2), back=True)
# B: across the desk at eye level, far enough back for real hair: head, shoulders, the hands on the book.
shot.subjects.append((4.0, 6.4, None, True))  # the page, not a face
shot.cam(4.0, (1.1, 6.2, -3.7), (BOOK[0], TOP + 0.2, BOOK[1]), fov=34, cut=True)  # the pen on the page,
shot.cam(6.4, (0.8, 5.8, -4.1), (BOOK[0], TOP + 0.3, BOOK[1]), fov=32, ease="linear")  # Diavolo looming behind it
shot.pan(6.4, 8.0, "self", (2.7, 4.4, 0.8), aim="Head", dy=-0.7, fov=40, cut=True, drift=(-0.2, 0.0, -0.4))  # it stops
# C: lower and closer, from the other side of the lamp's light: the look up, the grin, the Deathsinger behind.
shot.pan(8.0, 11.2, "self", (1.9, 4.9, -1.6), aim="Head", dy=-0.35, fov=44, cut=True, drift=(-0.3, 0.0, -0.4))
# D: low from the desk's east corner, pulling back as Diavolo rises and laughs.
shot.pan(11.2, 13.4, "self", (3.4, 3.0, -2.6), aim="Torso", dy=1.0, fov=52, cut=True, drift=(-0.3, 0.3, 1.0))
# E: high over Diavolo's shoulder: the Muertos bowing to them.
shot.subjects.append((13.4, LENGTH, None, True))  # the room, past Diavolo's shoulder: no face to frame
shot.cam(13.4, (-4.6, 7.8, -9.3), (1.2, 1.4, 0.4), fov=50, cut=True)
shot.cam(LENGTH, (-4.3, 8.1, -9.2), (1.2, 1.2, 0.2), fov=48, ease="linear")

# Faces
shot.face(0.0, "self", "Stern")
shot.face(9.1, "self", "Grin")
shot.face(11.3, "self", "Crazed")
shot.face(12.4, "self", "Laugh")
for k in range(len(KNEEL)):
    shot.face(11.6, f"ally:{k + 1}", "Shock")
    shot.face(13.3, f"ally:{k + 1}", "Devoted")

shot.event(0.0, "sfx", slot="mapRainGlass")
shot.event(0.0, "sfx", slot="penScratch")
shot.event(1.2, "fx", name="flash", r=200, g=210, b=255, strength=0.4, dur=0.3)
shot.event(1.25, "sfx", slot="thunder")
shot.event(5.0, "sfx", slot="mapNewsRadio")
shot.event(6.8, "sfx", slot="flatline")
shot.event(8.7, "sfx", slot="wisp")
shot.event(10.3, "fx", name="flash", r=200, g=20, b=30, strength=0.25, dur=0.4)
shot.event(11.42, "sfx", slot="slam")
shot.event(11.42, "fx", name="shake", strength=0.5, dur=0.35)
shot.event(12.6, "sfx", slot="hauntWhisper")
# The role card, as captions over the scene (the game fills them in), one per shot.
shot.event(0.8, "card", key="role", dur=3.2)
shot.event(4.5, "card", key="win", dur=2.8)
shot.event(7.8, "card", key="move", dur=3.2)
shot.event(12.4, "card", key="names", dur=2.5)
