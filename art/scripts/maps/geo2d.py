"""Plane geometry on the ground (x, z) for the big map scenes: polylines, convex polygons,
clipping and cutting, and covering a polygon with rotated rectangles (the colliders).

Pure Python (no bpy), so the checks can use it too. Points are (x, z) tuples. "Convex" pieces
are the working unit: streets, plazas and blocks are made of them, and a surface of lower
priority is cut by the ones above it so no two ground faces ever overlap (no flicker).
"""

import math

EPS = 1e-6


# Basics -----------------------------------------------------------------------------------------


def area(poly):
    """Signed area (shoelace on x, z): positive when counter-clockwise in the math plane."""
    total = 0.0
    n = len(poly)
    for i in range(n):
        x0, z0 = poly[i]
        x1, z1 = poly[(i + 1) % n]
        total += x0 * z1 - x1 * z0
    return total / 2


def ccw(poly):
    return list(poly) if area(poly) > 0 else list(reversed(poly))


def cw(poly):
    return list(poly) if area(poly) < 0 else list(reversed(poly))


def centroid(poly):
    a = area(poly)
    if abs(a) < EPS:
        xs = [p[0] for p in poly]
        zs = [p[1] for p in poly]
        return (sum(xs) / len(xs), sum(zs) / len(zs))
    cx = cz = 0.0
    n = len(poly)
    for i in range(n):
        x0, z0 = poly[i]
        x1, z1 = poly[(i + 1) % n]
        f = x0 * z1 - x1 * z0
        cx += (x0 + x1) * f
        cz += (z0 + z1) * f
    return (cx / (6 * a), cz / (6 * a))


def bbox(poly):
    xs = [p[0] for p in poly]
    zs = [p[1] for p in poly]
    return (min(xs), min(zs), max(xs), max(zs))


def bbox_overlap(a, b, pad=0.0):
    return a[0] - pad <= b[2] and b[0] - pad <= a[2] and a[1] - pad <= b[3] and b[1] - pad <= a[3]


def contains(poly, p):
    """Point in polygon (even-odd), any winding."""
    x, z = p
    inside = False
    n = len(poly)
    j = n - 1
    for i in range(n):
        xi, zi = poly[i]
        xj, zj = poly[j]
        if (zi > z) != (zj > z):
            t = (z - zi) / (zj - zi)
            if x < xi + t * (xj - xi):
                inside = not inside
        j = i
    return inside


def dist_point_segment(p, a, b):
    ax, az = a
    bx, bz = b
    dx, dz = bx - ax, bz - az
    length2 = dx * dx + dz * dz
    if length2 < EPS:
        return math.hypot(p[0] - ax, p[1] - az)
    t = max(0.0, min(1.0, ((p[0] - ax) * dx + (p[1] - az) * dz) / length2))
    return math.hypot(p[0] - (ax + t * dx), p[1] - (az + t * dz))


def dist_to_poly_edge(poly, p):
    n = len(poly)
    return min(dist_point_segment(p, poly[i], poly[(i + 1) % n]) for i in range(n))


def lerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def rect(cx, cz, w, d, rot=0.0):
    """The corners of a w x d rectangle centred on (cx, cz), turned rot degrees about +Y (the
    Roblox convention: rot 0 faces -Z; x' = x cos + z sin, z' = -x sin + z cos)."""
    a = math.radians(rot)
    c, s = math.cos(a), math.sin(a)
    out = []
    for lx, lz in ((-w / 2, -d / 2), (w / 2, -d / 2), (w / 2, d / 2), (-w / 2, d / 2)):
        out.append((cx + lx * c + lz * s, cz - lx * s + lz * c))
    return out


def rot_of(direction):
    """The rot (degrees) whose local +X points along direction (dx, dz)."""
    dx, dz = direction
    return math.degrees(math.atan2(-dz, dx))


def local_axes(rot):
    """World (x, z) of a rotated frame's local +X and +Z."""
    a = math.radians(rot)
    c, s = math.cos(a), math.sin(a)
    return (c, -s), (s, c)


# Polylines ---------------------------------------------------------------------------------------


def polyline_length(points):
    return sum(math.dist(points[i], points[i + 1]) for i in range(len(points) - 1))


def point_along(points, u):
    """The point u studs along a polyline, and the unit direction there."""
    for i in range(len(points) - 1):
        a, b = points[i], points[i + 1]
        seg = math.dist(a, b)
        if u <= seg or i == len(points) - 2:
            t = 0.0 if seg < EPS else max(0.0, min(1.0, u / seg))
            d = ((b[0] - a[0]) / seg, (b[1] - a[1]) / seg) if seg > EPS else (1.0, 0.0)
            return lerp(a, b, t), d
        u -= seg
    return points[-1], (1.0, 0.0)


def normal_left(d):
    """90 degrees to the left of direction d seen from above with -z up (the kit's "n" side)."""
    return (d[1], -d[0])


def offset_polyline(points, dist, miter_limit=4.0):
    """The polyline moved sideways by dist (positive to the left of travel, as normal_left),
    with mitred corners."""
    n = len(points)
    dirs = []
    for i in range(n - 1):
        a, b = points[i], points[i + 1]
        seg = math.dist(a, b)
        dirs.append(((b[0] - a[0]) / seg, (b[1] - a[1]) / seg))
    out = []
    for i in range(n):
        if i == 0:
            nx, nz = normal_left(dirs[0])
            out.append((points[0][0] + nx * dist, points[0][1] + nz * dist))
        elif i == n - 1:
            nx, nz = normal_left(dirs[-1])
            out.append((points[-1][0] + nx * dist, points[-1][1] + nz * dist))
        else:
            n0 = normal_left(dirs[i - 1])
            n1 = normal_left(dirs[i])
            mx, mz = n0[0] + n1[0], n0[1] + n1[1]
            ml = math.hypot(mx, mz)
            if ml < EPS:
                mx, mz, scale = n0[0], n0[1], 1.0
            else:
                mx, mz = mx / ml, mz / ml
                cos_half = mx * n0[0] + mz * n0[1]
                scale = min(miter_limit, 1.0 / max(cos_half, 1e-3))
            out.append((points[i][0] + mx * dist * scale, points[i][1] + mz * dist * scale))
    return out


def strip_quads(points, left, right):
    """Convex quads covering the band between offsets `right` and `left` (left > right) of a
    polyline, one per segment plus a wedge at each bend so the band has no gaps."""
    lo = offset_polyline(points, left)
    ro = offset_polyline(points, right)
    quads = []
    for i in range(len(points) - 1):
        q = [ro[i], ro[i + 1], lo[i + 1], lo[i]]
        quads.append(q)
    return [q for q in quads if abs(area(q)) > EPS]


def segment_hit(a, b, c, d):
    """Where segment a-b crosses segment c-d, or None."""
    r = (b[0] - a[0], b[1] - a[1])
    s = (d[0] - c[0], d[1] - c[1])
    den = r[0] * s[1] - r[1] * s[0]
    if abs(den) < EPS:
        return None
    t = ((c[0] - a[0]) * s[1] - (c[1] - a[1]) * s[0]) / den
    u = ((c[0] - a[0]) * r[1] - (c[1] - a[1]) * r[0]) / den
    if 0 <= t <= 1 and 0 <= u <= 1:
        return (a[0] + r[0] * t, a[1] + r[1] * t)
    return None


def polyline_hits(p, q):
    """Every point where polyline p crosses polyline q."""
    out = []
    for i in range(len(p) - 1):
        for j in range(len(q) - 1):
            hit = segment_hit(p[i], p[i + 1], q[j], q[j + 1])
            if hit:
                out.append(hit)
    return out


def split_polyline(points, cuts):
    """The polyline with gaps: cuts are ((x, z), width) near it. Returns the pieces left."""
    total = polyline_length(points)
    intervals = []
    for (cx, cz), w in cuts:
        # The nearest distance along the line to the cut's point.
        best, best_d, u = None, 1e9, 0.0
        for i in range(len(points) - 1):
            a, b = points[i], points[i + 1]
            seg = math.dist(a, b)
            if seg < EPS:
                continue
            t = max(0.0, min(1.0, ((cx - a[0]) * (b[0] - a[0]) + (cz - a[1]) * (b[1] - a[1])) / (seg * seg)))
            p = lerp(a, b, t)
            dd = math.dist(p, (cx, cz))
            if dd < best_d:
                best, best_d = u + t * seg, dd
            u += seg
        if best is not None and best_d < 6.0:
            intervals.append((best - w / 2, best + w / 2))
    pieces, cursor = [], 0.0
    for u0, u1 in sorted(intervals):
        if u0 > cursor + 0.5:
            pieces.append(sub_polyline(points, cursor, u0))
        cursor = max(cursor, u1)
    if cursor < total - 0.5:
        pieces.append(sub_polyline(points, cursor, total))
    return pieces


def sub_polyline(points, u0, u1):
    out = [point_along(points, u0)[0]]
    u = 0.0
    for i in range(len(points) - 1):
        seg = math.dist(points[i], points[i + 1])
        if u0 < u + seg < u1:
            out.append(points[i + 1])
        u += seg
    out.append(point_along(points, u1)[0])
    return out


def resample(points, step):
    """Points every `step` studs along a polyline (ends included)."""
    total = polyline_length(points)
    count = max(1, round(total / step))
    return [point_along(points, total * k / count)[0] for k in range(count + 1)]


def smooth_curve(control, step=8.0, tension=0.5):
    """A Catmull-Rom curve through the control points, sampled about every `step` studs."""
    pts = [control[0]] + list(control) + [control[-1]]
    out = []
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[i + 1], pts[i + 2]
        seg = math.dist(p1, p2)
        count = max(1, round(seg / step))
        for k in range(count):
            t = k / count
            t2, t3 = t * t, t * t * t
            out.append(tuple(
                0.5 * ((2 * p1[j]) + (-p0[j] + p2[j]) * t * (1 + (tension - 0.5))
                       + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t2
                       + (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t3)
                for j in range(2)))
    out.append(control[-1])
    return out


# Convex clipping ---------------------------------------------------------------------------------


def _side(a, b, p):
    """> 0 when p is left of a->b (counter-clockwise in the math plane)."""
    return (b[0] - a[0]) * (p[1] - a[1]) - (b[1] - a[1]) * (p[0] - a[0])


def clip_halfplane(poly, a, b, keep_left=True):
    """The part of poly on the left (or right) of the line a->b."""
    out = []
    n = len(poly)
    if n == 0:
        return out
    sign = 1 if keep_left else -1
    for i in range(n):
        p = poly[i]
        q = poly[(i + 1) % n]
        sp = _side(a, b, p) * sign
        sq = _side(a, b, q) * sign
        if sp >= -EPS:
            out.append(p)
        if (sp > EPS and sq < -EPS) or (sp < -EPS and sq > EPS):
            t = sp / (sp - sq)
            out.append(lerp(p, q, t))
    return _clean(out)


def _clean(poly):
    out = []
    for p in poly:
        if not out or math.dist(out[-1], p) > 1e-5:
            out.append(p)
    if len(out) > 1 and math.dist(out[0], out[-1]) <= 1e-5:
        out.pop()
    return out if len(out) >= 3 and abs(area(out)) > 1e-4 else []


def intersect(subject, clip):
    """subject (convex or not) clipped to the convex polygon clip."""
    clip = ccw(clip)
    out = list(subject)
    n = len(clip)
    for i in range(n):
        out = clip_halfplane(out, clip[i], clip[(i + 1) % n], True)
        if not out:
            return []
    return out


def subtract(a, b):
    """a - b for convex a and convex b: a list of convex pieces."""
    if not bbox_overlap(bbox(a), bbox(b)):
        return [a]
    if not intersect(a, b):
        return [a]
    b = ccw(b)
    pieces = []
    rest = list(a)
    n = len(b)
    for i in range(n):
        p, q = b[i], b[(i + 1) % n]
        outside = clip_halfplane(rest, p, q, False)
        if outside:
            pieces.append(outside)
        rest = clip_halfplane(rest, p, q, True)
        if not rest:
            break
    return pieces


def subtract_all(pieces, holes):
    """Every convex piece minus every convex hole."""
    out = list(pieces)
    for hole in holes:
        hb = bbox(hole)
        nxt = []
        for piece in out:
            if bbox_overlap(bbox(piece), hb):
                nxt.extend(subtract(piece, hole))
            else:
                nxt.append(piece)
        out = nxt
    return out


def convex_hull(points):
    pts = sorted(set(points))
    if len(pts) < 3:
        return pts

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])

    lower, upper = [], []
    for p in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    for p in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    return lower[:-1] + upper[:-1]


def is_convex(poly):
    n = len(poly)
    sign = 0
    for i in range(n):
        s = _side(poly[i], poly[(i + 1) % n], poly[(i + 2) % n])
        if abs(s) < EPS:
            continue
        if sign == 0:
            sign = 1 if s > 0 else -1
        elif (s > 0) != (sign > 0):
            return False
    return True


def triangulate(poly):
    """Ear clipping for a simple polygon; returns triangles (counter-clockwise)."""
    pts = ccw(poly)
    idx = list(range(len(pts)))
    tris = []
    guard = 0
    while len(idx) > 3 and guard < 10000:
        guard += 1
        n = len(idx)
        for k in range(n):
            i0, i1, i2 = idx[(k - 1) % n], idx[k], idx[(k + 1) % n]
            a, b, c = pts[i0], pts[i1], pts[i2]
            if _side(a, b, c) <= EPS:
                continue
            if any(_inside_tri(pts[j], a, b, c) for j in idx if j not in (i0, i1, i2)):
                continue
            tris.append([a, b, c])
            idx.pop(k)
            break
        else:
            break
    if len(idx) == 3:
        tris.append([pts[i] for i in idx])
    return tris


def _inside_tri(p, a, b, c):
    return _side(a, b, p) > EPS and _side(b, c, p) > EPS and _side(c, a, p) > EPS


def convex_pieces(poly):
    """A simple polygon as convex pieces (itself when already convex)."""
    if is_convex(poly):
        return [ccw(poly)]
    return triangulate(poly)


# Covering with rectangles (colliders) ------------------------------------------------------------


def cover(poly, step=6.0, mode="outer", max_len=512.0):
    """Rotated rectangles (cx, cz, w, d, rot) covering a convex polygon: strips `step` wide
    across its longest edge. mode "outer" may stick out by up to step * tan(edge slant) along
    slanted edges (use it where the neighbour is floor at the same height); "inner" stays
    inside (small gaps along slanted edges, for floors that end at a drop)."""
    poly = ccw(poly)
    n = len(poly)
    best = max(range(n), key=lambda i: math.dist(poly[i], poly[(i + 1) % n]))
    a, b = poly[best], poly[(best + 1) % n]
    length = math.dist(a, b)
    ux, uz = (b[0] - a[0]) / length, (b[1] - a[1]) / length
    vx, vz = -uz, ux  # left of a->b: into the polygon (counter-clockwise)

    def to_uv(p):
        dx, dz = p[0] - a[0], p[1] - a[1]
        return (dx * ux + dz * uz, dx * vx + dz * vz)

    uv = [to_uv(p) for p in poly]
    vmin = min(v for _, v in uv)
    vmax = max(v for _, v in uv)
    rects = []
    v = vmin
    while v < vmax - 1e-3:
        v1 = min(vmax, v + step)
        spans = []
        for vv in (v + 1e-4, (v + v1) / 2, v1 - 1e-4):
            span = _span_at(uv, vv)
            if span:
                spans.append(span)
        if spans:
            if mode == "inner":
                u0 = max(s[0] for s in spans)
                u1 = min(s[1] for s in spans)
            else:
                u0 = min(s[0] for s in spans)
                u1 = max(s[1] for s in spans)
            while u1 - u0 > 0.05:
                seg_end = min(u1, u0 + max_len)
                cu, cv = (u0 + seg_end) / 2, (v + v1) / 2
                cx = a[0] + ux * cu + vx * cv
                cz = a[1] + uz * cu + vz * cv
                rects.append((cx, cz, seg_end - u0, v1 - v, rot_of((ux, uz))))
                u0 = seg_end
        v = v1
    return rects


def _span_at(uv, v):
    xs = []
    n = len(uv)
    for i in range(n):
        (u0, v0), (u1, v1) = uv[i], uv[(i + 1) % n]
        if (v0 - v) * (v1 - v) <= 0 and abs(v1 - v0) > EPS:
            t = (v - v0) / (v1 - v0)
            xs.append(u0 + (u1 - u0) * t)
    if len(xs) < 2:
        return None
    return (min(xs), max(xs))
