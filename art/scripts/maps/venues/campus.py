"""University Campus at night: a quad with a fountain surrounded by brick college buildings
(library, lecture hall, science lab, cafeteria, campus security) and a clock tower.
x -110..110, z -90..90. Local coordinates match src/server/Maps/UniversityCampus.luau: the
buildings, doors and furniture stand where they always did, so the stations, sheets, drop
points and hoods keep their places.
"""

import math

from maps import kit

VIEWS = [
    ((0, 22, 58), (0, 4, -30), 17),
    ((-30, 7, -12), (-75, 6, -45), 17),
    ((40, 30, 60), (-10, 6, -40), 16),
    ((-58, 7, -48), (-85, 3, -70), 17),
    ((0, 150, 0.01), (0, 0, 0), 14),
    ((64, 7, -46), (88, 3, -72), 17),
]

GOLD = (214, 176, 96)
INSIDE = {"base": "BlackTrim", "wainscot": ("WoodPanel", 4.2), "rail": "Wood", "crown": "CreamTrim"}


def spaced(length, doors, width=4.0, spacing=8.0, margin=4.0, gap=3.0):
    """Window positions along a wall of `length`, keeping clear of doors [(at, w)]."""
    spots = []
    count = int((length - margin * 2) // spacing) + 1
    start = (length - (count - 1) * spacing) / 2
    for i in range(count):
        at = start + i * spacing
        if all(abs(at - d_at) > d_w / 2 + width / 2 + gap for d_at, d_w in doors):
            spots.append(at)
    return spots


def building(s, x1, z1, x2, z2, h, doors, floor_mat, outside="BrickRed", inside="PlasterLight", door_top=9.0,
             window_sides=("north", "east", "south", "west"), trim=INSIDE, rise=None, lights=None):
    """A brick college building with doors, windows, a stone plinth and cornice and a slate roof.
    doors: {side: [(centre, width)]}, north/south centres from x1 and west/east ones from z1."""
    kit.floor(s, x1, z1, x2, z2, floor_mat, y=0.02)
    w, d = x2 - x1, z2 - z1
    sides = {
        "north": ((x1, z1), (x2, z1), w, lambda c: c),
        "east": ((x2, z1), (x2, z2), d, lambda c: c),
        "south": ((x2, z2), (x1, z2), w, lambda c: w - c),
        "west": ((x1, z2), (x1, z1), d, lambda c: d - c),
    }
    for side, (a, b, length, conv) in sides.items():
        door_list = [(conv(c), width) for c, width in doors.get(side, [])]
        ops = [{"at": at, "w": width, "bottom": 0, "top": door_top, "kind": "door", "frame": "Stone", "casing": 0.6}
               for at, width in door_list]
        if side in window_sides:
            for at in spaced(length, door_list):
                ops.append({"at": at, "w": 3.6, "bottom": 3.6, "top": h - 4.2, "kind": "window", "frame": "Stone",
                            "mullions": "BlackMetal", "cols": 2, "rows": 3, "glass": "Glass", "sill": "Stone",
                            "casing": 0.5})
        length_, t, n = kit.wall(s, a, b, h, thick=1.2, core=outside, side_n=outside, side_s=inside, openings=ops,
                                 trim_s=trim)
        # Stone plinth (broken at the doors) and cornice on the outside.
        p0 = (a[0], 0, a[1])
        p1 = (b[0], 0, b[1])
        plinth = [(o + 0.6, y) for o, y in ((0, 0), (0.35, 0), (0.35, 1.4), (0.1, 1.7), (0, 1.8))]
        cursor = 0.0
        for at, width in sorted(door_list) + [(length + 10, 0)]:
            end = min(length, at - width / 2 - 0.6)
            if end - cursor > 0.1:
                s.sweep("Stone", kit.point_on(a, t, cursor), kit.point_on(a, t, end), plinth, n)
            cursor = at + width / 2 + 0.6
        s.sweep("Stone", add_y(p0, 0), add_y(p1, 0), [(o + 0.6, y) for o, y in ((0, h - 1.4), (0.2, h - 1.2),
                                                                              (0.45, h - 0.5), (0.45, h), (0, h))], n)
    kit.ceiling(s, x1 + 0.6, z1 + 0.6, x2 - 0.6, z2 - 0.6, h - 0.05, "PlasterLight", beams=8, beam_mat="Wood",
                beam_depth=0.9)
    kit.gable_roof(s, x1 - 0.6, z1 - 0.6, x2 + 0.6, z2 + 0.6, h, rise or min(w, d) * 0.28, "Slate", outside,
                   overhang=1.4)
    for lx, lz in lights or ():
        kit.pendant(s, lx, h - 0.9, lz, drop=3.8, shade="Brass", range_=30, brightness=1.0, wide=1.3)


def add_y(p, y):
    return (p[0], p[1] + y, p[2])


def plaque(s, x, y, z, rot, w, h, text):
    turn = kit.ry(rot)
    off = turn((0, 0, -0.35))
    s.box("BlackTrim", (x + off[0], y, z + off[2]), (w + 0.6, h + 0.4, 0.3), rot)
    off2 = turn((0, 0, -0.52))
    s.box("Brass", (x + off2[0], y - h / 2 - 0.1, z + off2[2]), (w + 0.6, 0.12, 0.1), rot)
    off3 = turn((0, 0, -0.52))
    s.sign((x + off3[0], y, z + off3[2]), rot, w, h, text, "Garamond", GOLD, None)
    lamp = turn((0, 0, -1.2))
    s.light("point", (x + lamp[0], y + 1.2, z + lamp[2]), (255, 214, 160), 12, 0.8)


def buildings(s):
    # Library (north-west)
    building(s, -100, -80, -50, -40, 14, {"south": [(25, 10)], "east": [(20, 8)]}, "WoodFloor",
             lights=[(-87.5, -60), (-62.5, -60)])
    plaque(s, -75, 11.2, -39.4, 180, 18, 2.4, "LIBRARY")
    for x, z, w in ((-80, -70, 12), (-80, -56, 12), (-64, -70, 8)):
        count = max(1, round(w / 3.2))
        unit = w / count
        for i in range(count):
            s.prop("Bookshelf", x - w / 2 + unit * (i + 0.5), z, 0, unit / 3.2)
    kit.table(s, -66, -50, 6, 3)
    s.prop("Chair", -66, -47.5, 0)
    for x in (-68, -64):
        s.cylinder("Brass", (x, 2.75, -50.8), 0.25, 0.1, 10)
        s.tube("Brass", (x, 2.85, -50.8), (x, 3.9, -50.8), 0.04, 5)
        s.lathe("NeonGreen", (x, 3.9, -50.6), [(0.5, 0), (0.25, 0.4)], 10, caps=(False, False))
    s.light("point", (-66, 4.5, -50.5), (200, 255, 200), 10, 0.7)

    # Lecture hall (north-east)
    building(s, 50, -80, 100, -40, 16, {"south": [(25, 10)], "west": [(20, 8)]}, "CarpetRed",
             lights=[(62.5, -60), (87.5, -60)])
    plaque(s, 75, 12.5, -39.4, 180, 20, 2.6, "LECTURE HALL")
    for row in range(3):
        for x in (60, 72, 84):
            s.prop("Bench", x, -72 + row * 7, 0)
    s.box("Wood", (75, 8, -79.2), (21, 8, 0.4))
    s.box("BlackTrim", (75, 8, -78.98), (20, 7, 0.06))  # blackboard
    for i, (u, v, w) in enumerate(((-6, 1.8, 5), (-5, 0.8, 3), (2, 1.5, 6), (3, -0.5, 4), (-4, -1.5, 5))):
        s.box("WhiteTrim", (75 + u, 8 + v, -78.94), (w, 0.08, 0.02))
    s.box("Wood", (75, 1.9, -75), (3, 3.8, 1.6))

    # Science lab (south-east)
    building(s, 50, 40, 100, 80, 14, {"north": [(25, 10)], "west": [(20, 8)]}, "TileWhite",
             lights=[(62.5, 60), (87.5, 60)])
    plaque(s, 75, 11.2, 39.4, 0, 18, 2.4, "SCIENCE LAB")
    kit.counter(s, 70, 70, 0, 14)
    kit.counter(s, 70, 56, 0, 14)
    s.prop("FilingCabinet", 97, 44, 90)
    for i in range(6):
        s.cylinder("Glass", (65 + i * 0.6, 3.5, 70), 0.15, 0.7, 8)
    s.box("Steel", (60, 6, 79.0), (6, 5, 1.6))  # fume hood
    s.box("GlassDark", (60, 5.4, 78.18), (5.4, 2.6, 0.05))

    # Cafeteria (south-west)
    building(s, -100, 40, -50, 80, 13.5, {"north": [(25, 10)], "east": [(20, 8)]}, "TileChecker", door_top=8.5,
             lights=[(-87.5, 60), (-62.5, 60)])
    plaque(s, -75, 10.4, 39.4, 0, 18, 2.4, "CAFETERIA")
    for x in (-85, -70):
        for z in (52, 66):
            kit.table(s, x, z, 8, 4, top="WhiteTrim")
            for dz in (-2.9, 2.9):
                s.box("BlackTrim", (x, 1.6, z + dz), (7, 0.3, 1.2), collide=False)
    kit.counter(s, -75, 77.5, 180, 20, top="Steel", body="WhiteTrim")
    s.prop("VendingMachine", -52.5, 72, 90)

    # Campus security (south): the headquarters of this map
    building(s, -15, 55, 15, 85, 13.5, {"north": [(15, 8)]}, "Concrete", outside="Stone", inside="PlasterGrey",
             door_top=8.5, window_sides=("north",), lights=[(-7.5, 70), (7.5, 70)])
    plaque(s, 0, 10.4, 54.4, 0, 16, 2.2, "CAMPUS SECURITY")
    s.prop("FilingCabinet", -12, 60, -90)
    for i in range(3):
        s.box("BlackMetal", (-14.2, 6 + (i % 2) * 2.6, 64 + i * 3.2), (0.4, 2.4, 3))
        s.box("NeonBlue", (-13.98, 6 + (i % 2) * 2.6, 64 + i * 3.2), (0.04, 2.0, 2.6))
    s.light("point", (-12, 7, 68), (80, 150, 255), 14, 0.8)
    s.box("NeonBlue", (0, 10.9, 54.2), (2, 0.4, 0.4))
    s.light("point", (0, 10.9, 53.2), (80, 150, 255), 14, 1.2, flicker=True)


def clock_tower(s, x=0, z=-70):
    w, h = 10, 30
    s.box("BrickRed", (x, h / 2, z), (w, h, w), skip=("-y",), collide=True)
    # Stone quoins, bands and a plinth.
    for cx in (-1, 1):
        for cz in (-1, 1):
            for k in range(int(h / 2)):
                big = k % 2 == 0
                qw = 1.6 if big else 1.0
                s.box("Stone", (x + cx * (w / 2 - qw / 2 + 0.05), k * 2 + 1, z + cz * (w / 2 - 0.4)),
                      (qw, 1.9, 0.9 if big else 1.6))
    for y in (0.9, 12, 21.5, 29.5):
        s.box("Stone", (x, y, z), (w + 0.8, 1.2 if y > 1 else 1.8, w + 0.8))
    # Glowing clock faces on all four sides.
    for rot in (0, 90, 180, -90):
        turn = kit.ry(rot)
        n = turn((0, 0, -1))
        centre = (x + n[0] * (w / 2 + 0.2), 17, z + n[2] * (w / 2 + 0.2))
        side = turn((1, 0, 0))
        r = 3.2
        ring = [(centre[0] + side[0] * math.cos(a) * r, centre[1] + math.sin(a) * r, centre[2] + side[2] * math.cos(a) * r)
                for a in (2 * math.pi * k / 28 for k in range(28))]
        s.polygon("WindowLit", list(reversed(ring)))
        for k in range(28):
            p0, p1 = ring[k], ring[(k + 1) % 28]
            s.tube("Stone", p0, p1, 0.35, 6, caps=False)
        for k in range(12):
            a = 2 * math.pi * k / 12
            p = (centre[0] + side[0] * math.cos(a) * 2.6 + n[0] * 0.05, centre[1] + math.sin(a) * 2.6,
                 centre[2] + side[2] * math.cos(a) * 2.6 + n[2] * 0.05)
            s.box("BlackTrim", p, (0.25, 0.5 if k % 3 == 0 else 0.3, 0.1), rot)
        s.tube("BlackTrim", add_y(centre, 0), (centre[0] + n[0] * 0.1, centre[1] + 2.2, centre[2] + n[2] * 0.1), 0.1, 4)
        s.tube("BlackTrim", add_y(centre, 0), (centre[0] + side[0] * 1.5 + n[0] * 0.15, centre[1] - 0.6,
                                              centre[2] + side[2] * 1.5 + n[2] * 0.15), 0.1, 4)
        if rot in (0, 180):
            s.light("point", (centre[0] + n[0] * 2, centre[1], centre[2] + n[2] * 2), (255, 214, 150), 14, 0.9)
        # Belfry openings.
        for u in (-2.2, 2.2):
            p = (x + n[0] * (w / 2 + 0.01) + side[0] * u, 25.5, z + n[2] * (w / 2 + 0.01) + side[2] * u)
            s.box("BlackTrim", p, (2.4, 5, 0.1), rot)
            s.box("Stone", (p[0] + n[0] * 0.2, 28.2, p[2] + n[2] * 0.2), (2.8, 0.5, 0.4), rot)
    kit.pyramid_roof(s, x, z, w + 1.2, 30.1, 14)


def fountain(s, x=0, z=0):
    s.lathe("Stone", (x, 0, z), [(9.3, 0), (9.3, 1.7), (9.6, 1.9), (9.6, 2.2), (8.6, 2.2), (8.4, 1.9)], 40,
            caps=(False, False))
    s.lathe("Stone", (x, 0, z), [(8.4, 1.9), (8.2, 1.2)], 40, caps=(False, False))
    s.polygon("Water", [(x + math.cos(a) * 8.3, 1.25, z + math.sin(a) * 8.3)
                        for a in reversed([2 * math.pi * k / 40 for k in range(40)])])
    s.lathe("Stone", (x, 1.2, z), [(1.9, 0), (1.7, 1.2), (0.9, 1.6), (0.7, 3.6), (1.2, 4.0), (3.0, 4.4), (3.2, 4.8),
                                   (2.6, 4.9), (0.6, 5.0), (0.5, 6.4), (0.9, 6.8), (0.2, 7.6)], 28)
    s.polygon("Water", [(x + math.cos(a) * 2.7, 6.1, z + math.sin(a) * 2.7)
                        for a in reversed([2 * math.pi * k / 24 for k in range(24)])])
    s.emitter("fountain", (x, 7.6, z))
    s.light("point", (x, 3, z), (150, 200, 255), 16, 0.8)
    # An octagon of colliders for the round basin.
    s.collider((x, 1.1, z), (17.4, 2.2, 17.4), 0)
    s.collider((x, 1.1, z), (17.4, 2.2, 17.4), 45)


def grounds(s):
    kit.floor(s, -110, -90, 110, 90, "Grass", y=0)
    paths = [(-6, -64, 6, 54), (-108, -6, 108, 6), (-79, -40, -71, -6), (71, -40, 79, -6), (71, 6, 79, 40),
             (-79, 6, -71, 40), (-50, -64, -6, -56), (6, -64, 50, -56), (-50, 56, -15, 64), (15, 56, 50, 64)]
    for x1, z1, x2, z2 in paths:
        kit.top_rect(s, "PaversWarm", x1, z1, x2, z2, 0.04)
    # Curbs along the main paths.
    for x in (-6.3, 6.3):
        for z0, z1 in ((-64, -6), (6, 54)):
            s.box("Stone", (x, 0.1, (z0 + z1) / 2), (0.6, 0.2, z1 - z0), skip=("-y",))
    for z in (-6.3, 6.3):
        for x0, x1 in ((-108, -6), (6, 108)):
            s.box("Stone", ((x0 + x1) / 2, 0.1, z), (x1 - x0, 0.2, 0.6), skip=("-y",))
    for (x1, z1, x2, z2) in ((-110, -90, 110, -90), (110, -90, 110, 90), (110, 90, -110, 90), (-110, 90, -110, -90)):
        kit.pier_wall(s, x1, z1, x2, z2, 7, 13)
    for x, z in ((-28, -24), (28, -24), (-28, 24), (28, 24), (-45, 0), (45, 0), (-30, -60), (30, -60)):
        s.prop("Tree", x, z, (x * 13 + z * 7) % 360)
    for x, z in ((-104, -20), (104, 20), (-104, 28), (104, -28), (-36, 86), (36, 86), (-36, -86), (36, -86)):
        s.prop("Tree", x, z, (x * 3 + z * 11) % 360, 0.85)
    for x, z, rot in ((-14, -18, 0), (14, -18, 0), (-14, 18, 180), (14, 18, 180)):
        s.prop("Bench", x, z, rot)
    for x, z in ((-40, -84), (40, -84), (-104, 0), (104, 0)):
        s.prop("Crate", x, z, (x + z) % 90)
    for x1, z1, x2, z2 in ((-30, 43.5, -18, 44.5), (18, 43.5, 30, 44.5), (-70.5, -7, -69.5, 7), (69.5, -7, 70.5, 7)):
        kit.hedge(s, x1 - 0.4, z1 - 0.4, x2 + 0.4, z2 + 0.4, 6)
    # The noticeboard kiosk where the evidence board hangs (the game hangs the board itself).
    for x in (-6.4, 6.4):
        s.box("Wood", (x, 4.75, 30.4), (0.5, 9.5, 0.5), collide=True)
    kit.gable_roof(s, -7.4, 29.6, 7.4, 31.2, 9.5, 0.9, "Slate", "Wood", overhang=0.5)
    for x, z in ((-66, -8), (66, 8)):
        s.box("Stone", (x, 0.6, z), (3, 1.2, 3), collide=True)
        s.prop("Plant", x, z, 0, 0.9, 1.2)


def lamps(s):
    for i, (x, z) in enumerate(((-8, -34), (8, 34), (-40, 12), (40, -12))):
        kit.lantern_post(s, x, z, 11, shadows=True, flicker=i == 2)
    for x, z in ((-8, 48), (8, -48), (-60, -8), (60, 8), (-92, 8), (92, -8), (-40, -60), (40, 60)):
        kit.lantern_post(s, x, z, 10)
    for a in range(4):
        ang = math.radians(45 + a * 90)
        kit.bollard_light(s, math.cos(ang) * 11.5, math.sin(ang) * 11.5)


def weather(s):
    for x, z, rx, rz in ((3, -40, 2.5, 1.5), (-30, 3, 3, 1.5), (46, -2, 2, 1.5), (-2, 52, 2.5, 2), (70, 4, 3, 1.5),
                         (-60, -3, 2, 1.2), (24, 3, 2, 1)):
        kit.puddle(s, x, z, rx, rz)
    for x, z in ((-9, -26), (9, 26), (-30, 16), (30, -16), (-6, 44), (6, -44)):
        s.prop("TrashCan", x, z, (z * 5) % 360)
    for x, z in ((-104, -30), (104, 40)):
        s.box("BlackMetal", (x, 0.08, z), (2.4, 0.16, 2.4), skip=("-y",))
        for k in range(5):
            s.box("DarkMetal", (x - 1 + k * 0.5, 0.17, z), (0.12, 0.04, 2.2))
        s.emitter("steam", (x, 0.2, z))
    kit.skyline(s, 0, 0, 110, 90, seed=23, count=30, reach=(2.1, 2.9), height=(30, 80))


def preview(s):
    stations = [(-95, -62, -90), (-60, -76, 180), (95, -60, 90), (95, 62, 90), (-95, 62, -90), (-22, 8, -90),
                (22, -8, 90), (0, 81, 0)]
    for x, z, rot in stations:
        s.prop("Station", x, z, rot)
    s.prop("TipBox", 12, 70, 90)
    s.prop("EvidenceBoard", 0, 30, 0, 1.0, 6)


def build(s):
    grounds(s)
    buildings(s)
    clock_tower(s)
    fountain(s)
    lamps(s)
    weather(s)
