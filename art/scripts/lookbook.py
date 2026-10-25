"""The look rulebook: the few numbers every surface in the game is made to, so the lobby, the war room
and the three maps read as one place. Map surfaces (maps/scanlib.py) and props (modelkit.py) both
take their sizes and their grade from here.

Detail density. A texture gets as many pixels as the eye can use from where a player stands, and no
more: that is what keeps a scene's memory level while surfaces gain detail maps.
Palette. Every photographed scan is regraded to the game's own colours: desaturated, a little cold.
Red is kept for danger and is never a surface's accent.
Wear. Dirt gathers low, in corners and under sills; polish and scuffs sit where hands and feet go;
edges chip; rain and snow show on what they fall on. Wear follows the shape of things, never an even
noise over everything.
"""

import math

STUDS_PER_METRE = 3.5  # a player is 5.2 studs tall

# Pixels per stud, by where a player sees the surface from.
DENSITY = {
    "wall": 64,  # at arm's length: walls, doors, counters
    "floor": 48,  # under the feet, seen from eye height
    "ground": 40,  # open ground
    "road": 56,  # wet roads: the lamps and signs lie mirrored in them
    "ceiling": 32,
    "far": 16,  # roofs, scenery nobody walks up to
    "prop": 48,  # a little under the walls: a prop carries four maps of its own, and a scene's memory is fixed
    # the maps' own props, as sharp as the walls round them (the owner, 2026-10-25: "make every texture in the game
    # more high quality"; the Agency, Campus, Tokyo and war room scenes had the memory for it, the lobby had not)
    "venue": 64,
    "held": 128,  # in the hand, in front of the camera
}
LARGEST = 1024
SMALLEST = 128


def pixels(studs, where):
    """The texture size (a power of two) for a surface `studs` across, seen from `where`."""
    size = 2 ** round(math.log2(studs * DENSITY[where]))
    return int(min(LARGEST, max(SMALLEST, size)))


# The grade every scan gets after its colour is moved onto the surface's own.
SATURATION = 0.85  # of the colour left after grading
COLD = (0.985, 1.0, 1.02)  # red, green, blue gains: a breath of blue
ALBEDO = (0.02, 0.85)  # the darkest and lightest a surface may be (linear), so light still models it
MACRO = 0.07  # how far a surface's tone drifts across one repeat (hides the tiling)
