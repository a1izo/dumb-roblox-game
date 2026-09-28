"""The campus fit-out kit, copied from Agency HQ's (agency/fit.py), not imported, so each venue can
change its own:
- partitions with doors and glass (clear glass lets a letter flash through; frosted glass,
  closed blinds and walls do not);
- closed doors and plaques;
- counters and tables built with the scene, so a sheet of paper rests exactly on them;
- stairs that are solid underneath with an invisible guard over their rails, balcony
  railings;
- ceiling fittings;
- desks whose lamps really light.

Added here:
- a stair foot closed with a rope and a sign;
- the build check that keeps every station's worker side clear.

Rotations follow the map kit: rot 0 faces -Z, 90 faces -X, 180 faces +Z, -90 faces +X. A wall
from a to b has its "n" side at (dz, -dx) of its direction: north for a wall running east, east
for one running south."""

import math

from maps import catalog, city, kit
from maps import geo2d as g2

WARM = (255, 214, 170)
LAMP = (255, 206, 150)
COOL = (200, 216, 255)
DOOR_H = 8.4
GUARD = 12.0  # the invisible wall over a railing or a stair's rail: nobody climbs over


def facing(dx, dz):
    """The rot that faces direction (dx, dz)."""
    return math.degrees(math.atan2(-dx, -dz))


def turn(rot, lx, lz):
    """A local (x, z) offset turned by rot (the map kit's ry)."""
    a = math.radians(rot)
    return (lx * math.cos(a) + lz * math.sin(a), -lx * math.sin(a) + lz * math.cos(a))


# Walls -------------------------------------------------------------------------------------------------

GLASS = {
    # kind: (pane material, blinds, a flash passes)
    "clear": ("Glass", False, True),
    "frosted": ("GlassFrosted", False, False),
    "blinds": ("Glass", True, False),
}


def partition(s, a, b, y0, y1, mat_n="PlasterLight", mat_s="PlasterLight", doors=(), glass=None, spans=None,
              sill=3.2, head=9.4, thick=0.6, trim=True, core=None, door_frame="DarkMetal"):
    """An inner wall from a to b (x, z) between floor y0 and ceiling y1. doors: [(distance from a
    to the door's middle, width)]. glass: a GLASS kind for windows along the wall above waist
    height, all along it between the doors, or only over spans [(u0, u1)] when given."""
    length = math.dist(a, b)
    ops = []
    for at, w in doors:
        ops.append({"at": at, "w": w, "bottom": y0, "top": y0 + DOOR_H, "kind": "door", "frame": door_frame,
                    "casing": 0.3})
    if glass:
        pane, blinds, through = GLASS[glass]
        if spans is None:
            cuts = sorted((at - w / 2 - 0.8, at + w / 2 + 0.8) for at, w in doors)
            spans, cursor = [], 0.6
            for c0, c1 in cuts:
                spans.append((cursor, c0))
                cursor = c1
            spans.append((cursor, length - 0.6))
        for u0, u1 in spans:
            if u1 - u0 < 1.4:
                continue
            ops.append({"at": (u0 + u1) / 2, "w": u1 - u0, "bottom": y0 + sill, "top": y0 + head, "kind": "window",
                        "frame": "BlackMetal", "mullions": "BlackMetal", "cols": max(1, round((u1 - u0) / 4.5)),
                        "rows": 1, "glass": pane, "blinds": blinds, "blinds_side": 1, "slat": "CreamTrim",
                        "sill": "BlackMetal", "casing": 0.2, "see_through": through})
    trims = {"base": "BlackTrim"} if trim else None
    kit.wall(s, a, b, y1, thick=thick, base=y0, core=core or mat_n, side_n=mat_n, side_s=mat_s, openings=ops,
             trim_n=trims, trim_s=trims)


def closed_door(s, x, z, rot, y=0.0, w=4.0, leaf="WoodPanel", sign=None):
    """A shut door flat on a wall face (x, z at the face, rot facing out of it): frame, leaf, a
    handle, and an optional plate over it."""
    back = turn(rot, 0, -0.08)
    s.box("DarkMetal", (x + back[0], y + DOOR_H / 2 + 0.15, z + back[1]), (w + 0.6, DOOR_H + 0.3, 0.16), rot)
    front = turn(rot, 0, -0.18)
    s.box(leaf, (x + front[0], y + DOOR_H / 2, z + front[1]), (w, DOOR_H, 0.1), rot)
    h = turn(rot, w / 2 - 0.5, -0.3)
    s.box("Steel", (x + h[0], y + 3.6, z + h[1]), (0.12, 0.5, 0.12), rot)
    if sign:
        p = turn(rot, 0, -0.26)
        s.box("BlackTrim", (x + p[0], y + DOOR_H + 1.0, z + p[1]), (w * 0.8, 0.8, 0.06), rot)
        q = turn(rot, 0, -0.3)
        s.sign((x + q[0], y + DOOR_H + 1.0, z + q[1]), rot, w * 0.75, 0.7, sign, "GothamBold", (230, 230, 230), None)


def plaque(s, x, y, z, rot, w, h, text, fg=(236, 232, 220), bg=(24, 24, 28), glow=None, font="GothamBold"):
    """A sign board on a wall face (room names, directions)."""
    p = turn(rot, 0, -0.06)
    s.box("BlackTrim", (x + p[0], y, z + p[1]), (w + 0.2, h + 0.2, 0.08), rot)
    q = turn(rot, 0, -0.12)
    s.sign((x + q[0], y, z + q[1]), rot, w, h, text, font, fg, bg, glow=glow)


# Furniture made with the scene --------------------------------------------------------------------------


def counter(s, x, z, rot, w, d=2.4, h=3.5, y=0.0, top="WhiteTrim", body="PlasterGrey"):
    s.box(body, (x, y + h / 2 - 0.05, z), (w, h - 0.1, d), rot)
    s.box(top, (x, y + h - 0.05, z), (w + 0.2, 0.1, d + 0.2), rot)
    s.collider((x, y + h / 2, z), (w, h, d), rot, True, body)
    return y + h + 0.05


def table(s, x, z, w, d, rot=0.0, y=0.0, top="Wood", legs="BlackMetal", h=2.75):
    """A table (its top at y + 2.8, where sheets of paper rest)."""
    s.box(top, (x, y + h - 0.1, z), (w, 0.2, d), rot)
    for dx in (-w / 2 + 0.3, w / 2 - 0.3):
        for dz in (-d / 2 + 0.3, d / 2 - 0.3):
            p = turn(rot, dx, dz)
            s.box(legs, (x + p[0], y + (h - 0.2) / 2, z + p[1]), (0.2, h - 0.2, 0.2), rot)
    s.collider((x, y + h / 2 + 0.025, z), (w, h + 0.05, d), rot, True, top)
    return y + h + 0.05


def chairs_round(s, x, z, w, d, rot=0.0, y=0.0, key="Chair"):
    """Chairs at a table's two long sides, facing it."""
    for side in (1, -1):
        for k in (-1, 1) if w > 4.5 else (0,):
            p = turn(rot, k * w / 4, side * (d / 2 + 1.2))
            s.prop(key, x + p[0], z + p[1], rot + (0 if side > 0 else 180), 1.0, y)


# Where the base Desk prop's lamp bulb is, from the desk's middle (Roblox local x, y, z).
DESK_LAMP = (2.4, 3.8, 0.06)


def desk(s, x, z, rot, y=0.0, lamp=True, chair=True, key="Desk"):
    """A desk (its CRT, papers and lamp), its chair on the side it faces, and the lamp's light."""
    s.prop(key, x, z, rot, 1.0, y)
    if chair:
        c = turn(rot, 0, -2.9)
        s.prop("OfficeChair", x + c[0], z + c[1], rot + 180, 1.0, y)
    if lamp:
        lx, ly, lz = DESK_LAMP
        p = turn(rot, lx, lz)
        s.light("point", (x + p[0], y + ly, z + p[1]), LAMP, 13, 0.8)


# Lights -------------------------------------------------------------------------------------------------

# After hours, but readable: the fittings left on light a little further and brighter than their
# nominal values (the game scales every lamp again by the map's preset).
ROOM_BRIGHTNESS = 1.35
ROOM_RANGE = 1.25


def panel(s, x, z, ceiling, w=4.0, d=1.2, color=WARM, range_=18, brightness=0.9, rot=0.0, on=True):
    """A frosted ceiling panel; off after hours unless on (the fitting is there either way)."""
    s.box("DarkMetal", (x, ceiling - 0.08, z), (w + 0.3, 0.16, d + 0.3), rot, skip=("+y",))
    if on:
        glow = "PanelWarm" if color[0] > color[2] else "PanelCool"
        s.box(glow, (x, ceiling - 0.17, z), (w, 0.04, d), rot, skip=("+y",))
        s.light("point", (x, ceiling - 1.0, z), color, range_ * ROOM_RANGE, brightness * ROOM_BRIGHTNESS)
    else:
        s.box("TubeDiffuser", (x, ceiling - 0.17, z), (w, 0.04, d), rot, skip=("+y",))


def downlight(s, x, z, ceiling, color=WARM, range_=16, brightness=0.8, angle=90):
    """A small round downlight in the ceiling, lighting straight down."""
    s.cylinder("DarkMetal", (x, ceiling - 0.12, z), 0.55, 0.12, 12)
    s.cylinder("NeonWarm" if color[0] > color[2] else "NeonCool", (x, ceiling - 0.16, z), 0.4, 0.04, 12)
    s.light("spot", (x, ceiling - 0.4, z), color, range_ * ROOM_RANGE, brightness * ROOM_BRIGHTNESS, False, "Bottom",
            angle)


def wall_lamp(s, x, y, z, rot, color=WARM, range_=16, brightness=0.8):
    """A caged bulkhead lamp on a wall face (doors outside, service corners)."""
    p = turn(rot, 0, -0.2)
    s.box("BlackMetal", (x + p[0], y, z + p[1]), (1.4, 0.8, 0.4), rot)
    q = turn(rot, 0, -0.42)
    s.box("NeonCool" if color[2] >= color[0] else "NeonWarm", (x + q[0], y, z + q[1]), (1.1, 0.5, 0.04), rot)
    r = turn(rot, 0, -1.0)
    s.light("point", (x + r[0], y, z + r[1]), color, range_, brightness)


def exit_sign(s, x, y, z, rot):
    kit.exit_sign(s, x, y, z, rot)
    p = turn(rot, 0, -0.6)
    s.light("point", (x + p[0], y, z + p[1]), (120, 255, 160), 8, 0.4)


# Stairs and rails ----------------------------------------------------------------------------------------


def stairs(s, g, a, b, y0, y1, width, mat="Stone", side_mat="Stone", step=0.7, rails=(True, True),
           rail_mat="BlackMetal", glass=None):
    """A straight flight from a (at y0) to b (at y1), solid under its steps (nobody walks into
    its side or under it) with rails on the sides asked for and an invisible guard over them."""
    city.stairs(s, g, a, b, y0, y1, width, mat, side_mat, step=step)
    run = math.dist(a, b)
    d = ((b[0] - a[0]) / run, (b[1] - a[1]) / run)
    n = g2.normal_left(d)
    rot = g2.rot_of(n)
    rise = y1 - y0
    count = max(2, round(abs(rise) / 0.7))
    low = min(y0, y1)
    for i in range(count):
        t0, t1 = i / count, (i + 1) / count
        c = (a[0] + d[0] * run * (t0 + t1) / 2, a[1] + d[1] * run * (t0 + t1) / 2)
        under = min(y0 + rise * t0, y0 + rise * t1) - 0.2 - low
        if under > 0.4:
            s.collider((c[0], low + under / 2, c[1]), (width, under, run / count), rot, False, None)
        top = max(y0 + rise * t0, y0 + rise * t1)
        for side, on in zip((1, -1), rails):
            if on:
                p = (c[0] + n[0] * side * (width / 2 + 0.15), c[1] + n[1] * side * (width / 2 + 0.15))
                s.collider((p[0], top + GUARD / 2, p[1]), (0.3, GUARD, run / count + 0.05), rot, False, None)
    for side, on in zip((1, -1), rails):
        if not on:
            continue
        p = (a[0] + n[0] * side * (width / 2 - 0.1), a[1] + n[1] * side * (width / 2 - 0.1))
        q = (b[0] + n[0] * side * (width / 2 - 0.1), b[1] + n[1] * side * (width / 2 - 0.1))
        s.tube(rail_mat, (p[0], y0 + 3.4, p[1]), (q[0], y1 + 3.4, q[1]), 0.1, 8)
        if glass:
            pts = [(p[0], y0 + 0.4, p[1]), (q[0], y1 + 0.4, q[1]), (q[0], y1 + 3.3, q[1]), (p[0], y0 + 3.3, p[1])]
            s.polygon(glass, pts)
            s.polygon(glass, pts[::-1])
        else:
            for t in (0.0, 0.25, 0.5, 0.75, 1.0):
                x = p[0] + (q[0] - p[0]) * t
                z = p[1] + (q[1] - p[1]) * t
                yy = y0 + rise * t
                s.tube(rail_mat, (x, yy, z), (x, yy + 3.4, z), 0.06, 6, caps=False)


def balcony(s, points, y, glass="Glass", mat="BlackMetal", h=3.6, guard=True, rails="Wood"):
    """A balustrade along a floor's edge (glass panes in a timber and iron frame) with the
    invisible guard over it (a flash seen through it passes: its collider lets sight lines
    through)."""
    for i in range(len(points) - 1):
        a, b = points[i], points[i + 1]
        length = math.dist(a, b)
        if length < 0.1:
            continue
        mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
        rot = g2.rot_of(((b[0] - a[0]) / length, (b[1] - a[1]) / length))
        s.box(glass, (mid[0], y + h / 2, mid[1]), (length, h - 0.4, 0.06), rot)
        s.box(rails, (mid[0], y + h, mid[1]), (length + 0.1, 0.2, 0.3), rot)
        s.box(mat, (mid[0], y + 0.15, mid[1]), (length, 0.3, 0.24), rot)
        count = max(1, round(length / 4.0))
        for k in range(count + 1):
            px = a[0] + (b[0] - a[0]) * k / count
            pz = a[1] + (b[1] - a[1]) * k / count
            s.box(mat, (px, y + h / 2, pz), (0.16, h, 0.16), rot)
        s.collider((mid[0], y + h / 2, mid[1]), (length, h, 0.4), rot, False, None)
        if guard:
            s.collider((mid[0], y + h + GUARD / 2, mid[1]), (length, GUARD, 0.4), rot, False, None)


def railing(s, points, y, h=3.4, mat="BlackMetal", guard=GUARD):
    """An iron rail (a slope's or a bridge's edge), solid for movement, with its guard."""
    for i in range(len(points) - 1):
        a, b = points[i], points[i + 1]
        kit.railing(s, [a, b], h=h, mat=mat, base=y, collide=False)
        length = math.dist(a, b)
        mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
        rot = g2.rot_of(((b[0] - a[0]) / length, (b[1] - a[1]) / length))
        s.collider((mid[0], y + h / 2, mid[1]), (length, h, 0.4), rot, False, None)
        if guard:
            s.collider((mid[0], y + h + guard / 2, mid[1]), (length, guard, 0.4), rot, False, None)


def roped_off(s, a, b, y=0.0, text="関係者以外立入禁止  STAFF ONLY"):
    """A stair foot (or any opening) closed with a rope between two brass posts and a small sign
    on a stand; an invisible wall across it."""
    length = math.dist(a, b)
    d = ((b[0] - a[0]) / length, (b[1] - a[1]) / length)
    rot = g2.rot_of(d)
    for p in (a, b):
        s.cylinder("Brass", (p[0], y, p[1]), 0.35, 0.1, 10)
        s.cylinder("Brass", (p[0], y + 0.1, p[1]), 0.08, 2.8, 8)
        s.lathe("Brass", (p[0], y + 2.9, p[1]), [(0.0, 0.0), (0.16, 0.05), (0.14, 0.25), (0.0, 0.3)], 8)
    sag = [(a[0] + (b[0] - a[0]) * t, y + 2.7 - 0.6 * math.sin(math.pi * t), a[1] + (b[1] - a[1]) * t)
           for t in (0.0, 0.25, 0.5, 0.75, 1.0)]
    for p, q in zip(sag, sag[1:]):
        s.tube("FabricRed", p, q, 0.08, 6)
    mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
    n = g2.normal_left(d)
    sign_at = (mid[0] - n[0] * 0.6, mid[1] - n[1] * 0.6)
    face = g2.rot_of(d)
    s.box("BlackMetal", (sign_at[0], y + 0.8, sign_at[1]), (0.1, 1.6, 0.1), face)
    s.box("CreamTrim", (sign_at[0], y + 2.0, sign_at[1]), (2.6, 0.9, 0.06), face)
    back = (sign_at[0] - n[0] * 0.05, sign_at[1] - n[1] * 0.05)
    s.sign((back[0], y + 2.0, back[1]), facing(-n[0], -n[1]), 2.4, 0.7, text, "GothamBold", (40, 30, 26), None)
    s.collider((mid[0], y + 6.0, mid[1]), (length, 12.0, 0.6), rot, False, None)


def floor_faces(s, poly, y, mat, holes=()):
    """The visible floor of a room (convex pieces, minus holes) at y."""
    pieces = g2.subtract_all([g2.ccw(p) for p in g2.convex_pieces(poly)], [g2.ccw(h) for h in holes])
    for piece in pieces:
        if abs(g2.area(piece)) > 0.05:
            city.up_face(s, mat, piece, y)


def ceiling_faces(s, poly, y, mat, holes=()):
    pieces = g2.subtract_all([g2.ccw(p) for p in g2.convex_pieces(poly)], [g2.ccw(h) for h in holes])
    for piece in pieces:
        if abs(g2.area(piece)) > 0.05:
            city.down_face(s, mat, piece, y)


# The build check: every station's worker side stays clear -------------------------------------------------

CLEAR = 5.0  # studs round the worker spot, on the station's working side
WORKER = 2.6  # the worker spot, in front of the station's middle (check_v2)


def clear_of_stations(s):
    """Fails the build when a collidable prop or a piece of furniture (a collider low enough to
    be furniture, not a wall or a floor) stands within CLEAR studs of a station's worker spot, on
    the side the station faces. Walls count only when they stand in front of the worker."""
    cat = catalog.load()
    stations = s.layout["stations"] + s.spare["stations"]
    problems = []
    obstacles = []
    for key, x, y, z, rot, sc, *_ in s.props:
        info = cat.get(key)
        if not info or not info["collide"] or key.startswith("Station"):
            continue
        sx, sy, sz = (v * sc for v in info["size"])
        obstacles.append((key, g2.rect(x, z, sx, sz, rot), y, y + sy, False))
    for c in s.colliders:
        x, y, z, sx, sy, sz, rot, query, look = c
        if not query or sy < 0.6:
            continue
        wall = max(sx, sz) > 12.0 or sy > 9.0 or min(sx, sz) <= 1.0  # walls, and the sills under glass
        obstacles.append((look or "a blocker", g2.rect(x, z, sx, sz, rot), y - sy / 2, y + sy / 2, wall))
    for st in stations:
        fx, fz = turn(st["rot"], 0, -1)
        wx, wz = st["x"] + fx * WORKER, st["z"] + fz * WORKER
        desk_poly = g2.rect(st["x"], st["z"], 5.2, 3.2, st["rot"])
        points = []
        steps = int(CLEAR / 0.5)
        for i in range(-steps, steps + 1):
            for j in range(-steps, steps + 1):
                px, pz = wx + i * 0.5, wz + j * 0.5
                if math.hypot(px - wx, pz - wz) > CLEAR:
                    continue
                ahead = (px - st["x"]) * fx + (pz - st["z"]) * fz
                if ahead < 1.6:  # behind the station's front: its own desk and the wall it backs on
                    continue
                points.append((px, pz, (px - wx) * fx + (pz - wz) * fz))
        for name, poly, y0, y1, wall in obstacles:
            if y1 < st["y"] + 0.5 or y0 > st["y"] + 5.0:
                continue
            if g2.intersect(g2.ccw(poly), g2.ccw(desk_poly)):
                continue  # the station's own collider, or what it stands on
            box = g2.bbox(poly)
            for px, pz, forward in points:
                if wall and forward < 0.5:
                    continue
                if box[0] <= px <= box[2] and box[1] <= pz <= box[3] and g2.contains(poly, (px, pz)):
                    problems.append(f"{st['name']}: {name} within {CLEAR:.0f} studs of its worker spot "
                                    f"(near {px:.1f}, {pz:.1f})")
                    break
    if problems:
        raise ValueError("stations not clear:\n  " + "\n  ".join(sorted(set(problems))))
