"""The Agency intro (everyone, 22.6 s; the intro phase follows it): night watch. Rebuilt 2026-11-02 at the owner's word
("not everyone has to be the main character... spread people around: the ones watching cams scroll through a few, and
on the cams you see people hanging out"; and the killer would never bring the Manual back to them): two on the night
watch in the security office flick through the building's cameras: the others in the break room, at the night desk,
in the copy room, in the bullpen. On the evidence room's camera the recovered Manual lies on the counter... the feed
breaks up, and the counter is empty. The tape run back: a figure in a suit, back to the camera, takes it. The alarm:
red beacons all over the building, and on every camera, room by room, everyone stops and looks up into the lens. Any
of them. Last, a camera on the dark floor upstairs: the figure walking away with the Manual, stopping, turning its
head to the camera... static. The named part (the watcher) is a random player, never by role.

A  0.0-2.2   The security office, dark: the two on the watch at the wall of feeds.
B  2.2-3.4   CAM 38-07 BREAK ROOM: coffee, two talking at a table, one at the machines.
C  3.4-4.6   CAM 38-09 NIGHT DESK: one working late, one at the whiteboard.
D  4.6-5.6   CAM 38-04 COPY ROOM: one at the copier.
E  5.6-6.8   CAM 38-01 BULLPEN: two at the squad table, one at the board.
F  6.8-8.2   The watcher, bored, from the monitors' eye: another click.
G  8.2-10.0  CAM 39-11 EVIDENCE: the Manual on the counter. The feed breaks up; the counter is empty.
H  10.0-11.0 The two at the console jolt and lean in.
I  11.0-12.8 The replay: a figure in a suit, back to the camera, lifts the Manual and walks off.
J  12.8-13.8 The watcher slams the alarm: red beacons.
K  13.8-17.0 The cameras again, room by room: everyone stops and looks up into the lens.
L  17.0-19.6 CAM 39-12 ANALYSTS: the dark floor upstairs, the figure walking away with the Manual; it stops; its head
             turns to the camera... static. Black.
   19.6-22.6 Black, then the case's card.

Places (Agency scene space; 38F's floor at y 0, 39F's at 14): the security office x -100..-58, z -75..-48 (the wall
of feeds on its east wall, the console in front with two OfficeChairs at (-63.9, -69.5) and (-63.9, -63.5)); the break
room x 50..100, z -75..-40 (tables 5 by 3 at (66, -66), (66, -53), (80, -58) with chairs round them, the coffee machine
on the counter at (97.4, -66), vending machines along the west wall); the night desk x 50..100, z -40..16 (desk pairs
at (62, -30), (62, -14), a whiteboard at (75, -24)); the copy room x -8..24, z -75..-48 (photocopiers at (-2, -71.4),
(6, -71.4)); the bullpen's squad table 8 by 4 at (-86, 46) with chairs round it and a whiteboard at (-76, 40.5); the
39F evidence lock-up x -50..-16, z -75..-48 (its counter at (-24, -52.5), its door at x -33 in the south wall); the
analysts' floor south of it, desk pairs with an aisle at x -44."""

import math
import random

from animlib import J
from cinema import framing
from cinema.acting import alive, body_reach, facing, soft, walking
from cinema.shot import Shot
from emotes.kit import MOUTH, reach
from motion import Motion

NAME = "IntroAgency"
BLACK = 19.6
LENGTH = BLACK + 3.0
FEEDS = [(2.2, 3.4, "break"), (3.4, 4.6, "night"), (4.6, 5.6, "copy"), (5.6, 6.8, "bullpen")]  # (from, to, room)
EVIDENCE = (8.2, 10.0)
DROP = 9.35  # the evidence feed breaks up: the counter is empty when it clears
REPLAY = (11.0, 12.8)
ALARM = 13.05  # the watcher slams the alarm
LOOKS = [(13.8, 14.6, "break"), (14.6, 15.4, "night"), (15.4, 16.2, "copy"), (16.2, 17.0, "bullpen")]
CORRIDOR = (17.0, BLACK)
FIG_TURN = 18.5  # the figure's head turns to the camera
CUTS = (2.2, 3.4, 4.6, 5.6, 6.8, 8.2, 10.0, 11.0, 12.8, 13.8, 14.6, 15.4, 16.2, 17.0)

# The rooms' own cameras (high in a corner: locked) and what they look at.
CAMS = {
    "break": ((51.6, 11.6, -74.4), (73.0, 2.4, -58.0), 50.0, "CAM 38-07  BREAK ROOM"),
    "night": ((51.2, 11.6, -39.0), (68.0, 2.6, -26.0), 50.0, "CAM 38-09  NIGHT DESK"),
    "copy": ((22.6, 11.4, -49.4), (6.0, 2.6, -66.0), 50.0, "CAM 38-04  COPY ROOM"),
    "bullpen": ((-97.4, 11.6, 34.0), (-83.0, 2.6, 45.0), 50.0, "CAM 38-01  BULLPEN"),
    "evidence": ((-17.4, 25.0, -72.6), (-25.0, 16.2, -54.0), 40.0, "CAM 39-11  EVIDENCE"),
    "corridor": ((-35.4, 25.2, -46.4), (-44.0, 15.6, -33.0), 46.0, "CAM 39-12  ANALYSTS"),
}

COUNTER_BOOK = (-24.0, 17.55 + 0.22, -52.4)  # the Manual on the evidence counter
FIGURE = (-24.0, -55.4)  # the figure at the counter, facing it (+z)
FIG2_FROM, FIG2_TO = (-41.0, -44.0), (-44.0, -35.0)  # the figure walking away down the aisle upstairs

# Sitting ---------------------------------------------------------------------------------------------------


def sit_key(m, t, ease="sine", hip=2.15, lean=-6.0, turn=0.0, neck=(4, 0, 0), right=None, left=None):
    joints = dict(root=(lean, turn, 0), rHip=J((52 - lean * 0.5, -turn, 4)), lHip=J((52 - lean * 0.5, -turn, -4)))
    off = (0.0, hip - 2.0, 0.0)
    r = right(joints, off) if callable(right) else (right if right is not None else J((18, 0, 8)))
    lv = left(joints, off) if callable(left) else (left if left is not None else J((18, 0, -8)))
    m.key(round(t, 4), ease, offset=off, neck=neck, rShoulder=r, lShoulder=lv, **joints)


def on_top(side, height, ahead=1.9, across=0.6):
    """A hand flat on the table or desk in front (the character's frame), `height` its top over the floor."""
    return lambda j, o: body_reach(side, j, o, (side * across, height + 0.45, -ahead), direction=(-side * 0.1, -0.5, -0.85))


def look_up(pos, yaw, cam, eye=4.6):
    """(neck pitch, neck yaw, root turn) that turn a head at `pos` (x, z) facing `yaw` up into the camera at `cam`."""
    want = facing(pos, (cam[0], cam[2]))
    d = (want - yaw + 180) % 360 - 180
    dist = math.hypot(cam[0] - pos[0], cam[2] - pos[1])
    pitch = math.degrees(math.atan2(cam[1] - eye, max(dist, 1.0)))
    body = max(-60.0, min(60.0, d * 0.5))
    return max(-40.0, min(60.0, pitch)), max(-75.0, min(75.0, d - body)), body


# The watch: the watcher at the console, and the other one beside him -------------------------------------------

SEAT_W, SEAT_O = (-64.3, -63.5), (-64.3, -69.5)  # (sat back in the chairs: turning, a knee met the console)
KEYS = (-61.6, 3.5, -64.6)


def local(seat, point):
    """A point in the set's space in the frame of someone seated at `seat` facing the feeds (+x, yaw -90)."""
    return (point[2] - seat[1], point[1], -(point[0] - seat[0]))  # (facing +x, the right hand is +z)


def desk_hand(seat, side):
    return lambda j, o: body_reach(side, j, o, local(seat, (seat[0] + 2.0, 3.95, seat[1] + 0.6 * side)),
                                   direction=(0.0, -0.5, -0.85))


def key_hand(seat, up=0.4):
    return lambda j, o: body_reach(1, j, o, local(seat, (KEYS[0], KEYS[1] + up, KEYS[2])), direction=(0.0, -0.6, -0.8))


w = Motion("IntroAgency_watcher", LENGTH, note="The Agency intro: the one at the console, on the night watch.")
sit_key(w, 0.0, lean=6, neck=(4, 2, 0), right=desk_hand(SEAT_W, 1), left=desk_hand(SEAT_W, -1))
for t in [f[0] for f in FEEDS] + [EVIDENCE[0] - 0.1]:  # (a bored click to the next camera)
    sit_key(w, t - 0.25, lean=2, neck=(6, 0, 0), right=key_hand(SEAT_W), left=desk_hand(SEAT_W, -1))
    sit_key(w, t - 0.05, "linear", lean=2, neck=(6, 0, 0), right=key_hand(SEAT_W, 0.22), left=desk_hand(SEAT_W, -1))
    sit_key(w, t + 0.15, "sine", lean=4, neck=(6, 2, 0), right=desk_hand(SEAT_W, 1), left=desk_hand(SEAT_W, -1))
sit_key(w, 7.2, lean=12, neck=(8, -6, 6), right=desk_hand(SEAT_W, 1), left=desk_hand(SEAT_W, -1))  # (sat back, a long breath)
sit_key(w, 7.9, lean=4, neck=(5, 0, 0), right=desk_hand(SEAT_W, 1), left=desk_hand(SEAT_W, -1))
sit_key(w, EVIDENCE[0] + 0.6, lean=-6, neck=(12, 0, 0), right=desk_hand(SEAT_W, 1), left=desk_hand(SEAT_W, -1))
sit_key(w, DROP - 0.05, lean=-8, neck=(12, 2, 0), right=desk_hand(SEAT_W, 1), left=desk_hand(SEAT_W, -1))
sit_key(w, DROP + 0.15, "out", lean=0, neck=(16, 0, 0), right=desk_hand(SEAT_W, 1), left=desk_hand(SEAT_W, -1))  # (a start)
sit_key(w, CUTS[6] + 0.4, lean=-16, neck=(10, 0, 0), right=desk_hand(SEAT_W, 1), left=desk_hand(SEAT_W, -1))  # (in at it)
for t in (CUTS[6] + 0.7, CUTS[6] + 0.95):  # (running the tape back)
    sit_key(w, t, "linear", lean=-14, neck=(8, 0, 0), right=key_hand(SEAT_W, 0.22), left=desk_hand(SEAT_W, -1))
    sit_key(w, t + 0.12, "linear", lean=-14, neck=(8, 0, 0), right=key_hand(SEAT_W), left=desk_hand(SEAT_W, -1))
sit_key(w, REPLAY[1] - 0.2, lean=-14, neck=(10, 0, 0), right=key_hand(SEAT_W, 0.7), left=desk_hand(SEAT_W, -1))
# the alarm: the hand up, and slammed down on the console
sit_key(w, ALARM - 0.18, "out", lean=-6, neck=(4, -8, 0), right=key_hand(SEAT_W, 1.5), left=desk_hand(SEAT_W, -1))
sit_key(w, ALARM, "snap", lean=-14, neck=(-4, -6, 0), right=key_hand(SEAT_W, 0.15), left=desk_hand(SEAT_W, -1))
sit_key(w, ALARM + 0.5, "sine", lean=-10, neck=(10, 0, 0), right=key_hand(SEAT_W, 0.25), left=desk_hand(SEAT_W, -1))
sit_key(w, LENGTH, "sine", lean=-12, neck=(12, 2, 0), right=key_hand(SEAT_W, 0.25), left=desk_hand(SEAT_W, -1))
soft(w, head=2.8, arms=2.6)
alive(w, 0.35, seed=91)
w.build()

FOLD = dict(right=J((40, 0, -38), (-0.3, 0.1, -0.22)), left=J((38, 0, 36), (0.3, 0.1, -0.22)))
o = Motion("IntroAgency_seated", LENGTH, note="The Agency intro: the other one on the night watch.")
sit_key(o, 0.0, lean=10, neck=(6, 0, 0), **FOLD)  # (sat back, arms folded, half asleep)
sit_key(o, 4.0, lean=11, neck=(-6, 0, 4), **FOLD)
sit_key(o, DROP + 0.1, lean=10, neck=(-4, 0, 4), **FOLD)
sit_key(o, DROP + 0.45, "out", lean=-14, neck=(10, 4, 0), right=desk_hand(SEAT_O, 1), left=desk_hand(SEAT_O, -1))  # (awake)
sit_key(o, ALARM + 0.1, lean=-14, neck=(10, 4, 0), right=desk_hand(SEAT_O, 1), left=desk_hand(SEAT_O, -1))
sit_key(o, ALARM + 0.5, "out", lean=-6, neck=(4, 30, 0), right=desk_hand(SEAT_O, 1), left=desk_hand(SEAT_O, -1))  # (to him)
sit_key(o, LENGTH, "sine", lean=-8, neck=(8, 12, 0), right=desk_hand(SEAT_O, 1), left=desk_hand(SEAT_O, -1))
soft(o, head=2.8, arms=2.6)
alive(o, 0.35, seed=92)
o.build()

# The rest of the building -----------------------------------------------------------------------------------
# (slot, room, (x, z), yaw, what they are doing). Yaw 0 faces -z.
PEOPLE = [
    ("everyone:2", "break", (64.75, -50.3), 0.0, "table"),  # at the table (66, -53), across from each other
    ("everyone:3", "break", (67.25, -55.7), 180.0, "table"),
    ("everyone:4", "break", (93.6, -66.0), -90.0, "coffee"),  # at the coffee machine
    ("everyone:5", "break", (55.6, -65.4), 90.0, "vending"),  # at the vending machines
    ("everyone:6", "night", (62.0, -34.65), 180.0, "desk"),  # working late at the desk (62, -31.75)
    ("everyone:7", "night", (75.0, -20.4), 0.0, "board"),  # at the whiteboard (75, -24)
    ("everyone:8", "copy", (6.0, -67.8), 0.0, "copier"),  # at the photocopier (6, -71.4)
    ("everyone:9", "bullpen", (-88.0, 42.8), 180.0, "table"),  # at the squad table (-86, 46)
    ("everyone:10", "bullpen", (-84.0, 49.2), 0.0, "table"),
    ("everyone:11", "bullpen", (-72.6, 40.5), 90.0, "board"),  # at its whiteboard (-76, 40.5)
]
LOOK_AT = {room: t0 for t0, _, room in LOOKS}
STAND = dict(rHip=J((0, 0, 2)), lHip=J((0, 0, -2)))


def person(k, slot, room, pos, yaw, doing):
    """Someone elsewhere in the building at night, at what they are doing; when the alarm goes and the beacons turn,
    they stop and look up into the room's camera."""
    rng = random.Random(1700 + k * 13)
    m = Motion(f"IntroAgency_{slot.replace(':', '')}", LENGTH, note="The Agency intro: someone elsewhere in the building.")
    cam = CAMS[room][0]
    seated = doing in ("table", "desk")
    top = 2.8 if doing == "table" else 2.9
    hip = 2.0 if doing == "table" else 2.15
    t = 0.0
    if seated:
        def pose(tt, ease="sine", neck=(-6, 0, 0), sip=False):
            sit_key(m, tt, ease, hip=hip, lean=-8, neck=neck,
                    right=reach(1, (MOUTH[0] + 0.1, MOUTH[1] - 0.05, MOUTH[2] - 0.1)) if sip else on_top(1, top),
                    left=on_top(-1, top))
        while t < LOOK_AT[room] - 0.2:
            talk = rng.uniform(-14, 14)
            pose(t, neck=(-4 + 6 * math.sin(t * 2.3 + k), talk, 3 * math.sin(t + k)), sip=doing == "table" and rng.random() < 0.3)
            t += rng.uniform(0.7, 1.2)
        pose(LOOK_AT[room] - 0.1, neck=(-4, 0, 0))
    else:
        if doing == "coffee":
            work = [reach(1, (0.3, 0.9, -1.5), direction=(-0.2, -0.1, -0.95)), reach(1, MOUTH)]  # (the cup at the machine)
        elif doing == "vending":
            work = [reach(1, (0.25, 1.35, -1.4), direction=(-0.2, 0.3, -0.95)), reach(1, (0.35, 1.2, -1.35))]
        elif doing == "board":
            work = [reach(1, (0.25, 1.7, -1.35), direction=(-0.1, 0.4, -0.9)), reach(1, (0.75, 1.5, -1.3), direction=(0.2, 0.3, -0.9))]
        else:  # the copier: both hands on its lid
            work = [reach(1, (0.45, -0.1, -1.25), direction=(-0.1, -0.6, -0.8)), reach(1, (0.5, 0.0, -1.2), direction=(-0.1, -0.5, -0.85))]
        left = reach(-1, (-0.45, -0.1, -1.25), direction=(0.1, -0.6, -0.8)) if doing == "copier" else J((6, 0, -5))
        i = 0
        while t < LOOK_AT[room] - 0.2:
            m.key(t, "sine", root=(-4, 0, 0), neck=(-8 + 10 * (i % 2 if doing in ("board", "vending") else 0), 4 * math.sin(t), 0),
                  rShoulder=work[i % 2], lShoulder=left, **STAND)
            t += rng.uniform(0.6, 1.1)
            i += 1
        m.key(LOOK_AT[room] - 0.1, root=(-3, 0, 0), neck=(-4, 0, 0), rShoulder=work[0], lShoulder=left, **STAND)
    # the alarm: stopped; the head (and the body) turned up into the camera, a beat after the cut to them
    pitch, nyaw, body = look_up(pos, yaw, cam, eye=4.4 if seated else 4.8)
    when = LOOK_AT[room] + 0.15 + rng.uniform(0.0, 0.2)
    if seated:
        sit_key(m, when, "out", hip=hip, lean=-2, turn=body * 0.4, neck=(pitch, nyaw + body * 0.6, 0),
                right=on_top(1, top), left=on_top(-1, top))
        sit_key(m, LENGTH, "sine", hip=hip, lean=-2, turn=body * 0.4, neck=(pitch, nyaw + body * 0.6, 2),
                right=on_top(1, top), left=on_top(-1, top))
    else:
        m.key(when, "out", root=(-1, body, 0), neck=(pitch, nyaw, 0), rShoulder=J((6, 0, 5)), lShoulder=J((6, 0, -5)), **STAND)
        m.key(LENGTH, "sine", root=(-1, body, 0), neck=(pitch, nyaw, 2), rShoulder=J((6, 0, 5)), lShoulder=J((6, 0, -5)), **STAND)
        m.plant(stance=0.06)
    soft(m, head=2.8, arms=2.6)
    alive(m, 0.4, seed=200 + k)
    m.build()
    return m.name


CLIPS = [person(k, *p) for k, p in enumerate(PEOPLE)]

# The figure: on the replay, lifting the Manual off the evidence counter and walking off; and on the floor upstairs,
# walking away down the aisle with it, stopping, its head turning back to the camera. A stand-in, never a player's
# face (its back to the camera).
CHEST = J((44, 0, -30), (-0.25, 0.1, -0.2))
fig = Motion("IntroAgency_figure", LENGTH, note="The Agency intro: the figure on the replay.")
FREACH = body_reach(1, dict(root=(-14, 0, 0)), (0, 0, 0), (0.0, COUNTER_BOOK[1] - 14.0 + 0.75, -2.85), direction=(0.0, -0.35, -0.95))
LIFT = body_reach(1, dict(root=(-9, 0, 0)), (0, 0, 0), (0.0, COUNTER_BOOK[1] - 14.0 + 1.6, -2.3), direction=(0.0, 0.1, -1.0))
fig.key(0.0, root=(-14, 0, 0), neck=(-24, 0, 0), rShoulder=FREACH, lShoulder=J((6, 0, -5)))
fig.key(REPLAY[0] + 0.5, "sine", root=(-14, 0, 0), neck=(-24, 0, 0), rShoulder=FREACH, lShoulder=J((6, 0, -5)))
fig.key(REPLAY[0] + 0.7, "out", root=(-9, 0, 0), neck=(-18, 0, 0), rShoulder=LIFT, lShoulder=J((6, 0, -5)))  # (up off it)
fig.key(REPLAY[0] + 0.9, "sine", root=(-4, 0, 0), neck=(-10, 0, 0), rShoulder=CHEST, lShoulder=J((6, 0, -5)))
fig.key(REPLAY[0] + 1.25, "sine", root=(-3, 0, 0), neck=(-6, 30, 0), rShoulder=CHEST, lShoulder=J((6, 0, -5)))
fig.key(LENGTH, root=(-3, 0, 0), neck=(-6, 0, 0), rShoulder=CHEST, lShoulder=J((6, 0, -5)))
walking(fig, REPLAY[0] + 1.3, REPLAY[1], speed=3.4)
fig.plant(None, REPLAY[0] + 1.3, stance=0.06)
fig.plant(REPLAY[1], None, stance=0.06)
soft(fig, head=2.6, arms=2.6)
fig.build()

fig2 = Motion("IntroAgency_figure2", LENGTH, note="The Agency intro: the figure walking away upstairs.")
WALK2 = (CORRIDOR[0] - 1.0, FIG_TURN - 0.4)
fig2.key(0.0, root=(-3, 0, 0), neck=(-6, 0, 0), rShoulder=CHEST, lShoulder=J((6, 0, -5)))
fig2.key(WALK2[1] + 0.2, "in", root=(-2, 0, 0), neck=(-4, 0, 0), rShoulder=CHEST, lShoulder=J((6, 0, -5)))  # (it stops)
fig2.key(FIG_TURN, "sine", root=(-2, 0, 0), neck=(-4, 0, 0), rShoulder=CHEST, lShoulder=J((6, 0, -5)))
fig2.key(FIG_TURN + 0.9, "sine", root=(-1, -30, 0), neck=(6, -70, 0), rShoulder=CHEST, lShoulder=J((6, 0, -5)))  # (the head round)
fig2.key(LENGTH, "sine", root=(-1, -32, 0), neck=(7, -72, 0), rShoulder=CHEST, lShoulder=J((6, 0, -5)))
walking(fig2, WALK2[0], WALK2[1], speed=math.hypot(FIG2_TO[0] - FIG2_FROM[0], FIG2_TO[1] - FIG2_FROM[1]) / (WALK2[1] - WALK2[0]))
fig2.plant(None, WALK2[0], stance=0.06)
fig2.plant(WALK2[1], None, stance=0.06)
soft(fig2, head=2.4, arms=2.6)
fig2.build()

# The shot -------------------------------------------------------------------------------------------------

shot = Shot(NAME, "Agency", LENGTH, note="Agency intro: night watch.", skippable=True, mood="TaskForceHQ")
shot.own = True  # players in their own avatars (the owner, 2026-10-28)
shot.allow = {}
wa = shot.actor("watcher", w)
wa.mark(0.0, (SEAT_W[0], 0.0, SEAT_W[1]), -90.0)
oa = shot.actor("everyone:1", o)
oa.mark(0.0, (SEAT_O[0], 0.0, SEAT_O[1]), -90.0)
shot.allow["watcher"] = shot.allow["everyone:1"] = ["OfficeChair"]
for (slot, room, pos, yaw, doing), clip in zip(PEOPLE, CLIPS):
    a = shot.actor(slot, clip=clip)
    a.mark(0.0, (pos[0], 0.0, pos[1]), yaw)
    if doing == "table":
        shot.allow[slot] = ["Chair", "solid"]  # (the check takes a table for a block to the floor: the knees go under it)
        if room == "break":
            a.hold("Teacup", "Right Arm", (0.0, -1.05, -0.15), (0, 0, 0))
    elif doing == "desk":
        shot.allow[slot] = ["OfficeChair", "Desk"]
    elif doing == "coffee":
        a.hold("Teacup", "Right Arm", (0.0, -1.05, -0.15), (0, 0, 0))

figure = shot.actor("extra:1", fig, extra=True, show=REPLAY)
figure.mark(0.0, (FIGURE[0], 14.0, FIGURE[1]), 180.0)
figure.mark(REPLAY[0] + 0.7, (FIGURE[0], 14.0, FIGURE[1]), 180.0)
figure.mark(REPLAY[0] + 1.0, (FIGURE[0], 14.0, FIGURE[1] - 1.0), 180.0)  # (a step back from the counter...)
figure.mark(REPLAY[0] + 1.3, (FIGURE[0], 14.0, FIGURE[1] - 1.0), 90.0)  # (...and turned away, to the door)
figure.mark(REPLAY[1], (FIGURE[0] - 3.4 * (REPLAY[1] - REPLAY[0] - 1.3), 14.0, FIGURE[1] - 1.0), 90.0, "linear")
figure.hold("Grimoire", "Right Arm", (0.0, -1.05, -0.35), (80, 0, 0), t0=REPLAY[0] + 0.55, t1=REPLAY[1])
yaw2 = facing(FIG2_FROM, FIG2_TO)
figure2 = shot.actor("extra:2", fig2, extra=True, show=CORRIDOR)
figure2.mark(0.0, (FIG2_FROM[0], 14.0, FIG2_FROM[1]), yaw2)
figure2.mark(WALK2[0], (FIG2_FROM[0], 14.0, FIG2_FROM[1]), yaw2)
figure2.mark(WALK2[1], (FIG2_TO[0], 14.0, FIG2_TO[1]), yaw2, "linear")
figure2.mark(LENGTH, (FIG2_TO[0], 14.0, FIG2_TO[1]), yaw2)
figure2.hold("Grimoire", "Right Arm", (0.0, -1.05, -0.35), (80, 0, 0))

# The Manual on the evidence counter: live on the feed until it breaks up; on the replay, until the figure lifts it.
for t0, t1 in ((0.0, DROP), (REPLAY[0], REPLAY[0] + 0.55)):
    on_counter = shot.prop("Grimoire", show=(t0, t1))
    on_counter.at(0.0, COUNTER_BOOK, (0, 90, 0))
    on_counter.at(LENGTH, COUNTER_BOOK, (0, 90, 0))

# The cameras. In the security office, held by hand and moving; the building's own cameras locked, black and white.


def feed(t0, t1, room, zoom=0.0):
    eye, look, fov, label = CAMS[room]
    shot.subjects.append((t0, t1, None, True))
    shot.cam(t0, eye, look, fov=fov, cut=True)
    shot.cam(t1, eye, look, fov=fov - zoom, ease="linear")
    shot.event(t0, "fx", name="cctv", dur=round(t1 - t0, 3), label=label)
    shot.event(t0, "fx", name="focus")


# A: the security office, dark: the two at the wall of feeds.
framing.dolly(shot, 0.0, CUTS[0], (-80.0, 7.6, -64.6), (-77.6, 7.0, -65.2), (-61.5, 5.6, -66.5), fov0=54, fov1=48, shake=0.4,
              seed=1, cut=False)
for t0, t1, room in FEEDS:  # B-E: flicking through the cameras
    feed(t0, t1, room)
# F: the watcher, bored, from the end of the console (the monitors leave no room in front of them).
shot.pan(CUTS[4], CUTS[5], "watcher", (-61.8, 6.0, -60.4), aim="Head", dy=0.0, fov=52, cut=True, drift=(0.0, -0.1, -0.2),
         operator=True, seed=3, shake=0.35, fov_to=50, ease_move=True)
feed(EVIDENCE[0], EVIDENCE[1], "evidence")  # G: the evidence room
# H: the two at the console jolt and lean in: from the end of the console again, pushing in.
framing.dolly(shot, CUTS[6], CUTS[7], (-61.9, 4.9, -60.3), (-62.0, 4.8, -60.9), (-64.6, 4.3, -65.6), fov0=58, fov1=52,
              shake=0.9, seed=4)
feed(REPLAY[0], REPLAY[1], "evidence")  # I: the replay
# J: the watcher slams the alarm: from behind them, the arm up against the feeds and down, the red coming on.
framing.dolly(shot, CUTS[8], CUTS[9], (-71.0, 6.8, -57.5), (-69.6, 6.3, -58.6), (-62.5, 4.4, -65.0), fov0=52, fov1=46,
              roll0=-4.0, roll1=-7.0, shake=0.8, seed=5)
for t0, t1, room in LOOKS:  # K: room by room, everyone looks up into the lens
    feed(t0, t1, room, zoom=4.0)
feed(CORRIDOR[0], LENGTH, "corridor", zoom=10.0)  # L: the floor upstairs (the camera's zoom creeping in)
shot.event(CUTS[4], "fx", name="focus", slot="watcher", part="Head", radius=2.5, far=0.12, near=0.06)
for t in (0.0, CUTS[6], CUTS[8]):
    shot.event(t, "fx", name="focus")

# The light: the security office dark, the feeds' cold glow on the two at the console; the evidence counter lit; and
# from the alarm, a red beacon turning in every room (and on the faces). The grade: dark, cold.
shot.grade = (0.22, -0.1, -0.05, (226, 234, 255))
shot.light("spot", (-61.8, 7.6, -66.8), (-65.0, 4.8, -66.5), color=(150, 190, 255), brightness=1.4, range=10, angle=70,
           shadows=False, flicker=0.25)  # (the feeds on their faces)
shot.light("spot", (COUNTER_BOOK[0], 24.0, COUNTER_BOOK[2] - 1.0), (COUNTER_BOOK[0], 17.6, COUNTER_BOOK[2]),
           color=(225, 232, 255), brightness=1.6, range=12, angle=45)  # (the evidence counter, lit)
BEACONS = [(-62.5, 10.5, -73.5), (74.0, 10.5, -58.0), (68.0, 10.5, -26.0), (8.0, 10.5, -62.0), (-82.0, 10.5, 44.0),
           (-42.0, 24.5, -40.0)]
for b in BEACONS:
    shot.light("point", b, color=(255, 30, 30), brightness=1.6, range=24, shadows=False, flicker=0.8, show=(ALARM, BLACK))

# Sound and effects.
shot.event(0.0, "sfx", slot="mapServerHum")
shot.event(0.0, "sfx", slot="mapRainGlass")
shot.event(0.3, "title", lines=["BUREAU HEADQUARTERS", "Night watch, 03:12"], dur=1.8)
for t in [f[0] for f in FEEDS] + [EVIDENCE[0]]:
    shot.event(t - 0.05, "sfx", slot="uiClick")
for k, t in enumerate((DROP - 0.35, DROP - 0.2, DROP - 0.05)):  # (the evidence feed breaking up)
    shot.event(t, "fx", name="flash", r=230, g=230, b=230, strength=0.55 - 0.1 * k, dur=0.12)
shot.event(DROP - 0.35, "sfx", slot="glitch")
shot.event(DROP + 0.2, "sfx", slot="heartbeat")
shot.event(CUTS[6] + 0.7, "sfx", slot="uiClick")
shot.event(ALARM, "sfx", slot="slam")
shot.event(ALARM, "fx", name="flash", r=255, g=40, b=40, strength=0.4, dur=0.3)
shot.event(ALARM + 0.1, "sfx", slot="mapSirenFar")
for t in (FIG_TURN + 0.55, FIG_TURN + 0.7, FIG_TURN + 0.8):  # (its head turns... and the feed breaks up)
    shot.event(t, "fx", name="flash", r=235, g=235, b=235, strength=0.6, dur=0.1)
shot.event(FIG_TURN + 0.55, "sfx", slot="glitch")
shot.event(FIG_TURN + 0.85, "fx", name="black", hush=True)
shot.event(BLACK + 0.5, "card", key="case", dur=LENGTH - BLACK - 0.5)
