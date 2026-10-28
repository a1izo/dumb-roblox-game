"""The Operative's role cutscene (the briefing, seen only by that Operative): the Bureau's locker room, alone,
before the night's work. At an open locker they take out their badge, look at it, turn and hold it up
open (the camera close on it), put it away, straighten their tie and walk out between the benches.

The locker room (maps/venues/sets/locker.py, Sets scene space, origin x 360): x 349..371, z -7..7; a row
of 13 lockers along the north wall (fronts at z -4.9; the eighth's middle at x 361.5), more along the
south wall either side of the door (x 359.5..363.5); benches at (356.4, 0) and (366.6, 0), the gap
between them at x 359.3..363.7 (2026-10-27: they were 2.2 apart, and the walk out brushed both); the eighth
locker stands open.

First timed to 15 s; 2026-10-27 about 4 s longer, at your word (19 s): the badge looked at and held up open longer,
the jacket and the tie unhurried, the walk out at its own pace. T maps the first timings onto the longer scene."""

from animlib import J
from cinema.acting import alive, beat, soft, walking
from cinema.shot import Shot
from motion import Motion

NAME = "RoleOperative"
LENGTH = 19.0
# The first 15 s timings -> the longer scene's: A as it was, B and C 1.4 s longer each, the badge put away and the tie
# 1.2 s longer; the walk out keeps its length (and so its stride).
WARP = ((0.0, 0.0), (3.6, 3.6), (7.0, 8.4), (10.4, 13.2), (12.5, 16.5), (15.0, LENGTH))


def T(t):
    for (a0, b0), (a1, b1) in zip(WARP, WARP[1:]):
        if t <= a1:
            return round(b0 + (t - a0) * (b1 - b0) / (a1 - a0), 3)
    return LENGTH + (t - 15.0)

LX = 360.0
STEP = 1.2  # how far from the lockers they stand to turn (the actor's BACK below)
LOCKER = (LX + 1.5, -3.6)
OUT = (LX + 1.5, 6.2)

# Acting ---------------------------------------------------------------------------------------------

# (the right hand alone in the open locker, the left at the side: the locker is 1.5 studs wide, two blocky arms are
# two, and held out together they went into the lockers either side, 2026-10-27; they stand with the right shoulder
# before the open locker for it)
INSIDE = dict(rShoulder=J((64, 0, -6), (0, 0.08, -0.3)), lShoulder=J((10, 0, 6)))
LOOK = dict(rShoulder=J((56, 0, -26), (-0.2, 0.1, -0.26)), lShoulder=J((50, 0, 22), (0.2, 0.1, -0.24)))
SHOW = dict(rShoulder=J((84, 0, -14), (-0.08, 0.18, -0.3)), lShoulder=J((6, 0, -4)))
POCKET = dict(rShoulder=J((40, 0, -54), (-0.34, 0.14, -0.16)), lShoulder=J((6, 0, -4)))
TIE = dict(rShoulder=J((62, 0, -52), (-0.36, 0.18, -0.2)), lShoulder=J((10, 0, -20), (0.1, 0.04, -0.1)))
WALK = dict(rShoulder=J((4, 0, -2)), lShoulder=J((4, 0, 2)))

o = Motion("RoleOperative_self", LENGTH, note="The Operative's role cutscene: the badge, the tie, out.")
o.key(0.0, root=(-6, 0, 0), neck=(-12, 0, 0), **INSIDE)
o.key(T(1.6), root=(-7, 0, 0), neck=(-14, 4, 0), **INSIDE)
o.key(T(3.0), root=(-6, 0, 0), neck=(-12, -2, 0), **INSIDE)
o.key(T(3.8), root=(-6, 0, 0), neck=(-14, 0, 0), **INSIDE)  # takes the badge out
o.key(T(6.4), root=(-4, 0, 0), neck=(-32, 2, 0), **LOOK)
o.key(T(7.0), root=(0, -18, 0), neck=(-6, -10, 0), **LOOK)  # turns
o.key(T(10.0), root=(2, 0, 0), neck=(6, 0, 0), **SHOW)
o.key(T(12.0), root=(0, 0, 0), neck=(-6, 0, 0), **TIE)
o.key(T(12.5), root=(-2, 0, 0), neck=(4, 0, 0), **WALK)
o.key(LENGTH, root=(-2, 0, 0), neck=(4, 0, 0), **WALK)
# The big moves acted: the badge looked down at with a small settle, then snapped up open to the camera (a
# breath drawn back first, a touch past and settling), put away, the tie tugged.
beat(o, T(4.6), 0.5, antic=0.08, over=0.1, root=(-4, 0, 0), neck=(-30, 0, 0), **LOOK)  # and looks at it
beat(o, T(7.8), 0.55, antic=0.16, over=0.14, root=(2, 0, 0), neck=(4, 0, 0), **SHOW)  # and holds it up, open
beat(o, T(10.8), 0.5, antic=0.1, over=0.08, root=(-2, 0, 0), neck=(-12, 0, 0), **POCKET)  # away inside the jacket
beat(o, T(11.5), 0.4, antic=0.08, over=0.1, root=(0, 0, 0), neck=(-8, 0, 0), **TIE)  # the tie
o.key(T(11.82), rShoulder=J((66, 0, -50), (-0.36, 0.14, -0.2)))
soft(o, arms=2.4).plant(None, T(12.3), stance=0.06)
walking(o, T(12.5), LENGTH + 1.0)
alive(o, 0.5, seed=5, t1=T(6.6))
alive(o, 0.35, seed=6, t0=T(8.4), t1=T(10.4))
o.build()

# The shot -------------------------------------------------------------------------------------------

shot = Shot(NAME, "Sets", LENGTH, note="The Operative's role cutscene: the locker room, the badge.")

# A: wide from the corner by the door: the cold room, the one figure at a locker.
shot.cam(0.0, (LX + 9.4, 6.8, 3.8), (LOCKER[0], 4.0, -4.6), fov=50)
shot.cam(T(3.6), (LX + 8.6, 6.4, 3.2), (LOCKER[0], 4.0, -4.6), fov=46, ease="linear")
# B: from the side along the lockers: the badge taken out, looked at.
shot.cam(T(3.6), (LX + 6.4, 4.8, -2.4), (LOCKER[0] - 0.6, 4.2, LOCKER[1] + 0.4), fov=42, cut=True)
shot.cam(T(7.0), (LX + 6.0, 4.6, -2.0), (LOCKER[0], 4.2, LOCKER[1] + 1.0), fov=38, ease="linear")
# C: in front: they turn and hold it up, open, to the camera (as far from them as before they stepped back).
shot.cam(T(7.0), (LOCKER[0] - 0.4, 4.4, 1.2 + STEP), (LOCKER[0], 4.0, LOCKER[1] + STEP), fov=40, cut=True)
shot.cam(T(10.4), (LOCKER[0] - 0.3, 4.4, 0.4 + STEP), (LOCKER[0], 4.0, LOCKER[1] + STEP), fov=32, ease="in")
# D: by the door: the badge put away, the tie, and they walk out past the camera.
shot.cam(T(10.4), (LX - 2.0, 5.2, 5.6), (LOCKER[0], 4.4, -3.0 + STEP), fov=46, cut=True)
shot.cam(LENGTH, (LX - 2.2, 5.0, 5.8), (OUT[0], 4.4, 4.0), fov=46)

me = shot.actor("self", o)
# (2026-10-27: looking at the badge and turning on the spot, the arms went into the lockers: a step back from
# them with the badge, and another before they turn)
BACK = STEP
me.mark(0.0, (LOCKER[0] - 1.5, 0.0, LOCKER[1]), 0.0)
me.mark(T(3.8), (LOCKER[0] - 1.5, 0.0, LOCKER[1]), 0.0)
me.mark(T(4.2), (LOCKER[0] - 1.5, 0.0, LOCKER[1] + 1.0), 0.0)  # (a step back with the badge...)
me.mark(T(4.6), (LOCKER[0], 0.0, LOCKER[1] + 1.0), 0.0)  # (...and over, to look at it)
me.mark(T(6.6), (LOCKER[0], 0.0, LOCKER[1] + 1.0), 0.0)
me.mark(T(7.0), (LOCKER[0], 0.0, LOCKER[1] + BACK), 0.0)
me.mark(T(7.8), (LOCKER[0], 0.0, LOCKER[1] + BACK), 180.0)
me.mark(T(12.5), (LOCKER[0], 0.0, LOCKER[1] + BACK), 180.0, "linear")
me.mark(LENGTH, (LOCKER[0], 0.0, LOCKER[1] + BACK + 4.0 * (LENGTH - T(12.5))), 180.0, "linear")
# The badge (0.84 wide, 0.6 tall, its face the model's -z once exported) held by its bottom edge in the fist, rising
# above it, upright across the arm: its face to them while they look at it, to the camera once they turn and hold it
# up. (2026-10-27: it sat over the end of the fist, its face to them throughout, and the hand ran through it as the
# arm moved.)
GRIP = (0.0, -1.05, -0.65)
me.hold("BureauBadge", "Right Arm", GRIP, (-90, 180, 0), t0=T(3.8), t1=T(7.2))
me.hold("BureauBadge", "Right Arm", GRIP, (-90, 0, 0), t0=T(7.2), t1=T(10.8))

shot.event(0.0, "sfx", slot="mapOfficeHum")
shot.event(T(3.8), "sfx", slot="pageTurn")
shot.event(T(7.8), "sfx", slot="heartbeat")
shot.event(T(10.8), "sfx", slot="pageTurn")
for key, t0, t1 in (("role", 1.0, 5.2), ("win", 5.4, 9.0), ("move", 9.2, 12.0), ("names", 12.0, 15.0)):
    shot.event(T(t0), "card", key=key, dur=round(T(t1) - T(t0), 2))
# No line: the Operative's scene has its role card captions, under its own music (silent until the slot has an id).
shot.audio(music="musicOperative")
