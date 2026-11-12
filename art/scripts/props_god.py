"""The Devourer of Gods for "A GOD.. IS NOT... AFRAID OF..." (Core set, 2026-11-10; redone 2026-11-12, the user: "the
head isnt accurate at all, its really ugly"). Our own 3D modelling read off the boss's final-phase sprites (head, body
and tail seen from above): slate-lavender armour edged lighter, pale mint seams between the plates, teal teardrop eyes
in pairs down the head, a pink diamond gem on the brow and the back, a maw ringed with curved pink fangs between two
great pincer mandibles that curl forward and in, cyan-tipped hooks over the fangs, horns raking out of the sides,
scroll-curled plates at the back of the skull; body links with a pink and a teal gem down the spine and swept blades
out of the sides; a tail of fins. Each carries a "Cracks" piece: glowing fractures over its surface (unbaked: the scene
colours them neon), which the scene lights up (SceneDeaths/God) as the god cracks apart.

Along -Y (the head leads), up Z. A body link is 4.6 long and about 4.4 across."""

import math
import random

import bmesh
from mathutils import Vector

import modelkit as mk
import propkit as pk
import props
from common import srgb
from props import prop


def _materials(tag):
    armor = pk.metal(tag + "_Armor", (52, 50, 92), (96, 98, 150), rough=0.34, metallic=0.7, scale=20)
    plate = pk.metal(tag + "_Plate", (92, 94, 148), (150, 154, 208), rough=0.3, metallic=0.72, scale=24)
    horn = mk.noisy(tag + "_Horn", srgb(118, 120, 172), srgb(170, 174, 218), scale=16, roughness=0.42, kind="plastic")
    mint = pk.glow(tag + "_Mint", (150, 240, 214), 1.8)
    teal = pk.glow(tag + "_Teal", (40, 200, 210), 3.0)
    pink = pk.glow(tag + "_Pink", (255, 90, 210), 3.2)
    dark = mk.flat(tag + "_Maw", srgb(30, 14, 40), 0.7)
    crack = mk.flat(tag + "_Crack", srgb(255, 236, 255), 0.4)
    return dict(armor=armor, plate=plate, horn=horn, mint=mint, teal=teal, pink=pink, dark=dark, crack=crack)


def _cracks(name, surface, count, length, mat, seed, radius=0.045):
    """Jagged glowing fracture lines lying on a surface: `surface(u, v)` gives a point (u, v in 0..1) and its outward
    normal; each crack wanders from a random start, lifted a hair off the surface."""
    rnd = random.Random(seed)
    parts = []
    for c in range(count):
        u, v = rnd.random(), rnd.random()
        du, dv = rnd.uniform(-1, 1), rnd.uniform(-1, 1)
        n = math.hypot(du, dv) or 1
        du, dv = du / n, dv / n
        pts = []
        for _ in range(9):
            p, nrm = surface(u, v)
            pts.append(tuple(Vector(p) + Vector(nrm) * 0.05))
            ang = rnd.uniform(-0.9, 0.9)
            du, dv = du * math.cos(ang) - dv * math.sin(ang), du * math.sin(ang) + dv * math.cos(ang)
            u = (u + du * length / 8) % 1.0
            v = min(1.0, max(0.0, v + dv * length / 8))
        parts.append(pk.sweep(f"{name}{c}", pts, [radius * (1.4 - 0.9 * k / 8) for k in range(9)], mat, sides=4))
    return parts


# The armoured cross-section: a ridged top, sloped shoulders, a flat belly. (x, z) for a half-width w, height h.
def _section(w, h):
    half = [(0.0, h), (0.36 * w, 0.94 * h), (0.76 * w, 0.68 * h), (w, 0.18 * h), (0.93 * w, -0.34 * h),
            (0.62 * w, -0.7 * h), (0.0, -0.8 * h)]
    return half + [(-x, z) for x, z in reversed(half[1:-1])]


def _upper(w, h):
    """The section's top arc, side to side over the ridge (for plates and seams)."""
    pts = _section(w, h)
    right = pts[:4]
    return [(-x, z) for x, z in reversed(right[1:])] + right


def _lerp_stations(stations, y):
    """(w, h, z0) at y along a list of (y, w, h, z0) stations ordered back to front (y falling)."""
    if y >= stations[0][0]:
        return stations[0][1:]
    for a, b in zip(stations, stations[1:]):
        if a[0] >= y >= b[0]:
            f = (a[0] - y) / (a[0] - b[0])
            f = f * f * (3 - 2 * f)
            return tuple(a[i] + (b[i] - a[i]) * f for i in (1, 2, 3))
    return stations[-1][1:]


def _loft(name, stations, mat, steps=4, outline=_section, caps=True):
    """A hull lofted through cross-sections at stations [(y, w, h, z0), ...], `steps` rings between each pair."""
    bm = bmesh.new()
    ys = []
    for a, b in zip(stations, stations[1:]):
        ys += [a[0] + (b[0] - a[0]) * k / steps for k in range(steps)]
    ys.append(stations[-1][0])
    rings = []
    for y in ys:
        w, h, z0 = _lerp_stations(stations, y)
        rings.append([bm.verts.new((x, y, z0 + z)) for x, z in outline(w, h)])
    n = len(rings[0])
    for r0, r1 in zip(rings, rings[1:]):
        for j in range(n):
            bm.faces.new((r0[j], r0[(j + 1) % n], r1[(j + 1) % n], r1[j]))
    if caps:
        bm.faces.new(rings[0])
        bm.faces.new(list(reversed(rings[-1])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = mk._obj_from_bm(name, bm, mat)
    mk.auto_smooth(obj, 34)
    return obj


def _shell(name, stations, y0, y1, grow, lift, mat, thick=0.16, steps=6):
    """An armour plate over the top of a hull from y0 (front) to y1 (back): the hull's top arc grown by `grow`, its
    back edge raised `lift` more (so each plate overlaps the next like a scale), `thick` deep."""
    bm = bmesh.new()
    rows = []
    for k in range(steps + 1):
        f = k / steps
        y = y0 + (y1 - y0) * f
        w, h, z0 = _lerp_stations(stations, y)
        g = grow + lift * f
        arc = _upper(w * g, h * g)
        outer = [bm.verts.new((x, y, z0 + z)) for x, z in arc]
        inner = [bm.verts.new((x * (1 - thick / max(w, 0.1)), y, z0 + z - thick)) for x, z in arc]
        rows.append((outer, inner))
    m = len(rows[0][0])
    for (o0, i0), (o1, i1) in zip(rows, rows[1:]):
        for j in range(m - 1):
            bm.faces.new((o0[j], o0[j + 1], o1[j + 1], o1[j]))
            bm.faces.new((i0[j + 1], i0[j], i1[j], i1[j + 1]))
        bm.faces.new((o0[0], o1[0], i1[0], i0[0]))
        bm.faces.new((o0[-1], i0[-1], i1[-1], o1[-1]))
    for outer, inner in (rows[0], rows[-1]):
        for j in range(m - 1):
            bm.faces.new((outer[j], inner[j], inner[j + 1], outer[j + 1]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = mk._obj_from_bm(name, bm, mat)
    mk.auto_smooth(obj, 34)
    return obj


def _edge_seam(name, stations, y, grow, mat, r=0.06):
    """A glowing seam along a plate's front edge (the hull's top arc at y, grown)."""
    w, h, z0 = _lerp_stations(stations, y)
    pts = [(x, y - 0.02, z0 + z) for x, z in _upper(w * grow, h * grow)]
    return pk.sweep(name, pts, r, mat, sides=5)


def _gem(name, at, size, mat, yaw=0.0):
    """A cut diamond gem (an octahedron), long along Y."""
    g = mk.sphere(name, 1.0, at, scale=size, mat=mat, segments=4, rings=2)
    g.rotation_euler = (0, 0, math.radians(45 + yaw))
    for f in g.data.polygons:
        f.use_smooth = False
    return g


def _scythe(side, root, reach, back, width, steps=9):
    """A crescent blade seen from above, out of the flank at (x, y) `root`: its spine curving out `reach` and back
    `back` (+Y), `width` at the root tapering to a point; the outline as (x, y) points, counter-clockwise."""
    spine = []
    for k in range(steps + 1):
        t = k / steps
        spine.append((root[0] + side * reach * math.sin(t * math.pi / 2), root[1] + back * t * t))
    lead, trail = [], []
    for k, (x, y) in enumerate(spine):
        t = k / steps
        w = width * (1 - t) ** 0.8
        a = spine[max(k - 1, 0)]
        b = spine[min(k + 1, steps)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        n = math.hypot(dx, dy) or 1
        nx, ny = -dy / n, dx / n
        lead.append((x + nx * w * 0.35, y + ny * w * 0.35))
        trail.append((x - nx * w * 0.65, y - ny * w * 0.65))
    pts = lead + list(reversed(trail[:-1]))
    area = sum(x0 * y1 - x1 * y0 for (x0, y0), (x1, y1) in zip(pts, pts[1:] + pts[:1]))
    return pts if area > 0 else list(reversed(pts))


def _blade(name, outline, at, mat, depth=0.22, tilt=(0, 0, 0)):
    """A flat blade seen from above: a polygon [(x, y)] in the XY plane, `depth` thick, bevelled."""
    return mk.extrude_shape(name, outline, depth, loc=at, rot=tilt, mat=mat, bevel=0.05)


HEAD = [(3.6, 1.5, 0.9, 0.5), (2.8, 2.0, 1.15, 0.55), (1.4, 2.3, 1.28, 0.55), (-0.2, 2.25, 1.25, 0.5),
        (-1.6, 1.9, 1.08, 0.42), (-2.8, 1.45, 0.86, 0.3), (-3.4, 1.15, 0.7, 0.25)]
OVER = 1.13  # the top of the outermost plates, as a share of the hull: what sits on the head sits on this


def _top(stations, x, y, lift=0.0, grow=1.0):
    """A point on the hull's top surface (grown by `grow`) over (x, y), and its up-ish normal."""
    w, h, z0 = _lerp_stations(stations, y)
    w, h = w * grow, h * grow
    arc = _section(w, h)[:4]
    ax = abs(x)
    for (x0, z0a), (x1, z1a) in zip(arc, arc[1:]):
        if x0 <= ax <= x1:
            f = (ax - x0) / max(x1 - x0, 1e-4)
            z = z0a + (z1a - z0a) * f
            nrm = Vector((-(z1a - z0a) * math.copysign(1, x or 1), 0, x1 - x0)).normalized()
            return Vector((x, y, z0 + z)) + nrm * lift, nrm
    return Vector((x, y, z0 + 0.2 * h)) + Vector((math.copysign(1, x or 1), 0, 0)) * lift, Vector((1, 0, 0))


@prop("GodHead", pivot="centre", material="Metal", collide=False, texture=512)
def god_head():
    """The Devourer's head, after its final-phase sprite: a long angular armoured skull in layered plates edged with
    mint seams; three pairs of teal teardrop eyes down the brow and a pink diamond gem behind them; a maw at the front
    ringed with curved pink fangs over a lit throat, cyan-tipped hooks over them; two great pincer mandibles curling
    forward and in from the front corners, barbed inside; three horns raking out of each side; scroll-curled plates at
    the back. Front to -Y."""
    m = _materials("GH")
    parts, glows = [], []
    parts.append(_loft("Skull", HEAD, m["armor"]))
    # the armour: three layered plates over the top, front to back, each lifting at its back edge over the next
    for k, (y0, y1, grow, lift) in enumerate(((-3.35, -1.3, 1.05, 0.05), (-1.5, 0.9, 1.07, 0.05),
                                             (0.7, 3.5, 1.09, 0.06))):
        parts.append(_shell(f"Plate{k}", HEAD, y0, y1, grow, lift, m["plate"]))
        glows.append(_edge_seam(f"Seam{k}", HEAD, y0 + 0.05, grow + 0.012, m["mint"]))
    # the mint line down the ridge between the eyes
    glows.append(pk.sweep("Ridge", [tuple(_top(HEAD, 0, y, 0.02, OVER)[0]) for y in (-3.1, -2.5, -1.9)], 0.05,
                          m["mint"], sides=5))
    # the crest down the spine: low backswept spikes over the plates
    for y in (-0.9, 1.3, 2.7):
        root = _top(HEAD, 0, y, -0.05, OVER)[0]
        parts.append(pk.sweep("Crest", [tuple(root), tuple(root + Vector((0, 0.45, 0.4))),
                                        tuple(root + Vector((0, 1.1, 0.62)))], [0.2, 0.12, 0.01], m["horn"], sides=6))
    # the eyes: three pairs of teal teardrops down the brow, pointed toward the snout
    for x, y, s in ((0.5, -2.55, 0.85), (0.9, -1.65, 1.05), (1.0, -0.55, 0.95)):
        for side in (-1, 1):
            at, nrm = _top(HEAD, side * x, y, 0.04, OVER)
            eye = mk.sphere("Eye", 0.27 * s, tuple(at), scale=(0.7, 1.8, 0.45), mat=m["teal"], segments=12, rings=8)
            eye.rotation_euler = (math.atan2(nrm.y, nrm.z), -side * math.atan2(abs(nrm.x), nrm.z),
                                  math.radians(side * -14))
            glows.append(eye)
    # the gems: pink on the brow, teal behind it
    glows.append(_gem("GemPink", tuple(_top(HEAD, 0, 0.35, 0.1, OVER)[0]), (0.36, 0.72, 0.26), m["pink"]))
    glows.append(_gem("GemTeal", tuple(_top(HEAD, 0, 2.05, 0.1, OVER)[0]), (0.26, 0.44, 0.22), m["teal"]))
    # the maw at the front: a dark mouth, the throat lit pink inside it, fangs ringing it
    mouth = Vector((0, -3.37, 0.22))
    parts.append(mk.sphere("Maw", 1.0, tuple(mouth + Vector((0, 0.12, 0))), scale=(0.9, 0.3, 0.55), mat=m["dark"],
                           segments=24, rings=12))
    glows.append(mk.sphere("Throat", 1.0, tuple(mouth + Vector((0, -0.1, 0))), scale=(0.6, 0.2, 0.36),
                           mat=m["pink"], segments=16, rings=8))
    # (two clusters of long curved fangs from the sides, as the sprite's, shorter ones above and below)
    for k in range(14):
        a = 2 * math.pi * (k + 0.5) / 14
        rim = mouth + Vector((math.cos(a) * 0.95, -0.15, math.sin(a) * 0.6))
        inward = (mouth - rim).normalized()
        size = 0.8 + 0.6 * abs(math.cos(a)) ** 2
        mid = rim + inward * 0.25 * size + Vector((0, -0.38 * size, 0))
        tip = rim + inward * 0.62 * size + Vector((0, -0.52 * size, 0))
        glows.append(pk.sweep("Fang", [tuple(rim), tuple(mid), tuple(tip)], [0.14 * size, 0.08 * size, 0.01],
                              m["pink"], sides=6))
    # the hooks over the fangs: curling down in front of the mouth, tipped cyan
    for side in (-1, 1):
        hook = [(side * 0.85, -3.1, 0.85), (side * 0.98, -3.85, 0.95), (side * 0.8, -4.35, 0.7),
                (side * 0.5, -4.5, 0.42)]
        parts.append(pk.sweep("Hook", hook[:3], [0.16, 0.13, 0.09], m["horn"], sides=6))
        glows.append(pk.sweep("HookTip", hook[2:], [0.09, 0.01], m["teal"], sides=6))
    # the pincers: from the front corners, out, forward, then curling in toward each other, a barb inside each
    for side in (-1, 1):
        arc = [(side * 1.4, -2.7, 0.15), (side * 2.2, -3.5, 0.2), (side * 2.55, -4.7, 0.25), (side * 2.4, -5.9, 0.25),
               (side * 1.9, -6.8, 0.2), (side * 1.2, -7.3, 0.15), (side * 0.5, -7.35, 0.1)]
        parts.append(pk.sweep("Mandible", arc, [0.55, 0.52, 0.46, 0.38, 0.28, 0.16, 0.03], m["horn"], sides=8))
        # the outer edge plate along it, lighter (the sprite's highlight edge), and the barb
        parts.append(pk.sweep("MandibleEdge", [(x + side * 0.12, y, z + 0.28) for x, y, z in arc[1:5]],
                              [0.16, 0.18, 0.15, 0.08], m["plate"], sides=6))
        parts.append(pk.sweep("Barb", [(side * 2.3, -4.8, 0.25), (side * 1.8, -5.15, 0.25), (side * 1.4, -5.2, 0.2)],
                              [0.22, 0.12, 0.01], m["horn"], sides=6))
        # the second, smaller prong outside the pincer's root (raking forward)
        parts.append(pk.sweep("Prong", [(side * 1.9, -2.4, 0.4), (side * 2.8, -3.1, 0.7), (side * 3.1, -4.2, 0.85)],
                              [0.3, 0.18, 0.02], m["horn"], sides=6))
    # the horns out of the sides: forward-raking at the front, out at the middle, back at the rear corners
    for side in (-1, 1):
        for y, out, fwd, up, r in ((-1.3, 2.1, -1.0, 0.5, 0.36), (0.5, 2.6, 0.4, 0.6, 0.42), (2.5, 2.3, 2.0, 0.4, 0.38)):
            w, h, z0 = _lerp_stations(HEAD, y)
            root = Vector((side * w * 0.95, y, z0 + 0.2 * h))
            tip = root + Vector((side * out, fwd, up))
            mid = root.lerp(tip, 0.5) + Vector((0, -0.25 * (1 if fwd < 0.5 else -1), 0.2))
            parts.append(pk.sweep("Horn", [tuple(root), tuple(mid), tuple(tip)], [r, r * 0.6, 0.02], m["horn"],
                                  sides=6))
    # the scroll curls at the back of the skull
    for side in (-1, 1):
        c = Vector((side * 1.1, 3.0, 1.55))
        curl = []
        for k in range(14):
            a = side * (math.pi * 1.6 * k / 13) + (0 if side > 0 else math.pi)
            r = 0.62 * (1 - 0.65 * k / 13)
            curl.append(tuple(c + Vector((math.cos(a) * r, math.sin(a) * r, 0.04 * k))))
        parts.append(pk.sweep("Scroll", curl, [0.18 - 0.1 * k / 13 for k in range(14)], m["plate"], sides=6))
    # the collar seam where the head meets the body
    w, h, z0 = _lerp_stations(HEAD, 3.5)
    ring = _section(w * 1.03, h * 1.03)
    glows.append(pk.sweep("Collar", [(x, 3.5, z0 + z) for x, z in ring + ring[:1]], 0.07, m["mint"], sides=5,
                          caps=False))

    def on_skull(u, v):
        a = 2 * math.pi * u
        y = -3.3 + 6.8 * v
        w, h, z0 = _lerp_stations(HEAD, y)
        return (math.cos(a) * w * 1.08, y, z0 + math.sin(a) * h * 1.08), (math.cos(a), 0.0, math.sin(a))

    cracks = _cracks("Crack", on_skull, 24, 0.55, m["crack"], 7)
    return parts, glows, {"pieces": {"Cracks": props.piece(cracks, bake=False)}}


def _segment(tag, length, radius, blades=True, fins=False):
    """One link: a faceted armoured barrel under a saddle plate (mint seam at its front edge), a pink and a teal gem
    down the spine, swept blades out of each side raking back, scroll plates low on the flanks, pink lights below;
    a tail link instead ends in three finned blades."""
    m = _materials(tag)
    parts, glows = [], []
    half = length / 2
    stations = [(half, radius * 0.86, radius * 0.72, 0), (0.0, radius, radius * 0.82, 0),
                (-half, radius * 0.88, radius * 0.74, 0)]
    if fins:
        stations = [(half, radius * 0.45, radius * 0.4, 0), (0.0, radius * 0.85, radius * 0.72, 0),
                    (-half, radius, radius * 0.8, 0)]
    parts.append(_loft("Core", stations, m["armor"], steps=3))
    parts.append(_shell("Saddle", stations, -half + 0.15, half - 0.35, 1.06, 0.05, m["plate"], steps=4))
    glows.append(_edge_seam("Seam", stations, -half + 0.2, 1.075, m["mint"]))
    if not fins:
        root = _top(stations, 0, 1.4, -0.05, 1.08)[0]
        parts.append(pk.sweep("Crest", [tuple(root), tuple(root + Vector((0, 0.5, 0.5))),
                                        tuple(root + Vector((0, 1.3, 0.75)))], [0.22, 0.13, 0.01], m["horn"], sides=6))
        glows.append(_gem("GemPink", tuple(_top(stations, 0, -0.55, 0.24)[0]), (0.28, 0.6, 0.2), m["pink"]))
        glows.append(_gem("GemTeal", tuple(_top(stations, 0, 0.75, 0.22)[0]), (0.22, 0.4, 0.18), m["teal"]))
    else:
        glows.append(_gem("GemTeal", tuple(_top(stations, 0, -0.6, 0.2)[0]), (0.2, 0.4, 0.16), m["teal"]))
    for side in (-1, 1):
        # (set into the belly plate, half sunk: nothing floats)
        bw, bh, bz = _lerp_stations(stations, -0.4)
        glows.append(mk.sphere("Light", 0.16, (side * bw * 0.45, -0.4, bz - bh * 0.74), mat=m["pink"], segments=10,
                               rings=6))
    if blades:
        for side in (-1, 1):
            big = _scythe(side, (side * radius * 0.7, -1.2), radius * 1.2, 3.4, 1.3)
            small = _scythe(side, (side * radius * 0.72, 0.4), radius * 0.75, 2.4, 0.8)
            parts.append(_blade("Blade", big, (0, 0, 0.3), m["horn"], depth=0.26, tilt=(0, side * -16, 0)))
            parts.append(_blade("BladeSmall", small, (0, 0, -0.25), m["horn"], depth=0.2, tilt=(0, side * 12, 0)))
            curl_c = Vector((side * radius * 0.82, 1.2, -0.45))
            curl = []
            for k in range(12):
                a = math.pi * 1.5 * k / 11
                r = 0.5 * (1 - 0.6 * k / 11)
                curl.append(tuple(curl_c + Vector((side * 0.05 * k, math.cos(a) * r, math.sin(a) * r))))
            parts.append(pk.sweep("Scroll", curl, [0.15 - 0.08 * k / 11 for k in range(12)], m["plate"], sides=6))
    if fins:
        for k, (yaw, out) in enumerate(((0, 0.0), (1, 1.0), (-1, 1.0))):
            if yaw == 0:
                fin = [(-0.3, half - 0.2), (0.3, half - 0.2), (0.15, half + 2.6), (-0.15, half + 2.6)]
                parts.append(_blade("FinTop", [(x, y) for x, y in fin], (0, 0, 0), m["horn"], depth=0.2,
                                    tilt=(0, 90, 0)))
            else:
                s = yaw
                fin = _scythe(s, (s * radius * 0.35, half - 0.6), radius + 1.2, 3.0, 1.2)
                parts.append(_blade("Fin", fin, (0, 0, 0), m["horn"], depth=0.2))

    def on_ring(u, v):
        a = 2 * math.pi * u
        y = -half + length * v
        w, h, z0 = _lerp_stations(stations, y)
        return (math.cos(a) * w * 1.1, y, z0 + math.sin(a) * h * 1.1), (math.cos(a), 0.0, math.sin(a))

    cracks = _cracks("Crack", on_ring, 14, 0.5, m["crack"], len(tag) * 13 + int(radius * 10))
    return parts, glows, {"pieces": {"Cracks": props.piece(cracks, bake=False)}}


@prop("GodBody", pivot="centre", material="Metal", collide=False, texture=512)
def god_body():
    """One armoured link of the Devourer's body (its final-phase body sprite): a faceted barrel under a saddle plate,
    a pink and a teal gem down the spine, two swept blades out of each side raking back, scroll plates on the flanks,
    a mint seam at its front edge, two pink lights below. Along Y."""
    return _segment("GB", 4.6, 2.2)


@prop("GodTail", pivot="centre", material="Metal", collide=False, texture=256)
def god_tail():
    """The Devourer's tail: a tapering armoured link ending in three finned blades, a teal gem on top. Along Y."""
    return _segment("GT", 3.6, 1.5, blades=False, fins=True)
