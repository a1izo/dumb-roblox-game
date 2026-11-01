"""The Agency intro (everyone, 22.6 s; the intro phase follows it): "It's in the building". Scrapped and rebuilt a third
time (2026-11-01; the owner chose this idea): the team crowded in the dark security office on 38F, watching the wall of
camera feeds. On the feed from an empty office upstairs, a black book drops onto a desk out of nowhere. They lean in;
the one at the console switches to another camera, the one in this room: there they are, crowded at the monitors,
and on the duty desk right behind them, the book. They turn round. Its cover lifts. The named part (the watcher, at
the console) is a random player, never by role.

A  0.0-2.6   Behind the team, low: the dark room, the wall of feeds glowing, the team crowded at it.
B  2.6-4.4   Over the console, tracking along their faces in the feeds' light: tired, bored, watching.
C  4.4-6.0   The feed (CAM 39-04): an empty office upstairs, a desk under a lamp. Nothing.
D  6.0-7.2   The watcher at the console leans in.
E  7.2-9.0   The feed: a black book drops onto the desk out of nowhere.
F  9.0-10.6  The team jolts and leans in on the screen.
G  10.6-12.2 The watcher's hand on the console, switching cameras.
H  12.2-14.4 The feed (CAM 38-02): this room, from its corner: the team crowded at the monitors; zooming in, past them,
             onto the duty desk behind them, and the book on it.
I  14.4-16.0 The watcher's face: it sinks in; he turns round in his chair.
J  16.0-18.0 From behind the book on the duty desk, low: the whole team turned round, staring at it.
K  18.0-19.6 The book, close: its cover lifts, a little, by itself. Black.
   19.6-22.6 Black, then the case's card.

The security office (maps/venues/agency/lower.py security(), Agency scene space, 38F's floor at y 0): x -100..-58,
z -75..-48; the wall of feeds on the east wall's west face (screens at x -61.4, z -71.4..-62.1, two rows), the
counter in front of it (x -61.9..-59.5, top 3.4) with two OfficeChairs at (-63.9, -69.5) and (-63.9, -63.5) facing it;
the duty desk at (-84, -57) along z, top 2.9; filing cabinets along the west glass; the door to the bullpen in the
south wall at x -86. The empty office upstairs is the 39F deck's desk at (8, 40) (top 16.9)."""

import math
import random

from animlib import J
from cinema import framing
from cinema.acting import alive, body_reach, facing, soft
from cinema.shot import Shot
from motion import Motion

NAME = "IntroAgency"
BLACK = 19.6
LENGTH = BLACK + 3.0
CUTS = (2.6, 4.4, 6.0, 7.2, 9.0, 10.6, 12.2, 14.4, 16.0, 18.0)  # B .. K
DROP = 7.95  # the book lands on the desk upstairs, on the feed
TURN = 14.6  # it sinks in: they turn round (each a beat apart)
OPEN = (18.4, 19.3)  # its cover lifting, a little
SCREENS = (-61.4, 6.9, -66.8)  # the middle of the wall of feeds
KEYS = (-61.6, 3.5, -64.6)  # the console's keys, in front of the watcher
DUTY = (-84.0, -57.0)  # the duty desk
BOOK = (-84.0, 2.9 + 0.22, -58.3)  # the book on it, on the papers at the end away from its monitor
UP_DESK = (8.0, 40.0)  # the empty office upstairs (39F)
UP_BOOK = (6.6, 16.9 + 0.22, 40.2)  # (on the papers, left of the desk's monitor)
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
    m.key(LENGTH, "sine", root=(-1, 0, 0), neck=(-3, total - total * 0.8, 2), **arms)
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

# The book: dropped onto the desk upstairs out of nowhere (on the feed); then, unseen, on the duty desk behind them.
up_book = shot.prop("Grimoire", show=(DROP - 0.25, CUTS[4]))
up_book.at(DROP - 0.25, (UP_BOOK[0], UP_BOOK[1] + 3.2, UP_BOOK[2]), (30, 40, 20))
up_book.at(DROP, UP_BOOK, (0, 22, 0), "in")
up_book.at(DROP + 0.12, (UP_BOOK[0], UP_BOOK[1] + 0.12, UP_BOOK[2]), (0, 24, 2), "out")  # (a small bounce)
up_book.at(DROP + 0.24, UP_BOOK, (0, 24, 0), "in")
up_book.at(CUTS[4], UP_BOOK, (0, 24, 0))
book = shot.prop("Grimoire", show=(CUTS[6], LENGTH), open=[(0.0, 0.0), (OPEN[0], 0.0), (OPEN[1], 0.22)])
book.at(0.0, BOOK, (0, 170, 0))
book.at(LENGTH, BOOK, (0, 170, 0))

FEED_UP = ((12.4, 22.4, 44.6), (UP_BOOK[0], 16.9, UP_BOOK[2]))  # the camera in the office upstairs
FEED_HERE = (-98.6, 11.6, -49.4)  # this room's own camera, in its south-west corner

# A: behind the team, low: the dark room, the feeds glowing, the team crowded at them.
framing.dolly(shot, 0.0, CUTS[0], (-85.0, 8.2, -64.2), (-82.6, 7.6, -65.0), (-62.0, 6.0, -66.5), fov0=56, fov1=50, shake=0.4,
              seed=1, cut=False)
# B: over the console, tracking along their faces in the feeds' light.
framing.dolly(shot, CUTS[0], CUTS[1], (-61.9, 7.8, -71.6), (-61.9, 7.6, -61.4), (-70.0, 5.0, -70.0), (-70.0, 5.0, -62.0),
              fov0=50, fov1=48, shake=0.4, seed=2)
# C: the feed upstairs: the empty office. (A camera on a wall: locked.)
shot.subjects.append((CUTS[1], CUTS[2], None, True))
shot.cam(CUTS[1], FEED_UP[0], FEED_UP[1], fov=46, cut=True)
shot.cam(CUTS[2], FEED_UP[0], FEED_UP[1], fov=46, ease="linear")
# D: the watcher leans in: from the monitors' eye, low over the console under the screens, up into his face.
shot.pan(CUTS[2], CUTS[3], "watcher", (-60.4, 4.1, -63.0), aim="Head", dy=0.0, fov=44, cut=True, drift=(0.0, 0.0, -0.4),
         operator=True, seed=3, shake=0.4, fov_to=42, ease_move=True)
# E: the feed upstairs: the drop.
shot.subjects.append((CUTS[3], CUTS[4], None, True))
shot.cam(CUTS[3], FEED_UP[0], FEED_UP[1], fov=46, cut=True)
shot.cam(CUTS[4], FEED_UP[0], FEED_UP[1], fov=46, ease="linear")
# F: the team jolts and leans in: from the wall of feeds, wide.
framing.dolly(shot, CUTS[4], CUTS[5], (-62.0, 7.6, -57.6), (-62.0, 7.2, -58.6), (-69.5, 4.8, -66.0), fov0=58, fov1=52,
              shake=0.9, seed=4)
# G: over the watcher's shoulder at the wall of feeds as he switches cameras.
framing.dolly(shot, CUTS[5], CUTS[6], (-67.4, 7.8, -61.0), (-66.8, 7.6, -61.6), (-61.4, 6.0, -65.6), fov0=50, fov1=44,
              roll0=-5.0, roll1=-7.0, shake=0.4, seed=5)
# H: the feed here: this room from its corner, zooming past them onto the duty desk behind them.
shot.subjects.append((CUTS[6], CUTS[7], None, True))
shot.cam(CUTS[6], FEED_HERE, (-70.0, 3.0, -63.0), fov=66, cut=True)
shot.cam(CUTS[6] + 0.5, FEED_HERE, (-70.0, 3.0, -63.0), fov=66, ease="linear")
shot.cam(CUTS[7], FEED_HERE, (BOOK[0], BOOK[1], BOOK[2]), fov=30, ease="sine")  # (the camera's zoom, slow)
# I: the watcher's face: it sinks in; he turns round in the chair.
shot.pan(CUTS[7], CUTS[8], "watcher", (-60.4, 4.1, -64.0), aim="Head", dy=0.0, fov=44, cut=True, drift=(0.0, 0.0, -0.4),
         roll=-5.0, operator=True, seed=6, shake=0.35, fov_to=40, ease_move=True)
# J: from behind the book on the duty desk, low: the whole team turned round to it.
framing.dolly(shot, CUTS[8], CUTS[9], (BOOK[0] - 3.0, 4.8, BOOK[2] - 2.6), (BOOK[0] - 2.4, 4.6, BOOK[2] - 2.2),
              (-74.0, 4.0, -61.0), fov0=54, fov1=48, shake=0.4, seed=7)  # (north of the desk: its monitor walls the south side)
# K: the book, close: its cover lifts a little, by itself.
framing.dolly(shot, CUTS[9], BLACK, (BOOK[0] + 2.4, 5.2, BOOK[2] + 1.8), (BOOK[0] + 1.5, 4.6, BOOK[2] + 1.2),
              (BOOK[0], BOOK[1], BOOK[2]), fov0=46, fov1=40, roll0=4.0, roll1=8.0, shake=0.3, seed=8)
shot.subjects.append((BLACK, LENGTH, None, True))
shot.cam(BLACK, (BOOK[0] + 1.5, 4.6, BOOK[2] + 1.2), (BOOK[0], BOOK[1], BOOK[2]), fov=40, cut=True)
shot.cam(LENGTH, (BOOK[0] + 1.5, 4.6, BOOK[2] + 1.2), (BOOK[0], BOOK[1], BOOK[2]), fov=40, ease="linear")
shot.cam_groups.sort(key=lambda g: g[0][0])

# The lens: barely soft; the feeds flat.
for t, slot, radius in ((CUTS[2], "watcher", 2.5), (CUTS[7], "watcher", 2.5)):
    shot.event(t, "fx", name="focus", slot=slot, part="Head", radius=radius, far=0.12, near=0.06)
for t in (0.0, CUTS[1], CUTS[3], CUTS[4], CUTS[6], CUTS[8]):
    shot.event(t, "fx", name="focus")

# The feeds: black and white, REC and the time, each camera's label.
for t0, t1, label in ((CUTS[1], CUTS[2], "CAM 39-04  OPS"), (CUTS[3], CUTS[4], "CAM 39-04  OPS"),
                      (CUTS[6], CUTS[7], "CAM 38-02  SECURITY")):
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
shot.light("spot", (UP_DESK[0] + 0.5, 23.0, UP_DESK[1] - 0.5), (UP_DESK[0], 16.9, UP_DESK[1]), color=(255, 214, 160),
           brightness=1.8, range=12, angle=40)

# Sound.
shot.event(0.0, "sfx", slot="mapServerHum")
shot.event(0.0, "sfx", slot="mapRainGlass")
shot.event(0.3, "title", lines=["BUREAU HEADQUARTERS, 38F", "Security, 00:04"], dur=2.2)
shot.event(DROP, "sfx", slot="bookImpact")
shot.event(DROP + 0.05, "fx", name="shake", strength=0.12, dur=0.15)
shot.event(CUTS[5] + 0.6, "sfx", slot="uiClick")
shot.event(CUTS[5] + 0.9, "sfx", slot="uiClick")
shot.event(TURN, "sfx", slot="heartbeat")
shot.event(CUTS[8], "sfx", slot="hauntWhisper")
shot.event(OPEN[0], "sfx", slot="pageTurn")
shot.event(BLACK, "fx", name="black", hush=True)
shot.event(BLACK + 0.5, "card", key="case", dur=LENGTH - BLACK - 0.5)
