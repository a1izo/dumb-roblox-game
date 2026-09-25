"""Street kit for the Tokyo district: towers with tiled facades and window grids, shutters,
awnings, vertical neon signs, utility poles and their wires, traffic lights, paper lanterns,
noren curtains, bicycles, guardrails and stocked konbini shelves."""

import math
import random

from maps import kit
from maps.mesher import add, cross, norm, ry, scale, sub

NEON = ["NeonPink", "NeonCyan", "NeonYellow", "NeonGreen", "NeonRed", "NeonOrange", "NeonBlue"]
NEON_RGB = {
    "NeonPink": (255, 80, 200),
    "NeonCyan": (60, 230, 255),
    "NeonYellow": (255, 220, 70),
    "NeonGreen": (100, 255, 140),
    "NeonRed": (255, 40, 60),
    "NeonOrange": (255, 130, 50),
    "NeonBlue": (80, 150, 255),
}


def face_frame(x1, z1, x2, z2, face):
    """For a face of a rectangle: (start corner, direction along the face, outward normal, length,
    rot that faces outward)."""
    if face == "n":
        return (x2, z1), (-1, 0, 0), (0, 0, -1), x2 - x1, 0
    if face == "s":
        return (x1, z2), (1, 0, 0), (0, 0, 1), x2 - x1, 180
    if face == "e":
        return (x2, z2), (0, 0, -1), (1, 0, 0), z2 - z1, -90
    return (x1, z1), (0, 0, 1), (-1, 0, 0), z2 - z1, 90


def tower(s, x1, z1, x2, z2, h, seed, faces=("n", "e", "s", "w"), tile="FacadeTile", floor_h=4.0,
          ground="shutter", balconies=False, lit=0.45, collide=True, roof=True):
    """A city building: a tiled core with a window grid on the given faces, a ground floor of
    shutters or shopfronts, a parapet and rooftop clutter."""
    rng = random.Random(seed)
    cx, cz = (x1 + x2) / 2, (z1 + z2) / 2
    s.box(tile, (cx, h / 2, cz), (x2 - x1, h, z2 - z1), skip=("-y",), collide=collide)
    s.box("ConcreteDark", (cx, h + 0.6, cz), (x2 - x1 + 0.6, 1.2, z2 - z1 + 0.6), skip=("-y",))
    s.box("ConcreteDark", (cx, h + 0.61, cz), (x2 - x1 - 1.2, 0.02, z2 - z1 - 1.2), skip=("-y",))
    for face in faces:
        start, along, out, length, rot = face_frame(x1, z1, x2, z2, face)
        floors = int((h - 5) // floor_h)
        bays = max(1, int(length // 3.4))
        bay_w = length / bays
        for f in range(floors):
            y0 = 5 + f * floor_h
            # A ledge between floors.
            p = add((start[0], y0 - 0.1, start[1]), add(scale(along, length / 2), scale(out, 0.15)))
            s.box("ConcreteDark", p, (length, 0.25, 0.3), rot, skip=("-y",))
            for b in range(bays):
                u = (b + 0.5) * bay_w
                centre = add((start[0], y0 + 1.9, start[1]), add(scale(along, u), scale(out, 0.02)))
                r = rng.random()
                mat = "WindowLit" if r < lit else ("WindowCool" if r < lit + 0.12 else "WindowDark")
                win_w = bay_w - 0.9
                s.box(mat, centre, (win_w, 2.4, 0.05), rot, skip=("+z", "+x", "-x", "+y", "-y"))
                s.box("DarkMetal", add(centre, scale(out, 0.06)), (win_w + 0.2, 0.15, 0.12), rot)
                s.box("DarkMetal", add(add(centre, scale(out, 0.06)), (0, 1.25, 0)), (win_w + 0.2, 0.12, 0.12), rot)
                s.box("DarkMetal", add(add(centre, scale(out, 0.06)), (0, -1.25, 0)), (win_w + 0.3, 0.18, 0.3), rot)
                if mat == "WindowLit" and rng.random() < 0.35:
                    # A drawn curtain half across.
                    side = -1 if rng.random() < 0.5 else 1
                    cpos = add(centre, add(scale(along, side * win_w / 4), scale(out, 0.04)))
                    s.box("CreamTrim" if rng.random() < 0.5 else "FabricRed", cpos, (win_w / 2, 2.3, 0.03), rot)
                if balconies and b % 2 == 0 and f % 2 == 1:
                    bpos = add((start[0], y0 - 0.2, start[1]), add(scale(along, u + bay_w / 2), scale(out, 1.0)))
                    s.box("ConcreteDark", bpos, (bay_w * 2 - 0.4, 0.3, 2.0), rot)
                    rail = add(bpos, add((0, 1.2, 0), scale(out, 0.95)))
                    s.box("Steel", rail, (bay_w * 2 - 0.4, 0.1, 0.1), rot)
                    s.box("GlassDark", add(bpos, add((0, 0.7, 0), scale(out, 0.95))), (bay_w * 2 - 0.6, 1.0, 0.05), rot)
                elif rng.random() < 0.18:
                    # An air conditioner under the window.
                    apos = add((start[0], y0 + 0.3, start[1]), add(scale(along, u + rng.uniform(-0.6, 0.6)), scale(out, 0.55)))
                    s.box("WhiteTrim", apos, (1.4, 0.9, 0.9), rot)
                    s.box("DarkMetal", add(apos, scale(out, 0.46)), (0.9, 0.7, 0.02), rot)
        # Ground floor.
        mid = add((start[0], 2.5, start[1]), scale(along, length / 2))
        if ground == "shutter":
            s.box("Shutter", add(mid, scale(out, 0.05)), (length - 1.2, 4.6, 0.1), rot, skip=("+z",))
            s.box("DarkMetal", add(add(mid, scale(out, 0.25)), (0, 2.4, 0)), (length - 0.8, 0.5, 0.5), rot)
        elif ground == "shop":
            s.box("GlassDark", add(mid, scale(out, 0.05)), (length - 1.2, 4.4, 0.06), rot, skip=("+z",))
            s.box("WindowLit", add(mid, scale(out, -0.05)), (length - 1.2, 4.4, 0.02), rot, skip=("+z",))
    if roof:
        for _ in range(rng.randint(1, 3)):
            rx = rng.uniform(x1 + 3, x2 - 3)
            rz = rng.uniform(z1 + 3, z2 - 3)
            kind = rng.random()
            if kind < 0.4:
                s.cylinder("DarkMetal", (rx, h + 3, rz), 2.0, 3.5, 12)
                for dx, dz in ((-1.4, -1.4), (1.4, -1.4), (1.4, 1.4), (-1.4, 1.4)):
                    s.tube("BlackMetal", (rx + dx, h + 1.2, rz + dz), (rx + dx, h + 3, rz + dz), 0.1, 4)
            elif kind < 0.8:
                s.box("WhiteTrim", (rx, h + 2.0, rz), (3, 1.8, 2), skip=("-y",))
                s.cylinder("DarkMetal", (rx, h + 2.9, rz), 0.7, 0.1, 10)
            else:
                s.tube("BlackMetal", (rx, h + 1.2, rz), (rx, h + 9, rz), 0.08, 4)
                s.box("NeonRed", (rx, h + 9, rz), (0.3, 0.3, 0.3))


def vertical_sign(s, x, y, z, rot, text, mat, h=None, w=1.8, font="GothamBlack"):
    """A lit vertical sign sticking out from a wall, one character per line."""
    chars = [c for c in text if c != " "]
    h = h or len(chars) * 1.7 + 0.6
    s.box("BlackTrim", (x, y, z), (0.5, h + 0.3, w + 0.3), rot)
    turn = ry(rot)
    for side in (-1, 1):
        off = turn((side * 0.27, 0, 0))
        s.box(mat, (x + off[0], y, z + off[2]), (0.04, h, w), rot)
        p = turn((side * 0.31, 0, 0))
        s.sign((x + p[0], y, z + p[2]), rot + (90 if side < 0 else -90), w - 0.2, h - 0.2, "\n".join(chars), font,
               (20, 16, 18), None)
    s.light("point", (x, y, z), NEON_RGB.get(mat, (255, 255, 255)), 14, 1.0)


def box_sign(s, x, y, z, rot, w, h, text, mat, font="Bangers", text_color=(255, 255, 255)):
    """A lit sign box on a wall (the text on a glowing face)."""
    turn = ry(rot)
    back = turn((0, 0, -0.35))
    s.box("BlackTrim", (x + back[0], y, z + back[2]), (w + 0.4, h + 0.4, 0.7), rot)
    face = turn((0, 0, -0.72))
    s.box(mat, (x + face[0], y, z + face[2]), (w, h, 0.04), rot)
    text_at = turn((0, 0, -0.76))
    s.sign((x + text_at[0], y, z + text_at[2]), rot, w - 0.4, h - 0.4, text, font, text_color, None)
    lamp = turn((0, 0, -2.0))
    s.light("point", (x + lamp[0], y, z + lamp[2]), NEON_RGB.get(mat, (255, 255, 255)), 16, 1.1)


def awning(s, x, y, z, rot, w, depth=2.4, mat="FabricRed", stripes=None):
    turn = ry(rot)
    out = turn((0, 0, -1))
    along = turn((1, 0, 0))
    top = (x, y, z)
    low = add((x, y - 1.1, z), scale(out, depth))
    ux = along
    d = norm(sub(low, top))
    uy = norm(cross(d, ux))
    if uy[1] < 0:
        uy = scale(uy, -1)
    uz = norm(cross(ux, uy))
    mid = scale(add(top, low), 0.5)
    s.obox(mat, mid, (w, 0.08, math.dist(top, low)), ux, uy, uz)
    if stripes:
        count = int(w / 1.2)
        for i in range(0, count, 2):
            u = -w / 2 + (i + 0.5) * w / count
            s.obox(stripes, add(add(mid, scale(ux, u)), scale(uy, 0.05)), (w / count, 0.02, math.dist(top, low)), ux, uy, uz)
    s.box(mat, add(low, (0, -0.25, 0)), (w, 0.5, 0.06), rot)


def noren(s, x, y, z, rot, w=6.0, h=2.4, mat="FabricRed", panels=4):
    turn = ry(rot)
    s.box("Wood", (x, y + 0.1, z), (w + 0.4, 0.15, 0.15), rot)
    for i in range(panels):
        u = -w / 2 + (i + 0.5) * w / panels
        p = turn((u, 0, -0.1))
        s.box(mat, (x + p[0], y - h / 2, z + p[2]), (w / panels - 0.12, h, 0.04), rot)


def lantern(s, x, y, z, mat="NeonRed", r=0.7):
    s.lathe(mat, (x, y - r * 1.3, z), [(0.25 * r, 0), (0.85 * r, 0.25 * r), (r, 1.3 * r), (0.85 * r, 2.35 * r),
                                     (0.25 * r, 2.6 * r)], 12)
    s.cylinder("BlackTrim", (x, y - r * 1.4, z), 0.3 * r, 0.15, 10)
    s.cylinder("BlackTrim", (x, y + r * 1.25, z), 0.3 * r, 0.15, 10)
    s.tube("BlackMetal", (x, y + r * 1.4, z), (x, y + r * 2.2, z), 0.03, 4)


def utility_pole(s, x, z, h=13.0, rot=0.0):
    s.cylinder("ConcreteDark", (x, 0, z), 0.4, h, 10, radius_top=0.3)
    turn = ry(rot)
    arms = []
    for y, w in ((h - 0.8, 3.4), (h - 2.2, 2.6)):
        a = add((x, y, z), turn((-w / 2, 0, 0)))
        b = add((x, y, z), turn((w / 2, 0, 0)))
        s.tube("DarkMetal", a, b, 0.09, 4)
        arms.append((a, b))
        for p in (a, b, (x, y, z)):
            s.cylinder("WhiteTrim", add(p, (0, 0.05, 0)), 0.1, 0.3, 6)
    s.cylinder("DarkMetal", add((x, h - 4.5, z), turn((0, 0, 0.7))), 0.55, 1.4, 10)
    s.collider((x, h / 2, z), (0.8, h, 0.8))
    return [arms[0][0], arms[0][1], (x, h - 2.2 + 0.3, z)]


def wires(s, a_points, b_points, sag=1.4, segments=8):
    """Sagging cables between the tops of two poles."""
    for a, b in zip(a_points, b_points):
        prev = a
        for k in range(1, segments + 1):
            t = k / segments
            p = (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t - sag * 4 * t * (1 - t), a[2] + (b[2] - a[2]) * t)
            s.tube("BlackTrim", prev, p, 0.04, 3, caps=False)
            prev = p


def traffic_light(s, x, z, rot, reach=4.0, h=7.0, lit="NeonRed"):
    """A pole with an arm over the road carrying a horizontal signal head, plus a walk signal."""
    s.cylinder("DarkMetal", (x, 0, z), 0.25, h, 10)
    turn = ry(rot)
    tip = add((x, h - 0.3, z), turn((0, 0, -reach)))
    s.tube("DarkMetal", (x, h - 0.3, z), tip, 0.12, 6)
    head = add(tip, (0, -0.6, 0))
    s.box("BlackTrim", head, (3.0, 1.0, 0.8), rot)
    for i, mat in enumerate(("NeonGreen", "NeonYellow", "NeonRed")):
        p = add(head, turn((-1.0 + i * 1.0, 0, -0.42)))
        s.cylinder(mat if mat == lit else "DarkMetal", (p[0], p[1] - 0.3, p[2]), 0.3, 0.05, 10)
    s.box("BlackTrim", (x, 3.2, z), (0.8, 1.6, 0.6), rot)
    walk = add((x, 3.6, z), turn((0, 0, -0.31)))
    s.box("NeonRed", walk, (0.6, 0.6, 0.02), rot)
    s.collider((x, h / 2, z), (0.6, h, 0.6))


def bicycle(s, x, z, rot):
    turn = ry(rot)
    for u in (-0.9, 0.9):
        c = add((x, 0.75, z), turn((0, 0, u)))
        right = turn((1, 0, 0))
        pts = []
        for k in range(16):
            a = 2 * math.pi * k / 16
            pts.append(add(c, add(scale(turn((0, 0, 1)), math.cos(a) * 0.7), (0, math.sin(a) * 0.7, 0))))
        for k in range(16):
            s.tube("BlackTrim", pts[k], pts[(k + 1) % 16], 0.05, 4, caps=False)
        del right
    front = add((x, 0.75, z), turn((0, 0, -0.9)))
    back = add((x, 0.75, z), turn((0, 0, 0.9)))
    seat = add((x, 1.9, z), turn((0, 0, 0.35)))
    bar = add((x, 2.0, z), turn((0, 0, -0.7)))
    for a, b in ((back, seat), (seat, bar), (bar, front), (back, add((x, 0.9, z), turn((0, 0, -0.1)))),
                 (add((x, 0.9, z), turn((0, 0, -0.1))), seat), (add((x, 0.9, z), turn((0, 0, -0.1))), bar)):
        s.tube("RedTrim", a, b, 0.05, 4)
    s.box("BlackTrim", seat, (0.3, 0.1, 0.6), rot)
    s.box("Steel", bar, (1.1, 0.06, 0.06), rot)


def guardrail(s, a, b, h=2.0, mat="WhiteTrim", posts=4.0):
    length = math.dist(a, b)
    count = max(1, round(length / posts))
    for i in range(count + 1):
        p = (a[0] + (b[0] - a[0]) * i / count, 0, a[1] + (b[1] - a[1]) * i / count)
        s.cylinder(mat, p, 0.08, h, 6)
    for y in (h - 0.1, h * 0.55):
        s.tube(mat, (a[0], y, a[1]), (b[0], y, b[1]), 0.07, 6)
    _, t, n, rot = kit.wall_frame(a, b)
    s.collider(((a[0] + b[0]) / 2, h / 2, (a[1] + b[1]) / 2), (length, h, 0.3), rot)


def shelves(s, x, z, rot, w, seed, h=5.5, d=1.6):
    """A konbini shelf unit stocked with colourful products on both sides."""
    rng = random.Random(seed)
    turn = ry(rot)
    s.box("WhiteTrim", (x, h / 2, z), (w, h, 0.3), rot, collide=False)
    s.collider((x, h / 2, z), (w, h, d), rot)
    colours = ["RedTrim", "NeonYellow", "WhiteTrim", "NeonGreen", "NeonBlue", "CreamTrim", "NeonOrange", "BlackTrim",
               "NeonPink"]
    for side in (-1, 1):
        for level in range(4):
            y = 0.3 + level * 1.3
            shelf = add((x, y, z), turn((0, 0, side * d / 4)))
            s.box("Steel", shelf, (w, 0.08, d / 2), rot)
            u = -w / 2 + 0.2
            while u < w / 2 - 0.4:
                pw = rng.uniform(0.3, 0.7)
                ph = rng.uniform(0.4, 0.9)
                mat = rng.choice(colours)
                if mat.startswith("Neon"):
                    mat = {"NeonYellow": "Brass", "NeonGreen": "Foliage", "NeonBlue": "DarkMetal", "NeonOrange": "RedTrim",
                           "NeonPink": "FabricRed"}[mat]
                p = add((x, y + 0.04 + ph / 2, z), turn((u + pw / 2, 0, side * d / 4)))
                s.box(mat, p, (pw - 0.05, ph, d / 2 - 0.2), rot)
                u += pw
