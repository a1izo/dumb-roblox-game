"""Diavolo's role cutscene (the briefing, seen only by Diavolo), 15 s: "...and EAT IT." After the anime's potato
chip scene: Diavolo at the desk at night, studying, the news on, eating chips; under the bag's edge a torn page
of the Manual, and between the chips a name goes on it. The television flatlines. Then the chip, held up, and
eaten like a verdict.

A  0.0-2.6   Wide from the television's corner: night, the lamp, rain on the window. Diavolo reads, calm; a hand
             goes into the bag of chips.
B  2.6-4.0   Across the desk: a chip eaten without looking up, eyes on the book.
C  4.0-6.2   On the desk by the lamp: the torn page, the pen writing a name in hard quick strokes.
D  6.2-7.4   His face, the eyes sliding to the television: the news, a man collapses live; a flatline.
E  7.4-9.0   Low: the hand takes a chip and lifts it, slowly.
F  9.0-10.6  Close, tilted: the chip held up before the face... and bitten: "...and EAT IT."
G  10.6-12.8 He leans back into the chair, the grin; behind him the Deathsinger rises and laughs.
H  12.8-15.0 Pushing in on the face: the laugh, the red.

The study (maps/venues/sets/study.py, Sets scene space): the room x -12..12, z -10..10, 14 high; the window in
the north wall; the desk before it at (0, -5.4) (x -3.3..3.3, z -7.0..-3.8, top 2.7), its lamp at the west end;
the chair behind it at (0, -8.0); the television across the room at (0, 6.6) facing the desk."""

from animlib import J
from cinema.acting import alive, perched, soft, strike
from cinema.shot import Shot
from motion import Motion

NAME = "RoleDiavolo"
LENGTH = 15.0
TOP = 2.7  # the desk top
HIP = 2.15  # on the chair's cushion
SIT = (0.0, -7.8)  # under the hips, facing south (180): thighs sloping under the desk's edge (z -7.0)
BOOK = (0.3, -6.4)  # the open book he studies
BAG = (2.4, -6.2)  # the bag of chips, east of the book (by his left hand)
PAGE = (-1.3, -6.5)  # the torn page, under his right hand, by the lamp
SINGER = (-2.6, -10.0)

# Diavolo --------------------------------------------------------------------------------------------------

READ_R = J((84, -8, -14), (-0.1, 0.04, -0.3))  # the right hand on the book (the pen in it)
READ_L = J((80, 8, 16), (0.1, 0.04, -0.3))
WRITE_R = J((80, -14, -20), (-0.14, 0.04, -0.3))  # the pen over the page, out to the right
BAG_L = J((76, 12, 30), (0.0, 0.06, -0.3))  # the left hand in the bag (across the body)
MOUTH_L = J((128, -34, 18), (0.0, 0.22, -0.2))  # the chip at the mouth
HELD_L = J((112, -24, 30), (0.0, 0.2, -0.24))  # the chip held up before the face
DOWN = (-14, 0, 0)  # the head over the book

d = Motion("RoleDiavolo_self", LENGTH, note="Diavolo's role cutscene: and eat it.")


def sit(t, ease="smooth", lean=-10, neck=DOWN, r=READ_R, l=READ_L, turn=0):
    perched(d, t, ease, hip=HIP, lean=lean, turn=turn, neck=neck, rShoulder=r, lShoulder=l)


sit(0.0)
sit(1.3, neck=(-12, 0, 0))
sit(1.8, "out", l=BAG_L)  # into the bag
sit(2.2, l=BAG_L)
sit(2.9, "out", neck=(-10, 0, 0), l=MOUTH_L)  # a chip, eaten without looking up
for k in range(3):  # chewing
    sit(3.1 + 0.18 * k, "sine", neck=(-10 + (2 if k % 2 == 0 else 0), 0, 0), l=MOUTH_L)
sit(3.7, l=READ_L)
# The name: the pen goes to the page, then hard quick strokes (hold, a tiny wind-up, snap down, settle).
sit(4.15, "out", r=WRITE_R, neck=(-18, -10, 0))
for k, t in enumerate((4.5, 4.75, 5.0, 5.3, 5.55, 5.8)):
    up = J((82, -14 + 4 * (k % 3), -20), (-0.14, 0.12, -0.3))
    strike(d, t, {"rShoulder": up}, {"rShoulder": WRITE_R}, antic=0.07, travel=0.05, over=0.15, settle=0.1)
sit(6.1, neck=(-18, -10, 0), r=WRITE_R)
# The eyes go to the television (towards the camera), the head following a beat later.
sit(6.5, "out", neck=(-6, 0, 0), r=READ_R)
sit(7.2, neck=(-2, 4, 0), r=READ_R)
# Another chip, lifted slowly, then held up before the face...
sit(7.6, "out", neck=(-4, 0, 0), l=BAG_L)
sit(8.1, l=BAG_L)
sit(9.0, "sine", lean=-4, neck=(4, -6, 0), l=HELD_L)
sit(9.6, lean=-4, neck=(6, -6, 4), l=HELD_L)  # ...held: the look past it, the slow smile
# ...and eaten: a snap forward into it.
strike(d, 10.0, {"lShoulder": J((104, -20, 30), (0.0, 0.2, -0.24)), "neck": J((10, -6, 4)), "root": J((-2, 0, 0)),
                 "rShoulder": J((96, -8, -14), (-0.1, 0.04, -0.3))},
       {"lShoulder": MOUTH_L, "neck": J((-14, 0, 0)), "root": J((-16, 0, 0)), "rShoulder": J((104, -8, -14), (-0.1, 0.04, -0.3))}, antic=0.12, travel=0.05, over=0.3,
       settle=0.25)
# He leans back into the chair (the arms swing out over the desk's edge first), the grin; the shoulders
# shake with a silent laugh.
perched(d, 10.5, hip=HIP, lean=2, neck=(4, 0, 0), rShoulder=J((60, 0, 56)), lShoulder=J((64, 0, -56)))
perched(d, 10.9, "out", hip=HIP, lean=10, neck=(14, 0, 0), rShoulder=J((-6, 0, 22)), lShoulder=J((-6, 0, -22)))
for k in range(8):
    t = 11.3 + 0.22 * k
    perched(d, t, "sine", hip=HIP, lean=10 + (3 if k % 2 else 0), neck=(14 + (4 if k % 2 else 0), 0, 0),
            rShoulder=J((-6, 0, 22)), lShoulder=J((-6, 0, -22)))
perched(d, 13.2, hip=HIP, lean=6, neck=(4, 0, 0), rShoulder=J((-6, 0, 22)), lShoulder=J((-6, 0, -22)))
perched(d, LENGTH, hip=HIP, lean=4, neck=(2, 0, 2), rShoulder=J((-4, 0, 22)), lShoulder=J((-4, 0, -22)))
soft(d, head=3.2, arms=3.0, arm_damp=0.55)
alive(d, 0.7, seed=1)
d.build()

# The shot -------------------------------------------------------------------------------------------------

shot = Shot(NAME, "Sets", LENGTH, note="Diavolo's role cutscene: and eat it.")
shot.room = (-12.0, -10.0, 12.0, 10.0, 14.0)
shot.allow = {"self": ["OfficeChair"]}  # in the chair, never into the desk

me = shot.actor("self", d)
me.mark(0.0, (SIT[0], 0.0, SIT[1]), 180.0)
me.hold("Pen", "Right Arm", (0, -1.0, -0.15), (60, 0, 0))
me.hold("Chip", "Left Arm", (0.0, -1.05, -0.2), (70, 0, 0), t0=2.3, t1=3.2)
me.hold("Chip", "Left Arm", (0.0, -1.05, -0.2), (70, 0, 0), t0=8.2, t1=10.05)

book = shot.prop("NotebookOpen")
book.at(0.0, (BOOK[0], TOP, BOOK[1]), (0, 180, 0))
book.at(LENGTH, (BOOK[0], TOP, BOOK[1]), (0, 180, 0))
bag = shot.prop("ChipBag")
bag.at(0.0, (BAG[0], TOP, BAG[1]), (0, 200, 0))
bag.at(LENGTH, (BAG[0], TOP, BAG[1]), (0, 200, 0))
page = shot.prop("PaperNote")
page.at(0.0, (PAGE[0], TOP + 0.01, PAGE[1]), (0, 170, 0))
page.at(LENGTH, (PAGE[0], TOP + 0.01, PAGE[1]), (0, 170, 0))

singer = shot.prop("Specter", show=(10.6, None))
singer.at(10.6, (SINGER[0], -11.0, SINGER[1]), (0, 180, 0))
singer.at(10.9, (SINGER[0], -9.6, SINGER[1]), (0, 180, 0), "in")
singer.at(12.2, (SINGER[0], 0.2, SINGER[1]), (10, 174, 0), "out")  # up behind the chair, leaning over the shoulder
for k in range(6):  # it laughs with them
    t = 12.5 + 0.4 * k
    singer.at(t, (SINGER[0], 0.3 + (0.25 if k % 2 else 0.0), SINGER[1] + 0.3), (12 - (5 if k % 2 else 0), 170, 4))

# A: wide from the television's corner, drifting in.
shot.pan(0.0, 2.6, "self", (2.6, 8.0, 7.2), aim="Torso", dy=0.6, fov=44, drift=(-0.8, -0.6, -2.2), back=True)
# B: across the desk, a chip eaten without looking up.
shot.pan(2.6, 4.0, "self", (2.4, 4.6, -0.6), aim="Head", dy=-0.5, fov=40, cut=True, drift=(-0.2, 0.0, -0.4))
# C: the page by the bag, the pen writing.
shot.subjects.append((4.0, 6.2, None, True))
shot.cam(4.0, (-2.9, 4.9, -4.3), (PAGE[0], TOP + 0.1, PAGE[1]), fov=30, cut=True)
shot.cam(6.2, (-2.7, 4.6, -4.6), (PAGE[0], TOP + 0.1, PAGE[1]), fov=28, ease="linear")
# D: his face, the eyes sliding to the television (towards us).
shot.pan(6.2, 7.4, "self", (0.6, 4.9, -1.6), aim="Head", dy=-0.2, fov=40, cut=True, drift=(0.0, 0.0, -0.3))
# E: low, the chip lifted.
shot.pan(7.4, 9.0, "self", (1.9, 3.9, -2.0), aim="Head", dy=-0.2, fov=48, cut=True, drift=(-0.2, 0.1, -0.3))
# F: close and tilted on the chip and the face, a snap push-in on the bite.
shot.subjects.append((9.0, 10.6, "self", False))
shot.cam(9.0, (1.0, 4.7, -2.7), (0.2, 4.5, -7.3), fov=44, roll=-8.0, cut=True)
shot.cam(9.95, (0.9, 4.7, -2.9), (0.2, 4.5, -7.3), fov=43, roll=-9.0, ease="linear")
shot.cam(10.05, (0.8, 4.7, -3.2), (0.1, 4.5, -7.3), fov=40, roll=-11.0, ease="snap")
shot.cam(10.6, (0.8, 4.7, -3.3), (0.1, 4.5, -7.3), fov=40, roll=-11.0, ease="linear")
# G: back into the chair, the Deathsinger rising behind: from the desk's east end, pulling back.
shot.pan(10.6, 12.8, "self", (3.6, 4.2, -2.4), aim="Torso", dy=1.0, fov=50, cut=True, drift=(0.4, 0.3, 0.8))
# H: pushing in on the face.
shot.pan(12.8, LENGTH, "self", (1.2, 4.8, -1.6), aim="Head", dy=-0.4, fov=44, cut=True, drift=(-0.3, -0.1, -1.1))

# Faces
shot.face(0.0, "self", "Stern")
shot.face(9.4, "self", "Grin")
shot.face(10.0, "self", "Crazed")
shot.face(10.9, "self", "Laugh")
shot.face(12.8, "self", "Grin")

shot.event(0.0, "sfx", slot="mapRainGlass")
shot.event(0.4, "sfx", slot="mapNewsRadio")
shot.event(1.2, "fx", name="flash", r=200, g=210, b=255, strength=0.35, dur=0.3)
shot.event(1.25, "sfx", slot="thunder")
shot.event(4.4, "sfx", slot="penScratch")
shot.event(7.0, "sfx", slot="flatline")
shot.event(9.05, "subtitle", text="I'll take a potato chip...", dur=0.9)
shot.event(10.0, "subtitle", text="...and EAT IT.", dur=1.3)
shot.event(10.0, "sfx", slot="slam")
shot.event(10.0, "fx", name="impact", r=255, g=40, b=50, strength=0.55, dur=0.28)
shot.event(10.0, "fx", name="shake", strength=0.35, dur=0.25)
shot.event(11.0, "sfx", slot="wisp")
shot.event(12.3, "sfx", slot="hauntWhisper")
shot.event(14.0, "fx", name="flash", r=200, g=20, b=30, strength=0.3, dur=0.5)
# The role card, as captions over the calmer moments (the game fills them in).
shot.event(0.5, "card", key="role", dur=2.0)
shot.event(4.3, "card", key="win", dur=1.8)
shot.event(10.9, "card", key="move", dur=1.8)
shot.event(13.0, "card", key="names", dur=1.9)
