"""The lobby: a grand noir hall (100 x 100 studs, 26 high) with the Academy behind its south door.

Local coordinates match src/server/Maps/Lobby.luau. The game still builds everything that
shows text or does something (title, boards, how-to-play, the spawn pad, drill desks and
dummies); this scene is the building around them and its furniture.
"""

import math

from maps import kit

H = 26
HALF = 50
ACADEMY = (-30, 50, 30, 96)
ACADEMY_H = 14.5

VIEWS = [
    ((0, 13, 44), (0, 12, -50), 17),
    ((43, 7, -43), (-8, 5, 20), 17),
    ((-44, 18, 44), (10, 6, -30), 16),
    ((0, 8.5, 53), (0, 3.5, 92), 18),
]

HALL_TRIM = {"base": "BlackTrim", "wainscot": ("WoodPanel", 6.5), "rail": "Brass", "crown": "CreamTrim"}
ACADEMY_TRIM = {"base": "BlackTrim", "wainscot": ("WoodPanel", 4.2), "rail": "Wood", "crown": "Wood"}


def clerestory(at):
    return {"at": at, "w": 6, "bottom": 19.6, "top": 24.4, "kind": "window", "frame": "BlackMetal",
            "mullions": "BlackMetal", "cols": 2, "rows": 3, "glass": "Glass", "sill": "Stone"}


def hall(s):
    kit.floor(s, -HALF, -HALF, HALF, HALF, "MarbleBlack", border=("MarbleWhite", 4))
    side_windows = [clerestory(at) for at in (10, 30, 50, 70, 90)]
    north_windows = [clerestory(at) for at in (10, 90)]
    door = {"at": 50, "w": 12, "bottom": 0, "top": 9.5, "kind": "door", "frame": "Stone", "casing": 0.8}
    walls = [
        ((-HALF, -HALF), (HALF, -HALF), north_windows),
        ((HALF, -HALF), (HALF, HALF), side_windows),
        ((HALF, HALF), (-HALF, HALF), [door]),
        ((-HALF, HALF), (-HALF, -HALF), side_windows),
    ]
    for a, b, ops in walls:
        kit.wall(s, a, b, H, core="ConcreteDark", side_s="Wallpaper", openings=ops, trim_s=HALL_TRIM)
    # A stone string course under the windows, broken where the title and the boards hang.
    course = [(0, 0), (0.3, 0.05), (0.35, 0.6), (0.5, 0.8), (0.5, 1.1), (0, 1.1)]
    y = 18.2
    for x0, x1 in ((-49.5, -24.5), (24.5, 49.5)):
        s.sweep("Stone", (x0, y, -49.5), (x1, y, -49.5), course, (0, 0, 1))
    for z0, z1 in ((-49.5, -40.2), (-23.8, -16.4), (16.4, 23.8), (40.2, 49.5)):
        s.sweep("Stone", (49.5, y, z0), (49.5, y, z1), course, (-1, 0, 0))
        s.sweep("Stone", (-49.5, y, z0), (-49.5, y, z1), course, (1, 0, 0))
    s.sweep("Stone", (49.5, y, 49.5), (-49.5, y, 49.5), course, (0, 0, -1))
    kit.ceiling(s, -HALF, -HALF, HALF, HALF, H, "PlasterDark", beams=12.5, beam_mat="Wood", beam_depth=1.4, beam_w=1.0)
    for x in (-32, 32):
        for z in (-32, 0, 32):
            kit.column_round(s, x, z, H, 1.3, "MarbleColumn", trim="Brass", flutes=14)


def runner(s):
    """The red carpet from the spawn to the title wall, with gold edges."""
    x0, x1, z0, z1 = -5, 5, -44, 18
    s.box("CarpetRed", (0, 0.04, (z0 + z1) / 2), (x1 - x0, 0.08, z1 - z0), skip=("-y",))
    for x in (x0 - 0.2, x1 + 0.2):
        s.box("Gold", (x, 0.05, (z0 + z1) / 2), (0.4, 0.1, z1 - z0 + 0.4), skip=("-y",))
    for z in (z0 - 0.2, z1 + 0.2):
        s.box("Gold", (0, 0.05, z), (x1 - x0, 0.1, 0.4), skip=("-y",))


def zero_mark(s, cx=0.0, cz=26.0):
    """Zero's mark: a brass 0 inlaid in the marble, with a thin gold light in its groove."""
    steps = 48
    for rx, rz, w, mat, y in ((4.6, 7.2, 1.3, "Gold", 0.03), (3.95, 6.55, 0.14, "NeonYellow", 0.05)):
        for k in range(steps):
            a0 = 2 * math.pi * k / steps
            a1 = 2 * math.pi * (k + 1) / steps
            pts = []
            for a, r in ((a0, 0), (a1, 0), (a1, w), (a0, w)):
                pts.append((cx + math.cos(a) * (rx - r), y, cz + math.sin(a) * (rz - r)))
            s.polygon(mat, [pts[0], pts[3], pts[2], pts[1]])
    s.light("point", (cx, 1.2, cz), (255, 214, 120), 12, 0.6)


def title_wall(s):
    z = -HALF + 0.5
    # A stone frame around the title the game writes (44 x 9 at y 17); the tagline hangs below.
    for x in (-22.7, 22.7):
        s.box("Stone", (x, 17.25, z + 0.4), (1.2, 10.5, 0.8))
    s.box("Stone", (0, 22.2, z + 0.4), (46.6, 0.8, 0.8))
    s.box("Stone", (0, 12.25, z + 0.4), (46.6, 0.5, 0.8))
    s.box("BlackTrim", (0, 17.2, z + 0.12), (44.6, 9.6, 0.2))
    # Tall red banners with gold rods either side.
    for x in (-31, 31):
        s.box("FabricRed", (x, 15.5, z + 0.35), (5, 15, 0.12))
        s.box("Gold", (x, 23.2, z + 0.5), (6, 0.25, 0.25))
        for dx in (-2.2, 0, 2.2):
            s.box("Gold", (x + dx, 7.8, z + 0.42), (0.5, 0.5, 0.06))
        s.polygon("FabricRed", [(x - 2.5, 8.0, z + 0.42), (x + 2.5, 8.0, z + 0.42), (x, 6.2, z + 0.42)])
        s.box("Gold", (x, 15.5, z + 0.43), (0.6, 13.5, 0.04))
    for x in (-38, 38):
        kit.sconce(s, x, 12, z, 180, range_=18, brightness=1.0)


def board_frames(s):
    """Brass frames around the boards the game hangs on the east and west walls."""
    for x, face in ((HALF - 0.5, -1), (-HALF + 0.5, 1)):
        for z, w, h in ((-32, 14, 14), (32, 14, 14)):
            frame(s, x, 11, z, w, h, face)
        frame(s, x, 11, 0, 30 if face > 0 else 26, 14 if face > 0 else 8, face)
        for z in (-20, 20):
            kit.sconce(s, x, 10, z, -90 if face > 0 else 90, range_=16, brightness=0.9)


def frame(s, x, y, z, w, h, face):
    d = 0.35
    for dz in (-w / 2 - 0.3, w / 2 + 0.3):
        s.box("Brass", (x + face * d / 2, y, z + dz), (d, h + 1.2, 0.6))
    for dy in (-h / 2 - 0.3, h / 2 + 0.3):
        s.box("Brass", (x + face * d / 2, y + dy, z), (d, 0.6, w + 1.2))


def lounge(s):
    for x in (-30, 30):
        s.box("CarpetGrey", (x, 0.03, -42), (16, 0.06, 10), skip=("-y",))
        s.prop("Sofa", x, -44.5, 180)
        for dx in (-3.2, 0, 3.2):
            s.prop("Bookshelf", x + dx, -48.5, 180)
        floor_lamp(s, x + 6.5, -45.5)
        floor_lamp(s, x - 6.5, -45.5)
    for x in (-40, 40):
        s.prop("Table", x, -42, 90, 0.8)
    for z in (-20, 20):
        s.prop("Bench", -40, z, -90)
        s.prop("Bench", 40, z, 90)
    for x in (-14, 14):
        s.prop("VendingMachine", x, 47.6, 0)
    for x, z in ((-45, -45), (45, -45), (-45, 45), (45, 45), (-8, 44), (8, 44)):
        s.prop("Plant", x, z, (x * 7 + z * 3) % 360)


def floor_lamp(s, x, z):
    s.cylinder("Brass", (x, 0, z), 0.6, 0.2, 16)
    s.tube("Brass", (x, 0.2, z), (x, 5.2, z), 0.07, 8)
    s.lathe("CreamTrim", (x, 5.0, z), [(1.0, 0), (0.6, 1.2)], 16, caps=(False, False))
    s.lathe("CreamTrim", (x, 5.0, z), [(0.6, 1.2), (1.0, 0)], 16, caps=(False, False))
    s.light("point", (x, 5.3, z), kit.WARM, 14, 0.9)


def hall_lights(s):
    for z in (-24, 0, 24):
        kit.chandelier(s, 0, H - 1.4, z, r=3.2, drop=7, arms=10, range_=40, brightness=1.4, shadows=z == 0)
    for x in (-24, 24):
        for z in (-24, 24):
            kit.pendant(s, x, H - 1.4, z, drop=6, shade="Brass", range_=30, brightness=1.0, wide=1.6)


def door_arch(s):
    # Stone pillars and a lintel around the Academy door; the game hangs its sign between them.
    z = HALF - 0.5
    for x in (-7.6, 7.6):
        s.box("Stone", (x, 6.6, z - 0.45), (1.4, 13.2, 0.9))
        s.box("Stone", (x, 13.5, z - 0.5), (1.8, 0.6, 1.0))
    s.box("Stone", (0, 13.9, z - 0.45), (17, 1.0, 0.9))
    s.box("Stone", (0, 14.8, z - 0.6), (2.2, 1.4, 1.2))


def academy(s):
    x1, z1, x2, z2 = ACADEMY
    kit.floor(s, x1, z1, x2, z2, "WoodFloor")
    # Each wall runs so its n side faces out of the room (the trims go on the inside).
    for a, b in (((x1, z2), (x1, z1)), ((x2, z1), (x2, z2)), ((x2, z2), (x1, z2))):
        kit.wall(s, a, b, ACADEMY_H, core="ConcreteDark", side_s="PlasterDark", trim_s=ACADEMY_TRIM)
    kit.ceiling(s, x1, z1, x2, z2, ACADEMY_H, "Ceiling")
    for x in (-14, 14):
        for z in (62, 80):
            kit.panel_light(s, x, ACADEMY_H, z, 6, 3, range_=30, brightness=1.1)
    # Bookcases between the drill desks.
    for x, rot in ((x1 + 1.4, -90), (x2 - 1.4, 90)):
        for z in (68, 80):
            s.prop("Bookshelf", x, z, rot)
    # Framed case posters high on the walls, a clock and sconces.
    for x, face in ((x1 + 0.5, 1), (x2 - 0.5, -1)):
        for z in (56, 92):
            s.box("Wood", (x + face * 0.1, 7.5, z), (0.2, 4.2, 3.4))
            s.box("Paper", (x + face * 0.22, 7.5, z), (0.06, 3.8, 3.0))
            s.box("RedTrim", (x + face * 0.26, 8.6, z), (0.04, 0.3, 2.4))
        for z in (68, 80):
            kit.sconce(s, x, 9.6, z, -90 if face > 0 else 90, range_=14, brightness=0.8)
    for x in (-18, 18):
        kit.sconce(s, x, 10.5, z2 - 0.5, 0, range_=14, brightness=0.8)
    # A lectern and two benches for the dummies' audience.
    s.box("Wood", (0, 2.1, 90), (3, 4.2, 1.6), collide=True)
    s.box("Brass", (0, 3.6, 89.15), (1.8, 0.4, 0.06))
    for x in (-10, 10):
        s.prop("Bench", x, 68, 0)


def outside(s):
    kit.skyline(s, 0, 0, 62, 62, seed=7, count=26, reach=(1.6, 2.4), height=(50, 130), arc=(40, 320))


def preview(s):
    """What the game builds itself, for the previews only (sign panels and the drill desks)."""
    s.box("Screen", (0, 17, -49.2), (44, 9, 0.3))
    s.box("Screen", (0, 10.5, -49.2), (36, 3, 0.3))
    s.box("Screen", (-49.2, 11, 0), (0.3, 14, 30))
    s.box("Screen", (49.2, 11, 0), (0.3, 8, 26))
    for x in (-49.2, 49.2):
        for z in (-32, 32):
            s.box("Screen", (x, 11, z), (0.3, 14, 14))
    s.box("MarbleWhite", (0, 0.2, 14), (12, 0.4, 12))
    for x, z in ((-26, 62), (-26, 74), (-26, 86), (26, 62), (26, 74), (26, 86)):
        s.box("DarkMetal", (x, 1.5, z), (2.4, 3, 5))
    for x in (-8, 0, 8):
        s.box("Stone", (x, 3, 80), (2, 6, 1))


def build(s):
    hall(s)
    runner(s)
    zero_mark(s)
    title_wall(s)
    board_frames(s)
    lounge(s)
    hall_lights(s)
    door_arch(s)
    academy(s)
    outside(s)
