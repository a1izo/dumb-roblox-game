"""The evidence archive of The Final Page told for the Bureau (src/shared/Cinema/WinCuts.luau finalPageBureau; the
user, 2026-10-27: every shop win cutscene for both Ace and the Coven): the Bureau's evidence archive at dawn, the case
over. A long steel table in the middle of a tall grey room, rows of steel archive shelving packed with boxes down
both sides, a caged door at the back, and high in the north wall a row of windows the first light comes through low
and gold, laying long bars of it across the table and the floor. The star's mark is the room's origin (plan.ARCHIVE),
at the table's south side, facing it."""

from maps import kit
from maps.venues.sets import plan as P

OX, OZ = P.ARCHIVE
X0, X1, Z0, Z1, H = -11.0, 11.0, -9.0, 9.0, 12.0
TRIM = {"base": "BlackTrim"}
DAWN = (255, 196, 140)
COLD = (176, 196, 232)
TABLE_Z = -2.4  # the table's middle (its top 2.75 high; the cutscene lays the Manual on it)
SHELF_X = 7.9  # the shelving rows' middles, either side


def box_file(s, x, y, z, rot, w=1.5, h=1.0, d=1.1):
    """An archive box: pale card, a darker lid, a white label on its end."""
    s.box("PlasterCream", (x, y + h / 2 - 0.06, z), (w, h - 0.12, d), rot)
    s.box("CreamTrim", (x, y + h - 0.06, z), (w + 0.06, 0.12, d + 0.06), rot)


def build(s):
    x0, z0, x1, z1 = OX + X0, OZ + Z0, OX + X1, OZ + Z1
    kit.floor(s, x0, z0, x1, z1, "TerrazzoDark")
    kit.ceiling(s, x0, z0, x1, z1, H, "CeilingDark")
    # The north wall: three high windows the dawn comes through; the caged door in the south wall behind the star.
    windows = [{"at": at, "w": 4.6, "bottom": 7.4, "top": 10.8, "kind": "window", "frame": "BlackTrim",
                "mullions": "BlackTrim", "cols": 3, "rows": 2, "sill": "Concrete", "glass": "WindowGlass"}
               for at in (4.0, 11.0, 18.0)]
    door = {"at": 11.0, "w": 4.0, "bottom": 0.0, "top": 7.8, "kind": "door", "frame": "DarkMetal"}
    runs = [((x0, z0), (x1, z0), windows), ((x1, z0), (x1, z1), []), ((x1, z1), (x0, z1), [door]),
            ((x0, z1), (x0, z0), [])]
    for a, b, ops in runs:
        kit.wall(s, a, b, H, core="ConcreteDark", side_s="PlasterGrey", openings=ops, trim_s=TRIM)
    # (the cage door: a steel frame, its chain-link panel, the padlock hanging open)
    s.box("DarkMetal", (OX, 3.9, z1 - 0.1), (3.9, 7.7, 0.12))
    s.box("ChainLink", (OX, 3.9, z1 - 0.2), (3.5, 7.3, 0.04))
    s.box("Brass", (OX + 1.6, 3.6, z1 - 0.32), (0.3, 0.4, 0.12))
    # The first light: low through the windows from the north-east, in long bars across the room (shadowed by the
    # mullions); a cold fill from the corridor's lamp beyond the cage.
    s.light("spot", (OX + 6.0, 12.6, OZ - 21.0), DAWN, 46, 2.4, shadows=True, face="Back", angle=60)
    s.light("point", (OX, 6.5, z1 + 3.0), COLD, 16, 0.5)
    # The table: long, steel-topped, the evidence lamp over it (off: the day has come).
    kit.table(s, OX, OZ + TABLE_Z, 7.2, 3.2, top="Steel", legs="DarkMetal")
    s.tube("BlackMetal", (OX, H, OZ + TABLE_Z), (OX, 7.6, OZ + TABLE_Z), 0.04, 4)
    s.lathe("DarkMetal", (OX, 7.0, OZ + TABLE_Z), [(0.15, 0.6), (1.1, 0.0)], 16)
    for x, z in ((-2.6, -0.2), (2.9, 0.4)):
        box_file(s, OX + x, 2.75, OZ + TABLE_Z + z, 8 if x < 0 else -14)
    box_file(s, OX - 2.6, 3.75, OZ + TABLE_Z - 0.2, 2, 1.4, 0.9, 1.0)
    # The shelving rows down both sides, three bays a side, boxes stacked on the floor at their ends.
    for side in (-1, 1):
        for z in (-5.5, 1.5):
            s.prop("ArchiveShelving", OX + side * SHELF_X, OZ + z, 90 * side)
        for k, (z, h) in enumerate(((6.4, 3), (7.6, 2))):
            for j in range(h):
                box_file(s, OX + side * (SHELF_X - 0.4), j * 1.0, OZ + z, 4 * (k + j) * side)
    # A trolley left by the west row with boxes on it; a filing cabinet and a fire extinguisher by the door.
    s.box("Steel", (OX - 4.6, 2.1, OZ + 5.4), (1.8, 0.1, 3.0))
    s.box("Steel", (OX - 4.6, 0.6, OZ + 5.4), (1.8, 0.1, 3.0))
    for dz in (-1.3, 1.3):
        for dx in (-0.8, 0.8):
            s.tube("DarkMetal", (OX - 4.6 + dx, 0.2, OZ + 5.4 + dz), (OX - 4.6 + dx, 2.1, OZ + 5.4 + dz), 0.05, 4)
    box_file(s, OX - 4.6, 2.15, OZ + 4.8, 5)
    box_file(s, OX - 4.6, 2.15, OZ + 6.1, -3)
    s.prop("FilingCabinet", OX + 4.6, OZ + 7.6, 0)
    kit.extinguisher(s, OX - 3.0, z1 - 0.5, 0)
    # The wall's notices: the archive's rules and a fire plan by the door, a clock over the windows.
    kit.picture(s, OX + 3.6, 5.6, z1 - 0.5, 0, w=2.0, h=2.6, frame="BlackTrim", inner="Paper")
    kit.wall_clock(s, OX, 11.2, z0 + 0.5, 180, 0.55)
