"""Diavolo's study: a room in an old house at night. Walnut panelling under dark damask, books floor to
ceiling on both side walls, a heavy desk with a banker's lamp, and behind it the tall window in the north
wall with the rain running down it and the city's lights beyond. Candles burn in the two corners by the
window, where the Muertos kneel."""

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
    window = {"at": 12.0, "w": 8.0, "bottom": 2.4, "top": 12.6, "kind": "window", "frame": "Wood",
              "mullions": "Wood", "cols": 2, "rows": 4, "sill": "Wood", "glass": "Glass"}
    door = {"at": 15.0, "w": 4.0, "bottom": 0.0, "top": 8.0, "kind": "door", "frame": "Wood"}
    runs = [((x0, z0), (x1, z0), [window]), ((x1, z0), (x1, z1), []), ((x1, z1), (x0, z1), [door]),
            ((x0, z1), (x0, z0), [])]
    for a, b, ops in runs:
        kit.wall(s, a, b, H, core="ConcreteDark", side_s="Damask", openings=ops, trim_s=TRIM)
    # Beyond the window: the rain on the glass, the city below in the dark.
    cx, cz = at(0.0, Z0)
    s.emitter("windowrain", (cx, 7.5, cz - 0.4), 0, (8.0, 10.0, 0.3))
    s.box("CityFacade", (cx, 10.0, cz - 70.0), (160.0, 60.0, 1.0))
    s.box("CityFacadeWarm", (cx - 30.0, 6.0, cz - 50.0), (24.0, 30.0, 1.0))
    s.box("CityFacade", (cx + 34.0, 4.0, cz - 45.0), (20.0, 26.0, 1.0))
    s.light("spot", (cx, 13.0, cz - 6.0), (150, 170, 220), 30, 1.2, shadows=True, face="Back", angle=50)
    # Books along both side walls, a reading chair, the sideboard by the door.
    for x, rot in ((X0 + 1.0, -90), (X1 - 1.0, 90)):
        for z in (-6.0, -1.2, 3.6):
            px, pz = at(x, z)
            s.prop("BookcaseTall", px, pz, rot)
    px, pz = at(-7.0, 6.0)
    s.prop("ClubChair", px, pz, 150)
    px, pz = at(7.5, 7.6)
    s.prop("Sideboard", px, pz, 180, 0.8)
    # The desk (no chair: Diavolo stands), the lamp and the papers; a low warm light on the open floor
    # in front of it, where the Muertos kneel.
    px, pz = at(0.0, -3.6)
    s.prop("ExecutiveDesk", px, pz, 180)
    px, pz = at(-2.2, -3.9)
    s.prop("BankerLamp", px, pz, 160, 1.0, 3.23)
    s.light("point", (px, 4.4, pz), (255, 214, 150), 14, 1.4, shadows=True)
    px, pz = at(0.4, -3.4)
    s.prop("PaperSheet", px, pz, 10, 1.0, 3.24)
    s.light("spot", (OX + 2.0, H - 1.0, OZ + 3.0), (255, 196, 140), 22, 0.9, shadows=True, angle=55)
    # Candles in the corners by the window, where the Muertos kneel; a brass sconce either side of the door.
    for x in (-8.5, 8.5):
        px, pz = at(x, -7.6)
        s.prop("CandleCluster", px, pz, 0)
        s.light("point", (px, 2.2, pz), CANDLE, 12, 0.9, flicker=True)
    for x in (-5.0, 5.0):
        kit.sconce(s, OX + x, 6.0, OZ + Z1 - 0.1, 0, range_=10, brightness=0.35)
    kit.wall_clock(s, OX + X1 - 0.3, 9.5, OZ - 7.0, 90, 0.8)
