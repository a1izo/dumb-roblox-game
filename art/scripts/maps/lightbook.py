"""The light rulebook: how each kind of fitting lights the space around it, so a lamp of one kind behaves
the same in every scene (one lighting language).

Roblox has no bounce light, and its spot and surface lights fall off steeply towards the edge of their cone:
measured in the game (Bureau HQ's archive, 2026-10-12), a ceiling panel as a spot shining down lit the shelves
beside it at 4% of what the same lamp as a round light did (118 degrees), 20% at 180 degrees, 40% at 180
degrees and twice as bright (with the floor under it then brighter than the round light's). Rooms lit by
downward spots read as black walls and ceilings round pools on the floor, and so do the people in them. So a
fitting inside a room is a round light, as its glow and the room's walls want; a lamp out in the open that
real fittings shade from above (lamp posts, lamps on a facade) is a spot, so nothing over its head is lit.

What a round light costs: without shadows it ignores walls and floors, so a ceiling lamp also lights the
foot of the walls on the floor above it, and a room's lamp the far side of a thin wall. The lamps nearest the
camera cast shadows (LightingController's keys), which hides the leaks nearest the player; the rest are kept
down by each lamp's range (finders.leak lists them at every export).

Colours are named by what makes the light; every scene picks from these.
"""

import math

MAX_RANGE = 60  # Roblox stops a light's reach there


def glow_of(look, size):
    """(size, colour) for a fitting's face drawn by the game (a flickering lamp's), in a glowing look's colour."""
    from maps import matlib

    return (tuple(size), matlib.FLAT[look][1])

# Colours (sRGB)
TUNGSTEN = (255, 206, 150)  # bulbs, desk lamps, lanterns, sconces
HALOGEN = (255, 214, 170)  # warm downlights and panels
NEUTRAL = (255, 236, 214)  # stage and display lighting
OFFICE = (226, 236, 255)  # fluorescent tubes
LED = (200, 216, 255)  # cold LED panels, screens' spill
SODIUM = (255, 176, 90)  # the expressway's and the depots' lamps
EMERGENCY = (255, 40, 40)
EXIT = (120, 255, 160)

# Lamps out in the open are shaded from above, as real ones are: wide cones (spots light little near their
# edge, so a narrower cone left the facades beside a lamp black), nothing over the lamp's head.
POST_ANGLE = 160  # a lamp post's head: the ground and the lower facades round it, not the upper floors
FACADE_ANGLE = 160  # a lamp on an outside wall: the street or lane in front of it, not the room behind
CEILING_DROP = 1.0  # how far under the ceiling a ceiling fitting's lamp hangs (closer, it barely lit the ceiling)
WALL_OUT = 0.5  # how far out of the wall a wall fitting's lamp sits (inside its shade)


def facing(dx, dz):
    """The rot that faces direction (dx, dz) (rot 0 faces -Z, 90 faces -X)."""
    return math.degrees(math.atan2(-dx, -dz))


def ceiling(s, pos, color, range_, brightness, shadows=False, flicker=False, role=None, glow=None, rot=0.0,
            clear=False):
    """The lamp of a fitting on a room's ceiling (panel, tube, downlit pendant, an arcade's lamps): a round
    light just under it. glow: (size, colour) of the fitting's face when the game draws it (see
    mesher.Scene.light); rot turns that face with the fitting."""
    s.light("point", pos, color, min(range_, MAX_RANGE), brightness, shadows, "Bottom", 90, flicker, role, rot,
            glow, clear)


def wall(s, pos, rot, color, range_, brightness, shadows=False, flicker=False, role=None, glow=None):
    """The lamp of a fitting on a wall inside (sconce, bulkhead, exit sign) that faces rot: a round light
    just in front of the wall, so it washes the wall round it as well as the room."""
    s.light("point", pos, color, min(range_, MAX_RANGE), brightness, shadows, "Front", 90, flicker, role, rot,
            glow)


def facade(s, pos, rot, color, range_, brightness, shadows=False, flicker=False, role=None, angle=FACADE_ANGLE,
           glow=None):
    """The lamp of a fitting on an outside wall that faces rot (a caged lane lamp, a bracket lamp over a
    door): a spot shining out of the wall over the street, nothing into the building behind."""
    s.light("spot", pos, color, min(range_, MAX_RANGE), brightness, shadows, "Front", angle, flicker, role, rot,
            glow)


def post(s, pos, color, range_, brightness, shadows=False, flicker=False):
    """The lamp in a lamp post's head: a spot shining down and out over the ground round it."""
    s.light("spot", pos, color, min(range_, MAX_RANGE), brightness, shadows, "Bottom", POST_ANGLE, flicker)


def open_light(s, pos, color, range_, brightness, shadows=False, flicker=False, role=None):
    """A lamp that shines every way: a bare flame, a chandelier in the middle of a room, a pool of the
    realm's light."""
    s.light("point", pos, color, min(range_, MAX_RANGE), brightness, shadows, "Bottom", 90, flicker, role)


# Laying out a room's ceiling fittings (the owner, 2026-11-01: every room's lamps were hand-typed points, turned
# every which way, two kinds in one ceiling, stacked on each other). A room's fittings are one kind, sit on a regular
# grid centred in its rectangle, are turned along its long side, and only go where something is lit: the grid cell
# over each desk, station or door asked for. Darker walkways between the pools are the look.

def bounds(rect):
    """(x0, z0, x1, z1) of a rectangle given that way or as its corners [(x, z), ...]."""
    if isinstance(rect[0], (tuple, list)):
        xs, zs = [p[0] for p in rect], [p[1] for p in rect]
        return min(xs), min(zs), max(xs), max(zs)
    return tuple(rect)


def long_rot(rect):
    """The rot that runs a fitting along the rectangle's long side (x0, z0, x1, z1): 0 along x, 90 along z."""
    x0, z0, x1, z1 = bounds(rect)
    return 0.0 if abs(x1 - x0) >= abs(z1 - z0) else 90.0


def grid(rect, spacing):
    """The grid's column (x) and row (z) centres: each side cut into whole bays about `spacing` long."""
    x0, z0, x1, z1 = bounds(rect)

    def axis(a, b):
        a, b = min(a, b), max(a, b)
        n = max(1, round((b - a) / spacing))
        bay = (b - a) / n
        return [a + bay * (i + 0.5) for i in range(n)]

    return axis(x0, x1), axis(z0, z1)


def snap(rect, spacing, points):
    """The grid cells over `points`, each once, in the order asked."""
    xs, zs = grid(rect, spacing)
    cells = []
    for x, z in points:
        cell = (min(xs, key=lambda v: abs(v - x)), min(zs, key=lambda v: abs(v - z)))
        if cell not in cells:
            cells.append(cell)
    return cells


def reach(spacing, range_):
    """A fitting's range on a grid: no further than 1.6 bays, so a point never sits under more than a few lamps."""
    return min(range_, spacing * 1.6, MAX_RANGE)
