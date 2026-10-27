"""The Operative's role cutscene (the briefing, seen only by that Operative): the Bureau's locker room, alone,
before the night's work. At an open locker they take out their badge, look at it, turn and hold it up
open (the camera close on it), put it away, straighten their tie and walk out between the benches.

The locker room (maps/venues/sets/locker.py, Sets scene space, origin x 360): x 349..371, z -7..7; a row
of 13 lockers along the north wall (fronts at z -4.9; the eighth's middle at x 361.5), more along the
south wall either side of the door (x 359.5..363.5); benches at (357.5, 0) and (365.5, 0), the gap
between them at x 360.4..362.6."""

from animlib import J
from cinema.acting import alive, beat, soft, walking
from cinema.shot import Shot
from motion import Motion

NAME = "RoleOperative"
LENGTH = 15.0
LX = 360.0
LOCKER = (LX + 1.5, -3.6)
OUT = (LX + 1.5, 6.2)

# Acting ---------------------------------------------------------------------------------------------

INSIDE = dict(rShoulder=J((66, 0, -4), (0, 0.08, -0.3)), lShoulder=J((60, 0, 4), (0, 0.06, -0.26)))
LOOK = dict(rShoulder=J((56, 0, -26), (-0.2, 0.1, -0.26)), lShoulder=J((50, 0, 22), (0.2, 0.1, -0.24)))
SHOW = dict(rShoulder=J((84, 0, -14), (-0.08, 0.18, -0.3)), lShoulder=J((6, 0, -4)))
POCKET = dict(rShoulder=J((40, 0, -54), (-0.34, 0.14, -0.16)), lShoulder=J((6, 0, -4)))
TIE = dict(rShoulder=J((62, 0, -52), (-0.36, 0.18, -0.2)), lShoulder=J((10, 0, -20), (0.1, 0.04, -0.1)))
WALK = dict(rShoulder=J((4, 0, -2)), lShoulder=J((4, 0, 2)))

o = Motion("RoleOperative_self", LENGTH, note="The Operative's role cutscene: the badge, the tie, out.")
o.key(0.0, root=(-6, 0, 0), neck=(-12, 0, 0), **INSIDE)
o.key(1.6, root=(-7, 0, 0), neck=(-14, 4, 0), **INSIDE)
o.key(3.0, root=(-6, 0, 0), neck=(-12, -2, 0), **INSIDE)
o.key(3.8, root=(-6, 0, 0), neck=(-14, 0, 0), **INSIDE)  # takes the badge out
o.key(6.4, root=(-4, 0, 0), neck=(-32, 2, 0), **LOOK)
o.key(7.0, root=(0, -18, 0), neck=(-6, -10, 0), **LOOK)  # turns
o.key(10.0, root=(2, 0, 0), neck=(6, 0, 0), **SHOW)
o.key(12.0, root=(0, 0, 0), neck=(-6, 0, 0), **TIE)
o.key(12.5, root=(-2, 0, 0), neck=(4, 0, 0), **WALK)
o.key(LENGTH, root=(-2, 0, 0), neck=(4, 0, 0), **WALK)
# The big moves acted: the badge looked down at with a small settle, then snapped up open to the camera (a
# breath drawn back first, a touch past and settling), put away, the tie tugged.
beat(o, 4.6, 0.5, antic=0.08, over=0.1, root=(-4, 0, 0), neck=(-30, 0, 0), **LOOK)  # and looks at it
beat(o, 7.8, 0.55, antic=0.16, over=0.14, root=(2, 0, 0), neck=(4, 0, 0), **SHOW)  # and holds it up, open
beat(o, 10.8, 0.5, antic=0.1, over=0.08, root=(-2, 0, 0), neck=(-12, 0, 0), **POCKET)  # away inside the jacket
beat(o, 11.5, 0.4, antic=0.08, over=0.1, root=(0, 0, 0), neck=(-8, 0, 0), **TIE)  # the tie
o.key(11.82, rShoulder=J((66, 0, -50), (-0.36, 0.14, -0.2)))
soft(o, arms=2.4).plant(None, 12.3, stance=0.06)
walking(o, 12.5, LENGTH + 1.0)
alive(o, 0.5, seed=5, t1=6.6)
alive(o, 0.35, seed=6, t0=8.4, t1=10.4)
o.build()

# The shot -------------------------------------------------------------------------------------------

shot = Shot(NAME, "Sets", LENGTH, note="The Operative's role cutscene: the locker room, the badge.")

# A: wide from the corner by the door: the cold room, the one figure at a locker.
shot.cam(0.0, (LX + 9.4, 6.8, 3.8), (LOCKER[0], 4.0, -4.6), fov=50)
shot.cam(3.6, (LX + 8.6, 6.4, 3.2), (LOCKER[0], 4.0, -4.6), fov=46, ease="linear")
# B: from the side along the lockers: the badge taken out, looked at.
shot.cam(3.6, (LX + 6.4, 4.8, -2.4), (LOCKER[0], 4.2, LOCKER[1]), fov=42, cut=True)
shot.cam(7.0, (LX + 6.0, 4.6, -2.0), (LOCKER[0], 4.2, LOCKER[1]), fov=38, ease="linear")
# C: in front: they turn and hold it up, open, to the camera.
shot.cam(7.0, (LOCKER[0] - 0.4, 4.4, 1.2), (LOCKER[0], 4.0, LOCKER[1]), fov=40, cut=True)
shot.cam(10.4, (LOCKER[0] - 0.3, 4.4, 0.4), (LOCKER[0], 4.0, LOCKER[1]), fov=32, ease="in")
# D: by the door: the badge put away, the tie, and they walk out past the camera.
shot.cam(10.4, (LX - 2.0, 5.2, 5.6), (LOCKER[0], 4.4, -3.0), fov=46, cut=True)
shot.cam(LENGTH, (LX - 2.2, 5.0, 5.8), (OUT[0], 4.4, 4.0), fov=46)

me = shot.actor("self", o)
me.mark(0.0, (LOCKER[0], 0.0, LOCKER[1]), 0.0)
me.mark(6.6, (LOCKER[0], 0.0, LOCKER[1]), 0.0)
me.mark(7.8, (LOCKER[0], 0.0, LOCKER[1]), 180.0)
me.mark(12.5, (LOCKER[0], 0.0, LOCKER[1]), 180.0, "linear")
me.mark(LENGTH, (LOCKER[0], 0.0, LOCKER[1] + 4.0 * (LENGTH - 12.5)), 180.0, "linear")
me.hold("BureauBadge", "Right Arm", (0.0, -1.1, -0.2), (-84, 0, 0), t0=3.8, t1=10.8)

shot.event(0.0, "sfx", slot="mapOfficeHum")
shot.event(3.8, "sfx", slot="pageTurn")
shot.event(7.8, "sfx", slot="heartbeat")
shot.event(10.8, "sfx", slot="pageTurn")
shot.event(1.0, "card", key="role", dur=4.2)
shot.event(5.4, "card", key="win", dur=3.6)
shot.event(9.2, "card", key="move", dur=2.8)
shot.event(12.0, "card", key="names", dur=3.0)
# No line: the Operative's scene keeps its 15 s, under its own music (silent until the slot has an id).
shot.audio(music="musicOperative")
