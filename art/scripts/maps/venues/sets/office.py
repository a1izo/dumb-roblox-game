"""The Bureau's office of its Sealed win cutscene (src/shared/Cinema/WinCuts.luau caseClosed; the owner, 2026-10-26:
"build extremely high quality and rendered scenes in which every cutscene sits"): a detective's office at night. The
star crouches on the chair at its middle, the desk before them and the evidence board on the north wall beyond it.
Grey plaster over a walnut dado, a grey carpet; in the west wall a window of venetian blinds, the city's cold light
coming through them in stripes across the room; filing cabinets either side of the board, a banker's lamp left on
on one, a bookshelf, a coat stand and a water cooler by the door, a ceiling fan stopped over the desk. The star's
mark is the room's origin (plan.OFFICE)."""

from maps import kit
from maps.venues.sets import plan as P

OX, OZ = P.OFFICE
X0, X1, Z0, Z1, H = -8.5, 8.5, -8.4, 8.0, 12.0
TRIM = {"base": "BlackTrim", "wainscot": ("WoodPanel", 3.4), "rail": "Wood", "crown": "WhiteTrim"}
NIGHT = (150, 175, 230)
LAMP = (255, 214, 150)
CABINET = 5.0  # a filing cabinet's height


def build(s):
    x0, z0, x1, z1 = OX + X0, OZ + Z0, OX + X1, OZ + Z1
    kit.floor(s, x0, z0, x1, z1, "CarpetGrey")
    kit.ceiling(s, x0, z0, x1, z1, H, "CeilingPlasterDark")
    # The window in the west wall, left of the star (z -3.5..1.5), and the door in the south wall behind them.
    window = {"at": Z1 + 1.0, "w": 5.0, "bottom": 3.6, "top": 9.6, "kind": "window", "frame": "WhiteTrim",
              "mullions": "WhiteTrim", "cols": 1, "rows": 1, "sill": "WhiteTrim", "glass": "Glass"}
    door = {"at": 3.5, "w": 3.6, "bottom": 0.0, "top": 7.6, "kind": "door", "frame": "Wood"}
    runs = [((x0, z0), (x1, z0), []), ((x1, z0), (x1, z1), []), ((x1, z1), (x0, z1), [door]),
            ((x0, z1), (x0, z0), [window])]
    for a, b, ops in runs:
        kit.wall(s, a, b, H, core="ConcreteDark", side_s="PlasterGrey", openings=ops, trim_s=TRIM)
    # (the door shut in its frame, its frosted pane: open, it showed the nothing beyond the set)
    s.box("Wood", (OX + X1 - 3.5, 3.8, OZ + Z1), (3.5, 7.6, 0.25))
    s.box("GlassFrosted", (OX + X1 - 3.5, 5.4, OZ + Z1 - 0.14), (2.2, 2.4, 0.04))
    s.box("Brass", (OX + X1 - 4.9, 3.6, OZ + Z1 - 0.2), (0.16, 0.16, 0.2))
    # The blinds: slats across the window inside it, a little apart, their cord and rail; the city's light through
    # them throws stripes on the east wall and the floor.
    for k in range(20):
        s.box("BlindSlat", (x0 + 0.7, 3.75 + k * 0.29, OZ - 1.0), (0.3, 0.05, 4.9))
    s.box("WhiteTrim", (x0 + 0.7, 9.55, OZ - 1.0), (0.4, 0.2, 5.0))
    s.tube("WhiteTrim", (x0 + 0.86, 9.5, OZ + 1.2), (x0 + 0.86, 5.2, OZ + 1.2), 0.025, 4)
    for dx, dz, w, h in ((-16.0, -6.0, 1.0, 34.0), (-22.0, 6.0, 1.0, 40.0)):
        s.box("CityFacade", (x0 + dx, h / 2 - 10.0, OZ + dz), (w, h, 14.0))
    s.light("spot", (x0 - 7.0, 7.4, OZ - 1.0), NIGHT, 30, 1.6, shadows=True, face="Right", angle=34)
    # Filing cabinets either side of the evidence board (the cutscene brings the board and the one on the west), the
    # banker's lamp on the east one, lit; the bookshelf on the east wall, the radiator under the window.
    s.prop("FilingCabinet", OX + 6.6, OZ - 6.9, 180)  # (its drawers to the room)
    s.prop("BankerLamp", OX + 6.6, OZ - 6.9, 180, 1.0, CABINET)
    s.light("point", (OX + 6.6, CABINET + 1.0, OZ - 7.0), LAMP, 10, 0.9, shadows=True)
    s.prop("Bookshelf", OX + X1 - 1.4, OZ + 1.8, 90)
    s.prop("Radiator", OX + X0 + 0.9, OZ - 1.0, -90, 0.8)
    s.prop("CoatStand", OX + 7.0, OZ + 6.4, 0)
    s.prop("WaterCooler", OX - 6.9, OZ + 6.5, 0)
    s.prop("Plant", OX - 6.6, OZ - 3.9, 0, 0.8)
    # The ceiling fan, stopped: its hub on a rod from the ceiling, four blades.
    fx, fz, fy = OX - 0.2, OZ + 2.6, H - 1.6
    s.tube("BlackMetal", (fx, H, fz), (fx, fy, fz), 0.06, 6)
    s.cylinder("BlackMetal", (fx, fy - 0.3, fz), 0.32, 0.4, 14)
    for rot in (20, 110):
        s.box("Wood", (fx, fy - 0.12, fz), (5.2, 0.05, 0.6), rot)
    # The clock over the door, a framed citation and a map on the east wall.
    kit.wall_clock(s, OX - 3.5, 9.6, OZ + Z1 - 0.3, 0, 0.75)
    kit.picture(s, OX + X1 - 0.55, 7.2, OZ - 3.2, 90, w=2.0, h=1.6, frame="Wood", inner="Paper")
    kit.picture(s, OX + X1 - 0.55, 7.0, OZ + 5.4, 90, w=3.2, h=2.4, frame="BlackTrim", inner="Paper")
