"""Tokyo's gameplay spots outside the rooms: the payphone booth by the police box,
hoods, the spawns round the scramble, named areas with their intro marks, and spare spots of every
kind. The stations, sheets, tip box and board inside buildings are placed with their rooms
(interiors.py).

Positions are set against the plan's buildings (plan.BUILDINGS); a spot inside a building sits on
the floor it names (ground floor y 0, the floor above y 14)."""

from maps import geo2d as g2
from maps.venues.tokyo import plan as P

UP = P.FLOOR_GF  # the first floor up


def centre(name, dx=0.0, dz=0.0):
    b = next(b for b in P.BUILDINGS if b["name"] == name)
    c = g2.centroid(b["poly"])
    return c[0] + dx, c[1] + dz


def stations(s):
    """The one station that stands outdoors: a real payphone booth on the plaza by the police box,
    off the kerb. The others are in the rooms that hold them (interiors.py)."""
    s.station("Phone", "Crossing Phone Booth", -84.0, -40.0, 60, prop="StationPhoneBooth")


def spots(s):
    s.hood(64.0, -76.0)
    s.hood(-16.0, 110.5)
    s.hood(-150.0, 108.0, spare=True)
    s.hood(114.0, 118.0, spare=True)


def spawns(s):
    """Three on each corner of the scramble: the station plaza, the corner by the police box's
    street, the department store's corner and the corner in front of the glass tower."""
    for x, z in [(-80, -44), (-86, -52), (-62, -42),
                 (-6, -40), (2, -52), (-34, -28),
                 (-6, -68), (-14, -80), (-2, -88),
                 (-78, -88), (-58, -104), (-46, -92)]:
        s.spawn(float(x), float(z))
    for x, z in [(-150, 20), (-60, 20), (36, 10), (140, 30), (-140, 60), (-80, 90.5), (0, 90.5), (112, 80),
                 (60, -100), (100, -100), (150, -51), (-40, 130)]:
        s.spawn(float(x), float(z), spare=True)


# Each area: its name, where it is, its floor, and where the two intro marks stand when they are
# not beside that spot (the scramble's are on a corner, clear of the crossing; the police box's
# between its counter and its desk).
AREAS = [
    ("the scramble", (-40, -62), 0.0, [(-60, -40), (-58, -36)]),
    ("the station plaza", (-86, -44)),
    ("the station hall", (-130, -80)),
    ("the metro platform", (-60, -62), P.PLATFORM_Y),
    ("the police box", centre("koban"), 0.0, [(-67.3, -31.2), (-64.9, -30.5)]),
    ("the glass tower", (-36, -94)),
    ("the department store", (34, -80)),
    ("the shopping street", (60, -101)),
    ("the back alley", (56, -14)),
    ("the river walk", (-40, 20)),
    ("the footbridge", (P.FOOTBRIDGE_X, 40)),
    ("the yokocho", (-60, 90.5)),
    ("the karaoke tower", (92, 80)),
    ("the viaduct lane", (40, 130)),
]


def areas(s):
    for item in AREAS:
        name, (x, z) = item[0], item[1]
        y = item[2] if len(item) > 2 else 0.0
        (ax, az), (bx, bz) = item[3] if len(item) > 3 else ((x + 2, z), (x - 2, z + 2))
        s.area(name, float(x), float(z), y=y, marks=[("stand", ax, az, 0), ("stand", bx, bz, 180)])


def build(s):
    stations(s)
    spots(s)
    spawns(s)
    areas(s)
