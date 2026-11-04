"""The city beyond the maps, one building at a time: a block in one of the night facades (maps/facades.py) whose window
grid is fitted to each wall, its lit windows laid exactly over the glass, a cornice, a parapet and, on the nearer ones,
what stands on a roof (the lift room, a water tank, plant). Cheap by design: a wall is one face whatever its windows,
so the detail is in the texture and the triangles go to the outline.

Agency (the view down from the 38th floor), Campus (the blocks round the walls) and Tokyo (the city past the streets)
all build their far city with block().
"""

import math
import random

from maps import buildings, city
from maps import geo2d as g2
from maps.facades import BAY, STYLES, TILE

# Each style's glass in its bay and floor, in studs (from facades.STYLES): where a lit window's glow goes.
WINDOWS = {name: style["glass"] for name, style in STYLES.items()}
# Styles whose glass runs nearly bay to bay: a lit stretch of a floor is one glow across its bays.
RIBBON = {"NightOffice"}
LIT = ("WindowLit", "WindowLit", "WindowCool")


def _face(s, mat, e, u0, u1, y0, y1, depth, uvs):
    """A face on edge e's wall plane from u0 to u1, y0 to y1, pushed out by depth, with uvs given per corner in
    (u0 y0, u1 y0, u1 y1, u0 y1) order (repeats of the texture)."""
    a, b = e.at(u0, depth), e.at(u1, depth)
    pts = [(a[0], y0, a[1]), (b[0], y0, b[1]), (b[0], y1, b[1]), (a[0], y1, a[1])]
    n = city.cross(city.sub(pts[1], pts[0]), city.sub(pts[2], pts[0]))
    if n[0] * e.n[0] + n[2] * e.n[1] < 0:
        pts.reverse()
        uvs = list(reversed(uvs))
    s.polygon(mat, pts, uvs, 1.0)


def _bays(length):
    """How many window bays a wall of this length takes, and how wide each is (near 6 studs)."""
    count = max(1, round(length / BAY))
    return count, length / count


def wall(s, e, style, y0, y1, ground):
    """The wall of edge e from y0 to y1 in a facade style, its bays fitted to its length and its floors to the
    building's floor lines (ground: the height of the building's foot; its first upper floor is FLOOR_GF above).
    Returns (count, width) of its bays."""
    count, width = _bays(e.length)
    # Seen from outside the wall runs right to left along e.t, so the texture runs from b to a.
    span = count * width / (2 * width)  # in repeats (two bays each)
    floor0 = ground + buildings.FLOOR_GF
    v0, v1 = (y0 - floor0) / TILE, (y1 - floor0) / TILE
    _face(s, style, e, 0.0, e.length, y0, y1, 0.0, [(span, v0), (0.0, v0), (0.0, v1), (span, v1)])
    return count, width


def lit_windows(e, style, count, width, levels, rng, lit):
    """The lit windows over the glass of edge e, as [(material, e, u0, u1, y0, y1)]: per floor, runs of lit bays
    (one glow across a run on a ribbon style, one per window otherwise)."""
    g0, g1, y0, y1 = WINDOWS[style]
    k = width / BAY
    # (lit is the share of windows lit. A run goes on to the next bay with chance `go`, so it averages 1 / (1 - go)
    # bays and starts often enough to give that share. On a ribbon style a run is one glow however long, so its runs
    # are long: an office floor lit end to end.)
    go = 0.8 if style in RIBBON else 0.5
    mean = 1.0 / (1.0 - go)
    start = 1.0 / max(1.0, mean / max(lit, 1e-3) - mean)
    out = []
    for level in levels:
        bay = 0
        while bay < count:
            if rng.random() >= start:
                bay += 1
                continue
            run = 1
            while bay + run < count and rng.random() < go:
                run += 1
            mat = rng.choice(LIT)
            # (bay i of the wall is at u = length - (i + 1) * width .. length - i * width: the wall runs b to a)
            if style in RIBBON:
                u0 = e.length - (bay + run) * width + g0 * k
                u1 = e.length - bay * width - (BAY - g1) * k
                pieces = [(u0, u1)]
            else:
                pieces = [(e.length - (i + 1) * width + g0 * k, e.length - (i + 1) * width + g1 * k)
                          for i in range(bay, bay + run)]
            for u0, u1 in pieces:
                out.append((mat, e, u0, u1, level + y0, level + y1))
            bay += run + 1
    return out


def roof_things(s, rng, poly, top, roof_mat, detail):
    """What stands on a roof: a lift room, sometimes a water tank on legs, plant boxes."""
    xs = [p[0] for p in poly]
    zs = [p[1] for p in poly]
    x0, x1, z0, z1 = min(xs), max(xs), min(zs), max(zs)
    if x1 - x0 < 12 or z1 - z0 < 12:
        return
    w, d = rng.uniform(5, 8), rng.uniform(5, 8)
    x, z = rng.uniform(x0 + w / 2 + 2, x1 - w / 2 - 2), rng.uniform(z0 + d / 2 + 2, z1 - d / 2 - 2)
    h = rng.uniform(5, 8)
    s.box("ConcreteDark", (x, top + h / 2, z), (w, h, d), skip=("-y",))
    if roof_mat == "Snow" and detail > 1:
        s.box("Snow", (x, top + h + 0.15, z), (w + 0.2, 0.3, d + 0.2), skip=("-y",))
    if detail > 1 and rng.random() < 0.45:
        tx = x1 - 5.0 if x < (x0 + x1) / 2 else x0 + 5.0
        tz = z1 - 5.0 if z < (z0 + z1) / 2 else z0 + 5.0
        s.box("BlackMetal", (tx, top + 2.0, tz), (5.0, 4.0, 5.0), skip=("-y",))  # the stand
        s.cylinder("DarkMetal", (tx, top + 4.0, tz), 2.8, 5.0, segments=8, caps=(False, True))
    if detail > 1 and rng.random() < 0.6:
        pw, pd = rng.uniform(3, 5), rng.uniform(2, 4)
        px_ = rng.uniform(x0 + pw / 2 + 1, x1 - pw / 2 - 1)
        pz = rng.uniform(z0 + pd / 2 + 1, z1 - pd / 2 - 1)
        s.box("DarkMetal", (px_, top + 1.1, pz), (pw, 2.2, pd), skip=("-y",))


def block(s, poly, floors, rng, *, y=0.0, lit=0.3, style=None, styles=None, detail=1, roof_mat="ConcreteDark",
          most=None, setback=True):
    """A building beyond the map on footprint poly [(x, z)], floors high from y. detail 0: walls, glows and roof
    only (the far skyline); 1: a cornice and a lift room; 2: also a water tank and plant (blocks people look at
    across a street). A tall block (16 floors and more) may step back for its top third. Returns the roof's height."""
    style = style or rng.choice(styles or list(STYLES))
    top = y + buildings.height(floors)
    levels = [y + level for level in buildings.floor_levels(floors)]
    parts = [(poly, y, top, levels)]
    xs, zs = [p[0] for p in poly], [p[1] for p in poly]
    if setback and floors >= 16 and min(max(xs) - min(xs), max(zs) - min(zs)) >= 22 and rng.random() < 0.6:
        inner = buildings.grow(poly, -rng.uniform(3.0, 5.0))
        if abs(g2.area(inner)) > 0.35 * abs(g2.area(poly)):
            cut = y + buildings.height(int(floors * 0.68))
            parts = [(poly, y, cut, [lv for lv in levels if lv < cut - 1]),
                     (inner, cut, top, [lv for lv in levels if lv >= cut - 1])]
    glows = []
    for k, (outline, y0, y1, part_levels) in enumerate(parts):
        last = k == len(parts) - 1
        for e in buildings.edges_of(outline):
            count, width = wall(s, e, style, y0, y1 + (1.4 if last else 0.0), y)
            glows += lit_windows(e, style, count, width, part_levels, rng, lit)
        if not last:
            # The ledge where it steps back.
            ring = g2.convex_pieces(outline)
            for piece in ring:
                city.up_face(s, "ConcreteDark", piece, y1)
        if detail >= 1:
            s.prism("ConcreteDark", buildings.grow(outline, 0.45), y1 + (1.4 if last else 0.0),
                    y1 + (2.1 if last else 0.7), top=last and roof_mat != "Snow")
    # Past `most` glows (the scene's triangles), a fair pick of them: all over the building, not its lowest floors.
    if most is not None and len(glows) > most:
        glows = rng.sample(glows, most)
    for mat, e, u0, u1, g0, g1 in glows:
        e.quad(s, mat, u0, u1, g0, g1, 0.06)
    final = parts[-1][0]
    if detail < 1 or roof_mat == "Snow":
        for piece in g2.convex_pieces(final):
            city.up_face(s, roof_mat, piece, top + (2.1 if detail >= 1 else 1.2))
    if detail >= 1 and roof_mat != "Snow":
        pass  # (the cornice's top is the roof seen from above)
    if detail >= 1:
        roof_things(s, rng, final, top + 2.1, roof_mat, detail)
    return top


def seeded(seed):
    return random.Random(seed)


def distance_to(box, x, z):
    """How far (x, z) is outside a box (x0, z0, x1, z1); 0 inside."""
    x0, z0, x1, z1 = box
    return math.hypot(max(x0 - x, 0.0, x - x1), max(z0 - z, 0.0, z - z1))
