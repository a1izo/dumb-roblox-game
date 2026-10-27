"""The Tokyo intro (everyone, 15 s): the platform. After Raye Penber's death in the subway (Death Note, episode 9;
art/refs/cinema/IntroTokyo.toml): a man seizes up at the train's door while the one inside the car watches. Ours:
both are random players and nobody dies; the victim falls and struggles, the Manual on the floor beside him.

A  0.0-3.4   Low along the glass screen doors: the car pulls in behind them, braking; the victim waits at a bay, his
             head following it in. Further down the platform the others wait over their phones.
B  3.4-7.2   From deep inside the car, past the watcher's shoulder, out through the glass: the doors open; the
             victim's jolt, the hand to his chest, doubled over, his palm slapping onto the pane, the head thrown
             back in agony.
D  7.2-9.2   Behind him on the platform: he slides down the glass to his knees and onto his side, the watcher
             standing over him beyond the glass; the Manual on the floor beside him.
E  9.2-11.6  Low by the glass at the floor, up through it: the watcher in the lit doorway looks down at him.
F  11.6-13.0 Close on the watcher through the glass: he lifts his head and looks at us, the faintest smile; the
             car's doors slide shut across him.
G  13.0-15.0 High from the platform's east end: the car pulls out; he lies struggling by the Manual; nobody looked up.

The metro (maps/venues/tokyo/plan.py, Tokyo scene space): the island platform at y -20 (x -140..-30, z -73..-51), its
north edge's glass screen doors at z -51.4 in 6-stud bays centred at x -136 + 6k, the yellow tactile strip at z
-52.1..-53.1; the north track's middle at z -46.5. The car (TrainCarOpen) is turned to run along x with its open
doorway facing the platform; its floor is level with the platform."""

from animlib import J
from cinema.acting import alive, kneel, seated, soft, strike
from cinema.shot import Shot
from emotes.kit import CHEST, reach
from motion import Motion

NAME = "IntroTokyo"
LENGTH = 15.0
FLOOR = -20.0
GLASS_Z = -51.4
DOOR_X = -88.0  # the car's open doorway, in line with a screen-door bay
TRACK_Z = -46.5
CAR_DOOR = 6.4  # the doorway's middle from the car's pivot, along x (the prop's DOOR_Y, turned)
CAR_Y = FLOOR - 1.5  # the car's floor is 1.5 over its pivot: level with the platform
STOP = DOOR_X - CAR_DOOR
ARRIVE, STOPPED, LEAVE = (0.0, STOP + 36.0), (3.4, STOP), (12.8, STOP)
GONE = (LENGTH, STOP - 34.0)

VICTIM = (DOOR_X, -52.8)  # on the strip, facing the glass
WATCHER = (DOOR_X - 1.6, -49.6)  # inside the doorway by its west post, facing out (the other half is clear)
MANUAL_AT = (DOOR_X - 1.9, -53.1)  # by his head and his hand, where he falls

# Everyone in the car rides it: their marks keep their place in it while it moves.
def ride(actor, x_in_car, z, yaw, y=FLOOR + 0.1):
    for t, x, ease in ((ARRIVE[0], ARRIVE[1], "smooth"), (STOPPED[0], STOPPED[1], "out"), (LEAVE[0], LEAVE[1], "smooth"),
                       (GONE[0], GONE[1], "in")):
        actor.mark(t, (x + x_in_car, y, z), yaw, ease)


# The victim -----------------------------------------------------------------------------------------------
# Facing the glass (+z). His left is +x, where the car comes from: the head follows it in.

HANG_R, HANG_L = J((4, 0, 4), (0, 0.02, 0)), J((4, 0, -4), (0, 0.02, 0))
CLUTCH = reach(1, CHEST, direction=(-0.55, 0.15, -0.8))  # the right hand clawed into the chest
PALM_HI = reach(-1, (-0.75, 1.25, -1.25), direction=(0.1, 0.35, -0.95))  # the left palm flat on the glass
PALM_LO = reach(-1, (-0.7, 0.4, -1.2), direction=(0.05, -0.2, -0.95))  # dragged down it

v = Motion("IntroTokyo_victim", LENGTH, note="The Tokyo intro: the seizure at the screen doors.")
v.key(0.0, root=(0, 6, 0), neck=(-4, 44, 0), rShoulder=HANG_R, lShoulder=HANG_L)  # looking up the platform at it
v.key(1.6, "sine", root=(0, 4, 0), neck=(-4, 26, 0), rShoulder=HANG_R, lShoulder=HANG_L)
v.key(3.3, "out", root=(0, 0, 0), neck=(-6, 2, 0), rShoulder=HANG_R, lShoulder=HANG_L)  # it stops in front of him
v.key(3.9, root=(0, 0, 0), neck=(-8, 0, 0), rShoulder=HANG_R, lShoulder=HANG_L)
# The jolt: held still, a tiny draw-in, then snapped double with the hand clawed into the chest.
strike(v, 4.15, {"root": J((3, 0, 0)), "neck": J((4, 0, 0)), "rShoulder": J((20, 0, 8))},
       {"root": J((-30, 0, 4)), "neck": J((-26, 0, 0)), "rShoulder": CLUTCH, "offset": (0.0, -0.25, 0.1)},
       antic=0.14, travel=0.06, over=0.25, settle=0.3)
v.key(4.6, root=(-28, -4, 6), neck=(-20, -6, 4), lShoulder=J((30, 0, -16)), rShoulder=CLUTCH)  # staggers
# The palm slapped onto the pane to hold himself up.
strike(v, 5.05, {"lShoulder": J((70, 0, -30))}, {"lShoulder": PALM_HI, "root": J((-18, 0, -4)), "neck": J((-10, 4, 0))},
       antic=0.1, travel=0.06, over=0.15, settle=0.25)
for k in range(4):  # shaking against it
    t = 5.4 + 0.18 * k
    v.key(t, "sine", root=(-18 + (3 if k % 2 else -2), 2 if k % 2 else -2, -4), neck=(-8 + (4 if k % 2 else 0), 0, 0),
          rShoulder=CLUTCH, lShoulder=PALM_HI)
# The agony: the head thrown back, the mouth open (the camera above).
v.key(6.2, "out", root=(-6, 0, -2), neck=(30, -8, 6), rShoulder=CLUTCH, lShoulder=PALM_HI)
for k in range(4):
    t = 6.45 + 0.17 * k
    v.key(t, "sine", root=(-6, 0, -2 + (2 if k % 2 else 0)), neck=(30 + (5 if k % 2 else 0), -8 + (6 if k % 2 else 0), 6),
          rShoulder=CLUTCH, lShoulder=PALM_HI)
# He reels back off the glass two steps (his mark moves), drops to his knees, and falls forward on his face,
# as Raye does: the arm out in front of him, the other at his side.
v.key(6.95, "in", root=(-12, 0, 0), neck=(6, 0, 0), rShoulder=CLUTCH, lShoulder=J((40, 0, -26)))
v.key(7.45, "out", root=(4, 0, 0), neck=(16, 0, 0), rShoulder=CLUTCH, lShoulder=J((24, 0, -36)))
kneel(v, 7.75, "in", lean=-10, head=-6, rShoulder=CLUTCH, lShoulder=J((30, 0, -20)))
kneel(v, 7.95, lean=-24, head=-16, rShoulder=CLUTCH, lShoulder=J((40, 0, -14)))
v.key(8.45, "in", floor=True, root=(-88, 0, 0), neck=(18, 0, 6), rShoulder=J((-12, 0, 8)),
      lShoulder=J((168, 0, -8)), rHip=J((-6, 0, 4)), lHip=J((-10, 0, -4)))
v.key(8.6, "out", floor=True, root=(-86, 0, 2), neck=(14, 0, 6), rShoulder=J((-12, 0, 8)),
      lShoulder=J((172, 0, -8)), rHip=J((-6, 0, 4)), lHip=J((-10, 0, -4)))
# Struggling on the floor: hard breaths heaving the back, the head lifted to the car, the hand clawing up the glass.
for k in range(14):
    t = 9.0 + 0.4 * k
    up = 1 if k % 2 else 0
    lift_head = 40 if t > 9.6 else 18
    claw = 178 + (10 if 3 <= k <= 7 else 0)
    v.key(t, "sine", floor=True, root=(-86 + 3 * up, 0, 2), neck=(lift_head + 4 * up, 0, 6),
          rShoulder=J((-12 + 4 * up, 0, 8)), lShoulder=J((claw + 4 * up, 0, -8)), rHip=J((-6 + 4 * up, 0, 4)),
          lHip=J((-10, 0, -4)))
soft(v, head=3.2, arms=3.2, arm_damp=0.55)
v.plant(0.0, 3.9, stance=0.06)
alive(v, 0.6, seed=3, t1=3.9)
v.build()

# The watcher ----------------------------------------------------------------------------------------------
# Facing out of the car (-z) at the victim, still the whole time; only the head and the face move.

w = Motion("IntroTokyo_watcher", LENGTH, note="The Tokyo intro: the one in the car, watching.")
STAND_R, STAND_L = J((2, 0, 3)), J((2, 0, -3))
w.key(0.0, root=(0, 0, 0), neck=(-12, 0, 0), rShoulder=STAND_R, lShoulder=STAND_L)
w.key(4.3, root=(0, 0, 0), neck=(-12, 0, 0), rShoulder=STAND_R, lShoulder=STAND_L)
w.key(5.2, "sine", root=(-3, 0, 0), neck=(-24, 0, 0), rShoulder=STAND_R, lShoulder=STAND_L)  # looks down at him
w.key(8.4, root=(-3, 0, 0), neck=(-26, 0, 0), rShoulder=STAND_R, lShoulder=STAND_L)
w.key(9.4, "sine", root=(-6, 0, 0), neck=(-40, 0, 0), rShoulder=STAND_R, lShoulder=STAND_L)  # down at the floor
w.key(10.6, "sine", root=(-6, 0, 2), neck=(-38, 0, 12), rShoulder=STAND_R, lShoulder=STAND_L)  # the head tilts
w.key(11.3, root=(-5, 0, 2), neck=(-36, 0, 12), rShoulder=STAND_R, lShoulder=STAND_L)
w.key(11.9, "sine", root=(-1, 0, 0), neck=(-8, 0, 8), rShoulder=STAND_R, lShoulder=STAND_L)  # up, at us
w.key(LENGTH, root=(-1, 0, 0), neck=(-6, 0, 6), rShoulder=STAND_R, lShoulder=STAND_L)
soft(w, head=2.4, arms=2.0)
w.plant(stance=0.06)
alive(w, 0.35, seed=5)
w.build()

# The others -----------------------------------------------------------------------------------------------
# Two asleep or on their phones on the car's seat; four waiting along the platform over their phones.

PHONE = J((96, 0, -16), (-0.1, 0.18, -0.25))
for k in range(2):
    m = Motion(f"IntroTokyo_seat{k}", LENGTH, note="The Tokyo intro: a passenger.")
    head = -36 if k == 0 else -22
    seated(m, 0.0, seat=1.85, lean=-6, legs=84, neck=(head, 0, 6 * (1 - 2 * k)),
           rShoulder=PHONE if k == 1 else J((30, 0, -6)), lShoulder=J((30, 0, 6)))
    seated(m, LENGTH, seat=1.85, lean=-6, legs=84, neck=(head - 2, 0, 6 * (1 - 2 * k)),
           rShoulder=PHONE if k == 1 else J((30, 0, -6)), lShoulder=J((30, 0, 6)))
    alive(m, 0.4, seed=10 + k)
    m.build()

WAITING = [(-112.0, -52.9), (-106.0, -53.2), (-64.0, -52.9), (-57.6, -53.4)]
for k in range(len(WAITING)):
    m = Motion(f"IntroTokyo_wait{k}", LENGTH, note="The Tokyo intro: someone waiting, on their phone.")
    m.key(0.0, root=(0, 0, 0), neck=(-30, 0, 0), rShoulder=PHONE, lShoulder=J((4, 0, -4)))
    m.key(LENGTH, root=(0, 0, 0), neck=(-30, 0, 0), rShoulder=PHONE, lShoulder=J((4, 0, -4)))
    soft(m, head=2.4)
    m.plant(stance=0.06)
    alive(m, 0.6, seed=20 + k)
    m.build()

# The shot -------------------------------------------------------------------------------------------------

shot = Shot(NAME, "Tokyo", LENGTH, note="The Tokyo intro: the platform.")

victim = shot.actor("victim", v)
victim.mark(0.0, (VICTIM[0], FLOOR, VICTIM[1]), 180.0)
victim.mark(6.95, (VICTIM[0], FLOOR, VICTIM[1]), 180.0)
victim.mark(7.5, (VICTIM[0], FLOOR, VICTIM[1] - 2.0), 180.0, "out")  # reels back off the glass
watcher = shot.actor("watcher", w)
ride(watcher, CAR_DOOR + WATCHER[0] - DOOR_X, WATCHER[1], 0.0)
for k, dx in enumerate((-4.6, 4.6)):  # the long seat's two halves either side of the doorway, along the far wall
    p = shot.actor(f"everyone:{k + 1}", clip=f"IntroTokyo_seat{k}")
    ride(p, CAR_DOOR + dx, -43.6, 0.0)
for k, (x, z) in enumerate(WAITING):
    p = shot.actor(f"everyone:{k + 3}", clip=f"IntroTokyo_wait{k}")
    p.mark(0.0, (x, FLOOR, z), 180.0)
    p.hold("Smartphone", "Right Arm", (0.0, -1.05, -0.2), (-14, 0, 0))

# The car, turned to run along x with its doorway facing the platform, and its two door leaves.
car = shot.prop("TrainCarOpen")
for t, x, ease in ((ARRIVE[0], ARRIVE[1], "smooth"), (STOPPED[0], STOPPED[1], "out"), (LEAVE[0], LEAVE[1], "smooth"),
                   (GONE[0], GONE[1], "in")):
    car.at(t, (x, CAR_Y, TRACK_Z), (0, -90, 0), ease)

LEAF_Z = TRACK_Z - 4.1  # just inside the car's side
for side in (-1, 1):
    leaf = shot.prop("TrainDoorLeaf")
    closed, opened = side * 1.1, side * 3.3
    keys = [(ARRIVE, closed, "smooth"), ((3.5, STOP), closed, "smooth"), ((4.1, STOP), opened, "out"),
            ((12.0, STOP), opened, "smooth"), ((12.5, STOP), closed, "in"), (LEAVE, closed, "smooth"), (GONE, closed, "in")]
    for (t, x), dx, ease in keys:
        leaf.at(t, (x + CAR_DOOR + dx, FLOOR + 3.7, LEAF_Z), (0, -90, 0), ease if t != GONE[0] else "in")

manual = shot.prop("Grimoire", scale=0.5)  # dropped on the floor beside him, as Raye's briefcase lay
manual.at(0.0, (MANUAL_AT[0], FLOOR + 0.11, MANUAL_AT[1]), (0, 28, 0))
manual.at(LENGTH, (MANUAL_AT[0], FLOOR + 0.11, MANUAL_AT[1]), (0, 28, 0))

# A: low on the platform from the west: the car brakes in behind the glass; he turns his head to follow it.
shot.subjects.append((0.0, 3.4, None, True))
shot.cam(0.0, (DOOR_X - 13.0, FLOOR + 2.6, -57.6), (DOOR_X + 2.0, FLOOR + 3.8, -51.0), fov=56)
shot.cam(3.4, (DOOR_X - 11.6, FLOOR + 2.8, -57.2), (DOOR_X + 0.6, FLOOR + 3.9, -51.4), fov=50, ease="linear")
# B: from deep inside the car, past the watcher's shoulder, out through the glass: the doors open, the jolt, the
# palm slapped on the pane, the head thrown back in agony; a slow push in all the while.
shot.pan(3.4, 7.2, "victim", (DOOR_X + 3.6, FLOOR + 4.6, -46.6), aim="Head", dy=-0.4, fov=44, cut=True,
         drift=(-0.5, -0.1, -0.9))
# D: behind him on the platform: he slides down the glass to his knees and over onto his side, the one in the
# doorway standing over him beyond it.
shot.pan(7.2, 9.2, "victim", (DOOR_X + 3.6, FLOOR + 5.0, -62.0), aim="Torso", dy=0.8, fov=46, cut=True,
         drift=(-0.6, -0.4, 0.4), back=True)
# E: low by the glass at the floor, up through it at the watcher looking down.
shot.pan(9.2, 11.6, "watcher", (DOOR_X - 2.4, FLOOR + 0.9, -52.5), aim="Head", dy=0.0, fov=50, cut=True,
         drift=(0.3, 0.2, 0.0))
# F: close on the watcher through the glass; the doors slide shut across him.
shot.pan(11.6, 13.0, "watcher", (DOOR_X + 1.4, FLOOR + 4.9, -56.6), aim="Head", dy=-0.4, fov=40, cut=True,
         drift=(-0.2, 0.0, 0.3))
# G: high from the east end: the car pulls out; he lies by the Manual.
shot.subjects.append((13.0, LENGTH, None, True))
shot.cam(13.0, (DOOR_X + 14.0, FLOOR + 7.0, -58.5), (DOOR_X - 0.5, FLOOR + 0.6, -52.8), fov=44, cut=True)
shot.cam(LENGTH, (DOOR_X + 15.5, FLOOR + 7.6, -59.5), (DOOR_X - 0.5, FLOOR + 0.6, -52.8), fov=46, ease="linear")

# Faces
shot.face(0.0, "victim", "Stern")
shot.face(4.15, "victim", "Shock")
shot.face(4.9, "victim", "Fear")
shot.face(0.0, "watcher", "Stern")
shot.face(10.2, "watcher", "Grin")
for k in range(6):
    shot.face(0.0, f"everyone:{k + 1}", "Stern")

shot.event(0.0, "sfx", slot="mapTrainArrive")
shot.event(3.5, "sfx", slot="trainDoors")
shot.event(3.9, "sfx", slot="mapStationChime")
shot.event(4.15, "sfx", slot="heartbeat")
shot.event(4.15, "fx", name="impact", r=255, g=40, b=50, strength=0.4, dur=0.22)
shot.event(5.05, "fx", name="shake", strength=0.2, dur=0.2)
shot.event(5.6, "sfx", slot="heartbeat")
shot.event(8.45, "sfx", slot="bodyFall")
shot.event(8.45, "fx", name="shake", strength=0.25, dur=0.25)
shot.event(12.0, "sfx", slot="trainDoors")
shot.event(12.9, "card", key="case", dur=2.1)
