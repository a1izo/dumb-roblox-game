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
from cinema.acting import alive, body_reach, facing, soft, strike, walking
from cinema.shot import Shot
from emotes.kit import CHIN, MOUTH, reach
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


def sit_key(m, t, ease="sine", hip=2.15, lean=-6.0, turn=0.0, neck=(4, 0, 0), right=None, left=None, roll=0.0):
    joints = dict(root=(lean, turn, roll), rHip=J((52 - lean * 0.5, -turn, 4)), lHip=J((52 - lean * 0.5, -turn, -4)))
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
sit_key(w, 0.0, lean=8, turn=-3, roll=-3, neck=(2, -8, 0), right=desk_hand(SEAT_W, 1), left=desk_hand(SEAT_W, -1))
sit_key(w, 1.0, lean=9, turn=5, roll=2, neck=(8, 14, 3), right=desk_hand(SEAT_W, 1), left=desk_hand(SEAT_W, -1))  # (a look along)
for t in [f[0] for f in FEEDS] + [EVIDENCE[0] - 0.1]:  # (a bored click to the next camera)
    sit_key(w, t - 0.25, lean=2, neck=(6, 0, 0), right=key_hand(SEAT_W), left=desk_hand(SEAT_W, -1))
    sit_key(w, t - 0.05, "linear", lean=2, neck=(6, 0, 0), right=key_hand(SEAT_W, 0.22), left=desk_hand(SEAT_W, -1))
    sit_key(w, t + 0.15, "out", lean=1, neck=(9, 3, 0), right=desk_hand(SEAT_W, 1), left=desk_hand(SEAT_W, -1))  # (a peck)
    sit_key(w, t + 0.55, "sine", lean=6, roll=2 * math.sin(t * 3), neck=(5, -4 * math.sin(t * 2), 2), right=desk_hand(SEAT_W, 1),
            left=desk_hand(SEAT_W, -1))
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
sit_key(o, 0.0, lean=10, neck=(-6, 0, 4), **FOLD)  # (sat back, arms folded, nodding off)
sit_key(o, 1.45, "in", lean=12, roll=3, neck=(-30, 0, 9), **FOLD)
sit_key(o, 1.6, "snap", lean=5, roll=-1, neck=(10, -8, -2), **FOLD)  # (jerks awake)
sit_key(o, 2.1, "sine", lean=9, neck=(2, -2, 0), **FOLD)
sit_key(o, 6.6, "sine", lean=10, neck=(-8, 0, 4), **FOLD)
sit_key(o, 8.0, "in", lean=12, roll=3, neck=(-28, 0, 8), **FOLD)
sit_key(o, 8.15, "snap", lean=6, roll=-1, neck=(8, -6, -2), **FOLD)
sit_key(o, 8.6, "sine", lean=9, neck=(-2, 0, 3), **FOLD)
sit_key(o, DROP + 0.1, lean=10, neck=(-4, 0, 4), **FOLD)
sit_key(o, DROP + 0.4, "out", lean=-18, neck=(10, 4, 0), right=desk_hand(SEAT_O, 1), left=desk_hand(SEAT_O, -1))  # (awake)
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
FEED_AT = {room: t0 for t0, _, room in FEEDS}
STAND = dict(rHip=J((0, 0, 2)), lHip=J((0, 0, -2)))
DOWN = (J((6, 0, 5)), J((6, 0, -5)))  # (arms hanging)


def fist(side, p, d=None):
    """A hand on `p` given in an upright standing body's torso frame (kit.reach's), for a body posed any way."""
    return lambda j, o: body_reach(side, j, o, (p[0], p[1] + 3.0, p[2]), direction=d)


def stand_key(m, t, ease="sine", lean=-3.0, turn=0.0, roll=0.0, neck=(-6, 0, 0), right=DOWN[0], left=DOWN[1]):
    joints = dict(root=(lean, turn, roll), **STAND)
    r = right(joints, (0, 0, 0)) if callable(right) else right
    lv = left(joints, (0, 0, 0)) if callable(left) else left
    m.key(round(t, 4), ease, neck=neck, rShoulder=r, lShoulder=lv, **joints)


def act(m, slot, f, top, hip):
    """Each one's own business, played big while their room's camera is on them (from f, for about 1.2 s)."""
    sk = lambda t, e="sine", **kw: sit_key(m, t, e, hip=hip, **kw)  # noqa: E731
    tbl = lambda side, up=0.0, ahead=1.9, across=0.6: on_top(side, top + up, ahead, across)  # noqa: E731
    at = lambda side, x, y, z, d=(0.0, 0.2, -1.0): (  # noqa: E731
        lambda j, o: body_reach(side, j, o, (x, hip + y, z), direction=d))  # (seated: y over the hips)
    if slot == "everyone:2":  # break room: hears something funny, and laughs
        sk(0.0, lean=-10, neck=(-6, 10, 0), right=tbl(1), left=tbl(-1))
        sk(f - 0.5, lean=-12, neck=(-8, 12, 2), right=tbl(1), left=tbl(-1))
        sk(f - 0.1, "sine", lean=-15, neck=(-14, 4, 0), right=tbl(1), left=tbl(-1))  # (in)
        sk(f + 0.15, "out", lean=10, roll=-3, neck=(24, -6, 6), right=at(1, 0.35, 1.1, -1.0), left=tbl(-1, 0.25))  # (back)
        for i, tt in enumerate((0.32, 0.47, 0.62, 0.8)):  # (shoulders shaking)
            sk(f + tt, "sine", lean=(6, 11, 5, 9)[i], roll=-3 + i, neck=((16, 23, 14, 18)[i], -6, 6), right=at(1, 0.35, 1.1, -1.0),
               left=tbl(-1, (0.0, 0.25, 0.0, 0.2)[i]))
        sk(f + 1.15, "sine", lean=-2, neck=(4, 8, 2), right=at(1, 0.1, 1.3, -0.75, (0, 1, -0.3)), left=tbl(-1))  # (a sip)
        sk(f + 1.9, "sine", lean=-8, neck=(-6, 10, 0), right=tbl(1), left=tbl(-1))
        sk(LOOK_AT["break"] - 0.4, lean=-9, neck=(-4, 14, 0), right=tbl(1), left=tbl(-1))
    elif slot == "everyone:3":  # break room: telling the story, both hands going
        sk(0.0, lean=-10, neck=(-4, 0, 0), right=tbl(1), left=tbl(-1))
        sk(f - 0.55, "sine", lean=-12, neck=(0, 6, 0), right=at(1, 0.55, 1.5, -1.4), left=tbl(-1))
        sk(f - 0.2, "snap", lean=-14, neck=(-10, 4, 0), right=at(1, 0.6, 1.1, -1.5), left=tbl(-1))  # (a beat on the word)
        sk(f + 0.1, "out", lean=-10, neck=(6, -8, 0), right=at(1, 0.8, 1.6, -1.35), left=tbl(-1))
        sk(f + 0.45, "out", lean=-16, neck=(10, 0, 0), right=at(1, 0.95, 1.5, -1.25, (0.6, 0.2, -0.8)),
           left=at(-1, -0.95, 1.5, -1.25, (-0.6, 0.2, -0.8)))  # ("and then!")
        sk(f + 0.85, "sine", lean=-14, neck=(12, 2, 3), right=at(1, 0.9, 1.45, -1.3, (0.6, 0.2, -0.8)),
           left=at(-1, -0.9, 1.45, -1.3, (-0.6, 0.2, -0.8)))
        sk(f + 1.3, "sine", lean=-6, neck=(2, 0, 0), right=tbl(1), left=tbl(-1))
        sk(LOOK_AT["break"] - 0.4, lean=-8, neck=(-2, 4, 0), right=at(1, 0.5, 1.3, -1.4), left=tbl(-1))
    elif slot == "everyone:6":  # night desk: typing, then the long stretch
        sk(0.0, lean=-10, neck=(-12, 0, 0), right=tbl(1), left=tbl(-1))
        for i, tt in enumerate((-0.6, -0.45, -0.3, -0.15)):
            sk(f + tt, "linear", lean=-10, neck=(-12, 0, 0), right=tbl(1, 0.12 * (i % 2)), left=tbl(-1, 0.12 * ((i + 1) % 2)))
        sk(f + 0.15, "sine", lean=-4, neck=(-2, 0, 0), right=J((100, 0, 30)), left=J((100, 0, -30)))
        sk(f + 0.55, "out", lean=12, roll=2, neck=(22, 0, 6), right=J((172, 0, 28)), left=J((172, 0, -28)))  # (the stretch)
        sk(f + 0.95, "sine", lean=14, roll=-2, neck=(24, 0, -4), right=J((176, 0, 34)), left=J((176, 0, -34)))
        sk(f + 1.4, "sine", lean=6, neck=(8, 0, 0), right=J((120, 0, 40)), left=J((120, 0, -40)))
        sk(f + 2.0, "sine", lean=-10, neck=(-12, 0, 0), right=tbl(1), left=tbl(-1))
        for i, tt in enumerate((-0.6, -0.45, -0.3)):
            sk(LOOK_AT["night"] + tt, "linear", lean=-10, neck=(-12, 0, 0), right=tbl(1, 0.12 * (i % 2)), left=tbl(-1))
    elif slot == "everyone:9":  # bullpen: jabbing at the papers, then up at the other one
        sk(0.0, lean=-10, neck=(-14, 0, 0), right=tbl(1), left=tbl(-1))
        sk(f - 0.45, "sine", lean=-18, neck=(-16, 0, 0), right=at(1, 0.2, 1.05, -2.5, (0, -0.3, -1)), left=tbl(-1))
        for tt in (-0.1, 0.12, 0.34):  # (taps)
            strike(m, f + tt, dict(rShoulder=at(1, 0.2, 1.35, -2.4, (0, -0.3, -1))(dict(root=(-18, 0, 0)), (0, hip - 2, 0))),
                   dict(rShoulder=at(1, 0.2, 1.0, -2.5, (0, -0.3, -1))(dict(root=(-18, 0, 0)), (0, hip - 2, 0))), antic=0.07,
                   travel=0.05, over=0.1, settle=0.08)
        sk(f + 0.65, "out", lean=-8, neck=(8, -16, 0), right=at(1, 0.75, 1.55, -1.4), left=tbl(-1))  # ("see?")
        sk(f + 1.05, "sine", lean=-9, neck=(4, -14, 3), right=at(1, 0.7, 1.4, -1.45), left=tbl(-1))
        sk(f + 1.6, "sine", lean=-12, neck=(-10, 0, 0), right=tbl(1), left=tbl(-1))
        sk(LOOK_AT["bullpen"] - 0.4, lean=-14, neck=(-14, 0, 0), right=tbl(1), left=tbl(-1))
    elif slot == "everyone:10":  # bullpen: sat back, arms folded, shaking the head, then a shrug
        sk(0.0, lean=8, neck=(-2, 0, 0), **FOLD)
        for i, tt in enumerate((-0.3, -0.1, 0.1, 0.3, 0.5)):
            sk(f + tt, "sine", lean=8, neck=(-4, (-16, 14, -12, 10, 0)[i], 0), **FOLD)
        sk(f + 0.75, "out", lean=2, roll=2, neck=(6, -4, 10), right=at(1, 0.95, 1.2, -1.15, (0.4, 0.3, -0.85)),
           left=at(-1, -0.95, 1.2, -1.15, (-0.4, 0.3, -0.85)))  # (a shrug)
        sk(f + 1.15, "sine", lean=4, neck=(4, -4, 8), right=at(1, 0.9, 1.15, -1.2, (0.4, 0.3, -0.85)),
           left=at(-1, -0.9, 1.15, -1.2, (-0.4, 0.3, -0.85)))
        sk(f + 1.7, "sine", lean=8, neck=(-2, 0, 0), **FOLD)
        sk(LOOK_AT["bullpen"] - 0.4, lean=8, neck=(-4, 6, 0), **FOLD)
    elif slot == "everyone:4":  # break room, at the coffee machine: the cup up, a long drink, a look round
        machine = fist(1, (0.3, 0.9, -1.5), (-0.2, -0.1, -0.95))
        stand_key(m, 0.0, lean=-6, roll=3, neck=(-10, 0, 0), right=machine)
        stand_key(m, f - 0.45, "sine", lean=-8, roll=3, neck=(-14, 0, 0), right=fist(1, (0.3, 0.75, -1.45)))  # (the cup)
        stand_key(m, f + 0.15, "out", lean=5, roll=-3, neck=(10, 0, 0), right=fist(1, MOUTH))  # (up)
        stand_key(m, f + 0.6, "sine", lean=8, roll=-4, neck=(22, 0, 4), right=fist(1, (0.05, 1.3, -0.65)))  # (a long drink)
        stand_key(m, f + 1.05, "out", lean=0, turn=-8, roll=-2, neck=(-2, -30, 0), right=fist(1, (0.35, 0.5, -0.8)))  # (a look)
        stand_key(m, f + 1.6, "sine", lean=-2, turn=-6, roll=2, neck=(-4, -24, 0), right=fist(1, (0.35, 0.5, -0.8)))
        stand_key(m, LOOK_AT["break"] - 0.4, lean=-2, roll=3, neck=(-6, 0, 0), right=fist(1, (0.35, 0.6, -0.8)))
    elif slot == "everyone:5":  # break room, the vending machine: a button, down for the drop, up with it
        stand_key(m, 0.0, lean=-3, roll=-3, neck=(4, 0, 0), right=DOWN[0])
        strike(m, f - 0.55, dict(rShoulder=reach(1, (0.25, 1.2, -1.0))), dict(rShoulder=reach(1, (0.25, 1.35, -1.4),
               (-0.2, 0.3, -0.95))), antic=0.15, travel=0.06, over=0.15, settle=0.15)
        stand_key(m, f - 0.2, "sine", lean=-14, neck=(-10, 0, 0), right=fist(1, (0.3, 0.6, -1.2)))
        stand_key(m, f + 0.2, "sine", lean=-42, roll=2, neck=(8, 0, 0), right=fist(1, (0.2, -1.25, -1.6), (0, -0.8, -0.6)),
                  left=fist(-1, (-0.5, -1.0, -0.6), (0, -1, 0)))  # (down to the tray, a hand on the knee)
        stand_key(m, f + 0.5, "sine", lean=-44, roll=-2, neck=(10, 4, 0), right=fist(1, (0.4, -1.35, -1.7), (0, -0.8, -0.6)),
                  left=fist(-1, (-0.5, -1.0, -0.6), (0, -1, 0)))
        stand_key(m, f + 0.9, "out", lean=4, roll=-2, neck=(-4, 0, 0), right=fist(1, (0.2, 0.55, -0.8)))  # (up with it)
        stand_key(m, f + 1.25, "sine", lean=0, turn=10, neck=(-20, 14, 0), right=fist(1, (0.15, 0.7, -0.9)))  # (a look at it)
        stand_key(m, f + 1.9, "sine", lean=-1, turn=6, roll=3, neck=(-14, 8, 0), right=fist(1, (0.2, 0.55, -0.85)))
        stand_key(m, LOOK_AT["break"] - 0.4, lean=-2, turn=4, roll=3, neck=(-10, 0, 0), right=fist(1, (0.2, 0.55, -0.85)))
    elif slot in ("everyone:7", "everyone:11"):  # at a whiteboard: writing hard, a step back to look; or presenting
        board = lambda x, y: fist(1, (x, y, -1.35), (-0.1, 0.3, -0.9))  # noqa: E731
        if slot == "everyone:7":
            stand_key(m, 0.0, lean=-4, neck=(4, 0, 0), right=board(0.1, 1.7))
            for i, tt in enumerate((-0.6, -0.45, -0.3, -0.15, 0.0, 0.15, 0.3)):  # (writing, fast)
                stand_key(m, f + tt, "linear", lean=-4, roll=-2 + 0.6 * i, neck=(4, -3 + i, 0),
                          right=board(0.1 + 0.12 * i, 1.72 - 0.14 * (i % 2)))
            stand_key(m, f + 0.6, "out", lean=6, roll=3, neck=(10, 6, -8), right=fist(1, (0.4, 0.45, -0.9)),
                      left=J((20, 0, -40)))  # (back, a hand on the hip, the head on one side)
            stand_key(m, f + 1.0, "sine", lean=5, roll=3, neck=(8, 8, -10), right=fist(1, (0.1, 1.0, -0.75)), left=J((20, 0, -40)))
            stand_key(m, f + 1.5, "sine", lean=4, roll=2, neck=(8, 4, -6), right=fist(1, CHIN), left=J((20, 0, -40)))  # (marker to chin)
            stand_key(m, LOOK_AT["night"] - 0.4, lean=-4, neck=(4, 0, 0), right=board(0.5, 1.6))
            for i, tt in enumerate((-0.25, -0.1, 0.05)):
                stand_key(m, LOOK_AT["night"] + tt, "linear", lean=-4, neck=(4, 0, 0), right=board(0.5 + 0.12 * i, 1.6 - 0.1 * (i % 2)))
        else:
            stand_key(m, 0.0, lean=-2, neck=(6, 0, 0), right=board(0.45, 1.7))
            stand_key(m, f - 0.4, "out", lean=0, neck=(8, 0, 0), right=fist(1, (0.55, 1.95, -1.55)))  # (pointing up at it)
            stand_key(m, f + 0.05, "out", lean=2, turn=-12, roll=3, neck=(2, -34, 0), right=fist(1, (0.55, 1.95, -1.55)),
                      left=fist(-1, (-0.75, 0.55, -1.0), (-0.5, 0.2, -0.8)))  # (round to the table, an open hand)
            strike(m, f + 0.5, dict(rShoulder=reach(1, (0.6, 1.8, -1.2))), dict(rShoulder=reach(1, (0.55, 1.75, -1.5))), antic=0.1,
                   travel=0.05, over=0.15, settle=0.12)  # (a slap on the board)
            strike(m, f + 0.75, dict(rShoulder=reach(1, (0.6, 1.8, -1.2))), dict(rShoulder=reach(1, (0.55, 1.75, -1.5))), antic=0.08,
                   travel=0.05, over=0.15, settle=0.15)
            stand_key(m, f + 1.15, "sine", lean=0, turn=-10, roll=2, neck=(4, -30, 4), right=fist(1, (0.5, 1.6, -1.45)),
                      left=fist(-1, (-0.6, 0.5, -0.95)))
            stand_key(m, f + 1.8, "sine", lean=-2, turn=-4, neck=(6, -10, 0), right=board(0.45, 1.6))
            stand_key(m, LOOK_AT["bullpen"] - 0.4, lean=-2, neck=(6, 0, 0), right=board(0.4, 1.65))
    else:  # the copy room: a jam: the button jabbed, the head down on the lid, a look at the watch
        lid = lambda side, x=0.45: fist(side, (side * x, -0.1, -1.25), (-side * 0.1, -0.6, -0.8))  # noqa: E731
        stand_key(m, 0.0, lean=-8, neck=(-12, 0, 0), right=lid(1), left=lid(-1))
        stand_key(m, f - 0.5, "sine", lean=-8, roll=2, neck=(-14, 0, 0), right=lid(1), left=lid(-1))
        for tt in (-0.3, -0.05, 0.2):  # (jab, jab, jab)
            strike(m, f + tt, dict(rShoulder=reach(1, (0.55, 0.35, -1.05))), dict(rShoulder=reach(1, (0.6, 0.0, -1.3),
                   (0, -0.7, -0.7))), antic=0.08, travel=0.05, over=0.1, settle=0.08)
        stand_key(m, f + 0.55, "in", lean=-22, roll=4, neck=(-30, 0, 6), right=lid(1, 0.6), left=lid(-1, 0.6))  # (slumped on it)
        stand_key(m, f + 0.9, "sine", lean=-20, roll=4, neck=(-32, 0, 8), right=lid(1, 0.6), left=lid(-1, 0.6))
        stand_key(m, f + 1.3, "out", lean=-4, roll=-2, neck=(-24, -14, 0), right=lid(1),
                  left=fist(-1, (-0.15, 0.55, -0.8), (0.6, 0.0, -0.4)))  # (the watch)
        stand_key(m, f + 1.9, "sine", lean=-8, neck=(-12, 0, 0), right=lid(1), left=lid(-1))
        stand_key(m, LOOK_AT["copy"] - 0.4, lean=-9, roll=2, neck=(-14, 0, 0), right=lid(1), left=lid(-1))


def person(k, slot, room, pos, yaw, doing):
    """Someone elsewhere in the building at night, at their own business, played big while the feed is on them; when
    the alarm goes and the beacons turn, the head snaps up into the room's camera and the body follows."""
    m = Motion(f"IntroAgency_{slot.replace(':', '')}", LENGTH, note="The Agency intro: someone elsewhere in the building.")
    cam = CAMS[room][0]
    seated = doing in ("table", "desk")
    top = 2.8 if doing == "table" else 2.9
    hip = 2.0 if doing == "table" else 2.15
    act(m, slot, FEED_AT[room], top, hip)
    # the alarm: a flinch, the head up into the lens, the body after it; held, breathing
    pitch, nyaw, body = look_up(pos, yaw, cam, eye=4.4 if seated else 4.8)
    when = LOOK_AT[room] + 0.15 + 0.07 * (k % 3)
    if seated:
        hands = dict(right=on_top(1, top), left=on_top(-1, top))
        sit_key(m, when - 0.12, "out", hip=hip, lean=-12, neck=(-14, 0, 0), **hands)  # (a flinch)
        sit_key(m, when + 0.06, "snap", hip=hip, lean=0, turn=body * 0.15, neck=(pitch + 8, nyaw + body * 0.85, 0), **hands)
        sit_key(m, when + 0.4, "sine", hip=hip, lean=-3, turn=body * 0.4, neck=(pitch, nyaw + body * 0.6, 0), **hands)
        sit_key(m, LENGTH, "sine", hip=hip, lean=-2, turn=body * 0.4, neck=(pitch + 2, nyaw + body * 0.6, 4), **hands)
    else:
        stand_key(m, when - 0.12, "out", lean=-8, neck=(-14, 0, 0), right=J((24, 0, 14)), left=J((24, 0, -14)))  # (a flinch)
        stand_key(m, when + 0.06, "snap", lean=3, turn=body * 0.2, neck=(pitch + 8, nyaw + body * 0.8, 0), right=J((14, 0, 10)),
                  left=J((14, 0, -10)))
        stand_key(m, when + 0.45, "sine", lean=-1, turn=body, neck=(pitch, nyaw, 0), right=J((8, 0, 6)), left=J((8, 0, -6)))
        stand_key(m, LENGTH, "sine", lean=-1, turn=body, neck=(pitch + 2, nyaw, 4), right=J((6, 0, 5)), left=J((6, 0, -5)))
        m.plant(stance=0.06)
    soft(m, head=2.4, arms=2.2, head_damp=0.55, arm_damp=0.5)
    for t0, t1 in ((FEED_AT[room] - 0.8, FEED_AT[room] + 2.0), (LOOK_AT[room] - 0.8, BLACK)):  # (only while seen: size)
        alive(m, 0.7, seed=200 + k, t0=t0, t1=t1)
    m.build()
    return m.name


CLIPS = [person(k, *p) for k, p in enumerate(PEOPLE)]

# The figure: on the replay, lifting the Manual off the evidence counter and walking off; and on the floor upstairs,
# walking away down the aisle with it, stopping, its head turning back to the camera. A stand-in, never a player's
# face (its back to the camera).
CHEST = J((44, 0, -30), (-0.25, 0.1, -0.2))


def swing(m, t0, t1, speed, blend=0.35):
    """With the legs' walk: the free (left) arm swings, the book arm a little, the shoulders turn against the hips."""
    from gait import WALK

    period = WALK.period * (4.0 / speed) ** 0.5

    def fn(t, pose, off):
        if t <= t0 - blend or t >= t1 + blend:
            return
        u = min(1.0, (t - (t0 - blend)) / blend, ((t1 + blend) - t) / blend)
        w = u * u * (3 - 2 * u)
        a = math.sin(2 * math.pi * max(0.0, t - t0) / period)
        if "lShoulder" in pose:
            pose["lShoulder"][0] += w * 24 * a
        if "rShoulder" in pose:
            pose["rShoulder"][0] -= w * 5 * a
        if "root" in pose:
            pose["root"][1] += w * 4 * a
        if "neck" in pose:
            pose["neck"][1] -= w * 3 * a

    m.extra(fn)
    return m


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
swing(fig, REPLAY[0] + 1.3, REPLAY[1], speed=3.4)
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
swing(fig2, WALK2[0], WALK2[1], speed=math.hypot(FIG2_TO[0] - FIG2_FROM[0], FIG2_TO[1] - FIG2_FROM[1]) / (WALK2[1] - WALK2[0]))
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

# The cameras. In the security office, held by hand and moving; the building's own cameras black and white, PTZ units
# in their corners: they pan and zoom slowly over whoever is in the room, and crash-zoom when something happens.

SLAM = ALARM + 0.07  # (the camera punches in as the room goes red)
PTZ = {  # room: (look, fov) at the start of a feed, and where the slow pan and zoom end up
    "break": ((63.0, 3.0, -56.5), 38.0, (65.0, 3.2, -53.8), 32.0),
    "night": ((67.0, 3.0, -29.0), 40.0, (68.0, 3.0, -28.0), 35.0),
    "copy": ((6.5, 3.4, -67.5), 34.0, (6.3, 3.6, -68.0), 29.0),
    "bullpen": ((-82.0, 3.0, 44.0), 42.0, (-82.5, 3.0, 44.5), 37.0),
}
STAR = {"break": "everyone:2", "night": "everyone:6", "copy": "everyone:8", "bullpen": "everyone:10"}  # (crash-zoomed)


def feed(t0, t1, room, look=None, fov=None, keys=(), label=None):
    """A building camera over t0..t1, starting on `look`/`fov` and moved by `keys` [(t, look, fov, ease)]; it holds
    the last of them to the cut."""
    eye, base, base_fov, name = CAMS[room]
    look, fov = look or base, fov or base_fov
    shot.subjects.append((t0, t1, None, True))
    shot.cam(t0, eye, look, fov=fov, cut=True)
    for t, lk, fv, ease in keys:
        shot.cam(t, eye, lk, fov=fv, ease=ease)
    last = keys[-1] if keys else (t0, look, fov, "linear")
    if last[0] < t1 - 1e-3:
        shot.cam(t1, eye, last[1], fov=last[2], ease="linear")
    shot.event(t0, "fx", name="cctv", dur=round(t1 - t0, 3), label=label or name)
    shot.event(t0, "fx", name="focus")


# A: the reveal: close on the wall of feeds between their heads, drawing back over them into the dark office.
framing.dolly(shot, 0.0, CUTS[0], (-66.0, 6.7, -66.5), (-77.6, 7.0, -65.2), (-58.5, 6.4, -66.5), (-61.5, 5.6, -66.5),
              fov0=54, fov1=50, shake=0.4, seed=1, cut=False)
for t0, t1, room in FEEDS:  # B-E: flicking through the cameras, each one panning slowly over its room
    look0, fov0, look1, fov1 = PTZ[room]
    feed(t0, t1, room, look0, fov0, [(t1, look1, fov1, "linear")])
# F: the watcher, bored, from the end of the console (the monitors leave no room in front of them).
shot.pan(CUTS[4], CUTS[5], "watcher", (-61.8, 6.0, -60.4), aim="Head", dy=0.0, fov=52, cut=True, drift=(0.0, -0.1, -0.2),
         operator=True, seed=3, shake=0.35, fov_to=50, ease_move=True)
# G: the evidence room: the camera's zoom creeping onto the Manual on the counter, until the feed breaks up.
BOOK_LOOK = (COUNTER_BOOK[0], COUNTER_BOOK[1] - 0.2, COUNTER_BOOK[2] - 0.4)
feed(EVIDENCE[0], EVIDENCE[1], "evidence", keys=[(DROP - 0.35, BOOK_LOOK, 26.0, "sine"), (EVIDENCE[1], BOOK_LOOK, 25.0, "linear")])
# H: the two jolt and lean in: a fast push, low between their chairs, at the wall of feeds.
framing.dolly(shot, CUTS[6], CUTS[7], (-72.0, 5.0, -66.5), (-69.0, 5.3, -66.5), (-60.0, 5.2, -66.5), fov0=54, fov1=44,
              shake=1.1, seed=4, ease_move=False)
# I: the replay, zoomed on the counter, following the figure out.
feed(REPLAY[0], REPLAY[1], "evidence", (FIGURE[0], 17.0, FIGURE[1] + 0.6), 28.0,
     [(REPLAY[0] + 1.3, (FIGURE[0], 17.0, FIGURE[1] - 0.2), 27.0, "sine"),
      (REPLAY[1], (FIGURE[0] - 1.8, 16.8, FIGURE[1] - 1.0), 30.0, "linear")], label="CAM 39-11  EVIDENCE  REPLAY")
# J: the alarm: from behind them, dutch; the hand up against the feeds, and on the slam the camera punches in as the
# room goes red.
framing.dolly(shot, CUTS[8], SLAM, (-71.0, 6.7, -57.6), (-70.6, 6.6, -58.0), (-62.5, 4.6, -65.0), fov0=50, fov1=48,
              roll0=-4.0, roll1=-5.0, shake=0.6, seed=5)
framing.dolly(shot, SLAM, CUTS[9], (-70.6, 6.6, -58.0), (-68.6, 6.0, -59.8), (-62.5, 4.6, -65.0), (-62.8, 4.4, -65.2),
              fov0=48, fov1=36, roll0=-5.0, roll1=-11.0, shake=1.5, seed=6, ease_move=False, cut=False)
# K: room by room, everyone looks up into the lens: the camera crash-zooms onto a face as it comes up.
for t0, t1, room in LOOKS:
    _, fov0, look1, _ = PTZ[room]
    k = [p[0] for p in PEOPLE].index(STAR[room])
    when = LOOK_AT[room] + 0.15 + 0.07 * (k % 3)  # (as in person(): the head comes up)
    head = tuple(float(v) for v in framing.part(shot, STAR[room], when + 0.4))  # (where it really is, the face up)
    feed(t0, t1, room, look1, fov0 - 4.0, [(when + 0.04, look1, fov0 - 5.0, "linear"), (when + 0.3, head, 17.0, "out"),
                                         (t1, head, 15.5, "linear")])
# L: the floor upstairs: the zoom creeping in on the figure walking off; when its head turns, a crash zoom onto it.
FIG_HEAD = (FIG2_TO[0], 18.6, FIG2_TO[1])
feed(CORRIDOR[0], LENGTH, "corridor", keys=[(FIG_TURN + 0.3, (-44.0, 16.0, -34.0), 38.0, "sine"),
                                            (FIG_TURN + 0.55, FIG_HEAD, 13.0, "out"), (LENGTH, FIG_HEAD, 12.0, "linear")])
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
