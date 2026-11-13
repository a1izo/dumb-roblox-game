"""Contact darkness: the soft dark where things meet the floor (the owner's graphics plan, 2026-11-13, phase 4; promised
to him on 2026-11-01). Roblox computes no ambient occlusion a script can steer, so a desk on carpet or a wall on a
floor reads as pasted on. Two things are laid on a floor as flat, near-black, mostly clear boxes of the look
"ContactDark", stacked from the widest and faintest to the narrowest and darkest so their edges step into a soft one
(a texture would do it in one, but a texture is an upload the owner has to agree to):

- under each piece of furniture (a desk, table, sofa, cabinet, shelf: its footprint from the prop catalog, grown by
  FURNITURE_GROW), and
- along the foot of each wall, on both sides, as a soft line.

Strength: about a third black under the thing itself, falling to a tenth at the rim, so it is "missed if it went", not
a drawn patch. It changes the venue's meshes, so a venue that uses it goes
up a version and the owner has to import its new FBX (a venue's CONTACT_DARKNESS = True switches it on).
"""

import math

from maps import catalog

LOOK = "ContactDark"
LIFT = 0.04  # over the floor, the first layer; each further one a hair higher
STEP = 0.012
# The layers, from the widest in, each how far past its edge: every one is the same look (one layer is 10% black, see
# matlib), so where they overlap they add up: four on the middle of a desk's footprint are about 34%, one at the rim 10%.
FURNITURE = (0.7, 0.4, 0.2, 0.0)  # past a footprint
WALL = (1.5, 0.9, 0.45)  # out of a wall's face: three at its foot are about 27%
FURNITURE_WORDS = ("Desk", "Table", "Sofa", "Cabinet", "Bookshelf", "Bookcase", "Shelf", "Shelving", "Counter", "Bench",
                   "Locker", "Fridge", "Rack", "Bed", "Cabin")
FLOOR_SLACK = 0.35  # a prop or wall whose foot is this near a level stands on it
FLAT_ONLY = ("+z", "-z", "+x", "-x", "-y")  # only the top face of a layer is drawn
WALL_MIN_HEIGHT = 6.0
WALL_MAX_THICK = 1.6


def looks_like_furniture(key):
    return any(word in key for word in FURNITURE_WORDS)


def under_props(s, levels, keys=None):
    """A stack of layers under each piece of furniture that stands on one of `levels` (the floors' heights). Returns how
    many pieces got one."""
    cat = catalog.load()
    done = 0
    for key, x, y, z, rot, sc, *rest in s.props:
        info = cat.get(key)
        if info is None or (keys is not None and key not in keys) or not looks_like_furniture(key):
            continue
        floor = next((lv for lv in levels if abs(y - lv) <= FLOOR_SLACK), None)
        if floor is None:
            continue
        w, h, d = info["size"]
        w, d = w * sc, d * sc
        if w * d < 1.5 or h * sc < 1.2:
            continue
        for k, grow in enumerate(FURNITURE):
            s.box(LOOK, (x, floor + LIFT + STEP * k, z), (w + 2 * grow, 0.02, d + 2 * grow), rot, skip=FLAT_ONLY)
        done += 1
    return done


def wall_bases(s, levels):
    """A soft line along the foot of each wall (a tall thin collider standing on a level), on both its sides. Returns how
    many walls got one."""
    done = 0
    for cx, cy, cz, sx, sy, sz, rot, _query, look in s.colliders:
        if look == "CurtainGlass" or sy < WALL_MIN_HEIGHT or min(sx, sz) > WALL_MAX_THICK:
            continue
        floor = next((lv for lv in levels if abs((cy - sy / 2) - lv) <= FLOOR_SLACK), None)
        if floor is None:
            continue
        a = math.radians(rot)
        local_x, local_z = (math.cos(a), -math.sin(a)), (math.sin(a), math.cos(a))  # the box's axes in the plan
        if sx <= sz:  # thin in x: the wall runs along its z
            length, thick, across = sz, sx, local_x
        else:
            length, thick, across = sx, sz, local_z
        for k, out in enumerate(WALL):
            size = (out, 0.02, length) if sx <= sz else (length, 0.02, out)
            for side in (1, -1):
                off = side * (thick / 2 + out / 2)
                s.box(LOOK, (cx + across[0] * off, floor + LIFT + STEP * k, cz + across[1] * off), size, rot,
                      skip=FLAT_ONLY)
        done += 1
    return done
