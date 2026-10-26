"""The Tokyo intro: the metro platform, the last train. While everyone waits, the train pulls in; one
player (the struggler, picked at random) suddenly crumples to the floor and writhes there, a black
notebook beside them. In the open doorway of the stopped train another random player (the watcher)
stands looking down at them, unmoved. The doors close and the train pulls away. Nobody dies here, and
neither part says anything about anyone's role.

The platform (maps/venues/tokyo/station.py): an island x -140..-30, z -73..-51, its floor at y -20,
glass screen doors along both edges; the north track's middle is z -77.5, its bed at y -24. The train
stops with its head car's middle at x -111 and the next car's at x -59 (rot 90: they run along x,
heading west). TrainCarOpen's doorway (one car on) faces the platform at x -65.4."""

import math
import random

from animlib import J
from cinema.acting import alive, beat, soft
from cinema.shot import Shot
from motion import Motion

NAME = "IntroTokyo"
LENGTH = 15.0
FLOOR = -20.0
TRACK = -77.5
CAR_Y = -24.0 + 0.7
CAR_FLOOR = CAR_Y + 1.5
HEAD_STOP, OPEN_STOP = -111.0, -59.0
DOOR_X = OPEN_STOP - 6.4  # the open doorway's middle
EDGE_Z = -73.1  # the car's side, at the platform edge
ARRIVE, STOPPED, LEAVE = 2.6, 5.8, 12.4
STRUGGLER = (-62.0, FLOOR, -68.4)
BOOK = (-60.0, FLOOR + 0.25, -69.9)

CROWD = [  # (x, z, yaw): people waiting along the platform, most facing the track
    (-50.0, -59.0, 5), (-72.5, -67.0, -10), (-52.0, -60.0, 20), (-76.0, -62.5, 0), (-48.0, -67.5, -5),
    (-83.0, -66.0, 10), (-66.0, -58.5, 160), (-90.0, -61.0, -20), (-44.0, -62.0, 30), (-96.0, -67.0, 0),
    (-38.0, -66.0, -15),
]


def bearing(frm, to):
    """The yaw that faces from `frm` towards `to` (x, z)."""
    dx, dz = to[0] - frm[0], to[1] - frm[1]
    return math.degrees(math.atan2(-dx, -dz))


# Acting ---------------------------------------------------------------------------------------------

STAND_ARMS = dict(rShoulder=J((2, 0, 3)), lShoulder=J((2, 0, -3)))


def crowd_clip(k, x, z, yaw):
    """Waiting (a phone, or arms folded); when the struggler falls, the head turns to look."""
    rng = random.Random(100 + k)
    m = Motion(f"IntroTokyo_crowd{k}", LENGTH, note="Tokyo intro: someone waiting for the train.")
    phone = k % 3 != 1
    if phone:
        arms = dict(rShoulder=J((62, 0, -26), (-0.2, 0.1, -0.2)), lShoulder=J((8, 0, -4)))
        head = (-22, 0, 0)
    else:
        arms = dict(rShoulder=J((40, 0, -38), (-0.3, 0.1, -0.22)), lShoulder=J((38, 0, 36), (0.3, 0.1, -0.22)))
        head = (-4, 0, 0)
    m.key(0.0, root=(0, 0, 0), neck=head, **arms)
    m.key(2.8, root=(0, 0, 0), neck=(head[0] + 2, rng.uniform(-6, 6), 0), **arms)
    # the train: a glance up the track as it comes in
    m.key(3.6 + rng.uniform(0, 0.6), root=(0, 4, 0), neck=(-2, -24, 0), **arms)
    m.key(6.6 + rng.uniform(0, 0.4), root=(0, 0, 0), neck=head, **arms)
    # the fall: the head turns to the noise, the body a little after it
    turn = (bearing((x, z), (STRUGGLER[0], STRUGGLER[2])) - yaw + 180) % 360 - 180
    turn = max(-80.0, min(80.0, turn))
    t0 = 7.3 + rng.uniform(0.0, 0.5)
    m.key(t0, root=(0, 0, 0), neck=head, **arms)
    beat(m, t0 + 0.35, 0.35, antic=0.08, over=0.15, root=(2, turn * 0.25, 0), neck=(-8, turn * 0.6, 0),
         rShoulder=J((20, 0, 0), (0, 0.04, -0.05)), lShoulder=J((16, 0, 0), (0, 0.04, -0.05)))
    m.key(LENGTH, root=(1, turn * 0.3, 0), neck=(-12, turn * 0.6, 0), rShoulder=J((10, 0, 2)), lShoulder=J((10, 0, -2)))
    return alive(soft(m).plant(stance=0.05), 0.5, seed=40 + k)


crowd_clips = [crowd_clip(k, x, z, yaw).build() for k, (x, z, yaw) in enumerate(CROWD)]

# The struggler: waiting, then a jolt, the knees go, down to the floor, writhing, then still.
strug = Motion("IntroTokyo_struggler", LENGTH, note="Tokyo intro: the one who collapses on the platform.", floor=True)
strug.key(0.0, root=(0, 0, 0), neck=(-6, 0, 0), **STAND_ARMS)
strug.key(5.9, root=(0, 0, 0), neck=(-4, 0, 0), **STAND_ARMS)
strug.key(6.15, "snap", offset=(0, -0.05, 0.04), root=(-16, 0, 0), neck=(-22, 0, 0),
          rShoulder=J((66, 0, -42), (-0.3, 0.14, -0.22)), lShoulder=J((20, 0, -10)))
strug.key(6.75, offset=(0.05, -0.85, 0.0), root=(-24, 8, 6), neck=(-18, 0, 6),
          rShoulder=J((66, 0, -42), (-0.3, 0.14, -0.22)), lShoulder=J((54, 0, -16), (0, 0.05, -0.15)))
strug.plant(0.0, 6.75, stance=0.05, tilt=(16, 12))
# down onto the back, the knees drawn up; writhing, a hand reaching towards the doorway
strug.key(7.35, "in", offset=(0, 0, 0.9), floor=True, root=(80, -6, -8), neck=(22, 24, -10),
          rShoulder=J((30, 0, 40), (0, 0.05, 0)), lShoulder=J((96, 0, -20), (0, 0.15, -0.1)),
          rHip=J((40, 0, 6), (0, 0.5, 0)), lHip=J((18, 0, -6), (0, 0.25, 0)))
for k, t in enumerate((7.9, 8.6, 9.3, 10.0, 10.7, 11.4)):
    s = 1 if k % 2 == 0 else -1
    strug.key(t, offset=(0, 0, 0.95), floor=True, root=(84 + 3 * s, -6 + 6 * s, -8 + 8 * s),
              neck=(22 + 4 * s, 26, -10 + 6 * s), rShoulder=J((26 + 10 * s, 0, 44), (0, 0.05, 0)),
              lShoulder=J((104 - 12 * s, 0, -24 + 10 * s), (0, 0.18, -0.12)),
              rHip=J((44 + 16 * s, 0, 6), (0, 0.55, 0)), lHip=J((24 - 14 * s, 0, -6), (0, 0.3, 0)))
strug.key(12.4, "in", offset=(0, 0, 0.95), floor=True, root=(88, -4, -6), neck=(20, 30, -10),
          rShoulder=J((14, 0, 44)), lShoulder=J((80, 0, -30), (0, 0.12, -0.1)),
          rHip=J((30, 0, 6), (0, 0.4, 0)), lHip=J((10, 0, -6), (0, 0.15, 0)))
strug.key(LENGTH, offset=(0, 0, 0.95), floor=True, root=(89, -4, -6), neck=(20, 32, -10),
          rShoulder=J((12, 0, 44)), lShoulder=J((60, 0, -34), (0, 0.1, -0.08)),
          rHip=J((26, 0, 6), (0, 0.35, 0)), lHip=J((8, 0, -6), (0, 0.1, 0)))
soft(strug, arms=2.4).build()

# The watcher: riding in with a hand on the pole, then standing in the doorway, looking down at them.
watch = Motion("IntroTokyo_watcher", LENGTH, note="Tokyo intro: the one in the train's doorway.")
pole = J((150, 0, -6), (0.05, 0.2, -0.1))
watch.key(0.0, root=(0, 0, 0), neck=(-4, 20, 0), rShoulder=J((4, 0, 2), (0, 0, 0.06)), lShoulder=pole)
watch.key(5.4, root=(0, 0, 0), neck=(-4, 10, 0), rShoulder=J((4, 0, 2), (0, 0, 0.06)), lShoulder=pole)
watch.key(5.9, "out", offset=(0, 0, -0.08), root=(3, 0, 0), neck=(0, 0, 0), rShoulder=J((4, 0, 2)), lShoulder=pole)
watch.key(7.6, root=(0, 0, 0), neck=(-6, 0, 0), rShoulder=J((-8, 0, 4), (0.02, 0.02, 0.12)),
          lShoulder=J((2, 0, -3)))  # the hand leaves the pole; the other goes into a pocket
watch.key(8.8, root=(-2, 6, 0), neck=(-26, 10, 6), rShoulder=J((-8, 0, 4), (0.02, 0.02, 0.12)),
          lShoulder=J((2, 0, -3)))  # looking down at them
watch.key(10.4, root=(-2, 6, 0), neck=(-28, 12, 9), rShoulder=J((-8, 0, 4), (0.02, 0.02, 0.12)),
          lShoulder=J((2, 0, -3)))
watch.key(11.2, root=(1, 4, 0), neck=(-16, 8, 4), rShoulder=J((-8, 0, 4), (0.02, 0.02, 0.12)),
          lShoulder=J((2, 0, -3)))  # the chin comes up: done
watch.key(LENGTH, root=(1, 4, 0), neck=(-14, 6, 3), rShoulder=J((-8, 0, 4), (0.02, 0.02, 0.12)), lShoulder=J((2, 0, -3)))
soft(watch, head=1.8, head_damp=0.85, arms=2.0).plant(stance=0.08)
alive(watch, 0.35, seed=60, t0=7.8)
watch.build()

# The shot ---------------------------------------------------------------------------------------------

shot = Shot(NAME, "Tokyo", LENGTH, note="Tokyo intro: the last train; one falls on the platform, one watches from the train.",
            skippable=True, mood="TokyoDistrict_Under")

# A: the platform, everyone waiting; far down the tunnel, the train's lamps.
shot.cam(0.0, (-120.0, -14.5, -61.0), (-60.0, -17.5, -66.0), fov=44)
shot.cam(3.2, (-116.0, -15.0, -62.0), (-60.0, -17.5, -67.0), fov=40, ease="linear")
# B: down by the screen doors as the train comes in.
shot.cam(3.2, (-96.0, -18.4, -70.8), (-40.0, -17.0, -76.5), fov=46, cut=True)
shot.cam(6.0, (-95.0, -18.2, -70.6), (-60.0, -17.0, -76.0), fov=40)
# C: the struggler falls.
shot.cam(6.0, (-56.0, -16.6, -62.0), (-62.0, -18.6, -68.4), fov=36, cut=True)
shot.cam(8.6, (-57.0, -17.2, -63.0), (-62.0, -19.4, -68.6), fov=32, ease="linear")
# D: through the screen door glass: the watcher in the doorway, looking down.
shot.cam(8.6, (-68.6, -15.4, -65.8), (DOOR_X, -16.4, -74.6), fov=30, cut=True)
shot.cam(11.0, (-68.3, -15.6, -66.4), (DOOR_X, -16.4, -74.6), fov=27, ease="linear")
# E: over the watcher's shoulder, down at them; the doors slide shut.
shot.cam(11.0, (DOOR_X - 2.6, -15.0, -78.4), (-62.0, -19.6, -68.4), fov=36, cut=True)
shot.cam(12.6, (DOOR_X - 2.4, -15.1, -78.2), (-62.0, -19.6, -68.4), fov=34, ease="linear")
# F: on the floor by them, the notebook close; the train leaves behind the glass.
shot.cam(12.6, (-57.8, -19.3, -66.4), (-61.6, -19.4, -69.6), fov=40, cut=True)
shot.cam(LENGTH, (-58.2, -19.3, -66.7), (-61.6, -19.5, -69.6), fov=36, ease="linear")


def car_path(prop, stop):
    """In from the east, slowing to a stop; out to the west, speeding up."""
    prop.at(0.0, (stop + 160.0, CAR_Y, TRACK), (0, 90, 0))
    prop.at(ARRIVE, (stop + 125.0, CAR_Y, TRACK), (0, 90, 0), "linear")
    prop.at(STOPPED, (stop, CAR_Y, TRACK), (0, 90, 0), "out")
    prop.at(LEAVE, (stop, CAR_Y, TRACK), (0, 90, 0))
    prop.at(LENGTH, (stop - 150.0, CAR_Y, TRACK), (0, 90, 0), "in")
    return prop


car_path(shot.prop("TrainHead"), HEAD_STOP)
car_path(shot.prop("TrainCarOpen"), OPEN_STOP)
# the door leaves: open (slid back into the car) until they close at 11.6
for side in (-1, 1):
    leaf = shot.prop("TrainDoorLeaf")
    y = CAR_Y + 5.2
    leaf.at(0.0, (DOOR_X + side * 3.3 + 160.0, y, EDGE_Z), (0, 90, 0))
    leaf.at(ARRIVE, (DOOR_X + side * 3.3 + 125.0, y, EDGE_Z), (0, 90, 0), "linear")
    leaf.at(STOPPED, (DOOR_X + side * 3.3, y, EDGE_Z), (0, 90, 0), "out")
    leaf.at(11.6, (DOOR_X + side * 3.3, y, EDGE_Z), (0, 90, 0))
    leaf.at(12.2, (DOOR_X + side * 1.1, y, EDGE_Z), (0, 90, 0), "out")
    leaf.at(LEAVE, (DOOR_X + side * 1.1, y, EDGE_Z), (0, 90, 0))
    leaf.at(LENGTH, (DOOR_X + side * 1.1 - 150.0, y, EDGE_Z), (0, 90, 0), "in")

w = shot.actor("watcher", watch)
w.mark(0.0, (DOOR_X + 160.0, CAR_FLOOR, EDGE_Z - 1.6), 180)
w.mark(ARRIVE, (DOOR_X + 125.0, CAR_FLOOR, EDGE_Z - 1.6), 180, "linear")
w.mark(STOPPED, (DOOR_X, CAR_FLOOR, EDGE_Z - 1.6), 180, "out")
w.mark(LEAVE, (DOOR_X, CAR_FLOOR, EDGE_Z - 1.6), 180)
w.mark(LENGTH, (DOOR_X - 150.0, CAR_FLOOR, EDGE_Z - 1.6), 180, "in")

s = shot.actor("struggler", strug)
s.mark(0.0, STRUGGLER, bearing((STRUGGLER[0], STRUGGLER[2]), (DOOR_X, EDGE_Z)) + 10)

for k, (x, z, yaw) in enumerate(CROWD):
    a = shot.actor(f"everyone:{k + 1}", clip=f"IntroTokyo_crowd{k}")
    a.mark(0.0, (x, FLOOR, z), yaw)

book = shot.prop("Grimoire", show=(7.35, LENGTH))
book.at(7.35, (BOOK[0], BOOK[1] + 1.2, BOOK[2]), (50, 40, 0))
book.at(7.6, BOOK, (0, 40, 0), "in")
book.at(LENGTH, BOOK, (0, 40, 0))

shot.event(0.4, "title", lines=["KAGEGAOKA STATION", "The last train, 23:59"], dur=2.6)
shot.event(2.4, "sfx", slot="mapTrainArrive")
shot.event(5.9, "sfx", slot="mapStationChime")
shot.event(6.15, "sfx", slot="heartbeat")
shot.event(7.35, "sfx", slot="bodyFall")
shot.event(11.6, "sfx", slot="trainDoors")
shot.event(13.2, "card", key="case", dur=1.6)
