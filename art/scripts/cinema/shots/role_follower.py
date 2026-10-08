"""The Muerto's role cutscene (the briefing, seen only by that Muerto), 15 s, four shots.

A  0.0-4.8   Low from the foot of the altar steps, down the nave: the Muerto walks slowly up between the
             other Muertos, kneeling in pairs, towards the camera.
B  4.8-8.8   Low behind the Muerto, up the steps: they sink to their knees; on the steps Diavolo, a black
             shape against the red glow of the robed figure, looks round and turns; the candles flare.
C  8.8-12.4  From the side: Diavolo comes down the steps, leans over the kneeling Muerto and lays a hand on
             their head; the Muerto looks up.
D  12.4-15.0 High from beside the figure: Diavolo opens their arms; every Muerto bows to the floor.

The shrine (maps/venues/sets/shrine.py, Sets scene space, origin x 120): the hall x 109..131, z -16..14,
20 high; three altar steps up from the north wall (tops 0.6, 1.2, 1.8; front edges at z -6.5, -7.5,
-8.5); the altar block at z -11.6..-9.2 (x 117..123); the robed figure behind it; candles on the floor at
x 114.0 / 126.0, z -5.2, -1.6, 9.6; pillars at x 111.4 / 128.6, z -8, -1, 6."""

from animlib import J
from cinema.acting import PRAY, beat, facing, hold, kneel, soft, walking
from cinema.shot import Shot
from motion import Motion

NAME = "RoleMuerto"
LENGTH = 15.0
OX = 120.0
DOOR = (OX, 10.0)
KNEEL_AT = (OX, -2.6)
STEP = (OX, 1.2, -7.4)  # Diavolo at the front of the middle step, clear of the altar
OVER = (OX, -4.9)  # Diavolo come down, standing over the Muerto
OTHERS = [(OX - 3.8, 1.6), (OX + 3.8, 1.6), (OX - 3.8, 6.2), (OX + 3.8, 6.2)]  # pairs the Muerto walks up between
SPEED = 2.8
WALK = (0.2, 0.2 + (DOOR[1] - KNEEL_AT[1]) / SPEED)
DOWN = (8.9, 10.1)  # Diavolo's steps down

# The Muerto ------------------------------------------------------------------------------------------

ARMS = dict(rShoulder=J((4, 0, -2)), lShoulder=J((4, 0, 2)))

me = Motion("RoleMuerto_self", LENGTH, note="The Muerto's role cutscene: the walk, the kneel, the hand.")
me.key(0.0, root=(-5, 0, 0), neck=(-12, 0, 0), **ARMS)  # walking up the nave, eyes low
me.key(WALK[1], root=(-5, 0, 0), neck=(-8, 0, 0), **ARMS)
beat(me, WALK[1] + 0.5, 0.5, neck=(10, 0, 0))  # stops; looks up at the steps
me.key(5.2, offset=(0, 0, 0), rHip=(0, 0, 0), lHip=(0, 0, 0))  # still standing...
kneel(me, 6.0, "out", lean=-8, head=-2, **PRAY)  # ...then sinks to the knees
kneel(me, 6.8, lean=-14, head=-30, **PRAY)  # and bows the head
kneel(me, 7.5, lean=-14, head=-30, **PRAY)
kneel(me, 7.9, "out", lean=-6, head=-6, **PRAY)  # the flare: eyes come up
kneel(me, 9.2, lean=-6, head=-8, **PRAY)
kneel(me, 9.9, lean=-16, head=-32, **PRAY)  # bows as Diavolo comes down
kneel(me, 10.8, lean=-16, head=-32, **PRAY)
kneel(me, 11.1, lean=-18, head=-38, **PRAY)  # the hand presses the head down...
kneel(me, 11.9, "out", lean=-2, head=20, **PRAY)  # ...and they look up into Diavolo's face
kneel(me, 13.0, lean=-2, head=22, **PRAY)
kneel(me, 13.8, "out", lean=-44, head=-40, **PRAY)  # and down to the floor
kneel(me, LENGTH, lean=-45, head=-40, **PRAY)
soft(me, head=2.6, arms=2.2).plant(None, WALK[0] - 0.05, stance=0.05).plant(WALK[1] + 0.1, 5.15, stance=0.05)
walking(me, WALK[0], WALK[1], speed=SPEED)
me.build()

# Diavolo ---------------------------------------------------------------------------------------------

FOLD = dict(rShoulder=J((40, 0, -38), (-0.3, 0.1, -0.22)), lShoulder=J((38, 0, 36), (0.3, 0.1, -0.22)))
HANG = dict(rShoulder=J((4, 0, 2)), lShoulder=J((4, 0, -2)))
REACH = dict(rShoulder=J((70, 0, -4), (0, 0.1, -0.3)))
OPEN = dict(rShoulder=J((32, -12, 62), (0.1, 0.14, -0.06)), lShoulder=J((32, 12, -62), (-0.1, 0.14, -0.06)))

dv = Motion("RoleMuerto_diavolo", LENGTH, note="The Muerto's role cutscene: Diavolo at the altar.")
dv.key(0.0, root=(3, 0, 0), neck=(14, 0, 0), **FOLD)  # facing the figure, arms folded, head up
dv.key(5.8, root=(3, 0, 0), neck=(14, 0, 2), **FOLD)
beat(dv, 6.4, 0.6, antic=0.08, neck=(-4, -58, 0))  # looks back over the shoulder...
beat(dv, 7.3, 0.8, root=(-3, -26, 0), neck=(-8, -20, 0))  # ...and turns
beat(dv, 7.9, 0.5, root=(-6, 0, 0), neck=(-18, 0, 0))  # looking down at the Muerto
beat(dv, 8.8, 0.5, **HANG)
hold(dv, DOWN[1])
beat(dv, 10.9, 0.7, antic=0.15, root=(-24, 0, 0), neck=(-30, 0, 0), **REACH)  # leans over, a hand on the head
hold(dv, 11.9)
beat(dv, 12.6, 0.6, root=(-2, 0, 0), neck=(-12, 0, 0), **HANG)  # straightens
beat(dv, 13.5, 0.7, antic=0.3, root=(6, 0, 0), neck=(16, 0, 0), **OPEN)  # and opens the arms
dv.key(LENGTH, root=(7, 0, 0), neck=(18, 0, 0))
soft(dv, head=2.4, arms=2.0).plant(None, DOWN[0] - 0.05, stance=0.06).plant(DOWN[1] + 0.1, None, stance=0.06)
walking(dv, DOWN[0], DOWN[1], speed=2.4)
dv.build()


def kneeler(k):
    m = Motion(f"RoleMuerto_kneel{k}", LENGTH, note="The Muerto's role cutscene: another Muerto kneeling.")
    lag = 0.15 * (k + 1)
    kneel(m, 0.0, lean=-12, head=-28, **PRAY)
    kneel(m, 7.6 + lag, lean=-12, head=-26, **PRAY)
    kneel(m, 8.3 + lag, "out", lean=-28, head=-34, **PRAY)  # they bow lower as Diavolo turns
    kneel(m, 13.3 + lag, lean=-28, head=-34, **PRAY)
    kneel(m, 14.0 + lag, "out", lean=-46, head=-40, **PRAY)
    kneel(m, LENGTH, lean=-46, head=-40, **PRAY)
    return soft(m)


for k in range(len(OTHERS)):
    kneeler(k).build()

# The shot --------------------------------------------------------------------------------------------

shot = Shot(NAME, "Sets", LENGTH, note="The Muerto's role cutscene: the shrine, Diavolo, the vow.")
shot.room = (109.0, -16.0, 131.0, 14.0, 20.0)
shot.allow = {"diavolo": ["self"]}  # the hand on the head

a = shot.actor("self", me)
a.mark(0.0, (DOOR[0], 0.0, DOOR[1]), 0.0)
a.mark(WALK[0], (DOOR[0], 0.0, DOOR[1]), 0.0, "linear")
a.mark(WALK[1], (KNEEL_AT[0], 0.0, KNEEL_AT[1]), 0.0, "linear")
a.mark(LENGTH, (KNEEL_AT[0], 0.0, KNEEL_AT[1]), 0.0)

d = shot.actor("diavolo", dv, silhouette=(0.0, 7.6))
d.mark(0.0, STEP, 0.0)
d.mark(6.6, STEP, 0.0)
d.mark(7.6, STEP, -180.0)
d.mark(DOWN[0], STEP, -180.0, "linear")
d.mark(DOWN[0] + 0.45, (OX, 0.6, -6.7), -180.0, "linear")
d.mark(DOWN[1], (OVER[0], 0.0, OVER[1]), -180.0, "linear")
d.mark(LENGTH, (OVER[0], 0.0, OVER[1]), -180.0)

for k, (x, z) in enumerate(OTHERS):
    o = shot.actor(f"ally:{k + 1}", clip=f"RoleMuerto_kneel{k}")
    o.mark(0.0, (x, 0.0, z), 0.0)  # facing the altar, legs back down the nave

# A: low from the foot of the steps, down the nave, rising as the Muerto comes.
shot.pan(0.0, 4.8, "self", (OX + 3.2, 2.4, -5.6), aim="Torso", dy=1.0, fov=46, drift=(0.0, 1.2, 0.0))
# B: low behind the Muerto, up the steps to Diavolo.
shot.cam(4.8, (OX - 1.4, 3.8, 2.8), (OX, 4.0, -7.4), fov=42, cut=True)
shot.cam(8.8, (OX - 1.3, 3.6, 2.0), (OX, 4.4, -7.4), fov=40, ease="linear")
# C: from the west side (Diavolo's right, the reaching hand), both: the descent, the hand, the look up.
shot.pan(8.8, 12.4, "diavolo", (OX - 4.6, 3.4, -3.4), aim="Torso", dy=-0.4, fov=50, cut=True, drift=(0.2, 0.0, 0.2))
# D: high from beside the figure, down on them all.
shot.cam(12.4, (OX + 5.4, 10.0, -12.6), (OX, 1.0, -2.6), fov=52, cut=True)
shot.cam(LENGTH, (OX + 5.0, 10.8, -12.8), (OX, 0.8, -2.6), fov=50, ease="linear")

shot.event(0.0, "sfx", slot="hauntWhisper")
shot.event(5.6, "sfx", slot="heartbeat")
shot.event(7.6, "fx", name="flash", r=255, g=150, b=80, strength=0.3, dur=0.5)
shot.event(7.6, "sfx", slot="wisp")
shot.event(10.9, "sfx", slot="heartbeat")
shot.event(13.6, "sfx", slot="bell")
shot.event(0.8, "card", key="role", dur=3.8)
shot.event(5.2, "card", key="win", dur=3.4)
shot.event(9.2, "card", key="move", dur=3.0)
shot.event(12.6, "card", key="names", dur=2.4)
