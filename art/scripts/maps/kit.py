"""Architecture kit for the map scenes: walls with doors and windows and their trims, floors,
ceilings, columns, railings, stairs, light fixtures, and the city beyond the windows.

All functions take a mesher.Scene first and work in Roblox studs (see mesher.py). Walls are
given by the two ends of their centre line on the floor (x, z); their "n" side is on the right
when you walk from a to b seen from above with -z up (n = the direction rotated 90 degrees).
"""

import math
import random

from maps.mesher import add, cross, norm, ry, scale, sub

WARM = (255, 214, 170)
COOL = (190, 210, 255)


def wall_frame(a, b):
    ax, az = a
    bx, bz = b
    length = math.hypot(bx - ax, bz - az)
    t = ((bx - ax) / length, 0.0, (bz - az) / length)
    n = (t[2], 0.0, -t[0])
    rot = math.degrees(math.atan2(-t[2], t[0]))
    return length, t, n, rot


def point_on(a, t, along, y=0.0):
    return (a[0] + t[0] * along, y, a[1] + t[2] * along)


# Trims -----------------------------------------------------------------------------------------

BASEBOARD = [(0, 0), (0.14, 0), (0.14, 0.5), (0.08, 0.62), (0, 0.66)]
CHAIR_RAIL = [(0, -0.12), (0.1, -0.08), (0.14, 0.0), (0.1, 0.08), (0, 0.12)]


def crown(h):
    return [(0, h - 0.9), (0.12, h - 0.8), (0.28, h - 0.5), (0.4, h - 0.22), (0.46, h - 0.1), (0.46, h), (0, h)]


def trims(s, a, t, outward, spans, height, spec, base=0.0):
    """Mouldings along one face of a wall. spans: [(start, end)] along the wall where the face is
    unbroken at floor level. spec keys: base, wainscot (material, height), rail, crown."""
    for u0, u1 in spans:
        if u1 - u0 < 0.05:
            continue
        p0 = point_on(a, t, u0, base)
        p1 = point_on(a, t, u1, base)
        if spec.get("wainscot"):
            mat, top = spec["wainscot"]
            mid_u = (u0 + u1) / 2
            centre = add(point_on(a, t, mid_u, base + top / 2), scale(outward, 0.04))
            rot = math.degrees(math.atan2(-t[2], t[0]))
            s.box(mat, centre, (u1 - u0, top, 0.08), rot, skip=("-y",))
            rail = spec.get("rail", "Wood")
            s.sweep(rail, add(p0, (0, top, 0)), add(p1, (0, top, 0)),
                    [(o + 0.08, h) for o, h in CHAIR_RAIL], outward)
        if spec.get("base"):
            s.sweep(spec["base"], p0, p1, [(o + (0.08 if spec.get("wainscot") else 0), h) for o, h in BASEBOARD],
                    outward)
        if spec.get("crown"):
            s.sweep(spec["crown"], p0, p1, crown(height - base), outward)


def wall(s, a, b, height, *, thick=1.0, base=0.0, core="PlasterDark", side_n=None, side_s=None,
         openings=(), trim_n=None, trim_s=None, collide=True, top=None):
    """A wall from a to b with doors and windows cut out.

    openings: dicts with at (distance from a to the middle), w, bottom, top, and kind:
      "door"   open doorway with a frame (and casings when frame is given)
      "window" glass, sill, frame and mullions; blinds=True adds slats on the n side
      "gap"    a plain hole
    Returns (length, t, n)."""
    side_n = side_n or core
    side_s = side_s or core
    length, t, n, rot = wall_frame(a, b)
    ops = sorted(openings, key=lambda o: o["at"])
    mats = {"-z": side_n, "+z": side_s, "+y": top or core, "-y": core, "+x": core, "-x": core}
    cursor = 0.0
    segments = []  # (u0, u1, y0, y1, is_lintel)
    for op in ops:
        u0 = max(0.0, op["at"] - op["w"] / 2)
        u1 = min(length, op["at"] + op["w"] / 2)
        if u0 - cursor > 0.02:
            segments.append((cursor, u0, base, height, False))
        bottom = op.get("bottom", base)
        top_y = op.get("top", min(height, base + 8.5))
        if bottom - base > 0.02:
            segments.append((u0, u1, base, bottom, False))
        if height - top_y > 0.02:
            segments.append((u0, u1, top_y, height, True))
        cursor = u1
    if length - cursor > 0.02:
        segments.append((cursor, length, base, height, False))
    for u0, u1, y0, y1, lintel in segments:
        centre = point_on(a, t, (u0 + u1) / 2, (y0 + y1) / 2)
        skip = () if lintel else ("-y",)
        s.box(core, centre, (u1 - u0, y1 - y0, thick), rot, collide=collide, skip=skip, mats=mats)
    for op in ops:
        opening(s, a, t, n, rot, thick, base, op, collide)
    # Trims run along the floor between doors.
    doors = [(o["at"] - o["w"] / 2, o["at"] + o["w"] / 2) for o in ops if o.get("bottom", base) <= base + 0.05]
    spans, cursor = [], 0.0
    for d0, d1 in doors:
        spans.append((cursor, max(cursor, d0 - (0.4 if trim_n or trim_s else 0))))
        cursor = d1 + (0.4 if trim_n or trim_s else 0)
    spans.append((cursor, length))
    if trim_n:
        trims(s, add3(a, scale(n, thick / 2)), t, n, spans, height, trim_n, base)
    if trim_s:
        trims(s, add3(a, scale(n, -thick / 2)), t, scale(n, -1), spans, height, trim_s, base)
    return length, t, n


def add3(a2, v):
    return (a2[0] + v[0], a2[1] + v[2])


def opening(s, a, t, n, rot, thick, base, op, collide):
    kind = op.get("kind", "door")
    u0 = op["at"] - op["w"] / 2
    u1 = op["at"] + op["w"] / 2
    bottom = op.get("bottom", base)
    top_y = op.get("top", base + 8.5)
    frame = op.get("frame")
    if kind in ("door", "gap") and bottom <= base + 0.05 and top_y - bottom >= 6 and hasattr(s, "openings"):
        # A way through at floor level: check_v2 keeps the space in front of it clear.
        x, _, z = point_on(a, t, op["at"])
        s.openings.append((round(x, 3), round(bottom, 3), round(z, 3), round(u1 - u0, 3), round(rot, 2), thick, kind))
    if kind == "gap":
        return
    if frame:
        # Linings inside the opening and casings on both faces.
        lining = 0.12
        for u in (u0 + lining / 2, u1 - lining / 2):
            s.box(frame, point_on(a, t, u, (bottom + top_y) / 2), (lining, top_y - bottom, thick + 0.1), rot)
        s.box(frame, point_on(a, t, op["at"], top_y - lining / 2), (u1 - u0, lining, thick + 0.1), rot)
        if kind == "window":
            s.box(frame, point_on(a, t, op["at"], bottom + lining / 2), (u1 - u0, lining, thick + 0.1), rot)
        casing = op.get("casing", 0.35)
        if kind == "window":
            post_y, post_h = (bottom + top_y) / 2, top_y - bottom + casing * 2
        else:
            post_y, post_h = (bottom + top_y + casing) / 2, top_y - bottom + casing
        for side in (1, -1):
            off = scale(n, side * (thick / 2 + 0.05))
            for u in (u0 - casing / 2, u1 + casing / 2):
                s.box(frame, add(point_on(a, t, u, post_y), off), (casing, post_h, 0.1), rot)
            s.box(frame, add(point_on(a, t, op["at"], top_y + casing / 2), off), (u1 - u0 + casing * 2, casing, 0.12),
                  rot)
    if kind == "window":
        sill_mat = op.get("sill", frame or "WhiteTrim")
        # (Its top a hair over the wall below, so the two never flicker.)
        s.box(sill_mat, point_on(a, t, op["at"], bottom - 0.06), (u1 - u0 + 0.6, 0.16, thick + 0.5), rot)
        glass = op.get("glass", "Glass")
        if glass:
            s.box(glass, point_on(a, t, op["at"], (bottom + top_y) / 2), (u1 - u0, top_y - bottom, 0.06), rot,
                  skip=("+x", "-x", "+y", "-y"))
        mull = op.get("mullions", frame or "BlackMetal")
        cols = op.get("cols", max(1, round((u1 - u0) / 3)))
        rows = op.get("rows", 2)
        for i in range(1, cols):
            u = u0 + (u1 - u0) * i / cols
            s.box(mull, point_on(a, t, u, (bottom + top_y) / 2), (0.12, top_y - bottom, 0.16), rot)
        for j in range(1, rows):
            y = bottom + (top_y - bottom) * j / rows
            s.box(mull, point_on(a, t, op["at"], y), (u1 - u0, 0.12, 0.16), rot)
        if op.get("blinds"):
            side = op.get("blinds_side", 1)
            slat_mat = op.get("slat", "CreamTrim")
            count = int((top_y - bottom) / 0.42)
            tilt = math.radians(28)
            for k in range(count):
                y = bottom + 0.25 + k * 0.42
                centre = add(point_on(a, t, op["at"], y), scale(n, side * (thick / 2 + 0.35)))
                uy = norm(add(scale((0, 1, 0), math.cos(tilt)), scale(n, math.sin(tilt) * side)))
                uz = norm(cross(t, uy))
                s.obox(slat_mat, centre, (u1 - u0 - 0.1, 0.03, 0.34), t, uy, uz)
        if collide and op.get("block", True):
            # Windows block movement and, like the solid walls they replace, sight lines too
            # (so who can see a letter flash does not change).
            s.collider(point_on(a, t, op["at"], (bottom + top_y) / 2), (u1 - u0, top_y - bottom, thick), rot,
                       query=op.get("see_through", False) is False)


# Floors and ceilings -----------------------------------------------------------------------------


def floor(s, x1, z1, x2, z2, mat, y=0.0, thick=1.0, collide=True, border=None, sides=False):
    """A floor slab with its top at y. border = (material, width) inlays a band around it."""
    x1, x2 = min(x1, x2), max(x1, x2)
    z1, z2 = min(z1, z2), max(z1, z2)
    if collide:
        s.collider(((x1 + x2) / 2, y - thick / 2, (z1 + z2) / 2), (x2 - x1, thick, z2 - z1))
    if border:
        bmat, w = border
        top_rect(s, mat, x1 + w, z1 + w, x2 - w, z2 - w, y)
        top_rect(s, bmat, x1, z1, x2, z1 + w, y)
        top_rect(s, bmat, x1, z2 - w, x2, z2, y)
        top_rect(s, bmat, x1, z1 + w, x1 + w, z2 - w, y)
        top_rect(s, bmat, x2 - w, z1 + w, x2, z2 - w, y)
    else:
        top_rect(s, mat, x1, z1, x2, z2, y)
    if sides:
        s.box(mat, ((x1 + x2) / 2, y - thick / 2, (z1 + z2) / 2), (x2 - x1, thick, z2 - z1), skip=("+y", "-y"))


def top_rect(s, mat, x1, z1, x2, z2, y, step=32.0):
    """An upward face over a rectangle, cut into tiles of at most `step` studs (so big floors
    fall into several chunks)."""
    xs = _cuts(x1, x2, step)
    zs = _cuts(z1, z2, step)
    for i in range(len(xs) - 1):
        for j in range(len(zs) - 1):
            a, b = xs[i], xs[i + 1]
            c, d = zs[j], zs[j + 1]
            s.polygon(mat, [(a, y, d), (b, y, d), (b, y, c), (a, y, c)])


def bottom_rect(s, mat, x1, z1, x2, z2, y, step=32.0):
    xs = _cuts(x1, x2, step)
    zs = _cuts(z1, z2, step)
    for i in range(len(xs) - 1):
        for j in range(len(zs) - 1):
            a, b = xs[i], xs[i + 1]
            c, d = zs[j], zs[j + 1]
            s.polygon(mat, [(a, y, c), (b, y, c), (b, y, d), (a, y, d)])


def _cuts(a, b, step):
    count = max(1, math.ceil((b - a) / step))
    return [a + (b - a) * i / count for i in range(count + 1)]


def ceiling(s, x1, z1, x2, z2, h, mat, beams=None, beam_mat="WhiteTrim", beam_depth=0.8, beam_w=0.8, roof=True):
    """A ceiling at height h; beams = spacing of a coffer grid hanging below it. roof adds a
    collider over it, so the rain (which looks up for a roof) stops indoors."""
    bottom_rect(s, mat, x1, z1, x2, z2, h)
    if roof:
        s.collider(((x1 + x2) / 2, h + 0.3, (z1 + z2) / 2), (abs(x2 - x1), 0.6, abs(z2 - z1)))
    if beams:
        x = x1 + beams
        while x < x2 - 0.5:
            s.box(beam_mat, (x, h - beam_depth / 2, (z1 + z2) / 2), (beam_w, beam_depth, z2 - z1), skip=("+y",))
            x += beams
        z = z1 + beams
        while z < z2 - 0.5:
            s.box(beam_mat, ((x1 + x2) / 2, h - beam_depth / 2 - 0.01, z), (x2 - x1, beam_depth, beam_w), skip=("+y",))
            z += beams


# Columns, railings, stairs ------------------------------------------------------------------------


def column_round(s, x, z, h, r, mat, trim="WhiteTrim", flutes=12, base=0.0, collide=True):
    s.lathe(trim, (x, base, z), [(r + 0.35, 0), (r + 0.35, 0.5), (r + 0.2, 0.7), (r + 0.1, 0.95)], 24)
    s.lathe(mat, (x, base, z), [(r, 0.95), (r, h - 1.1)], 32, caps=(False, False), flutes=flutes,
            flute_depth=r * 0.12 if flutes else 0)
    s.lathe(trim, (x, base, z), [(r + 0.05, h - 1.1), (r + 0.2, h - 0.8), (r + 0.45, h - 0.45),
                                 (r + 0.5, h - 0.3), (r + 0.5, h)], 24)
    if collide:
        s.collider((x, base + h / 2, z), (r * 2, h, r * 2))


def column_square(s, x, z, h, w, mat, trim="BlackTrim", base=0.0, collide=True, rot=0.0):
    s.box(trim, (x, base + 0.35, z), (w + 0.5, 0.7, w + 0.5), rot, skip=("-y",))
    s.box(mat, (x, base + h / 2, z), (w, h, w), rot, skip=("-y", "+y"))
    s.box(trim, (x, base + h - 0.3, z), (w + 0.4, 0.6, w + 0.4), rot, skip=("+y",))
    if collide:
        s.collider((x, base + h / 2, z), (w + 0.5, h, w + 0.5), rot)


def railing(s, points, h=3.2, mat="BlackMetal", post_every=3.0, base=0.0, glass=None, collide=True):
    """A rail along a polyline [(x, z)] with posts and a lower bar (or glass panels)."""
    for i in range(len(points) - 1):
        a = (points[i][0], base, points[i][1])
        b = (points[i + 1][0], base, points[i + 1][1])
        s.tube(mat, add(a, (0, h, 0)), add(b, (0, h, 0)), 0.12, 8)
        length = math.dist(a, b)
        count = max(1, round(length / post_every))
        for k in range(count + 1):
            p = add(a, scale(sub(b, a), k / count))
            s.tube(mat, p, add(p, (0, h, 0)), 0.08, 6, caps=False)
        if glass:
            mid = scale(add(a, b), 0.5)
            _, t, n, rot = wall_frame((a[0], a[2]), (b[0], b[2]))
            s.box(glass, add(mid, (0, h * 0.5, 0)), (length, h * 0.8, 0.05), rot)
        else:
            s.tube(mat, add(a, (0, h * 0.45, 0)), add(b, (0, h * 0.45, 0)), 0.06, 6)
        if collide:
            _, t, n, rot = wall_frame((a[0], a[2]), (b[0], b[2]))
            mid = scale(add(a, b), 0.5)
            s.collider(add(mid, (0, h / 2, 0)), (length, h, 0.4), rot)


def stairs(s, x, z, rot, width, rise, run, steps, mat, side_mat=None, base=0.0, collide=True):
    """A straight flight starting at (x, z) and climbing towards the direction rot faces."""
    side_mat = side_mat or mat
    turn = ry(rot)
    for i in range(steps):
        p = add((x, 0, z), turn((0, 0, -run * (i + 0.5))))
        top = rise * (i + 1)
        centre = (p[0], base + top / 2, p[2])
        s.box(mat, centre, (width, top, run), rot, skip=("-y",), mats={"+x": side_mat, "-x": side_mat},
              collide=collide)


# Lights ---------------------------------------------------------------------------------------------


def panel_light(s, x, y, z, w=4.0, d=2.0, color=WARM, range_=24, brightness=1.1, frame="DarkMetal", rot=0.0,
                shadows=False, soft=False):
    """A ceiling panel with its light. soft: a frosted diffuser that reads as lit without
    blooming (rooms people walk into), instead of a bright neon face."""
    s.box(frame, (x, y - 0.08, z), (w + 0.3, 0.16, d + 0.3), rot, skip=("+y",))
    warm = color[0] > color[2]  # the panel glows the colour its light is
    if soft:
        glow = "PanelWarm" if warm else "PanelCool"
    else:
        glow = "NeonWarm" if warm else "NeonCool"
    s.box(glow, (x, y - 0.17, z), (w, 0.04, d), rot, skip=("+y",))
    s.light("point", (x, y - 1.0, z), color, range_, brightness, shadows)


def tube_light(s, x, y, z, length=6.0, rot=0.0, color=(226, 236, 255), range_=18, brightness=0.7, tubes=2,
               shadows=False):
    """A fluorescent fitting on a ceiling at height y: a steel housing with its tubes behind a
    ribbed diffuser, and one light under it. Dimmer than a panel, and it does not bloom."""
    s.box("Steel", (x, y - 0.12, z), (length + 0.2, 0.24, 0.5 + 0.35 * tubes), rot, skip=("+y",))
    a = math.radians(rot)
    for k in range(tubes):
        off = (k - (tubes - 1) / 2) * 0.35
        dx, dz = off * math.sin(a), off * math.cos(a)
        s.box("TubeDiffuser", (x + dx, y - 0.3, z + dz), (length - 0.2, 0.14, 0.18), rot)
    for u in (-length / 2 + 0.15, length / 2 - 0.15):
        dx, dz = u * math.cos(a), -u * math.sin(a)
        s.box("DarkMetal", (x + dx, y - 0.3, z + dz), (0.2, 0.3, 0.5 + 0.35 * tubes), rot)
    s.light("point", (x, y - 1.0, z), color, range_, brightness, shadows)


def pendant(s, x, ceiling_y, z, drop=4.0, shade="BlackMetal", color=WARM, range_=22, brightness=1.4,
            shadows=False, wide=1.4):
    low = ceiling_y - drop
    s.tube("BlackMetal", (x, ceiling_y, z), (x, low + 0.6, z), 0.04, 5, caps=False)
    s.lathe(shade, (x, low, z), [(wide, 0), (wide * 0.9, 0.2), (wide * 0.45, 0.55), (0.18, 0.7), (0.16, 0.9)], 20,
            caps=(False, True))
    s.lathe(shade, (x, low + 0.02, z), [(0.16, 0.88), (0.45 * wide - 0.04, 0.55), (0.9 * wide - 0.04, 0.2),
                                        (wide - 0.05, 0.02)], 20, caps=(False, False))
    s.lathe("NeonWarm", (x, low + 0.25, z), [(0.25, -0.05), (0.3, 0.1), (0.25, 0.3), (0.0, 0.34)], 10)
    s.light("spot", (x, low + 0.2, z), color, range_, brightness, shadows, "Bottom", 80)


def chandelier(s, x, ceiling_y, z, r=2.4, drop=5.0, arms=8, color=WARM, range_=34, brightness=1.6, shadows=True):
    low = ceiling_y - drop
    s.tube("Brass", (x, ceiling_y, z), (x, low + 1.2, z), 0.06, 6, caps=False)
    s.lathe("Brass", (x, low, z), [(0.0, -0.4), (0.35, -0.2), (0.5, 0.3), (0.25, 0.8), (0.12, 1.2)], 16)
    for k in range(arms):
        a = 2 * math.pi * k / arms
        tip = (x + math.cos(a) * r, low + 0.5, z + math.sin(a) * r)
        s.tube("Brass", (x, low + 0.2, z), tip, 0.05, 5)
        s.cylinder("Brass", add(tip, (0, -0.1, 0)), 0.18, 0.2, 10)
        s.cylinder("CreamTrim", add(tip, (0, 0.1, 0)), 0.08, 0.5, 8)
        s.lathe("NeonWarm", add(tip, (0, 0.6, 0)), [(0.0, 0), (0.09, 0.08), (0.05, 0.22), (0.0, 0.28)], 8)
    s.light("point", (x, low + 0.4, z), color, range_, brightness, shadows)


def sconce(s, x, y, z, rot, color=WARM, range_=14, brightness=0.9):
    turn = ry(rot)
    back = add((x, y, z), turn((0, 0, 0.05)))
    s.box("Brass", back, (0.5, 0.9, 0.1), rot)
    arm = add((x, y + 0.1, z), turn((0, 0, -0.35)))
    s.box("Brass", arm, (0.12, 0.12, 0.6), rot)
    shade = add((x, y + 0.2, z), turn((0, 0, -0.65)))
    s.lathe("CreamTrim", (shade[0], shade[1] - 0.1, shade[2]), [(0.32, 0), (0.22, 0.55)], 12, caps=(False, False))
    s.lathe("NeonWarm", (shade[0], shade[1] - 0.05, shade[2]), [(0.0, 0), (0.12, 0.1), (0.0, 0.3)], 8)
    s.light("point", (shade[0], shade[1] + 0.2, shade[2]), color, range_, brightness)


def spotlight_rig(s, x, y, z, color=(255, 236, 214), range_=26, brightness=5, angle=60, shadows=True):
    s.lathe("BlackMetal", (x, y - 0.9, z), [(0.9, 0), (0.95, 0.2), (0.7, 0.8), (0.3, 1.0)], 16, caps=(False, True))
    s.lathe("NeonWarm", (x, y - 0.85, z), [(0.0, 0.0), (0.6, 0.05)], 16, caps=(False, False))
    s.tube("BlackMetal", (x, y, z), (x, y + 3, z), 0.06, 6)
    s.light("spot", (x, y - 1.0, z), color, range_, brightness, shadows, "Bottom", angle)


# Outside -------------------------------------------------------------------------------------------


def skyline(s, cx, cz, half_x, half_z, seed, count=28, reach=(1.3, 1.9), height=(40, 120), arc=(0.0, 360.0)):
    """A ring of dark towers with lit windows far outside the playable area. arc limits it to
    the directions (degrees, 0 = +z, 90 = +x) where it can be seen."""
    rng = random.Random(seed)
    for i in range(count):
        angle = math.radians(arc[0] + (arc[1] - arc[0]) * (i + 0.5) / count) + rng.uniform(-0.05, 0.05)
        r = rng.uniform(*reach)
        x = cx + math.sin(angle) * half_x * r
        z = cz + math.cos(angle) * half_z * r
        w = rng.uniform(18, 36)
        d = rng.uniform(18, 36)
        h = rng.uniform(*height)
        rot = math.degrees(angle) + rng.uniform(-20, 20)
        s.box("ConcreteDark", (x, h / 2 - 2, z), (w, h, d), rot, skip=("-y",))
        # Roof parapet and a few lit windows on the side that faces the map.
        s.box("BlackTrim", (x, h - 2 + 0.6, z), (w + 0.6, 1.2, d + 0.6), rot, skip=("-y",))
        turn = ry(rot)
        towards_centre = norm((cx - x, 0, cz - z))
        # Pick the tower face that points most towards the middle.
        faces = [((0, 0, -1), d / 2, w), ((0, 0, 1), d / 2, w), ((-1, 0, 0), w / 2, d), ((1, 0, 0), w / 2, d)]
        best = max(faces, key=lambda f: sum(a * b for a, b in zip(turn(f[0]), towards_centre)))
        normal, dist, width = best
        normal_w = turn(normal)
        side = turn((normal[2], 0, -normal[0]))
        floors = int((h - 6) / 4)
        cols = int(width / 3.2)
        for fy in range(floors):
            for fx in range(cols):
                if rng.random() > 0.28:
                    continue
                u = -width / 2 + 1.6 + fx * 3.2
                y = 4 + fy * 4 - 2
                centre = add((x, y, z), add(scale(normal_w, dist + 0.05), scale(side, u)))
                mat = "WindowLit" if rng.random() < 0.7 else "WindowCool"
                s.obox(mat, centre, (1.6, 1.8, 0.05), side, (0, 1, 0), normal_w,
                       skip=("-z", "+x", "-x", "+y", "-y"))


# Wall dressing -----------------------------------------------------------------------------------
# Each item hangs on a wall face at (x, y, z) and faces the direction rot (like props).


def _on_wall(x, y, z, rot, out):
    turn = ry(rot)
    p = turn((0, 0, -out))
    return (x + p[0], y, z + p[2])


def whiteboard(s, x, y, z, rot, w=6.0, h=3.4, scribbles=True):
    s.box("Steel", _on_wall(x, y, z, rot, 0.08), (w + 0.3, h + 0.3, 0.16), rot)
    s.box("Paper", _on_wall(x, y, z, rot, 0.17), (w, h, 0.03), rot)
    s.box("Steel", _on_wall(x, y - h / 2 - 0.2, z, rot, 0.3), (w, 0.1, 0.4), rot)
    if scribbles:
        turn = ry(rot)
        for i, (u, v, lw, mat) in enumerate(((-1.8, 0.9, 2.2, "BlackTrim"), (-1.5, 0.4, 1.6, "BlackTrim"),
                                              (0.9, 0.7, 1.8, "RedTrim"), (-1.9, -0.3, 2.6, "BlackTrim"),
                                              (0.8, -0.6, 2.0, "BlackTrim"))):
            p = turn((u * w / 6, 0, -0.2))
            s.box(mat, (x + p[0], y + v * h / 3.4, z + p[2]), (lw * w / 6, 0.07, 0.02), rot)


def picture(s, x, y, z, rot, w=2.4, h=3.0, frame="Wood", inner="Paper", border=0.2):
    s.box(frame, _on_wall(x, y, z, rot, 0.07), (w, h, 0.14), rot)
    s.box(inner, _on_wall(x, y, z, rot, 0.145), (w - border * 2, h - border * 2, 0.02), rot)


def wall_clock(s, x, y, z, rot, r=1.0):
    centre = _on_wall(x, y, z, rot, 0.1)
    turn = ry(rot)
    normal = turn((0, 0, -1))
    s.tube("BlackMetal", add(centre, scale(normal, -0.1)), add(centre, scale(normal, 0.08)), r, 20)
    face = add(centre, scale(normal, 0.1))
    side = turn((1, 0, 0))
    pts = [add(face, add(scale(side, math.cos(a) * (r - 0.1)), (0, math.sin(a) * (r - 0.1), 0)))
           for a in (2 * math.pi * k / 20 for k in range(20))]
    s.polygon("Paper", list(reversed(pts)))  # side x up points into the wall, so wind it backwards
    s.box("BlackTrim", add(face, add(scale(side, 0.0), (0, 0.3, 0))), (0.06, 0.6, 0.02), rot)
    s.box("BlackTrim", add(face, scale(side, 0.22)), (0.45, 0.06, 0.02), rot)


def exit_sign(s, x, y, z, rot):
    s.box("BlackTrim", _on_wall(x, y, z, rot, 0.1), (1.6, 0.6, 0.2), rot)
    s.box("NeonGreen", _on_wall(x, y, z, rot, 0.21), (1.4, 0.45, 0.02), rot)
    p = _on_wall(x, y, z, rot, 0.23)
    s.sign(p, rot, 1.3, 0.4, "EXIT", "GothamBlack", (235, 255, 235), None)


def extinguisher(s, x, z, rot):
    p = _on_wall(x, 0, z, rot, 0.35)
    s.cylinder("RedTrim", (p[0], 1.6, p[2]), 0.28, 1.4, 12)
    s.lathe("BlackMetal", (p[0], 3.0, p[2]), [(0.2, 0), (0.12, 0.25), (0.06, 0.4)], 8)
    s.box("BlackMetal", _on_wall(x, 2.4, z, rot, 0.05), (0.5, 0.2, 0.1), rot)


def vent(s, x, y, z, rot, w=2.0, h=1.0):
    s.box("DarkMetal", _on_wall(x, y, z, rot, 0.05), (w, h, 0.1), rot)
    count = int(h / 0.2)
    for i in range(count):
        s.box("BlackMetal", _on_wall(x, y - h / 2 + 0.12 + i * 0.2, z, rot, 0.12), (w - 0.2, 0.05, 0.04), rot)


# Outdoors -------------------------------------------------------------------------------------------


def gable_roof(s, x1, z1, x2, z2, h, rise, mat="Slate", gable="BrickRed", overhang=1.2, trim="Stone", thick=0.5):
    """A pitched roof over a rectangle (walls up to h), the ridge along its longer side and
    rise studs above h, with gable walls filling both ends."""
    along_x = (x2 - x1) >= (z2 - z1)
    if along_x:
        a0, a1, c0, c1 = x1, x2, z1, z2
        axis, across = (1.0, 0.0, 0.0), (0.0, 0.0, 1.0)

        def pt(a, c, y):
            return (a, y, c)
    else:
        a0, a1, c0, c1 = z1, z2, x1, x2
        axis, across = (0.0, 0.0, 1.0), (1.0, 0.0, 0.0)

        def pt(a, c, y):
            return (c, y, a)

    mid = (c0 + c1) / 2
    half_in = (c1 - c0) / 2
    half = half_in + overhang
    drop = overhang * rise / half_in
    run_h = rise + drop
    slope = math.hypot(half, run_h)
    centre_a = (a0 + a1) / 2
    for side in (-1, 1):
        n = norm(add((0.0, half, 0.0), scale(across, side * run_h)))
        eave = pt(centre_a, mid + side * half, h - drop)
        ridge = pt(centre_a, mid, h + rise)
        centre = add(scale(add(eave, ridge), 0.5), scale(n, -thick / 2))
        uz = cross(axis, n)
        s.obox(mat, centre, (a1 - a0 + overhang * 2, thick, slope), axis, n, uz)
    for a in (a0, a1):
        tri = [pt(a, c0, h), pt(a, c1, h), pt(a, mid, h + rise - 0.25)]
        s.polygon(gable, tri)
        s.polygon(gable, list(reversed(tri)))
    s.tube(trim, pt(a0 - overhang, mid, h + rise + 0.05), pt(a1 + overhang, mid, h + rise + 0.05), 0.28, 6)


def pyramid_roof(s, x, z, w, base_y, height, mat="Slate", finial="Brass"):
    """A square spire roof (clock towers)."""
    hw = w / 2
    apex = (x, base_y + height, z)
    corners = [(x - hw, base_y, z - hw), (x + hw, base_y, z - hw), (x + hw, base_y, z + hw), (x - hw, base_y, z + hw)]
    for i in range(4):
        a, b = corners[i], corners[(i + 1) % 4]
        s.polygon(mat, [b, a, apex])
    s.tube(finial, apex, add(apex, (0, 2.5, 0)), 0.12, 6)
    s.lathe(finial, add(apex, (0, 0.6, 0)), [(0.0, 0), (0.35, 0.3), (0.0, 0.7)], 10)


def lantern_post(s, x, z, h=10.0, shadows=False, flicker=False, color=WARM, collide=True, glow=None, y=0.0):
    """A cast-iron lamp post with a glass lantern, standing on the ground at height y."""
    s.lathe("BlackMetal", (x, y, z), [(0.55, 0), (0.55, 0.35), (0.35, 0.6), (0.24, 1.3), (0.17, 1.6), (0.15, h - 1.3),
                                      (0.26, h - 1.1), (0.26, h - 0.9)], 10)
    top = y + h - 0.9
    s.box("NeonWarm", (x, top + 0.7, z), (0.7, 1.1, 0.7))
    for dx in (-0.4, 0.4):
        for dz in (-0.4, 0.4):
            s.tube("BlackMetal", (x + dx, top, z + dz), (x + dx * 1.25, top + 1.35, z + dz * 1.25), 0.05, 4)
    s.lathe("BlackMetal", (x, top + 1.3, z), [(0.75, 0), (0.6, 0.15), (0.2, 0.7), (0.06, 1.0)], 8)
    s.cylinder("BlackMetal", (x, top - 0.05, z), 0.5, 0.12, 8)
    s.light("spot", (x, top + 0.3, z), color, h + 14, 2.6, shadows, "Bottom", 80, flicker)
    if glow if glow is not None else shadows:
        s.light("point", (x, top + 0.8, z), color, 9, 0.7, False, flicker=flicker)
    if collide:
        s.collider((x, y + h / 2, z), (0.6, h, 0.6))


def bollard_light(s, x, z, color=WARM):
    s.lathe("BlackMetal", (x, 0, z), [(0.35, 0), (0.3, 2.2), (0.35, 2.4), (0.0, 2.6)], 10)
    s.box("NeonWarm", (x, 2.0, z), (0.5, 0.35, 0.5))
    s.light("point", (x, 2.0, z), color, 8, 0.6)


def hedge(s, x1, z1, x2, z2, h, collide=True):
    x1, x2 = min(x1, x2), max(x1, x2)
    z1, z2 = min(z1, z2), max(z1, z2)
    s.box("Hedge", ((x1 + x2) / 2, h / 2, (z1 + z2) / 2), (x2 - x1, h, z2 - z1), skip=("-y",), collide=collide)


def puddle(s, x, z, rx, rz, y=0.03, seed=0):
    import random as _r

    rng = _r.Random(seed or int(x * 7 + z * 13))
    pts = []
    count = 14
    for k in range(count):
        a = 2 * math.pi * k / count
        wob = 0.8 + rng.random() * 0.35
        pts.append((x + math.cos(a) * rx * wob, y, z + math.sin(a) * rz * wob))
    s.polygon("Puddle", list(reversed(pts)))


def pier_wall(s, x1, z1, x2, z2, h, pier_every=12.0, mat="BrickRed", pier="Stone", thick=1.4, collide_h=12.0):
    """A brick boundary wall with stone piers and coping."""
    length, t, n, rot = wall_frame((x1, z1), (x2, z2))
    mid = ((x1 + x2) / 2, h / 2, (z1 + z2) / 2)
    s.box(mat, mid, (length, h, thick), rot, skip=("-y",))
    s.box(pier, (mid[0], h + 0.2, mid[2]), (length + 0.4, 0.4, thick + 0.5), rot, skip=("-y",))
    count = max(1, round(length / pier_every))
    for i in range(count + 1):
        p = point_on((x1, z1), t, length * i / count, 0)
        s.box(pier, (p[0], (h + 1.2) / 2, p[2]), (thick + 0.8, h + 1.2, thick + 0.8), rot, skip=("-y",))
        s.lathe(pier, (p[0], h + 1.2, p[2]), [(0.9, 0), (0.5, 0.5), (0.0, 0.9)], 4)
    s.collider((mid[0], collide_h / 2, mid[2]), (length, collide_h, thick), rot)


# Furniture built with the scene (so its size matches gameplay exactly) ----------------------------


def counter(s, x, z, rot, w, top="MarbleWhite", body="WhiteTrim", h=3.5, d=2.4):
    """A counter with cupboard doors on its front (the side rot faces); top at height h."""
    s.box(body, (x, h / 2 - 0.05, z), (w, h - 0.1, d), rot)
    s.box(top, (x, h - 0.05, z), (w + 0.2, 0.1, d + 0.2), rot)
    s.collider((x, h / 2, z), (w, h, d), rot)
    turn = ry(rot)
    doors = max(1, int(w / 2))
    for i in range(doors):
        u = -w / 2 + (i + 0.5) * w / doors
        p = turn((u, 0, -d / 2 - 0.02))
        s.box("BlackTrim", (x + p[0], h * 0.45, z + p[2]), (w / doors - 0.2, h * 0.7, 0.04), rot)
        k = turn((u + w / doors * 0.3, 0, -d / 2 - 0.06))
        s.box("Steel", (x + k[0], h * 0.62, z + k[2]), (0.1, 0.5, 0.08), rot)


def table(s, x, z, w, d, top="Wood", legs="BlackMetal", h=2.75, rot=0.0, collide=True):
    """A table whose top is at height h (sheets of paper rest on 2.8)."""
    s.box(top, (x, h - 0.1, z), (w, 0.2, d), rot)
    turn = ry(rot)
    for dx in (-w / 2 + 0.3, w / 2 - 0.3):
        for dz in (-d / 2 + 0.3, d / 2 - 0.3):
            p = turn((dx, 0, dz))
            s.box(legs, (x + p[0], (h - 0.2) / 2, z + p[2]), (0.2, h - 0.2, 0.2), rot)
    if collide:
        s.collider((x, h / 2, z), (w, h, d), rot)
