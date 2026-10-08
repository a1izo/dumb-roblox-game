"""Diavolo's role cutscene (the briefing, seen only by Diavolo), 15 s.

1  0.0-3.0   From behind the kneeling Muertos, over the desk: Diavolo at the tall window, back to the room,
             a black shape against the rain. Lightning.
2  3.0-5.4   From the room's east side: Diavolo looks round over the right shoulder, smiles, turns.
3  5.4-7.7   Diavolo walks round the desk to the open floor before the Muertos, the notebook in hand.
4  7.7-9.0   Insert: the notebook raised, held to the chest.
5  9.0-11.4  Low from the west: Diavolo throws their arms open; behind, unseen, the Deathsinger rises
             out of the dark over the desk.
6  11.4-12.8 High over Diavolo's shoulder: the Muertos bow down to the floor.
7  12.8-15.0 Close: a hand over the face, a chuckle that breaks into a laugh, head thrown back.

The study (maps/venues/sets/study.py, Sets scene space): the room x -12..12, z -10..10, 14 high; the
window in the north wall (x -4..4); the desk at (0, -3.6) (x -3.3..3.3, z -5.2..-2.0, top 3.23), the
lamp at its west end; no chair (Diavolo stands)."""

from animlib import J
from cinema import framing
from cinema.acting import PRAY, beat, facing, hold, kneel, soft, walking
from cinema.shot import Shot
from motion import Motion

NAME = "RoleDiavolo"
LENGTH = 15.0
WINDOW = (3.2, -8.8)
CORNER = (4.9, -5.4)  # round the desk's east end
STAND = (2.2, -0.8)  # the open floor in front of the desk
SINGER = (2.2, -3.6)
KNEEL = [(0.0, 3.4), (4.4, 3.4), (-2.6, 1.4), (7.0, 1.4)]  # an arc with a gap in front of Diavolo
WALK_START, WALK_END = 5.4, 7.6

# Diavolo ---------------------------------------------------------------------------------------------

BEHIND = dict(rShoulder=J((-20, 0, -10), (0.16, 0.05, 0.18)), lShoulder=J((-20, 0, 10), (-0.16, 0.05, 0.18)))
WALK_ARMS = dict(rShoulder=J((6, 0, -2)), lShoulder=J((10, 0, 4), (0.0, 0.02, -0.04)))
BOOK = dict(lShoulder=J((78, 0, 34), (0.26, 0.18, -0.3)))  # the notebook held up to the chest

d = Motion("RoleDiavolo_self", LENGTH, note="Diavolo's role cutscene: the window, the notebook, the laugh.")
d.key(0.0, root=(4, 0, 0), neck=(10, 0, 0), **BEHIND)  # chest up, eyes up at the storm
d.key(1.6, root=(5, 0, 0), neck=(12, 0, -4), **BEHIND)
d.key(3.0, root=(4, 0, 0), neck=(10, 0, -2), **BEHIND)
beat(d, 3.7, 0.5, neck=(-6, -60, 6))  # a look over the right shoulder, into the room
hold(d, 4.5)
beat(d, 5.0, 0.5, root=(-4, -40, 0), neck=(-6, -30, 0))  # the body follows the head round
beat(d, 5.5, 0.4, root=(-6, 0, 0), neck=(2, 0, 0), **WALK_ARMS)
hold(d, WALK_END)
beat(d, 8.1, 0.45, root=(-4, 0, 0), neck=(-14, 0, 0), **BOOK)  # raises the notebook, eyes on it
hold(d, 8.9)
beat(d, 9.6, 0.6, root=(6, 0, 0), neck=(16, 0, 0), lShoulder=J((14, 0, -8)))  # straightens, chin up
beat(d, 10.2, 0.5, antic=0.35, over=0.15,  # and throws the arms open
     rShoulder=J((34, -12, 66), (0.1, 0.16, -0.06)), lShoulder=J((34, 12, -66), (-0.1, 0.16, -0.06)))
d.key(11.2, root=(7, 0, 0), neck=(18, 0, 0))
hold(d, 12.6)
FACE = dict(rShoulder=J((136, 0, -38), (-0.24, 0.32, -0.26)), lShoulder=J((22, 0, -18), (0.04, 0.04, 0.0)))
beat(d, 13.1, 0.4, root=(-10, 0, 0), neck=(-18, 0, 0), **FACE)  # a hand over the face
for k in range(4):  # a chuckle shakes the shoulders
    t = 13.2 + 0.15 * k
    d.key(t, "sine", root=(-10 + (4 if k % 2 else 0), 0, 0), neck=(-16 + (5 if k % 2 else 0), 0, 0))
beat(d, 14.0, 0.3, antic=0.3, over=0.2, root=(16, 0, 0), neck=(34, 0, 0),  # and breaks: head back
     rShoulder=J((40, -14, 64), (0.08, 0.2, 0.0)), lShoulder=J((40, 14, -64), (-0.08, 0.2, 0.0)))
for k in range(7):
    t = 14.15 + 0.12 * k
    d.key(t, "sine", root=(16 + (4 if k % 2 else 0), 0, (2 if k % 2 else -2)), neck=(34 + (6 if k % 2 else 0), 0, 0))
soft(d, head=2.6, arms=2.2).plant(None, WALK_START - 0.1, stance=0.06).plant(WALK_END + 0.1, None, stance=0.06)
walking(d, WALK_START, WALK_END)
d.build()

# The Muertos -----------------------------------------------------------------------------------------


def kneeler(k):
    m = Motion(f"RoleDiavolo_kneel{k}", LENGTH, note="Diavolo's role cutscene: a Muerto kneeling.")
    lag = 0.12 * k
    kneel(m, 0.0, lean=-10, head=-30, **PRAY)
    kneel(m, 7.4 + lag, lean=-10, head=-28, **PRAY)
    kneel(m, 8.0 + lag, lean=-4, head=-8, **PRAY)  # they lift their eyes as Diavolo comes before them
    kneel(m, 10.0 + lag, lean=0, head=-2, **PRAY)  # a breath in as the arms open...
    kneel(m, 10.7 + lag, "out", lean=-46, head=-40, **PRAY)  # ...and down to the floor
    kneel(m, 12.2 + lag, lean=-48, head=-42, **PRAY)
    kneel(m, LENGTH, lean=-47, head=-42, **PRAY)
    return soft(m, head=3.0, arms=2.6)


for k in range(len(KNEEL)):
    kneeler(k).build()

# The shot --------------------------------------------------------------------------------------------

shot = Shot(NAME, "Sets", LENGTH, note="Diavolo's role cutscene: the study, the Muertos, the Deathsinger.")
shot.room = (-12.0, -10.0, 12.0, 10.0, 14.0)

me = shot.actor("self", d, silhouette=(0.0, 3.0))
me.mark(0.0, (WINDOW[0], 0.0, WINDOW[1]), 0.0)
me.mark(4.6, (WINDOW[0], 0.0, WINDOW[1]), 0.0)
# turning right all the way round: 0 -> -153 (to the corner) -> -210 (to the open floor) -> -180
me.mark(WALK_START, (WINDOW[0], 0.0, WINDOW[1]), facing(WINDOW, CORNER))
me.mark(WALK_START + 0.94, (CORNER[0], 0.0, CORNER[1]), facing(WINDOW, CORNER), "linear")
me.mark(WALK_END, (STAND[0], 0.0, STAND[1]), facing(CORNER, STAND) - 360, "linear")
me.mark(WALK_END + 0.5, (STAND[0], 0.0, STAND[1]), -180.0)
me.mark(LENGTH, (STAND[0], 0.0, STAND[1]), -180.0)
me.hold("Notebook", "Left Arm", (0.0, -1.15, -0.25), (12, 0, 0))
for k, (x, z) in enumerate(KNEEL):
    a = shot.actor(f"ally:{k + 1}", clip=f"RoleDiavolo_kneel{k}")
    a.mark(0.0, (x, 0.0, z), facing((x, z), STAND))

singer = shot.prop("Specter", show=(9.0, None))
singer.at(9.0, (SINGER[0], -11.0, SINGER[1]), (0, 180, 0))
singer.at(9.4, (SINGER[0], -9.6, SINGER[1]), (0, 180, 0), "in")
singer.at(11.0, (SINGER[0], 0.4, SINGER[1]), (0, 180, 0), "out")
singer.at(LENGTH, (SINGER[0], 0.8, SINGER[1]), (0, 184, 0))

# 1: from behind the Muertos, over the desk to the window; a slow creep in.
shot.cam(0.0, (1.0, 4.8, 8.6), (3.0, 4.6, -8.8), fov=42)
shot.cam(3.0, (1.6, 4.6, 6.0), (3.0, 4.7, -8.8), fov=40, ease="linear")
# 2: from the room's east side, holding on them as they look round and turn.
shot.pan(3.0, WALK_START, "self", (8.6, 4.8, -8.4), fov=34, cut=True)
# 3: from the south-east corner, turning with them as they come round the desk.
shot.pan(WALK_START, WALK_END, "self", (9.4, 4.4, 4.2), dy=-0.6, fov=44, cut=True, drift=(-1.2, 0.0, -0.6))
# 4: in front, between the kneeling Muertos: the notebook raised to the chest.
shot.frame(WALK_END, "self", "medium", angle=0, height=0.4, cut=True)
shot.frame(9.0, "self", "medium", angle=4, height=0.2, dist=0.82, ease="linear")
# 5: low from the south-east, up at Diavolo's face and the Deathsinger rising behind.
shot.pan(9.0, 11.4, "self", (2.9, 1.8, 2.6), aim="Torso", dy=2.4, fov=54, cut=True, drift=(0.0, 0.0, -0.4))
# 6: over Diavolo's shoulder, down onto the Muertos bowing.
shot.cam(11.4, (-3.6, 7.4, -1.2), (2.2, 1.2, 2.2), fov=46, cut=True)
shot.cam(12.8, (-3.8, 7.9, -1.4), (2.2, 1.0, 2.2), fov=44, ease="linear")
# 7: the laugh, close; the camera rises as the head goes back, to keep the face.
shot.frame(12.8, "self", "close", angle=-25, height=-0.2, cut=True)
shot.frame(13.9, "self", "close", angle=-20, height=0.4, dist=0.92)
shot.frame(LENGTH, "self", "close", angle=-16, height=1.6, dist=0.86, ease="in")

shot.event(0.0, "sfx", slot="mapRainGlass")
shot.event(1.2, "fx", name="flash", r=200, g=210, b=255, strength=0.5, dur=0.35)
shot.event(1.25, "sfx", slot="thunder")
shot.event(9.2, "sfx", slot="wisp")
shot.event(10.2, "fx", name="flash", r=200, g=20, b=30, strength=0.35, dur=0.5)
shot.event(10.2, "sfx", slot="eyesOpen")
shot.event(14.0, "sfx", slot="hauntWhisper")
# The role card, as captions over the scene (the game fills them in).
shot.event(1.0, "card", key="role", dur=4.2)
shot.event(5.6, "card", key="win", dur=3.4)
shot.event(9.2, "card", key="move", dur=2.8)
shot.event(12.2, "card", key="names", dur=2.8)
