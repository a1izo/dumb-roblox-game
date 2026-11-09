"""Second-pass models for the scene deaths' sets (asked 2026-11-09: "review and improve the models tenfold"): lofted
smooth surfaces in place of boxes and extrusions. A saloon car lofted from sections, wheels turned on their axle,
chiselled rocks cut by planes, ruined buildings with real window openings, floor slabs and broken tops, fuller grass.

Roblox space as parts.py (x right, y up, z backwards; rot degrees about +Y, 0 faces -Z).
"""

import math
import random

from maps import mesher
from maps.venues.scenes import parts


def _sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def _cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def _dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def loft(s, mat, rings, closed=True, centres=None, uv_scale=1.0, smooth=True):
    """A surface through rings of points (each ring the same count), ring after ring. Each face turns away from its
    ring's centre (centres: a point per ring; the ring's own centroid by default). closed: each ring joins its last
    point back to its first."""
    n = len(rings[0])
    if centres is None:
        centres = [tuple(sum(p[k] for p in ring) / n for k in range(3)) for ring in rings]
    verts, faces, uvs = [], [], []
    for ring in rings:
        verts.extend(ring)
    along = [0.0]
    for i in range(1, len(rings)):
        a, b = centres[i - 1], centres[i]
        along.append(along[-1] + math.dist(a, b))
    around = []
    for ring in rings:
        acc = [0.0]
        for j in range(1, n + (1 if closed else 0)):
            acc.append(acc[-1] + math.dist(ring[j - 1], ring[j % n]))
        around.append(acc)
    span = n if closed else n - 1
    for i in range(len(rings) - 1):
        for j in range(span):
            j1 = (j + 1) % n
            quad = [i * n + j, i * n + j1, (i + 1) * n + j1, (i + 1) * n + j]
            uvq = [(around[i][j], along[i]), (around[i][j + 1], along[i]), (around[i + 1][j + 1], along[i + 1]),
                   (around[i + 1][j], along[i + 1])]
            for tri, uvt in (((0, 1, 2), (0, 1, 2)), ((0, 2, 3), (0, 2, 3))):
                ids = [quad[k] for k in tri]
                pts = [verts[k] for k in ids]
                if len({tuple(round(c, 5) for c in p) for p in pts}) < 3:
                    continue
                normal = _cross(_sub(pts[1], pts[0]), _sub(pts[2], pts[0]))
                mid = tuple(sum(p[k] for p in pts) / 3 for k in range(3))
                c = tuple((centres[i][k] + centres[i + 1][k]) / 2 for k in range(3))
                if _dot(normal, _sub(mid, c)) < 0:
                    ids = [ids[0], ids[2], ids[1]]
                    uvt = (uvt[0], uvt[2], uvt[1])
                faces.append(tuple(ids))
                uvs.append([(uvq[k][0] * uv_scale, uvq[k][1] * uv_scale) for k in uvt])
    if smooth:
        s.mesh(mat, verts, faces, uvs)
    else:  # (flat facets, each mapped on the world plane it faces most: no texture stretched round the body)
        for f in faces:
            s.polygon(mat, [verts[k] for k in f])


def turned_ring(axis_point, axis, profile, segments, start=0.0, end=math.tau):
    """Rings for a body turned about `axis` (unit, through axis_point): profile [(radius, offset along the axis)].
    Returns a list of rings (one per profile point), each `segments` points round."""
    ax = axis
    helper = (0, 1, 0) if abs(ax[1]) < 0.9 else (1, 0, 0)
    u = mesher.norm(_cross(helper, ax))
    v = _cross(ax, u)
    rings = []
    for r, off in profile:
        ring = []
        for k in range(segments):
            a = start + (end - start) * k / segments
            ring.append(tuple(axis_point[i] + ax[i] * off + (u[i] * math.cos(a) + v[i] * math.sin(a)) * r
                              for i in range(3)))
        rings.append(ring)
    return rings


# The saloon ---------------------------------------------------------------------------------------------------


def _body_station(z):
    """(half width, bottom, top) of the body's section at z (local; nose at -z)."""
    az = abs(z)
    w = 2.02 - (0.42 * ((az - 3.7) / 1.1) ** 2 if az > 3.7 else 0.0)
    bottom = 0.55 + (0.2 * ((az - 3.9) / 0.9) if az > 3.9 else 0.0)
    if z < 0:  # the bonnet falls toward the nose
        top = 2.06 - 0.12 * max(0.0, (az - 2.3) / 1.9) - (0.42 * ((az - 4.2) / 0.6) ** 1.6 if az > 4.2 else 0.0)
    else:  # the boot lid, then the tail
        top = 2.1 - (0.5 * ((az - 4.25) / 0.55) ** 1.6 if az > 4.25 else 0.0)
    return w, bottom, top


def _body_ring(z):
    w, b, t = _body_station(z)
    half = [(0.0, t + 0.03), (w * 0.55, t), (w - 0.18, t - 0.06), (w - 0.02, t - 0.3), (w + 0.03, (t + b) / 2 + 0.25),
            (w, b + 0.28), (w - 0.12, b + 0.04), (w * 0.5, b)]
    pts = half + [(-x, y) for x, y in reversed(half[1:])]
    return [(x, y, z) for x, y in pts]


def _glass_ring(z):
    """The glasshouse's section at z: the belt at the sides, the roof over (None outside the glasshouse)."""
    if z < -2.35 or z > 2.5:
        return None
    if z < -1.05:  # the windscreen rising
        u = (z + 2.35) / 1.3
        top = 2.1 + 1.22 * math.sin(u * math.pi / 2)
    elif z > 1.25:  # the rear window falling
        u = (2.5 - z) / 1.25
        top = 2.12 + 1.2 * math.sin(u * math.pi / 2)
    else:
        top = 3.32 + 0.04 * math.cos((z - 0.1) / 1.2 * math.pi / 2)
    base = 2.08
    roof_w = 1.38
    return [(1.86, base, z), (1.62, base + (top - base) * 0.62, z), (roof_w, top - 0.04, z), (0.0, top + 0.02, z),
            (-roof_w, top - 0.04, z), (-1.62, base + (top - base) * 0.62, z), (-1.86, base, z)]


def _to_world(p, x, y, z, rot):
    return parts.place(p, x, y, z, rot)


def car(s, x, z, rot, paint="CarBlue", y=0.0):
    """A four-door saloon, nose toward rot (0 faces -Z): a lofted body with a rounded nose and tail, a glasshouse with
    its tumblehome and pillars, round tyres on spoked rims under black arch liners, grille, lamps, plates, mirrors."""
    zs = [-4.85, -4.75, -4.55, -4.25, -3.8, -3.0, -2.3, -1.2, 0.0, 1.2, 2.4, 3.2, 3.9, 4.35, 4.6, 4.78, 4.88]

    def W(p):
        return _to_world(p, x, y, z, rot)

    rings = [[W(p) for p in _body_ring(zz)] for zz in zs]
    centres = [W((0.0, (_body_station(zz)[1] + _body_station(zz)[2]) / 2, zz)) for zz in zs]
    loft(s, paint, rings, closed=True, centres=centres)
    for end, zz in ((0, zs[0]), (-1, zs[-1])):  # the nose and tail closed
        ring = rings[end]
        out = parts.turned((0, 0, -1 if end == 0 else 1), rot)
        c = centres[end]
        for k in range(len(ring)):
            parts.poly(s, paint, [c, ring[k], ring[(k + 1) % len(ring)]], out)
    # the glasshouse and its roof skin
    gz = [-2.35, -2.0, -1.6, -1.25, -1.05, -0.4, 0.4, 1.25, 1.5, 1.9, 2.25, 2.5]
    grings = [[W(p) for p in _glass_ring(zz)] for zz in gz]
    gcentres = [W((0.0, 2.0, zz)) for zz in gz]
    loft(s, "GlassDark", grings, closed=False, centres=gcentres)
    roof = [[W((xx, yy + 0.03, zz)) for (xx, yy, zz) in _glass_ring(zz)[2:5]] for zz in gz[4:8]]
    loft(s, paint, roof, closed=False, centres=[W((0.0, 2.0, zz)) for zz in gz[4:8]])
    # pillars: A along the windscreen's edges, B between the doors, C along the rear window
    for side in (-1, 1):
        a = [W((side * 1.84, 2.1, -2.33)), W((side * 1.5, 2.9, -1.6)), W((side * 1.4, 3.3, -1.05))]
        s.bent_tube(paint, a, [0.09, 0.08, 0.07], segments=6)
        c = [W((side * 1.84, 2.12, 2.48)), W((side * 1.55, 2.95, 1.75)), W((side * 1.4, 3.32, 1.25))]
        s.bent_tube(paint, c, [0.16, 0.13, 0.1], segments=6)
        s.tube(paint, W((side * 1.84, 2.1, 0.15)), W((side * 1.42, 3.33, 0.15)), 0.1, 6)
        s.tube("BlackTrim", W((side * 1.88, 2.08, -2.3)), W((side * 1.88, 2.08, 2.45)), 0.035, 4)
        # door shut lines and handles
        for dz in (-1.9, 0.15, 2.3):
            s.tube("BlackTrim", W((side * 2.05, 0.95, dz)), W((side * 2.06, 2.0, dz)), 0.012, 3)
        for dz in (-0.5, 1.6):
            s.box("Chrome", W((side * 2.07, 1.75, dz)), (0.05, 0.08, 0.35), rot)
        # mirror on its arm
        s.tube("BlackTrim", W((side * 1.85, 2.2, -1.95)), W((side * 2.15, 2.28, -1.9)), 0.04, 4)
        s.box(paint, W((side * 2.3, 2.3, -1.88)), (0.22, 0.24, 0.36), rot)
    # wheels: tyre, rim, five spokes, hub; the arch liner over each
    tyre = [(0.42, -0.3), (0.66, -0.31), (0.74, -0.22), (0.77, -0.08), (0.77, 0.08), (0.74, 0.22), (0.66, 0.31),
            (0.42, 0.3)]
    for side in (-1, 1):
        axis = parts.turned((side * 1.0, 0, 0), rot)
        for wz in (-3.05, 3.05):
            hub = W((side * 1.9, 0.77, wz))
            loft(s, "Tyre", turned_ring(hub, axis, tyre, 20), closed=True, centres=[hub] * len(tyre))
            rim = W((side * 2.2, 0.77, wz))
            face = turned_ring(rim, axis, [(0.42, 0.0), (0.12, 0.02)], 16)
            loft(s, "Chrome", face, closed=True, centres=[W((side * 1.6, 0.77, wz))] * 2)
            for k in range(5):
                a = math.tau * k / 5
                p = turned_ring(rim, axis, [(0.38, 0.01)], 5, start=a, end=a + math.tau)[0][0]
                s.tube("DarkMetal", rim, p, 0.05, 4)
            s.tube("DarkMetal", rim, W((side * 2.24, 0.77, wz)), 0.1, 6)
            arch_out = [W((side * 2.06, 0.77 + math.sin(math.pi * k / 12) * 0.98, wz - math.cos(math.pi * k / 12) * 0.98))
                        for k in range(13)]
            arch_in = [W((side * 2.06, 0.77 + math.sin(math.pi * k / 12) * 0.86, wz - math.cos(math.pi * k / 12) * 0.86))
                       for k in range(13)]
            for k in range(12):
                parts.poly(s, "BlackTrim", [arch_in[k], arch_out[k], arch_out[k + 1], arch_in[k + 1]],
                           parts.turned((side, 0, 0), rot))
    # the front: grille, lamps, plate; the back: lamps, plate; bumpers' rubbing strips
    front, back = parts.turned((0, 0, -1), rot), parts.turned((0, 0, 1), rot)
    zf, zb = -4.88, 4.9
    parts.poly(s, "BlackTrim", [W((-0.85, 1.12, zf)), W((0.85, 1.12, zf)), W((0.8, 1.48, zf)), W((-0.8, 1.48, zf))], front)
    for k in range(4):
        yy = 1.17 + k * 0.085
        s.box("Chrome", W((0.0, yy, zf - 0.01)), (1.6, 0.025, 0.02), rot)
    for side in (-1, 1):  # (set into the nose and tail, not standing off their curve)
        s.box("HeadLamp", W((side * 1.22, 1.42, -4.76)), (0.56, 0.16, 0.08), rot)
        s.box("TailLamp", W((side * 1.2, 1.62, 4.84)), (0.6, 0.26, 0.08), rot)
    for zz, out in ((zf - 0.005, front), (zb + 0.005, back)):
        parts.poly(s, "PaintWhite", [W((-0.45, 0.82, zz)), W((0.45, 0.82, zz)), W((0.45, 1.02, zz)),
                                     W((-0.45, 1.02, zz))], out)
    for side in (-1, 1):
        s.tube("BlackTrim", W((side * 2.06, 1.25, -3.9)), W((side * 2.06, 1.25, 3.9)), 0.05, 4)


# Rock -----------------------------------------------------------------------------------------------------------


def rock(s, mat, centre, radii, seed, rot=0.0, cuts=11, sink=0.25, flat_top=0.0, segs=(14, 9), grain=0.03, strata=0.0):
    """A broken boulder: an ellipsoid chiselled by `cuts` random planes (flat facets meeting at sharp edges, as split
    rock does), a fine grain of noise over it, its foot sunk `sink` of its height. strata: ledges stepped into its
    sides (layered sandstone), flat_top: its top sheared flat."""
    r = random.Random(seed)
    rx, ry_, rz = radii
    planes = []
    for _ in range(cuts):
        n = mesher.norm((r.gauss(0, 1), r.gauss(0, 0.7), r.gauss(0, 1)))
        planes.append((n, r.uniform(0.5, 0.82)))
    if flat_top:
        planes.append(((0.0, 1.0, 0.0), 1 - flat_top))
    nu, nv = segs
    base = sink * ry_ * 2
    grid = []
    for j in range(nv + 1):
        lat = -math.pi / 2 + math.pi * j / nv
        row = []
        for i in range(nu):
            lon = math.tau * i / nu
            d = (math.cos(lat) * math.cos(lon), math.sin(lat), math.cos(lat) * math.sin(lon))
            p = list(d)
            for n, off in planes:  # (the unit sphere's points past a plane pushed back onto it)
                over = _dot(p, n) - off
                if over > 0:
                    p = [p[k] - n[k] * over for k in range(3)]
            g = 1 + grain * math.sin(p[0] * 23 + seed) * math.sin(p[1] * 19 + seed * 0.7) * math.sin(p[2] * 21)
            if strata:
                p[1] = math.floor(p[1] / strata) * strata + (p[1] % strata) * 0.35
            q = parts.turned((p[0] * rx * g, p[1] * ry_ * g, p[2] * rz * g), rot)
            row.append((centre[0] + q[0], centre[1] + q[1] + ry_ - base, centre[2] + q[2]))
        grid.append(row)
    rings = grid
    centres = [(centre[0], centre[1] + ry_ - base, centre[2])] * len(rings)
    loft(s, mat, rings, closed=True, centres=centres, smooth=False)


# Grass ----------------------------------------------------------------------------------------------------------


def grass_clump(s, x, z, y, seed, blades=9, height=(0.35, 0.8), spread=0.3, dry=0.3):
    """A tuft: thin blades in three tapering segments, each arching out from the middle, both sides drawn."""
    r = random.Random(seed)
    for _ in range(blades):
        mat = "GrassBladeDry" if r.random() < dry else "GrassBlade"
        a = r.uniform(0, math.tau)
        d = r.uniform(0, spread)
        bx, bz = x + math.cos(a) * d, z + math.sin(a) * d
        hgt = r.uniform(*height)
        lean = r.uniform(0.15, 0.6) * hgt
        face = a + r.uniform(-0.6, 0.6)
        w = r.uniform(0.045, 0.075)
        side = (math.cos(face + math.pi / 2), math.sin(face + math.pi / 2))
        out = (math.cos(a), math.sin(a))
        pts = []
        for k, (t, wk) in enumerate(((0.0, 1.0), (0.4, 0.85), (0.75, 0.5), (1.0, 0.0))):
            bend = lean * t * t
            cx, cz = bx + out[0] * bend, bz + out[1] * bend
            cy = y - 0.04 + hgt * (t - 0.12 * t * t)
            half = w * wk
            pts.append(((cx - side[0] * half, cy, cz - side[1] * half), (cx + side[0] * half, cy, cz + side[1] * half)))
        n = (math.cos(face), 0, math.sin(face))
        for k in range(3):
            (a0, b0), (a1, b1) = pts[k], pts[k + 1]
            quad = [a0, b0, b1, a1] if k < 2 else [a0, b0, a1]
            for sign in (1, -1):
                parts.poly(s, mat, quad, (n[0] * sign, 0, n[2] * sign), [(0, 0)] * len(quad))


# Ruins ----------------------------------------------------------------------------------------------------------


def ruin(s, x, z, w, d, h, seed, rot=0.0, mat="ConcreteDark", bay=3.6, storey=4.2, thick=0.8, ground=0.0):
    """A bombed-out building: four façades of bays and storeys, each bay a window opening with its reveals, sill and
    lintel; the walls' tops torn away along a slope (one corner fallen most) in ragged steps; floor slabs showing as
    ledges where they met the walls, broken off short inside; rebar standing out of every break; rubble at the foot."""
    r = random.Random(seed)
    fall = r.uniform(0.35, 0.75)  # how much of the height the lowest corner lost
    corner = r.randrange(4)
    floors = max(2, int(h // storey))
    corners = [(-w / 2, -d / 2), (w / 2, -d / 2), (w / 2, d / 2), (-w / 2, d / 2)]

    def P(u, y, v):  # local (along x, up, along z) to world
        return parts.place((u, y, v), x, ground, z, rot)

    def top_at(px, pz):
        # the torn top: lowest at the fallen corner, rising away from it, ragged
        cx, cz = corners[corner]
        dist = math.hypot(px - cx, pz - cz) / math.hypot(w, d)
        t = h * (1 - fall * max(0.0, 1 - dist * 1.6))
        return max(storey * 0.8, t + r.uniform(-0.5, 0.5) * storey)

    for k in range(4):
        (ax, az), (bx, bz) = corners[k], corners[(k + 1) % 4]
        length = math.hypot(bx - ax, bz - az)
        ux, uz = (bx - ax) / length, (bz - az) / length
        nx, nz = uz, -ux  # outward (the corners run clockwise seen from above in local space)
        if (ax + bx) * nx + (az + bz) * nz < 0:
            nx, nz = -nx, -nz
        cols = max(2, int(round(length / bay)))
        cw = length / cols
        tops = []
        for c in range(cols):
            mx, mz = ax + ux * cw * (c + 0.5), az + uz * cw * (c + 0.5)
            tops.append(top_at(mx, mz))

        def Wp(t, y, out):
            return P(ax + ux * t + nx * out, y, az + uz * t + nz * out)

        def face(t0, t1, y0, y1, out, normal_sign):
            n = parts.turned((nx * normal_sign, 0, nz * normal_sign), rot)
            parts.poly(s, mat, [Wp(t0, y0, out), Wp(t1, y0, out), Wp(t1, y1, out), Wp(t0, y1, out)], n,
                       [(t0, y0), (t1, y0), (t1, y1), (t0, y1)])

        def slab(t0, t1, y0, y1):  # a solid piece of wall: both faces
            face(t0, t1, y0, y1, thick / 2, 1)
            face(t0, t1, y0, y1, -thick / 2, -1)

        def cap(t0, t1, y, up):  # a horizontal face across the wall's thickness
            n = parts.turned((0, 1 if up else -1, 0), rot)
            parts.poly(s, mat, [Wp(t0, y, -thick / 2), Wp(t1, y, -thick / 2), Wp(t1, y, thick / 2), Wp(t0, y, thick / 2)], n)

        def jamb(t, y0, y1, toward):  # a vertical face across the thickness, facing along the wall
            n = parts.turned((ux * toward, 0, uz * toward), rot)
            parts.poly(s, mat, [Wp(t, y0, -thick / 2), Wp(t, y1, -thick / 2), Wp(t, y1, thick / 2), Wp(t, y0, thick / 2)], n)

        for c in range(cols):
            t0, t1 = cw * c, cw * (c + 1)
            top = tops[c]
            pier = cw * 0.22
            for f in range(floors):
                y0, y1 = f * storey, (f + 1) * storey
                if y0 >= top:
                    break
                y1c = min(y1, top)
                window = f > 0 or r.random() < 0.5
                if window and y1c - y0 > storey * 0.55:
                    sill, lintel = y0 + storey * 0.32, min(y1c, y0 + storey * 0.82)
                    slab(t0, t0 + pier, y0, y1c)
                    slab(t1 - pier, t1, y0, y1c)
                    slab(t0 + pier, t1 - pier, y0, sill)
                    if lintel < y1c:
                        slab(t0 + pier, t1 - pier, lintel, y1c)
                        cap(t0 + pier, t1 - pier, lintel, False)
                    cap(t0 + pier, t1 - pier, sill, True)
                    jamb(t0 + pier, sill, lintel, 1)
                    jamb(t1 - pier, sill, lintel, -1)
                    # the sill's stone lip
                    s.box("ConcreteDark", Wp((t0 + t1) / 2, sill - 0.08, thick / 2 + 0.12), (cw - 2 * pier + 0.3, 0.16, 0.3),
                          rot + math.degrees(math.atan2(-uz, ux)))
                else:
                    slab(t0, t1, y0, y1c)
            cap(t0, t1, top, True)
            # rebar out of the break
            for _ in range(r.randint(1, 3)):
                t = r.uniform(t0 + 0.2, t1 - 0.2)
                s.tube("BlackMetal", Wp(t, top - 0.4, r.uniform(-0.2, 0.2)),
                       Wp(t + r.uniform(-0.4, 0.4), top + r.uniform(0.5, 1.6), r.uniform(-0.5, 0.5)), 0.045, 4)
        # the steps between columns of different heights, and the wall's two ends
        for c in range(cols + 1):
            left = tops[c - 1] if c > 0 else 0.0
            right = tops[c] if c < cols else 0.0
            if abs(left - right) > 1e-3:
                jamb(cw * c, min(left, right), max(left, right), 1 if right > left else -1)
        # floor slabs: a ledge along the façade at each floor, broken off in places
        for f in range(1, floors):
            y = f * storey
            for c in range(cols):
                if tops[c] > y + 0.4 and r.random() < 0.8:
                    s.box("ConcreteDark", Wp(cw * (c + 0.5), y - 0.2, thick / 2 + 0.18), (cw + 0.02, 0.4, 0.36),
                          rot + math.degrees(math.atan2(-uz, ux)))
    # the floors inside, broken off short of the far walls
    for f in range(1, floors):
        y = f * storey
        reach = r.uniform(0.3, 0.7)
        s.box("ConcreteDark", P(0, y - 0.25, -d / 2 + d * reach / 2), (w - thick, 0.5, d * reach), rot)
    # rubble heaped at the foot of the fallen corner
    cx, cz = corners[corner]
    for k in range(10):
        px, pz = cx * r.uniform(0.6, 1.3), cz * r.uniform(0.6, 1.3)
        q = r.uniform(0.6, 2.0)
        rock(s, "WarRubble" if k % 2 else mat, P(px, 0, pz), (q * 1.4, q * 0.6, q), seed * 31 + k,
             rot=r.uniform(0, 360), cuts=6, sink=0.35, flat_top=0.3, segs=(8, 5))
