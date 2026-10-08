"""The Muerto's role cutscene (the briefing, seen only by that Muerto), 15 s, four shots: summoned.

A  0.0-4.8   A back alley in the rain under a sodium lamp. The Muerto's phone buzzes; the screen glows red; they
             read it ("COME."), put it away and walk to the stair going down beside the lamp.
B  4.8-7.4   From inside the shrine's open doors, up the stairs: the Muerto comes down between the candles,
             the alley's light behind them.
C  7.4-11.4  Low in the nave, towards the altar: the Muerto walks up between the kneeling Muertos, who all turn
             their heads to them at once, eyes red. On the steps Diavolo's black shape raises a hand: come.
D  11.4-15.0 Over Diavolo's shoulder, down the nave: the doors slam shut behind the Muerto; they flinch, look
             back, then turn and come on.

The shrine (maps/venues/sets/shrine.py, Sets scene space, origin x 120): the hall x 109..131, z -16..14, with
the doorway in the south wall (x 116.8..123.2); the stair climbs south from it (z 14.5..24.7, up to y 6) to a
landing and the alley (y 6, z 28..48, x 110..130; its entrance at x 116.8..123.2 in the wall at z 28). Kneeling
pairs at x 116.2 / 123.8; Diavolo on the middle altar step at (120, 1.2, -7.4)."""

import math

from animlib import J
from cinema.acting import PRAY, alive, beat, facing, hold, kneel, soft, walking
from cinema.shot import Shot
from motion import Motion

NAME = "RoleMuerto"
LENGTH = 15.0
OX = 120.0
ALLEY_Y = 6.0
SPEED = 3.2
SLOPE = math.hypot(10.2, 6.0) / 10.2  # path length per stud of stair run
START = (OX + 1.0, 33.0)
LANDING = (OX + 0.1, 27.3)
STAIR_TOP = (OX, 24.7)
INSIDE = (OX, 13.4)  # just inside the doors (after the cut)
STOP = (OX, 0.6)
ON = (OX, -2.0)  # two steps further, at the end
DIAVOLO = (OX, 1.2, -7.4)
OTHERS = [(OX - 3.8, 1.4), (OX + 3.8, 1.4), (OX - 3.8, 6.6), (OX + 3.8, 6.6)]


def walk_time(a, b, slope=1.0):
    return math.hypot(b[0] - a[0], b[1] - a[1]) * slope / SPEED


T_LANDING = 3.0 + walk_time(START, LANDING)
T_TOP = T_LANDING + walk_time(LANDING, STAIR_TOP)
T_CUT = 7.4
T_STOP = T_CUT + walk_time(INSIDE, STOP)
T_ON = (13.6, 13.6 + walk_time(STOP, ON))

# The Muerto ------------------------------------------------------------------------------------------

ARMS = dict(rShoulder=J((4, 0, -2), (-0.06, 0, 0)), lShoulder=J((4, 0, 2), (0.06, 0, 0)))
PHONE = dict(rShoulder=J((104, 0, -20), (-0.12, 0.2, -0.3)))

me = Motion("RoleMuerto_self", LENGTH, note="The Muerto's role cutscene: the summons, the stair, the doors.")
me.key(0.0, root=(-2, 0, 0), neck=(-4, 0, 0), **ARMS)
beat(me, 0.9, 0.5, antic=0.1, neck=(-26, 0, 0), **PHONE)  # the phone up to read
hold(me, 2.4)
beat(me, 2.8, 0.4, neck=(4, 0, 0))  # looks up: resolve
beat(me, 3.1, 0.4, **ARMS)  # the phone away
hold(me, T_STOP)
beat(me, T_STOP + 0.4, 0.4, root=(-2, 0, 0), neck=(6, 0, 0))  # stops, looks up at the altar
beat(me, 11.75, 0.2, antic=0.0, over=0.3, root=(6, 0, 0), neck=(10, 0, 0),  # the slam: a flinch
     rShoulder=J((24, 0, -14), (-0.1, 0.06, -0.1)), lShoulder=J((24, 0, 14), (0.1, 0.06, -0.1)))
beat(me, 12.6, 0.6, root=(-2, 34, 0), neck=(0, 62, 0))  # a look back over the shoulder at the doors
hold(me, 13.0)
beat(me, 13.5, 0.5, root=(-4, 0, 0), neck=(-2, 0, 0), **ARMS)  # and turns to the altar again
me.key(LENGTH, root=(-4, 0, 0), neck=(-4, 0, 0))
soft(me, head=2.6, arms=2.4)
for t0, t1 in ((None, 2.95), (T_STOP + 0.1, T_ON[0] - 0.05), (T_ON[1] + 0.1, None)):
    me.plant(t0, t1, stance=0.05)
walking(me, 3.0, T_CUT - 0.02, speed=SPEED)
walking(me, T_CUT, T_STOP, speed=SPEED)
walking(me, *T_ON, speed=SPEED)
alive(me, 0.7, seed=2)
me.build()

# Diavolo, a black shape on the altar steps -----------------------------------------------------------

HANG = dict(rShoulder=J((4, 0, 2)), lShoulder=J((4, 0, -2)))
OUT = dict(rShoulder=J((86, 0, -6), (0, 0.12, -0.3)))
CURL = dict(rShoulder=J((104, 0, -6), (0, 0.24, -0.1)))

dv = Motion("RoleMuerto_diavolo", LENGTH, note="The Muerto's role cutscene: Diavolo beckons from the altar.")
dv.key(0.0, root=(4, 0, 0), neck=(-6, 0, 0), **HANG)
hold(dv, 9.6)
beat(dv, 10.2, 0.6, antic=0.15, **OUT)  # the hand comes out...
for k, t in enumerate((10.6, 11.0, 13.6, 14.0)):  # ...and draws them in
    beat(dv, t, 0.2, antic=0.0, **(CURL if k % 2 == 0 else OUT))
soft(dv, head=2.4, arms=2.4).plant(stance=0.06)
alive(dv, 0.5, seed=4)
dv.build()

# The other Muertos -----------------------------------------------------------------------------------


def kneeler(k, x):
    """Kneeling, head bowed; at 8.8 every head turns to the aisle at once, then follows the Muerto past."""
    m = Motion(f"RoleMuerto_kneel{k}", LENGTH, note="The Muerto's role cutscene: the heads that turn.")
    side = 1 if x < OX else -1  # turn right (-) from the west side, left (+) from the east
    kneel(m, 0.0, lean=-14, head=-30, **PRAY)
    kneel(m, 8.6, lean=-14, head=-30, **PRAY)
    kneel(m, 8.8, "snap", lean=-8, head=-4, turn=-side * 22, neck=(-4, -side * 66, 0), **PRAY)
    back = 1.0 if k < 2 else 0.0  # the front pair turns further as the Muerto passes them
    kneel(m, 10.6, lean=-8, head=-4, turn=-side * (22 - 44 * back), neck=(-4, -side * (66 - 132 * back), 0), **PRAY)
    kneel(m, LENGTH, lean=-8, head=-4, turn=-side * (22 - 44 * back), neck=(-4, -side * (66 - 132 * back), 0), **PRAY)
    soft(m, head=4.0, arms=2.4)
    return m


for k, (x, z) in enumerate(OTHERS):
    kneeler(k, x).build()

# The shot --------------------------------------------------------------------------------------------

shot = Shot(NAME, "Sets", LENGTH, note="The Muerto's role cutscene: summoned.")
shot.room = (109.0, -16.0, 131.0, 48.0, 32.0)

a = shot.actor("self", me)
a.mark(0.0, (START[0], ALLEY_Y, START[1]), facing(START, LANDING))
a.mark(3.0, (START[0], ALLEY_Y, START[1]), facing(START, LANDING), "linear")
a.mark(T_LANDING, (LANDING[0], ALLEY_Y, LANDING[1]), facing(START, LANDING), "linear")
a.mark(T_TOP, (STAIR_TOP[0], ALLEY_Y, STAIR_TOP[1]), 0.0, "linear")
run = (T_CUT - T_TOP) * SPEED / SLOPE  # how far down the stair they get before the cut
a.mark(T_CUT - 0.02, (OX, ALLEY_Y - run * 6.0 / 10.2, STAIR_TOP[1] - run), 0.0, "linear")
a.mark(T_CUT, (INSIDE[0], 0.0, INSIDE[1]), 0.0, "linear")
a.mark(T_STOP, (STOP[0], 0.0, STOP[1]), 0.0, "linear")
a.mark(T_ON[0], (STOP[0], 0.0, STOP[1]), 0.0, "linear")
a.mark(T_ON[1], (ON[0], 0.0, ON[1]), 0.0, "linear")
a.mark(LENGTH, (ON[0], 0.0, ON[1]), 0.0)
a.hold("Smartphone", "Right Arm", (0.0, -1.05, -0.2), (-14, 0, 0), t0=0.4, t1=3.2)

d = shot.actor("diavolo", dv, silhouette=(0.0, LENGTH))
d.mark(0.0, DIAVOLO, 180.0)

for k, (x, z) in enumerate(OTHERS):
    o = shot.actor(f"ally:{k + 1}", clip=f"RoleMuerto_kneel{k}")
    o.mark(0.0, (x, 0.0, z), 0.0)


def door(hinge, side, close=(11.55, 11.85)):
    """One leaf of the double door, standing open into the shrine, slammed shut at `close`."""
    leaf = shot.prop("ShrineDoor")
    hx, hz = hinge
    keys = [(0.0, 90.0), (close[0], 90.0)]
    keys += [(close[0] + (close[1] - close[0]) * u, 90.0 * (1 - u) ** 0.6) for u in (0.25, 0.5, 0.75, 1.0)]
    keys.append((LENGTH, 0.0))
    for t, phi in keys:
        ang = math.radians(phi)
        cx = hx + side * 1.6 * math.cos(ang)
        cz = hz - 1.6 * math.sin(ang)
        yaw = phi if side > 0 else 180.0 - phi
        leaf.at(t, (cx, 0.0, cz), (0, yaw, 0), "in" if t > close[0] else "smooth")


door((OX - 3.2, 13.2), 1)
door((OX + 3.2, 13.2), -1)

# A: the alley, from its west side: the Muerto reads, then goes to the way down under the lamp.
shot.pan(0.0, 4.8, "self", (OX - 4.4, ALLEY_Y + 3.4, 31.4), aim="Head", dy=-0.2, fov=40, drift=(0.0, 0.3, -0.4))
# B: from inside the doors, up the stair.
shot.pan(4.8, T_CUT, "self", (OX + 1.2, 2.2, 12.8), aim="Torso", dy=0.6, fov=44, cut=True)
# C: low in the nave, the heads turning.
shot.pan(T_CUT, 11.4, "self", (OX + 1.0, 2.4, -3.6), aim="Head", dy=-0.4, fov=50, cut=True, drift=(0.0, 0.0, -0.4))
# D: over Diavolo's shoulder: the doors slam, the look back, the walk on.
shot.pan(11.4, LENGTH, "self", (OX + 3.6, 5.4, -9.0), aim="Torso", dy=0.6, fov=44, cut=True, drift=(-0.3, 0.0, 0.3))

# Faces
shot.face(0.0, "self", "Stern")
shot.face(1.0, "self", "Shock")
shot.face(2.6, "self", "Stern")
shot.face(11.7, "self", "Fear")
shot.face(13.4, "self", "Stern")
shot.face(14.4, "self", "Devoted")
for k in range(len(OTHERS)):
    shot.face(8.8, f"ally:{k + 1}", "Devoted")

shot.event(0.0, "sfx", slot="rainLoop")
shot.event(0.5, "sfx", slot="mapPhoneRing")
shot.event(1.0, "subtitle", text="COME.", dur=1.6)
shot.event(5.0, "sfx", slot="hauntWhisper")
shot.event(8.8, "sfx", slot="wisp")
shot.event(11.82, "sfx", slot="slam")
shot.event(11.82, "fx", name="shake", strength=0.45, dur=0.3)
shot.event(14.4, "sfx", slot="heartbeat")
shot.event(0.8, "card", key="role", dur=3.6)
shot.event(5.0, "card", key="win", dur=2.3)
shot.event(7.8, "card", key="move", dur=3.4)
shot.event(12.0, "card", key="names", dur=2.9)
