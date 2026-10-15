"""The Muerto's flat: a bare modern room high over the city at night, where they write the names. A lone
desk in the middle of the floor with its back to a wide window; the city's red neon pours in through the
glass behind it, so whoever sits there is a black shape edged in red, lit from the front only by the desk's
green screen and its lamp. Little else: a shelf, a sofa against the wall, a plant.

The shots look at the desk from the room (south), the window behind it."""

from maps import kit
from maps.venues.sets import plan as P

OX, OZ = P.FLAT
X0, X1, Z0, Z1, H = -9.0, 9.0, -7.0, 7.0, 10.0
NEON = (255, 40, 70)  # the city's red through the window
DESK = (0.0, -2.6)  # the desk (its writer sits north of it, facing south, the window at their back)
CHAIR = (1.3, -5.5)  # east of the screen, where the writer sits
DESK_SCALE = 1.12  # a seated R6 body's thighs (a stud thick, knees that do not bend) pass under its top


def at(x, z):
    return OX + x, OZ + z


def build(s):
    x0, z0 = at(X0, Z0)
    x1, z1 = at(X1, Z1)
    kit.floor(s, x0, z0, x1, z1, "WoodFloorDark")
    kit.ceiling(s, x0, z0, x1, z1, H, "CeilingPlasterDark")
    # Floor to ceiling glass along the north wall, behind the desk.
    window = {"at": 9.0, "w": 13.0, "bottom": 1.2, "top": 9.2, "kind": "window", "frame": "BlackTrim",
              "mullions": "BlackTrim", "cols": 4, "rows": 2, "sill": "BlackTrim", "glass": "Glass"}
    door = {"at": 14.0, "w": 3.6, "bottom": 0.0, "top": 7.6, "kind": "door", "frame": "BlackTrim"}
    runs = [((x0, z0), (x1, z0), [window]), ((x1, z0), (x1, z1), []), ((x1, z1), (x0, z1), [door]),
            ((x0, z1), (x0, z0), [])]
    for a, b, ops in runs:
        kit.wall(s, a, b, H, core="ConcreteDark", side_s="PlasterGrey", openings=ops, trim_s={"base": "BlackTrim"})
    # The city beyond the glass: towers, and the red of a sign flooding in.
    cx, cz = at(0.0, Z0)
    s.box("CityFacade", (cx, 4.0, cz - 36.0), (120.0, 60.0, 1.0))  # (well clear of the locker room south)
    s.box("CityFacadeWarm", (cx + 22.0, 0.0, cz - 24.0), (16.0, 36.0, 1.0))
    s.box("CityFacade", (cx - 24.0, -2.0, cz - 28.0), (18.0, 32.0, 1.0))
    s.box("NeonRed", (cx - 8.0, 7.5, cz - 16.0), (6.0, 2.2, 0.3))  # the sign itself, seen past the desk
    s.light("spot", (cx - 4.0, 8.0, cz - 3.0), NEON, 34, 3.4, shadows=True, face="Back", angle=70)
    s.light("spot", (cx + 5.0, 9.0, cz - 2.0), (90, 110, 200), 26, 0.35, shadows=False, face="Back", angle=60)
    # The desk and its chair; the desk's own lamp and screen light the face in front.
    px, pz = at(*DESK)
    s.prop("Desk", px, pz, 0, DESK_SCALE)  # drawers, keyboard and screen face the writer (north side)
    px, pz = at(*CHAIR)
    s.prop("OfficeChair", px, pz, 180, 0.85)  # low enough for a seated R6 body to go under the desk
    # The writer's face: the screen's green glow from their right, the lamp from their left, and a dim light
    # from above so the black suit holds its shape against the dark.
    s.light("point", (OX - 1.1, 4.1, OZ + DESK[1] - 1.0), (90, 230, 170), 8, 1.3, shadows=False)
    s.light("point", (OX + 2.4, 4.3, OZ + DESK[1] - 0.6), (255, 200, 140), 9, 1.8, shadows=True)
    s.light("spot", (OX + 1.3, H - 0.4, OZ + DESK[1] - 0.6), (170, 175, 210), 14, 0.7, shadows=True, angle=40)
    # Sparse: a shelf, the sofa against the east wall, a plant in the corner by the window (all clear of the walls'
    # faces at +-8.5 and +-6.5, and of the doorway, x -6.8..-3.2: they stood in them).
    px, pz = at(X0 + 1.6, 1.5)
    s.prop("Bookshelf", px, pz, -90)
    px, pz = at(X1 - 2.2, 2.0)
    s.prop("Sofa", px, pz, 90)
    px, pz = at(-7.0, -5.0)
    s.prop("Plant", px, pz, 0)
    s.light("spot", (OX, H - 0.6, OZ + 3.0), (120, 130, 170), 22, 0.25, shadows=False, angle=80)  # a breath of fill
