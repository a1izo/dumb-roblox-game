"""Kagegaoka University's gameplay spots outside the rooms' own (stations, sheets, drop points,
the tip box, the board and most hoods are placed with their rooms and grounds):
- the spawns, mid-avenue, where the case gathers under the ginkgos;
- the named areas with their intro marks;
- spare spawns and hoods all over the campus."""

from maps.venues.campus import plan as P

HY = P.HOLLOW_Y
GY = P.GALLERY_Y


def spawns(s):
    for x, z in P.SPAWNS:
        s.spawn(x, z, 0.0)
    for x, y, z in ((-40.0, 0.0, -34.0), (0.0, 0.0, -34.5), (60.0, 0.0, -34.0), (120.0, 0.0, -34.0), (146.0, 0.0, 0.0),
                    (56.0, 0.0, 28.0), (120.0, 0.0, 28.0), (-120.0, 0.0, 51.0), (-60.0, 0.0, 51.0), (20.0, 0.0, 96.0),
                    (-104.0, HY, 30.0), (-110.0, 0.0, -44.0)):
        s.spawn(x, z, y, spare=True)


def spots(s):
    s.hood(13.0, 64.0, spare=True)
    s.hood(-79.0, -60.0, spare=True)


# Each area: its name, where it is, its floor, and its two intro marks (x, z, the way they face).
AREAS = [
    ("the red gate", (-20.0, 100.0), 0.0, [(-24.0, 102.0, 0), (-16.0, 102.0, 0)]),
    ("the check-in tents", (6.0, 71.0), 0.0, [(-3.4, 67.0, -90), (-3.4, 75.0, -90)]),
    ("the guard booth", (8.0, 101.0), 0.0, [(4.0, 98.0, -90), (4.0, 104.0, -90)]),
    ("the ginkgo avenue", (-20.0, 40.0), 0.0, [(-23.0, 50.0, 0), (-17.0, 50.0, 0)]),
    ("the forecourt", (-20.0, -40.0), 0.0, [(-26.0, -41.0, 0), (-14.0, -41.0, 0)]),
    ("the clock tower", (-20.0, -55.0), 0.0, [(-23.0, -55.0, 0), (-17.0, -55.0, 0)]),
    ("the foyer", (-20.0, -70.0), 0.0, [(-26.0, -70.0, 0), (-14.0, -70.0, 0)]),
    ("the exam headquarters", (-54.0, -70.0), 0.0, [(-56.5, -67.0, 180), (-47.5, -67.8, 180)]),
    ("the proctors' room", (14.0, -70.0), 0.0, [(12.0, -68.0, 90), (12.0, -72.5, 90)]),
    ("the exam hall", (-20.0, -90.0), 0.0, [(-24.0, -81.0, 0), (-16.0, -81.0, 0)]),
    ("the arcade", (-79.0, -80.0), 0.0, [(-79.0, -70.0, 180), (-79.0, -90.0, 0)]),
    ("Law & Letters", (-91.0, -66.0), 0.0, [(-93.0, -62.0, 180), (-93.0, -70.0, 0)]),
    ("student affairs", (-120.0, -65.0), 0.0, [(-104.0, -66.0, 90), (-104.0, -58.0, 90)]),
    ("the seminar room", (-135.0, -94.0), 0.0, [(-140.0, -84.5, 0), (-132.0, -84.5, 0)]),
    ("the pond hollow", (-100.0, 30.0), HY, [(-112.0, 32.0, 0), (-106.0, 32.0, 0)]),
    ("the circulation desk", (56.0, -52.0), 0.0, [(56.0, -48.0, 0), (62.0, -48.0, 0)]),
    ("the reading room", (110.0, -60.0), 0.0, [(100.0, -45.5, 0), (120.0, -45.5, 0)]),
    ("the gallery", (110.0, -80.0), GY, [(100.0, -79.0, 180), (120.0, -79.0, 180)]),
    ("the stacks", (110.0, -96.0), 0.0, [(99.0, -86.4, 0), (121.0, -86.4, 0)]),
    ("the rare books room", (110.0, -95.0), GY, [(100.0, -90.5, 0), (120.0, -90.5, 0)]),
    ("the club house", (-118.0, 74.0), 0.0, [(-125.0, 74.0, 90), (-111.0, 74.0, -90)]),
    ("the kotatsu room", (-139.0, 94.0), 0.0, [(-139.0, 84.0, 180), (-133.0, 84.0, 180)]),
    ("the band room", (-119.0, 92.0), 0.0, [(-119.0, 85.0, 0), (-114.0, 85.0, 0)]),
    ("the cafeteria", (-60.0, 78.0), 0.0, [(-60.0, 66.0, 180), (-60.0, 76.0, 180)]),
    ("the Faculty of Science", (58.0, 70.0), 0.0, [(58.0, 62.0, 0), (58.0, 78.0, 180)]),
    ("the forensic medicine lab", (88.0, 56.0), 0.0, [(78.0, 46.0, -90), (78.0, 52.0, -90)]),
    ("the chemistry lab", (125.0, 57.0), 0.0, [(120.0, 57.0, 0), (130.0, 57.0, 0)]),
    ("the tennis court", (104.0, 28.0), 0.0, [(98.0, 28.0, 0), (110.0, 28.0, 0)]),
    ("the bike shed", (50.0, -20.0), 0.0, [(48.0, -12.0, 0), (54.0, -12.0, 0)]),
]


def areas(s):
    for name, (x, z), y, marks in AREAS:
        s.area(name, x, z, y=y, marks=[("stand", mx, mz, rot) for mx, mz, rot in marks])


def build(s):
    spawns(s)
    spots(s)
    areas(s)
