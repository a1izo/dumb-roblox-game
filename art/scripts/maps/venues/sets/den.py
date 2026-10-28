"""The detective's den of Case Closed told for the Coven (src/shared/Cinema/WinCuts.luau caseClosedCoven; the user,
2026-10-27: every shop win cutscene for both Ace and the Coven): the detective's own study at night, turned over. Dark
panelling under green damask, a stone fireplace in the north wall with a fire burning low, the red-string wall beside
it (the cutscene's board), and everything searched: drawers hanging out of the cabinet, books swept off the shelves,
papers across the floor, the desk lamp the only other light. Rain on the window in the east wall. The star sits in
the detective's armchair at the room's origin (plan.DEN), facing the fire."""

import random

from maps import kit
from maps.venues.sets import plan as P

OX, OZ = P.DEN
X0, X1, Z0, Z1, H = -9.0, 9.0, -8.5, 8.0, 11.0
TRIM = {"base": "BlackTrim", "wainscot": ("WoodPanel", 3.8), "rail": "Wood", "crown": "Wood"}
MOON = (150, 172, 222)
LAMP = (255, 206, 140)
FIRE = (0.0, -7.25)  # the firebox's middle (the cutscene's fire burns there)


def fireplace(s):
    """A stone fireplace: the chimney breast standing out of the north wall, its opening, the hearth, the mantel and
    the painting over it; the grate and its logs inside."""
    fx, fz = OX + FIRE[0], OZ + Z0 + 0.5  # (the wall's inner face)
    s.box("Stone", (fx - 2.35, 1.6, fz + 0.75), (1.3, 3.2, 1.5))  # the jambs
    s.box("Stone", (fx + 2.35, 1.6, fz + 0.75), (1.3, 3.2, 1.5))
    s.box("Stone", (fx, 3.6, fz + 0.75), (6.0, 0.8, 1.5))  # the lintel
    s.box("Stone", (fx, 7.6, fz + 0.55), (5.0, 7.2, 1.1))  # the breast up to the ceiling
    s.box("BlackMetal", (fx, 1.6, fz + 0.06), (3.4, 3.2, 0.1))  # the soot-black back
    s.box("Wood", (fx, 4.15, fz + 0.95), (6.6, 0.3, 1.9))  # the mantel shelf
    s.box("MarbleBlack", (fx, 0.06, fz + 2.1), (6.4, 0.12, 2.2))  # the hearth
    s.box("Ash", (fx, 0.08, fz + 0.75), (3.3, 0.06, 1.4))
    for dx in (-1.1, 1.1):  # the grate's legs and bars, three logs across it
        s.box("BlackMetal", (fx + dx, 0.4, fz + 0.8), (0.12, 0.8, 1.2))
    for dz in (0.4, 0.8, 1.2):
        s.tube("BlackMetal", (fx - 1.2, 0.7, fz + dz), (fx + 1.2, 0.7, fz + dz), 0.05, 4)
    for (ax, ay, az), (bx, by, bz) in (((-1.0, 0.9, 0.7), (0.9, 1.0, 0.9)), ((-0.7, 1.15, 1.1), (1.1, 0.95, 0.6)),
                                       ((-0.2, 1.3, 0.8), (0.6, 1.45, 1.0))):
        s.tube("Bark", (fx + ax, ay, fz + az), (fx + bx, by, fz + bz), 0.2, 8)
    # (over the mantel a painting, a candlestick either end; the clock between them)
    kit.picture(s, fx, 7.0, fz + 1.1, 180, w=3.6, h=2.6, frame="Gold", inner="Photo")
    for dx in (-2.8, 2.8):
        s.cylinder("Brass", (fx + dx, 4.3, fz + 1.0), 0.18, 0.1, 10)
        s.cylinder("CreamTrim", (fx + dx, 4.4, fz + 1.0), 0.08, 0.7, 8)


def build(s):
    rng = random.Random(23)
    x0, z0, x1, z1 = OX + X0, OZ + Z0, OX + X1, OZ + Z1
    kit.floor(s, x0, z0, x1, z1, "Parquet")
    kit.ceiling(s, x0, z0, x1, z1, H, "CeilingPlasterDark")
    s.box("CarpetRed", (OX, 0.04, OZ - 2.0), (8.0, 0.08, 7.0))  # the rug between the chair and the fire
    window = {"at": 8.0, "w": 4.0, "bottom": 3.2, "top": 8.8, "kind": "window", "frame": "Wood", "mullions": "Wood",
              "cols": 2, "rows": 3, "sill": "Wood", "glass": "WindowGlass"}
    door = {"at": 13.0, "w": 3.4, "bottom": 0.0, "top": 7.4, "kind": "door", "frame": "Wood"}
    runs = [((x0, z0), (x1, z0), []), ((x1, z0), (x1, z1), [window]), ((x1, z1), (x0, z1), [door]),
            ((x0, z1), (x0, z0), [])]
    for a, b, ops in runs:
        kit.wall(s, a, b, H, core="ConcreteDark", side_s="Damask", openings=ops, trim_s=TRIM)
    s.box("Wood", (OX - 4.0, 3.7, z1 - 0.1), (3.3, 7.4, 0.2))  # the door, shut
    s.box("Brass", (OX - 2.7, 3.5, z1 - 0.3), (0.16, 0.16, 0.2))
    fireplace(s)
    # The moon through the rain on the window; the city's glow below it.
    s.light("spot", (x1 + 9.0, 9.0, OZ - 0.0), MOON, 24, 1.1, shadows=True, face="Left", angle=40)
    s.box("CityFacade", (x1 + 18.0, 2.0, OZ + 2.0), (1.0, 30.0, 18.0))
    # The searched room: the cabinet's drawers pulled and hanging, its papers over the floor; the bookcase stripped,
    # its books on the floor below it; the desk by the west wall, its lamp on, its chair kicked back.
    s.prop("FilingCabinet", OX + 6.4, OZ + Z0 + 1.65, 0)
    for k, y in enumerate((3.9, 2.5, 1.1)):
        out = (1.6, 0.9, 0.0)[k]
        if out:
            s.box("PaintSteel", (OX + 6.4, y, OZ + Z0 + 2.65 + out / 2), (2.1, 1.1, out))
    s.prop("BookcaseTall", OX + X1 - 1.0, OZ + 4.6, -90)
    for k in range(16):
        x = OX + X1 - 2.2 - rng.uniform(0, 2.6)
        z = OZ + 4.6 + rng.uniform(-2.6, 2.6)
        mat = rng.choice(("Leather", "FabricRed", "CarpetNavy", "CarpetGreen", "Wood"))
        s.box(mat, (x, 0.12 + 0.12 * (k % 3), z), (rng.uniform(0.9, 1.4), 0.22, rng.uniform(0.6, 0.9)),
              rng.uniform(0, 180))
    for k in range(34):
        x = OX + rng.uniform(X0 + 1.0, X1 - 1.0)
        z = OZ + rng.uniform(Z0 + 2.6, Z1 - 1.0)
        if abs(x - OX) < 1.9 and abs(z - OZ) < 2.0:
            continue  # (not under the armchair)
        s.box("Paper", (x, 0.1 + 0.005 * (k % 4), z), (0.85, 0.01, 1.1), rng.uniform(0, 180))
    s.prop("Desk", OX - 6.6, OZ + 1.2, 90)
    s.prop("BankerLamp", OX - 6.6, OZ + 2.6, 90, 1.0, 4.58)
    s.light("point", (OX - 6.6, 5.7, OZ + 2.6), LAMP, 12, 0.7, shadows=True)
    for k in range(6):
        s.box("Paper", (OX - 6.6 + rng.uniform(-0.6, 0.6), 4.6, OZ + 0.4 + rng.uniform(-1.2, 1.2)), (0.85, 0.01, 1.1),
              rng.uniform(0, 180))
    s.prop("OfficeChair", OX - 4.2, OZ + 3.8, 60)
    s.prop("FloorGlobe", OX - 7.0, OZ - 5.6, 30)
    kit.wall_clock(s, OX + 6.0, 9.0, z0 + 0.5, 180, 0.6)
