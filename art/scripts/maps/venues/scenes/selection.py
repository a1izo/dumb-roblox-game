"""Dead by selection (art/refs/deaths/selection.md): a dim board room after hours. Dark wood panelling to the dado,
grey plaster over it, a grey carpet; along the left a wall of tall windows behind half-closed blinds, the city's
cold glow through them; the long table and its chairs pushed back behind the victim; a ceiling of dark tiles with its
panels switched off. At the end the board on its stand (the scene draws the chart on its screen): a black bezel round
the screen, two steel legs on a wide foot. Lit by the board itself (the scene's light) and the windows.

Scene space: the victim near the origin facing -Z; the board's screen centred at (0, 5.5, -6), 12 x 7.5.
"""

from maps import kit
from maps.venues.scenes import parts
from maps.venues.scenes import plan as P

OX, OZ = P.SELECTION
X0, X1, Z0, Z1 = -14.0, 14.0, -12.0, 14.0
CEIL = 12.0
BOARD = (0.0, 5.5, -6.0)


def W(x, y, z):
    return (OX + x, y, OZ + z)


def build(s):
    s.box("CarpetGrey", W(0, -0.5, (Z0 + Z1) / 2), (X1 - X0, 1.0, Z1 - Z0))
    kit.ceiling(s, OX + X0, OZ + Z0, OX + X1, OZ + Z1, CEIL, "CeilingDark", beams=None)
    for z in (-6.0, 2.0, 10.0):
        for x in (-6.0, 6.0):
            s.box("DiffuserOff", W(x, CEIL - 0.05, z), (4.0, 0.1, 2.0))
    # the end wall behind the board and the back wall: panelled to the dado, plaster over it
    for z, sign in ((Z0, 1), (Z1, -1)):
        s.box("PlasterDark", W(0, CEIL / 2, z - sign * 0.5), (X1 - X0, CEIL, 1.0))
        s.box("WoodPanel", W(0, 2.0, z + sign * 0.06), (X1 - X0, 4.0, 0.12))
        s.box("Wood", W(0, 4.05, z + sign * 0.12), (X1 - X0, 0.18, 0.24))
        s.box("Wood", W(0, 0.25, z + sign * 0.1), (X1 - X0, 0.5, 0.2))
    s.box("PlasterDark", W(X1 + 0.5, CEIL / 2, (Z0 + Z1) / 2), (1.0, CEIL, Z1 - Z0))
    s.box("WoodPanel", W(X1 - 0.06, 2.0, (Z0 + Z1) / 2), (0.12, 4.0, Z1 - Z0))
    s.box("Wood", W(X1 - 0.12, 4.05, (Z0 + Z1) / 2), (0.24, 0.18, Z1 - Z0))
    # the window wall at the left (-X): tall windows between piers, blinds half down, the city's glow behind
    s.box("PlasterDark", W(X0 - 0.5, CEIL / 2, (Z0 + Z1) / 2), (1.0, CEIL, Z1 - Z0))
    for k in range(5):
        z = Z0 + 3.0 + k * 5.0
        s.box("WindowCool", W(X0 - 0.02, 6.0, z), (0.04, 8.0, 3.4))
        s.box("BlackTrim", W(X0 + 0.05, 6.0, z), (0.1, 8.2, 0.12))
        for j in range(22):
            y = 10.0 - j * 0.24
            s.box("BlindSlat", W(X0 + 0.18, y, z), (0.05, 0.05, 3.3), 0)
        s.box("BlackTrim", W(X0 + 0.12, 1.9, z), (0.3, 0.12, 3.6))
    # the long table pushed back behind the victim, its chairs; a credenza and a plant
    kit.table(s, OX, OZ + 8.5, 14.0, 4.0, top="Wood", legs="BlackMetal", h=2.75, collide=False)
    for x in (-5.0, -1.7, 1.7, 5.0):
        s.prop("OfficeChair", OX + x, OZ + 6.0, 180)
        s.prop("OfficeChair", OX + x, OZ + 11.2, 0)
    s.box("Wood", W(X1 - 1.2, 1.5, 0.0), (1.8, 3.0, 6.0))
    s.prop("OfficeFicus", OX + X1 - 1.6, OZ - 9.0, 0)
    s.prop("WaterCooler", OX + X0 + 1.6, OZ + 12.0, 180)
    # the board's stand: a black bezel round the scene's screen, two steel legs on a wide foot
    bx, by, bz = BOARD
    s.box("BlackTrim", W(bx, by, bz - 0.28), (12.8, 8.3, 0.25))
    for dx in (-4.0, 4.0):
        s.box("Steel", W(bx + dx, 0.85, bz - 0.3), (0.35, 1.7, 0.35))
        s.box("Steel", W(bx + dx, 0.06, bz - 0.3), (0.5, 0.12, 3.0))
    s.box("BlackMetal", W(bx, 1.6, bz - 0.3), (8.4, 0.3, 0.3))
