"""Ace's room and the Butler's pantry beside it.

Ace's room: a dark hotel suite turned into a surveillance room. A wall of monitors on the north side, the
only light; one armchair in front of them where Ace sits crouched; a low table with sweets and tea; cables
across the carpet. The pantry next door (through a doorway in the east wall): the Butler's narrow galley,
cupboards and a counter, the tea trolley, one warm lamp."""

from maps import kit
from maps.venues.sets import plan as P

AX, AZ = P.ACE
PX, PZ = P.PANTRY
SCREEN = (140, 180, 255)


def ace_room(s):
    x0, z0, x1, z1, h = AX - 12.0, AZ - 9.0, AX + 10.0, AZ + 9.0, 12.0
    kit.floor(s, x0, z0, x1, z1, "CarpetNavy")
    kit.ceiling(s, x0, z0, x1, z1, h, "CeilingDark")
    door = {"at": 9.0, "w": 4.0, "bottom": 0.0, "top": 8.0, "kind": "door", "frame": "BlackTrim"}
    runs = [((x0, z0), (x1, z0), []), ((x1, z0), (x1, z1), [door]), ((x1, z1), (x0, z1), []), ((x0, z1), (x0, z0), [])]
    for a, b, ops in runs:
        kit.wall(s, a, b, h, core="ConcreteDark", side_s="PlasterDark", openings=ops)
    # The monitor wall: CRT banks with screens above them, cameras' feeds and the case.
    for x in (-7.5, -2.0, 3.5):
        s.prop("StationCRTBank", AX + x, AZ - 6.7, 0)
    for x, loop in ((-7.5, "cctv"), (-2.0, "news"), (3.5, "cctv")):
        s.box("Screen", (AX + x, 9.4, AZ - 8.38), (4.6, 2.6, 0.2))
        s.screen((AX + x, 9.4, AZ - 8.26), 0, 4.4, 2.4, loop)
    for x in (-7.5, -2.0, 3.5):
        s.light("point", (AX + x, 5.0, AZ - 5.0), SCREEN, 14, 0.9)
    s.light("spot", (AX - 2.0, 9.0, AZ - 7.8), SCREEN, 20, 0.8, face="Back", angle=70)
    # The armchair facing them, a low table beside it with sweets and a teacup.
    s.prop("ClubChair", AX - 2.0, AZ - 1.8, 0)
    s.box("Wood", (AX + 1.6, 1.3, AZ - 1.4), (2.4, 0.15, 2.0))
    for dx, dz in ((-0.6, -0.4), (0.6, -0.4), (-0.6, 0.4), (0.6, 0.4)):
        s.box("BlackMetal", (AX + 1.6 + dx, 0.6, AZ - 1.4 + dz), (0.1, 1.2, 0.1))
    for k, (dx, dz, color) in enumerate(((-0.6, -0.3, "NeonPink"), (-0.2, 0.2, "PaintYellow"), (0.3, -0.4, "Vermilion"),
                                          (0.0, -0.1, "WhiteTrim"))):
        s.box(color, (AX + 1.6 + dx, 1.45, AZ - 1.4 + dz), (0.3, 0.15, 0.3))
    s.box("WhiteTrim", (AX + 2.3, 1.55, AZ - 1.0), (0.4, 0.35, 0.4))
    # Cables across the carpet to the monitors, a filing cabinet, the curtains drawn.
    for k in range(4):
        s.tube("Rubber", (AX - 9.0 + k * 3.0, 0.08, AZ - 6.8), (AX - 3.0 + k * 1.6, 0.08, AZ + 2.0), 0.08, 5)
    s.prop("FilingCabinet", AX + 8.2, AZ - 7.4, 0)
    s.box("FabricRed", (AX - 11.6, 6.0, AZ + 2.0), (0.2, 10.0, 8.0))


def pantry(s):
    x0, z0, x1, z1, h = PX - 7.0, PZ - 6.0, PX + 7.0, PZ + 6.0, 11.0
    kit.floor(s, x0, z0, x1, z1, "TileChecker")
    kit.ceiling(s, x0, z0, x1, z1, h, "Ceiling")
    door = {"at": 6.0, "w": 4.0, "bottom": 0.0, "top": 8.0, "kind": "gap"}  # facing Ace's door
    runs = [((x0, z0), (x1, z0), []), ((x1, z0), (x1, z1), []), ((x1, z1), (x0, z1), []), ((x0, z1), (x0, z0), [door])]
    for a, b, ops in runs:
        kit.wall(s, a, b, h, core="ConcreteDark", side_s="Wallpaper", openings=ops,
                 trim_s={"base": "WoodPanel", "wainscot": ("WoodPanel", 3.6), "rail": "Wood", "crown": "Wood"})
    # The counter and cupboards along the north wall, the shelves above, the trolley.
    kit.counter(s, PX + 1.0, PZ - 4.6, 180, 10.0, top="MarbleWhite", body="WoodPanel")
    for k in range(3):
        s.box("Wood", (PX + 1.0, 6.4 + k * 1.6, PZ - 5.6), (9.6, 0.15, 0.8))
        for j in range(5):
            s.box("WhiteTrim", (PX - 2.6 + j * 1.8, 6.75 + k * 1.6, PZ - 5.6), (0.5, 0.55, 0.5))
    s.prop("DrinksTrolley", PX + 2.0, PZ + 1.5, 90)
    s.box("BlackMetal", (PX - 1.4, 3.75, PZ - 4.4), (0.8, 0.5, 0.8))  # the kettle on the counter
    kit.pendant(s, PX + 1.0, h, PZ - 1.0, drop=3.5, shade="Brass", range_=18, brightness=1.0)


def build(s):
    ace_room(s)
    pantry(s)
