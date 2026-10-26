"""The Agency intro: midnight on the Bureau's 39th floor. Everyone is gathered round the big map table on
the operations deck, the case spread out on it and in the middle the black notebook itself, recovered
and bagged as evidence. They read, take notes, argue over it; one (the reader) reaches out and opens
it; another (the presenter) turns and points up at the video wall across the atrium, where the dead
look back from the screens. The camera ends on the notebook. Both named parts are random players.

The operations deck (maps/venues/agency/upper.py): 39F's floor at y 14; the map table's middle at
(17, 62), 10 across (x) by 6 deep (z), its top at y 16.8, chairs at x 14.5 / 19.5 on both long sides
(z 57.8, 66.2). The video wall is on the core's south face (z -5.5), x -6..40, its screens y 22..32,
across the atrium (x -4..38, z 4..34)."""

import math
import random

from animlib import J
from cinema.acting import alive, beat, soft
from cinema.shot import Shot
from motion import Motion

NAME = "IntroAgency"
LENGTH = 15.0
Y = 14.0
TABLE = (17.0, 62.0)
TOP = 16.8
WALL = (17.0, 27.0, -5.5)  # the middle of the video wall

READER = (17.0, 58.6, 0.0)  # (x, z, yaw): north side, middle, facing the table (+z is yaw 180)
PRESENTER = (22.4, 58.7, 0.0)
SPOTS = [  # the others round the table, nearest the camera's way first
    (12.2, 58.7), (11.0, 61.0), (12.2, 65.4), (17.0, 65.5), (21.8, 65.4), (23.2, 61.6), (11.0, 63.4),
    (23.2, 63.8), (14.6, 56.4), (19.6, 56.4),
]


def facing(frm, to):
    """The yaw that faces from (x, z) towards (x, z)."""
    dx, dz = to[0] - frm[0], to[1] - frm[1]
    return math.degrees(math.atan2(-dx, -dz))


def turn_to(yaw, frm, to):
    return max(-90.0, min(90.0, (facing(frm, to) - yaw + 180) % 360 - 180))


# Acting ---------------------------------------------------------------------------------------------

LEAN = dict(rShoulder=J((52, 0, -10), (-0.1, 0.06, -0.26)), lShoulder=J((52, 0, 10), (0.1, 0.06, -0.26)))
NOTES = dict(rShoulder=J((58, 0, -24), (-0.18, 0.1, -0.24)), lShoulder=J((56, 0, 26), (0.22, 0.1, -0.24)))
FOLDED = dict(rShoulder=J((40, 0, -38), (-0.3, 0.1, -0.22)), lShoulder=J((38, 0, 36), (0.3, 0.1, -0.22)))
CHIN = dict(rShoulder=J((112, 0, -32), (-0.28, 0.24, -0.22)), lShoulder=J((40, 0, 34), (0.3, 0.08, -0.22)))
STYLES = [LEAN, NOTES, FOLDED, CHIN]


def table_clip(k, x, z, yaw):
    """Round the table: leaning on it, writing notes, arms folded or a hand at the chin; at 8.6 the head
    (then the body) turns to the video wall where the presenter points."""
    rng = random.Random(300 + k)
    arms = STYLES[k % len(STYLES)]
    lean = -14 if arms is LEAN else (-8 if arms is NOTES else -3)
    m = Motion(f"IntroAgency_member{k}", LENGTH, note="Agency intro: someone at the map table.")
    look = rng.uniform(-8, 8)
    m.key(0.0, root=(lean, 0, 0), neck=(-24, look, 0), **arms)
    m.key(3.0 + rng.uniform(0, 1), root=(lean + 2, rng.uniform(-6, 6), 0), neck=(-20, -look, 0), **arms)
    m.key(6.2 + rng.uniform(0, 0.6), root=(lean, 0, 0), neck=(-26, 0, 0), **arms)
    turn = turn_to(yaw, (x, z), (WALL[0], WALL[2]))
    t0 = 8.7 + rng.uniform(0, 0.4)
    m.key(t0, root=(lean, 0, 0), neck=(-24, 0, 0), **arms)
    beat(m, t0 + 0.5, 0.5, antic=0.06, over=0.12, root=(-2, turn * 0.3, 0), neck=(16, turn * 0.6, 0),
         rShoulder=J((10, 0, 0), (0, 0.04, -0.05)), lShoulder=J((10, 0, 0), (0, 0.04, -0.05)))
    m.key(11.2 + rng.uniform(0, 0.4), root=(-2, turn * 0.3, 0), neck=(18, turn * 0.6, 0),
          rShoulder=J((8, 0, 0)), lShoulder=J((8, 0, 0)))
    m.key(12.0 + rng.uniform(0, 0.5), root=(lean * 0.6, 0, 0), neck=(-22, 0, 0), **arms)
    m.key(LENGTH, root=(lean * 0.6, 0, 0), neck=(-24, 0, 0), **arms)
    return alive(soft(m).plant(stance=0.06), 0.55, seed=k)


for k, (x, z) in enumerate(SPOTS):
    table_clip(k, x, z, facing((x, z), TABLE)).build()

# The reader: leaning over the notebook, reaches out at 6.2 and lifts its cover, then looks up.
reader = Motion("IntroAgency_reader", LENGTH, note="Agency intro: the one who opens the notebook.")
reader.key(0.0, root=(-12, 0, 0), neck=(-26, 0, 0), **NOTES)
reader.key(5.8, root=(-13, 0, 0), neck=(-28, 4, 0), **NOTES)
beat(reader, 6.5, 0.6, antic=0.08, over=0.06, root=(-22, 0, 0), neck=(-34, 0, 0),
     rShoulder=J((78, 0, -8), (-0.05, 0.12, -0.36)), lShoulder=J((40, 0, 18), (0.15, 0.05, -0.2)))
reader.key(7.4, root=(-22, 0, 0), neck=(-36, 0, 0), rShoulder=J((84, -20, -4), (-0.05, 0.16, -0.36)),
           lShoulder=J((40, 0, 18), (0.15, 0.05, -0.2)))  # the cover comes up
reader.key(8.4, root=(-18, 0, 0), neck=(-30, 0, 0), rShoulder=J((74, -10, -6), (-0.05, 0.12, -0.34)),
           lShoulder=J((40, 0, 18), (0.15, 0.05, -0.2)))
beat(reader, 9.2, 0.7, antic=0.1, over=0.1, root=(-6, 8, 0), neck=(14, 30, 0),
     rShoulder=J((40, 0, -6), (0, 0.06, -0.2)), lShoulder=J((16, 0, 6)))  # to the wall with the others
reader.key(12.2, root=(-6, 8, 0), neck=(12, 30, 0), rShoulder=J((40, 0, -6), (0, 0.06, -0.2)), lShoulder=J((16, 0, 6)))
reader.key(13.0, root=(-16, 0, 0), neck=(-32, 0, 0), rShoulder=J((70, 0, -8), (-0.05, 0.1, -0.32)),
           lShoulder=J((40, 0, 18), (0.15, 0.05, -0.2)))
reader.key(LENGTH, root=(-17, 0, 0), neck=(-34, 0, 0), rShoulder=J((70, 0, -8), (-0.05, 0.1, -0.32)),
           lShoulder=J((40, 0, 18), (0.15, 0.05, -0.2)))
soft(reader).plant(stance=0.05, forward=(0.2, 0.0))
alive(reader, 0.45, seed=21, t1=5.8)
alive(reader, 0.45, seed=22, t0=10.0)
reader.build()

# The presenter: arms folded, then at 8.6 turns and points up at the video wall.
pres = Motion("IntroAgency_presenter", LENGTH, note="Agency intro: the one who points at the video wall.")
pturn = turn_to(PRESENTER[2], (PRESENTER[0], PRESENTER[1]), (WALL[0], WALL[2]))
pres.key(0.0, root=(-3, 0, 0), neck=(-18, -8, 0), **FOLDED)
pres.key(8.2, root=(-3, 0, 0), neck=(-20, -6, 0), **FOLDED)
beat(pres, 8.8, 0.6, antic=0.16, over=0.12, root=(4, pturn * 0.6, 0), neck=(10, pturn * 0.4, 0),
     rShoulder=J((122, 10, -14), (0, 0.22, -0.2)), lShoulder=J((10, 0, -4)))  # (a breath drawn, then the point)
pres.key(11.6, root=(5, pturn * 0.6, 0), neck=(12, pturn * 0.4, 0),
         rShoulder=J((124, 10, -14), (0, 0.22, -0.2)), lShoulder=J((10, 0, -4)))
pres.key(12.6, root=(-2, pturn * 0.2, 0), neck=(-16, 0, 0), **FOLDED)
pres.key(LENGTH, root=(-3, 0, 0), neck=(-18, 0, 0), **FOLDED)
soft(pres).plant(stance=0.06)
alive(pres, 0.5, seed=23, t1=8.2)
alive(pres, 0.4, seed=24, t0=12.4)
pres.build()

# The shot -------------------------------------------------------------------------------------------

shot = Shot(NAME, "Agency", LENGTH, note="Agency intro: the Bureau round the notebook on the operations deck.",
            skippable=True, mood="TaskForceHQ")

# A: from over the atrium's railing, high, across the desks to the gathering at the table.
shot.cam(0.0, (17.0, 26.0, 36.0), (17.0, 16.0, 62.0), fov=40)
shot.cam(3.0, (17.0, 23.5, 41.0), (17.0, 16.4, 62.0), fov=38, ease="linear")
# B: round the table at eye height, a slow arc.
shot.cam(3.0, (4.0, 22.6, 55.0), (17.0, 16.6, 62.0), fov=40, cut=True)
shot.cam(6.0, (4.6, 22.4, 68.6), (17.0, 16.6, 62.0), fov=40)
# C: low across the table top: the notebook in the lamplight, the reader's hand lifting its cover.
shot.cam(6.0, (14.6, 18.1, 64.8), (17.2, 17.0, 61.6), fov=32, cut=True)
shot.cam(8.6, (14.8, 18.0, 64.5), (17.2, 17.0, 61.6), fov=28, ease="linear")
# D: behind the group: the presenter points, everyone turns; the video wall across the atrium.
shot.cam(8.6, (20.0, 20.0, 69.5), (17.0, 22.0, 20.0), fov=42, cut=True)
shot.cam(11.2, (20.0, 20.4, 68.0), (17.0, 24.0, 10.0), fov=38, ease="linear")
# E: down on the notebook, pushing in to its dark cover.
shot.cam(11.2, (17.0, 22.0, 63.4), (17.0, 16.9, 62.0), fov=40, cut=True)
shot.cam(13.0, (17.0, 19.0, 62.6), (17.0, 16.9, 62.0), fov=34, ease="in")
# F: top down on the table and everyone round it.
shot.cam(13.0, (17.0, 34.0, 62.4), (17.0, 16.0, 62.0), fov=40, cut=True)
shot.cam(LENGTH, (17.0, 32.0, 62.4), (17.0, 16.0, 62.0), fov=38, ease="linear")

r = shot.actor("reader", reader)
r.mark(0.0, (READER[0], Y, READER[1]), facing((READER[0], READER[1]), TABLE))
p = shot.actor("presenter", pres)
p.mark(0.0, (PRESENTER[0], Y, PRESENTER[1]), facing((PRESENTER[0], PRESENTER[1]), TABLE))
for k, (x, z) in enumerate(SPOTS):
    a = shot.actor(f"everyone:{k + 1}", clip=f"IntroAgency_member{k}")
    a.mark(0.0, (x, Y, z), facing((x, z), TABLE))
    if STYLES[k % len(STYLES)] is NOTES:
        a.hold("Pen", "Right Arm", (0, -1.0, -0.15), (60, 0, 0))

book = shot.prop("Grimoire")
book.at(0.0, (17.0, TOP + 0.05, 62.0), (0, 10, 0))
book.at(LENGTH, (17.0, TOP + 0.05, 62.0), (0, 10, 0))
for k, (dx, dz, rot) in enumerate(((-3.2, -1.2, 20), (3.0, 1.0, -30), (-2.4, 1.6, 70), (2.6, -1.4, 5))):
    page = shot.prop("PaperSheet")
    page.at(0.0, (17.0 + dx, TOP + 0.02, 62.0 + dz), (0, rot, 0))
    page.at(LENGTH, (17.0 + dx, TOP + 0.02, 62.0 + dz), (0, rot, 0))

shot.event(0.4, "title", lines=["BUREAU HEADQUARTERS, 39F", "Operations, 00:04"], dur=2.6)
shot.event(0.0, "sfx", slot="mapRainGlass")
shot.event(7.2, "sfx", slot="pageTurn")
shot.event(8.8, "sfx", slot="screenStatic")
shot.event(11.2, "sfx", slot="heartbeat")
shot.event(13.2, "card", key="case", dur=1.6)
