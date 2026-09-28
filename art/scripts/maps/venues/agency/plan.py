"""Agency HQ's plan, in local studs: x east, z south (north is -z), y up. The Agency has the 38th
and 39th floors of the Kagegaoka Central Tower: 38F (the entry floor, y 0) and 39F (y 14), each a
plate of 200 x 150 studs with its south-east corner cut on the diagonal. The core (lifts, a fire
stair, closed service rooms) stands off-centre to the north-east with a corridor round it; the
rooms line the glass walls. Over the lobby the 39F floor is open (the atrium) and a grand stair
climbs to the operations deck, which faces the video wall on the core; the fire stair at the
core's east end is the second way between the floors.

Every room, wall line and gameplay spot the venue modules use is set here, so the layout sits in
one place. Run it on its own (python art/scripts/maps/venues/agency/plan.py) to check that no two
rooms overlap on a floor and every room stays on the plate.
"""

import os
import sys

if __name__ == "__main__":
    sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))

from maps import geo2d as g2  # noqa: E402

X0, X1, Z0, Z1 = -100.0, 100.0, -75.0, 75.0
CUT = ((100.0, 35.0), (60.0, 75.0))  # the chamfered south-east corner, from its north end
PLATE = [(X0, Z0), (X1, Z0), CUT[0], CUT[1], (X0, Z1)]

L1 = 0.0  # 38F
CEIL1 = 13.0  # its ceiling (the 39F slab is 13..14)
L2 = 14.0  # 39F
CEIL2 = 27.0
ROOF = 28.0
LEVELS = (L1, L2)
BOUNDS = ((X0, -1.0, Z0), (X1, ROOF, Z1))

# The street far below (the city the windows look down on) and the tower's own name.
STREET_Y = -440.0
TOWER = "影ヶ丘セントラルタワー"
TOWER_EN = "KAGEGAOKA CENTRAL TOWER"


def box(x0, z0, x1, z1):
    return [(x0, z0), (x1, z0), (x1, z1), (x0, z1)]


def rect_of(r):
    return box(*r)


# The core and the corridor round it -------------------------------------------------------------------

CORE = (-8.0, -40.0, 42.0, -6.0)  # x0, z0, x1, z1
RING = (-16.0, -48.0, 50.0, 2.0)  # the corridor's outer edge (8 studs round the core)

# The fire stair, in the core's east end: a switchback, doors on the core's east face (x 42).
SHAFT = (30.0, -40.0, 42.0, -6.0)
FLIGHT_A = dict(x=(36.5, 41.5), z0=-14.0, z1=-30.0, y0=L1, y1=7.0)  # the landing up to the half landing
FLIGHT_B = dict(x=(30.5, 35.5), z0=-30.0, z1=-14.0, y0=7.0, y1=L2)  # the half landing up to 39F
DIVIDER = (35.8, 36.2)
HALF_LANDING = (-40.0, -30.0)  # z extent, all across the shaft, at y 7
LANDING = (-14.0, -6.0)  # z extent of each floor's landing
STAIR_DOOR_Z = -10.0

# The lifts (38F only; 39F is the Agency's own floor): three cars on the core's south face.
LIFTS_X = (11.5, 18.5, 25.5)
LIFT_W = 7.0

# The atrium: the hole in 39F's floor over the lobby, the grand stair along its west side.
VOID = (-4.0, 4.0, 38.0, 34.0)
GRAND = dict(x=(-4.0, 4.0), z0=34.0, z1=4.0)  # climbs north: z 34 at 38F up to z 4 at 39F
VIDEO_WALL = (-6.0, 40.0)  # x extent on the core's south face at 39F

# Rooms ------------------------------------------------------------------------------------------------
# Each: name -> (floor y, rectangle x0, z0, x1, z1 or a polygon). The corridor and the open plans
# (bullpen, lobby, operations) are what the rooms leave.

ROOMS_L1 = {
    "security": box(-100, -75, -58, -48),
    "observation": box(-58, -75, -44, -48),
    "interview_a": box(-44, -75, -26, -58),
    "interview_b": box(-26, -75, -8, -58),
    "copy": box(-8, -75, 24, -48),
    "lockers": box(24, -75, 50, -48),
    "break": box(50, -75, 100, -40),
    "night": box(50, -40, 100, 16),
    "sergeant": box(-100, 53, -76, 75),
}
LOUNGE = [(-16.0, 44.0), (50.0, 44.0), (50.0, 16.0), (100.0, 16.0), CUT[0], CUT[1], (-16.0, 75.0)]
LOBBY = box(-16, -6, 50, 44)
BULLPEN = box(-100, -48, -16, 75)

ROOMS_L2 = {
    "forensics": box(-100, -75, -50, -48),
    "lockup": box(-50, -75, -16, -48),
    "server": box(-16, -75, 30, -48),
    "archive": box(30, -75, 100, -48),
    "canteen": box(50, -48, 100, 16),
    "training": box(-100, 40, -16, 75),
    "director": [(60.0, 16.0), (100.0, 16.0), CUT[0], CUT[1]],
}
ANALYSTS = box(-100, -48, -16, 40)
OPS = [(-16.0, -6.0), (50.0, -6.0), (50.0, 16.0), (60.0, 16.0), (60.0, 75.0), (-16.0, 75.0)]


def rooms(level):
    return ROOMS_L1 if level == L1 else ROOMS_L2


# Checks ------------------------------------------------------------------------------------------------


def check():
    problems = []
    plate = g2.ccw(PLATE)
    core = rect_of(CORE)
    for level, table in ((L1, ROOMS_L1), (L2, ROOMS_L2)):
        items = list(table.items())
        extra = [("lounge", LOUNGE), ("lobby", LOBBY)] if level == L1 else [("ops", OPS)]
        for name, poly in items + extra:
            for p in poly:
                if not g2.contains(plate, (p[0] * 0.999, p[1] * 0.999)) and p not in PLATE:
                    problems.append(f"{level:.0f}: {name} leaves the plate at {p}")
            for piece in g2.convex_pieces(poly):
                hit = g2.intersect(g2.ccw(piece), g2.ccw(core))
                if hit and abs(g2.area(hit)) > 0.5:
                    problems.append(f"{level:.0f}: {name} overlaps the core")
        everything = items + extra
        for i, (a, pa) in enumerate(everything):
            for b, pb in everything[i + 1:]:
                for qa in g2.convex_pieces(pa):
                    for qb in g2.convex_pieces(pb):
                        hit = g2.intersect(g2.ccw(qa), g2.ccw(qb))
                        if hit and abs(g2.area(hit)) > 0.5:
                            problems.append(f"{level:.0f}: {a} overlaps {b}")
    return sorted(set(problems))


if __name__ == "__main__":
    found = check()
    print(f"{len(ROOMS_L1)} + {len(ROOMS_L2)} rooms, {len(found)} problem(s)")
    for p in found:
        print("  -", p)
