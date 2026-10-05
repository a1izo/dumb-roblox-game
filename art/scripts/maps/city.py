"""City kit for the big map scenes (1000 x 800 studs): ground surfaces that never overlap,
exact floors, streets with sidewalks along bending centre lines, terraces with retaining walls,
stairs and slopes, enterable shop shells and solid city blocks with lit windows.

Everything takes a mesher.Scene first and works in Roblox studs. Polygons are [(x, z)].
Buildings use a local frame: centred on (cx, cz), turned rot degrees (rot 0 faces -Z), the
front is the side rot faces, "u" runs along a wall from its middle.
"""

import math
import random

from maps import geo2d as g2
from maps import kit
from maps.mesher import add, cross, dot, ry, sub

# Faces and floors ---------------------------------------------------------------------------------


def up_face(s, mat, poly, y):
    """A horizontal face looking up over a convex polygon."""
    s.polygon(mat, [(x, y, z) for x, z in g2.cw(poly)])


def down_face(s, mat, poly, y):
    s.polygon(mat, [(x, y, z) for x, z in g2.ccw(poly)])


def vquad(s, mat, p, q, y0, y1, out):
    """A vertical wall face from ground point p to q, between heights y0 and y1, facing out
    (a direction (x, z))."""
    pts = [(p[0], y0, p[1]), (q[0], y0, q[1]), (q[0], y1, q[1]), (p[0], y1, p[1])]
    n = cross(sub(pts[1], pts[0]), sub(pts[2], pts[0]))
    if n[0] * out[0] + n[2] * out[1] < 0:
        pts.reverse()
    s.polygon(mat, pts)


def as_rect(poly, tol=0.02):
    """(cx, cz, w, d, rot) when the polygon is a rectangle, else None."""
    if len(poly) != 4:
        return None
    for i in range(4):
        a, b, c = poly[i], poly[(i + 1) % 4], poly[(i + 2) % 4]
        u = (b[0] - a[0], b[1] - a[1])
        v = (c[0] - b[0], c[1] - b[1])
        lu, lv = math.hypot(*u), math.hypot(*v)
        if lu < 1e-6 or lv < 1e-6 or abs(u[0] * v[0] + u[1] * v[1]) / (lu * lv) > tol:
            return None
    p0, p1, p2 = poly[0], poly[1], poly[2]
    w = math.dist(p0, p1)
    d = math.dist(p1, p2)
    cx = sum(p[0] for p in poly) / 4
    cz = sum(p[1] for p in poly) / 4
    return cx, cz, w, d, g2.rot_of(((p1[0] - p0[0]) / w, (p1[1] - p0[1]) / w))


def floor(s, poly, y, thick=1.0, look=None, query=True):
    """Solid floor under a polygon, its top at y (a box when it is a rectangle, else wedge
    triangles)."""
    for piece in g2.convex_pieces(poly):
        r = as_rect(piece)
        if r:
            cx, cz, w, d, rot = r
            s.collider((cx, y - thick / 2, cz), (w, thick, d), rot, query, look)
            continue
        p = g2.ccw(piece)
        for i in range(1, len(p) - 1):
            s.floor_tri(p[0], p[i], p[i + 1], y, thick, look, query)


# Ground surfaces ------------------------------------------------------------------------------------


class Ground:
    """Collects the ground's faces and writes them so none overlaps another at the same height:
    a face of higher priority cuts the lower ones (roads cut sidewalks, crossings cut roads),
    and between equal priorities the first one added wins. Each piece also becomes a zone."""

    CELL = 64.0

    def __init__(self, s):
        self.s = s
        self.items = []

    def add(self, poly, mat, y=0.0, priority=0, zone="plaza", name=None):
        for piece in g2.convex_pieces(poly):
            if abs(g2.area(piece)) > 0.01:
                self.items.append((priority, len(self.items), g2.ccw(piece), mat, y, zone, name))

    def _cells(self, box):
        c = self.CELL
        for i in range(math.floor(box[0] / c), math.floor(box[2] / c) + 1):
            for j in range(math.floor(box[1] / c), math.floor(box[3] / c) + 1):
                yield (i, j)

    def finish(self):
        grid = {}
        placed = []
        count = 0
        for priority, _, poly, mat, y, zone, name in sorted(self.items, key=lambda it: (-it[0], it[1])):
            box = g2.bbox(poly)
            seen = set()
            pieces = [poly]
            for cell in self._cells(box):
                for index in grid.get(cell, ()):
                    if index in seen:
                        continue
                    seen.add(index)
                    other, oy, obox = placed[index]
                    if abs(oy - y) > 0.3 or not g2.bbox_overlap(box, obox):
                        continue
                    nxt = []
                    for piece in pieces:
                        nxt.extend(g2.subtract(piece, other))
                    pieces = nxt
                    if not pieces:
                        break
                if not pieces:
                    break
            for piece in pieces:
                up_face(self.s, mat, piece, y)
                if zone:
                    self.s.zone(zone, piece, y, name=name)
                count += 1
            index = len(placed)
            placed.append((poly, y, box))
            for cell in self._cells(box):
                grid.setdefault(cell, []).append(index)
        return count


# Streets -------------------------------------------------------------------------------------------


def road(g, points, width, walk=0.0, y=0.0, road_mat="Asphalt", walk_mat="Pavers", name=None, priority=4,
         walk_left=True, walk_right=True):
    """A road along the centre line `points` with sidewalks `walk` wide either side."""
    for q in g2.strip_quads(points, width / 2, -width / 2):
        g.add(q, road_mat, y, priority, "road", name)
    if walk:
        if walk_left:
            for q in g2.strip_quads(points, width / 2 + walk, width / 2):
                g.add(q, walk_mat, y, priority - 2, "sidewalk", name)
        if walk_right:
            for q in g2.strip_quads(points, -width / 2, -width / 2 - walk):
                g.add(q, walk_mat, y, priority - 2, "sidewalk", name)


def path(g, points, width, mat="Pavers", kind="lane", y=0.0, priority=1, name=None):
    """A pedestrian way (lane, alley, arcade...) along a centre line."""
    for q in g2.strip_quads(points, width / 2, -width / 2):
        g.add(q, mat, y, priority, kind, name)


def dashes(s, points, y=0.0, mat="WhiteTrim", dash=6.0, gap=6.0, w=0.4, offset=0.0):
    """Painted dashes along a centre line (offset sideways)."""
    total = g2.polyline_length(points)
    u = gap / 2
    while u + dash < total:
        p, d = g2.point_along(points, u + dash / 2)
        n = g2.normal_left(d)
        c = (p[0] + n[0] * offset, p[1] + n[1] * offset)
        s.box(mat, (c[0], y + 0.06, c[1]), (dash, 0.12, w), g2.rot_of(d), skip=("-y",))
        u += dash + gap


def street_lamps(s, points, offset, spacing=28.0, y=0.0, sides=(1, -1), start=8.0, shadows_every=0,
                 color=(255, 214, 160)):
    """Lamp posts along both kerbs of a road, staggered, each throwing a pool of light on the
    road and the sidewalk (offset: from the centre line to the posts)."""
    total = g2.polyline_length(points)
    placed = []
    for k, side in enumerate(sides):
        u = start + k * spacing / 2
        n_lamp = 0
        while u < total - 4:
            p, d = g2.point_along(points, u)
            n = g2.normal_left(d)
            x, z = p[0] + n[0] * side * offset, p[1] + n[1] * side * offset
            # The lamp's head reaches over the road: rot faces the road (-n * side).
            rot = math.degrees(math.atan2(n[0] * side, n[1] * side))
            s.prop("LampPost", x, z, rot, 1.0, y)
            head = (x - n[0] * side * 1.1, z - n[1] * side * 1.1)
            s.light("spot", (head[0], y + 11.6, head[1]), color, 34, 3.0,
                    bool(shadows_every) and n_lamp % shadows_every == 0, "Bottom", 80)
            s.light("point", (head[0], y + 10.8, head[1]), color, 12, 0.5)
            s.collider((x, y + 6, z), (0.6, 12, 0.6), 0, True, None)
            placed.append((x, z))
            n_lamp += 1
            u += spacing
    return placed


def pole_lamp(s, x, z, y=0.0, h=9.0, color=(255, 200, 140), range_=24.0, brightness=1.3):
    """A cheap lamp on a thin pole (for filling dark back lots)."""
    s.box("DarkMetal", (x, y + h / 2, z), (0.3, h, 0.3), skip=("-y",))
    s.box("BlackMetal", (x, y + h + 0.1, z), (1.2, 0.2, 1.2))
    s.box("NeonWarm", (x, y + h - 0.2, z), (0.8, 0.4, 0.8), skip=("+y",))
    s.light("point", (x, y + h - 0.8, z), color, range_, brightness)
    s.collider((x, y + h / 2, z), (0.5, h, 0.5), 0, True, None)


def wall_lamps(s, points, offset, spacing=18.0, y=0.0, h=8.0, color=(255, 196, 140), range_=20.0,
               brightness=1.1, start=5.0, flicker_every=0):
    """Small lamps on the building fronts along a lane, alternating sides."""
    total = g2.polyline_length(points)
    u = start
    k = 0
    while u < total - 2:
        p, d = g2.point_along(points, u)
        n = g2.normal_left(d)
        side = 1 if k % 2 == 0 else -1
        x, z = p[0] + n[0] * side * offset, p[1] + n[1] * side * offset
        rot = g2.rot_of(d)
        s.box("BlackMetal", (x, y + h + 0.3, z), (0.4, 0.6, 0.4), rot)
        s.box("NeonWarm", (x, y + h - 0.15, z), (0.5, 0.3, 0.5), rot)
        s.light("point", (x - n[0] * side * 0.8, y + h - 0.6, z - n[1] * side * 0.8), color, range_, brightness,
                flicker=bool(flicker_every) and k % flicker_every == flicker_every - 1)
        k += 1
        u += spacing


def stripe(s, points, y=0.0, mat="WhiteTrim", w=0.4, offset=0.0):
    """A continuous painted line along a centre line (offset sideways)."""
    line = g2.offset_polyline(points, offset)
    for i in range(len(line) - 1):
        a, b = line[i], line[i + 1]
        length = math.dist(a, b)
        if length < 0.05:
            continue
        mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
        s.box(mat, (mid[0], y + 0.02, mid[1]), (length, 0.04, w), g2.rot_of(((b[0] - a[0]) / length, (b[1] - a[1]) / length)),
              skip=("-y",))


def zebra(s, centre, direction, width, depth=4.0, y=0.0, stripe=1.0, mat="WhiteTrim"):
    """A zebra crossing across a road: stripes along `direction` (the road), spread across a
    road `width` wide, `depth` deep (along the walking line)."""
    d = direction
    n = g2.normal_left(d)
    count = int(width / (stripe * 2))
    rot = g2.rot_of(n)
    for k in range(count):
        off = -width / 2 + stripe + k * stripe * 2
        c = (centre[0] + d[0] * off, centre[1] + d[1] * off)
        s.box(mat, (c[0], y + 0.02, c[1]), (depth, 0.04, stripe), rot, skip=("-y",))


# Terrain -------------------------------------------------------------------------------------------


def terrace(s, g, poly, y, base=0.0, top_mat="Pavers", wall_mat="Stone", zone="lane", name=None, walls=True,
            priority=1, coping="ConcreteDark"):
    """Raised solid ground over a polygon: top at y, retaining walls down to base."""
    g.add(poly, top_mat, y, priority, zone, name)
    floor(s, poly, y, y - base, wall_mat)
    if walls:
        retaining(s, poly, y, base, wall_mat, coping)


def retaining(s, poly, y, base, wall_mat="Stone", coping="ConcreteDark", edges=None):
    p = g2.ccw(poly)
    n = len(p)
    for i in range(n):
        if edges is not None and i not in edges:
            continue
        a, b = p[i], p[(i + 1) % n]
        dx, dz = b[0] - a[0], b[1] - a[1]
        length = math.hypot(dx, dz)
        if length < 0.05:
            continue
        out = (dz / length, -dx / length)  # right of a->b: outside a counter-clockwise polygon
        vquad(s, wall_mat, a, b, base, y, out)
        mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
        s.box(coping, (mid[0] + out[0] * 0.15, y + 0.12, mid[1] + out[1] * 0.15), (length + 0.3, 0.24, 0.6),
              g2.rot_of((dx / length, dz / length)), skip=("-y",))


GUARD_FROM = 2.0  # how high a flight climbs before its side guards begin


def stairs(s, g, a, b, y0, y1, width, mat="Stone", side_mat="ConcreteDark", step=0.8, name=None, cheeks=True,
           guard=0.0, guard_out=0.15):
    """A flight of steps from a (x, z) at height y0 to b at y1 (either way up), with a smooth
    ramp under the steps for walking and a "stairs" zone. The mass under the steps is solid (no
    walking into the side of a flight); guard: an invisible wall that high along both sides over
    the steps, where handrails or balustrades stand (guard_out: how far out past the steps)."""
    run = math.dist(a, b)
    d = ((b[0] - a[0]) / run, (b[1] - a[1]) / run)
    n = g2.normal_left(d)
    rot = g2.rot_of(n)  # local x across the flight, local z along it
    rise = y1 - y0
    count = max(2, round(abs(rise) / step))
    low = min(y0, y1)
    for i in range(count):
        t0, t1 = i / count, (i + 1) / count
        top = y0 + rise * (t1 if rise > 0 else t0)
        c = (a[0] + d[0] * run * (t0 + t1) / 2, a[1] + d[1] * run * (t0 + t1) / 2)
        h = max(0.2, top - low)
        s.box(mat, (c[0], low + h / 2, c[1]), (width, h, run / count), rot, skip=("-y",),
              mats={"+x": side_mat, "-x": side_mat})
        s.step((c[0], low + h / 2, c[1]), (width, h, run / count), rot, mat)
        # Solid under the ramp, never above it (walking up stays smooth).
        under = min(y0 + rise * t0, y0 + rise * t1) - 0.15 - low
        if under > 0.6:
            s.collider((c[0], low + under / 2, c[1]), (width, under, run / count), rot, False, None)
        # (Not over the first steps: people step onto a flight from its sides there too.)
        if guard > 0 and top - low > GUARD_FROM:
            for side in (1, -1):
                off = width / 2 + guard_out
                p = (c[0] + n[0] * side * off, c[1] + n[1] * side * off)
                s.collider((p[0], top + guard / 2, p[1]), (0.3, guard, run / count + 0.05), rot, False, None)
    s.ramp(a if rise > 0 else b, b if rise > 0 else a, low, max(y0, y1), width, look=mat)
    band = [
        (a[0] + g2.normal_left(d)[0] * width / 2, a[1] + g2.normal_left(d)[1] * width / 2),
        (b[0] + g2.normal_left(d)[0] * width / 2, b[1] + g2.normal_left(d)[1] * width / 2),
        (b[0] - g2.normal_left(d)[0] * width / 2, b[1] - g2.normal_left(d)[1] * width / 2),
        (a[0] - g2.normal_left(d)[0] * width / 2, a[1] - g2.normal_left(d)[1] * width / 2),
    ]
    s.zone("stairs", band, y0, y1, name=name)
    return band


def slope(s, g, a, b, y0, y1, width, mat="Pavers", side_mat="Stone", name=None, zone="lane", sides=True):
    """A sloping lane from a at y0 to b at y1: a tilted face, a ramp under it, and walls under
    its edges down to the lower end's height."""
    run = math.dist(a, b)
    d = ((b[0] - a[0]) / run, (b[1] - a[1]) / run)
    n = g2.normal_left(d)
    hw = width / 2
    pa_l = (a[0] + n[0] * hw, a[1] + n[1] * hw)
    pa_r = (a[0] - n[0] * hw, a[1] - n[1] * hw)
    pb_l = (b[0] + n[0] * hw, b[1] + n[1] * hw)
    pb_r = (b[0] - n[0] * hw, b[1] - n[1] * hw)
    pts = [(pa_r[0], y0, pa_r[1]), (pb_r[0], y1, pb_r[1]), (pb_l[0], y1, pb_l[1]), (pa_l[0], y0, pa_l[1])]
    nrm = cross(sub(pts[1], pts[0]), sub(pts[2], pts[0]))
    if nrm[1] < 0:
        pts.reverse()
    s.polygon(mat, pts)
    lo, hi = (a, b) if y1 >= y0 else (b, a)
    s.ramp(lo, hi, min(y0, y1), max(y0, y1), width, look=mat)
    if sides:
        base = min(y0, y1)
        for p, q, out in ((pa_l, pb_l, n), (pa_r, pb_r, (-n[0], -n[1]))):
            yp, yq = y0, y1
            quad = [(p[0], base, p[1]), (q[0], base, q[1]), (q[0], yq, q[1]), (p[0], yp, p[1])]
            nn = cross(sub(quad[1], quad[0]), sub(quad[2], quad[0]))
            if nn[0] * out[0] + nn[2] * out[1] < 0:
                quad.reverse()
            s.polygon(side_mat, quad)
    s.zone(zone, [pa_l, pb_l, pb_r, pa_r], y0, y1, name=name)


def rail(s, points, y=0.0, h=3.2, mat="BlackMetal", collide=True):
    clean = [points[0]]
    for p in points[1:]:
        if math.dist(p, clean[-1]) > 0.1:
            clean.append(p)
    if len(clean) >= 2:
        kit.railing(s, clean, h=h, mat=mat, base=y, collide=collide)


# Building frames -----------------------------------------------------------------------------------


class Frame:
    """A building's local frame: to_world((lx, lz)) and the world direction of a local one."""

    def __init__(self, cx, cz, rot, y=0.0):
        self.cx, self.cz, self.rot, self.y = cx, cz, rot, y
        self._turn = ry(rot)

    def w(self, lx, lz):
        p = self._turn((lx, 0, lz))
        return (self.cx + p[0], self.cz + p[2])

    def w3(self, lx, ly, lz):
        p = self._turn((lx, 0, lz))
        return (self.cx + p[0], self.y + ly, self.cz + p[2])

    def dir(self, lx, lz):
        p = self._turn((lx, 0, lz))
        return (p[0], p[2])

    def poly(self, x0, z0, x1, z1):
        return [self.w(x0, z0), self.w(x1, z0), self.w(x1, z1), self.w(x0, z1)]


SIDES = {
    # side: (middle (lx, lz) as fractions of (w/2, d/2), outward (lx, lz), which size runs along it)
    "front": ((0, -1), (0, -1), "w"),
    "back": ((0, 1), (0, 1), "w"),
    "right": ((1, 0), (1, 0), "d"),
    "left": ((-1, 0), (-1, 0), "d"),
}


def side_line(f, w, d, side, inset=0.0):
    """(a, b, length, outward) of a side's wall centre line, running so the kit's "n" side of
    the wall is the outside."""
    (mx, mz), (ox, oz), along = SIDES[side]
    hw, hd = w / 2 - inset, d / 2 - inset
    mid = f.w(mx * hw, mz * hd)
    out = f.dir(ox, oz)
    length = (w if along == "w" else d)
    t = (-out[1], out[0])
    a = (mid[0] - t[0] * length / 2, mid[1] - t[1] * length / 2)
    b = (mid[0] + t[0] * length / 2, mid[1] + t[1] * length / 2)
    return a, b, length, out


def openings_for(length, doors, height, base, storefront=False, windows=False, door_top=8.0, sill=3.0,
                 window_top=8.0, glass="Glass"):
    """Openings for kit.wall: doors given as (u from the middle, width); storefront glass fills
    the rest of the wall; windows puts regular windows between the doors instead."""
    ops = []
    spans = []
    for u, width in sorted(doors):
        at = length / 2 + u
        ops.append({"at": at, "w": width, "bottom": base, "top": base + door_top, "kind": "door",
                    "frame": "DarkMetal", "casing": 0.3})
        spans.append((at - width / 2, at + width / 2))
    if storefront or windows:
        cursor = 1.2
        gaps = []
        for s0, s1 in sorted(spans):
            gaps.append((cursor, s0 - 1.0))
            cursor = s1 + 1.0
        gaps.append((cursor, length - 1.2))
        for u0, u1 in gaps:
            if u1 - u0 < 2.4:
                continue
            if storefront:
                ops.append({"at": (u0 + u1) / 2, "w": u1 - u0, "bottom": base + 0.8, "top": base + door_top - 0.4,
                            "kind": "window", "frame": "DarkMetal", "mullions": "DarkMetal",
                            "cols": max(1, round((u1 - u0) / 4)), "rows": 1, "glass": glass, "sill": "DarkMetal",
                            "casing": 0.2})
            else:
                count = max(1, int((u1 - u0) / 5))
                for k in range(count):
                    c = u0 + (u1 - u0) * (k + 0.5) / count
                    ops.append({"at": c, "w": 2.6, "bottom": base + sill, "top": base + window_top, "kind": "window",
                                "frame": "DarkMetal", "cols": 1, "rows": 2, "glass": glass, "sill": "ConcreteDark",
                                "casing": 0.2})
    return ops


def shop(s, cx, cz, w, d, rot, *, y=0.0, h=11.0, outside="PlasterLight", inside="PlasterLight", floor_mat="TileWhite",
         doors=None, storefront=("front",), windows=(), upper=0.0, upper_mat=None, seed=0, light=(255, 226, 190),
         light_range=None, brightness=1.0, lit=0.45, roof=True, name=None, zone=True, ceiling="Ceiling"):
    """An enterable one-room building: walls with doors (doors={side: [(u, width)]}, default
    one in the middle of the front), shop windows on the storefront sides, a floor, a ceiling
    with a roof collider (rain stops and cameras stay inside), lamps, and optionally `upper`
    studs of solid storeys above with lit windows. Returns its Frame."""
    f = Frame(cx, cz, rot, y)
    doors = doors if doors is not None else {"front": [(0, 6)]}
    for side in ("front", "back", "right", "left"):
        a, b, length, out = side_line(f, w, d, side, 0.5)
        ops = openings_for(length, doors.get(side, []), y + h, y, storefront=side in storefront,
                           windows=side in windows)
        kit.wall(s, a, b, y + h, thick=1.0, base=y, core=outside, side_n=outside, side_s=inside, openings=ops,
                 trim_s={"base": "BlackTrim"})
    inner = f.poly(-w / 2 + 1, -d / 2 + 1, w / 2 - 1, d / 2 - 1)
    up_face(s, floor_mat, inner, y + 0.06)
    floor(s, inner, y + 0.06, 0.4, floor_mat)
    down_face(s, ceiling, inner, y + h - 0.05)
    top = y + h + upper
    s.collider((cx, y + h + 0.3, cz), (w - 1, 0.6, d - 1), rot, True, None)
    if upper > 0:
        body_mat = upper_mat or outside
        s.box(body_mat, (cx, y + h + upper / 2, cz), (w, upper, d), rot, skip=("-y",), collide=True)
        rng = random.Random(seed)
        for side in ("front", "back", "right", "left"):
            windows_on(s, f, w, d, side, y + h + 1.0, top - 1.0, rng, lit)
    if roof:
        s.box("ConcreteDark", (cx, top + 0.4, cz), (w + 0.4, 0.8, d + 0.4), rot, skip=("-y",))
    lx = max(1, round((w - 2) / 12))
    lz = max(1, round((d - 2) / 12))
    for i in range(lx):
        for j in range(lz):
            px = -w / 2 + 1 + (w - 2) * (i + 0.5) / lx
            pz = -d / 2 + 1 + (d - 2) * (j + 0.5) / lz
            p = f.w3(px, h - 0.1, pz)
            kit.panel_light(s, p[0], p[1], p[2], 3.0, 1.2, color=light, range_=light_range or max(16, h + 8),
                            brightness=brightness * 1.5, rot=rot)
    if zone:
        s.zone("interior", inner, y, name=name)
    return f


def multi(s, g, cx, cz, w, d, rot, levels, *, y=0.0, floor_h=12.0, outside="PlasterLight", inside="PlasterLight",
          floor_mat="TileWhite", doors=None, storefront=("front",), upper_doors=None, stair_side=1, upper=0.0,
          upper_mat=None, seed=0, lit=0.45, light=(255, 226, 190), brightness=1.0, name=None, names=None,
          ceiling="Ceiling", ground_holes=(), voids=()):
    """An enterable building of `levels` floors joined by a switchback stairwell in its back
    corner (right when stair_side is 1, left when -1): walls with doors on the ground floor
    (doors={side: [(u, width)]}), windows upstairs (upper_doors adds openings on upper floors,
    e.g. onto an outside corridor: {level: {side: [(u, width)]}}), floor slabs with the
    stairwell cut out and a railing round it, lamps on every floor, a roof, and `upper` studs of
    solid storeys above. Returns (Frame, stairwell polygon in local studs)."""
    f = Frame(cx, cz, rot, y)
    doors = doors if doors is not None else {"front": [(0, 6)]}
    upper_doors = upper_doors or {}
    top = y + levels * floor_h
    # The stairwell: two lanes 5 wide along local z, a landing at the back.
    sx = stair_side
    x_out = sx * (w / 2 - 1.0)
    x_mid = sx * (w / 2 - 6.0)
    x_in = sx * (w / 2 - 11.0)
    z_back = d / 2 - 1.0
    z_land = d / 2 - 6.0
    z_front = d / 2 - 18.0
    well = f.poly(min(x_in, x_out), z_front, max(x_in, x_out), z_back)
    lane_up = (x_out + x_mid) / 2
    lane_down = (x_mid + x_in) / 2
    for k in range(levels):
        base = y + k * floor_h
        for side in ("front", "back", "right", "left"):
            a, b, length, out = side_line(f, w, d, side, 0.5)
            if k == 0:
                ops = openings_for(length, doors.get(side, []), base + floor_h, base, storefront=side in storefront,
                                   windows=side not in storefront)
            else:
                ops = openings_for(length, upper_doors.get(k, {}).get(side, []), base + floor_h, base, windows=True,
                                   sill=3.0, window_top=9.0)
            kit.wall(s, a, b, base + floor_h, thick=1.0, base=base, core=outside, side_n=outside, side_s=inside,
                     openings=ops, trim_s={"base": "BlackTrim"})
        inner = f.poly(-w / 2 + 1, -d / 2 + 1, w / 2 - 1, d / 2 - 1)
        void_polys = [f.poly(*v) for v in voids]
        if k == 0:
            for piece in g2.subtract_all([g2.ccw(inner)], [g2.ccw(h) for h in ground_holes]):
                up_face(s, floor_mat, piece, base + 0.06)
                floor(s, piece, base + 0.06, 0.4, floor_mat)
        else:
            pieces = g2.subtract_all([g2.ccw(inner)], [g2.ccw(well)] + [g2.ccw(v) for v in void_polys])
            for piece in pieces:
                up_face(s, floor_mat, piece, base)
                floor(s, piece, base, 1.0, floor_mat)
                down_face(s, ceiling, piece, base - 1.0)
            # Railing round the well on the side away from the flights' ends.
            p0 = f.w(x_in, z_front)
            p1 = f.w(x_in, z_back)
            rail(s, [p0, p1], base, 3.2)
            # Glass balustrades along the long sides of every void (its ends stay open for the
            # stairs or escalators that arrive there).
            for x0, z0, x1, z1 in voids:
                if abs(x1 - x0) >= abs(z1 - z0):
                    pairs = (((x0, z0), (x1, z0)), ((x0, z1), (x1, z1)))
                else:
                    pairs = (((x0, z0), (x0, z1)), ((x1, z0), (x1, z1)))
                for pa, pb in pairs:
                    kit.railing(s, [f.w(*pa), f.w(*pb)], h=3.4, mat="Steel", base=base, glass="Glass")
        if True:
            # Flights from this level up to the next (none from the top floor).
            if k < levels - 1:
                half = floor_h / 2
                a1, b1 = f.w(lane_up, z_front), f.w(lane_up, z_land)
                stairs(s, g, a1, b1, base, base + half, 4.6, "Concrete", name=(names or {}).get(k) or name)
                land = f.poly(min(x_in, x_out), z_land, max(x_in, x_out), z_back)
                up_face(s, "Concrete", land, base + half)
                floor(s, land, base + half, 1.0, "Concrete")
                a2, b2 = f.w(lane_down, z_land), f.w(lane_down, z_front)
                stairs(s, g, a2, b2, base + half, base + floor_h, 4.6, "Concrete", name=(names or {}).get(k) or name)
            elif k > 0:
                # At the top floor the up-lane is an open drop: close it off.
                rail(s, [f.w(x_out, z_front), f.w(x_mid, z_front)], base, 3.2)
        zone_poly = inner if k == 0 else inner
        s.zone("interior", zone_poly, base, name=(names or {}).get(k) or name)
        lx = max(1, round((w - 2) / 14))
        lz = max(1, round((d - 2) / 14))
        for i in range(lx):
            for j in range(lz):
                px = -w / 2 + 1 + (w - 2) * (i + 0.5) / lx
                pz = -d / 2 + 1 + (d - 2) * (j + 0.5) / lz
                p = f.w3(px, k * floor_h + floor_h - 1.1, pz)
                kit.panel_light(s, p[0], p[1], p[2], 3.0, 1.2, color=light, range_=20, brightness=brightness * 1.5, rot=rot)
    inner = f.poly(-w / 2 + 1, -d / 2 + 1, w / 2 - 1, d / 2 - 1)
    down_face(s, ceiling, inner, top - 0.05)
    s.collider((cx, top + 0.3, cz), (w - 1, 0.6, d - 1), rot, True, None)
    if upper > 0:
        s.box(upper_mat or outside, (cx, top + upper / 2, cz), (w, upper, d), rot, skip=("-y",), collide=True)
        rng = random.Random(seed)
        for side in ("front", "back", "right", "left"):
            windows_on(s, f, w, d, side, top + 1.0, top + upper - 1.0, rng, lit)
    s.box("ConcreteDark", (cx, top + upper + 0.4, cz), (w + 0.4, 0.8, d + 0.4), rot, skip=("-y",))
    return f, well


def windows_on(s, f, w, d, side, y0, y1, rng, lit=0.45, floor_h=4.0, bay=3.4, ledges=True):
    """Lit, cool and dark window panes (single faces, cheap) on one side of a solid body."""
    (mx, mz), (ox, oz), along = SIDES[side]
    length = w if along == "w" else d
    mid_l = (mx * w / 2 + ox * 0.03, mz * d / 2 + oz * 0.03)
    t_l = (-oz, ox)
    out = f.dir(ox, oz)
    floors = int((y1 - y0) // floor_h)
    bays = max(1, int(length // bay))
    bw = length / bays
    for k in range(floors):
        yy = y0 + k * floor_h
        if ledges:
            c = f.w3(mid_l[0] + ox * 0.12, 0, mid_l[1] + oz * 0.12)
            s.box("ConcreteDark", (c[0], yy - 0.1, c[2]), (length if along == "w" else 0.3, 0.2,
                                                         0.3 if along == "w" else length), f.rot, skip=("-y",))
        for j in range(bays):
            if rng.random() < 0.12:
                continue
            u = -length / 2 + (j + 0.5) * bw
            r = rng.random()
            mat = "WindowLit" if r < lit else ("WindowCool" if r < lit + 0.12 else "WindowDark")
            lx, lz = mid_l[0] + t_l[0] * u, mid_l[1] + t_l[1] * u
            hw = (bw - 0.9) / 2
            p = f.w(lx - t_l[0] * hw, lz - t_l[1] * hw)
            q = f.w(lx + t_l[0] * hw, lz + t_l[1] * hw)
            vquad(s, mat, p, q, yy + 0.8, yy + 3.2, out)


class Occupancy:
    """Footprints already taken (streets, plazas, buildings), to test new ones against."""

    CELL = 48.0

    def __init__(self):
        self.polys = []
        self.grid = {}

    def _cells(self, box):
        c = self.CELL
        for i in range(math.floor(box[0] / c), math.floor(box[2] / c) + 1):
            for j in range(math.floor(box[1] / c), math.floor(box[3] / c) + 1):
                yield (i, j)

    def add(self, poly):
        for piece in g2.convex_pieces(poly):
            index = len(self.polys)
            box = g2.bbox(piece)
            self.polys.append((piece, box))
            for cell in self._cells(box):
                self.grid.setdefault(cell, []).append(index)

    def hits(self, poly, min_area=0.5):
        box = g2.bbox(poly)
        seen = set()
        for cell in self._cells(box):
            for index in self.grid.get(cell, ()):
                if index in seen:
                    continue
                seen.add(index)
                other, obox = self.polys[index]
                if not g2.bbox_overlap(box, obox):
                    continue
                inter = g2.intersect(poly, other)
                if inter and abs(g2.area(inter)) > min_area:
                    return True
        return False


def frontage(points, offset, depth, rng, widths=(10, 22), gaps=(0.0, 0.0, 0.0, 3.0, 4.0), side=1, start=0.0,
             end=None, occupancy=None, bounds=None):
    """Lots along one side of a street centre line, fronts facing the street: returns
    [(cx, cz, w, d, rot)]. offset is the distance from the centre line to the fronts (half the
    road plus the sidewalk); side 1 is the left of travel (normal_left), -1 the right. Random
    narrow gaps between lots become alleys. Lots that hit `occupancy` are skipped; kept lots
    are added to it."""
    total = g2.polyline_length(points)
    end = total if end is None else end
    u = start
    lots = []
    depth_range = depth if isinstance(depth, tuple) else (depth, depth)
    while u < end - widths[0]:
        w = rng.uniform(*widths)
        depth = rng.uniform(*depth_range)
        if u + w > end:
            w = end - u
        p, d = g2.point_along(points, u + w / 2)
        n = g2.normal_left(d)
        n = (n[0] * side, n[1] * side)
        c = (p[0] + n[0] * (offset + depth / 2), p[1] + n[1] * (offset + depth / 2))
        # The front faces back towards the street: rot facing -n.
        rot = math.degrees(math.atan2(n[0], n[1]))
        poly = g2.rect(c[0], c[1], w, depth, rot)
        ok = True
        if bounds and not all(g2.contains(bounds, q) for q in poly):
            ok = False
        if ok and occupancy is not None and occupancy.hits(poly):
            ok = False
        if ok:
            lots.append((c[0], c[1], w, depth, rot))
            if occupancy is not None:
                occupancy.add(poly)
        u += w + rng.choice(gaps)
    return lots


def grow_lanes(points, offset, rng, occupancy, *, side=1, spacing=(50, 85), widths=(4.5, 8.0), max_len=170.0,
               min_len=24.0, step=4.0, bend=0.45, bounds=None, start=10.0, end=None):
    """Side lanes growing into a block from one side of a street: every `spacing` studs a lane
    heads inwards (a little off square), may turn once part way (a dog-leg), and stops when it
    meets something already there (joining it) or reaches max_len (a dead end). Returns
    [(polyline, width)]; each lane is added to `occupancy` as it is made."""
    total = g2.polyline_length(points)
    end = total - 10.0 if end is None else end
    lanes = []
    u = start + rng.uniform(0, spacing[0] / 2)
    while u < end:
        p, d = g2.point_along(points, u)
        n = g2.normal_left(d)
        n = (n[0] * side, n[1] * side)
        width = rng.uniform(*widths)
        angle = math.radians(rng.uniform(-14, 14))
        c, sn = math.cos(angle), math.sin(angle)
        head = (n[0] * c - n[1] * sn, n[0] * sn + n[1] * c)
        pos = (p[0] + n[0] * (offset + 0.5), p[1] + n[1] * (offset + 0.5))
        line = [pos]
        length = 0.0
        turn_at = rng.uniform(0.3, 0.7) * max_len if rng.random() < bend else None
        joined = False
        while length < max_len:
            if turn_at is not None and length >= turn_at:
                a2 = math.radians(rng.choice([-1, 1]) * rng.uniform(25, 50))
                c2, s2 = math.cos(a2), math.sin(a2)
                head = (head[0] * c2 - head[1] * s2, head[0] * s2 + head[1] * c2)
                line.append(pos)
                turn_at = None
            nxt = (pos[0] + head[0] * step, pos[1] + head[1] * step)
            probe = g2.rect((pos[0] + nxt[0]) / 2 + head[0] * step, (pos[1] + nxt[1]) / 2 + head[1] * step,
                            width + 3, step, g2.rot_of((-head[1], head[0])))
            if bounds is not None and not all(g2.contains(bounds, q) for q in probe):
                break
            if occupancy.hits(probe, 0.3):
                joined = True
                pos = (nxt[0] + head[0] * step, nxt[1] + head[1] * step)
                length += step * 2
                break
            pos = nxt
            length += step
        line.append(pos)
        if length >= min_len:
            clean = [line[0]]
            for q in line[1:]:
                if math.dist(q, clean[-1]) > 1.0:
                    clean.append(q)
            if len(clean) >= 2:
                lanes.append((clean, width, joined))
                for q in g2.strip_quads(clean, width / 2 + 1.0, -width / 2 - 1.0):
                    occupancy.add(q)
        u += rng.uniform(*spacing)
    return lanes


def block(s, cx, cz, w, d, rot, h, *, y=0.0, mat="FacadeTile", seed=0, lit=0.4, faces=("front", "back", "right", "left"),
          ground="shutter", parapet=True, floor_h=4.0, name=None):
    """A solid building nobody enters: a body with lit windows on the given faces, a ground
    floor of shutters ("shutter"), dark shop glass ("shop") or plain wall (None)."""
    f = Frame(cx, cz, rot, y)
    s.box(mat, (cx, y + h / 2, cz), (w, h, d), rot, skip=("-y",), collide=True)
    rng = random.Random(seed)
    for side in faces:
        windows_on(s, f, w, d, side, y + 5.0, y + h - 1.0, rng, lit, floor_h)
        if ground:
            (mx, mz), (ox, oz), along = SIDES[side]
            length = w if along == "w" else d
            t_l = (-oz, ox)
            base_l = (mx * w / 2 + ox * 0.06, mz * d / 2 + oz * 0.06)
            hw = length / 2 - 0.8
            p = f.w(base_l[0] - t_l[0] * hw, base_l[1] - t_l[1] * hw)
            q = f.w(base_l[0] + t_l[0] * hw, base_l[1] + t_l[1] * hw)
            vquad(s, "Shutter" if ground == "shutter" else "GlassDark", p, q, y + 0.2, y + 4.4, f.dir(ox, oz))
    if parapet:
        s.box("ConcreteDark", (cx, y + h + 0.5, cz), (w + 0.4, 1.0, d + 0.4), rot, skip=("-y",))
    s.zone("offlimits", f.poly(-w / 2, -d / 2, w / 2, d / 2), y, name=name)
    return f
