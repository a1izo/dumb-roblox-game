"""Diavolo's role cutscene (the briefing, seen only by Diavolo): the study at night. Diavolo stands at the
tall window with their back to the room, watching the rain; the Muertos kneel on the carpet before the
desk. Diavolo turns, lays a hand on the black notebook on the desk, and behind them, unseen, the
Deathsinger rises out of the dark; Diavolo straightens, opens their arms, and laughs. The role card runs
as captions over it.

The study (maps/venues/sets/study.py, Sets scene space): the room x -12..12, z -10..10, the window in the
north wall (x -4..4); the desk at (0, -3.6), 6.6 across, its top at y 3.23; the desk chair behind it at
(0, -6.2). Diavolo stands behind the desk's east end; the Muertos kneel south of the desk."""

from animlib import J
from cinema.acting import PRAY, facing, kneel, soft, walking
from cinema.shot import Shot
from motion import Motion

NAME = "RoleDiavolo"
LENGTH = 15.0
TOP = 3.23  # the desk top
WINDOW = (2.2, -8.7)  # where Diavolo stands at first, looking out
DIAVOLO = (3.4, -6.0)  # behind the desk's east end
NOTEBOOK = (2.9, -4.6)
SINGER = (-1.6, -8.6)  # where the Deathsinger rises, right behind Diavolo
KNEEL = [(-2.4, 0.9), (2.6, 0.9), (-5.4, 2.3), (5.6, 2.3)]

# Acting ---------------------------------------------------------------------------------------------

BEHIND = dict(rShoulder=J((-16, 0, -8), (0.14, 0.04, 0.16)), lShoulder=J((-16, 0, 8), (-0.14, 0.04, 0.16)))
DOWN = dict(rShoulder=J((4, 0, 2)), lShoulder=J((4, 0, -2)))
OPEN = dict(rShoulder=J((24, -10, 30), (0.04, 0.12, -0.08)), lShoulder=J((24, 10, -30), (-0.04, 0.12, -0.08)))
FACE = dict(rShoulder=J((132, 0, -36), (-0.22, 0.3, -0.24)), lShoulder=J((16, 0, -14), (0.02, 0.04, 0.0)))
WIDE = dict(rShoulder=J((40, -12, 62), (0.08, 0.18, 0.0)), lShoulder=J((40, 12, -62), (-0.08, 0.18, 0.0)))

d = Motion("RoleDiavolo_self", LENGTH, note="Diavolo's role cutscene: at the window, the notebook, the laugh.")
d.key(0.0, root=(2, 0, 0), neck=(10, 0, 0), **BEHIND)
d.key(3.2, root=(2, 4, 0), neck=(8, -6, 0), **BEHIND)
d.key(3.8, root=(-2, -16, 0), neck=(-4, -10, 0), **DOWN)  # the body leads the turn
d.key(4.6, root=(-6, 0, 0), neck=(-12, 0, 0), **DOWN)
d.key(5.3, root=(-8, 0, 0), neck=(-20, 0, 0), **DOWN)
d.key(5.6, root=(-14, 0, 0), neck=(-28, 0, 0), rShoulder=J((46, 0, -4), (0, 0.06, -0.22)), lShoulder=J((6, 0, -2)))
d.key(7.0, root=(-15, 0, 0), neck=(-30, 2, 0), rShoulder=J((48, 0, -4), (0, 0.06, -0.22)), lShoulder=J((6, 0, -2)))
d.key(8.0, root=(0, 0, 0), neck=(-4, 0, 0), rShoulder=J((14, 0, 4)), lShoulder=J((8, 0, -4)))
d.key(9.2, "out", root=(4, 0, 0), neck=(12, 0, 0), **OPEN)  # the red flash: chin up, arms open
d.key(10.4, root=(4, 0, 0), neck=(10, 0, 0), **OPEN)
d.key(11.0, root=(-6, 0, 0), neck=(-14, 0, 0), **FACE)  # a hand over the face: it starts as a chuckle
for k in range(9):
    t = 11.2 + 0.24 * k
    d.key(t, "sine", root=(-4 + (3 if k % 2 else -1), 0, 0), neck=(-10 + (5 if k % 2 else 0), 0, 0), **FACE)
d.key(13.6, "out", root=(10, 0, 0), neck=(26, 0, 0), **WIDE)  # and breaks out: head back, arms wide
for k in range(5):
    t = 13.8 + 0.24 * k
    d.key(t, "sine", root=(10 + (3 if k % 2 else 0), 0, 0), neck=(26 + (4 if k % 2 else 0), 0, 0), **WIDE)
d.key(LENGTH, root=(11, 0, 0), neck=(28, 0, 0), **WIDE)
soft(d, head=2.6, arms=2.2).plant(None, 4.5, stance=0.06).plant(5.5, None, stance=0.06)
walking(d, 4.6, 5.3)
d.build()


def kneeler(k):
    """A Muerto kneeling before the desk, head bowed; at the red flash they bow lower."""
    m = Motion(f"RoleDiavolo_kneel{k}", LENGTH, note="Diavolo's role cutscene: a Muerto kneeling.")
    lag = 0.15 * k
    kneel(m, 0.0, head=-24, **PRAY)
    kneel(m, 4.0 + lag, head=-18, **PRAY)  # they look up as Diavolo turns
    kneel(m, 8.4 + lag, head=-20, **PRAY)
    kneel(m, 9.2 + lag, "out", lean=-34, head=-34, **PRAY)  # and bow down to the floor
    kneel(m, LENGTH, lean=-36, head=-36, **PRAY)
    return soft(m)


for k in range(len(KNEEL)):
    kneeler(k).build()

# The shot -------------------------------------------------------------------------------------------

shot = Shot(NAME, "Sets", LENGTH, note="Diavolo's role cutscene: the study, the Muertos, the Deathsinger.")

# A: from the door, behind the kneeling Muertos: the desk, and Diavolo's back dark against the rainy window.
shot.cam(0.0, (-1.0, 7.4, 9.0), (1.6, 4.6, -8.0), fov=46)
shot.cam(3.6, (-0.4, 6.8, 6.6), (2.0, 4.8, -8.0), fov=42, ease="linear")
# B: from the desk's east end: Diavolo turns from the window, comes to the desk, lays a hand on the notebook.
shot.cam(3.6, (7.6, 5.2, -1.2), (2.8, 4.4, -7.0), fov=44, cut=True)
shot.cam(7.2, (7.8, 5.0, -0.8), (3.0, 4.2, -6.0), fov=44, ease="linear")
# C: low from the front: the Deathsinger rises out of the dark behind them.
shot.cam(7.2, (0.2, 2.8, 3.0), (0.8, 6.4, -7.0), fov=50, cut=True)
shot.cam(10.6, (0.3, 2.6, 2.2), (0.8, 7.2, -7.0), fov=46, ease="linear")
# D: over Diavolo's shoulder, down on the kneeling Muertos.
shot.cam(10.6, (5.4, 7.8, -8.2), (-0.4, 1.0, 1.8), fov=46, cut=True)
shot.cam(13.0, (5.8, 8.6, -8.4), (-0.4, 1.0, 1.8), fov=44, ease="linear")
# E: Diavolo laughing, arms wide, the Deathsinger looming behind.
shot.cam(13.0, (5.6, 5.0, 0.4), (1.6, 5.6, -6.8), fov=48, cut=True)
shot.cam(LENGTH, (5.2, 5.0, -0.6), (1.6, 5.8, -6.8), fov=42, ease="in")

me = shot.actor("self", d)
me.mark(0.0, (WINDOW[0], 0.0, WINDOW[1]), 0.0)
me.mark(3.3, (WINDOW[0], 0.0, WINDOW[1]), 0.0)
me.mark(4.5, (WINDOW[0], 0.0, WINDOW[1]), -156.0)
me.mark(5.4, (DIAVOLO[0], 0.0, DIAVOLO[1]), -164.0)
me.mark(6.0, (DIAVOLO[0], 0.0, DIAVOLO[1]), -180.0)
me.mark(LENGTH, (DIAVOLO[0], 0.0, DIAVOLO[1]), -180.0)
for k, (x, z) in enumerate(KNEEL):
    a = shot.actor(f"ally:{k + 1}", clip=f"RoleDiavolo_kneel{k}")
    a.mark(0.0, (x, 0.0, z), facing((x, z), DIAVOLO))

book = shot.prop("Notebook")
book.at(0.0, (NOTEBOOK[0], TOP + 0.11, NOTEBOOK[1]), (0, 8, 0))
book.at(LENGTH, (NOTEBOOK[0], TOP + 0.11, NOTEBOOK[1]), (0, 8, 0))
singer = shot.prop("Specter", show=(7.2, None))
singer.at(7.2, (SINGER[0], -11.0, SINGER[1]), (0, 180, 0))
singer.at(7.6, (SINGER[0], -10.0, SINGER[1]), (0, 180, 0), "in")
singer.at(9.4, (SINGER[0], 0.4, SINGER[1]), (0, 180, 0), "out")
singer.at(LENGTH, (SINGER[0], 0.8, SINGER[1]), (0, 184, 0))

shot.event(0.0, "sfx", slot="mapRainGlass")
shot.event(2.0, "sfx", slot="thunder")
shot.event(7.4, "sfx", slot="wisp")
shot.event(9.2, "fx", name="flash", r=200, g=20, b=30, strength=0.35, dur=0.5)
shot.event(9.2, "sfx", slot="eyesOpen")
shot.event(11.0, "sfx", slot="hauntWhisper")
# The role card, as captions over the scene (the game fills them in).
shot.event(1.0, "card", key="role", dur=4.2)
shot.event(5.4, "card", key="win", dur=3.6)
shot.event(9.2, "card", key="move", dur=2.8)
shot.event(12.0, "card", key="names", dur=3.0)
