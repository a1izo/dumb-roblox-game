"""The second pass's dressing for Bureau HQ's rooms that read empty: the observation room's second
chair and cabinet, the copy room's files and pin board, a sofa corner in the lobby, armchair corners
and a sideboard in the lounge, shelves, a microscope table and a whiteboard in the forensics lab,
boxes of evidence in the lock-up, four training desks, a meeting table and a sideboard on the
operations deck, and a bench, cooler and plants along both corridors.

Every placement keeps the doorways, the stations' worker sides and the corridors' 6 studs clear."""

from maps.venues.agency import fit
from maps.venues.agency import plan as P

L1, L2 = P.L1, P.L2


def p(s, key, x, z, rot=0.0, scale=1.0, y=L1):
    s.prop(key, x, z, rot, scale, y)


def lower(s):
    # Observation: a second chair at the mirror, a filing cabinet between the two doors' walls.
    p(s, "Chair", -54.5, -68.0, -90)
    p(s, "FilingCabinet", -56.6, -62.0, -90)
    # The copy room: cabinets along the north wall west of the door, the shift's pin board east of it.
    for x in (-4.5, -2.1, 0.3):
        p(s, "FilingCabinet", x, -49.4, 0)
    s.prop("PinBoard", 17.0, -48.45, 0, 1.0, L1 + 6.5)
    # The lobby: a sofa corner by the planters, round a low table.
    p(s, "Sofa", 40.0, 13.4, 180)
    p(s, "Sofa", 40.0, 21.8, 0)
    fit.table(s, 40.0, 17.6, 5.0, 2.4, 0, L1, h=1.6)
    # The lounge: two armchair corners with a floor lamp, a sideboard and a cooler by the east glass.
    for cx in (5.0, 25.0):
        p(s, "ClubChair", cx - 3.6, 55.0, -90)
        p(s, "ClubChair", cx + 3.6, 55.0, 90)
        fit.table(s, cx, 55.0, 2.6, 2.6, 0, L1, h=1.6)
    p(s, "FloorLamp", 15.0, 58.0)
    p(s, "Sideboard", 97.3, 30.0, -90)
    p(s, "WaterCooler", 98.6, 60.0, -90)
    # The corridor round the core: a plant at its south-west corner.
    p(s, "Plant", -14.4, -46.4)


def upper(s):
    y = L2
    # Forensics: specimen shelves on the north wall between the doors, a microscope table, a whiteboard.
    for x in (-96.0, -78.0, -70.0):
        p(s, "SpecimenShelf", x, -49.2, 0, 1.0, y)
    # (The lab island in the middle is the room's own: a microscope on it, a chair at it.)
    p(s, "Microscope", -79.0, -58.6, 180, 1.0, y + 3.5)
    p(s, "OfficeChair", -79.0, -55.6, 180, 1.0, y)
    p(s, "Whiteboard", -97.7, -55.0, -90, 1.0, y)
    # The lock-up: boxes of evidence waiting to be logged.
    p(s, "Crate", -45.5, -51.2, 0, 0.6, y)
    p(s, "Crate", -42.8, -51.4, 12, 0.6, y)
    p(s, "Crate", -45.4, -51.2, 6, 0.6, y + 2.45)
    # Training: four desks facing the whiteboard in the east half.
    for x in (-40.0, -32.0):
        for z in (52.0, 60.0):
            fit.desk(s, x, z, 0, y, lamp=False)
    # The operations deck: the briefing table in its north-east corner, a sideboard on its east wall.
    fit.table(s, 46.0, 62.0, 10.0, 5.0, 0, y)
    fit.chairs_round(s, 46.0, 62.0, 10.0, 5.0, 0, y)
    p(s, "Sideboard", 58.4, 46.0, -90, 1.0, y)
    # The corridor round the core: a bench and a cooler against the outer walls, a plant at the corner.
    p(s, "Bench", 48.85, -18.0, 90, 0.9, y)
    p(s, "WaterCooler", -15.0, -24.0, -90, 1.0, y)
    p(s, "Plant", -14.4, -46.4, 0, 1.0, y)


# The blackout (Bureau HQ's mechanic) ---------------------------------------------------------------------

# Red emergency lamps, off until someone pulls the breaker: along the corridor round the core and over
# the open floors, on both storeys.
EMERGENCY = {
    L1: [(-12.0, -44.0), (22.0, -44.0), (46.0, -44.0), (-12.0, -14.0), (46.0, -14.0), (-58.0, -20.0), (-58.0, 30.0),
         (17.0, 20.0), (60.0, 40.0), (25.0, 60.0)],
    L2: [(-12.0, -44.0), (22.0, -44.0), (46.0, -44.0), (-12.0, -14.0), (46.0, -14.0), (-58.0, -20.0), (-58.0, 20.0),
         (-60.0, 58.0), (20.0, 50.0), (40.0, 10.0)],
}


def blackout(s):
    # The main breaker panel on the core's east face, 10 studs past the fire stair's door (the game
    # builds it at this anchor; its door folds flat against the wall).
    s.anchor("breaker", P.CORE[2] + 1.25, L1, -20.0, rot=-90)
    for level, spots in EMERGENCY.items():
        ceiling = P.CEIL1 if level == L1 else P.CEIL2
        for x, z in spots:
            s.box("RedTrim", (x, ceiling - 0.12, z), (1.0, 0.24, 0.5), skip=("+y",))
            s.box("NeonRed", (x, ceiling - 0.26, z), (0.8, 0.05, 0.3), skip=("+y",))
            s.light("point", (x, ceiling - 0.8, z), (255, 40, 40), 26, 0.9, role="emergency")


def build(s):
    lower(s)
    upper(s)
    blackout(s)
