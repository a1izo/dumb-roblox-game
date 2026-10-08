"""Diavolo's role cutscene (the briefing, seen only by Diavolo), 15 s, four shots.

A  0.0-4.8   One slow move down the room, over the kneeling Muertos, to the tall window: Diavolo stands
             against the rain, a black shape. Lightning. They look round over the shoulder; a second flash
             shows their face; they turn to the room.
B  4.8-8.6   In front of them, going back as they come: Diavolo walks slowly down the room between the
             Muertos and stops; raises the notebook to the chest.
C  8.6-12.0  Low in the aisle: Diavolo throws their arms open; behind them, unseen, the Deathsinger rises out
             of the dark; the Muertos bow down to the floor.
D  12.0-15.0 Close, pushing in: a hand over the face, a chuckle, then the head thrown back in a laugh.

The study (maps/venues/sets/study.py, Sets scene space): the room x -12..12, z -10..10, 14 high; the
window in the north wall (x -3..3, from 5.4 up); the desk against the west side (x -8.6..-5.4,
z -6.9..-0.3); bookcases along both side walls (out to x -9.5 / 9.5); the floor down the middle is open."""

from animlib import J
from cinema.acting import PRAY, beat, facing, hold, kneel, soft, walking
from cinema.shot import Shot
from motion import Motion

NAME = "RoleDiavolo"
LENGTH = 15.0
WINDOW = (0.0, -7.3)  # room behind for the arms as they turn
STAND = (0.0, -2.8)
SINGER = (0.0, -6.6)
KNEEL = [(-3.2, 0.4), (3.2, 0.4), (-2.6, 4.4), (2.6, 4.4)]  # two rows either side of an open aisle
SPEED = 2.6  # a slow walk
WALK = (4.9, 4.9 + (STAND[1] - WINDOW[1]) / SPEED)

# Diavolo ---------------------------------------------------------------------------------------------

BEHIND = dict(rShoulder=J((-20, 0, -10), (0.16, 0.05, 0.18)), lShoulder=J((-20, 0, 10), (-0.16, 0.05, 0.18)))
HANGING = dict(rShoulder=J((4, 0, 2)), lShoulder=J((8, 0, -2)))
BOOK = dict(lShoulder=J((76, 0, 32), (0.24, 0.16, -0.28)))  # the notebook held up to the chest
IN = dict(rShoulder=J((46, 0, -40), (-0.3, 0.1, -0.2)), lShoulder=J((46, 0, 40), (0.3, 0.1, -0.2)))
WIDE = dict(rShoulder=J((38, -14, 70), (0.1, 0.18, -0.04)), lShoulder=J((38, 14, -70), (-0.1, 0.18, -0.04)))
FACE = dict(rShoulder=J((136, 0, -38), (-0.24, 0.32, -0.26)), lShoulder=J((26, 0, -22), (0.04, 0.06, 0.0)))

d = Motion("RoleDiavolo_self", LENGTH, note="Diavolo's role cutscene: the window, the walk, the laugh.")
d.key(0.0, root=(3, 0, 0), neck=(8, 0, 0), **BEHIND)  # chest up, looking out at the storm
d.key(1.4, root=(4, 0, 0), neck=(12, 0, -3), **BEHIND)
d.key(2.6, root=(3, 0, 0), neck=(10, 0, -2), **BEHIND)
beat(d, 3.4, 0.8, antic=0.08, neck=(-4, -64, 4))  # a slow look over the right shoulder
hold(d, 3.7)
beat(d, 4.5, 0.8, root=(-3, -30, 0), neck=(-6, -24, 0))  # the body comes round after the head
beat(d, 5.1, 0.6, root=(-5, 0, 0), neck=(-2, 0, 0), **HANGING)
hold(d, WALK[1])
beat(d, WALK[1] + 0.5, 0.5, root=(-2, 0, 0), neck=(-4, 0, 0))  # stops, weight settles
beat(d, 8.3, 0.7, root=(-4, 0, 0), neck=(-16, 0, 0), **BOOK)  # the notebook up to the chest, eyes on it
hold(d, 8.8)
beat(d, 9.3, 0.5, neck=(-10, 0, 0), **IN)  # the arms come in...
beat(d, 9.9, 0.45, antic=0.0, over=0.18, root=(6, 0, 0), neck=(12, 0, 0), **WIDE)  # ...and fling open
beat(d, 11.4, 1.2, root=(4, 0, 0), neck=(16, 0, 0))  # the chin rises, slowly
hold(d, 11.9)
beat(d, 12.5, 0.5, root=(-8, 0, 0), neck=(-16, 0, 0), **FACE)  # a hand over the face
for k in range(5):  # a chuckle shakes the shoulders
    t = 12.65 + 0.2 * k
    d.key(t, "sine", root=(-8 + (3 if k % 2 else 0), 0, 0), neck=(-14 + (4 if k % 2 else 0), 0, 0))
beat(d, 13.9, 0.4, antic=0.3, over=0.2, root=(16, 0, 0), neck=(34, 0, 0), **WIDE)  # and breaks: head back
for k in range(7):
    t = 14.1 + 0.13 * k
    d.key(t, "sine", root=(16 + (3 if k % 2 else 0), 0, (2 if k % 2 else -2)), neck=(34 + (5 if k % 2 else 0), 0, 0))
soft(d, head=2.4, arms=2.0).plant(None, WALK[0] - 0.1, stance=0.06).plant(WALK[1] + 0.1, None, stance=0.06)
walking(d, WALK[0], WALK[1], speed=SPEED)
d.build()

# The Muertos -----------------------------------------------------------------------------------------


def kneeler(k):
    m = Motion(f"RoleDiavolo_kneel{k}", LENGTH, note="Diavolo's role cutscene: a Muerto kneeling.")
    lag = 0.15 * k
    kneel(m, 0.0, lean=-12, head=-30, **PRAY)
    kneel(m, 4.6 + lag, lean=-12, head=-28, **PRAY)
    kneel(m, 5.4 + lag, lean=-6, head=-12, **PRAY)  # they lift their eyes as Diavolo turns to them
    kneel(m, 9.6 + lag, lean=-4, head=-6, **PRAY)
    kneel(m, 10.0 + lag, lean=0, head=0, **PRAY)  # a breath in as the arms fling open...
    kneel(m, 10.7 + lag, "out", lean=-46, head=-40, **PRAY)  # ...and down to the floor
    kneel(m, LENGTH, lean=-47, head=-42, **PRAY)
    return soft(m, head=2.6, arms=2.2)


for k in range(len(KNEEL)):
    kneeler(k).build()

# The shot --------------------------------------------------------------------------------------------

shot = Shot(NAME, "Sets", LENGTH, note="Diavolo's role cutscene: the study, the Muertos, the Deathsinger.")
shot.room = (-12.0, -10.0, 12.0, 10.0, 14.0)

me = shot.actor("self", d, silhouette=(0.0, 3.5))
me.mark(0.0, (WINDOW[0], 0.0, WINDOW[1]), 0.0)
me.mark(3.8, (WINDOW[0], 0.0, WINDOW[1]), 0.0)
me.mark(4.8, (WINDOW[0], 0.0, WINDOW[1]), -180.0)
me.mark(WALK[0], (WINDOW[0], 0.0, WINDOW[1]), -180.0, "linear")
me.mark(WALK[1], (STAND[0], 0.0, STAND[1]), -180.0, "linear")
me.mark(LENGTH, (STAND[0], 0.0, STAND[1]), -180.0)
me.hold("Notebook", "Left Arm", (0.0, -1.15, -0.25), (12, 0, 0))
for k, (x, z) in enumerate(KNEEL):
    a = shot.actor(f"ally:{k + 1}", clip=f"RoleDiavolo_kneel{k}")
    a.mark(0.0, (x, 0.0, z), facing((x, z), STAND) if z < 2.0 else 0.0)  # the back row straight on

singer = shot.prop("Specter", show=(9.0, None))
singer.at(9.0, (SINGER[0], -11.0, SINGER[1]), (0, 180, 0))
singer.at(9.3, (SINGER[0], -9.8, SINGER[1]), (0, 180, 0), "in")
singer.at(11.2, (SINGER[0], 0.4, SINGER[1]), (0, 180, 0), "out")
singer.at(LENGTH, (SINGER[0], 0.7, SINGER[1]), (0, 182, 0))

# A: one slow move down the room, over the Muertos, to the window.
shot.cam(0.0, (0.0, 6.6, 9.2), (0.0, 4.8, -8.5), fov=40)
shot.cam(4.8, (0.0, 5.6, 4.4), (0.0, 4.4, -8.5), fov=38, ease="linear")
# B: in front of them, going back as they come.
shot.follow(4.8, 8.6, "self", "medium", angle=0, height=0.2, cut=True)
# C: low in the aisle, up at Diavolo and the Deathsinger rising behind.
shot.pan(8.6, 12.0, "self", (0.7, 1.8, 3.4), aim="Torso", dy=1.8, fov=54, cut=True, drift=(-0.2, 0.5, -0.8))
# D: close, pushing in; the camera rises as the head goes back, to keep the face.
shot.frame(12.0, "self", "close", angle=-10, height=0.0, cut=True)
shot.frame(13.8, "self", "close", angle=-8, height=0.3, dist=0.88)
shot.frame(LENGTH, "self", "close", angle=-6, height=1.4, dist=0.8, ease="in")

shot.event(0.0, "sfx", slot="mapRainGlass")
shot.event(1.3, "fx", name="flash", r=200, g=210, b=255, strength=0.45, dur=0.35)
shot.event(1.35, "sfx", slot="thunder")
shot.event(3.5, "fx", name="flash", r=200, g=210, b=255, strength=0.3, dur=0.3)
shot.event(9.2, "sfx", slot="wisp")
shot.event(9.9, "fx", name="flash", r=200, g=20, b=30, strength=0.3, dur=0.5)
shot.event(9.9, "sfx", slot="eyesOpen")
shot.event(13.9, "sfx", slot="hauntWhisper")
# The role card, as captions over the scene (the game fills them in), one per shot.
shot.event(0.8, "card", key="role", dur=3.6)
shot.event(5.2, "card", key="win", dur=3.2)
shot.event(8.9, "card", key="move", dur=2.9)
shot.event(12.2, "card", key="names", dur=2.7)
