"""Buildings for the big map scenes, at real scale: a ground floor of 14 studs and 12 studs for
every floor above it (a player is about 5.2 studs tall).

A building is given as the plans give it: a footprint polygon [(x, z)], a number of floors, a kind
and a style (see STYLE_KEYS below; venues/tokyo/plan.py sets them per building). build() makes:

- the body: every wall of the footprint, dressed in the style's cladding with windows sized to
  12-stud floors (recessed glass, frames and sills; lit, cool, curtained or dark rooms), floor
  bands, corner piers. Walls hidden against a neighbour stay plain, as blank side walls do.
- the ground floor: shutters, lit display windows or a lobby, with a fascia sign; or nothing when
  the building holds an interior (venues build the room there, with its doors).
- the roof: parapet, roof deck and rooftop plant (water tanks, AC units, a stair hut, antennas,
  billboards), and signs: stacked vertical signs on a corner, fascia and rooftop signs (the
  game draws their words).
- colliders: the solid body (from the first floor up where there is an interior).

massing() still draws a plain block at true height (layout reviews); far() a cheap block for the
city beyond the map.
"""

import math
import random

from maps import city
from maps import geo2d as g2

FLOOR_GF = 14.0
FLOOR_UP = 12.0
SILL = 3.0  # window sill above the floor
HEAD = 9.6  # window head above the floor
ROOM_DEPTH = 3.0  # the rooms behind the low windows
ROOMS_BELOW = 38.0  # windows whose sill is lower than this get a room behind clear glass
CORE_INSET = 4.5  # the dark core inside every body (deeper than any room or shop set)

STYLE_KEYS = (
    "clad",  # cladding material of the upper floors
    "trim",  # frames, bands, parapet caps
    "windows",  # "punched", "band", "curtain", "balcony", "tin"
    "bay",  # window bay width
    "lit",  # share of lit rooms
    "ground",  # "shutters", "display", "lobby", "interior", "tin"
    "fascia",  # (text, colour) for the ground floor's sign
    "vsign",  # [(text, colour), ...] stacked vertical signs on a front corner
    "roof",  # rooftop items: "tank", "ac", "hut", "antenna", ("billboard", text, colour)
    "screen",  # a giant screen on the front: (width, height)
)

SIGN_COLOURS = {
    "white": ((244, 240, 230), (24, 24, 28)),
    "yellow": ((250, 214, 70), (30, 24, 20)),
    "red": ((210, 30, 40), (255, 250, 240)),
    "pink": ((250, 110, 190), (255, 255, 255)),
    "blue": ((40, 110, 220), (255, 255, 255)),
    "green": ((40, 170, 100), (255, 255, 255)),
    "orange": ((250, 140, 40), (30, 20, 16)),
    "purple": ((150, 70, 200), (255, 255, 255)),
    "cyan": ((60, 210, 240), (20, 24, 30)),
    "black": ((24, 24, 28), (250, 214, 70)),
}


def height(floors):
    return FLOOR_GF + FLOOR_UP * (floors - 1)


def floor_levels(floors):
    """The height of every floor above the ground floor."""
    return [FLOOR_GF + FLOOR_UP * k for k in range(floors - 1)]


def grow(poly, d):
    """The polygon pushed outward by d (mitred corners)."""
    p = g2.ccw(poly)
    n = len(p)
    out = []
    for i in range(n):
        a, b, c = p[i - 1], p[i], p[(i + 1) % n]
        e0 = (b[0] - a[0], b[1] - a[1])
        e1 = (c[0] - b[0], c[1] - b[1])
        l0, l1 = math.hypot(*e0), math.hypot(*e1)
        # Counter-clockwise in the math plane: outside is to the right of each edge.
        n0 = (e0[1] / l0, -e0[0] / l0)
        n1 = (e1[1] / l1, -e1[0] / l1)
        m = (n0[0] + n1[0], n0[1] + n1[1])
        ml = math.hypot(*m)
        if ml < 1e-6:
            out.append((b[0] + n0[0] * d, b[1] + n0[1] * d))
            continue
        m = (m[0] / ml, m[1] / ml)
        k = d / max(0.25, m[0] * n0[0] + m[1] * n0[1])
        out.append((b[0] + m[0] * k, b[1] + m[1] * k))
    return out


class Edge:
    """One wall of a footprint: from a to b, running t, facing out along n (x, z)."""

    def __init__(self, a, b):
        self.a, self.b = a, b
        self.length = math.dist(a, b)
        self.t = ((b[0] - a[0]) / self.length, (b[1] - a[1]) / self.length)
        self.n = (self.t[1], -self.t[0])
        self.rot = g2.rot_of(self.t)
        self.party = 0.0  # height up to which a neighbour hides it (0: open)
        self.front = False

    def at(self, u, depth=0.0):
        return (self.a[0] + self.t[0] * u + self.n[0] * depth, self.a[1] + self.t[1] * u + self.n[1] * depth)

    def quad(self, s, mat, u0, u1, y0, y1, depth=0.0):
        """A face on the wall plane (pushed out by depth), facing out."""
        if u1 - u0 < 0.01 or y1 - y0 < 0.01:
            return
        city.vquad(s, mat, self.at(u0, depth), self.at(u1, depth), y0, y1, self.n)

    def box(self, s, mat, u, y, depth, size, skip=()):
        """A box on the wall: size (along, up, out), centred at u, y and depth out from the wall."""
        x, z = self.at(u, depth)
        s.box(mat, (x, y, z), size, self.rot, skip=skip)

    def niche(self, s, u0, u1, y0, y1, depth, side, back=None, floor=None, ceiling=None, front=0.0):
        """A closed recess in the wall from u0 to u1 and y0 to y1, from `front` back to `depth`
        (both measured into the wall): jambs, and a back, floor and soffit when given, every face
        looking into it, so nothing behind the wall can show through."""
        p0, p1 = self.at(u0, -front), self.at(u1, -front)
        q0, q1 = self.at(u0, -depth), self.at(u1, -depth)
        city.vquad(s, side, p0, q0, y0, y1, self.t)
        city.vquad(s, side, p1, q1, y0, y1, (-self.t[0], -self.t[1]))
        if ceiling:
            city.down_face(s, ceiling, [p0, q0, q1, p1], y1)
        if floor:
            city.up_face(s, floor, [p0, p1, q1, q0], y0)
        if back:
            self.quad(s, back, u0, u1, y0, y1, -depth)


def edges_of(poly):
    p = g2.ccw(poly)
    out = []
    for i in range(len(p)):
        a, b = p[i], p[(i + 1) % len(p)]
        if math.dist(a, b) > 0.3:
            out.append(Edge(a, b))
    return out


# Windows -------------------------------------------------------------------------------------------


def room_light(rng, lit):
    """What a window shows: a lit room, a cool-lit one (TV, office), curtains, or darkness."""
    r = rng.random()
    if r < lit * 0.7:
        return "lit"
    if r < lit:
        return "cool"
    if r < lit + 0.12:
        return "curtain"
    return "dark"


ROOM_LOOKS = {  # back, sides, floor, ceiling
    "lit": ("RoomLitBack", "RoomLitSide", "WoodFloor", "RoomLitCeiling"),
    "curtain": ("RoomLitBack", "RoomLitSide", "WoodFloor", "RoomLitCeiling"),
    "cool": ("RoomCoolBack", "RoomCoolSide", "CarpetGrey", "RoomCoolCeiling"),
    "dark": ("RoomDark", "RoomDark", "RoomDark", "RoomDark"),
}


def fake_room(s, e, u0, u1, y0, y1, depth, look, rng):
    """A shallow room behind clear glass: its back wall, sides, floor (at the floor level, a sill
    below the window) and ceiling, lit or dark, now and then a piece of furniture against the
    back and a ceiling light."""
    back, side, floor, ceiling = ROOM_LOOKS[look]
    lo, hi = y0 - SILL, y1 + 1.0
    w0, w1 = u0 - 0.5, u1 + 0.5
    e.niche(s, w0, w1, lo, hi, depth + ROOM_DEPTH, side, back=back, floor=floor, ceiling=ceiling, front=depth)
    if look in ("lit", "cool") and rng.random() < 0.6:
        # A desk, a shelf or a sofa against the back wall, in silhouette.
        kind = rng.random()
        mid = (u0 + u1) / 2 + rng.uniform(-0.6, 0.6)
        if kind < 0.4:
            e.box(s, "RoomDark", mid, lo + 1.3, -(depth + ROOM_DEPTH - 0.8), ((u1 - u0) * 0.5, 2.6, 1.4))
        elif kind < 0.7:
            e.box(s, "RoomDark", mid, lo + 3.0, -(depth + ROOM_DEPTH - 0.4), ((u1 - u0) * 0.6, 6.0, 0.8))
        else:
            e.box(s, "RoomDark", mid, lo + 1.0, -(depth + ROOM_DEPTH - 0.9), ((u1 - u0) * 0.7, 2.0, 1.6))
    if look == "lit" and rng.random() < 0.5:
        e.box(s, "NeonWarm", (u0 + u1) / 2, hi - 0.1, -(depth + ROOM_DEPTH / 2), ((u1 - u0) * 0.5, 0.12, 0.5))


def window(s, e, u0, u1, y0, y1, frame, rng, lit, depth=0.45, sill=True, mullion=True, room=False):
    """A recessed window between u0..u1 and y0..y1 on edge e, the glass set `depth` back. With
    room, clear glass and a shallow room behind it; without, an opaque pane that glows like a lit
    room, or shows a cool-lit or dark one."""
    look = room_light(rng, lit)
    if room:
        e.quad(s, "WindowGlass", u0, u1, y0, y1, -depth)
        fake_room(s, e, u0, u1, y0, y1, depth, look, rng)
        if look == "curtain":
            cut = u0 + (u1 - u0) * rng.uniform(0.3, 0.7)
            e.quad(s, rng.choice(("Fabric", "FabricRed", "CreamTrim")), u0, cut, y0, y1, -depth - 0.15)
    else:
        glass = {"lit": "WindowLit", "cool": "WindowCool", "curtain": "WindowLit", "dark": "WindowDark"}[look]
        e.quad(s, glass, u0, u1, y0, y1, -depth)
        if look == "curtain":
            # Curtains drawn across part of a lit room.
            cut = u0 + (u1 - u0) * rng.uniform(0.3, 0.7)
            e.quad(s, rng.choice(("Fabric", "FabricRed", "CreamTrim")), u0, cut, y0, y1, -depth + 0.05)
        elif look == "lit" and rng.random() < 0.5:
            # A ceiling light strip seen at the top of the room.
            e.quad(s, "NeonWarm", u0 + 0.3, u1 - 0.3, y1 - 0.5, y1 - 0.25, -depth + 0.03)
    # Reveals: the jambs and head of the opening, facing into it (and the bottom where no sill
    # covers it).
    p0, p1 = e.at(u0), e.at(u1)
    q0, q1 = e.at(u0, -depth), e.at(u1, -depth)
    city.vquad(s, frame, p0, q0, y0, y1, e.t)
    city.vquad(s, frame, p1, q1, y0, y1, (-e.t[0], -e.t[1]))
    city.down_face(s, frame, [p0, q0, q1, p1], y1)
    if sill:
        e.box(s, frame, (u0 + u1) / 2, y0 - 0.12, 0.1, (u1 - u0 + 0.5, 0.24, 0.9 + depth))
    else:
        city.up_face(s, frame, [p0, p1, q1, q0], y0)
    if mullion and u1 - u0 > 3.2:
        e.box(s, frame, (u0 + u1) / 2, (y0 + y1) / 2, -depth + 0.08, (0.18, y1 - y0, 0.16))
    return look


# Walls ----------------------------------------------------------------------------------------------


def plain_wall(s, e, y0, y1, mat):
    e.quad(s, mat, 0, e.length, y0, y1)


def bays(length, bay, margin=1.4):
    """Window bays along a wall: [(u0, u1)] of each bay (between piers)."""
    usable = length - 2 * margin
    if usable <= 2.5:
        return []
    count = max(1, int(usable / bay))
    width = usable / count
    return [(margin + k * width, margin + (k + 1) * width) for k in range(count)]


def room_at(style, sill_y):
    """Whether a window with its sill at sill_y gets a room behind clear glass: the low floors,
    above any real room of an interior (build() sets rooms_from)."""
    return style.get("rooms_from", 0.0) <= sill_y - SILL < ROOMS_BELOW - SILL and sill_y < ROOMS_BELOW


def punched(s, e, y0, y1, levels, style, rng):
    """Walls with a window in every bay of every floor."""
    clad, trim = style["clad"], style["trim"]
    bay = style.get("bay", 7.0)
    win = min(bay - 1.6, style.get("win", 4.6))
    spans = bays(e.length, bay)
    if not spans:
        plain_wall(s, e, y0, y1, clad)
        return
    for k, level in enumerate(levels):
        top = levels[k + 1] if k + 1 < len(levels) else y1
        wy0, wy1 = level + SILL, min(level + HEAD, top - 1.0)
        # Wall strips below and above the windows, piers between them.
        e.quad(s, clad, 0, e.length, level, wy0)
        e.quad(s, clad, 0, e.length, wy1, top)
        cursor = 0.0
        for u0, u1 in spans:
            mid = (u0 + u1) / 2
            w0, w1 = mid - win / 2, mid + win / 2
            e.quad(s, clad, cursor, w0, wy0, wy1)
            window(s, e, w0, w1, wy0, wy1, trim, rng, style.get("lit", 0.45), room=room_at(style, wy0))
            cursor = w1
        e.quad(s, clad, cursor, e.length, wy0, wy1)
        # A band at the floor line.
        e.box(s, trim, e.length / 2, level + 0.15, 0.15, (e.length + 0.3, 0.3, 0.3))


def ribbon(s, e, y0, y1, levels, style, rng):
    """Continuous window bands between projecting floor slabs (offices)."""
    clad, trim = style["clad"], style["trim"]
    pane = style.get("bay", 4.0)
    for k, level in enumerate(levels):
        top = levels[k + 1] if k + 1 < len(levels) else y1
        wy0, wy1 = level + 3.4, min(level + 10.4, top - 0.8)
        e.quad(s, clad, 0, e.length, level, wy0)
        e.quad(s, clad, 0, e.length, wy1, top)
        e.box(s, clad, e.length / 2, level + 0.4, 0.45, (e.length + 0.9, 0.8, 0.9))
        if e.length < 3.0:
            e.quad(s, clad, 0, e.length, wy0, wy1)
            continue
        e.quad(s, clad, 0, 0.8, wy0, wy1)
        e.quad(s, clad, e.length - 0.8, e.length, wy0, wy1)
        u = 0.8
        while u + 0.5 < e.length - 0.8:
            u1 = min(e.length - 0.8, u + pane)
            window(s, e, u, u1, wy0, wy1, trim, rng, style.get("lit", 0.5), depth=0.3, sill=False, mullion=False,
                   room=room_at(style, wy0))
            e.box(s, trim, u1, (wy0 + wy1) / 2, 0.02, (0.25, wy1 - wy0, 0.25))
            u = u1


def curtain(s, e, y0, y1, levels, style, rng):
    """A glass curtain wall: a mullion grid over tinted glass, some floors lit behind it."""
    trim = style["trim"]
    lit = style.get("lit", 0.35)
    e.quad(s, "GlassDark", 0, e.length, y0, y1)
    e.quad(s, "CoreDark", 0, e.length, y0, y1, -0.6)
    for k, level in enumerate(levels):
        top = levels[k + 1] if k + 1 < len(levels) else y1
        e.box(s, trim, e.length / 2, level + 0.3, 0.15, (e.length, 0.6, 0.3))
        if rng.random() < lit and e.length > 2.0:
            e.quad(s, "WindowCool" if rng.random() < 0.6 else "WindowLit", 0.6, e.length - 0.6, level + 1.2,
                   top - 1.2, -0.05)
    step = style.get("bay", 4.0)
    count = max(1, round(e.length / step))
    for i in range(count + 1):
        e.box(s, trim, e.length * i / count, (y0 + y1) / 2, 0.15, (0.35, y1 - y0, 0.3))


def balconies(s, e, y0, y1, levels, style, rng):
    """Flats: a balcony across each bay of every floor, sliding doors behind, AC units and some
    washing hung out."""
    clad, trim = style["clad"], style["trim"]
    bay = style.get("bay", 9.0)
    spans = bays(e.length, bay, margin=0.8)
    if not spans:
        plain_wall(s, e, y0, y1, clad)
        return
    for k, level in enumerate(levels):
        top = levels[k + 1] if k + 1 < len(levels) else y1
        head = min(top, level + 9.8)
        e.quad(s, clad, 0, e.length, level, level + 1.0)
        e.quad(s, clad, 0, e.length, head, top)
        cursor = 0.0
        for u0, u1 in spans:
            e.quad(s, clad, cursor, u0 + 0.6, level + 1.0, head)
            window(s, e, u0 + 0.6, u1 - 0.6, level + 1.0, head, trim, rng, style.get("lit", 0.45), depth=0.4,
                   sill=False, room=room_at(style, level + 1.0 + SILL))
            cursor = u1 - 0.6
            mid = (u0 + u1) / 2
            width = u1 - u0 - 0.4
            e.box(s, "ConcreteDark", mid, level + 0.4, 1.6, (width, 0.8, 3.2))
            e.box(s, style.get("panel", clad), mid, level + 2.1, 3.1, (width, 2.6, 0.25))
            e.box(s, trim, mid, level + 3.6, 3.1, (width, 0.2, 0.3))
            if rng.random() < 0.6:
                e.box(s, "WhiteTrim", u0 + 1.6, level + 1.9, 1.2, (2.2, 1.8, 1.0))  # AC unit
            if rng.random() < 0.3:
                e.box(s, rng.choice(("FabricRed", "CreamTrim", "Fabric")), mid + 1.0, level + 5.0, 2.4,
                      (3.0, 1.8, 0.1))  # washing
        e.quad(s, clad, cursor, e.length, level + 1.0, head)


def tin(s, e, y0, y1, levels, style, rng):
    """Yokocho upper floors: tin or boards, a small window per bay."""
    clad, trim = style["clad"], style["trim"]
    for k, level in enumerate(levels):
        top = levels[k + 1] if k + 1 < len(levels) else y1
        e.quad(s, clad, 0, e.length, level, level + 4.0)
        e.quad(s, clad, 0, e.length, level + 8.5, top)
        u = 0.0
        for u0, u1 in bays(e.length, 6.0, margin=1.0):
            mid = (u0 + u1) / 2
            e.quad(s, clad, u, mid - 1.6, level + 4.0, level + 8.5)
            window(s, e, mid - 1.6, mid + 1.6, level + 4.0, level + 8.5, trim, rng, style.get("lit", 0.55), depth=0.3,
                   room=room_at(style, level + 4.0))
            u = mid + 1.6
        e.quad(s, clad, u, e.length, level + 4.0, level + 8.5)


FACADES = {"punched": punched, "band": ribbon, "curtain": curtain, "balcony": balconies, "tin": tin}


# The ground floor ---------------------------------------------------------------------------------------


def fascia(s, e, text, colour, y=11.4, h=3.0, u0=None, u1=None):
    """A lit shop sign board across a ground floor, the words drawn by the game."""
    u0 = 0.6 if u0 is None else u0
    u1 = e.length - 0.6 if u1 is None else u1
    if u1 - u0 < 2.0:
        return
    bg, fg = SIGN_COLOURS.get(colour, SIGN_COLOURS["white"])
    e.box(s, "BlackTrim", (u0 + u1) / 2, y, 0.35, (u1 - u0, h + 0.3, 0.7))
    x, z = e.at((u0 + u1) / 2, 0.75)
    s.sign((x, y, z), e.rot, u1 - u0 - 0.6, h - 0.4, text, "GothamBlack", fg, bg, glow=bg)


def shutters(s, e, style, rng):
    """Roll shutters down over closed shops, each in a closed recess (jambs, floor, the box
    over it), so there is no gap to see past."""
    spans = bays(e.length, 12.0, margin=0.8) or [(0.8, max(1.0, e.length - 0.8))]
    cursor = 0.0
    for u0, u1 in spans:
        a, b = u0 + 0.4, u1 - 0.4
        e.quad(s, style["clad"], cursor, a, 0, 9.4)
        e.niche(s, a, b, 0.0, 9.4, 0.3, style["clad"], floor="ConcreteDark", ceiling=style["trim"])
        e.quad(s, "Shutter", a, b, 0, 8.6, -0.3)
        e.quad(s, style["trim"], a, b, 8.6, 9.4, -0.3)
        e.box(s, "DarkMetal", (u0 + u1) / 2, 9.0, 0.2, (u1 - u0 - 0.8, 0.8, 0.6))
        cursor = b
    e.quad(s, style["clad"], cursor, e.length, 0, 9.4)
    e.quad(s, style["clad"], 0, e.length, 9.4, FLOOR_GF)


SHOP_SETS = [  # back wall, floor, shelf and goods colours of a shop seen through its window
    ("PlasterLight", "TileWhite", "WhiteTrim", ("RedTrim", "PaintYellow", "CreamTrim")),
    ("WoodPanel", "WoodFloor", "Wood", ("CreamTrim", "FabricRed", "BlackTrim")),
    ("PlasterGrey", "TileWhite", "Steel", ("NeonCyan", "WhiteTrim", "RedTrim")),
    ("Wallpaper", "WoodFloorDark", "Brass", ("CreamTrim", "Fabric", "PaintYellow")),
]
SET_DEPTH = 4.0


def shop_set(s, e, u0, u1, y0, y1, rng, lit=True):
    """A shop behind a window, SET_DEPTH deep: its back wall with shelves of goods, a floor, a
    ceiling with a light fitting (and its light), side walls."""
    back, floor, shelf, goods = rng.choice(SHOP_SETS)
    e.niche(s, u0, u1, y0, y1, SET_DEPTH, back, back=back, floor=floor, ceiling="Ceiling", front=0.3)
    width = u1 - u0
    for k, h in enumerate((2.2, 4.4, 6.6)):
        if h > y1 - y0 - 1.0:
            break
        e.box(s, shelf, (u0 + u1) / 2, y0 + h, -(SET_DEPTH - 0.6), (width - 0.6, 0.15, 1.0))
        n = max(2, int(width / 1.1))
        for i in range(n):
            if rng.random() < 0.25:
                continue
            u = u0 + 0.6 + (width - 1.2) * (i + 0.5) / n
            hh = rng.uniform(0.6, 1.4)
            e.box(s, rng.choice(goods), u, y0 + h + 0.08 + hh / 2, -(SET_DEPTH - 0.6), (0.7, hh, 0.6))
    if lit:
        e.box(s, "NeonWarm", (u0 + u1) / 2, y1 - 0.15, -SET_DEPTH / 2, (width * 0.6, 0.1, 0.6))
        x, z = e.at((u0 + u1) / 2, -SET_DEPTH / 2)
        s.light("point", (x, y1 - 1.0, z), (255, 220, 180), 12, 0.7)


def display(s, e, style, rng):
    """Lit shop windows with the shop behind them, a glass door between them."""
    spans = bays(e.length, 10.0, margin=0.8) or [(0.8, max(1.0, e.length - 0.8))]
    cursor = 0.0
    for i, (u0, u1) in enumerate(spans):
        a, b = u0 + 0.3, u1 - 0.3
        e.quad(s, style["trim"], cursor, a, 0, 9.4)
        if i == len(spans) // 2 and len(spans) > 1:
            e.quad(s, "WindowGlass", a, b, 0, 8.6, -0.3)
            shop_set(s, e, a, b, 0.0, 8.6, rng, lit=False)
        else:
            e.quad(s, "WindowGlass", a, b, 1.0, 8.6, -0.3)
            e.quad(s, style["trim"], a, b, 0, 1.0)
            shop_set(s, e, a, b, 0.0, 8.6, rng)
        e.quad(s, style["trim"], a, b, 8.6, 9.4)
        e.box(s, style["trim"], (u0 + u1) / 2, 8.9, 0.15, (u1 - u0, 0.6, 0.3))
        cursor = b
    e.quad(s, style["trim"], cursor, e.length, 0, 9.4)
    e.quad(s, style["clad"], 0, e.length, 9.4, FLOOR_GF)


def lobby(s, e, style, rng):
    """An office entrance: a glass front with the lit lobby behind (a stone floor, a reception
    counter against the back wall, a ceiling light), a canopy over the doors."""
    mid = e.length / 2
    w = min(12.0, e.length - 2.0)
    if w < 3:
        plain_wall(s, e, 0, FLOOR_GF, style["clad"])
        return
    a, b = mid - w / 2, mid + w / 2
    e.quad(s, style["clad"], 0, a, 0, FLOOR_GF)
    e.quad(s, style["clad"], b, e.length, 0, FLOOR_GF)
    e.quad(s, style["clad"], a, b, 10.0, FLOOR_GF)
    e.quad(s, "WindowGlass", a, b, 0, 10.0, -0.3)
    e.niche(s, a, b, 0.0, 10.0, SET_DEPTH, "PlasterLight", back="MarbleWhite", floor="MarbleWhite", ceiling="Ceiling",
            front=0.3)
    counter = min(6.0, w - 2.0)
    e.box(s, "WoodPanel", mid, 1.8, -(SET_DEPTH - 1.0), (counter, 3.6, 1.4))
    e.box(s, "MarbleBlack", mid, 3.65, -(SET_DEPTH - 1.0), (counter + 0.2, 0.1, 1.6))
    # Downlights over the desk, a tenant board on the back wall, potted plants by the glass.
    for du in (-w / 4, w / 4):
        e.box(s, "PanelWarm", mid + du, 9.9, -SET_DEPTH / 2, (1.2, 0.08, 1.2))
    x, z = e.at(mid, -SET_DEPTH / 2)
    s.light("point", (x, 8.6, z), (255, 222, 180), 14, 0.7)
    if w >= 8.0:
        bx, bz = e.at(a + 1.6, -(SET_DEPTH - 0.06))
        s.sign((bx, 6.2, bz), e.rot, 2.2, 3.0, "テナント\nご案内\n\n1F  受付\n2F-  各社", "GothamBlack",
               (230, 226, 214), (34, 36, 42), glow=None)
        for u in (a + 1.2, b - 1.2):
            px, pz = e.at(u, -1.4)
            potted_plant(s, px, pz)
    for k in range(5):
        u = a + w * k / 4
        e.box(s, "DarkMetal", u, 5.0, -0.2, (0.25, 10.0, 0.3))
    e.box(s, style["trim"], mid, 10.6, 2.0, (w + 2.0, 0.5, 4.0))


def potted_plant(s, x, z):
    """A tall potted plant for a lobby behind glass (drawn, not a prop: nobody reaches it)."""
    s.cylinder("BlackTrim", (x, 0.0, z), 0.7, 1.6, segments=10, radius_top=0.8)
    s.lathe("Foliage", (x, 1.4, z), [(0.2, 0.0), (0.9, 0.6), (1.1, 1.6), (0.8, 2.6), (0.0, 3.2)], 9)


def tin_front(s, e, style, rng):
    """A tiny bar's frontage: timber with a sliding door, the lit room behind it, an awning."""
    mid = e.length / 2
    half = min(2.2, e.length / 2 - 0.8)
    if half > 0.8:
        e.quad(s, "WoodPanel", 0, mid - half, 0, 9.0)
        e.quad(s, "WoodPanel", mid + half, e.length, 0, 9.0)
        e.quad(s, "WoodPanel", mid - half, mid + half, 7.6, 9.0)
        e.quad(s, "WindowGlass", mid - half, mid + half, 0, 7.6, -0.3)
        e.niche(s, mid - half, mid + half, 0.0, 7.6, SET_DEPTH, "RoomLitSide", back="RoomLitBack", floor="WoodFloorDark",
                ceiling="RoomLitCeiling", front=0.3)
        e.box(s, "Wood", mid, 7.9, 0.1, (half * 2 + 0.6, 0.3, 0.4))
        e.box(s, "Wood", mid, 1.8, -(SET_DEPTH - 0.8), (half * 2 - 0.4, 3.6, 1.2))  # the counter
    else:
        e.quad(s, "WoodPanel", 0, e.length, 0, 9.0)
    e.quad(s, style["clad"], 0, e.length, 9.0, FLOOR_GF)
    e.box(s, "Shutter", e.length / 2, 9.6, 0.7, (e.length, 0.25, 1.4))


GROUNDS = {"shutters": shutters, "display": display, "lobby": lobby, "tin": tin_front}


# Roofs, signs, screens ---------------------------------------------------------------------------------


def roof(s, poly, top, style, rng, edges):
    for piece in g2.convex_pieces(poly):
        city.up_face(s, "ConcreteDark", piece, top)
    trim = style["trim"]
    for e in edges:
        e.quad(s, style["clad"], 0, e.length, top, top + 1.6)
        # The parapet's inner face and its cap.
        city.vquad(s, "ConcreteDark", e.at(0, -0.6), e.at(e.length, -0.6), top, top + 1.6, (-e.n[0], -e.n[1]))
        e.box(s, trim, e.length / 2, top + 1.7, -0.3, (e.length + 0.2, 0.2, 0.8))
    c = g2.centroid(poly)
    area = abs(g2.area(poly))
    for item in style.get("roof", ()):
        name = item[0] if isinstance(item, tuple) else item
        if name == "tank" and area > 150:
            x, z = c[0] + rng.uniform(-3, 3), c[1] + rng.uniform(-3, 3)
            for dx, dz in ((-1.6, -1.6), (1.6, -1.6), (-1.6, 1.6), (1.6, 1.6)):
                s.box("DarkMetal", (x + dx, top + 2.0, z + dz), (0.3, 4.0, 0.3))
            s.cylinder("Steel", (x, top + 4.0, z), 2.4, 4.2, segments=14)
        elif name == "ac":
            for _ in range(int(min(6, area / 120))):
                x, z = c[0] + rng.uniform(-6, 6), c[1] + rng.uniform(-6, 6)
                if g2.contains(poly, (x, z)):
                    s.box("WhiteTrim", (x, top + 1.1, z), (2.4, 2.2, 1.4), rng.uniform(0, 90))
        elif name == "hut" and area > 200:
            x, z = c[0] + rng.uniform(-4, 4), c[1] + rng.uniform(-4, 4)
            s.box(style["clad"], (x, top + 4.0, z), (7.0, 8.0, 7.0), 0, skip=("-y",))
            s.box("ConcreteDark", (x, top + 8.2, z), (7.6, 0.4, 7.6))
        elif name == "antenna":
            s.tube("DarkMetal", (c[0], top, c[1]), (c[0], top + 18.0, c[1]), 0.2, 6)
            s.box("NeonRed", (c[0], top + 18.3, c[1]), (0.6, 0.6, 0.6))
        elif name == "billboard":
            _, words, colour = item
            front = max(edges, key=lambda e: e.length + (1000 if e.front else 0))
            u = front.length / 2
            bw = min(front.length - 2, 24.0)
            bg, fg = SIGN_COLOURS.get(colour, SIGN_COLOURS["white"])
            for du in (-bw / 3, bw / 3):
                x, z = front.at(u + du, -2.0)
                s.box("DarkMetal", (x, top + 4.0, z), (0.5, 8.0, 0.5))
            x, z = front.at(u, -2.0)
            s.box("DarkMetal", (x, top + 11.0, z), (bw, 7.0, 0.6), front.rot)
            sx, sz = front.at(u, -1.6)
            s.sign((sx, top + 11.0, sz), front.rot, bw - 1.0, 6.0, words, "GothamBlack", fg, bg, glow=bg)


def vertical_signs(s, e, top, signs, u=1.4):
    """Stacked vertical signs on a front corner, one per floor: a box standing out from the
    wall with a lit panel and words on both faces."""
    y = FLOOR_GF + 0.6
    for k, (words, colour) in enumerate(signs):
        if y + 10.0 > top:
            break
        bg, fg = SIGN_COLOURS.get(colour, SIGN_COLOURS["white"])
        x, z = e.at(u, 1.5)
        s.box("BlackTrim", (x, y + 5.0, z), (2.8, 10.6, 1.3), e.rot)
        for side in (1, -1):
            px, pz = x + e.t[0] * side * 0.7, z + e.t[1] * side * 0.7
            face = math.degrees(math.atan2(-e.t[0] * side, -e.t[1] * side))
            s.sign((px, y + 5.0, pz), face, 2.4, 9.6, "\n".join(words), "GothamBlack",
                   fg, bg, glow=bg if side > 0 else None)
        y += FLOOR_UP


def screen(s, e, top, size):
    """A giant screen on the front: its frame and a dark face the game plays loops on."""
    w, h = size
    w = min(w, e.length - 2)
    u = e.length / 2
    y = min(top - h / 2 - 4, FLOOR_GF + 8 + h / 2)
    e.box(s, "BlackMetal", u, y, 0.6, (w + 1.6, h + 1.6, 1.2))
    e.quad(s, "Screen", u - w / 2, u + w / 2, y - h / 2, y + h / 2, 1.25)
    x, z = e.at(u, 1.3)
    s.screen((x, y, z), e.rot, w, h)
    # The screen's glow on the street below it (a crossing lit by its screens).
    gx, gz = e.at(u, 8.0)
    s.light("spot", (gx, y - h / 2, gz), (196, 204, 255), 64, 1.3, False, "Bottom", 120)


# Building ----------------------------------------------------------------------------------------------


def party_heights(poly, others, top):
    """For each edge of poly: how high a neighbour stands against it (0 when nothing does)."""
    result = []
    for e in edges_of(poly):
        best = 0.0
        for frac in (0.25, 0.5, 0.75):
            p = e.at(e.length * frac, 1.2)
            for other_poly, other_top in others:
                if g2.contains(other_poly, p):
                    best = max(best, min(other_top, top))
        result.append(best)
    return result


def build(s, b, style, others=(), fronts=None, y=0.0):
    """Builds one building. others: [(poly, top)] of its neighbours; fronts: the indices of the
    edges (counter-clockwise order, from edges_of) that face a street."""
    poly = b["poly"]
    floors = b["floors"]
    top = y + height(floors)
    rng = random.Random(b["name"])
    edges = edges_of(poly)
    for e, h in zip(edges, party_heights(poly, others, top)):
        e.party = h
    for i in fronts or ():
        edges[i].front = True
    levels = [y + level for level in floor_levels(floors)]
    facade = FACADES.get(style.get("windows", "punched"))
    interior = style.get("ground") == "interior"
    # The solid body: all of it, or above the rooms of an interior (one floor, or two).
    rooms = style.get("rooms", 1) if interior else 0
    bottom = y + (FLOOR_GF + FLOOR_UP * (rooms - 1) if rooms else 0.0)
    style = dict(style, rooms_from=bottom)
    for e in edges:
        hidden = e.party
        if hidden < FLOOR_GF - 0.5 and not interior:
            ground = GROUNDS.get(style.get("ground", "shutters"), shutters) if e.front else None
            if ground:
                ground(s, e, style, rng)
            else:
                plain_wall(s, e, y, y + FLOOR_GF, style["clad"])
        if levels and hidden < top - 0.5:
            if hidden > levels[0] + 0.5:
                plain_wall(s, e, hidden, top, style["clad"])
            elif e.front or e.length > 8:
                facade(s, e, levels[0], top, levels, style, rng)
            else:
                plain_wall(s, e, levels[0], top, style["clad"])
        if hidden < top - 0.5:
            x, z = e.at(0, 0.25)
            pier = style["trim"] if style.get("windows") == "curtain" else style["clad"]
            s.box(pier, (x, (max(y, hidden) + top) / 2, z), (0.8, top - max(y, hidden), 0.8), e.rot)
        if e.front and style.get("fascia") and not interior and hidden < 1:
            fascia(s, e, *style["fascia"])
    front_edges = [e for e in edges if e.front] or sorted(edges, key=lambda e: -e.length)[:1]
    if style.get("vsign"):
        vertical_signs(s, front_edges[0], top, style["vsign"])
    if style.get("screen"):
        screen(s, max(front_edges, key=lambda e: e.length), top, style["screen"])
    roof(s, poly, top, style, rng, edges)
    city.floor(s, poly, top, max(1.0, top - bottom), look=style["clad"])
    # A dark core inside the body, deeper than any room or shop set: whatever the street sees
    # past a window's edge or a shutter's is dark wall, never the sky.
    core = grow(poly, -CORE_INSET)
    if abs(g2.area(core)) > 4.0 and g2.area(core) * g2.area(poly) > 0:
        s.prism("CoreDark", core, max(bottom, y), top - 0.5, top=False)
    return top


# Massing: a plain block at true height ------------------------------------------------------------------

MASS_BODY = {
    "glass": "MassGlass",
    "bar": "MassWarm",
    "koban": "MassWarm",
    "karaoke": "MassMid",
    "edge": "MassMid",
    "station": "MassLight",
}


def massing(s, b, y=0.0, collide=True):
    poly = b["poly"]
    floors = b["floors"]
    top = y + height(floors)
    body = MASS_BODY.get(b["kind"], "MassLight")
    ground = "MassEnter" if b.get("use") else "MassClosed"
    s.prism(ground, poly, y, y + FLOOR_GF - 0.3, top=False)
    # The floor, inset a little so neighbours stay apart in the plans.
    for piece in g2.convex_pieces(grow(poly, -0.6)):
        city.up_face(s, "MassEnter" if b.get("use") else "MassMid", piece, y + 0.05)
    s.prism(body, poly, y + FLOOR_GF - 0.3, top, top=True)
    for level in floor_levels(floors):
        s.prism("MassBand", grow(poly, 0.25), y + level - 0.3, y + level + 0.3, top=True, bottom=True)
    s.prism("MassBand", grow(poly, 0.3), top, top + 1.2, top=True, top_mat="MassMid")
    if collide:
        city.floor(s, poly, top, top - y, look=body)
    return top


def far(s, poly, floors, seed, y=0.0, lit=0.35):
    """A building beyond the map: a block with flat lit windows on the 12-stud floor grid, a
    parapet line and a roof. lit: the share of windows lit (fewer on the distant skyline)."""
    rng = random.Random(seed)
    top = y + height(floors)
    clad = rng.choice(("FacadeTile", "FacadeTileGrey", "ConcreteDark", "PlasterGrey", "BrickDark"))
    for e in edges_of(poly):
        e.quad(s, clad, 0, e.length, y, top + 1.4)
        spans = bays(e.length, 7.0)
        for level in floor_levels(floors):
            for u0, u1 in spans:
                r = rng.random()
                if r < lit:
                    mat = "WindowLit" if r < lit * 0.7 else "WindowCool"
                    e.quad(s, mat, (u0 + u1) / 2 - 2.0, (u0 + u1) / 2 + 2.0, level + 3.0, level + 9.4, 0.05)
    for piece in g2.convex_pieces(poly):
        city.up_face(s, "ConcreteDark", piece, top + 0.2)
    return top
