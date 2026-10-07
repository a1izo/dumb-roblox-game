"""The Muerto's role cutscene (the briefing, seen only by that Muerto): the shrine under the city. The
Muertos kneel on the stone between the rows of candles; on the altar steps, against the red glow of the
robed figure, stands Diavolo, a black shape at first. The candles flare and show their face; Diavolo
holds out a hand to the Muerto, who lifts their hands to it, then lays one on their heart and bows.

The shrine (maps/venues/sets/shrine.py, Sets scene space, origin x 120): the hall x 109..131,
z -16..14; three altar steps up from the north wall (tops at y 0.6, 1.2, 1.8; the top step's front edge
at z -8.5), the altar block at z -10.4, the figure behind it; two red cushions at (117.8 / 122.2, -4.5)
(0.5 high); candles on the floor at x 115.5 / 124.5."""

from animlib import J
from cinema.acting import PRAY, facing, kneel, soft
from cinema.shot import Shot
from motion import Motion

NAME = "RoleMuerto"
LENGTH = 15.0
OX = 120.0
STEP = 1.8  # the top step
DIAVOLO = (OX, -8.9)
SELF = (OX - 2.2, -4.5)
CUSHION = 0.5
OTHERS = [((OX + 2.2, -4.5), CUSHION), ((OX - 3.2, -1.2), 0.0), ((OX + 3.2, -1.2), 0.0)]

# Acting ---------------------------------------------------------------------------------------------

UP = dict(rShoulder=J((118, 0, -16), (-0.1, 0.22, -0.2)), lShoulder=J((118, 0, 16), (0.1, 0.22, -0.2)))
HEART = dict(rShoulder=J((44, 0, -58), (-0.36, 0.16, -0.22)), lShoulder=J((4, 0, -4)))

me = Motion("RoleMuerto_self", LENGTH, note="The Muerto's role cutscene: kneeling, the hand, the vow.")
kneel(me, 0.0, head=-26, **PRAY)
kneel(me, 4.8, head=-28, **PRAY)
kneel(me, 5.6, lean=-4, head=-2, **PRAY)  # looks up at the altar
kneel(me, 7.0, lean=-2, head=4, **PRAY)
kneel(me, 7.4, lean=0, head=8, **PRAY)  # the candles flare: a start
kneel(me, 8.4, lean=-2, head=6, **PRAY)
kneel(me, 9.4, "out", lean=2, head=10, **UP)  # lifts both hands to Diavolo's
kneel(me, 10.6, lean=2, head=12, **UP)
kneel(me, 11.4, lean=-10, head=-14, **HEART)
kneel(me, 12.2, lean=-24, head=-30, **HEART)  # a hand on the heart, a bow
kneel(me, 13.6, lean=-22, head=-28, **HEART)
kneel(me, LENGTH, lean=-8, head=2, **HEART)  # and looks up again
soft(me)
me.build()

BEHIND = dict(rShoulder=J((-16, 0, -8), (0.14, 0.04, 0.16)), lShoulder=J((-16, 0, 8), (-0.14, 0.04, 0.16)))
REACH = dict(rShoulder=J((66, 0, -12), (0, 0.1, -0.22)), lShoulder=J((-10, 0, 6), (-0.1, 0.02, 0.1)))
WELCOME = dict(rShoulder=J((26, -10, 26), (0.04, 0.1, -0.08)), lShoulder=J((26, 10, -26), (-0.04, 0.1, -0.08)))
turn = (facing(DIAVOLO, SELF) - 180.0 + 180.0) % 360.0 - 180.0  # towards the Muerto, from facing south

dv = Motion("RoleMuerto_diavolo", LENGTH, note="The Muerto's role cutscene: Diavolo on the altar steps.")
dv.key(0.0, root=(2, 0, 0), neck=(-6, 0, 0), **BEHIND)
dv.key(6.6, root=(2, 0, 0), neck=(-8, 0, 0), **BEHIND)
dv.key(7.6, root=(-2, turn * 0.3, 0), neck=(-20, turn * 0.5, 0), **BEHIND)  # looks down at the Muerto
dv.key(8.4, root=(-6, turn * 0.4, 0), neck=(-22, turn * 0.5, 0), **REACH)  # and holds out a hand
dv.key(10.6, root=(-6, turn * 0.4, 0), neck=(-24, turn * 0.5, 0), **REACH)
dv.key(11.6, root=(2, turn * 0.2, 0), neck=(-12, turn * 0.3, 0), **WELCOME)
dv.key(12.6, root=(3, 0, 0), neck=(-6, 0, 0), **WELCOME)
dv.key(13.2, root=(3, 0, 0), neck=(-16, 0, 0), **WELCOME)  # a nod
dv.key(LENGTH, root=(3, 0, 0), neck=(-4, 0, 0), **WELCOME)
soft(dv, head=2.6, arms=2.2).plant(stance=0.06)
dv.build()


def kneeler(k):
    m = Motion(f"RoleMuerto_kneel{k}", LENGTH, note="The Muerto's role cutscene: another Muerto kneeling.")
    lag = 0.2 * (k + 1)
    kneel(m, 0.0, head=-26, **PRAY)
    kneel(m, 5.4 + lag, head=-26, **PRAY)
    kneel(m, 6.2 + lag, lean=-4, head=-4, **PRAY)
    kneel(m, 11.2 + lag, lean=-4, head=-6, **PRAY)
    kneel(m, 12.2 + lag, lean=-24, head=-30, **PRAY)  # they bow with the Muerto
    kneel(m, LENGTH, lean=-22, head=-28, **PRAY)
    return soft(m)


for k in range(len(OTHERS)):
    kneeler(k).build()

# The shot -------------------------------------------------------------------------------------------

shot = Shot(NAME, "Sets", LENGTH, note="The Muerto's role cutscene: the shrine, Diavolo, the vow.")

# A: from the door end, high, down the nave: the kneeling backs, the candles, the black shape on the steps.
shot.cam(0.0, (OX, 9.4, 11.0), (OX, 3.0, -8.0), fov=44)
shot.cam(3.6, (OX, 8.2, 7.6), (OX, 3.2, -8.0), fov=42, ease="linear")
# B: low from the foot of the steps, the Muerto's face as they look up.
shot.cam(3.6, (OX - 7.8, 2.2, -8.8), (SELF[0], 2.0, SELF[1]), fov=48, cut=True)
shot.cam(7.0, (OX - 7.4, 2.2, -8.4), (SELF[0], 2.2, SELF[1]), fov=44, ease="linear")
# C: behind the Muerto, up at Diavolo: the flare, the hand held out.
shot.cam(7.0, (OX - 0.6, 3.6, -1.4), (OX, 5.6, DIAVOLO[1]), fov=42, cut=True)
shot.cam(10.8, (OX - 0.6, 3.4, -2.2), (OX - 0.3, 5.4, DIAVOLO[1]), fov=38, ease="linear")
# D: from the side of the steps, down on the Muerto's vow.
shot.cam(10.8, (OX - 6.4, 6.8, -9.6), (SELF[0], 1.6, SELF[1]), fov=48, cut=True)
shot.cam(13.2, (OX - 6.6, 6.4, -9.2), (SELF[0], 1.8, SELF[1]), fov=44, ease="linear")
# E: low behind the kneeling Muertos, up the steps to Diavolo and the figure.
shot.cam(13.2, (OX, 1.2, -0.2), (OX, 6.6, -12.0), fov=50, cut=True)
shot.cam(LENGTH, (OX, 1.0, 0.6), (OX, 7.0, -12.0), fov=48, ease="linear")

a = shot.actor("self", me)
a.mark(0.0, (SELF[0], CUSHION, SELF[1]), facing(SELF, DIAVOLO))
dva = shot.actor("diavolo", dv, silhouette=(0.0, 7.2))
dva.mark(0.0, (DIAVOLO[0], STEP, DIAVOLO[1]), 180.0)
for k, ((x, z), y) in enumerate(OTHERS):
    o = shot.actor(f"ally:{k + 1}", clip=f"RoleMuerto_kneel{k}")
    o.mark(0.0, (x, y, z), facing((x, z), DIAVOLO))

shot.event(0.0, "sfx", slot="hauntWhisper")
shot.event(5.6, "sfx", slot="heartbeat")
shot.event(7.2, "fx", name="flash", r=255, g=150, b=80, strength=0.25, dur=0.5)
shot.event(7.2, "sfx", slot="wisp")
shot.event(12.2, "sfx", slot="bell")
shot.event(1.0, "card", key="role", dur=4.2)
shot.event(5.4, "card", key="win", dur=3.6)
shot.event(9.2, "card", key="move", dur=2.8)
shot.event(12.0, "card", key="names", dur=3.0)
