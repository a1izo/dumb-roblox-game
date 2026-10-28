"""The rooftop of Checkmate told for the Coven (src/shared/Cinema/WinCuts.luau checkmateCoven; the user, 2026-10-27:
every shop win cutscene for both Ace and the Coven): the roof of an old hotel in the rain at night, over a neon street.
A low brick parapet with stone coping at the front, the deck running with water, a crate by the edge (the cutscene's,
with the chessboard on it), a chimney stack, a skylight, a tangle of old aerials, and the hotel's tall red sign
standing up off the corner, lighting everything red; eighty studs down, the street's signs and cars. The star's mark
is the roof's origin (plan.ROOFRAIN), looking over the edge (-z)."""

from maps import kit
from maps.venues.sets import plan as P

OX, OZ = P.ROOFRAIN
X0, X1, Z0, Z1 = -14.0, 14.0, -4.2, 14.0
DROP = 80.0  # the street, below the roof
PARAPET = 1.3
RED = (255, 52, 66)
STREET = -DROP


def build(s):
    x0, z0, x1, z1 = OX + X0, OZ + Z0, OX + X1, OZ + Z1
    kit.floor(s, x0, z0, x1, z1, "AsphaltWet")
    for x, z, rx, rz in ((-2.0, 1.4, 2.2, 1.3), (4.5, 4.0, 1.6, 1.1), (-8.0, 8.0, 2.4, 1.5), (7.0, 10.5, 1.8, 1.2)):
        kit.puddle(s, OX + x, OZ + z, rx, rz)
    # The parapet: brick, stone coping; the hotel's face dropping to the street under it, rows of windows.
    edges = [((x0, z0), (x1, z0)), ((x1, z0), (x1, z1)), ((x1, z1), (x0, z1)), ((x0, z1), (x0, z0))]
    for a, b in edges:
        kit.wall(s, a, b, PARAPET, thick=0.7, core="BrickDark", side_s="BrickDark", side_n="BrickDark")
    for (ax, az), (bx, bz) in edges:
        s.box("Stone", ((ax + bx) / 2, PARAPET + 0.1, (az + bz) / 2), (abs(bx - ax) + 0.9, 0.2, abs(bz - az) + 0.9))
    s.box("BrickDark", (OX, -DROP / 2, z0 - 0.45), (x1 - x0 + 0.9, DROP, 0.9))
    for floor in range(17):
        y = -5.0 - floor * 4.4
        for k in range(6):
            lit = (floor * 5 + k * 3) % 7 == 0
            s.box("DimWarm" if lit else "WindowDark", (OX - 11.5 + k * 4.6, y, z0 - 0.95), (1.6, 2.4, 0.1))
    # The hotel's sign: a tall frame standing up off the north-east corner, red tubes up its face; its light.
    sx, sz = x1 - 1.0, z0 - 1.6
    s.box("BlackMetal", (sx, -4.0, sz), (1.6, 22.0, 0.8))
    for k in range(7):
        s.box("NeonRed", (sx, -12.0 + k * 2.6, sz - 0.42), (1.1, 1.6, 0.06))
    s.box("NeonRed", (sx - 0.62, -4.0, sz - 0.42), (0.1, 21.0, 0.06))
    s.box("NeonRed", (sx + 0.62, -4.0, sz - 0.42), (0.1, 21.0, 0.06))
    s.light("point", (sx - 1.0, 4.0, sz + 1.0), RED, 26, 1.3, shadows=True)
    for y in (-9.0, 0.0):
        s.tube("BlackMetal", (sx, y, sz + 0.4), (sx, y, z0 + 0.2), 0.08, 6)
    # On the deck: the chimney stack with its pots, the skylight, the aerials and their wires, a pipe along the back.
    s.box("BrickDark", (OX - 8.5, 2.6, OZ + 4.0), (2.4, 5.2, 1.6))
    s.box("Stone", (OX - 8.5, 5.3, OZ + 4.0), (2.7, 0.25, 1.9))
    for dx in (-0.6, 0.6):
        s.cylinder("BrickRed", (OX - 8.5 + dx, 5.4, OZ + 4.0), 0.32, 0.9, 10)
    s.box("BlackMetal", (OX + 5.5, 0.5, OZ + 6.0), (4.2, 1.0, 3.0))
    s.box("GlassDark", (OX + 5.5, 1.08, OZ + 6.0), (3.8, 0.08, 2.6))
    for k, (x, z, h) in enumerate(((-3.5, 9.5, 7.0), (2.0, 11.5, 9.0), (9.5, 2.0, 6.0))):
        s.tube("DarkMetal", (OX + x, 0.0, OZ + z), (OX + x, h, OZ + z), 0.06, 5)
        for j in range(3):
            y = h - 0.6 - j * 0.9
            w = 1.6 - j * 0.35
            s.tube("DarkMetal", (OX + x - w, y, OZ + z), (OX + x + w, y, OZ + z), 0.03, 4)
        s.tube("BlackMetal", (OX + x, h * 0.7, OZ + z), (OX + x + 2.5, 0.05, OZ + z - 3.0), 0.012, 3)
    s.tube("PaintSteel", (x0 + 1.0, 0.5, z1 - 1.0), (x1 - 1.0, 0.5, z1 - 1.0), 0.2, 8)
    # The street: wet road and pavements, the far side's shopfronts and their signs, two cars' lights.
    kit.floor(s, OX - 60.0, OZ - 34.0, OX + 60.0, z0 - 1.0, "AsphaltWet", y=STREET)
    s.box("PaversWet", (OX, STREET + 0.1, z0 - 4.0), (120.0, 0.2, 6.0))
    s.box("PaversWet", (OX, STREET + 0.1, OZ - 31.0), (120.0, 0.2, 6.0))
    s.box("BrickDark", (OX, STREET + 25.0, OZ - 37.0), (120.0, 50.0, 6.0))
    for k, (x, mat) in enumerate(((-28.0, "NeonPink"), (-12.0, "NeonCyan"), (6.0, "NeonOrange"), (22.0, "NeonPink"),
                                  (36.0, "NeonCyan"))):
        s.box("WindowLit", (OX + x, STREET + 2.4, OZ - 33.9), (8.0, 4.0, 0.1))
        s.box(mat, (OX + x, STREET + 6.0 + (k % 2) * 1.6, OZ - 33.8), (6.0, 1.2, 0.12))
    for row in range(8):
        for k in range(-12, 13):
            if (row * 3 + k) % 4 == 0:
                s.box("DimWindow", (OX + k * 4.6, STREET + 11.0 + row * 4.6, OZ - 33.9), (1.6, 2.4, 0.1))
    for x, z in ((-20.0, -14.0), (16.0, -20.0)):
        s.box("BlackMetal", (OX + x, STREET + 0.9, OZ + z), (8.0, 1.6, 3.6))
        for dz in (-1.2, 1.2):
            s.box("NeonWarm", (OX + x - 4.05, STREET + 0.9, OZ + z + dz), (0.1, 0.4, 0.6))
            s.box("NeonRed", (OX + x + 4.05, STREET + 0.9, OZ + z + dz), (0.1, 0.4, 0.6))
