"""The Tokyo intro (everyone, 23 s; the intro phase follows it): the platform. After Raye Penber's death in the
subway (Death Note, episode 9; art/refs/cinema/IntroTokyo.toml): a man seizes up at the train's door while the one
inside the car watches. Ours: both are random players and nobody dies; the victim falls and struggles, the Manual he
was carrying on the floor beside him.

A  0.0-5.0   Wide on the platform: people waiting here and there, a pair talking, someone walking through; the car
             brakes in behind the glass screen doors. The victim waits a little back from the glass, a black book
             under his hand.
B  5.0-8.0   From inside the car, past the shoulder of the one standing by the doorway's post: the doors open; the
             victim looks up and sees him. A beat.
C  8.0-12.0  Closer, still from inside the car: the jolt. A hand clawed into his chest; the book falls from the other;
             doubled over, staggering in place, the head thrown back.
D  12.0-15.0 Low on the platform from the side: he sinks to his knees, sways, and falls forward on his face, as Raye
             does, a hand reaching for the glass; the book lies where it fell.
E  15.0-18.2 From the floor by him, up through the glass: the watcher looks down at him.
F  18.2-20.4 Close on the watcher through the glass: he lifts his head to us, the faintest smile; the doors close.
G  20.4-23.0 High from the east: the car pulls out; he lies struggling by the book; nobody else has looked up.

The metro (maps/venues/tokyo/plan.py, Tokyo scene space): the island platform at y -20 (x -140..-30, z -73..-51), its
north edge's glass screen doors at z -51.4 in 6-stud bays centred at x -136 + 6k, the yellow tactile strip at
z -52.1..-53.1, the stairwell at its west end (x -146..-121); the north track's middle at z -46.5. The car
(TrainCarOpen) runs along x with its open doorway facing the platform, its floor level with it."""

from animlib import J
from cinema import framing
from cinema.acting import alive, facing, kneel, seated, soft, strike, walking
from cinema.shot import Shot
from emotes.kit import CHEST, reach
from motion import Motion

NAME = "IntroTokyo"
LENGTH = 23.0
FLOOR = -20.0
GLASS_Z = -51.4
DOOR_X = -88.0  # the car's open doorway, in line with a screen-door bay
TRACK_Z = -46.5
CAR_DOOR = 6.4  # the doorway's middle from the car's pivot, along x (the prop's DOOR_Y, turned)
CAR_Y = FLOOR - 1.5  # the car's floor is 1.5 over its pivot: level with the platform
STOP = DOOR_X - CAR_DOOR
ARRIVE, STOPPED, LEAVE = (0.0, STOP + 52.0), (4.6, STOP), (20.4, STOP)
GONE = (LENGTH, STOP - 30.0)
DOORS_OPEN, DOORS_SHUT = (5.0, 5.7), (19.6, 20.2)

VICTIM = (DOOR_X, -55.2)  # waiting a little back from the glass, behind the yellow strip, facing it
WATCHER = (DOOR_X - 1.6, -49.6)  # inside the doorway by its west post, facing out (the other half is clear)
JOLT, DROP, KNEES, FALL = 8.3, 8.55, 12.7, 13.9


def ride(actor, x_in_car, z, yaw, y=FLOOR + 0.1):
    """Everyone in the car rides it: their marks keep their place in it while it moves."""
    for t, x, ease in ((ARRIVE[0], ARRIVE[1], "smooth"), (STOPPED[0], STOPPED[1], "out"), (LEAVE[0], LEAVE[1], "smooth"),
                       (GONE[0], GONE[1], "in")):
        actor.mark(t, (x + x_in_car, y, z), yaw, ease)


# The victim -----------------------------------------------------------------------------------------------
# Facing the glass (+z); his left is +x, where the car comes from. The book hangs in his left hand at his side.

HANG_R = J((4, 0, 4), (0, 0.02, 0))
BOOK_L = J((8, 0, -6), (0, 0.02, 0))  # the left arm down, the book in its hand
CLUTCH = reach(1, CHEST, direction=(-0.55, 0.15, -0.8))  # the right hand clawed into the chest
FLUNG_L = J((40, 0, -38))  # the left arm thrown out as the book drops
OUT_L = reach(-1, (-0.9, 0.9, -1.9), direction=(0.1, 0.25, -0.95))  # reaching out towards the doorway

v = Motion("IntroTokyo_victim", LENGTH, note="The Tokyo intro: the seizure on the platform.")
# The car comes in from his left: his head follows it, slowly, as it brakes.
v.key(0.0, root=(0, 6, 0), neck=(-4, 46, 0), rShoulder=HANG_R, lShoulder=BOOK_L)
v.key(2.4, "sine", root=(0, 4, 0), neck=(-4, 24, 0), rShoulder=HANG_R, lShoulder=BOOK_L)
v.key(4.6, "out", root=(0, 0, 0), neck=(-6, 0, 0), rShoulder=HANG_R, lShoulder=BOOK_L)
# The doors open on the man inside: he looks up at him, and holds the look.
v.key(5.9, "sine", root=(1, 0, 0), neck=(4, -6, 0), rShoulder=HANG_R, lShoulder=BOOK_L)
v.key(6.6, root=(1, 0, 0), neck=(5, -8, 4), rShoulder=HANG_R, lShoulder=BOOK_L)  # a tilt: does he know him?
v.key(7.8, "sine", root=(1, 0, 0), neck=(3, -8, 6), rShoulder=HANG_R, lShoulder=BOOK_L)
# The jolt: held still, the smallest draw-in, then snapped double with the hand clawed into the chest; the other
# arm flings out and the book drops.
strike(v, JOLT, {"root": J((3, 0, 0)), "neck": J((6, 0, 0)), "rShoulder": J((18, 0, 8))},
       {"root": J((-28, 0, 4)), "neck": J((-24, 0, 0)), "rShoulder": CLUTCH, "lShoulder": FLUNG_L,
        "offset": (0.0, -0.22, 0.0)}, antic=0.18, travel=0.07, over=0.25, settle=0.35)
# Doubled over and staggering where he stands: the weight thrown side to side (the feet stay put), the free hand
# reaching out to the man behind the glass.
for k, (t, lean, side) in enumerate(((9.2, -26, -6), (9.8, -22, 7), (10.4, -18, -4))):
    v.key(t, "sine", offset=(0.0, -0.2, 0.0), root=(lean, side * 0.6, side), neck=(-16 + 4 * k, -side, side * 0.5),
          rShoulder=CLUTCH, lShoulder=OUT_L if k else J((60, 0, -24)))
# The agony: the head thrown back, the mouth open, shaking.
v.key(10.9, "out", offset=(0.0, -0.12, 0.0), root=(-4, 0, -2), neck=(30, -6, 6), rShoulder=CLUTCH, lShoulder=OUT_L)
for k in range(6):
    t = 11.1 + 0.2 * k
    v.key(t, "sine", offset=(0.0, -0.12, 0.0), root=(-4, 0, -2 + (2 if k % 2 else 0)),
          neck=(30 + (5 if k % 2 else 0), -6 + (5 if k % 2 else 0), 6), rShoulder=CLUTCH, lShoulder=OUT_L)
# The legs go: down onto his knees where he stands, swaying there a moment.
kneel(v, KNEES, "in", lean=-12, head=-8, rShoulder=CLUTCH, lShoulder=J((30, 0, -20)))
kneel(v, KNEES + 0.25, "out", lean=-20, head=-16, rShoulder=CLUTCH, lShoulder=J((36, 0, -16)))
kneel(v, KNEES + 0.75, "sine", lean=-14, head=-10, turn=4, rShoulder=CLUTCH, lShoulder=J((26, 0, -18)))
kneel(v, FALL - 0.05, "sine", lean=-22, head=-18, rShoulder=CLUTCH, lShoulder=J((40, 0, -14)))
# And forward onto his face, the arm out in front of him, the other at his side (R6 lies flat only face down).
v.key(FALL + 0.45, "in", floor=True, root=(-88, 0, 0), neck=(18, 0, 6), rShoulder=J((-12, 0, 8)),
      lShoulder=J((168, 0, -8)), rHip=J((-6, 0, 4)), lHip=J((-10, 0, -4)))
v.key(FALL + 0.6, "out", floor=True, root=(-86, 0, 2), neck=(14, 0, 6), rShoulder=J((-12, 0, 8)),
      lShoulder=J((172, 0, -8)), rHip=J((-6, 0, 4)), lHip=J((-10, 0, -4)))
# Struggling on the floor: hard breaths heaving his back, the head lifting to the car, the hand clawing forward.
for k in range(int((LENGTH - FALL - 1.0) / 0.45)):
    t = FALL + 1.0 + 0.45 * k
    up = 1 if k % 2 else 0
    lift_head = 42 if t > FALL + 2.0 else 20
    claw = 176 + (10 if 4 <= k <= 9 else 0)
    v.key(t, "sine", floor=True, root=(-86 + 3 * up, 0, 2), neck=(lift_head + 4 * up, 0, 6),
          rShoulder=J((-12 + 4 * up, 0, 8)), lShoulder=J((claw + 4 * up, 0, -8)), rHip=J((-6 + 4 * up, 0, 4)),
          lHip=J((-10, 0, -4)))
soft(v, head=3.0, arms=3.0, arm_damp=0.55)
v.plant(0.0, KNEES - 0.1, stance=0.06)
alive(v, 0.6, seed=3, t1=JOLT - 0.3)
v.build()

# The watcher ----------------------------------------------------------------------------------------------
# By the doorway's post, facing out at him; still the whole time, only the head and the face move.

STAND_R, STAND_L = J((2, 0, 3)), J((2, 0, -3))
w = Motion("IntroTokyo_watcher", LENGTH, note="The Tokyo intro: the one in the car, watching.")
w.key(0.0, root=(0, 0, 0), neck=(-10, 0, 0), rShoulder=STAND_R, lShoulder=STAND_L)
w.key(5.6, root=(0, 0, 0), neck=(-10, 0, 0), rShoulder=STAND_R, lShoulder=STAND_L)
w.key(6.6, "sine", root=(0, 0, 0), neck=(-14, -12, 0), rShoulder=STAND_R, lShoulder=STAND_L)  # at him
w.key(JOLT + 0.8, root=(-2, 0, 0), neck=(-18, -12, 0), rShoulder=STAND_R, lShoulder=STAND_L)
w.key(FALL + 0.4, "sine", root=(-5, 0, 0), neck=(-34, -10, 0), rShoulder=STAND_R, lShoulder=STAND_L)  # down at him
w.key(16.6, "sine", root=(-6, 0, 2), neck=(-36, -8, 12), rShoulder=STAND_R, lShoulder=STAND_L)  # the head tilts
w.key(18.4, root=(-5, 0, 2), neck=(-35, -8, 12), rShoulder=STAND_R, lShoulder=STAND_L)
w.key(19.1, "sine", root=(-1, 0, 0), neck=(-8, 0, 8), rShoulder=STAND_R, lShoulder=STAND_L)  # up, at us
w.key(LENGTH, root=(-1, 0, 0), neck=(-6, 0, 6), rShoulder=STAND_R, lShoulder=STAND_L)
soft(w, head=2.4, arms=2.0)
w.plant(stance=0.06)
alive(w, 0.35, seed=5)
w.build()

# The others -----------------------------------------------------------------------------------------------
# Two on the car's long seat; on the platform people waiting where people wait, a pair talking, one walking through.

PHONE = J((96, 0, -16), (-0.1, 0.18, -0.25))
for k in range(2):
    m = Motion(f"IntroTokyo_seat{k}", LENGTH, note="The Tokyo intro: a passenger.")
    head = -36 if k == 0 else -22
    for t in (0.0, LENGTH):
        seated(m, t, seat=1.85, lean=-6, legs=84, neck=(head - (2 if t else 0), 0, 6 * (1 - 2 * k)),
               rShoulder=PHONE if k == 1 else J((30, 0, -6)), lShoulder=J((30, 0, 6)))
    alive(m, 0.4, seed=10 + k)
    m.build()

# (x, z, yaw, what they do)
WAITING = [
    (-107.0, -55.6, 180.0, "phone"),  # a few bays west, behind the strip
    (-99.0, -70.4, 60.0, "phone"),  # over by the far wall, turned half away
    (-68.6, -57.6, None, "talk"),  # a pair talking, east of him
    (-65.6, -58.4, None, "talk"),
    (-110.0, -66.8, 0.0, "watch"),  # waiting for the other track, checking the time
]
TALK = ((-68.6, -57.6), (-65.6, -58.4))


def waiting(k, kind):
    m = Motion(f"IntroTokyo_wait{k}", LENGTH, note="The Tokyo intro: someone on the platform.")
    if kind == "phone":
        poses = [(0.0, dict(neck=(-30, 0, 0), rShoulder=PHONE)), (LENGTH, dict(neck=(-30, 0, 0), rShoulder=PHONE))]
    elif kind == "watch":
        wrist = J((92, 0, 26), (0.12, 0.16, -0.22))
        poses = [(0.0, dict(neck=(-8, 0, 0), lShoulder=J((4, 0, -4)))), (6.0, dict(neck=(-8, 0, 0), lShoulder=J((4, 0, -4)))),
                 (6.6, dict(neck=(-26, 0, 0), lShoulder=wrist)), (8.4, dict(neck=(-26, 0, 0), lShoulder=wrist)),
                 (9.0, dict(neck=(-8, 0, 0), lShoulder=J((4, 0, -4)))), (LENGTH, dict(neck=(-6, 0, 0), lShoulder=J((4, 0, -4))))]
    else:  # talking: the head nodding, a hand coming up as they make a point, now and then a laugh
        poses = []
        for i in range(12):
            t = i * 2.0 + (0.6 if k % 2 else 0.0)
            gesture = (i + k) % 3 == 0
            poses.append((min(t, LENGTH), dict(neck=(-2 + (4 if i % 2 else 0), 0, 3 if i % 2 else -2),
                                              rShoulder=J((46, 0, -10), (-0.1, 0.1, -0.15)) if gesture else J((4, 0, 4)))))
    for t, pose in poses:
        base = dict(root=(0, 0, 0), rShoulder=J((4, 0, 4)), lShoulder=J((4, 0, -4)))
        base.update(pose)
        m.key(t, "sine", **base)
    soft(m, head=2.4, arms=2.6)
    m.plant(stance=0.06)
    alive(m, 0.7, seed=20 + k)
    return m


for k, (_, _, _, kind) in enumerate(WAITING):
    waiting(k, kind).build()

# Someone walking the length of the platform behind it all, from the stairs towards the east end.
WALK_FROM, WALK_TO, WALK_T = (-116.0, -63.2), (-62.0, -63.2), (2.0, 20.0)
walk_speed = (WALK_FROM[0] - WALK_TO[0]) * -1 / (WALK_T[1] - WALK_T[0])
walker = Motion("IntroTokyo_walker", LENGTH, note="The Tokyo intro: someone walking through.")
walker.key(0.0, root=(0, 0, 0), neck=(-6, 0, 0), rShoulder=J((4, 0, 4)), lShoulder=J((4, 0, -4)))
walker.key(LENGTH, root=(0, 0, 0), neck=(-6, 0, 0), rShoulder=J((4, 0, 4)), lShoulder=J((4, 0, -4)))
walking(walker, WALK_T[0], WALK_T[1], speed=walk_speed)
walker.plant(None, WALK_T[0], stance=0.06)
walker.plant(WALK_T[1], None, stance=0.06)
walker.build()

# Faceless commuters further off, for the station's depth (nobody's avatar).
EXTRAS = [(-126.0, -57.0, 200.0), (-122.5, -68.5, 10.0), (-58.0, -66.0, 330.0), (-52.0, -56.0, 160.0)]
for k in range(len(EXTRAS)):
    m = Motion(f"IntroTokyo_extra{k}", LENGTH, note="The Tokyo intro: a commuter far off.")
    for t in (0.0, LENGTH):
        m.key(t, root=(0, 0, 0), neck=(-20 if k % 2 else -6, 0, 0), rShoulder=PHONE if k % 2 else J((4, 0, 4)),
              lShoulder=J((4, 0, -4)))
    m.plant(stance=0.06)
    alive(m, 0.6, seed=40 + k)
    m.build()

# The shot -------------------------------------------------------------------------------------------------

shot = Shot(NAME, "Tokyo", LENGTH, note="The Tokyo intro: the platform.")

victim = shot.actor("victim", v)
victim.mark(0.0, (VICTIM[0], FLOOR, VICTIM[1]), 180.0)
# (the root moves 0.4 forward with the fall so the legs stay where the knees were: nothing slides)
victim.mark(FALL - 0.05, (VICTIM[0], FLOOR, VICTIM[1]), 180.0)
victim.mark(FALL + 0.45, (VICTIM[0], FLOOR, VICTIM[1] + 0.4), 180.0, "in")
victim.hold("Grimoire", "Left Arm", (0.12, -1.05, -0.05), (90, 0, 0), t1=DROP, scale=0.42)
watcher = shot.actor("watcher", w)
ride(watcher, CAR_DOOR + WATCHER[0] - DOOR_X, WATCHER[1], 0.0)
for k, dx in enumerate((-4.6, 4.6)):  # the long seat's two halves either side of the doorway, along the far wall
    p = shot.actor(f"everyone:{k + 1}", clip=f"IntroTokyo_seat{k}")
    ride(p, CAR_DOOR + dx, -43.6, 0.0)
for k, (x, z, yaw, kind) in enumerate(WAITING):
    p = shot.actor(f"everyone:{k + 3}", clip=f"IntroTokyo_wait{k}")
    if yaw is None:  # the pair face each other
        other = TALK[1] if (x, z) == TALK[0] else TALK[0]
        yaw = facing((x, z), other)
    p.mark(0.0, (x, FLOOR, z), yaw)
    if kind == "phone":
        p.hold("Smartphone", "Right Arm", (0.0, -1.05, -0.2), (-14, 0, 0))
pw = shot.actor(f"everyone:{len(WAITING) + 3}", clip="IntroTokyo_walker")
pw.mark(0.0, (WALK_FROM[0], FLOOR, WALK_FROM[1]), -90.0)
pw.mark(WALK_T[0], (WALK_FROM[0], FLOOR, WALK_FROM[1]), -90.0)
pw.mark(WALK_T[1], (WALK_TO[0], FLOOR, WALK_TO[1]), -90.0, "linear")
for k, (x, z, yaw) in enumerate(EXTRAS):
    e = shot.actor(f"extra:{k + 1}", clip=f"IntroTokyo_extra{k}", extra=True)
    e.mark(0.0, (x, FLOOR, z), yaw)
    if k % 2:
        e.hold("Smartphone", "Right Arm", (0.0, -1.05, -0.2), (-14, 0, 0))

# The car, turned to run along x with its doorway facing the platform, and its two door leaves.
car = shot.prop("TrainCarOpen")
for t, x, ease in ((ARRIVE[0], ARRIVE[1], "smooth"), (STOPPED[0], STOPPED[1], "out"), (LEAVE[0], LEAVE[1], "smooth"),
                   (GONE[0], GONE[1], "in")):
    car.at(t, (x, CAR_Y, TRACK_Z), (0, -90, 0), ease)
LEAF_Z = TRACK_Z - 4.1  # just inside the car's side
for side in (-1, 1):
    leaf = shot.prop("TrainDoorLeaf")
    closed, opened = side * 1.1, side * 3.3
    keys = [(ARRIVE, closed, "smooth"), ((DOORS_OPEN[0], STOP), closed, "smooth"), ((DOORS_OPEN[1], STOP), opened, "out"),
            ((DOORS_SHUT[0], STOP), opened, "smooth"), ((DOORS_SHUT[1], STOP), closed, "in"), (LEAVE, closed, "smooth"),
            (GONE, closed, "in")]
    for (t, x), dx, ease in keys:
        leaf.at(t, (x + CAR_DOOR + dx, FLOOR + 3.7, LEAF_Z), (0, -90, 0), ease)

# The book: in his hand until he seizes, then it drops from where the hand is and lands flat beside his feet.
hand = framing.part(shot, "victim", DROP, "lhand")
LANDED = (VICTIM[0] + 1.6, FLOOR + 0.215 * 0.42, VICTIM[1] - 0.4)
book = shot.prop("Grimoire", show=(DROP, None), scale=0.42)
book.at(DROP, (float(hand[0]), float(hand[1]), float(hand[2])), (90, 0, 0))
book.at(DROP + 0.38, (LANDED[0], LANDED[1] + 0.05, LANDED[2]), (12, 30, 4), "in")  # hits the floor
book.at(DROP + 0.5, (LANDED[0], LANDED[1] + 0.12, LANDED[2]), (6, 32, 2), "out")  # a little bounce
book.at(DROP + 0.62, LANDED, (0, 34, 0), "in")
book.at(LENGTH, LANDED, (0, 34, 0))

# A: wide on the platform from the west: the people, the car braking in behind the glass, him waiting with the book.
shot.subjects.append((0.0, 5.0, None, True))
shot.cam(0.0, (DOOR_X - 20.0, FLOOR + 7.6, -66.5), (DOOR_X + 1.0, FLOOR + 2.6, -54.0), fov=48)
shot.cam(5.0, (DOOR_X - 17.5, FLOOR + 6.8, -65.0), (DOOR_X + 0.5, FLOOR + 2.8, -54.4), fov=44, ease="linear")
# B: on the platform behind his shoulder, up into the open doors: he looks up at the man.
shot.pan(5.0, 8.0, "watcher", (DOOR_X - 2.6, FLOOR + 4.6, -59.4), aim="Head", dy=-0.3, fov=38, cut=True,
         drift=(0.3, -0.1, 0.4))
# C: three-quarter front from the east, by the glass: the jolt, the book dropping, doubled over, the head
# thrown back.
shot.pan(8.0, 12.0, "victim", (DOOR_X + 9.4, FLOOR + 4.0, -53.8), aim="Torso", dy=-0.4, fov=52, cut=True,
         drift=(0.3, 0.0, -0.3))
# D: low on the platform from the east side: down onto his knees, and forward onto his face.
shot.pan(12.0, 15.0, "victim", (DOOR_X + 7.5, FLOOR + 3.0, -57.4), aim="Torso", dy=0.3, fov=50, cut=True,
         drift=(-0.5, -0.4, 0.2), back=True)
# E: low behind him on the platform, along his body to the watcher looking down from the doorway.
shot.pan(15.0, 18.2, "watcher", (DOOR_X + 1.8, FLOOR + 3.8, -60.6), aim="Head", dy=-1.7, fov=46, cut=True,
         drift=(-0.2, 0.1, 0.5))
# F: close on the watcher through the glass; he lifts his head to us; the doors close.
shot.pan(18.2, 20.4, "watcher", (DOOR_X - 0.2, FLOOR + 4.9, -56.6), aim="Head", dy=-0.4, fov=40, cut=True,
         drift=(-0.2, 0.0, 0.3))
# G: high from the east end: the car pulls out; he lies by the book; nobody has looked up.
shot.subjects.append((20.4, LENGTH, None, True))
shot.cam(20.4, (DOOR_X + 11.0, FLOOR + 8.0, -64.5), (DOOR_X - 1.0, FLOOR + 0.8, -54.0), fov=48, cut=True)
shot.cam(LENGTH, (DOOR_X + 12.2, FLOOR + 8.6, -65.6), (DOOR_X - 1.0, FLOOR + 0.8, -54.0), fov=50, ease="linear")

# Faces
shot.face(0.0, "victim", "Stern")
shot.face(JOLT, "victim", "Shock")
shot.face(JOLT + 0.9, "victim", "Fear")
shot.face(0.0, "watcher", "Stern")
shot.face(17.0, "watcher", "Grin")
for k in range(len(WAITING) + 3):
    shot.face(0.0, f"everyone:{k + 1}", "Stern")

shot.event(0.0, "sfx", slot="mapTrainArrive")
shot.event(DOORS_OPEN[0], "sfx", slot="trainDoors")
shot.event(DOORS_OPEN[0] + 0.4, "sfx", slot="mapStationChime")
shot.event(JOLT, "sfx", slot="heartbeat")
shot.event(JOLT, "fx", name="impact", r=255, g=40, b=50, strength=0.4, dur=0.24)
shot.event(DROP + 0.38, "sfx", slot="bookImpact")
shot.event(9.6, "sfx", slot="heartbeat")
shot.event(11.0, "sfx", slot="heartbeat")
shot.event(FALL + 0.45, "sfx", slot="bodyFall")
shot.event(FALL + 0.45, "fx", name="shake", strength=0.22, dur=0.25)
shot.event(DOORS_SHUT[0], "sfx", slot="trainDoors")
shot.event(20.7, "card", key="case", dur=2.3)
