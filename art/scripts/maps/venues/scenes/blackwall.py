"""Blackwall gateway (art/refs/deaths/blackwall.md): an underground car park seen through the hacker's eye. A drive
aisle runs away from the lens (+Z) between rows of square concrete pillars, each painted with a teal band and a big
white "1" (the level); bays either side with their white lines and wheel stops, cars parked nose in; at the right (-X)
a two-level car lift with the blue car up on its deck and a grey one under it. A low concrete soffit with deep beams
over each line of pillars, a big duct and the pipes down the aisle, fluorescent fittings; the back wall with its
roller shutter, an up-ramp at the far left, an exit door. Haze is the game's (Atmosphere).

Scene space: the victim at the origin facing the lens (-Z); the lens at (-1, 5.2, -9.5) looking +Z; the camera turns
to the right (-X, -Z) at the end, so the near right wall and the stair door are built too.
"""

from maps import kit
from maps.venues.scenes import models, parts
from maps.venues.scenes import plan as P

OX, OZ = P.BLACKWALL
X0, X1, Z0, Z1 = -34.0, 34.0, -30.0, 64.0
CEIL = 12.0
PILLAR_X = (-8.0, 8.0, -24.0, 24.0)
PILLAR_Z = (-10.0, 6.0, 22.0, 38.0, 54.0)
LIFT = (-12.0, 4.0)  # the lift's middle (the blue car on its deck)


def W(x, y, z):
    return (OX + x, y, OZ + z)


def one(s, cx, cy, cz, face, size=2.2):
    """A painted "1" on a pillar's face: `face` the face's outward direction along X or Z (+1/-1, axis)."""
    sign, axis = face
    off = 1.21 + 0.03  # (clear of the teal band's face, or the "1" z-fights it)

    def at(u, v):
        # u across the face (left to right seen from in front), v up
        if axis == "z":
            return W(cx + sign * u, cy + v, cz + sign * off)
        return W(cx + sign * off, cy + v, cz - sign * u)

    out = (0, 0, sign) if axis == "z" else (sign, 0, 0)
    k = size / 2.2
    for quad in (
        [(-0.25, -1.0), (0.25, -1.0), (0.25, 1.0), (-0.25, 1.0)],  # the stem
        [(-0.25, 0.62), (-0.25, 1.0), (-0.85, 0.55), (-0.85, 0.2)],  # the flag
        [(-0.7, -1.0), (0.7, -1.0), (0.7, -0.72), (-0.7, -0.72)],  # the foot
    ):
        parts.poly(s, "PaintWhite", [at(u * k, v * k) for u, v in quad], out)


def build(s):
    # the slab, the soffit, the walls
    s.box("ParkFloor", W(0, -0.5, (Z0 + Z1) / 2), (X1 - X0, 1.0, Z1 - Z0))
    s.box("ParkConcrete", W(0, CEIL + 0.5, (Z0 + Z1) / 2), (X1 - X0, 1.0, Z1 - Z0))
    for x in (X0 - 0.5, X1 + 0.5):
        s.box("ParkConcrete", W(x, CEIL / 2, (Z0 + Z1) / 2), (1.0, CEIL, Z1 - Z0))
    for z in (Z0 - 0.5, Z1 + 0.5):
        s.box("ParkConcrete", W(0, CEIL / 2, z), (X1 - X0 + 2, CEIL, 1.0))
    # a dark painted dado round the walls, a yellow kerb line on the floor along them
    for x, sx in ((X0 + 0.02, 1), (X1 - 0.02, -1)):
        s.box("BlackTrim", W(x, 1.0, (Z0 + Z1) / 2), (0.04, 2.0, Z1 - Z0))
        s.box("HazardYellow", W(x + sx * 0.6, 0.02, (Z0 + Z1) / 2), (0.3, 0.04, Z1 - Z0))
    s.box("BlackTrim", W(0, 1.0, Z1 - 0.02), (X1 - X0, 2.0, 0.04))
    # the beams over each line of pillars (across) and along the pillar rows
    for z in PILLAR_Z:
        s.box("ParkConcrete", W(0, CEIL - 0.8, z), (X1 - X0, 1.6, 1.6))
    for x in PILLAR_X:
        s.box("ParkConcrete", W(x, CEIL - 0.6, (Z0 + Z1) / 2), (1.4, 1.2, Z1 - Z0))
    # the pillars: board-marked concrete, a teal band with the white "1" facing the aisle, a black-and-yellow foot
    for x in PILLAR_X:
        for z in PILLAR_Z:
            s.box("ParkConcrete", W(x, CEIL / 2, z), (2.4, CEIL, 2.4))
            s.box("PaintTeal", W(x, 5.0, z), (2.42, 3.6, 2.42))
            for k in range(4):
                s.box("HazardYellow" if k % 2 == 0 else "HazardBlack", W(x, 0.2 + k * 0.4, z), (2.44, 0.4, 2.44))
            towards = -1 if x > 0 else 1
            one(s, x, 5.0, z, (towards, "x"))
            one(s, x, 5.0, z, (-1, "z"))
    # bay lines and wheel stops either side of the aisle; cars parked nose in
    for side in (-1, 1):
        for k in range(-1, 9):
            z = -10 + k * 8
            s.box("PaintWhite", W(side * 15.5, 0.012, z), (15.0, 0.024, 0.22))
        for k in range(0, 8):
            z = -6 + k * 8
            s.box("ConcreteDark", W(side * 21.5, 0.12, z), (0.5, 0.24, 2.8))
    s.box("PaintWhite", W(-7.2, 0.012, 17), (0.22, 0.024, 94))
    s.box("PaintWhite", W(7.2, 0.012, 17), (0.22, 0.024, 94))
    for k in range(6):  # (the aisle's arrows, pointing on)
        z = 10 + k * 12
        parts.poly(s, "PaintWhite", [W(-0.3, 0.014, z), W(0.3, 0.014, z), W(0.3, 0.014, z + 2.2),
                                     W(-0.3, 0.014, z + 2.2)], (0, 1, 0))
        parts.poly(s, "PaintWhite", [W(-0.9, 0.014, z + 2.2), W(0.9, 0.014, z + 2.2), W(0, 0.014, z + 3.4)], (0, 1, 0))
    for x, z, rot, paint in ((-18.0, 18.0, 90, "CarGrey"), (-18.0, 26.0, 90, "CarRed"), (-18.0, 42.0, 90, "CarGrey"),
                             (18.0, 18.0, -90, "CarGrey"), (18.0, 34.0, -90, "CarBlue"), (18.0, 50.0, -90, "CarRed"),
                             (18.0, -6.0, -90, "CarGrey")):
        models.car(s, OX + x, OZ + z, rot, paint)
    # the two-level lift at the right: four yellow posts, the deck with its ramps and rails, the blue car up on it
    lx, lz = LIFT
    for dx in (-2.9, 2.9):
        for dz in (-5.2, 5.2):
            s.box("HazardYellow", W(lx + dx, 4.6, lz + dz), (0.6, 9.2, 0.6))
            s.box("BlackMetal", W(lx + dx, 0.08, lz + dz), (1.1, 0.16, 1.1))
    for dz in (-5.2, 5.2):
        s.box("HazardYellow", W(lx, 9.0, lz + dz), (6.4, 0.5, 0.6))
    deck_y = 5.6
    s.box("MetalFloor", W(lx, deck_y, lz), (5.6, 0.25, 10.4))
    s.box("HazardYellow", W(lx - 2.75, deck_y + 0.3, lz), (0.15, 0.35, 10.4))
    s.box("HazardYellow", W(lx + 2.75, deck_y + 0.3, lz), (0.15, 0.35, 10.4))
    s.box("BlackMetal", W(lx, deck_y - 0.4, lz), (5.0, 0.5, 0.5))
    for dz in (-4.0, 4.0):
        s.tube("Steel", W(lx - 2.9, 7.4, lz + dz * 1.3), W(lx + 2.9, 7.4, lz + dz * 1.3), 0.08, 6)
    models.car(s, OX + lx, OZ + lz, 0, "CarBlue", y=deck_y + 0.125)
    models.car(s, OX + lx, OZ + lz, 0, "CarGrey")
    # the duct and pipes down the aisle; the sprinkler main in red
    s.box("Steel", W(-3.5, CEIL - 1.6, (Z0 + Z1) / 2), (2.6, 1.6, Z1 - Z0))
    for z in range(int(Z0) + 4, int(Z1), 10):
        s.box("BlackMetal", W(-3.5, CEIL - 0.6, z), (3.0, 0.2, 0.2))
    for x, mat, r in ((3.0, "PaintSteel", 0.3), (3.8, "PaintSteel", 0.2), (-14.0, "RedTrim", 0.18)):
        s.tube(mat, W(x, CEIL - 0.6, Z0), W(x, CEIL - 0.6, Z1), r, 8)
    # the fluorescent fittings: down the aisle and over each row of bays
    for z in (-2.0, 14.0, 30.0, 46.0):
        kit.tube_light(s, OX + 0.0, CEIL - 0.0, OZ + z, length=5.0, rot=90, color=(232, 236, 214), range_=22,
                       brightness=0.9)
        for x in (-16.0, 16.0):
            kit.tube_light(s, OX + x, CEIL - 0.0, OZ + z, length=5.0, rot=90, color=(232, 236, 214), range_=18,
                           brightness=0.6)
    # the back wall: a roller shutter, the exit door and sign; the up-ramp at the far left
    s.box("Shutter", W(-4.0, 4.5, Z1 - 0.15), (14.0, 9.0, 0.3))
    s.box("BlackMetal", W(-4.0, 9.2, Z1 - 0.3), (14.6, 0.6, 0.6))
    s.box("PaintSteel", W(-24.0, 3.5, Z1 - 0.12), (3.2, 7.0, 0.24))
    kit.exit_sign(s, OX - 24.0, 8.0, OZ + Z1 - 0.05, 180)
    s.box("ParkConcrete", W(26.0, 2.0, 50.0), (12.0, 0.6, 26.0), 0)
    for k in range(8):
        y = k * 0.75
        s.box("ParkFloor", W(26.0, y / 2, 44 + k * 2.2), (12.0, y + 0.2, 2.2))
    s.box("ParkConcrete", W(19.6, 2.5, 52.0), (0.8, 5.0, 24.0))
    # the near right wall (the camera's turn at the end): the stair core's steel door, its sign, an extinguisher
    s.box("PaintSteel", W(X0 + 0.12, 3.5, -12.0), (0.24, 7.0, 3.4))
    s.box("BlackMetal", W(X0 + 0.15, 7.2, -12.0), (0.3, 0.4, 3.8))
    kit.exit_sign(s, OX + X0 + 0.05, 8.0, OZ - 12.0, -90)
    kit.extinguisher(s, OX + X0 + 0.05, OZ - 4.0, -90)
    # oil stains in the bays
    for x, z in ((-17.5, -6.5), (17.0, 9.5), (-16.5, 33.5), (-11.6, 3.0)):
        parts.poly(s, "Puddle", [W(x - 1.2, 0.02, z - 0.7), W(x + 1.0, 0.02, z - 0.9), W(x + 1.3, 0.02, z + 0.6),
                                 W(x - 0.9, 0.02, z + 0.9)], (0, 1, 0))
