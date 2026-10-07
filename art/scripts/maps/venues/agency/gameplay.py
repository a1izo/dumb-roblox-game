"""Agency HQ's gameplay spots outside the rooms' own (stations, sheets and some hoods
are placed with their rooms): the spawns (in the lobby and the bullpen, where the lifts and the
gates bring the Agency in), the named areas with their intro marks, a last hood and the spare
spawns on both floors."""

from maps.venues.agency import plan as P

L1, L2 = P.L1, P.L2


def spawns(s):
    for x, z in ((8, 13), (14, 13), (20, 13), (26, 13), (32, 13), (8, 19), (32, 19)):
        s.spawn(float(x), float(z), L1)
    for x, z in ((-22, 12), (-22, 28), (-24, 36), (-36, 30), (-26, -2)):
        s.spawn(float(x), float(z), L1)
    for x, y, z in ((-80, L1, 0), (72, L1, -48), (75, L1, 8), (20, L1, 58), (-58, L1, 58),
                    (17, L2, 70), (70, L2, -18), (-44, L2, -4), (-48, L2, 57), (40, L2, -62), (44, L2, 20), (-10, L2, 20)):
        s.spawn(float(x), float(z), y, spare=True)


def spots(s):
    s.hood(-97.5, 12.0, L1 + 0.6)


# Each area: its name, where it is, its floor, and its two intro marks (x, z, the way they face).
AREAS = [
    ("the lobby", (18, 14), L1, [(15, 16, 0), (21, 16, 180)]),
    ("the lounge", (30, 57), L1, [(27, 57, -90), (33, 57, 90)]),
    ("the bullpen", (-58, 8), L1, [(-61, 7, -90), (-55, 9, 90)]),
    ("the security office", (-80, -60), L1, [(-82, -60, 0), (-78, -62, 180)]),
    ("the observation room", (-52, -62), L1, [(-53, -60, -90), (-53, -64, -90)]),
    ("the interview rooms", (-26, -52), L1, [(-29, -52, 0), (-23, -52, 180)]),
    ("the copy room", (8, -55), L1, [(5, -54, 0), (11, -55, 180)]),
    ("the locker room", (37, -56), L1, [(35, -55, 90), (39, -55, -90)]),
    ("the break room", (74, -47), L1, [(71, -47, 0), (77, -47, 180)]),
    ("the night desk", (74, 9), L1, [(71, 9, -90), (77, 9, 90)]),
    ("the sergeant's office", (-84, 59), L1, [(-86, 59, 180), (-82, 58, 0)]),
    ("the operations deck", (17, 46), L2, [(14, 46, 180), (20, 46, 180)]),
    ("the director's office", (80, 45), L2, [(78, 46, 0), (82, 44, 180)]),
    ("the canteen", (69, -20), L2, [(69, -24, 0), (69, -16, 180)]),
    ("the archive", (42, -63), L2, [(40, -62, 90), (44, -63, -90)]),
    ("the server room", (-5, -53), L2, [(-7, -52, 90), (-3, -54, -90)]),
    ("the evidence lock-up", (-33, -58), L2, [(-35, -58, 90), (-31, -57, -90)]),
    ("the forensics lab", (-76, -64), L2, [(-79, -64, 90), (-73, -64, -90)]),
    ("the analysts' office", (-44, -6), L2, [(-46, -6, 90), (-42, -7, -90)]),
    ("the training room", (-48, 57), L2, [(-48, 54, 180), (-48, 60, 0)]),
]


def areas(s):
    for name, (x, z), y, marks in AREAS:
        s.area(name, float(x), float(z), y=y, marks=[("stand", float(mx), float(mz), rot) for mx, mz, rot in marks])


def build(s):
    spawns(s)
    spots(s)
    areas(s)
