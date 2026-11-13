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
    """The lamp of a fitting on a room's ceiling (panel, tube, downlit pendant, an arcade's lamps): a noir pool
    (pool below) from just under it, every map alike since 2026-11-02 (it was a round light that lit the ceiling and
    left the floor dim). range_ is kept for the older callers and no longer used. glow: (size, colour) of the
    fitting's face when the game draws it (see mesher.Scene.light); rot turns that face with the fitting. shadows:
    see pool."""
    pool(s, pos, color, brightness, flicker=flicker, glow=glow, rot=rot, role=role, shadows=shadows)


# A noir ceiling lamp (the owner's look, tuned in a Studio play test at full quality, 2026-11-02): a spot straight down
# throwing a pool on the floor, the ceiling round it left dark. Round lights a dozen studs up gave the floor a sixth of
# their light and lit the ceiling flat instead; with the room's fill turned down (LightingPresets) these pools are the
# light the room has. An 80 degree cone from a 13 stud ceiling makes a pool about 21 studs across.
POOL_ANGLE = 80
# A pendant that lights a room on its own (a spot down from its shade: kit.pendant): its brightness. At 1.0 such
# rooms measured a fifth to a third of rooms lit by pools (art/scripts/maps/room_light.py, the 2026-11-06 sweep);
# every map's lone-pendant rooms use this.
PENDANT_ROOM = 3.5
POOL_RANGE = 28
POOL_GAIN = 8.5  # times the fitting's nominal brightness (checked through the player's own camera, 2026-11-02)


# A pool that casts shadows (the owner's graphics plan, 2026-11-13; seen in a Studio play test at full quality, HQ's
# bullpen, a pool alone on a grey pad): a shadow-casting spot goes DARK within about a stud of the ceiling face above it
# (dark at 0.8 below, lit at 1.1 below; HQ's lamps hang 0.5 to 0.7 under it, which is why the shadows given to them at
# run time "turned the lamp off"), so it hangs SHADOW_DROP lower. A shadowed spot also lights its floor at about a
# third of what the same spot does without shadows (a pool of 8 against one of 24: equal): SceneBuilder builds it
# SHADOW_GAIN times brighter and LightingController takes that back off when the key moves on to another lamp.
SHADOW_DROP = 1.0
SHADOW_GAIN = 3.0


def pool(s, pos, color, brightness, flicker=False, glow=None, rot=0.0, role=None, shadows=False):
    """The lamp of a ceiling fitting as a noir pool: a spot down, POOL_ANGLE wide, clear of its fitting. Its range
    is cut to its own floor at export (stop_pools). shadows: a lamp the game may give shadows (it picks the few nearest
    the camera as its keys, LightingController): hung SHADOW_DROP lower, and never a flickering one (its face is its own
    part, drawn where the lamp is)."""
    if shadows and not flicker:
        pos = (pos[0], pos[1] - SHADOW_DROP, pos[2])
    else:
        shadows = False
    s.light("spot", pos, color, POOL_RANGE, brightness * POOL_GAIN, shadows, "Bottom", POOL_ANGLE, flicker, role, rot,
            glow, True)
    s.lights[-1]["pool"] = True


# A pool's light stops at its own floor (seen in a Studio play test at full quality, 2026-11-06). Lamps cast no
# shadows, so a pool 13 studs up with a 28 stud range went on through its floor into the storey below: Bureau HQ's
# 39F lamps lit 38F's ceiling, blew out its pillars and whiteboards, put a white halo round the security office's
# camera monitors, and stacked a second set of lamps on every point of 38F (the engine drops lights where too many
# overlap). Measured on a test floor, a shorter range barely dims the pool itself (Roblox's falloff is not physical:
# a range of 13 needs 1.7 times the brightness to match 28 at 12 studs, and a lamp 16 up lights its floor more than
# one 12 up). 2.4 gave 38F back the light it had borrowed from 39F but blew out Tokyo's tiled station hall; at 1.7
# every pool keeps its own brightness and only the borrowed light is gone.
POOL_PAST_FLOOR = 1.0  # how far past its floor a pool reaches
POOL_FURNITURE = 7.0  # anything nearer than this under a ceiling lamp is furniture, not its floor
POOL_SHORT = 13.0  # the range the cut gain was chosen at (a lamp 12 studs over its floor)
POOL_CUT_GAIN = 1.7  # brightness times this at POOL_SHORT, less for a smaller cut
POOL_PROBES = ((0.0, 0.0), (3.0, 0.0), (-3.0, 0.0), (0.0, 3.0), (0.0, -3.0))  # where the floor is looked for


def stop_pools(scene):
    """Cuts every ceiling pool's range to its own floor (the lowest drop to an upward face at least POOL_FURNITURE
    down, in the scene's opaque meshes, that two of the POOL_PROBES rays agree on) plus POOL_PAST_FLOOR, and raises
    its brightness for the cut. Pools with no agreed floor within POOL_RANGE are left alone. Needs Blender
    (mathutils); outside it nothing changes."""
    try:
        from mathutils import Vector

        from maps import finders
    except ImportError:
        return 0
    pools = [li for li in scene.lights if li.get("pool") and li["range"] == POOL_RANGE]
    if not pools:
        return 0
    tree, _ = finders.Tris(scene).tree("opaque")
    if tree is None:
        return 0
    down = Vector((0.0, -1.0, 0.0))

    def drop(x, y, z):
        """How far below (x, y, z) the first upward face at least POOL_FURNITURE down is, or None."""
        start = Vector((x, y, z))
        travelled = 0.0
        for _ in range(12):
            hit = tree.ray_cast(start, down, POOL_RANGE - travelled)
            if hit[0] is None:
                return None
            loc, normal, _index, dist = hit
            travelled += dist
            if travelled >= POOL_FURNITURE and normal.y > 0.5:
                return travelled
            start = loc + down * 0.01
            travelled += 0.01
        return None

    cut = 0
    for li in pools:
        x, y, z = li["pos"]
        # Under the lamp and POOL_PROBE either side: a desk under its middle is passed by the outer rays, and a ray
        # down a stairwell or an atrium's edge counts only where another one agrees with it.
        drops = [d for d in (drop(x + dx, y, z + dz) for dx, dz in POOL_PROBES) if d is not None]
        agreed = [d for d in drops if sum(1 for e in drops if abs(e - d) <= 1.0) >= 2]
        if not agreed:
            continue
        floor = max(agreed)
        reach = min(POOL_RANGE, floor + POOL_PAST_FLOOR)
        if reach >= POOL_RANGE:
            continue
        share = min(1.0, (POOL_RANGE - reach) / (POOL_RANGE - POOL_SHORT))
        li["range"] = round(reach, 1)
        li["brightness"] = round(li["brightness"] * (1 + (POOL_CUT_GAIN - 1) * share), 2)
        cut += 1
    return cut


LAMP_GAP = 3.0  # check_v2's: two lit lamps nearer than this are stacked


def unstack(scene, gap=LAMP_GAP):
    """Takes out the lamps that stack on another lit lamp (the owner's rule: one light to a fitting, never two on one
    point): a scene lamp within `gap` of a prop's own lamp (the prop is the visible source), then the weaker of two
    scene lamps. Emergency lamps stay. Returns how many went. Run by export.write_scene_v2 for venues with UNSTACK."""
    from maps import catalog

    cat = catalog.load()
    held = []
    for key, x, y, z, rot, sc, *rest in scene.props:
        if rest and rest[0] == "dark":
            continue
        a = math.radians(rot)
        for li in cat.get(key, {}).get("lights", []):
            lx, ly, lz = li["at"]
            held.append((x + (lx * math.cos(a) + lz * math.sin(a)) * sc, y + ly * sc,
                         z + (-lx * math.sin(a) + lz * math.cos(a)) * sc))
    keep = []
    gone = 0
    for li in scene.lights:
        if li.get("role") != "emergency" and any(math.dist(li["pos"], p) < gap for p in held):
            gone += 1
            continue
        keep.append(li)
    lit = [li for li in keep if li.get("role") != "emergency"]
    drop = set()
    for i, a in enumerate(lit):
        for b in lit[i + 1:]:
            if id(a) in drop or id(b) in drop or math.dist(a["pos"], b["pos"]) >= gap:
                continue
            drop.add(id(a if a["brightness"] * a["range"] < b["brightness"] * b["range"] else b))
    scene.lights[:] = [li for li in keep if id(li) not in drop]
    return gone + len(drop)


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


# What a big lit sign gives the street (the owner's graphics plan, 2026-11-13: signs, screens and windows glowed and lit
# nothing, so the glow looked painted on). One spot out of each large coloured sign's face, in its colour; the walls and
# the ground near a pink sign take a pink tint that dies away within about 20 studs. Plain white and black signs give
# none (a tint is the point), nor do small ones; two sign lights never stand within SIGN_GLOW_APART of each other
# (the venue's lamp budget, check_v2 "lamps"); signs above SIGN_GLOW_TOP only light the sky and the buildings across.
SIGN_GLOW_TOP = 20.0
SIGN_GLOW_APART = 9.0
SIGN_GLOW_SATURATION = 90  # the widest gap between a colour's channels below which it is "white"
_SIGN_GLOWS = {}


def sign_glow(s, pos, rot, color, area):
    """The light of a lit sign of `area` square studs at pos that faces rot (the rot its board was given), in `color`
    (the sign's glow colour): a spot 0.9 out of its face, range 14 to 19 and brightness 0.6 to 1.2 by size. Returns
    whether one was added."""
    if area < 8.0 or pos[1] > SIGN_GLOW_TOP or max(color) - min(color) < SIGN_GLOW_SATURATION:
        return False
    taken = _SIGN_GLOWS.setdefault(id(s), [])
    out = (-math.sin(math.radians(rot)), -math.cos(math.radians(rot)))
    at = (pos[0] + out[0] * 0.9, pos[1], pos[2] + out[1] * 0.9)
    if any(math.dist(at, other) < SIGN_GLOW_APART for other in taken):
        return False
    taken.append(at)
    facade(s, at, rot, color, 14.0 + min(5.0, area / 12.0), max(0.6, min(1.2, 0.5 + area / 60.0)))
    return True


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
