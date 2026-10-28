"""The Agency intro (everyone, 22.6 s; the intro phase follows it): the Bureau's operations deck at midnight. Rebuilt a
second time from scratch (2026-10-28, the owner: "the HQ intro sucks, everything, the pacing, the scenes"): no longer a
group standing round a table, but a deck at work, cut to its rhythm, until a new death lights up on the wall of the
dead and stops everyone; one walks down to the rail to face it, and behind them all, on the empty table, the Manual
opens by itself. The named part (the lead) is a random player, never by role.

A  0.0-2.0   High over the atrium, craning down onto the deck: the Bureau at work under the lamps at midnight.
B  2.0-3.4   Close at a desk: typing fast, the monitor's glow on a face.
C  3.4-5.0   Low in the centre aisle, backing away: two agents striding up it at us with files.
D  5.0-6.4   At the evidence board: a photograph pinned up, the hand flat on it.
E  6.4-7.6   At a desk: one on the phone stops talking, and looks up.
F  7.6-9.4   From the rail, low: the wall of the dead across the atrium; one screen flares red. A new one.
G  9.4-11.4  High from the atrium, looking back at the deck: everyone has stopped, turned to the wall; the two with
             the files frozen mid-aisle.
H  11.4-13.6 Behind the lead, tracking: down the aisle between the desks to the rail.
I  13.6-15.4 The empty table behind them all, low: the lamp over it stutters; the Manual's cover lifts by itself.
J  15.4-17.4 The lead at the rail from the atrium side, close, the wall's red on the face: the head turns, slowly,
             over the shoulder, as if someone had spoken.
K  17.4-19.6 From behind the open Manual on the table, low: far down the aisle the lead, turned to us; the camera
             comes down into the page.
   19.6-22.6 Black, then the case's card.

The operations deck (maps/venues/agency/upper.py, Agency scene space): 39F's floor at y 14; the atrium rail along
z 33.8 (x -3.8..37.8, glass above it); desks (6 by 3.2, top 2.9 over the floor) at z 40 (x 0, 8, 26, 34) and z 50
(x 4, 12, 22, 30), each with its OfficeChair 2.9 behind it, all facing the atrium (-z); the centre aisle at x 17; the
map table at x 12..22, z 59..65, solid to the floor, its own chairs at x 14.5 / 19.5, z 57.8 / 66.2; the video wall
across the atrium on the core's south face (z -5.5), x -6..40, screens y 22..32."""

import math
import random

from animlib import J
from cinema import framing
from cinema.acting import alive, body_reach, soft, walking
from cinema.shot import Shot
from emotes.kit import reach
from motion import Motion

NAME = "IntroAgency"
BLACK = 19.6
LENGTH = BLACK + 3.0
Y = 14.0
DESK_TOP = 2.9
HIP = 2.15  # on an OfficeChair's cushion
CUTS = (2.0, 3.4, 5.0, 6.4, 7.6, 9.4, 11.4, 13.6, 15.4, 17.4)  # B .. K
FLARE = 8.1  # the new face lights up on the wall
STOP = 8.5  # ..and the deck stops (each a beat apart)
LEAD_WALK = (11.5, 13.6)
LEAD_FROM, LEAD_TO = (12.6, 45.0), (15.2, 35.9)  # (beside the aisle, clear of the two walking up it)
OPEN = (14.2, 15.2)  # the cover lifting by itself
TURN = 15.9  # the lead's head turns over the shoulder
TABLE = (17.0, 62.0)
BOOK = (17.0, 61.2)
WALL = (17.0, -5.5)

# (slot, desk x, desk z): the ones at desks (the chair 2.9 behind each desk, facing the atrium)
SEATED = [("typist", 8.0, 40.0), ("phone", 30.0, 50.0), ("desk3", 0.0, 40.0), ("desk4", 34.0, 40.0)]
WALKERS = [((17.0, 39.6), (17.0, 55.2), 3.0), ((17.0, 36.6), (17.0, 52.2), 3.25)]  # (from, to, start): up the aisle, stopped by the flare
BOARD = (36.4, 58.0)  # the evidence board, facing the deck (-x)
PINNER = (34.6, 58.0)
STANDING = [("table", 10.2, 61.2, "fold"), ("board2", 34.6, 62.6, "chin"), ("rail", 24.0, 35.6, "pockets"),
            ("lean", 6.4, 56.4, "fold")]  # (slot, x, z, stance): the others standing about


def facing(frm, to):
    dx, dz = to[0] - frm[0], to[1] - frm[1]
    return math.degrees(math.atan2(-dx, -dz))


def turn_to(yaw, frm, to):
    return max(-80.0, min(80.0, (facing(frm, to) - yaw + 180) % 360 - 180))


# At a desk -------------------------------------------------------------------------------------------------

KEYS = (0.0, DESK_TOP + 0.05, -1.75)  # (the character's frame) the keyboard at the desk's near edge


def desk_key(m, t, ease="sine", lean=-8.0, turn=0.0, neck=(-10, 0, 0), right=None, left=None, xr=0.0, xl=0.0, up=0.0):
    joints = dict(root=(lean, turn, 0), rHip=J((52 - lean * 0.5, -turn, 4)), lHip=J((52 - lean * 0.5, -turn, -4)))
    off = (0.0, HIP - 2.0, 0.0)
    r = right if right is not None else body_reach(1, joints, off, (0.45 + xr, KEYS[1] + 0.75 + up, KEYS[2]),
                                                   direction=(-0.2, -0.55, -0.8))
    lv = left if left is not None else body_reach(-1, joints, off, (-0.45 + xl, KEYS[1] + 0.75 + up, KEYS[2]),
                                                  direction=(0.2, -0.55, -0.8))
    m.key(round(t, 4), ease, offset=off, neck=neck, rShoulder=r, lShoulder=lv, **joints)


def seated_worker(k, slot):
    """At a desk: typing (each their own rhythm), then the stop: the hands still, the head up to the wall."""
    rng = random.Random(900 + k * 7)
    m = Motion(f"IntroAgency_{slot}", LENGTH, note="The Agency intro: someone at a desk.")
    phone = slot == "phone"
    ear = reach(1, (0.85, 1.45, -0.15), direction=(0.2, 0.9, -0.3))  # (a phone at the right ear)
    t, tempo = 0.0, rng.uniform(0.2, 0.27)  # (a key a stroke pair: finer keys burst Roblox's script size limit)
    stop = STOP + rng.uniform(0.0, 0.5) if not phone else 7.05
    while t < stop:
        if phone:  # talking: the head nodding, the free hand on the desk
            desk_key(m, t, lean=-4, neck=(-6 + 4 * math.sin(t * 3), 10 * math.sin(t * 0.7), 6), right=ear, xl=0.1)
            t += 0.45
        else:
            desk_key(m, t, "linear", neck=(-12, 4 * math.sin(t * 2), 0), xr=0.12 * math.sin(t * 9 + k),
                     xl=0.12 * math.cos(t * 7 + k), up=0.06 * (int(t / tempo) % 2))
            t += tempo
    # the stop: everything still; the head comes up to the wall (on the phone, a beat sooner: the call told them)
    up = stop + 0.25
    if phone:
        desk_key(m, up, "out", lean=-1, neck=(12, 0, 0), right=ear, xl=0.1)
        desk_key(m, up + 0.6, "sine", lean=-1, neck=(14, 0, 0), right=reach(1, (0.7, 0.9, -0.6)), xl=0.1)  # (the phone down)
    else:
        desk_key(m, up, "out", lean=-3, neck=(12, 0, 0))
    desk_key(m, BLACK, "sine", lean=-2, neck=(13, 0, 2), right=reach(1, (0.7, 0.9, -0.6)) if phone else None,
             xl=0.1 if phone else 0.0)
    desk_key(m, LENGTH, "sine", lean=-2, neck=(13, 0, 2), right=reach(1, (0.7, 0.9, -0.6)) if phone else None,
             xl=0.1 if phone else 0.0)
    soft(m, head=3.0, arms=3.4)
    m.build()


for k, (slot, _, _) in enumerate(SEATED):
    seated_worker(k, slot)

# On their feet ---------------------------------------------------------------------------------------------

FOLDED = dict(rShoulder=J((40, 0, -38), (-0.3, 0.1, -0.22)), lShoulder=J((38, 0, 36), (0.3, 0.1, -0.22)))
POCKETS = dict(rShoulder=J((10, 0, -4), (-0.08, 0.12, -0.02)), lShoulder=J((10, 0, 4), (0.08, 0.12, -0.02)))
CHIN = dict(rShoulder=reach(1, (0.2, 1.0, -0.75), direction=(-0.3, 0.7, -0.6)), lShoulder=J((38, 0, 36), (0.3, 0.1, -0.22)))
FILE = dict(rShoulder=J((6, 0, 5)), lShoulder=reach(-1, (-0.35, 0.3, -0.75), direction=(0.4, 0.2, -0.9)))  # (a file at the chest)
STANCES = {"fold": FOLDED, "pockets": POCKETS, "chin": CHIN}


def stander(k, slot, x, z, stance):
    rng = random.Random(700 + k * 11)
    yaw = facing((x, z), TABLE) if slot in ("table",) else facing((x, z), (x - 1.0, z)) if slot == "board2" else \
        facing((x, z), WALL)
    m = Motion(f"IntroAgency_{slot}", LENGTH, note="The Agency intro: someone on the deck.")
    arms = STANCES[stance]
    m.key(0.0, root=(-3, 0, 0), neck=(-18 if slot != "rail" else 8, 0, 0), **arms)
    t = rng.uniform(1.0, 2.0)
    while t < STOP - 1.0:
        side = rng.choice((-1, 1))
        m.key(t, "sine", root=(-3, 3 * side, 0), neck=(-14 if slot != "rail" else 6, 20 * side, 0), **arms)
        t += rng.uniform(1.4, 2.4)
    stop = STOP + rng.uniform(0.0, 0.5)
    m.key(stop, root=(-3, 0, 0), neck=(-16 if slot != "rail" else 8, 0, 0), **arms)
    turn = turn_to(yaw, (x, z), WALL)
    m.key(stop + 0.35, "out", root=(-1, turn * 0.4, 0), neck=(14, turn * 0.55, 0), **arms)
    m.key(LENGTH, "sine", root=(-1, turn * 0.45, 0), neck=(14, turn * 0.55, 3), **arms)
    soft(m, head=2.8, arms=2.6)
    m.plant(stance=0.06)
    alive(m, 0.5, seed=80 + k)
    m.build()
    return yaw


STAND_YAWS = [stander(k, slot, x, z, stance) for k, (slot, x, z, stance) in enumerate(STANDING)]

# The pinner: pinning a photograph up on the evidence board (the left hand holds it flat, the right presses the pin),
# then the hand stays on it as the head turns to the wall.
p = Motion("IntroAgency_pinner", LENGTH, note="The Agency intro: a photograph pinned on the evidence board.")
PIN_L = reach(-1, (-0.25, 1.35, -1.25), direction=(0.2, 0.3, -0.95))
PIN_R0 = reach(1, (0.4, 1.7, -1.1), direction=(-0.3, 0.4, -0.9))
PIN_R1 = reach(1, (0.05, 1.45, -1.3), direction=(-0.3, 0.3, -0.95))
p.key(0.0, root=(-2, 0, 0), neck=(4, 0, 0), **FOLDED)
p.key(4.6, root=(-2, 0, 0), neck=(6, 0, 0), **FOLDED)
p.key(5.0, "sine", root=(-4, 0, 0), neck=(8, -6, 0), rShoulder=PIN_R0, lShoulder=PIN_L)
p.key(5.45, "in", root=(-6, 0, 0), neck=(6, -4, 0), rShoulder=PIN_R1, lShoulder=PIN_L)  # (the pin pressed home)
p.key(5.6, "out", root=(-5, 0, 0), neck=(6, -4, 0), rShoulder=reach(1, (0.1, 1.4, -1.2)), lShoulder=PIN_L)
p.key(6.1, "sine", root=(-3, 0, 0), neck=(4, 0, 0), rShoulder=reach(1, (0.3, 1.2, -1.15)), lShoulder=PIN_L)
ptn = turn_to(facing(PINNER, BOARD), PINNER, WALL)
p.key(STOP + 0.3, root=(-3, 0, 0), neck=(4, 0, 0), rShoulder=reach(1, (0.3, 1.2, -1.15)), lShoulder=PIN_L)
p.key(STOP + 0.7, "out", root=(-1, ptn * 0.45, 0), neck=(12, ptn * 0.5, 0), rShoulder=J((10, 0, 6)), lShoulder=PIN_L)
p.key(LENGTH, "sine", root=(-1, ptn * 0.5, 0), neck=(12, ptn * 0.5, 2), rShoulder=J((10, 0, 6)), lShoulder=PIN_L)
soft(p, head=2.8, arms=2.6)
p.plant(stance=0.06)
p.build()

# The two with files, striding down the aisle at the camera; stopped dead mid-aisle by the flare, heads up to it.


def walker(k, frm, to, start):
    m = Motion(f"IntroAgency_walker{k}", LENGTH, note="The Agency intro: striding down the aisle with a file.")
    m.key(0.0, root=(-5, 0, 0), neck=(-8, 0, 0), **FILE)
    for i, t in enumerate([start + 0.3 + 0.4 * j for j in range(int((STOP - start) / 0.4))]):
        s = 1 if (i + k) % 2 else -1
        m.key(t, "sine", root=(-6, 2 * s, 0), neck=(-6, -2 * s + (12 if k == 1 and 4.6 < t < 5.4 else 0), 0),
              rShoulder=J((14 * s, 0, 5)), lShoulder=FILE["lShoulder"])
    s = 1 if k == 0 else -1  # (stopped dead, they turn round to look back at the wall behind them)
    m.key(STOP + 0.15 * k, "in", root=(-2, 0, 0), neck=(-4, 0, 0), **FILE)
    m.key(STOP + 0.15 * k + 0.45, "out", root=(1, 34 * s, 0), neck=(12, 48 * s, 0), **FILE)
    m.key(LENGTH, "sine", root=(1, 38 * s, 0), neck=(12, 50 * s, 3), **FILE)
    speed = math.hypot(to[0] - frm[0], to[1] - frm[1]) / (STOP - start)
    walking(m, start, STOP + 0.15 * k, speed=speed)
    m.plant(None, start, stance=0.06)
    m.plant(STOP + 0.15 * k, None, stance=0.06)
    soft(m, head=2.6, arms=2.6)
    m.build()


for k, (frm, to, start) in enumerate(WALKERS):
    walker(k, frm, to, start)

# The lead: at the head of the aisle with a report, looking up with the rest at the flare; then walks down the aisle
# to the rail to face the wall; at the rail, the head turns slowly over the shoulder: something behind them.
lead = Motion("IntroAgency_lead", LENGTH, note="The Agency intro: the one who walks down to the wall.")
lead.key(0.0, root=(-4, 0, 0), neck=(-22, 0, 0), **FILE)
lead.key(3.0, "sine", root=(-4, 4, 0), neck=(-20, 14, 0), **FILE)
lead.key(5.6, "sine", root=(-4, 0, 0), neck=(-24, 0, 0), **FILE)
lead.key(STOP + 0.2, root=(-4, 0, 0), neck=(-22, 0, 0), **FILE)
lead.key(STOP + 0.5, "out", root=(0, 0, 0), neck=(12, 0, 0), **FILE)
lead.key(LEAD_WALK[0], root=(-2, 0, 0), neck=(10, 0, 0), rShoulder=J((6, 0, 5)), lShoulder=J((6, 0, -5)))
for i, t in enumerate([LEAD_WALK[0] + 0.25 + 0.4 * j for j in range(int((LEAD_WALK[1] - LEAD_WALK[0]) / 0.4))]):
    s = 1 if i % 2 else -1
    lead.key(t, "sine", root=(-5, 2 * s, 0), neck=(10, -2 * s, 0), rShoulder=J((14 * s, 0, 5)), lShoulder=J((-14 * s, 0, -5)))
lead.key(LEAD_WALK[1] + 0.3, "out", root=(-1, 0, 0), neck=(16, 0, 0), rShoulder=J((6, 0, 5)), lShoulder=J((6, 0, -5)))
lead.key(TURN, "sine", root=(-1, 0, 0), neck=(16, 0, 0), rShoulder=J((6, 0, 5)), lShoulder=J((6, 0, -5)))
lead.key(TURN + 1.2, "sine", root=(-1, -14, 0), neck=(2, -58, 0), rShoulder=J((6, 0, 5)), lShoulder=J((6, 0, -5)))  # (over the shoulder)
lead.key(LENGTH, "sine", root=(-1, -18, 0), neck=(0, -62, 0), rShoulder=J((6, 0, 5)), lShoulder=J((6, 0, -5)))
walking(lead, LEAD_WALK[0], LEAD_WALK[1], speed=math.hypot(LEAD_TO[0] - LEAD_FROM[0], LEAD_TO[1] - LEAD_FROM[1]) /
        (LEAD_WALK[1] - LEAD_WALK[0]))
lead.plant(None, LEAD_WALK[0], stance=0.06)
lead.plant(LEAD_WALK[1], None, stance=0.06)
soft(lead, head=2.8, arms=2.6)
lead.build()

# The shot -------------------------------------------------------------------------------------------------

shot = Shot(NAME, "Agency", LENGTH, note="Agency intro: the operations deck at work, until the wall stops it.",
            skippable=True, mood="TaskForceHQ")
shot.own = True  # players in their own avatars (the owner, 2026-10-28)
shot.allow = {}

la = shot.actor("lead", lead)
la.mark(0.0, (LEAD_FROM[0], Y, LEAD_FROM[1]), 0.0)
la.mark(LEAD_WALK[0], (LEAD_FROM[0], Y, LEAD_FROM[1]), 0.0)
la.mark(LEAD_WALK[1], (LEAD_TO[0], Y, LEAD_TO[1]), 0.0, "linear")
la.mark(LENGTH, (LEAD_TO[0], Y, LEAD_TO[1]), 0.0)
la.hold("PaperNote", "Left Arm", (0.0, -1.05, -0.3), (80, 0, 0), t1=LEAD_WALK[0])
n = 1
for slot, dx, dz in SEATED:
    a = shot.actor(f"everyone:{n}", clip=f"IntroAgency_{slot}")
    a.mark(0.0, (dx, Y, dz + 2.9), 0.0)
    shot.allow[a.slot] = ["OfficeChair", "Desk"]  # (sat at their own desk)
    if slot == "phone":
        a.hold("Smartphone", "Right Arm", (0.0, -1.05, -0.2), (-14, 0, 0), t1=7.75)
    n += 1
for (slot, x, z, _), yaw in zip(STANDING, STAND_YAWS):
    a = shot.actor(f"everyone:{n}", clip=f"IntroAgency_{slot}")
    a.mark(0.0, (x, Y, z), yaw)
    n += 1
pa = shot.actor(f"everyone:{n}", clip="IntroAgency_pinner")
pa.mark(0.0, (PINNER[0], Y, PINNER[1]), facing(PINNER, BOARD))
pa.hold("PaperNote", "Left Arm", (0.0, -1.05, -0.2), (80, 0, 0), t0=4.7)
n += 1
for k, (frm, to, start) in enumerate(WALKERS):
    a = shot.actor(f"everyone:{n}", clip=f"IntroAgency_walker{k}")
    a.mark(0.0, (frm[0], Y, frm[1]), 180.0)
    a.mark(start, (frm[0], Y, frm[1]), 180.0)
    a.mark(STOP + 0.15 * k, (to[0], Y, to[1]), 180.0, "linear")
    a.mark(LENGTH, (to[0], Y, to[1]), 180.0)
    a.hold("PaperNote", "Left Arm", (0.0, -1.05, -0.3), (80, 0, 0))
    n += 1

board = shot.prop("EvidenceBoard")
board.at(0.0, (BOARD[0], Y, BOARD[1]), (0, 90, 0))  # (its face to the deck)
board.at(LENGTH, (BOARD[0], Y, BOARD[1]), (0, 90, 0))
book = shot.prop("Grimoire", open=[(0.0, 0.0), (OPEN[0], 0.0), (OPEN[1], 1.0)])
book.at(0.0, (BOOK[0], Y + 2.8 + 0.22, BOOK[1]), (0, 90, 0))
book.at(LENGTH, (BOOK[0], Y + 2.8 + 0.22, BOOK[1]), (0, 90, 0))
PAGE = (BOOK[0], Y + 2.8 + 0.3, BOOK[1])
for k, (dx, dz, rot) in enumerate(((-3.4, 0.6, 20), (2.6, 1.4, -30), (-1.8, 2.4, 70), (3.4, -0.4, 5))):
    sheet = shot.prop("PaperSheet")
    sheet.at(0.0, (TABLE[0] + dx, Y + 2.82, TABLE[1] + dz), (0, rot, 0))
    sheet.at(LENGTH, (TABLE[0] + dx, Y + 2.82, TABLE[1] + dz), (0, rot, 0))

# The cameras, every one moving and held by hand.
TYPIST = (8.0, Y, 42.9)
PHONE = (30.0, Y, 52.9)
# A: high in the deck's corner by the rail, craning down onto it.
framing.dolly(shot, 0.0, CUTS[0], (4.0, 24.0, 36.6), (6.5, 22.4, 38.6), (20.0, 15.0, 55.0), (19.0, 15.6, 52.0), fov0=60,
              fov1=54, shake=0.4, seed=1, cut=False)  # (inside the rail: over the atrium the glass walls it off)
# B: the typist in profile from the end of the desk: the monitor's glow on the face, the hands going.
shot.pan(CUTS[0], CUTS[1], "everyone:1", (13.4, 19.3, 41.8), aim="Head", dy=-0.3, fov=44, cut=True, drift=(-0.2, 0.0, 0.3),
         operator=True, seed=2, shake=0.5, fov_to=34)
# C: low in the centre aisle, backing away: the two striding at us.
shot.pan(CUTS[1], CUTS[2], "everyone:10", (17.6, 16.8, 55.6), aim="Torso", dy=0.6, fov=50, cut=True, drift=(0.0, 0.1, 0.8),
         operator=True, seed=3, shake=0.7, fov_to=46)
# D: the evidence board, close past the pinner's shoulder: the photograph pinned.
framing.dolly(shot, CUTS[2], CUTS[3], (30.6, 19.6, 54.2), (31.4, 19.4, 55.0), (BOARD[0] - 0.4, 18.8, BOARD[1] + 0.4), fov0=52, fov1=46,
              roll0=-4.0, roll1=-6.0, shake=0.5, seed=4)
# E: the one on the phone, from in front across the desk: the talking stops; the eyes come up.
shot.pan(CUTS[3], CUTS[4], "everyone:2", (31.6, 19.0, 47.0), aim="Head", dy=-0.2, fov=40, cut=True, drift=(-0.2, 0.0, 0.4),
         operator=True, seed=5, shake=0.5, fov_to=34, ease_move=True)
# F: from the rail, low, looking up across the atrium: the wall of the dead; one screen flares.
framing.dolly(shot, CUTS[4], CUTS[5], (17.0, 16.4, 36.4), (17.0, 16.9, 35.6), (17.0, 27.0, -5.5), (14.0, 27.5, -5.5),
              fov0=56, fov1=40, shake=0.4, seed=6)
# G: high from the rail's corner, looking back across the deck: everyone stopped, turned to the wall.
framing.dolly(shot, CUTS[5], CUTS[6], (25.0, 23.5, 36.4), (24.0, 22.8, 37.2), (15.0, 15.5, 48.0), fov0=60, fov1=54, shake=0.6,
              seed=7)
# H: behind the lead, tracking down the aisle to the rail.
shot.pan(CUTS[6], CUTS[7], "lead", (10.6, 20.6, 54.6), aim="Head", dy=-0.4, fov=56, cut=True, drift=(3.0, -0.8, -10.0),
         back=True, operator=True, seed=8, shake=0.6, ease_move=True)
# I: the empty table, low: the lamp over it stutters; the cover lifts by itself.
framing.dolly(shot, CUTS[7], CUTS[8], (19.4, 17.6, 63.4), (18.6, 17.5, 62.6), (BOOK[0], Y + 3.1, BOOK[1]), fov0=44, fov1=36,
              roll0=6.0, roll1=9.0, shake=0.3, seed=9)
# J: the lead at the rail from the atrium side, close, the wall's red on the face: the head turns over the shoulder.
shot.pan(CUTS[8], CUTS[9], "lead", (17.8, 18.9, 31.4), aim="Head", dy=-0.1, fov=38, cut=True, drift=(0.0, 0.0, 0.5),
         roll=-6.0, operator=True, seed=10, shake=0.35, fov_to=31, ease_move=True)
# K: from behind the open Manual, low: far down the aisle the lead turned to us; coming down into the page.
framing.dolly(shot, CUTS[9], BLACK, (17.0, Y + 4.6, 64.4), (BOOK[0] + 0.05, Y + 2.8 + 1.4, BOOK[1] + 0.6),
              (17.0, Y + 4.2, 40.0), PAGE, fov0=40, fov1=36, roll0=0.0, roll1=8.0, shake=0.3, seed=11)
shot.subjects.append((BLACK, LENGTH, None, True))
shot.cam(BLACK, (17.0, Y + 6.0, 64.4), PAGE, fov=44, cut=True)
shot.cam(LENGTH, (17.0, Y + 6.0, 64.4), PAGE, fov=44, ease="linear")

# The lens: barely soft.
for t, slot, part, radius in ((CUTS[0], "everyone:1", "Head", 2.5), (CUTS[3], "everyone:2", "Head", 2.5),
                              (CUTS[6], "lead", "Head", 6.0), (CUTS[8], "lead", "Head", 2.5)):
    shot.event(t, "fx", name="focus", slot=slot, part=part, radius=radius, far=0.12, near=0.06)
for t in (0.0, CUTS[1], CUTS[4], CUTS[7], CUTS[9]):
    shot.event(t, "fx", name="focus")

# The light: the deck under its desk lamps, the monitors' cold glow on the faces; the wall's cold light over the rail;
# when the new face flares, its red light washes over everyone turned to it; the table's lamp stutters over the
# Manual. The grade: dark, cold.
shot.grade = (0.2, -0.08, -0.05, (226, 234, 255))
shot.light("spot", (TYPIST[0], Y + 3.6, TYPIST[2] - 2.6), (TYPIST[0], Y + 4.6, TYPIST[2]), color=(170, 210, 255),
           brightness=1.2, range=6, angle=60, flicker=0.3)  # (the typist's monitor)
shot.light("spot", (PHONE[0], Y + 3.6, PHONE[2] - 2.6), (PHONE[0], Y + 4.6, PHONE[2]), color=(170, 210, 255),
           brightness=1.0, range=6, angle=60, flicker=0.3)
shot.light("spot", (17.0, 24.0, 20.0), (17.0, 17.0, 40.0), color=(170, 190, 255), brightness=1.4, range=40, angle=45,
           shadows=False)  # (the wall's cold glow over the deck)
shot.light("spot", (17.0, 22.0, 18.0), (17.0, 17.0, 40.0), color=(255, 40, 50), brightness=2.4, range=44, angle=50,
           show=(FLARE, LENGTH), flicker=0.25)  # (the new one's red)
shot.light("spot", (TABLE[0], Y + 9.0, TABLE[1]), (BOOK[0], Y + 2.8, BOOK[1]), color=(215, 228, 255), brightness=2.0,
           range=14, angle=45, flicker=0.0, show=(0.0, OPEN[0] - 0.4))
shot.light("spot", (TABLE[0], Y + 9.0, TABLE[1]), (BOOK[0], Y + 2.8, BOOK[1]), color=(215, 228, 255), brightness=2.0,
           range=14, angle=45, flicker=0.95, show=(OPEN[0] - 0.4, LENGTH))  # (stuttering)

# Sound and effects.
shot.event(0.0, "sfx", slot="mapOfficeHum")
shot.event(0.0, "sfx", slot="mapRainGlass")
shot.event(0.3, "title", lines=["BUREAU HEADQUARTERS, 39F", "Operations, 00:04"], dur=1.9)
shot.event(CUTS[0], "sfx", slot="typewriter")
shot.event(CUTS[2] + 0.45, "sfx", slot="stamp")  # (the pin pressed home)
shot.event(CUTS[3] - 0.4, "sfx", slot="mapPhoneRing")
shot.event(FLARE, "fx", name="flash", r=255, g=40, b=50, strength=0.35, dur=0.35)
shot.event(FLARE, "sfx", slot="screenStatic")
shot.event(STOP, "sfx", slot="heartbeat")
shot.event(OPEN[0] - 0.4, "sfx", slot="hauntFlicker")
shot.event(OPEN[0], "sfx", slot="pageTurn")
for k, t in enumerate((OPEN[0] - 0.4, OPEN[0] - 0.2, OPEN[0] + 0.1)):  # (the lamp over the table dying and coming back)
    shot.event(t, "fx", name="flash", r=0, g=0, b=0, strength=0.55 - 0.1 * k, dur=0.1)
shot.event(TURN, "sfx", slot="hauntWhisper")
shot.event(BLACK, "fx", name="black", hush=True)
shot.event(BLACK + 0.5, "card", key="case", dur=LENGTH - BLACK - 0.5)
