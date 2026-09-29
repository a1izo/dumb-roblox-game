"""The war room's plan, in local studs: x east, z south (north is -z), y up; the meeting room's
origin (Venues.MEETING). 60 x 60 studs, 18 high, the same room every case meets in:

- the round table in the middle, its twelve standing places at 17 studs, a chair behind each;
- Zero's screen (30 x 12, its middle 10 up) on the north wall between two speaker columns;
- the evidence board (18 x 9) on the east wall, the case wall of pinned photographs round it, the
  records door north of it;
- three windows in the south wall with venetian blinds half open over the city at night;
- bookcases, the sideboard and the clock on the west wall;
- the Specters' mezzanine at 12 round the east, south and west walls and the north corners (it
  stops short of the screen), which only Specters reach (they fly).

Run on its own to check the numbers (python art/scripts/maps/venues/meeting/plan.py)."""

import math
import os
import sys

if __name__ == "__main__":
    sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))

HALF = 30.0
H = 18.0
WALL_T = 1.0
IN = HALF - WALL_T / 2  # the inner face of the walls
BOUNDS = ((-HALF, 0.0, -HALF), (HALF, H, HALF))

TABLE_R = 13.05
SEATS = 12
SEAT_R = 17.0
CHAIR_R = 19.6

SCREEN = (0.0, 10.0, -IN + 0.2, 180.0, 30.0, 12.0)  # x, y, z, rot, w, h (the game builds it)
BOARD = (IN - 0.2, 7.2, 0.0, 90.0, 18.0, 9.0)
DOOR_Z = -23.0  # the records door in the east wall
WINDOWS = [16.0, 0.0, -16.0]  # x of each south window's middle
WINDOW = (7.0, 6.8, 11.4)  # width, sill (over the panelling), head

GALLERY_Y = 12.0
GALLERY_D = 3.5
GALLERY_GAP = 16.5  # the north walkway stops |x| < this (Zero's screen)
SPEAKERS = (19.5, -IN + 1.1)


def seats():
    """(x, z, rot) of each standing place, facing the table (the game's seat CFrames)."""
    out = []
    for i in range(SEATS):
        a = i * 2 * math.pi / SEATS
        x, z = math.sin(a) * SEAT_R, math.cos(a) * SEAT_R
        out.append((x, z, math.degrees(a)))
    return out


def chairs():
    out = []
    for i in range(SEATS):
        a = i * 2 * math.pi / SEATS
        out.append((math.sin(a) * CHAIR_R, math.cos(a) * CHAIR_R, math.degrees(a)))
    return out


def gallery_spots():
    """Where Specters stand on the mezzanine (y on its floor), facing the table."""
    mid = IN - GALLERY_D / 2
    pts = [(mid, z) for z in (-20.0, -10.0, 0.0, 10.0, 20.0)]
    pts += [(x, mid) for x in (20.0, 10.0, 0.0, -10.0, -20.0)]
    pts += [(-mid, z) for z in (20.0, 10.0, 0.0, -10.0, -20.0)]
    pts += [(-23.0, -mid)]
    out = []
    for x, z in pts:
        out.append((x, z, math.degrees(math.atan2(x, z))))
    return out


def check():
    problems = []
    for x, z, rot in seats():
        if math.hypot(x, z) - TABLE_R < 3.0:
            problems.append(f"seat at {x:.1f}, {z:.1f} is too close to the table")
    for x, z, rot in chairs():
        if abs(x) > IN - 1.4 or abs(z) > IN - 1.4:
            problems.append(f"chair at {x:.1f}, {z:.1f} touches a wall")
    sx, sy, sz, srot, sw, sh = SCREEN
    if sy + sh / 2 > H - 1.0:
        problems.append("the screen reaches the ceiling")
    if sw / 2 > GALLERY_GAP - 0.5:
        problems.append("the north mezzanine crosses the screen")
    bx, by, bz, brot, bw, bh = BOARD
    if by + bh / 2 > GALLERY_Y - 0.2:
        problems.append("the board reaches the mezzanine")
    if abs(DOOR_Z) - 3.4 < bw / 2 + 1.0:
        problems.append("the door touches the board")
    if SPEAKERS[0] - 1.4 < sw / 2 + 0.8:
        problems.append("the speakers touch the screen")
    return problems


if __name__ == "__main__":
    found = check()
    print(f"{SEATS} seats, {len(gallery_spots())} gallery spots, {len(found)} problem(s)")
    for p in found:
        print("  -", p)
