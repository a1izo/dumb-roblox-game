"""The Muerto's role cutscene (the briefing, seen only by that Muerto), 15 s.

1  0.0-3.6   Low from the altar steps down the nave: the Muerto walks up between the rows of candles, the
             other Muertos kneeling at the sides.
2  3.6-6.0   From the side: the Muerto goes down on their knees before the steps, hands together, head bowed.
3  6.0-8.6   Low over the Muerto's shoulder, up the steps: Diavolo, a black shape against the red glow of
             the robed figure, turns round. The candles flare and show their face.
4  8.6-11.0  From the side: Diavolo comes down the steps and stands over the kneeling Muerto.
5  11.0-13.0 Close and low on the Muerto: Diavolo's hand comes down on their head; they look up.
6  13.0-15.0 High from beside the figure: everyone bows; Diavolo opens their arms.

The shrine (maps/venues/sets/shrine.py, Sets scene space, origin x 120): the hall x 109..131, z -16..14,
20 high; three altar steps up from the north wall (tops 0.6, 1.2, 1.8; front edges at z -6.5, -7.5,
-8.5), the altar block at z -10.4 (x 117..123), the robed figure behind it (x 116..124, 12 high); candles on
the floor at x 115.5 / 124.5, z -6, -1, 4, 9; pillars at x 111.4 / 128.6, z -8, -1, 6."""

from animlib import J
from cinema.acting import PRAY, beat, facing, hold, kneel, soft, walking
from cinema.shot import Shot
from motion import Motion

NAME = "RoleMuerto"
LENGTH = 15.0
OX = 120.0
DOOR = (OX, 9.0)
KNEEL_AT = (OX, -3.4)
ALTAR = (OX, -9.0)  # Diavolo, on the top step
BELOW = (OX, -5.4)  # Diavolo, come down to the floor
OTHERS = [(OX - 6.8, -3.0), (OX + 6.8, -3.0), (OX - 6.8, 2.4), (OX + 6.8, 2.4)]
ARRIVE = 0.3 + (DOOR[1] - KNEEL_AT[1]) / 4.0  # the walk's own speed

# The Muerto ------------------------------------------------------------------------------------------

WALK = dict(rShoulder=J((4, 0, -2)), lShoulder=J((4, 0, 2)))
UP = dict(rShoulder=J((96, 0, -18), (-0.12, 0.18, -0.24)), lShoulder=J((96, 0, 18), (0.12, 0.18, -0.24)))

me = Motion("RoleMuerto_self", LENGTH, note="The Muerto's role cutscene: the walk, the kneel, the hand.")
me.key(0.0, root=(-6, 0, 0), neck=(-14, 0, 0), **WALK)  # head down, walking up the nave
me.key(ARRIVE, root=(-6, 0, 0), neck=(-10, 0, 0), **WALK)
beat(me, ARRIVE + 0.5, 0.45, neck=(8, 0, 0))  # a look up at the altar
hold(me, ARRIVE + 0.9)
me.key(ARRIVE + 0.9, offset=(0, 0, 0), rHip=(0, 0, 0), lHip=(0, 0, 0))  # still standing...
kneel(me, ARRIVE + 1.6, "out", lean=-8, head=-6, **PRAY)  # ...then down on the knees
kneel(me, ARRIVE + 2.4, lean=-14, head=-32, **PRAY)  # and bows the head
kneel(me, 7.4, lean=-14, head=-30, **PRAY)
kneel(me, 7.9, "out", lean=-6, head=-8, **PRAY)  # the flare: eyes come up
kneel(me, 10.6, lean=-8, head=-12, **PRAY)
kneel(me, 11.2, lean=-18, head=-30, **PRAY)  # the hand on the head pushes it down...
kneel(me, 12.0, "out", lean=-2, head=22, **UP)  # ...and they look up, hands reaching
kneel(me, 13.0, lean=-2, head=24, **UP)
kneel(me, 13.7, "out", lean=-40, head=-38, **PRAY)  # and down to the floor
kneel(me, LENGTH, lean=-42, head=-40, **PRAY)
soft(me, head=2.8, arms=2.4).plant(None, 0.3, stance=0.05).plant(ARRIVE + 0.1, ARRIVE + 0.85, stance=0.05)
walking(me, 0.3, ARRIVE)
me.build()

# Diavolo ---------------------------------------------------------------------------------------------

BEHIND = dict(rShoulder=J((-20, 0, -10), (0.16, 0.05, 0.18)), lShoulder=J((-20, 0, 10), (-0.16, 0.05, 0.18)))
REACH = dict(rShoulder=J((62, 0, -6), (0, 0.08, -0.28)))
OPEN = dict(rShoulder=J((30, -12, 60), (0.1, 0.14, -0.06)), lShoulder=J((30, 12, -60), (-0.1, 0.14, -0.06)))

dv = Motion("RoleMuerto_diavolo", LENGTH, note="The Muerto's role cutscene: Diavolo at the altar.")
dv.key(0.0, root=(4, 0, 0), neck=(14, 0, 0), **BEHIND)  # facing the figure, head up
dv.key(6.0, root=(4, 0, 0), neck=(14, 0, 2), **BEHIND)
beat(dv, 6.6, 0.45, neck=(-4, -50, 0))  # looks back over the shoulder...
beat(dv, 7.4, 0.5, root=(-4, -30, 0), neck=(-10, -10, 0))  # ...and turns
beat(dv, 7.9, 0.35, root=(-6, 0, 0), neck=(-18, 0, 0), rShoulder=J((6, 0, 4)), lShoulder=J((6, 0, -4)))
hold(dv, 10.6)
beat(dv, 11.2, 0.5, antic=0.2, root=(-16, 0, 0), neck=(-30, 0, 0), **REACH)  # the hand on the head
hold(dv, 12.6)
beat(dv, 13.6, 0.6, antic=0.3, root=(6, 0, 0), neck=(16, 0, 0), **OPEN)  # straightens, arms open
dv.key(LENGTH, root=(7, 0, 0), neck=(18, 0, 0))
soft(dv, head=2.6, arms=2.2).plant(None, 8.5, stance=0.06).plant(9.7, None, stance=0.06)
walking(dv, 8.6, 9.5)
dv.build()


def kneeler(k):
    m = Motion(f"RoleMuerto_kneel{k}", LENGTH, note="The Muerto's role cutscene: another Muerto kneeling.")
    lag = 0.15 * (k + 1)
    kneel(m, 0.0, lean=-12, head=-28, **PRAY)
    kneel(m, 7.6 + lag, lean=-12, head=-26, **PRAY)
    kneel(m, 8.2 + lag, "out", lean=-30, head=-36, **PRAY)  # they bow lower as Diavolo turns
    kneel(m, 13.4 + lag, lean=-30, head=-34, **PRAY)
    kneel(m, 14.0 + lag, "out", lean=-46, head=-40, **PRAY)
    kneel(m, LENGTH, lean=-46, head=-40, **PRAY)
    return soft(m)


for k in range(len(OTHERS)):
    kneeler(k).build()

# The shot --------------------------------------------------------------------------------------------

shot = Shot(NAME, "Sets", LENGTH, note="The Muerto's role cutscene: the shrine, Diavolo, the vow.")
shot.room = (109.0, -16.0, 131.0, 14.0, 20.0)

a = shot.actor("self", me)
a.mark(0.0, (DOOR[0], 0.0, DOOR[1]), 0.0)
a.mark(0.3, (DOOR[0], 0.0, DOOR[1]), 0.0, "linear")
a.mark(ARRIVE, (KNEEL_AT[0], 0.0, KNEEL_AT[1]), 0.0, "linear")
a.mark(LENGTH, (KNEEL_AT[0], 0.0, KNEEL_AT[1]), 0.0)

d = shot.actor("diavolo", dv, silhouette=(0.0, 7.8))
d.mark(0.0, (ALTAR[0], 1.8, ALTAR[1]), 0.0)
d.mark(6.6, (ALTAR[0], 1.8, ALTAR[1]), 0.0)
d.mark(7.6, (ALTAR[0], 1.8, ALTAR[1]), 180.0)
d.mark(8.6, (ALTAR[0], 1.8, ALTAR[1]), 180.0, "linear")
d.mark(9.0, (ALTAR[0], 1.2, ALTAR[1] + 1.4), 180.0, "linear")
d.mark(9.5, (BELOW[0], 0.0, BELOW[1]), 180.0, "linear")
d.mark(LENGTH, (BELOW[0], 0.0, BELOW[1]), 180.0)

for k, (x, z) in enumerate(OTHERS):
    o = shot.actor(f"ally:{k + 1}", clip=f"RoleMuerto_kneel{k}")
    o.mark(0.0, (x, 0.0, z), facing((x, z), (OX, -9.0)))

# 1: low from the foot of the steps, down the nave; the camera turns to keep the Muerto in frame.
shot.pan(0.0, 3.6, "self", (OX + 1.8, 2.6, -8.0), aim="Torso", dy=1.0, fov=44, drift=(0.0, 1.2, -0.2))
# 2: from in front, beside the steps, as they go down on their knees.
shot.pan(3.6, 6.0, "self", (OX + 3.6, 2.8, -5.6), aim="Torso", dy=0.6, fov=42, cut=True, drift=(-0.2, 0.0, 0.2))
# 3: low over the Muerto's shoulder, up the steps at Diavolo turning round.
shot.pan(6.0, 8.6, "diavolo", (OX - 2.6, 2.4, -0.2), aim="Head", dy=-0.6, fov=40, cut=True, drift=(0.0, 0.0, -0.8))
# 4: from the west side, both of them, as Diavolo comes down.
shot.pan(8.6, 11.0, "diavolo", (OX - 5.8, 3.4, -6.2), aim="Torso", dy=0.2, fov=46, cut=True, drift=(0.3, 0.0, 0.2))
# 5: both in profile from the side: the hand comes down on the Muerto's head; they look up.
shot.frame(11.0, "self", "two", other="diavolo", height=0.3, dist=0.7, cut=True)
shot.frame(13.0, "self", "two", other="diavolo", height=0.1, dist=0.62, ease="linear")
# 6: high from beside the figure, down on them all.
shot.cam(13.0, (OX + 5.4, 11.0, -12.0), (OX, 1.2, -3.0), fov=52, cut=True)
shot.cam(LENGTH, (OX + 5.0, 11.8, -12.4), (OX, 1.0, -3.0), fov=50, ease="linear")

shot.event(0.0, "sfx", slot="hauntWhisper")
shot.event(4.6, "sfx", slot="heartbeat")
shot.event(7.8, "fx", name="flash", r=255, g=150, b=80, strength=0.3, dur=0.5)
shot.event(7.8, "sfx", slot="wisp")
shot.event(11.2, "sfx", slot="heartbeat")
shot.event(13.7, "sfx", slot="bell")
shot.event(1.0, "card", key="role", dur=4.2)
shot.event(5.6, "card", key="win", dur=3.4)
shot.event(9.2, "card", key="move", dur=2.8)
shot.event(12.2, "card", key="names", dur=2.8)
