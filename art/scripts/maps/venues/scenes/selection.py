"""Dead by selection (art/refs/deaths/selection.md), redone 2026-11-10 (the user: "make the character look at the
phone ... then up to the starry night sky in contempt with dramatic camera shots"): a ROOFTOP at night over a city,
under the Milky Way (SkySceneNight). The roof of a six-storey block: felt, a walkway of slabs from the stair room's
steel door (a caged lamp over it: the warm light at the victim's back) to the parapet where the victim stands; a low
parapet all round under a pale coping; a water tank on its stand, two air-handling units on pads, vent stacks, a
pipe run, an antenna mast with a red lamp. Round it the city in its night facades (maps/skyline.py): lower blocks
across the street, taller ones behind them, towers far off.

Scene space: the victim at the origin facing -Z (the parapet 4 studs ahead, the city beyond); the roof's top at y 0.
"""

import random

from maps import buildings, skyline
from maps.venues.scenes import plan as P

OX, OZ = P.SELECTION
X0, X1, Z0, Z1 = -17.0, 17.0, -4.0, 24.0
GY = -76.0  # the street
STYLES = ("NightOffice", "NightTile", "NightFlats", "NightBrick")


def W(x, y, z):
    return (OX + x, y, OZ + z)


def floors_to(top):
    """How many floors reach about `top` from the street."""
    return max(2, round((top - GY - buildings.FLOOR_GF) / buildings.FLOOR_UP) + 1)


def lot(cx, cz, w, d):
    return [(OX + cx - w / 2, OZ + cz - d / 2), (OX + cx + w / 2, OZ + cz - d / 2), (OX + cx + w / 2, OZ + cz + d / 2),
            (OX + cx - w / 2, OZ + cz + d / 2)]


def roof(s):
    mid = (Z0 + Z1) / 2
    s.box("Asphalt", W(0, -0.5, mid), (X1 - X0 + 2.0, 1.0, Z1 - Z0 + 2.0))
    # the block under it, down to the street
    s.box("ConcreteDark", W(0, (GY - 1.0) / 2, mid), (X1 - X0 + 2.0, -1.0 - GY, Z1 - Z0 + 2.0), skip=("+y", "-y"))
    # the walkway: slabs from the stair door to the parapet
    for k in range(9):
        s.box("ParkConcrete", W(0.0, 0.04, 14.6 - k * 2.05), (3.0, 0.08, 1.95))
    # the parapet and its coping
    for cx, cz, sx, sz in ((0, Z0 - 0.5, X1 - X0 + 2.0, 1.0), (0, Z1 + 0.5, X1 - X0 + 2.0, 1.0),
                           (X0 - 0.5, mid, 1.0, Z1 - Z0), (X1 + 0.5, mid, 1.0, Z1 - Z0)):
        s.box("ConcreteDark", W(cx, 1.3, cz), (sx, 2.6, sz))
        s.box("ParkConcrete", W(cx, 2.72, cz), (sx + 0.3, 0.24, sz + 0.3))
    # a gutter channel along the front parapet, a drain grate in it
    s.box("ConcreteDark", W(0, 0.06, Z0 + 0.5), (X1 - X0, 0.12, 0.9))
    s.box("BlackMetal", W(-6.0, 0.13, Z0 + 0.5), (1.2, 0.04, 0.7))


def stair_room(s):
    """The stair room behind the victim: a steel door facing the walkway, a caged lamp over it."""
    s.box("ConcreteDark", W(0, 4.25, 20.0), (9.0, 8.5, 8.0))
    s.box("ParkConcrete", W(0, 8.65, 20.0), (9.6, 0.3, 8.6))
    s.box("BlackTrim", W(0, 3.45, 15.94), (3.8, 6.9, 0.14))
    s.box("PaintSteel", W(0, 3.35, 15.88), (3.3, 6.6, 0.14))
    s.box("Steel", W(1.2, 3.3, 15.78), (0.14, 0.6, 0.1))  # the handle
    s.box("BlackMetal", W(0, 0.1, 15.3), (3.6, 0.2, 1.4))  # the step
    # the lamp: a bracket, a glowing glass in a cage
    s.box("BlackMetal", W(0, 7.55, 15.8), (0.5, 0.2, 0.5))
    s.box("NeonWarm", W(0, 7.3, 15.7), (0.7, 0.36, 0.4))
    for dx in (-0.36, 0.0, 0.36):
        s.box("BlackMetal", W(dx, 7.3, 15.48), (0.04, 0.44, 0.04))
    # a cable tray up the wall and a junction box
    s.box("DarkMetal", W(3.4, 4.0, 15.9), (0.3, 8.0, 0.16))
    s.box("DarkMetal", W(3.4, 2.4, 15.82), (0.8, 1.0, 0.3))


def plant(s):
    """What stands on the roof: the water tank, two air-handling units, vent stacks, a pipe run, the mast."""
    # the water tank at the front left, on a stand of four legs with cross braces, a ladder up it
    tx, tz = -11.0, 3.0
    for dx in (-1.7, 1.7):
        for dz in (-1.7, 1.7):
            s.tube("BlackMetal", W(tx + dx, 0, tz + dz), W(tx + dx, 4.4, tz + dz), 0.14)
    for dx in (-1.7, 1.7):
        s.tube("BlackMetal", W(tx + dx, 0.4, tz - 1.7), W(tx + dx, 4.0, tz + 1.7), 0.07)
    for dz in (-1.7, 1.7):
        s.tube("BlackMetal", W(tx - 1.7, 4.0, tz + dz), W(tx + 1.7, 0.4, tz + dz), 0.07)
    s.box("BlackMetal", W(tx, 4.5, tz), (4.4, 0.2, 4.4))
    s.cylinder("DarkMetal", W(tx, 4.6, tz), 2.5, 5.2, segments=20)
    for band in (5.4, 7.2, 9.0):
        s.cylinder("BlackMetal", W(tx, band, tz), 2.56, 0.16, segments=20, caps=(False, False))
    s.cylinder("BlackMetal", W(tx, 9.8, tz), 2.7, 1.5, segments=20, radius_top=0.25)
    for side in (-0.3, 0.3):
        s.tube("Steel", W(tx + 2.75, 0.0, tz + side), W(tx + 2.75, 9.6, tz + side), 0.05)
    for k in range(12):
        s.tube("Steel", W(tx + 2.75, 0.7 + k * 0.76, tz - 0.3), W(tx + 2.75, 0.7 + k * 0.76, tz + 0.3), 0.04)
    # the air-handling units at the back left, on pads: a louvred side, a fan grille on top
    for uz in (11.5, 17.5):
        ux = -11.0
        s.box("ConcreteDark", W(ux, 0.15, uz), (5.4, 0.3, 4.0))
        s.box("PaintSteel", W(ux, 1.95, uz), (4.8, 3.3, 3.4))
        for k in range(7):
            s.box("DarkMetal", W(ux + 2.42, 0.9 + k * 0.34, uz), (0.06, 0.12, 2.8))
        s.cylinder("BlackMetal", W(ux, 3.6, uz), 1.25, 0.14, segments=18)
        s.cylinder("DarkMetal", W(ux, 3.6, uz), 0.3, 0.22, segments=10)
    # a pipe run from the units along the left parapet, on low stands
    for off, r in ((0.0, 0.2), (0.55, 0.13)):
        s.tube("DarkMetal", W(X0 + 1.2 + off, 0.7, 20.0), W(X0 + 1.2 + off, 0.7, 7.0), r)
        s.tube("DarkMetal", W(X0 + 1.2 + off, 0.7, 7.0), W(X0 + 1.2 + off, 0.0, 6.4), r)
    for z in (9.0, 13.0, 17.0):
        s.box("BlackMetal", W(X0 + 1.5, 0.25, z), (1.3, 0.5, 0.2))
    # vent stacks at the right, each under a cap
    for vx, vz, h in ((10.0, 6.0, 2.8), (11.8, 7.4, 2.2), (9.4, 8.2, 1.6)):
        s.cylinder("DarkMetal", W(vx, 0, vz), 0.42, h, segments=12)
        s.cylinder("BlackMetal", W(vx, h + 0.12, vz), 0.72, 0.2, segments=12, radius_top=0.2)
    # a roof hatch at the right back
    s.box("DarkMetal", W(11.5, 0.45, 18.0), (3.2, 0.9, 3.2))
    s.box("PaintSteel", W(11.5, 0.95, 18.0), (3.4, 0.12, 3.4))
    # the mast at the front right: a lattice of three legs, cross arms, a red lamp on top, two guy wires
    mx, mz = 12.5, -0.5
    for dx, dz in ((0.0, 0.35), (-0.3, -0.18), (0.3, -0.18)):
        s.tube("Steel", W(mx + dx, 0.0, mz + dz), W(mx + dx * 0.25, 24.0, mz + dz * 0.25), 0.07)
    for k in range(8):
        y = 1.5 + k * 2.8
        f = 1.0 - 0.75 * y / 24.0
        s.tube("Steel", W(mx - 0.3 * f, y, mz - 0.18 * f), W(mx + 0.3 * f, y, mz - 0.18 * f), 0.035)
        s.tube("Steel", W(mx + 0.3 * f, y, mz - 0.18 * f), W(mx, y + 1.4, mz + 0.35 * f), 0.035)
        s.tube("Steel", W(mx, y, mz + 0.35 * f), W(mx - 0.3 * f, y + 1.4, mz - 0.18 * f), 0.035)
    for y, half in ((18.0, 1.6), (21.0, 1.1)):
        s.tube("Steel", W(mx - half, y, mz), W(mx + half, y, mz), 0.05)
        for k in range(5):
            x = mx - half + 2 * half * k / 4
            s.tube("Steel", W(x, y - 0.35, mz), W(x, y + 0.35, mz), 0.03)
    s.box("NeonRed", W(mx, 24.2, mz), (0.32, 0.32, 0.32))
    s.tube("BlackMetal", W(mx, 16.0, mz), W(X1 - 0.5, 2.9, 6.0), 0.025)
    s.tube("BlackMetal", W(mx, 16.0, mz), W(4.0, 0.1, Z0 + 0.4), 0.025)


def city(s):
    """The city round the roof, in its night facades: nearer blocks lower than the roof or about it (the far ones show
    over them), taller ones behind, towers far off; lit windows on all of them."""
    rng = random.Random(1110)
    s.box("CityGround", W(0, GY - 0.5, 0), (860.0, 1.0, 860.0), skip=("-y", "+x", "-x", "+z", "-z"))

    def put(cx, cz, w, d, top, lit, detail, most, styles=STYLES):
        skyline.block(s, lot(cx, cz, w, d), floors_to(top), random.Random(rng.random()), y=GY, lit=lit,
                      styles=styles, detail=detail, roof_mat="CityRoof", most=most)

    # (the near ones stand BELOW the roof: the sky is what this scene is about, and a wall of facades hid it; and no
    # office ribbons near, whose lit floors are slabs of white at this distance)
    near = ("NightTile", "NightFlats", "NightBrick")
    # across the street in front (toward -Z), and the rows behind it, each standing higher than the one before
    for cz, depth, tops, lit, detail, most, styles in ((-46.0, 34.0, (-52.0, -14.0), 0.3, 2, 50, near),
                                                       (-104.0, 40.0, (-34.0, 4.0), 0.3, 1, 44, near),
                                                       (-170.0, 44.0, (-16.0, 30.0), 0.28, 0, 40, STYLES),
                                                       (-250.0, 50.0, (0.0, 70.0), 0.26, 0, 36, STYLES),
                                                       (-340.0, 56.0, (10.0, 120.0), 0.24, 0, 32, STYLES)):
        x = -330.0 + rng.uniform(0, 20)
        while x < 330.0:
            w = rng.uniform(30.0, 52.0)
            put(x + w / 2, cz + rng.uniform(-6, 6), w, depth * rng.uniform(0.8, 1.1), rng.uniform(*tops), lit, detail,
                most, styles)
            x += w + rng.choice((6.0, 8.0, 22.0))
    # to the sides and behind: neighbours, lower near and rising away
    for cx in (-70.0, 70.0, -126.0, 126.0, -190.0, 190.0):
        z = -14.0
        while z < 150.0:
            d = rng.uniform(30.0, 48.0)
            rise = (abs(cx) - 70.0) * 0.35
            put(cx + rng.uniform(-5, 5), z + d / 2, 38.0, d, rng.uniform(-50.0, -12.0) + rise, 0.26, 1, 40,
                near if abs(cx) < 100 else STYLES)
            z += d + rng.choice((6.0, 20.0))
    x = -40.0
    while x < 40.0:
        w = rng.uniform(26.0, 40.0)
        put(x + w / 2, 78.0, w, 36.0, rng.uniform(-46.0, -10.0), 0.26, 1, 40, near)
        x += w + 8.0


def build(s):
    roof(s)
    stair_room(s)
    plant(s)
    city(s)
