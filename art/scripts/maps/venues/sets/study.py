"""Diavolo's study: a room in an old house at night. Walnut panelling under dark damask, books floor to
ceiling on both side walls; in the north wall the tall window with the rain running down it and the city's
lights beyond, and before it a heavy desk with a banker's lamp, the chair behind it. Across the room an old
television on its legs, facing the desk. Candles burn in the two corners by the window."""

from maps import kit
from maps.venues.sets import plan as P

OX, OZ = P.STUDY
X0, X1, Z0, Z1, H = -12.0, 12.0, -10.0, 10.0, 14.0
TRIM = {"base": "BlackTrim", "wainscot": ("WoodPanel", 4.6), "rail": "Brass", "crown": "Wood"}
CANDLE = (255, 170, 90)


def at(x, z):
    return OX + x, OZ + z


def build(s):
    x0, z0 = at(X0, Z0)
    x1, z1 = at(X1, Z1)
    kit.floor(s, x0, z0, x1, z1, "WoodFloorDark", border=("Parquet", 1.6))
    kit.ceiling(s, x0, z0, x1, z1, H, "WoodPanel", beams=6.0, beam_mat="Wood")
    # The window starts above the panelling (4.6 high) and stops under the crown.
    window = {"at": 12.0, "w": 6.0, "bottom": 5.4, "top": 12.4, "kind": "window", "frame": "Wood",
              "mullions": "Wood", "cols": 2, "rows": 3, "sill": "Wood", "glass": "Glass"}
    door = {"at": 15.0, "w": 4.0, "bottom": 0.0, "top": 8.0, "kind": "door", "frame": "Wood"}
    runs = [((x0, z0), (x1, z0), [window]), ((x1, z0), (x1, z1), []), ((x1, z1), (x0, z1), [door]),
            ((x0, z1), (x0, z0), [])]
    for a, b, ops in runs:
        kit.wall(s, a, b, H, core="ConcreteDark", side_s="Damask", openings=ops, trim_s=TRIM)
    # Beyond the window: the rain on the glass, the city below in the dark.
    cx, cz = at(0.0, Z0)
    s.emitter("windowrain", (cx, 8.9, cz - 0.4), 0, (6.0, 7.0, 0.3))
    s.box("CityFacade", (cx, 10.0, cz - 70.0), (160.0, 60.0, 1.0))
    s.box("CityFacadeWarm", (cx - 30.0, 6.0, cz - 50.0), (24.0, 30.0, 1.0))
    s.box("CityFacade", (cx + 34.0, 4.0, cz - 45.0), (20.0, 26.0, 1.0))
    s.light("spot", (cx, 13.0, cz - 6.0), (150, 170, 220), 30, 1.2, shadows=True, face="Back", angle=50)
    # Books along both side walls, a reading chair, the sideboard by the door.
    for x, rot in ((X0 + 1.5, -90), (X1 - 1.5, 90)):  # backs to the walls (1.9 deep)
        for z in (-6.0, -1.2, 3.6):
            px, pz = at(x, z)
            s.prop("BookcaseTall", px, pz, rot)
    px, pz = at(-7.0, 6.0)
    s.prop("ClubChair", px, pz, 150)
    px, pz = at(7.6, 8.5)
    s.prop("Sideboard", px, pz, 180, 0.7)  # against the south wall, east of the door
    # The desk in front of the window, its chair behind (Diavolo writes with the rain at his back); the desk
    # carries its own banker's lamp (west end), pen stand, nameplate and dossier, and the point light is its
    # lamp's. Across the room, facing him, an old television on its legs, the news on.
    px, pz = at(0.0, -5.4)
    s.prop("ExecutiveDesk", px, pz, 180)
    px, pz = at(0.0, -8.0)
    s.prop("OfficeChair", px, pz, 180)
    s.light("point", (OX - 2.3, 3.55, OZ - 5.75), (255, 214, 150), 20, 2.6, shadows=True)  # under the shade
    px, pz = at(1.0, 6.6)  # (a stud east of the doorway, x -5..-1: in front of it, it narrowed the way out)
    s.prop("CRTTelevision", px, pz, 0)
    s.screen((OX + 1.3, 1.75, OZ + 5.43), 0, 1.9, 1.5, "news")
    s.light("spot", (OX, H - 1.0, OZ + 0.5), (255, 196, 140), 26, 0.8, shadows=True, angle=70)  # a little fill
    # Candles in the corners by the window; a brass sconce either side of the door.
    for x in (-8.5, 8.5):
        px, pz = at(x, -8.4)
        s.prop("CandleCluster", px, pz, 0)
        s.light("point", (px, 2.2, pz), CANDLE, 12, 0.9, flicker=True)
    for x in (-5.0, 5.0):
        kit.sconce(s, OX + x, 6.0, OZ + Z1 - 0.1, 0, range_=10, brightness=0.35)
    kit.wall_clock(s, OX + X1 - 0.3, 9.5, OZ - 7.0, 90, 0.8)
