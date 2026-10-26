"""The hall of the Bureau's Godhood win cutscene (src/shared/Cinema/WinCuts.luau checkmate; the owner, 2026-10-26:
"build extremely high quality and rendered scenes in which every cutscene sits"): a vast stone hall at night, the
cutscene's chessboard (eight squares of 6, laid by the game) sunk level in a floor of black marble, in a carved walnut
frame inlaid with brass. Two rows of fluted black columns carry the dark vault; between them tall windows let the
moon in, and at the far end a great window behind the giant king throws it long across the board; crimson banners
hang either side of it; mist lies over the floor. The star's mark is the room's origin (plan.HALL), on the board's
near rank."""

from maps import kit
from maps.venues.sets import plan as P

OX, OZ = P.HALL
X0, X1, Z0, Z1, H = -40.0, 40.0, -58.0, 36.0, 48.0
BOARD = (-24.0, -33.0, 24.0, 15.0)  # the cutscene's board: 48 square, its middle at z -9, its top at the floor's
FRAME = 1.0
MOON = (150, 172, 230)


def build(s):
    x0, z0, x1, z1 = OX + X0, OZ + Z0, OX + X1, OZ + Z1
    bx0, bz0, bx1, bz1 = OX + BOARD[0], OZ + BOARD[1], OX + BOARD[2], OZ + BOARD[3]
    # The floor: a bed under the board (its squares stand on it, half a stud deep), black marble round it level with
    # the board's top, and the frame between them, a lip a little proud of both, a brass line along its outer edge.
    kit.floor(s, x0, z0, x1, z1, "ConcreteDark", y=-0.55)
    f = FRAME
    for a, b, c, d in ((x0, z0, x1, bz0 - f), (x0, bz1 + f, x1, z1), (x0, bz0 - f, bx0 - f, bz1 + f),
                       (bx1 + f, bz0 - f, x1, bz1 + f)):
        kit.floor(s, a, b, c, d, "MarbleBlack", y=0.0, thick=0.55)
    cx, cz = (bx0 + bx1) / 2, (bz0 + bz1) / 2
    w, d = bx1 - bx0, bz1 - bz0
    for centre, size in (((cx, -0.2, bz0 - f / 2), (w + 2 * f, 0.7, f)), ((cx, -0.2, bz1 + f / 2), (w + 2 * f, 0.7, f)),
                         ((bx0 - f / 2, -0.2, cz), (f, 0.7, d)), ((bx1 + f / 2, -0.2, cz), (f, 0.7, d))):
        s.box("Wood", centre, size)
    for centre, size in (((cx, 0.16, bz0 - f + 0.08), (w + 2 * f, 0.02, 0.12)), ((cx, 0.16, bz1 + f - 0.08), (w + 2 * f, 0.02, 0.12)),
                         ((bx0 - f + 0.08, 0.16, cz), (0.12, 0.02, d + 2 * f)), ((bx1 + f - 0.08, 0.16, cz), (0.12, 0.02, d + 2 * f))):
        s.box("Brass", centre, size)
    # The walls: tall windows down both sides between the columns, a great one at the far end behind the king.
    side = [{"at": at, "w": 5.0, "bottom": 10.0, "top": 34.0, "kind": "window", "frame": "Stone", "mullions": "BlackMetal",
             "cols": 1, "rows": 4, "sill": "Stone", "glass": "GlassDark"} for at in (14.5, 27.5, 40.5, 53.5, 66.5, 79.5)]
    great = {"at": -X0, "w": 18.0, "bottom": 8.0, "top": 40.0, "kind": "window", "frame": "Stone",
             "mullions": "BlackMetal", "cols": 3, "rows": 6, "sill": "Stone", "glass": "GlassDark"}
    runs = [((x0, z0), (x1, z0), [great]), ((x1, z0), (x1, z1), side), ((x1, z1), (x0, z1), []), ((x0, z1), (x0, z0), side)]
    for a, b, ops in runs:
        kit.wall(s, a, b, H, core="ConcreteDark", side_s="Stone", openings=ops, trim_s={"base": "BlackTrim"})
    kit.ceiling(s, x0, z0, x1, z1, H, "CeilingDark", beams=13.0, beam_mat="DarkMetal", beam_depth=2.4, beam_w=1.6)
    # Two rows of columns, between the windows.
    for x in (-31.0, 31.0):
        for z in range(-50, 31, 13):
            kit.column_round(s, OX + x, OZ + z, H, 1.6, "MarbleBlack", trim="Brass", flutes=16)
    # The moon: a long cold light through the great window down the board (behind the king: his edge, the star's
    # face), pools under the side windows, and the night beyond the glass.
    s.light("spot", (OX, 30.0, OZ + Z0 - 6.0), MOON, 90, 1.6, shadows=True, face="Back", angle=30)
    for x, face in ((x0 - 4.0, "Right"), (x1 + 4.0, "Left")):
        for z in (-37.0, -11.0, 15.0):
            s.light("spot", (x, 26.0, OZ + z), MOON, 46, 0.7, shadows=True, face=face, angle=26)
    s.box("CityFacade", (OX, 20.0, OZ + Z0 - 30.0), (140.0, 70.0, 1.0))
    # Crimson banners either side of the great window, each on its brass rod.
    for x in (-16.0, 16.0):
        s.box("FabricRed", (OX + x, 25.0, OZ + Z0 + 0.62), (5.0, 26.0, 0.1))
        s.tube("Brass", (OX + x - 3.0, 38.2, OZ + Z0 + 0.7), (OX + x + 3.0, 38.2, OZ + Z0 + 0.7), 0.14, 8)
    # Mist over the floor, dust high in the moonlight.
    s.emitter("mist", (OX, 1.5, OZ - 9.0), 0, (76.0, 3.0, 88.0))
    s.emitter("dust", (OX, 24.0, OZ - 20.0), 0, (40.0, 30.0, 60.0))
