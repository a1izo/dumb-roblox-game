"""Modelling helpers for the scene deaths' sets: terrain, rocks, grass, bare trees, headstones, extrusions, cars.

All in Roblox space (x right, y up, z backwards), rot in degrees about +Y as mesher.ry (0 faces -Z). Faces are turned
to face the way they should by poly() (Newell's normal against an outward hint), so no helper has to get its winding
right by hand.
"""

import math
import random

from mathutils.geometry import tessellate_polygon

from maps import mesher


def _newell(pts):
    nx = ny = nz = 0.0
    for i, (x0, y0, z0) in enumerate(pts):
        x1, y1, z1 = pts[(i + 1) % len(pts)]
        nx += (y0 - y1) * (z0 + z1)
        ny += (z0 - z1) * (x0 + x1)
        nz += (x0 - x1) * (y0 + y1)
    return (nx, ny, nz)


def poly(s, mat, pts, outward, uvs=None):
    """A face turned so its front looks along `outward` (a direction)."""
    n = _newell(pts)
    if n[0] * outward[0] + n[1] * outward[1] + n[2] * outward[2] < 0:
        pts = list(reversed(pts))
        if uvs is not None:
            uvs = list(reversed(uvs))
    s.polygon(mat, pts, uvs)


def place(p, x, y, z, rot):
    """A local point turned by rot about +Y and moved to (x, y, z)."""
    q = mesher.ry(rot)(p)
    return (q[0] + x, q[1] + y, q[2] + z)


def turned(v, rot):
    return mesher.ry(rot)(v)


# Ground -------------------------------------------------------------------------------------------------------------


def heightfield(s, mat, x0, z0, x1, z1, step, h, tile=64.0, skirt=1.5):
    """Ground over x0..x1, z0..z1 at height h(x, z), cut into tiles of `tile` studs (one mesh piece each, shaded as one
    across their joins), with a skirt hanging under each tile's edge so no crack shows between tiles of different
    steps. step: a number, or a function of (x, z) giving the step of the tile centred there."""
    tx = x0
    while tx < x1 - 1e-6:
        tz = z0
        tw = min(tile, x1 - tx)
        while tz < z1 - 1e-6:
            td = min(tile, z1 - tz)
            st = step(tx + tw / 2, tz + td / 2) if callable(step) else step
            nx, nz = max(1, round(tw / st)), max(1, round(td / st))
            verts, normals, faces, uvs = [], [], [], []
            for i in range(nx + 1):
                for j in range(nz + 1):
                    x, z = tx + tw * i / nx, tz + td * j / nz
                    y = h(x, z)
                    e = 0.5
                    gx = (h(x + e, z) - h(x - e, z)) / (2 * e)
                    gz = (h(x, z + e) - h(x, z - e)) / (2 * e)
                    m = math.sqrt(gx * gx + 1 + gz * gz)
                    verts.append((x, y, z))
                    normals.append((-gx / m, 1 / m, -gz / m))

            def at(i, j):
                return i * (nz + 1) + j

            for i in range(nx):
                for j in range(nz):
                    a, b, c, d = at(i, j), at(i, j + 1), at(i + 1, j), at(i + 1, j + 1)
                    for f in ((a, b, c), (c, b, d)):
                        faces.append(f)
                        uvs.append([(verts[k][0], verts[k][2]) for k in f])
            s.mesh(mat, verts, faces, uvs, normals, ground=True)
            # skirts: each edge of the tile, hanging down
            edges = (
                [(tx + tw * i / nx, tz) for i in range(nx + 1)],
                [(tx + tw * i / nx, tz + td) for i in range(nx + 1)],
                [(tx, tz + td * j / nz) for j in range(nz + 1)],
                [(tx + tw, tz + td * j / nz) for j in range(nz + 1)],
            )
            outs = ((0, 0, -1), (0, 0, 1), (-1, 0, 0), (1, 0, 0))
            for line, out in zip(edges, outs):
                for (ax, az), (bx, bz) in zip(line, line[1:]):
                    ya, yb = h(ax, az), h(bx, bz)
                    pts = [(ax, ya, az), (bx, yb, bz), (bx, yb - skirt, bz), (ax, ya - skirt, az)]
                    poly(s, mat, pts, out)
                    poly(s, mat, pts, (-out[0], -out[1], -out[2]))
            tz += td
        tx += tw


def noise2(x, z, seed=0, octaves=4, scale=40.0):
    """Smooth value in about -1..1: a sum of waves at random angles (no lattice, so no grid shows)."""
    r = random.Random(seed)
    total, amp, norm = 0.0, 1.0, 0.0
    f = 1.0 / scale
    for _ in range(octaves):
        for _ in range(3):
            a = r.uniform(0, math.tau)
            ph = r.uniform(0, math.tau)
            total += amp * math.sin((x * math.cos(a) + z * math.sin(a)) * f * math.tau + ph)
            norm += amp
        amp *= 0.5
        f *= 2.03
    return total / norm * 1.7


# Rocks ----------------------------------------------------------------------------------------------------------


def rock(s, mat, centre, radii, seed, rot=0.0, rough=0.22, segs=(12, 8), sink=0.25, flat_top=0.0):
    """A boulder: a lumpy ellipsoid (radii x, y, z) sunk into the ground by `sink` of its height, turned by rot.
    flat_top cuts its top flat (a slab, a ridge's shelf)."""
    r = random.Random(seed)
    dirs = [(r.uniform(-1, 1), r.uniform(-1, 1), r.uniform(-1, 1)) for _ in range(7)]
    phases = [r.uniform(0, math.tau) for _ in dirs]
    freqs = [r.uniform(1.4, 3.6) for _ in dirs]
    nu, nv = segs
    cx, cy, cz = centre
    rx, ry_, rz = radii
    grid = []
    for j in range(nv + 1):
        v = j / nv
        lat = -math.pi / 2 + math.pi * v
        row = []
        for i in range(nu):
            lon = math.tau * i / nu
            d = (math.cos(lat) * math.cos(lon), math.sin(lat), math.cos(lat) * math.sin(lon))
            k = 1.0
            for (a, b, c), ph, fr in zip(dirs, phases, freqs):
                k += rough * math.sin((d[0] * a + d[1] * b + d[2] * c) * fr * 2 + ph) / len(dirs) * 2.2
            # (facets: a little of each point pulled to its plane, so it reads as broken rock, not dough)
            k = max(0.55, k)
            y = d[1] * ry_ * k
            if flat_top and y > ry_ * (1 - flat_top):
                y = ry_ * (1 - flat_top) + (y - ry_ * (1 - flat_top)) * 0.15
            p = (d[0] * rx * k, y, d[2] * rz * k)
            p = turned(p, rot)
            row.append((cx + p[0], cy + p[1] - sink * ry_ * 2 + ry_, cz + p[2]))
        grid.append(row)
    centre_pt = (cx, cy + ry_ - sink * ry_ * 2, cz)
    verts, faces, uvs = [], [], []
    for row in grid:
        verts.extend(row)

    def vid(j, i):
        return j * nu + (i % nu)

    for j in range(nv):
        for i in range(nu):
            quad = [vid(j, i), vid(j, i + 1), vid(j + 1, i + 1), vid(j + 1, i)]
            for tri in ((quad[0], quad[1], quad[2]), (quad[0], quad[2], quad[3])):
                pts = [verts[k] for k in tri]
                if len({tuple(round(c, 5) for c in p) for p in pts}) < 3:
                    continue
                n = _newell(pts)
                mid = [sum(p[k] for p in pts) / 3 for k in range(3)]
                out = (mid[0] - centre_pt[0], mid[1] - centre_pt[1], mid[2] - centre_pt[2])
                if n[0] * out[0] + n[1] * out[1] + n[2] * out[2] < 0:
                    tri = (tri[0], tri[2], tri[1])
                    n = (-n[0], -n[1], -n[2])
                ax = max(range(3), key=lambda k: abs(n[k]))
                pick = [(0, 2), (2, 1), (0, 1)][[1, 0, 2].index(ax)] if ax != 1 else (0, 2)
                if ax == 0:
                    pick = (2, 1)
                elif ax == 2:
                    pick = (0, 1)
                faces.append(tri)
                uvs.append([(verts[k][pick[0]], verts[k][pick[1]]) for k in tri])
    s.mesh(mat, verts, faces, uvs)


# Grass ----------------------------------------------------------------------------------------------------------


def grass_clump(s, x, z, y, seed, blades=9, height=(0.7, 1.5), spread=0.4, dry=0.35):
    """A tuft of grass blades (both sides drawn), bent out from its middle."""
    r = random.Random(seed)
    for _ in range(blades):
        mat = "GrassBladeDry" if r.random() < dry else "GrassBlade"
        a = r.uniform(0, math.tau)
        d = r.uniform(0, spread)
        bx, bz = x + math.cos(a) * d, z + math.sin(a) * d
        hgt = r.uniform(*height)
        lean = r.uniform(0.2, 0.8) * hgt
        face = a + r.uniform(-0.8, 0.8)
        w = r.uniform(0.07, 0.12)
        side = (math.cos(face + math.pi / 2) * w, 0, math.sin(face + math.pi / 2) * w)
        out = (math.cos(a), 0, math.sin(a))
        p0 = (bx, y - 0.05, bz)
        p1 = (bx + out[0] * lean * 0.35, y + hgt * 0.55, bz + out[2] * lean * 0.35)
        p2 = (bx + out[0] * lean, y + hgt, bz + out[2] * lean)
        q = [
            (p0[0] - side[0], p0[1], p0[2] - side[2]), (p0[0] + side[0], p0[1], p0[2] + side[2]),
            (p1[0] + side[0] * 0.6, p1[1], p1[2] + side[2] * 0.6), (p1[0] - side[0] * 0.6, p1[1], p1[2] - side[2] * 0.6),
        ]
        tip = [q[3], q[2], p2]
        n = (math.cos(face), 0, math.sin(face))
        for pts in (q, tip):
            poly(s, mat, pts, n, [(0, 0)] * len(pts))
            poly(s, mat, pts, (-n[0], 0, -n[2]), [(0, 0)] * len(pts))


# Trees ----------------------------------------------------------------------------------------------------------


def bare_tree(s, mat, x, z, y, height, seed, levels=4, trunk=0.8, spread=38.0, lean=(0.0, 0.0), sides=9):
    """A bare broad tree (an old oak in winter): a trunk that forks, each limb forking again, twigs at the ends."""
    r = random.Random(seed)

    def norm(v):
        m = math.sqrt(sum(c * c for c in v)) or 1.0
        return tuple(c / m for c in v)

    def bend(d, angle, around):
        # turn d by angle (degrees) toward a random side, `around` radians about it
        d = norm(d)
        helper = (0, 1, 0) if abs(d[1]) < 0.9 else (1, 0, 0)
        u = norm(mesher.cross(helper, d))
        v = mesher.cross(d, u)
        a = math.radians(angle)
        side = tuple(math.cos(around) * u[k] + math.sin(around) * v[k] for k in range(3))
        return norm(tuple(math.cos(a) * d[k] + math.sin(a) * side[k] for k in range(3)))

    def limb(p, d, length, radius, level):
        pts, radii = [p], [radius]
        q = p
        cur = d
        n = 3 if level < 2 else 2
        for k in range(n):
            cur = bend(cur, r.uniform(4, 14), r.uniform(0, math.tau))
            cur = norm((cur[0], cur[1] + (0.08 if level < 3 else -0.02), cur[2]))
            q = tuple(q[i] + cur[i] * length / n for i in range(3))
            pts.append(q)
            radii.append(radius * (1 - 0.38 * (k + 1) / n))
        s.bent_tube(mat, pts, radii, segments=max(4, sides - level * 2), caps=(level == 0, True))
        if level >= levels:
            return
        forks = 2 if level == 0 else r.choice((2, 2, 3))
        base_around = r.uniform(0, math.tau)
        for f in range(forks):
            around = base_around + math.tau * f / forks + r.uniform(-0.4, 0.4)
            nd = bend(cur, spread * r.uniform(0.7, 1.25), around)
            limb(q, nd, length * r.uniform(0.6, 0.78), radii[-1] * 0.92, level + 1)
        # a side branch from the limb's middle
        if level < levels - 1 and r.random() < 0.7:
            mid = pts[len(pts) // 2]
            nd = bend(d, spread * 1.4, r.uniform(0, math.tau))
            limb(mid, nd, length * 0.5, radius * 0.45, level + 2)

    base = (x, y - 0.3, z)
    # the root flare
    for k in range(5):
        a = math.tau * k / 5 + r.uniform(-0.3, 0.3)
        s.bent_tube(mat, [(x + math.cos(a) * trunk * 2.2, y - 0.25, z + math.sin(a) * trunk * 2.2),
                          (x + math.cos(a) * trunk * 0.9, y + 0.5, z + math.sin(a) * trunk * 0.9),
                          (x, y + 1.6, z)], [trunk * 0.35, trunk * 0.6, trunk * 0.8], segments=6, caps=(True, False))
    limb(base, norm((lean[0], 1.0, lean[1])), height * 0.42, trunk, 0)


# Stones ---------------------------------------------------------------------------------------------------------


def _arched(w, h, sag, n, bottom):
    """A headstone's outline (u, v): flat sides, a shallow round top of sagitta `sag`, from v = bottom."""
    half = w / 2
    big = (sag * sag + half * half) / (2 * sag)
    pts = [(-half, bottom), (half, bottom)]
    for k in range(n + 1):
        u = half - w * k / n
        pts.append((u, h - big + math.sqrt(max(0.0, big * big - u * u))))
    return pts


def headstone(s, mat, x, z, rot, w=1.3, h=2.0, t=0.32, bevel=0.05, sag=0.22, arch=7, sink=0.4, y=0.0,
              engrave=True):
    """An upright headstone, its face toward rot (0 faces -Z), sunk into the ground, edges bevelled; with a few
    engraved lines across its face (a dark inlay a hair proud of the stone)."""
    outer = _arched(w, h, sag, arch, -sink)
    inner = _arched(w - 2 * bevel, h - bevel, sag * 0.9, arch, -sink)
    ht = t / 2

    def P(u, v, d):
        return place((u, v, d), x, y, z, rot)

    front = turned((0, 0, -1), rot)
    back = turned((0, 0, 1), rot)
    poly(s, mat, [P(u, v, -ht) for u, v in inner], front)
    poly(s, mat, [P(u, v, ht) for u, v in inner], back)
    n = len(outer)
    for i in range(n):
        j = (i + 1) % n
        (ua, va), (ub, vb) = outer[i], outer[j]
        (ia, ja), (ib, jb) = inner[i], inner[j]
        mid = ((ua + ub) / 2, (va + vb) / 2)
        out = turned((mid[0], mid[1] - h / 2, 0), rot)
        if i == 0:
            out = turned((0, -1, 0), rot)
        seg = math.hypot(ub - ua, vb - va)
        poly(s, mat, [P(ua, va, -ht + bevel), P(ub, vb, -ht + bevel), P(ub, vb, ht - bevel), P(ua, va, ht - bevel)],
             out, [(0, 0), (seg, 0), (seg, t), (0, t)])
        for sign, side, face in ((-1, -ht, front), (1, ht, back)):
            pts = [P(ua, va, side - sign * bevel), P(ub, vb, side - sign * bevel), P(ib, jb, side), P(ia, ja, side)]
            o = tuple((out[k] + face[k]) for k in range(3))
            poly(s, mat, pts, o, [(0, 0), (seg, 0), (seg, bevel), (0, bevel)])
    if engrave:
        lines = ((0.0, h * 0.70, w * 0.16, 0.07), (0.0, h * 0.53, w * 0.5, 0.035), (0.0, h * 0.45, w * 0.38, 0.03),
                 (0.0, h * 0.37, w * 0.44, 0.03))
        for u, v, half, thick in lines:
            pts = [P(u - half / 2 * 2, v - thick, -ht - 0.006), P(u + half, v - thick, -ht - 0.006),
                   P(u + half, v + thick, -ht - 0.006), P(u - half, v + thick, -ht - 0.006)]
            poly(s, "Engrave", pts, front)


# Extrusions and cars ----------------------------------------------------------------------------------------------


def extrude_x(s, mat, profile, x0, x1, cap_mat=None, base=(0.0, 0.0, 0.0), rot=0.0):
    """A profile [(z, y)] (any simple polygon) drawn from x0 to x1 (local), turned by rot and moved to base."""
    cap_mat = cap_mat or mat
    area = sum(profile[i][0] * profile[(i + 1) % len(profile)][1] - profile[(i + 1) % len(profile)][0] * profile[i][1]
               for i in range(len(profile)))
    if area < 0:
        profile = list(reversed(profile))

    def P(xx, zz, yy):
        return place((xx, yy, zz), base[0], base[1], base[2], rot)

    tris = tessellate_polygon([[(z, y, 0.0) for z, y in profile]])
    for xx, out in ((x0, (-1, 0, 0)), (x1, (1, 0, 0))):
        for tri in tris:
            pts = [P(xx, profile[k][0], profile[k][1]) for k in tri]
            poly(s, cap_mat, pts, turned(out, rot), [(profile[k][0], profile[k][1]) for k in tri])
    n = len(profile)
    for i in range(n):
        (za, ya), (zb, yb) = profile[i], profile[(i + 1) % n]
        dz, dy = zb - za, yb - ya
        out = turned((0, -dz, dy), rot)
        seg = math.hypot(dz, dy)
        poly(s, mat, [P(x0, za, ya), P(x1, za, ya), P(x1, zb, yb), P(x0, zb, yb)], out,
             [(0, 0), (x1 - x0, 0), (x1 - x0, seg), (0, seg)])


def car(s, x, z, rot, paint="CarBlue", y=0.0):
    """A four-door saloon, nose toward rot (0 faces -Z): the body, the glasshouse and roof, bumpers, lamps, wheels."""
    base = (x, y, z)
    # (local: nose at -z, so rot 0 points it -Z like everything else)
    body = [(-4.7, 0.75), (-4.75, 1.45), (-4.45, 1.95), (-2.3, 2.15), (2.2, 2.2), (4.35, 2.15), (4.7, 1.75),
            (4.7, 0.75), (3.6, 0.6), (-3.6, 0.6)]
    extrude_x(s, paint, body, -2.1, 2.1, base=base, rot=rot)
    glass = [(-2.35, 2.12), (-1.15, 3.25), (1.2, 3.3), (2.45, 2.15)]
    extrude_x(s, "GlassDark", glass, -1.85, 1.85, base=base, rot=rot)
    roof = [(-1.1, 3.22), (-1.0, 3.42), (1.15, 3.45), (1.25, 3.27)]
    extrude_x(s, paint, roof, -1.8, 1.8, base=base, rot=rot)
    for zz in (-4.85, 4.85):
        s_box = [(zz - 0.2, 0.7), (zz - 0.2, 1.25), (zz + 0.2, 1.25), (zz + 0.2, 0.7)]
        extrude_x(s, "BlackTrim", s_box, -2.15, 2.15, base=base, rot=rot)
    for sx in (-1, 1):
        lamp = [(-4.72, 1.5), (-4.5, 1.88), (-4.25, 1.88), (-4.4, 1.5)]
        extrude_x(s, "HeadLamp", lamp, sx * 1.95 - 0.55, sx * 1.95 + 0.55, base=base, rot=rot)
        tail = [(4.4, 1.55), (4.4, 1.95), (4.72, 1.85), (4.72, 1.55)]
        extrude_x(s, "TailLamp", tail, sx * 1.95 - 0.6, sx * 1.95 + 0.6, base=base, rot=rot)
        for zz in (-3.0, 3.0):
            a = place((sx * 1.8, 0.75, zz), x, y, z, rot)
            b = place((sx * 2.18, 0.75, zz), x, y, z, rot)
            s.tube("Tyre", a, b, 0.75, segments=14)
            c = place((sx * 2.2, 0.75, zz), x, y, z, rot)
            s.tube("Chrome", b, c, 0.44, segments=10)
