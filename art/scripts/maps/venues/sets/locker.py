"""The Bureau's locker room, early on the night of a case: steel lockers along both long walls, a bench
down the middle, the Bureau's seal on the end wall, a mirror, cold fluorescent light."""

from maps import kit
from maps.venues.sets import plan as P

OX, OZ = P.LOCKER
W, TALL, DEEP = 1.5, 7.0, 1.6


def lockers(s, x_from, count, z_back, face, seed):
    """A row of steel lockers from x_from eastwards, backs against z_back, doors towards face (+1 / -1):
    each a carcass on a black plinth, a door with vent slits top and bottom, a handle and a name card."""
    z = z_back + face * DEEP / 2
    front = z_back + face * (DEEP + 0.03)
    for k in range(count):
        x = OX + x_from + W * (k + 0.5)
        s.box("PaintSteel", (x, 0.4 + TALL / 2, OZ + z), (W - 0.04, TALL, DEEP), collide=True)
        s.box("BlackTrim", (x, 0.2, OZ + z - face * 0.1), (W, 0.4, DEEP - 0.2))
        s.box("PaintSteel", (x, 0.4 + TALL / 2, OZ + front), (W - 0.16, TALL - 0.3, 0.06))
        # (Vents and cards stand well proud of the door: a hundredth off it, they flickered.)
        for y in (TALL - 0.2, TALL - 0.45, TALL - 0.7, 1.0, 1.25):
            s.box("DarkMetal", (x, y, OZ + front + face * 0.06), (W - 0.6, 0.06, 0.03))
        s.box("Steel", (x + 0.5, 3.9, OZ + front + face * 0.07), (0.08, 0.55, 0.1))
        if (k * 7 + seed) % 3:
            s.box("Paper", (x, TALL - 1.2, OZ + front + face * 0.06), (0.6, 0.25, 0.03))


def build(s):
    x0, z0, x1, z1, h = OX - 11.0, OZ - 7.0, OX + 11.0, OZ + 7.0, 11.0
    kit.floor(s, x0, z0, x1, z1, "TileWhite")
    kit.ceiling(s, x0, z0, x1, z1, h, "Ceiling")
    door = {"at": 9.5, "w": 4.0, "bottom": 0.0, "top": 8.0, "kind": "door", "frame": "DarkMetal"}
    runs = [((x0, z0), (x1, z0), []), ((x1, z0), (x1, z1), []), ((x1, z1), (x0, z1), [door]), ((x0, z1), (x0, z0), [])]
    for a, b, ops in runs:
        kit.wall(s, a, b, h, core="ConcreteDark", side_s="PlasterGrey", openings=ops,
                 trim_s={"base": "BlackTrim"})
    lockers(s, -9.75, 13, -6.5, 1, 0)
    lockers(s, -9.75, 5, 6.5, -1, 1)
    lockers(s, 3.6, 4, 6.5, -1, 2)  # (clear of the doorway, x -0.5..3.5: the row ran across its edge)
    # Two benches down the middle, a gap between them on the way to the door.
    s.prop("Bench", OX - 2.5, OZ, 0)
    s.prop("Bench", OX + 5.5, OZ, 0)
    # The seal on the west wall, a mirror and a sink on the east wall (the walls' faces at x +-10.5: inside them
    # and turned to the wall, the seal could not be seen).
    s.sign((OX - 10.4, 7.2, OZ), -90, 6.0, 1.2, "BUREAU", "GothamBlack", (220, 222, 226), (24, 26, 32))
    s.box("MirrorGlass", (OX + 10.42, 6.0, OZ - 1.0), (0.1, 3.0, 4.0))
    s.box("WhiteTrim", (OX + 10.05, 3.2, OZ - 1.0), (0.8, 0.4, 2.2))
    for x in (-6.0, 0.0, 6.0):
        kit.tube_light(s, OX + x, h, OZ, length=6.0, rot=90, range_=16, brightness=0.8)
