"""The light rulebook: how each kind of fitting lights the space around it, so a lamp of one kind behaves
the same in every scene (one lighting language), and so no lamp's light reaches through the wall, floor or
ceiling it is fixed to.

In Roblox a light without shadows ignores walls, and only the few lamps nearest the camera cast shadows
(LightingController's keys). So a fitting's lamp is aimed: a ceiling fitting shines down only (nothing up
into its own ceiling or the floor over it), a wall fitting only out of its wall (nothing into the room
behind). Open flames, chandeliers hung in the middle of a room and the Grey Realm's pools stay round lights.
Spots are also the cheapest lights to cast shadows when they are keys (Future lighting: spot under 120
degrees, then surface, then point lights, the dearest).

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

# Cones about as wide as real fittings throw: wider, a ceiling lamp reached through the next room's wall and
# a lamp post into the building beside it. Under 120 degrees a spot is also the cheapest key to shadow.
CEILING_ANGLE = 118  # a ceiling fitting's cone: the room below it, nothing above
WALL_ANGLE = 140  # a wall fitting's cone: the space in front, nothing behind
POST_ANGLE = 118  # a lamp post's head: the ground round it, not the upper floors beside it
CEILING_DROP = 0.3  # how far under the ceiling a ceiling fitting's lamp sits (inside its diffuser)
WALL_OUT = 0.5  # how far out of the wall a wall fitting's lamp sits (inside its shade)


def facing(dx, dz):
    """The rot that faces direction (dx, dz) (rot 0 faces -Z, 90 faces -X)."""
    return math.degrees(math.atan2(-dx, -dz))


def ceiling(s, pos, color, range_, brightness, shadows=False, flicker=False, role=None, glow=None, rot=0.0):
    """The lamp of a ceiling fitting (panel, tube, downlight, a lamp under an awning): a spot shining down.
    glow: (size, colour) of the fitting's face when the game draws it (see mesher.Scene.light)."""
    s.light("spot", pos, color, min(range_, MAX_RANGE), brightness, shadows, "Bottom", CEILING_ANGLE, flicker, role,
            rot, glow)


def wall(s, pos, rot, color, range_, brightness, shadows=False, flicker=False, role=None, angle=WALL_ANGLE,
         glow=None):
    """The lamp of a fitting on a wall that faces rot (sconce, bulkhead, caged lamp, exit sign): a spot
    shining out of the wall."""
    s.light("spot", pos, color, min(range_, MAX_RANGE), brightness, shadows, "Front", angle, flicker, role, rot,
            glow)


def post(s, pos, color, range_, brightness, shadows=False, flicker=False):
    """The lamp in a lamp post's head: a spot shining down and out over the ground round it."""
    s.light("spot", pos, color, min(range_, MAX_RANGE), brightness, shadows, "Bottom", POST_ANGLE, flicker)


def open_light(s, pos, color, range_, brightness, shadows=False, flicker=False, role=None):
    """A lamp that shines every way: a bare flame, a chandelier in the middle of a room, a pool of the
    realm's light."""
    s.light("point", pos, color, min(range_, MAX_RANGE), brightness, shadows, "Bottom", 90, flicker, role)
