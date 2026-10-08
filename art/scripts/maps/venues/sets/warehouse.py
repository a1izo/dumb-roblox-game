"""The warehouse of the finale: an empty steel shed by the docks. Corrugated walls, a concrete floor stained
with oil, yellow-painted steel columns, crates stacked in the corners, a roll-up door half open on the
night, the roof's skylights letting the moon down in long beams, and one lamp hanging over the open floor
in the middle where it all ends."""

from maps import kit
from maps.venues.sets import plan as P

OX, OZ = P.WAREHOUSE
X0, X1, Z0, Z1, H = -36.0, 36.0, -26.0, 26.0, 26.0
MOON = (160, 180, 230)


def build(s):
    x0, z0, x1, z1 = OX + X0, OZ + Z0, OX + X1, OZ + Z1
    kit.floor(s, x0, z0, x1, z1, "ConcreteDark")
    for dx, dz, w, d in ((-8.0, 6.0, 9.0, 6.0), (12.0, -10.0, 6.0, 4.0), (20.0, 12.0, 5.0, 7.0)):  # oil stains
        s.box("Rubber", (OX + dx, 0.02, OZ + dz), (w, 0.03, d))
    door = {"at": 26.0, "w": 16.0, "bottom": 0.0, "top": 9.0, "kind": "gap"}
    runs = [((x0, z0), (x1, z0), []), ((x1, z0), (x1, z1), []), ((x1, z1), (x0, z1), [door]), ((x0, z1), (x0, z0), [])]
    for a, b, ops in runs:
        kit.wall(s, a, b, H, core="ConcreteDark", side_s="Shutter", openings=ops)
    # The roll-up door, raised to 9: its curtain above the opening, the night outside.
    s.box("Shutter", (OX + 10.0, (9.0 + 16.0) / 2, OZ + Z1 - 0.6), (16.0, 7.0, 0.3))
    s.box("CityRoad", (OX + 10.0, -0.01, OZ + Z1 + 20.0), (40.0, 0.1, 40.0))
    s.light("point", (OX + 10.0, 6.0, OZ + Z1 + 6.0), (200, 150, 90), 26, 0.8)
    # The roof: a dark deck on steel trusses, skylight strips letting the moon in.
    s.box("DarkMetal", (OX, H + 0.5, OZ), (X1 - X0, 1.0, Z1 - Z0), skip=("+y",))
    for x in range(int(X0) + 8, int(X1) - 4, 12):
        s.box("BlackMetal", (OX + x, H - 1.2, OZ), (0.8, 2.4, Z1 - Z0))
        s.box("BlackMetal", (OX + x, H - 3.8, OZ), (0.4, 0.4, Z1 - Z0))
        for z in range(int(Z0) + 4, int(Z1), 8):
            s.tube("BlackMetal", (OX + x, H - 3.8, OZ + z), (OX + x, H - 1.2, OZ + z + 4), 0.15, 5)
    for x in (-18.0, 6.0):
        s.box("GlassFrosted", (OX + x, H - 0.05, OZ), (5.0, 0.1, Z1 - Z0 - 8.0))
        for z in (-12.0, 0.0, 12.0):
            s.light("spot", (OX + x, H - 0.5, OZ + z), MOON, 34, 1.3, shadows=True, angle=35)
    # Yellow-painted columns in two rows, crates in the corners and along the walls, a forklift's pallets.
    for x in (-24.0, -8.0, 8.0, 24.0):
        for z in (-12.0, 12.0):
            kit.column_square(s, OX + x, OZ + z, H, 1.2, "PaintYellow", trim="BlackMetal")
    for x, z, rot, stack in ((-31.0, -21.0, 5, 2), (-25.0, -21.5, -8, 1), (-31.0, -15.2, 14, 1), (30.0, -21.0, -6, 2),
                             (24.2, -21.0, 10, 1), (31.0, 20.0, 3, 2), (-31.0, 20.0, -12, 2), (-25.2, 21.0, 4, 1),
                             (18.0, -21.5, 20, 1)):
        for k in range(stack):
            s.prop("Crate", OX + x, OZ + z, rot + k * 13, 1.25, k * 5.0)
    for x, z in ((-16.0, -22.0), (-12.0, -22.0)):
        s.box("Wood", (OX + x, 0.3, OZ + z), (3.6, 0.6, 3.6))
    # The lamp over the middle of the floor: the only warm light, a hard cone on the concrete.
    kit.pendant(s, OX, H, OZ, drop=10.0, shade="BlackMetal", range_=30, brightness=2.2, shadows=True, wide=2.2)
    s.light("spot", (OX, H - 10.5, OZ), (255, 214, 160), 28, 2.0, shadows=True, angle=60)
    s.emitter("dust", (OX, 10.0, OZ), 0, (60.0, 18.0, 44.0))
    s.sign((OX - 35.6, 14.0, OZ), 90, 10.0, 3.0, "倉庫 B", "GothamBlack", (40, 40, 36), (200, 170, 30))
