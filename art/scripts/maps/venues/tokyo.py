"""Tokyo District at night: two avenues cross in the middle; each block holds a shop with an
open interior (konbini, metro station, net cafe, koban, ramen shop) under tall towers.
x -110..110, z -90..90. Local coordinates match src/server/Maps/TokyoDistrict.luau: the shops,
doors and furniture stand where they always did, so the stations, sheets, drop points and
hoods keep their places.
"""

import math

from maps import kit, urban

VIEWS = [
    ((24, 16, 30), (-10, 6, -20), 16),
    ((-4, 5.5, 60), (0, 8, -40), 16),
    ((-28, 5.5, -16), (-44, 3, -40), 17),
    ((50, 42, 45), (-5, 2, -15), 15),
    ((0, 170, 0.01), (0, 0, 0), 14),
    ((60, 5.5, 18), (76, 3, 40), 17),
    ((-94, 6, -14), (-100, 8, -44), 18),
]

SIDEWALK_Y = 0.12


def ground(s):
    kit.floor(s, -110, -90, 110, 90, "Asphalt")
    for x1, z1, x2, z2 in ((-110, -90, -8, -8), (8, -90, 110, -8), (-110, 8, -8, 90), (8, 8, 110, 90)):
        kit.top_rect(s, "Pavers", x1, z1, x2, z2, SIDEWALK_Y)
        s.collider(((x1 + x2) / 2, SIDEWALK_Y / 2, (z1 + z2) / 2), (x2 - x1, SIDEWALK_Y, z2 - z1))
        # Curbs along the road edges.
        for (ax, az, bx, bz) in ((x1, z1, x2, z1), (x1, z2, x2, z2), (x1, z1, x1, z2), (x2, z1, x2, z2)):
            if abs(ax) in (8,) and ax == bx or abs(az) in (8,) and az == bz:
                cx, cz = (ax + bx) / 2, (az + bz) / 2
                sx = abs(bx - ax) if ax != bx else 0.4
                sz = abs(bz - az) if az != bz else 0.4
                s.box("Concrete", (cx, 0.1, cz), (sx, 0.2, sz), skip=("-y",))
    # Crosswalks, stop lines, centre lines and manholes.
    for i in range(7):
        for z in (-12, 12):
            s.box("WhiteTrim", (-6 + i * 2, 0.02, z), (1, 0.04, 4), skip=("-y",))
        for x in (-12, 12):
            s.box("WhiteTrim", (x, 0.02, -6 + i * 2), (4, 0.04, 1), skip=("-y",))
    for z in (-15, 15):
        s.box("WhiteTrim", (-4 if z < 0 else 4, 0.02, z), (7, 0.04, 0.4), skip=("-y",))
    for x in (-15, 15):
        s.box("WhiteTrim", (x, 0.02, 4 if x < 0 else -4), (0.4, 0.04, 7), skip=("-y",))
    for z in (-70, -50, -30, 30, 50, 70):
        s.box("PaintYellow", (0, 0.02, z), (0.5, 0.04, 6), skip=("-y",))
    for x in (-90, -70, -50, -30, 30, 50, 70, 90):
        s.box("PaintYellow", (x, 0.02, 0), (6, 0.04, 0.5), skip=("-y",))
    for x, z in ((0, -40), (0, 44), (-36, 0), (40, 0)):
        s.cylinder("DarkMetal", (x, 0, z), 1.3, 0.04, 16, caps=(False, True))


def towers(s):
    urban.tower(s, -105, -88, -65, -52, 36, 1, faces=("e", "s"), tile="FacadeTile", balconies=True)
    urban.tower(s, 65, -88, 105, -52, 40, 2, faces=("w", "s"), tile="FacadeTileGrey")
    urban.tower(s, -105, 52, -65, 88, 30, 3, faces=("e", "n"), tile="FacadeTile", ground="shop")
    urban.tower(s, 72, 56, 108, 88, 34, 4, faces=("w", "n"), tile="FacadeTileGrey", balconies=True)
    # Backdrop buildings that close the district in.
    backdrop = [
        ((-65, -90, -40, -84), 28, "s"), ((-40, -90, -8, -84), 38, "s"), ((-8, -90, 8, -84), 24, "s"),
        ((8, -90, 34, -84), 32, "s"), ((34, -90, 65, -84), 26, "s"),
        ((-56, 84, -36, 90), 26, "n"),  # leaves the nook behind the karaoke bar (a drop point) ((-36, 84, -8, 90), 34, "n"), ((-8, 84, 8, 90), 22, "n"),
        ((8, 84, 40, 90), 30, "n"), ((40, 84, 72, 90), 24, "n"),
        ((104, -52, 110, -8), 30, "w"), ((104, -8, 110, 8), 22, "w"), ((104, 8, 110, 56), 28, "w"),
        ((-110, -52, -108.6, -8), 26, "e"), ((-110, -8, -108.6, 8), 20, "e"), ((-110, 8, -108.6, 52), 30, "e"),
    ]
    for i, ((x1, z1, x2, z2), h, face) in enumerate(backdrop):
        urban.tower(s, x1, z1, x2, z2, h, 10 + i, faces=(face,), tile="FacadeTileGrey" if i % 2 else "FacadeTile",
                    ground="shop" if i % 3 == 0 else "shutter", roof=False)
    # Colliders all round the edge, as tall as the old boundary.
    for (cx, cz, sx, sz) in ((0, -90.5, 222, 1), (0, 90.5, 222, 1), (-110.5, 0, 1, 182), (110.5, 0, 1, 182)):
        s.collider((cx, 20, cz), (sx, 40, sz))
    # Neon on the towers.
    urban.box_sign(s, -64.6, 16, -62, -90, 12, 3, "24H HOTEL", "NeonPink")
    urban.vertical_sign(s, -63.4, 24, -58, -90, "ホテル", "NeonPink")
    urban.box_sign(s, 64.6, 18, -62, 90, 12, 3, "CAPSULE", "NeonCyan")
    urban.vertical_sign(s, 63.4, 27, -58, 90, "カプセル", "NeonCyan")
    urban.box_sign(s, -64.6, 14, 62, -90, 12, 3, "KARAOKE", "NeonYellow")
    urban.vertical_sign(s, -63.4, 21, 66, -90, "カラオケ", "NeonYellow")
    urban.vertical_sign(s, 70.6, 22, 60, 90, "居酒屋", "NeonRed")
    # A big screen over the crossing.
    s.box("BlackTrim", (-64.6, 28, -70), (1.0, 7, 12))
    s.box("NeonBlue", (-64.05, 28, -70), (0.05, 6.2, 11.2))
    s.sign((-64.0, 28, -70), -90, 11, 6, "ARE YOU\nBEING WATCHED?", "Bangers", (255, 255, 255), None)
    s.light("point", (-62, 28, -70), (80, 150, 255), 22, 1.4)
    fire_escape(s)


def fire_escape(s, x0=-100, z=-52):
    """Zig-zag iron stairs on the alley side of the north-west tower."""
    for i, y in enumerate((8, 15, 22, 29)):
        s.box("BlackMetal", (x0 + 4, y, z + 1.3), (9, 0.25, 2.4))
        s.tube("BlackMetal", (x0 - 0.5, y + 2.4, z + 2.5), (x0 + 8.5, y + 2.4, z + 2.5), 0.06, 4)
        for k in range(10):
            s.tube("BlackMetal", (x0 - 0.5 + k, y, z + 2.5), (x0 - 0.5 + k, y + 2.4, z + 2.5), 0.04, 4, caps=False)
        if i < 3:
            a = (x0 + (7 if i % 2 == 0 else 1), y + 0.1, z + 1.3)
            b = (x0 + (1 if i % 2 == 0 else 7), y + 7, z + 1.3)
            s.tube("BlackMetal", a, b, 0.08, 4)
            s.tube("BlackMetal", (a[0], a[1] + 1.4, a[2] + 1.0), (b[0], b[1] + 1.4, b[2] + 1.0), 0.05, 4)
            steps = 10
            for k in range(steps):
                t = (k + 0.5) / steps
                p = (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2])
                s.box("DarkMetal", p, (0.6, 0.08, 2.0))


def shop_walls(s, x1, z1, x2, z2, h, doors, outside, inside, storefronts=(), door_top=8.0, glass_top=7.6):
    """A shop's four walls: doors {side: [(centre, width)]} and big shop windows on the sides in
    storefronts (the street sides)."""
    w, d = x2 - x1, z2 - z1
    sides = {
        "north": ((x1, z1), (x2, z1), w, lambda c: c),
        "east": ((x2, z1), (x2, z2), d, lambda c: c),
        "south": ((x2, z2), (x1, z2), w, lambda c: w - c),
        "west": ((x1, z2), (x1, z1), d, lambda c: d - c),
    }
    for side, (a, b, length, conv) in sides.items():
        door_list = [(conv(c), width) for c, width in doors.get(side, [])]
        ops = [{"at": at, "w": width, "bottom": 0, "top": door_top, "kind": "door", "frame": "DarkMetal", "casing": 0.3}
               for at, width in door_list]
        if side in storefronts:
            # Shop windows fill the wall between the doors.
            spans, cursor = [], 1.5
            for at, width in sorted(door_list):
                spans.append((cursor, at - width / 2 - 1.2))
                cursor = at + width / 2 + 1.2
            spans.append((cursor, length - 1.5))
            for u0, u1 in spans:
                if u1 - u0 < 3:
                    continue
                ops.append({"at": (u0 + u1) / 2, "w": u1 - u0, "bottom": 1.0, "top": glass_top, "kind": "window",
                            "frame": "DarkMetal", "mullions": "DarkMetal", "cols": max(1, round((u1 - u0) / 4)),
                            "rows": 1, "glass": "Glass", "sill": "DarkMetal", "casing": 0.25})
        kit.wall(s, a, b, h, thick=1.0, core=outside, side_n=outside, side_s=inside, openings=ops,
                 trim_s={"base": "BlackTrim"})
    kit.ceiling(s, x1 + 0.5, z1 + 0.5, x2 - 0.5, z2 - 0.5, h - 0.05, "Ceiling")
    s.box("ConcreteDark", ((x1 + x2) / 2, h + 0.5, (z1 + z2) / 2), (w + 1.4, 1.0, d + 1.4), skip=("-y",))
    s.box("DarkMetal", ((x1 + x2) / 2, h + 1.2, (z1 + z2) / 2), (w + 1.4, 0.4, d + 1.4), skip=("-y",))


def konbini(s):
    x1, z1, x2, z2 = -60, -50, -24, -24
    kit.floor(s, x1, z1, x2, z2, "TileWhite", y=0.13)
    shop_walls(s, x1, z1, x2, z2, 10, {"south": [(18, 8)], "east": [(13, 6)]}, "PlasterLight", "PlasterLight",
               storefronts=("south", "east"))
    # Store stripes along the top of the street fronts.
    for mat, y in (("NeonGreen", 9.2), ("NeonOrange", 8.8), ("RedTrim", 8.4)):
        s.box(mat, (-42, y, -23.45), (36, 0.35, 0.1))
        s.box(mat, (-23.45, y, -37), (0.1, 0.35, 26))
    s.light("point", (-42, 8.8, -21), (100, 255, 140), 12, 0.6)
    urban.box_sign(s, -42, 12.4, -23.3, 180, 16, 2.8, "KONBINI 24", "NeonGreen", "GothamBlack")
    for x in (-50, -42, -34):
        for z in (-44, -32):
            kit.panel_light(s, x, 10, z, 5, 1.6, color=kit.COOL, range_=18, brightness=1.0)
    urban.shelves(s, -42, -44, 0, 10, 51)
    urban.shelves(s, -42, -34, 0, 10, 52)
    # The glowing drinks fridges along the back wall.
    for i in range(6):
        x = -49.5 + i * 2.6
        s.box("Steel", (x, 3.5, -48.8), (2.6, 7, 1.6))
        s.box("WindowCool", (x, 3.7, -47.98), (2.2, 6.2, 0.04))
        for k in range(5):
            s.box("DarkMetal", (x, 1.4 + k * 1.25, -48.2), (2.2, 0.06, 1.0))
        s.box("Steel", (x + 0.9, 3.8, -47.9), (0.08, 1.6, 0.1))
    s.collider((-42, 3.5, -48.8), (16, 7, 1.6))
    s.light("point", (-42, 4, -46), (180, 210, 255), 14, 0.8)
    kit.counter(s, -30, -30, 90, 8, top="WhiteTrim", body="Foliage")
    s.box("BlackMetal", (-30.2, 4.0, -32), (1.2, 0.9, 1.0))
    s.box("NeonGreen", (-30.8, 4.2, -32), (0.05, 0.4, 0.8))
    s.box("DarkMetal", (-30.4, 3.9, -27.4), (1.4, 0.8, 1.4))


def metro(s):
    x1, z1, x2, z2 = 24, -50, 60, -24
    kit.floor(s, x1, z1, x2, z2, "TileMetro", y=0.13)
    shop_walls(s, x1, z1, x2, z2, 10, {"south": [(18, 8)], "west": [(13, 6)]}, "ConcreteDark", "TileMetro",
               storefronts=())
    for x in (32, 38, 46, 52):
        s.box("Steel", (x, 1.5, -36), (1, 3, 2), collide=True)
        s.box("NeonGreen", (x, 3.02, -35.4), (0.6, 0.04, 0.3))
        s.box("BlackTrim", (x + 0.9, 2.4, -36), (0.9, 0.1, 0.1))
    s.prop("Bench", 34, -47.5, 180)
    s.prop("Bench", 44, -47.5, 180)
    s.box("DarkMetal", (42, 6, -49.4), (10.4, 4.4, 0.2))
    s.sign((42, 6, -49.25), 180, 10, 4, "LINE 3  >>  SHIBUYA", "GothamBold", (255, 255, 255), (30, 90, 60))
    for x in (32, 42, 52):
        kit.panel_light(s, x, 10, -37, 6, 1.2, color=kit.COOL, range_=18, brightness=1.0)
    # The round metro sign on the roof above the entrance.
    s.box("BlackTrim", (42, 12.6, -23.4), (12.4, 3.2, 0.6))
    s.box("NeonBlue", (42, 12.6, -23.08), (12, 2.8, 0.04))
    s.sign((42, 12.6, -23.0), 180, 11.6, 2.6, "METRO  ·  駅", "GothamBlack", (255, 255, 255), None)
    s.light("point", (42, 12, -21), (80, 150, 255), 14, 1.0)
    # A stairwell sign by the corner where the stairs go down.
    s.box("BlackTrim", (56, 8, -24.6), (4, 1.2, 0.2))
    s.sign((56, 8, -24.75), 0, 3.8, 1.0, "↓ PLATFORMS", "GothamBold", (255, 220, 70), None)


def phone_booth(s):
    # Roof and posts over the Phone Booth station (20, -14).
    s.box("RedTrim", (20, 8.2, -14), (6.5, 0.4, 4.5))
    s.box("WhiteTrim", (20, 8.46, -14), (6.1, 0.12, 4.1))
    for x in (17, 23):
        s.box("RedTrim", (x, 4, -15.8), (0.4, 8, 0.4), collide=True)
    s.sign((20, 7.6, -11.85), 180, 4, 0.7, "PUBLIC PHONE  公衆電話", "GothamBold", (255, 255, 255), (150, 20, 30))
    s.light("point", (20, 7.4, -14), (255, 214, 170), 10, 0.8)
    s.prop("VendingMachine", 70, -12, 180)
    s.prop("VendingMachine", 76, -12, 180)
    s.prop("VendingMachine", 30, -21.4, 180)
    s.prop("VendingMachine", -70, 12, 0)


def net_cafe(s):
    x1, z1, x2, z2 = -60, 24, -24, 50
    kit.floor(s, x1, z1, x2, z2, "CarpetGrey", y=0.13)
    shop_walls(s, x1, z1, x2, z2, 10, {"north": [(18, 8)], "east": [(13, 6)]}, "ConcreteDark", "PlasterDark",
               storefronts=("north", "east"))
    for x in (-52, -44, -36):
        s.prop("Desk", x, 47.5, 0)
        s.prop("OfficeChair", x, 45, 180)
        s.box("NeonPink", (x, 7.5, 49.45), (6, 0.12, 0.08))
    kit.table(s, -30, 44, 4, 3, top="BlackTrim")
    s.box("NeonCyan", (-42, 9.7, 37), (30, 0.08, 0.08))
    s.box("NeonPink", (-59.45, 5, 37), (0.08, 0.1, 22))
    for x, z in ((-50, 32), (-34, 32)):
        kit.panel_light(s, x, 10, z, 4, 1.2, color=kit.COOL, range_=16, brightness=0.7)
    s.light("point", (-44, 6, 46), (255, 80, 200), 14, 0.8)
    urban.box_sign(s, -42, 12.4, 23.3, 0, 14, 2.8, "NET CAFE", "NeonCyan", "GothamBlack")
    s.box("NeonCyan", (-42, 10.8, 23.35), (30, 0.2, 0.2))
    for i, x in enumerate((-58, -56.5, -55)):
        urban.bicycle(s, x, 21.5, 90)


def koban(s):
    x1, z1, x2, z2 = 16, 22, 48, 46
    kit.floor(s, x1, z1, x2, z2, "Concrete", y=0.13)
    shop_walls(s, x1, z1, x2, z2, 10, {"north": [(16, 8)]}, "PlasterLight", "PlasterGrey", storefronts=())
    kit.table(s, 32, 42, 5, 3, top="Wood")
    s.prop("FilingCabinet", 46, 25, 90)
    for x in (24, 40):
        kit.panel_light(s, x, 10, 34, 4, 1.6, color=kit.COOL, range_=18, brightness=0.9)
    # The famous red lamp over the door, and the name board.
    s.lathe("NeonRed", (32, 10.4, 20.8), [(0.0, 0), (0.55, 0.2), (0.6, 0.7), (0.4, 1.2), (0.0, 1.35)], 16)
    s.box("BlackMetal", (32, 11.0, 21.2), (0.3, 0.3, 0.8))
    s.light("point", (32, 11.6, 21.0), (255, 40, 40), 18, 2.0, flicker=False)
    s.box("WhiteTrim", (32, 13.4, 21.35), (10.4, 2.6, 0.3))
    s.sign((32, 13.4, 21.15), 0, 10, 2.4, "KOBAN  交番", "GothamBlack", (30, 30, 60), None)
    s.box("BlackTrim", (32, 8.4, 21.45), (9, 0.3, 0.2))
    for i, z in enumerate((27, 29, 31)):
        urban.bicycle(s, 50.5, z, 0)


def ramen(s):
    x1, z1, x2, z2 = 56, 24, 92, 50
    kit.floor(s, x1, z1, x2, z2, "WoodFloorDark", y=0.13)
    shop_walls(s, x1, z1, x2, z2, 10, {"north": [(18, 8)], "west": [(13, 6)]}, "WoodPanel", "PlasterLight",
               storefronts=("north",))
    kit.counter(s, 74, 44, 0, 16, top="Wood", body="Wood")
    for x in (68, 72, 76, 80):
        s.cylinder("BlackMetal", (x, 0, 41), 0.15, 1.6, 8)
        s.cylinder("RedTrim", (x, 1.6, 41), 0.6, 0.3, 12)
        s.collider((x, 1, 41), (1.2, 2, 1.2))
    for x in (64, 74, 84):
        kit.pendant(s, x, 10, 40, drop=3.5, shade="RedTrim", range_=16, brightness=0.9, wide=1.0)
    urban.noren(s, 74, 8.3, 23.2, 0, 7, 2.6)
    for x in (68.6, 79.4):
        urban.lantern(s, x, 7.2, 23.0)
        s.light("point", (x, 6.8, 22.2), (255, 60, 40), 10, 0.9)
    urban.box_sign(s, 74, 12.4, 23.3, 0, 12, 2.8, "RAMEN", "NeonOrange", "Bangers")
    urban.vertical_sign(s, 57.2, 7, 22.2, 0, "ラーメン", "NeonRed", w=1.6)
    s.box("NeonOrange", (74, 10.8, 23.35), (30, 0.2, 0.2))
    s.box("BlackTrim", (74, 6.2, 49.4), (10, 3, 0.1))  # menu board
    for i in range(4):
        s.box("CreamTrim", (70.5 + i * 2.3, 6.2, 49.33), (1.9, 2.4, 0.03))


def karaoke_nook(s):
    """The dead end behind the karaoke bar where notes get dropped: bins and a flickering light."""
    s.prop("TrashCan", -63.6, 88.4, 20)
    s.prop("Crate", -57.8, 88.6, 10, 0.6)
    s.tube("DarkMetal", (-64.5, 0.1, 89.4), (-64.5, 24, 89.4), 0.3, 8)
    kit.sconce(s, -60.5, 8, 89.5, 0, color=(255, 170, 120), range_=12, brightness=0.8)
    s.lights[-1]["flicker"] = True


def alley(s):
    s.prop("Dumpster", -104, -40, 90)
    for x, z, sz in ((-96, -46, 3), (-100, -20, 4), (-80, -14, 3)):
        s.prop("Crate", x, z, (x * 3) % 90, sz / 4)
    # Pipes and a light over the alley.
    for y in (6, 6.6):
        s.tube("DarkMetal", (-104, y, -51.4), (-66, y, -51.4), 0.25, 8)
    kit.sconce(s, -86, 7.5, -51.4, 180, color=(255, 190, 120), range_=18, brightness=1.0)
    s.lights[-1]["flicker"] = True


def street(s):
    lamps = [(-12, -30, 90), (12, -30, -90), (-12, 30, 90), (12, 30, -90), (-40, -12, 180), (40, 12, 0), (-80, 12, 0),
             (80, -12, 180), (-40, 12, 0), (40, -12, 180)]
    for i, (x, z, rot) in enumerate(lamps):
        s.prop("LampPost", x, z, rot)
        turn = kit.ry(rot)
        head = turn((0, 0, -1.1))
        s.light("spot", (x + head[0], 11.6, z + head[2]), (255, 205, 150), 27, 3.2, i < 6, "Bottom", 75,
                flicker=i in (3, 8))
        s.collider((x, 6, z), (0.6, 12, 0.6))
    # Utility poles along the avenues, wired together.
    lines = [
        [(-9.6, z) for z in (-80, -56)], [(-9.6, z) for z in (56, 80)],
        [(9.6, z) for z in (-80, -56)], [(9.6, z) for z in (56, 80)],
        [(x, -9.6) for x in (-88, -64)], [(x, -9.6) for x in (64, 88)],
        [(x, 9.6) for x in (-88, -64)], [(x, 9.6) for x in (64, 88)],
    ]
    for line in lines:
        tops = []
        for x, z in line:
            rot = 90 if abs(x) == 9.6 else 0
            tops.append(urban.utility_pole(s, x, z, 13, rot))
        for a, b in zip(tops, tops[1:]):
            urban.wires(s, a, b)
    # Wires strung across the avenues between facing poles.
    for z in (-80, 80):
        urban.wires(s, [(-9.6, 12.2, z)], [(9.6, 12.2, z)], sag=0.8)
    for x in (-88, 88):
        urban.wires(s, [(x, 12.2, -9.6)], [(x, 12.2, 9.6)], sag=0.8)
    for x, z, rot in ((9.8, -9.8, 90), (-9.8, 9.8, -90), (-9.8, -9.8, 180), (9.8, 9.8, 0)):
        urban.traffic_light(s, x, z, rot, lit="NeonRed" if rot in (90, -90) else "NeonGreen")
    for x, z, rot, color in ((-4, -60, 0, "white"), (4, 60, 180, "blue"), (-60, 4, 90, "red"), (60, -4, -90, "black"),
                             (-90, -4, 90, "yellow")):
        s.prop("Car", x, z, rot)
    for x, z, rot in ((-14, -20, 0), (20, 24, 180), (-44, -14, 90), (44, 14, -90), (60, -14, 0)):
        s.prop("Hydrant", x, z, rot)
    for x, z in ((-18, -14), (24, 12), (-66, 14), (66, -14), (-20, 66), (26, -66)):
        s.prop("TrashCan", x, z, (x * 7) % 360)
    for x, z, rx, rz in ((-6, -40, 3, 2), (8, -72, 2.5, 1.5), (-30, 6, 3.5, 1.5), (50, -6, 3, 1.5), (82, 5, 2.5, 1.5),
                         (-78, -4, 3, 1.5), (4, 48, 3, 2), (-20, -7, 2, 1.5), (22, 8, 2.5, 1.5), (-5, 78, 3, 1.5)):
        kit.puddle(s, x, z, rx, rz)
    for x, z in ((-100, -62), (100, 22), (-22, -84), (26, 84)):
        s.box("BlackMetal", (x, 0.08, z), (2.4, 0.16, 2.4), skip=("-y",))
        for k in range(5):
            s.box("DarkMetal", (x - 1 + k * 0.5, 0.17, z), (0.12, 0.04, 2.2))
        s.emitter("steam", (x, 0.2, z))
    kit.skyline(s, 0, 0, 110, 90, seed=37, count=34, reach=(1.7, 2.5), height=(50, 140))


def preview(s):
    stations = [(-56, -40, -90), (56, -40, 90), (20, -14, 180), (-56, 36, -90), (20, 40, -90), (-90, -30, -90),
                (14, 16, 0), (88, 32, 90)]
    for x, z, rot in stations:
        s.prop("Station", x, z, rot)
    s.prop("TipBox", 44, 40, 90)
    s.prop("EvidenceBoard", 15.2, 34, 90, 1.0, 5)


def build(s):
    ground(s)
    towers(s)
    konbini(s)
    metro(s)
    phone_booth(s)
    net_cafe(s)
    koban(s)
    ramen(s)
    alley(s)
    karaoke_nook(s)
    street(s)
