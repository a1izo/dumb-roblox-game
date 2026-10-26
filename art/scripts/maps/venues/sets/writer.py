"""The writer's room of the Coven's Sealed win cutscene (src/shared/Cinema/WinCuts.luau finalPage; the owner,
2026-10-26: "build extremely high quality and rendered scenes in which every cutscene sits"): a study in an old house
at night. The star sits at its middle facing the tall window in the north wall, the rain running down the glass and
the city's towers black against the sky until the lightning shows them. Damask over a low walnut dado, books floor to
ceiling down both side walls, a reading chair and a globe in the corners behind, a radiator under the sill. Lit by
the cutscene's own candles and the Manual's pages, a breath of moonlight through the glass and two sconces behind.
The star's mark is the room's origin (plan.WRITER)."""

from maps import kit
from maps.venues.sets import plan as P

OX, OZ = P.WRITER
X0, X1, Z0, Z1, H = -8.5, 8.5, -6.5, 8.2, 13.0
TRIM = {"base": "BlackTrim", "wainscot": ("WoodPanel", 2.2), "rail": "Brass", "crown": "Wood"}
MOON = (150, 170, 220)


def build(s):
    x0, z0, x1, z1 = OX + X0, OZ + Z0, OX + X1, OZ + Z1
    kit.floor(s, x0, z0, x1, z1, "WoodFloorDark", border=("Parquet", 1.2))
    kit.ceiling(s, x0, z0, x1, z1, H, "WoodPanel", beams=4.25, beam_mat="Wood")
    # The cutscene's window: 4.4 wide, from 2.4 to 9.4, a mullion down its middle and a transom across.
    window = {"at": -X0, "w": 4.4, "bottom": 2.4, "top": 9.4, "kind": "window", "frame": "Wood", "mullions": "Wood",
              "cols": 2, "rows": 2, "sill": "Wood", "glass": "Glass"}
    door = {"at": 4.0, "w": 3.6, "bottom": 0.0, "top": 7.6, "kind": "door", "frame": "Wood"}
    runs = [((x0, z0), (x1, z0), [window]), ((x1, z0), (x1, z1), []), ((x1, z1), (x0, z1), [door]),
            ((x0, z1), (x0, z0), [])]
    for a, b, ops in runs:
        kit.wall(s, a, b, H, core="ConcreteDark", side_s="Damask", openings=ops, trim_s=TRIM)
    # (the door shut in its frame: open, it showed the nothing beyond the set)
    s.box("Wood", (OX + X1 - 4.0, 3.8, OZ + Z1), (3.5, 7.6, 0.25))
    s.box("Brass", (OX + X1 - 5.4, 3.6, OZ + Z1 - 0.2), (0.16, 0.16, 0.2))
    # Beyond the glass: the rain on it, and towers between it and the night (the cutscene's "Sky", 16 out, that the
    # lightning lights: they stand black against it), a cold moon over them.
    s.emitter("windowrain", (OX, 5.9, OZ + Z0 - 0.45), 0, (4.4, 7.0, 0.3))
    for dx, dz, w, h in ((-7.5, -12.0, 8.0, 21.0), (6.0, -13.0, 9.0, 25.0), (-0.5, -14.5, 6.0, 29.0)):
        s.box("CityFacade", (OX + dx, h / 2 - 8.0, OZ + dz), (w, h, 1.0))
    for dx, y, dz in ((-5.5, 9.5, -11.4), (6.8, 12.0, -12.4), (-1.2, 15.5, -13.9)):  # a few windows still lit
        s.box("DimWindow", (OX + dx, y, OZ + dz), (0.9, 1.2, 0.2))
    s.light("spot", (OX, 12.0, OZ + Z0 - 5.0), MOON, 24, 0.45, shadows=True, face="Back", angle=40)
    # Books down both side walls (their backs to them), the radiator under the sill; behind the star a reading chair
    # turned to the room and a globe on its stand, a floor lamp left dark.
    for x, rot in ((X0 + 1.5, -90), (X1 - 1.5, 90)):
        for z in (-3.0, 1.8):
            s.prop("BookcaseTall", OX + x, OZ + z, rot)
    s.prop("Radiator", OX, OZ + Z0 + 0.95, 180, 0.8)
    s.prop("ClubChair", OX - 5.4, OZ + 5.5, -40)
    s.prop("FloorGlobe", OX + 5.6, OZ + 5.7, 20)
    s.prop("FloorLamp", OX - 7.3, OZ + 6.9, 0, 0.9)
    # Two sconces either side of the door, low; the clock on the east wall past the books.
    for x in (1.6, 7.4):
        kit.sconce(s, OX + x, 6.2, OZ + Z1 - 0.1, 0, range_=8, brightness=0.22)
    kit.wall_clock(s, OX + X1 - 0.3, 9.0, OZ + 5.6, 90, 0.7)
    # (a picture over the reading chair, in the dark: it catches the lightning)
    kit.picture(s, OX + X0 + 0.55, 7.4, OZ + 5.4, -90, w=3.0, h=2.2, frame="Brass", inner="Paper")
