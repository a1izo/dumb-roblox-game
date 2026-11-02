"""The Agency intro (everyone, 22.6 s; the intro phase follows it): "It's in the building". Scrapped and rebuilt a third
time (2026-11-01; the owner chose this idea), then told so it makes sense (2026-11-02, the owner: "why would they be
watching the Manual, and why would it teleport"): the recovered Manual is evidence, kept in the evidence room upstairs,
and the team is on a night watch over its camera. The feed glitches; when it clears, the counter is empty. They run
the tape back: a figure in a suit, face never seen, lifts it and walks away. The one at the console switches to this
room's own camera: the book is on the desk right behind them, and has been all along. One of them took it. They turn
round to it, then to each other. The named part (the watcher, at the console) is a random player, never by role.

A  0.0-2.6   Behind the team, low: the dark security office, the wall of feeds glowing, the team crowded at it.
B  2.6-4.4   Over the console, tracking along their faces in the feeds' light: tired, watching.
C  4.4-6.0   The feed (CAM 39-11 EVIDENCE): the evidence room upstairs, the Manual on the counter. All quiet.
D  6.0-7.2   The watcher at the console, from the monitors' eye, leans in.
E  7.2-9.0   The feed: it breaks up into static... and clears on an empty counter.
F  9.0-10.6  The team jolts and leans in on the screen.
G  10.6-12.2 Over the watcher's shoulder at the wall of feeds: he runs the tape back.
H1 12.2-14.2 The replay (CAM 39-11, 23:58): a figure in a suit, its back to the camera, lifts the Manual and walks off.
H2 14.2-15.6 He switches to this room's own camera (CAM 38-02 SECURITY): the team at the monitors... and, zooming past
             them, the duty desk right behind them, the Manual on it.
I  15.6-16.6 The watcher's face: it sinks in; he turns round in his chair.
J  16.6-18.2 From behind the book on the duty desk, low: the whole team turned round to it.
K  18.2-19.6 Past the book, drifting across their faces: they look at each other. Black.
   19.6-22.6 Black, then the case's card.

The security office (maps/venues/agency/lower.py security(), Agency scene space, 38F's floor at y 0): x -100..-58,
z -75..-48; the wall of feeds on the east wall's west face (screens at x -61.4, z -71.4..-62.1, two rows), the
counter in front of it (x -61.9..-59.5, top 3.4) with two OfficeChairs at (-63.9, -69.5) and (-63.9, -63.5) facing it;
the duty desk at (-84, -57) along z, top 2.9, its monitor at the south end; filing cabinets along the west glass. The
evidence room is 39F's lock-up (maps/venues/agency/upper.py lockup(), floor y 14): x -50..-16, z -75..-48, its cages
along the north wall, the evidence counter (7 by 2.2, top 17.55) at (-24, -52.5) by the door in the south wall."""

import math
import random

from animlib import J
from cinema import framing
from cinema.acting import alive, body_reach, facing, soft, walking
from cinema.shot import Shot
from motion import Motion

NAME = "IntroAgency"
BLACK = 19.6
LENGTH = BLACK + 3.0
CUTS = (2.6, 4.4, 6.0, 7.2, 9.0, 10.6, 12.2, 14.2, 15.6, 16.6, 18.2)  # B, C, D, E, F, G, H1, H2, I, J, K
DROP = 7.75  # the feed breaks up: the counter is empty when it clears (the team's start)
TURN = 15.8  # it sinks in: they turn round (each a beat apart)
GLANCE = 18.3  # ..and look at each other
SCREENS = (-61.4, 6.9, -66.8)  # the middle of the wall of feeds
KEYS = (-61.6, 3.5, -64.6)  # the console's keys, in front of the watcher
DUTY = (-84.0, -57.0)  # the duty desk
BOOK = (-84.0, 2.9 + 0.22, -58.3)  # the book on it, on the papers at the end away from its monitor
COUNTER_BOOK = (-24.0, 17.55 + 0.22, -52.4)  # the Manual on the evidence counter upstairs (39F lock-up)
FIGURE = (-24.0, -55.4)  # where the figure stands at the counter, facing it (+z)
SEATS = [("watcher", (-64.3, -63.5)), ("everyone:1", (-64.3, -69.5))]  # (sat back in the chairs: turning, a knee met the console)
# (x, z): the rest standing crowded behind the console, three rows, a body's width (4) apart
STANDING = [(-67.6, -72.2), (-67.6, -66.5), (-68.4, -60.2), (-71.4, -69.4), (-71.4, -63.6), (-72.2, -56.8),
            (-75.2, -71.2), (-75.2, -66.4), (-75.2, -60.6), (-63.0, -56.0)]

# Sitting at the console ---------------------------------------------------------------------------------------

HIP = 2.15  # on an OfficeChair's cushion


def seated(m, t, ease="sine", lean=-6.0, turn=0.0, neck=(4, 0, 0), right=None, left=None):
    joints = dict(root=(lean, turn, 0), rHip=J((52 - lean * 0.5, -turn, 4)), lHip=J((52 - lean * 0.5, -turn, -4)))
    off = (0.0, HIP - 2.0, 0.0)
    r = right(joints, off) if callable(right) else (right if right is not None else J((18, 0, 8)))
    lv = left(joints, off) if callable(left) else (left if left is not None else J((18, 0, -8)))
    m.key(round(t, 4), ease, offset=off, neck=neck, rShoulder=r, lShoulder=lv, **joints)


def local(seat, point):
    """A point in the set's space in the frame of someone seated at `seat` facing the feeds (+x, yaw -90)."""
    return (point[2] - seat[1], point[1], -(point[0] - seat[0]))  # (facing +x, the right hand is +z)


ON_DESK_R = lambda seat: (lambda j, o: body_reach(1, j, o, local(seat, (seat[0] + 2.0, 3.95, seat[1] + 0.6)),  # noqa: E731
                                                  direction=(0.0, -0.5, -0.85)))
ON_DESK_L = lambda seat: (lambda j, o: body_reach(-1, j, o, local(seat, (seat[0] + 2.0, 3.95, seat[1] - 0.6)),  # noqa: E731
                                                  direction=(0.0, -0.5, -0.85)))
KEY_R = lambda seat: (lambda j, o: body_reach(1, j, o, local(seat, (KEYS[0], KEYS[1] + 0.4, KEYS[2])),  # noqa: E731
                                              direction=(0.0, -0.6, -0.8)))

seat_w = SEATS[0][1]
w = Motion("IntroAgency_watcher", LENGTH, note="The Agency intro: the one at the console.")
# watching, slumped, chin low; a yawn; then he leans in
seated(w, 0.0, lean=4, neck=(2, 2, 0), right=ON_DESK_R(seat_w), left=ON_DESK_L(seat_w))
seated(w, 2.0, lean=6, neck=(10, -4, 4), right=ON_DESK_R(seat_w), left=J((150, 0, -20)))  # (a yawn, a stretch)
seated(w, 3.0, lean=4, neck=(2, 0, 0), right=ON_DESK_R(seat_w), left=ON_DESK_L(seat_w))
seated(w, CUTS[2] + 0.2, lean=-9, neck=(12, 4, 0), right=ON_DESK_R(seat_w), left=ON_DESK_L(seat_w))  # (leaning in)
seated(w, DROP - 0.05, lean=-10, neck=(12, 4, 0), right=ON_DESK_R(seat_w), left=ON_DESK_L(seat_w))
seated(w, DROP + 0.12, "out", lean=-2, neck=(14, 2, 0), right=ON_DESK_R(seat_w), left=ON_DESK_L(seat_w))  # (a start)
seated(w, CUTS[4] + 0.6, lean=-18, neck=(8, 0, 0), right=ON_DESK_R(seat_w), left=ON_DESK_L(seat_w))  # (right in at it)
# switching cameras: the hand to the keys, two presses
seated(w, CUTS[5] + 0.3, lean=-14, neck=(-10, -6, 0), right=KEY_R(seat_w), left=ON_DESK_L(seat_w))
for k, t in enumerate((CUTS[5] + 0.6, CUTS[5] + 0.9)):
    seated(w, t, "linear", lean=-14, neck=(-10, -6, 0), left=ON_DESK_L(seat_w),
           right=lambda j, o: body_reach(1, j, o, local(seat_w, (KEYS[0], KEYS[1] + 0.25, KEYS[2])), direction=(0.0, -0.6, -0.8)))
    seated(w, t + 0.15, "linear", lean=-14, neck=(-10, -6, 0), right=KEY_R(seat_w), left=ON_DESK_L(seat_w))
seated(w, CUTS[6] + 0.2, lean=-12, neck=(8, 0, 0), right=KEY_R(seat_w), left=ON_DESK_L(seat_w))
seated(w, TURN, lean=-12, neck=(8, 0, 0), right=KEY_R(seat_w), left=ON_DESK_L(seat_w))
# it sinks in: still; then he turns round in the chair to the desk behind them
seated(w, TURN + 0.6, lean=-6, neck=(4, -10, 0), right=J((34, 0, 8)), left=J((34, 0, -8)))  # (the hands off the console)
wturn = max(-80.0, min(80.0, (facing(seat_w, DUTY) - (-90.0) + 180) % 360 - 180))
seated(w, TURN + 1.5, "sine", lean=-2, turn=wturn * 0.5, neck=(2, wturn * 0.8, 0), right=J((6, 0, 8)), left=J((6, 0, -8)))
seated(w, LENGTH, "sine", lean=-2, turn=wturn * 0.55, neck=(0, wturn * 0.85, 0), right=J((6, 0, 8)), left=J((6, 0, -8)))
soft(w, head=2.8, arms=2.6)
alive(w, 0.35, seed=91)
w.build()

seat_o = SEATS[1][1]
o = Motion("IntroAgency_seated", LENGTH, note="The Agency intro: the other one at the console.")
seated(o, 0.0, lean=8, neck=(4, 0, 0), right=J((40, 0, -38), (-0.3, 0.1, -0.22)), left=J((38, 0, 36), (0.3, 0.1, -0.22)))  # (arms folded, sat back)
seated(o, DROP - 0.1, lean=8, neck=(4, 0, 0), right=J((40, 0, -38), (-0.3, 0.1, -0.22)), left=J((38, 0, 36), (0.3, 0.1, -0.22)))
seated(o, DROP + 0.35, "out", lean=-14, neck=(10, 6, 0), right=ON_DESK_R(seat_o), left=ON_DESK_L(seat_o))  # (sitting up, in at it)
seated(o, TURN + 0.2, lean=-14, neck=(10, 6, 0), right=ON_DESK_R(seat_o), left=ON_DESK_L(seat_o))
seated(o, TURN + 0.55, lean=-8, neck=(6, 2, 0), right=J((34, 0, 8)), left=J((34, 0, -8)))  # (the hands off the console)
oturn = max(-80.0, min(80.0, (facing(seat_o, DUTY) - (-90.0) + 180) % 360 - 180))
seated(o, TURN + 1.1, "sine", lean=-4, turn=oturn * 0.5, neck=(2, oturn * 0.8, 0), right=J((6, 0, 8)), left=J((6, 0, -8)))
seated(o, LENGTH, "sine", lean=-4, turn=oturn * 0.55, neck=(0, oturn * 0.85, 0), right=J((6, 0, 8)), left=J((6, 0, -8)))
soft(o, head=2.8, arms=2.6)
alive(o, 0.35, seed=92)
o.build()

# Standing behind them ----------------------------------------------------------------------------------------

STANCES = [
    dict(rShoulder=J((40, 0, -38), (-0.3, 0.1, -0.22)), lShoulder=J((38, 0, 36), (0.3, 0.1, -0.22))),  # arms folded
    dict(rShoulder=J((10, 0, -4), (-0.08, 0.12, -0.02)), lShoulder=J((10, 0, 4), (0.08, 0.12, -0.02))),  # hands in pockets
    dict(rShoulder=J((-18, 0, 10), (0.0, 0.05, 0.12)), lShoulder=J((-18, 0, -10), (0.0, 0.05, 0.12))),  # hands behind
    dict(rShoulder=J((112, 0, -32), (-0.28, 0.24, -0.22)), lShoulder=J((38, 0, 36), (0.3, 0.1, -0.22))),  # hand at the chin
]


def stander(k, x, z):
    """Crowded behind the console watching the feeds: weight shifting, a word to a neighbour; at the drop a start and a
    lean in; then, each a beat apart, turned round to the desk behind them."""
    rng = random.Random(1300 + k * 17)
    yaw = facing((x, z), (SCREENS[0], SCREENS[2]))
    arms = STANCES[k % len(STANCES)]
    up = 10 + rng.uniform(-3, 3)  # (the feeds are up on the wall)
    m = Motion(f"IntroAgency_crowd{k}", LENGTH, note="The Agency intro: one of the team at the feeds.")
    m.key(0.0, root=(-2, 0, 0), neck=(up, rng.uniform(-6, 6), 0), **arms)
    t = rng.uniform(0.8, 2.0)
    while t < DROP - 1.2:
        side = rng.choice((-1, 1))
        m.key(t, "sine", root=(-2, 4 * side, 2 * side), neck=(up - 6, 24 * side, 0), **arms)  # (a word to a neighbour)
        m.key(t + rng.uniform(0.6, 1.0), "sine", root=(-2, 0, 0), neck=(up, 0, 0), **arms)
        t += rng.uniform(1.6, 2.6)
    m.key(DROP + rng.uniform(0.0, 0.1), root=(-2, 0, 0), neck=(up, 0, 0), **arms)
    m.key(DROP + 0.2 + rng.uniform(0.0, 0.15), "out", root=(3, 0, 0), neck=(up + 4, 0, 0), **arms)  # (a start)
    m.key(CUTS[4] + 0.7 + rng.uniform(0.0, 0.3), "sine", root=(-10, 0, 0), neck=(up - 2, 0, 0), **arms)  # (leaning in)
    stop = TURN + 0.2 + rng.uniform(0.0, 0.6)
    m.key(stop, root=(-8, 0, 0), neck=(up - 2, 0, 0), **arms)
    # turning right round to the desk behind them: the head first, then the whole body on the spot (the path turns
    # them; what is left the neck takes)
    total = (facing((x, z), DUTY) - yaw + 180) % 360 - 180
    head = max(-60.0, min(60.0, total * 0.35))
    m.key(stop + 0.45, "sine", root=(-2, 0, 0), neck=(2, head, 0), **arms)  # (the head round first)
    m.key(stop + 1.4, "sine", root=(-1, 0, 0), neck=(-2, total - total * 0.8, 0), **arms)  # (then the body)
    # then at each other: who? a look to one side, a look to the other
    rest = total - total * 0.8
    side = 1 if k % 2 else -1
    g = GLANCE + rng.uniform(0.0, 0.4)
    m.key(g, "sine", root=(-1, 0, 0), neck=(-2, rest, 0), **arms)
    m.key(g + 0.35, "out", root=(-1, 0, 0), neck=(0, rest + 38 * side, 0), **arms)
    m.key(g + 0.9, "sine", root=(-1, 0, 0), neck=(0, rest + 34 * side, 2), **arms)
    m.key(LENGTH, "sine", root=(-1, 0, 0), neck=(-1, rest - 26 * side, 2), **arms)
    soft(m, head=2.8, arms=2.6)
    m.plant(stance=0.06)
    alive(m, 0.45, seed=110 + k)
    m.build()
    return yaw, stop, total * 0.8


TURNS = [stander(k, x, z) for k, (x, z) in enumerate(STANDING)]

# The shot -------------------------------------------------------------------------------------------------

shot = Shot(NAME, "Agency", LENGTH, note="Agency intro: it's in the building.", skippable=True, mood="TaskForceHQ")
shot.own = True  # players in their own avatars (the owner, 2026-10-28)
shot.allow = {}
for (slot, seat), clip in zip(SEATS, ("IntroAgency_watcher", "IntroAgency_seated")):
    a = shot.actor(slot, w if slot == "watcher" else None, clip=None if slot == "watcher" else clip)
    a.mark(0.0, (seat[0], 0.0, seat[1]), -90.0)
    shot.allow[slot] = ["OfficeChair"]
for k, ((x, z), (yaw, stop, spin)) in enumerate(zip(STANDING, TURNS)):
    a = shot.actor(f"everyone:{k + 2}", clip=f"IntroAgency_crowd{k}")
    a.mark(0.0, (x, 0.0, z), yaw)
    a.mark(stop + 0.45, (x, 0.0, z), yaw)
    a.mark(stop + 1.4, (x, 0.0, z), yaw + spin)  # (turned round on the spot)
    a.mark(LENGTH, (x, 0.0, z), yaw + spin)

# The Manual: on the evidence counter upstairs, live on the feed, until the feed breaks up; on the replay, there again,
# lifted by the figure; and all along, on the duty desk behind the team.
for t0, t1 in ((0.0, DROP), (CUTS[6], CUTS[6] + 0.75)):
    on_counter = shot.prop("Grimoire", show=(t0, t1))
    on_counter.at(0.0, COUNTER_BOOK, (0, 90, 0))
    on_counter.at(LENGTH, COUNTER_BOOK, (0, 90, 0))
book = shot.prop("Grimoire")
book.at(0.0, BOOK, (0, 170, 0))
book.at(LENGTH, BOOK, (0, 170, 0))

# The figure on the replay: a stand-in, never a player's face (its back to the camera): it lifts the Manual off the
# counter, holds it to its chest, turns away and walks off.
fig = Motion("IntroAgency_figure", LENGTH, note="The Agency intro: the figure on the replay.")
FJ = dict(root=(-14, 0, 0))
FREACH = body_reach(1, FJ, (0, 0, 0), (0.0, COUNTER_BOOK[1] - 14.0 + 0.75, -2.85), direction=(0.0, -0.35, -0.95))
CHEST = J((44, 0, -30), (-0.25, 0.1, -0.2))
fig.key(0.0, root=(-14, 0, 0), neck=(-24, 0, 0), rShoulder=FREACH, lShoulder=J((6, 0, -5)))
fig.key(CUTS[6] + 0.7, "sine", root=(-14, 0, 0), neck=(-24, 0, 0), rShoulder=FREACH, lShoulder=J((6, 0, -5)))
LIFT = body_reach(1, dict(root=(-9, 0, 0)), (0, 0, 0), (0.0, COUNTER_BOOK[1] - 14.0 + 1.6, -2.3), direction=(0.0, 0.1, -1.0))
fig.key(CUTS[6] + 0.9, "out", root=(-9, 0, 0), neck=(-18, 0, 0), rShoulder=LIFT, lShoulder=J((6, 0, -5)))  # (up off it)
fig.key(CUTS[6] + 1.1, "sine", root=(-4, 0, 0), neck=(-10, 0, 0), rShoulder=CHEST, lShoulder=J((6, 0, -5)))
fig.key(CUTS[6] + 1.45, "sine", root=(-3, 0, 0), neck=(-6, 30, 0), rShoulder=CHEST, lShoulder=J((6, 0, -5)))
fig.key(LENGTH, root=(-3, 0, 0), neck=(-6, 0, 0), rShoulder=CHEST, lShoulder=J((6, 0, -5)))
walking(fig, CUTS[6] + 1.5, CUTS[7], speed=3.4)
fig.plant(None, CUTS[6] + 1.5, stance=0.06)
fig.plant(CUTS[7], None, stance=0.06)
soft(fig, head=2.6, arms=2.6)
fig.build()
figure = shot.actor("extra:1", fig, extra=True, show=(CUTS[6], CUTS[7]))
figure.mark(0.0, (FIGURE[0], 14.0, FIGURE[1]), 180.0)
figure.mark(CUTS[6] + 0.9, (FIGURE[0], 14.0, FIGURE[1]), 180.0)
figure.mark(CUTS[6] + 1.2, (FIGURE[0], 14.0, FIGURE[1] - 1.0), 180.0)  # (a step back from the counter...)
figure.mark(CUTS[6] + 1.5, (FIGURE[0], 14.0, FIGURE[1] - 1.0), 90.0)  # (...and turned away, west, to the door)
figure.mark(CUTS[7], (FIGURE[0] - 3.4 * (CUTS[7] - CUTS[6] - 1.5), 14.0, FIGURE[1] - 1.0), 90.0, "linear")
figure.hold("Grimoire", "Right Arm", (0.0, -1.05, -0.35), (80, 0, 0), t0=CUTS[6] + 0.75, t1=CUTS[7])

FEED_LOCK = ((-17.4, 25.0, -72.6), (-25.0, 16.2, -54.0))  # the evidence room's camera, high in its north-east corner
FEED_HERE = (-98.6, 11.6, -49.4)  # this room's own camera, in its south-west corner

# A: behind the team, low: the dark room, the feeds glowing, the team crowded at them.
framing.dolly(shot, 0.0, CUTS[0], (-85.0, 8.2, -64.2), (-82.6, 7.6, -65.0), (-62.0, 6.0, -66.5), fov0=56, fov1=50, shake=0.4,
              seed=1, cut=False)
# B: over the console, tracking along their faces in the feeds' light.
framing.dolly(shot, CUTS[0], CUTS[1], (-61.9, 7.8, -71.6), (-61.9, 7.6, -61.4), (-70.0, 5.0, -70.0), (-70.0, 5.0, -62.0),
              fov0=50, fov1=48, shake=0.4, seed=2)
# C: the evidence room's feed: the Manual on the counter, all quiet. (A camera on a wall: locked.)
shot.subjects.append((CUTS[1], CUTS[2], None, True))
shot.cam(CUTS[1], FEED_LOCK[0], FEED_LOCK[1], fov=40, cut=True)
shot.cam(CUTS[2], FEED_LOCK[0], FEED_LOCK[1], fov=40, ease="linear")
# D: the watcher leans in: from the monitors' eye, low over the console under the screens, up into his face.
shot.pan(CUTS[2], CUTS[3], "watcher", (-60.4, 4.1, -63.0), aim="Head", dy=0.0, fov=44, cut=True, drift=(0.0, 0.0, -0.4),
         operator=True, seed=3, shake=0.4, fov_to=42, ease_move=True)
# E: the evidence feed: it breaks up, and clears on an empty counter.
shot.subjects.append((CUTS[3], CUTS[4], None, True))
shot.cam(CUTS[3], FEED_LOCK[0], FEED_LOCK[1], fov=40, cut=True)
shot.cam(CUTS[4], FEED_LOCK[0], FEED_LOCK[1], fov=40, ease="linear")
# F: the team jolts and leans in: from the wall of feeds, wide.
framing.dolly(shot, CUTS[4], CUTS[5], (-62.0, 7.6, -57.6), (-62.0, 7.2, -58.6), (-69.5, 4.8, -66.0), fov0=58, fov1=52,
              shake=0.9, seed=4)
# G: over the watcher's shoulder at the wall of feeds as he runs the tape back.
framing.dolly(shot, CUTS[5], CUTS[6], (-67.4, 7.8, -61.0), (-66.8, 7.6, -61.6), (-61.4, 6.0, -65.6), fov0=50, fov1=44,
              roll0=-5.0, roll1=-7.0, shake=0.4, seed=5)
# H1: the replay of the evidence feed: the figure lifts the Manual and walks off.
shot.subjects.append((CUTS[6], CUTS[7], None, True))
shot.cam(CUTS[6], FEED_LOCK[0], FEED_LOCK[1], fov=40, cut=True)
shot.cam(CUTS[7], FEED_LOCK[0], FEED_LOCK[1], fov=40, ease="linear")
# H2: this room's own camera from its corner, zooming past the team onto the duty desk behind them.
shot.subjects.append((CUTS[7], CUTS[8], None, True))
shot.cam(CUTS[7], FEED_HERE, (-70.0, 3.0, -63.0), fov=66, cut=True)
shot.cam(CUTS[7] + 0.35, FEED_HERE, (-70.0, 3.0, -63.0), fov=66, ease="linear")
shot.cam(CUTS[8], FEED_HERE, (BOOK[0], BOOK[1], BOOK[2]), fov=30, ease="sine")  # (the camera's zoom)
# I: the watcher's face: it sinks in; he turns round in the chair.
shot.pan(CUTS[8], CUTS[9], "watcher", (-60.4, 4.1, -64.0), aim="Head", dy=0.0, fov=44, cut=True, drift=(0.0, 0.0, -0.4),
         roll=-5.0, operator=True, seed=6, shake=0.35, fov_to=40, ease_move=True)
# J: from behind the book on the duty desk, low: the whole team turned round to it.
framing.dolly(shot, CUTS[9], CUTS[10], (BOOK[0] - 3.0, 4.8, BOOK[2] - 2.6), (BOOK[0] - 2.4, 4.6, BOOK[2] - 2.2),
              (-74.0, 4.0, -61.0), fov0=54, fov1=48, shake=0.4, seed=7)  # (north of the desk: its monitor walls the south side)
# K: past the book, drifting across their faces as they look at each other.
framing.dolly(shot, CUTS[10], BLACK, (BOOK[0] - 1.6, 4.9, BOOK[2] - 3.4), (BOOK[0] - 1.4, 4.9, BOOK[2] + 1.6),
              (-71.0, 4.8, -67.0), (-71.0, 4.8, -60.0), fov0=44, fov1=44, roll0=-3.0, roll1=3.0, shake=0.35, seed=8)
shot.subjects.append((BLACK, LENGTH, None, True))
shot.cam(BLACK, (BOOK[0] - 1.4, 4.9, BOOK[2] + 1.6), (-71.0, 4.8, -60.0), fov=44, cut=True)
shot.cam(LENGTH, (BOOK[0] - 1.4, 4.9, BOOK[2] + 1.6), (-71.0, 4.8, -60.0), fov=44, ease="linear")
shot.cam_groups.sort(key=lambda g: g[0][0])

# The lens: barely soft; the feeds flat.
for t, slot, radius in ((CUTS[2], "watcher", 2.5), (CUTS[8], "watcher", 2.5)):
    shot.event(t, "fx", name="focus", slot=slot, part="Head", radius=radius, far=0.12, near=0.06)
for t in (0.0, CUTS[1], CUTS[3], CUTS[4], CUTS[6], CUTS[7], CUTS[9]):
    shot.event(t, "fx", name="focus")

# The feeds: black and white, REC and the time, each camera's label.
for t0, t1, label in ((CUTS[1], CUTS[2], "CAM 39-11  EVIDENCE"), (CUTS[3], CUTS[4], "CAM 39-11  EVIDENCE"),
                      (CUTS[6], CUTS[7], "CAM 39-11  REPLAY 23:58"), (CUTS[7], CUTS[8], "CAM 38-02  SECURITY")):
    shot.event(t0, "fx", name="cctv", dur=round(t1 - t0, 3), label=label)
    shot.event(t0, "sfx", slot="screenStatic")

# The light: the room dark, the feeds' cold glow on the faces turned to them; the duty desk's lamp behind them, the
# panel over it stuttering once they turn; upstairs, the lamp over the empty desk. The grade: dark, cold.
shot.grade = (0.22, -0.1, -0.05, (226, 234, 255))
shot.light("spot", (SCREENS[0] - 0.4, 7.6, SCREENS[2]), (-70.0, 4.8, -65.0), color=(150, 190, 255), brightness=1.6,
           range=18, angle=70, shadows=False, flicker=0.25)  # (the feeds on their faces)
shot.light("spot", (BOOK[0] + 0.6, 8.0, BOOK[2]), (BOOK[0], BOOK[1], BOOK[2]), color=(255, 214, 160), brightness=1.4,
           range=10, angle=40, flicker=0.0, show=(0.0, TURN))
shot.light("spot", (BOOK[0] + 0.6, 8.0, BOOK[2]), (BOOK[0], BOOK[1], BOOK[2]), color=(255, 214, 160), brightness=1.4,
           range=10, angle=40, flicker=0.85, show=(TURN, LENGTH))  # (stuttering over it once they turn)
shot.light("spot", (COUNTER_BOOK[0], 24.0, COUNTER_BOOK[2] - 1.0), (COUNTER_BOOK[0], 17.6, COUNTER_BOOK[2]),
           color=(225, 232, 255), brightness=1.6, range=12, angle=45)  # (the evidence counter, lit)

# Sound.
shot.event(0.0, "sfx", slot="mapServerHum")
shot.event(0.0, "sfx", slot="mapRainGlass")
shot.event(0.3, "title", lines=["BUREAU HEADQUARTERS, 38F", "Security, 00:04"], dur=2.2)
for k, t in enumerate((DROP - 0.35, DROP - 0.2, DROP - 0.05)):  # (the feed breaking up: static, and gone)
    shot.event(t, "fx", name="flash", r=230, g=230, b=230, strength=0.55 - 0.1 * k, dur=0.12)
shot.event(DROP - 0.35, "sfx", slot="glitch")
shot.event(CUTS[5] + 0.6, "sfx", slot="uiClick")
shot.event(CUTS[5] + 0.9, "sfx", slot="uiClick")
shot.event(CUTS[7], "sfx", slot="uiClick")
shot.event(TURN, "sfx", slot="heartbeat")
shot.event(CUTS[9], "sfx", slot="hauntWhisper")
shot.event(BLACK, "fx", name="black", hush=True)
shot.event(BLACK + 0.5, "card", key="case", dur=LENGTH - BLACK - 0.5)
