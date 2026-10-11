"""Kagegaoka University's plan, in local studs: x east, z south (north is -z), y up. The campus
is 300 x 220 studs inside its wall. The red gate on the south wall opens onto the ginkgo avenue,
which runs north to the forecourt and the Great Auditorium with its clock tower. West of the
avenue lie Law & Letters (with its arcade), the pond hollow sunk 5 studs, the club house and the
cafeteria; east of it the library, the tennis court (look-only, fenced) and the science building.
The buildings on the edge have their backs on the boundary, so the wall only closes the gaps.

Every building, room, path and height the venue modules use is set here, so the layout sits in
one place. Run it on its own (python art/scripts/maps/venues/campus/plan.py) to check that no
two buildings or rooms overlap, that every path stays clear of the buildings and that it all
stays inside the wall.
"""

import os
import sys

if __name__ == "__main__":
    sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))

from maps import geo2d as g2  # noqa: E402

X0, X1, Z0, Z1 = -150.0, 150.0, -110.0, 110.0
WALL_T = 1.4  # the campus wall and the outer walls of the buildings
GF = 14.0  # a ground storey, floor to floor
UP = 12.0  # the storeys above (look-only)
CEIL = 13.0  # the ceiling of a ground-floor room (the slab above is 13..14)
HOLLOW_Y = -5.0
BOUNDS = ((X0, -8.0, Z0), (X1, 84.0, Z1))

UNIVERSITY = "影ヶ丘大学"
UNIVERSITY_EN = "KAGEGAOKA UNIVERSITY"


def box(x0, z0, x1, z1):
    return [(x0, z0), (x1, z0), (x1, z1), (x0, z1)]


def rect_of(r):
    return box(*r)


def inner(r, t=WALL_T):
    """A building's floor inside its outer walls."""
    return (r[0] + t, r[1] + t, r[2] - t, r[3] - t)


# Buildings (x0, z0, x1, z1) -----------------------------------------------------------------------

AUDITORIUM = (-66.0, -110.0, 26.0, -62.0)
TOWER = (-30.0, -62.0, -10.0, -48.0)  # the clock tower, standing out into the forecourt
LAW = (-150.0, -110.0, -82.0, -50.0)
ARCADE = (-82.0, -106.0, -76.0, -54.0)  # covered walk along Law & Letters' east face
LIBRARY = (40.0, -110.0, 150.0, -40.0)
CLUB = (-150.0, 58.0, -88.0, 110.0)
CAFETERIA = (-80.0, 58.0, -40.0, 110.0)
SCIENCE = (48.0, 36.0, 150.0, 110.0)
BOOTH = (-2.0, 92.0, 18.0, 108.0)
GATE = (-32.0, 104.0, -8.0, 110.0)  # the passage under the red gate
EAST_GATE = (-6.0, 6.0)  # z span of the iron gate in the east wall

BUILDINGS = {
    "auditorium": AUDITORIUM,
    "tower": TOWER,
    "law": LAW,
    "library": LIBRARY,
    "club": CLUB,
    "cafeteria": CAFETERIA,
    "science": SCIENCE,
    "booth": BOOTH,
}

# Heights: eaves (the top of the walls) and the roof's rise above them.
EAVES = {"auditorium": 26.0, "law": 38.0, "library": 30.0, "club": 38.0, "cafeteria": 16.0, "science": 38.0,
         "booth": 10.0}
TOWER_TOP = 60.0  # the tower's parapet; the spire rises from here
SPIRE = 20.0
CLOCK_Y = 47.0  # the middle of the clock faces
CLOCK_R = 4.2

# Doors: building -> [(face, centre along x or z, width)]. Faces: "n" (z0), "s" (z1), "w" (x0),
# "e" (x1). Height is fit.DOOR_H unless the module says otherwise.
DOORS = {
    "tower": [("s", -20.0, 8.0), ("n", -20.0, 6.0)],
    "auditorium": [("w", -94.0, 5.0), ("e", -94.0, 5.0)],
    "law": [("e", -80.0, 6.0), ("s", -91.0, 5.0)],
    "library": [("w", -52.0, 6.0), ("s", 110.0, 6.0)],
    "club": [("n", -118.0, 6.0), ("e", 74.0, 5.0)],
    "cafeteria": [("n", -60.0, 8.0), ("w", 84.0, 5.0), ("e", 70.0, 5.0)],
    "science": [("n", 58.0, 6.0), ("w", 72.0, 6.0)],
    "booth": [("w", 101.0, 4.0)],
}

# Rooms (ground floor unless noted) -----------------------------------------------------------------

FOYER_Z = (-78.0, -62.0)  # the foyer band across the auditorium's south side
HALL_Z = (-110.0, -78.0)  # the exam hall behind it
EXAM_HQ = (-64.6, -77.7, -44.0, -63.4)
PROCTOR = (4.0, -77.7, 24.6, -63.4)
STAGE = (-64.6, -108.6, 24.6, -101.0)  # look-only, 1.2 high, guarded
HALL_H = 24.0  # the exam hall's ceiling (its roof trusses above)

LAW_HALL = (-98.0, -108.6, -83.4, -51.4)  # the entrance hall along the arcade
AFFAIRS = (-148.6, -80.0, -98.0, -51.4)  # student affairs, the exam paper vault
SEMINAR = (-148.6, -108.6, -122.0, -80.0)
PROFESSOR = (-122.0, -108.6, -98.0, -80.0)

CIRCULATION = (41.4, -64.0, 72.0, -41.4)
MICROFILM = (41.4, -108.6, 72.0, -64.0)
READING = (72.0, -84.0, 148.6, -41.4)  # double height, its ceiling at READING_H
READING_H = 28.0
STACKS = (72.0, -108.6, 148.6, -84.0)  # ground floor, under the rare books room
GALLERY_Y = 12.0
GALLERY = (72.0, -84.0, 148.6, -76.0)  # along the reading room's north side, at GALLERY_Y
RARE_BOOKS = (72.0, -108.6, 148.6, -84.0)  # at GALLERY_Y, over the stacks
# The gallery's two stairs, along the reading room's side walls: (x centre, width, foot z, head z).
GALLERY_STAIRS = [(74.3, 4.0, -59.5, -76.0), (146.3, 4.0, -50.0, -76.0)]

CLUB_ENTRY = (-128.0, 59.4, -108.0, 71.0)
CLUB_CORRIDOR = (-148.6, 71.0, -89.4, 77.0)
NEWSROOM = (-148.6, 59.4, -128.0, 71.0)
FILM_CLUB = (-108.0, 59.4, -89.4, 71.0)
KOTATSU = (-148.6, 77.0, -129.0, 108.6)
BAND_ROOM = (-129.0, 77.0, -109.0, 108.6)
LOCKER_ROOM = (-109.0, 77.0, -89.4, 108.6)

DINING = (-78.6, 59.4, -41.4, 96.0)
KITCHEN = (-78.6, 96.0, -41.4, 108.6)  # behind the counter, look-only

SCI_HALL = (49.4, 37.4, 68.0, 108.6)
FORENSIC = (68.0, 37.4, 108.0, 72.0)
CHEMISTRY = (108.0, 37.4, 148.6, 72.0)
SPECIMENS = (68.0, 72.0, 108.0, 108.6)
LECTURE_ROOM = (108.0, 72.0, 148.6, 108.6)  # shut

ROOMS = {
    "exam_hq": EXAM_HQ, "proctor": PROCTOR, "law_hall": LAW_HALL, "affairs": AFFAIRS, "seminar": SEMINAR,
    "professor": PROFESSOR, "circulation": CIRCULATION, "microfilm": MICROFILM, "reading": READING,
    "stacks": STACKS, "club_entry": CLUB_ENTRY, "club_corridor": CLUB_CORRIDOR, "newsroom": NEWSROOM,
    "film_club": FILM_CLUB, "kotatsu": KOTATSU, "band_room": BAND_ROOM, "locker_room": LOCKER_ROOM,
    "dining": DINING, "kitchen": KITCHEN, "sci_hall": SCI_HALL, "forensic": FORENSIC, "chemistry": CHEMISTRY,
    "specimens": SPECIMENS, "lecture_room": LECTURE_ROOM,
}
ROOM_OF = {  # which building each room is in
    "exam_hq": "auditorium", "proctor": "auditorium", "law_hall": "law", "affairs": "law", "seminar": "law",
    "professor": "law", "circulation": "library", "microfilm": "library", "reading": "library",
    "stacks": "library", "club_entry": "club", "club_corridor": "club", "newsroom": "club", "film_club": "club",
    "kotatsu": "club", "band_room": "club", "locker_room": "club", "dining": "cafeteria", "kitchen": "cafeteria",
    "sci_hall": "science", "forensic": "science", "chemistry": "science", "specimens": "science",
    "lecture_room": "science",
}

# Outdoors ---------------------------------------------------------------------------------------------

AVENUE = (-32.0, -30.0, -8.0, 110.0)
FORECOURT = (-66.0, -62.0, 26.0, -38.0)  # and its south strip, PATHS["forecourt_s"]
HOLLOW = (-150.0, -38.0, -52.0, 44.0)  # the rim; its floor at HOLLOW_Y
COURT = (66.0, -28.0, 142.0, 20.0)  # the fence line; look-only inside
TENTS = (0.0, 62.0, 32.0, 80.0)
BIKE_SHED = (40.0, -24.0, 60.0, -16.0)

# Shovelled paths (the rest is snow), each a rectangle.
PATHS = {
    "avenue": AVENUE,
    "forecourt": (-66.0, -62.0, 26.0, -38.0),
    "forecourt_s": (-52.0, -38.0, 26.0, -30.0),
    "west_side": (-76.0, -110.0, -66.0, -50.0),
    "north_rim": (-150.0, -50.0, -66.0, -38.0),
    "east_side": (26.0, -110.0, 40.0, -40.0),
    "lib_court": (26.0, -40.0, 150.0, -28.0),
    "east_path": (142.0, -28.0, 150.0, 22.0),
    "east_cross": (-8.0, 22.0, 150.0, 34.0),
    "west_cross": (-52.0, 2.0, -32.0, 10.0),
    "south": (-150.0, 44.0, -32.0, 58.0),
    "alley": (-88.0, 58.0, -80.0, 110.0),
    "cafe_east": (-40.0, 58.0, -32.0, 110.0),
    "gate_plaza": (-8.0, 84.0, 48.0, 110.0),
    "science_west": (36.0, 34.0, 48.0, 84.0),
    "science_door": (54.0, 34.0, 62.0, 36.0),
}

# The hollow: its floor at HOLLOW_Y all round the frozen pond, three ways down, a bridge over the
# pond's middle.
POND = [(-142.0, -2.0), (-138.0, -9.0), (-126.0, -12.0), (-110.0, -10.0), (-96.0, -12.0), (-82.0, -9.0),
        (-73.0, -2.0), (-74.0, 8.0), (-84.0, 14.0), (-100.0, 12.0), (-116.0, 16.0), (-132.0, 13.0), (-141.0, 6.0)]
POND_Y = HOLLOW_Y - 0.4  # the ice
BRIDGE = dict(x=-104.0, w=5.0, z0=-19.0, z1=23.0, rise=2.2, ramp=8.0)
# The ways down: (kind, top (x, z) at the rim, foot (x, z) on the hollow floor, width).
HOLLOW_WAYS = [
    ("slope", (-52.0, 6.0), (-68.0, 6.0), 8.0),  # from the west cross path
    ("stairs", (-120.0, -38.0), (-120.0, -28.0), 6.0),  # from the north rim path
    ("slope", (-90.0, 44.0), (-90.0, 30.0), 8.0),  # from the south path
]

# The avenue's trees (both sides, on the lawn just off the paving) and its spawns.
GINKGO_X = (-35.5, -4.5)
GINKGO_Z = [-20.0 + 14.0 * k for k in range(9)]  # -20 .. 92
SPAWNS = [(x, z) for z in (12.0, 20.0, 28.0, 36.0) for x in (-26.0, -20.0, -14.0)]


# Checks ------------------------------------------------------------------------------------------------


def _overlap(a, b):
    hit = g2.intersect(g2.ccw(a), g2.ccw(b))
    return bool(hit) and abs(g2.area(hit)) > 0.5


def check():
    problems = []
    bounds = box(X0, Z0, X1, Z1)
    items = list(BUILDINGS.items())
    for name, r in items:
        if r[0] < X0 or r[2] > X1 or r[1] < Z0 or r[3] > Z1:
            problems.append(f"{name} leaves the campus")
    for i, (a, ra) in enumerate(items):
        for b, rb in items[i + 1:]:
            if {a, b} == {"auditorium", "tower"}:
                continue
            if _overlap(rect_of(ra), rect_of(rb)):
                problems.append(f"{a} overlaps {b}")
    for pname, pr in PATHS.items():
        if not _overlap(rect_of(pr), bounds):
            problems.append(f"path {pname} is outside the campus")
        for bname, br in items:
            if (pname, bname) in (("forecourt", "tower"), ("gate_plaza", "booth")):
                continue
            if _overlap(rect_of(pr), rect_of(br)):
                problems.append(f"path {pname} runs into {bname}")
        if _overlap(rect_of(pr), rect_of(HOLLOW)):
            problems.append(f"path {pname} runs into the hollow")
        if _overlap(rect_of(pr), rect_of(COURT)):
            problems.append(f"path {pname} runs into the court")
    for name, r in ROOMS.items():
        home = inner(BUILDINGS[ROOM_OF[name]])
        if r[0] < home[0] - 0.01 or r[2] > home[2] + 0.01 or r[1] < home[1] - 0.01 or r[3] > home[3] + 0.01:
            problems.append(f"room {name} leaves its building")
    names = list(ROOMS)
    for i, a in enumerate(names):
        for b in names[i + 1:]:
            if _overlap(rect_of(ROOMS[a]), rect_of(ROOMS[b])):
                problems.append(f"room {a} overlaps {b}")
    for name, r in (("court", COURT), ("tents", TENTS), ("bike shed", BIKE_SHED)):
        for bname, br in items:
            if _overlap(rect_of(r), rect_of(br)):
                problems.append(f"{name} overlaps {bname}")
    hx0, hz0, hx1, hz1 = HOLLOW
    for x, z in POND:
        if not (hx0 + 6 < x < hx1 - 6 and hz0 + 6 < z < hz1 - 6):
            problems.append(f"the pond comes within 6 of the hollow's wall at {(x, z)}")
    for x, z in SPAWNS:
        if not g2.contains(rect_of(AVENUE), (x, z)):
            problems.append(f"spawn {(x, z)} is off the avenue")
    return sorted(set(problems))


if __name__ == "__main__":
    found = check()
    print(f"{len(BUILDINGS)} buildings, {len(ROOMS)} rooms, {len(PATHS)} paths, {len(found)} problem(s)")
    for p in found:
        print("  -", p)
