"""The meeting room: the Agency's war room. 60 x 60 studs, 18 high, round table in the middle
(placed by the game with the seats), Zero's screen on the north wall, the evidence board on the
east wall, the Specters' gallery walkway at 12 studs.

Local coordinates match src/server/Maps/MeetingRoom.luau.
"""

import math

from maps import kit

H = 18
HALF = 30

# Where the preview puts the pieces the game builds itself.
SEATS = 12
SEAT_RADIUS = 17

VIEWS = [
    ((24, 13, 25), (-6, 3, -6), 18),
    ((0, 5.5, 25), (0, 8, -29), 22),
    ((-25, 14, -23), (8, 2, 8), 20),
]

INTERIOR = {"base": "BlackTrim", "wainscot": ("WoodPanel", 5.2), "rail": "Wood", "crown": "Wood"}


def room(s):
    kit.floor(s, -HALF, -HALF, HALF, HALF, "CarpetRed", border=("WoodFloorDark", 3.5))
    windows = [
        {"at": at, "w": 7, "bottom": 3.6, "top": 11.2, "kind": "window", "frame": "Wood", "mullions": "Wood",
         "cols": 2, "rows": 3, "blinds": True, "blinds_side": -1, "slat": "BlackTrim", "sill": "Wood"}
        for at in (14, 30, 46)
    ]
    walls = [
        ((-HALF, -HALF), (HALF, -HALF), []),
        ((HALF, -HALF), (HALF, HALF), []),
        ((HALF, HALF), (-HALF, HALF), windows),
        ((-HALF, HALF), (-HALF, -HALF), []),
    ]
    for a, b, ops in walls:
        kit.wall(s, a, b, H, core="ConcreteDark", side_s="Wallpaper", openings=ops, trim_s=INTERIOR)
    kit.ceiling(s, -HALF, -HALF, HALF, HALF, H, "PlasterDark", beams=10, beam_mat="Wood", beam_depth=1.1, beam_w=0.9)
    s.box("Wood", (0, H - 1.25, 0), (8, 0.6, 8), skip=("+y",))  # the rose the spotlight hangs from


def zero_screen(s):
    # The game draws the screen (30 x 12 at y = 10); this is its bezel and the red neon.
    z = -HALF + 0.5
    for x, w in ((-15.6, 1.2), (15.6, 1.2)):
        s.box("BlackMetal", (x, 10, z + 0.3), (w, 13.4, 0.6))
    for y in (3.4, 16.6):
        s.box("BlackMetal", (0, y, z + 0.3), (32.4, 1.2, 0.6))
    for x in (-17.2, 17.2):
        s.box("NeonRed", (x, 10, z + 0.12), (0.18, 12, 0.18))
        s.light("point", (x, 10, z + 1.5), (255, 40, 60), 12, 0.8)
    s.box("Brass", (0, 2.2, z + 0.1), (6, 0.8, 0.12))
    s.sign((0, 2.2, z + 0.18), 180, 5.6, 0.7, "THE AGENCY  ·  WAR ROOM", "SpecialElite", (30, 22, 14), None)


def gallery(s):
    """The Specters' walkway around the walls at 12 studs (no collisions: Specters fly)."""
    y, depth = 12, 3.5
    inner = HALF - 0.5 - depth
    edge = HALF - 0.5
    slabs = [
        ((0, -edge + depth / 2), (HALF * 2 - 1, depth)),
        ((0, edge - depth / 2), (HALF * 2 - 1, depth)),
        ((-edge + depth / 2, 0), (depth, HALF * 2 - 1 - depth * 2)),
        ((edge - depth / 2, 0), (depth, HALF * 2 - 1 - depth * 2)),
    ]
    for (x, z), (sx, sz) in slabs:
        s.box("MetalFloor", (x, y - 0.2, z), (sx, 0.4, sz), mats={"-y": "BlackMetal"})
    corners = [(-inner, -inner), (inner, -inner), (inner, inner), (-inner, inner), (-inner, -inner)]
    kit.railing(s, corners, 3.0, "BlackMetal", 3.2, base=y, collide=False)
    # Brackets under the walkway.
    for i in range(-4, 5):
        p = i * 6.5
        for x, z, ux in ((p, -edge, (0, 0, 1)), (p, edge, (0, 0, -1)), (-edge, p, (1, 0, 0)), (edge, p, (-1, 0, 0))):
            if abs(p) > HALF - 4:
                continue
            base = (x, y - 0.4, z)
            tip = (x + ux[0] * (depth - 0.4), y - 0.4, z + ux[2] * (depth - 0.4))
            low = (x, y - 3.2, z)
            s.tube("BlackMetal", low, tip, 0.1, 6)
            s.tube("BlackMetal", base, tip, 0.08, 6)


def lights(s):
    kit.spotlight_rig(s, 0, H - 1.6, 0, range_=26, brightness=5, angle=60)
    for x in (-14, 14):
        for z in (-14, 14):
            kit.pendant(s, x, H - 1.1, z, drop=3.6, shade="Brass", range_=26, brightness=1.0, wide=1.2)
    y = 7.2
    for z in (-12, 12):
        kit.sconce(s, HALF - 0.5, y, z, 90)
    for x in (-8, 8, -24, 24):
        kit.sconce(s, x, y, HALF - 0.5, 0)
    for x in (-22, 22):
        kit.sconce(s, x, y, -HALF + 0.5, 180)
    kit.sconce(s, -HALF + 0.5, y, -5, -90)
    kit.sconce(s, -HALF + 0.5, y, 5, -90)
    # A red glow under the rail of the wainscot, all round the room.
    for a, b in (((-29, -29.35), (29, -29.35)), ((-29, 29.35), (29, 29.35))):
        s.box("NeonRed", ((a[0] + b[0]) / 2, 0.85, a[1]), (58, 0.1, 0.1))
    for x in (-29.35, 29.35):
        s.box("NeonRed", (x, 0.85, 0), (0.1, 0.1, 58))
    for x, z in ((0, -27), (0, 27), (-27, 0), (27, 0)):
        s.light("point", (x, 1.2, z), (255, 40, 60), 12, 0.6)


def door(s):
    # A closed double door on the east wall, north of the board.
    x = HALF - 0.5
    z = -22
    for dz in (-1.5, 1.5):
        s.box("WoodPanel", (x - 0.08, 4.4, z + dz), (0.16, 8.6, 2.9), mats={"-x": "WoodPanel"})
        s.box("Brass", (x - 0.25, 4.2, z + dz * 0.25), (0.14, 1.2, 0.16))
    for dz in (-3.2, 3.2):
        s.box("Wood", (x - 0.12, 4.6, z + dz), (0.24, 9.2, 0.4))
    s.box("Wood", (x - 0.12, 9.3, z), (0.24, 0.5, 6.8))
    s.box("Brass", (x - 0.1, 10.6, z), (0.1, 0.7, 3))
    s.sign((x - 0.18, 10.6, z), 90, 2.8, 0.55, "RECORDS", "SpecialElite", (30, 22, 14), None)


def west_wall(s):
    x = -HALF + 0.5
    # A sideboard between the bookcases, a wall clock above it.
    s.box("Wood", (x + 1.1, 1.6, 0), (2.2, 3.2, 12), mats={"+y": "WoodFloorDark"}, collide=True)
    for dz in (-4, 0, 4):
        s.box("WoodPanel", (x + 2.22, 1.7, dz), (0.06, 2.4, 3.6))
        s.box("Brass", (x + 2.3, 2.0, dz), (0.1, 0.12, 0.8))
    s.cylinder("Brass", (x + 1.2, 3.2, 3.8), 0.35, 0.2, 12)
    s.tube("Brass", (x + 1.2, 3.4, 3.8), (x + 1.2, 5.2, 3.8), 0.06, 6)
    s.lathe("CreamTrim", (x + 1.2, 5.0, 3.8), [(0.8, 0), (0.45, 0.9)], 16, caps=(False, False))
    s.light("point", (x + 1.4, 5.2, 3.8), kit.WARM, 10, 0.8)
    # Clock: brass ring, pale face, hands.
    cx, cy = x + 0.15, 9.5
    face_mat = "Paper"
    ring = 2.1
    for k in range(24):
        a0 = 2 * math.pi * k / 24
        a1 = 2 * math.pi * (k + 1) / 24
        p0 = (cx, cy + math.cos(a0) * ring, math.sin(a0) * ring)
        p1 = (cx, cy + math.cos(a1) * ring, math.sin(a1) * ring)
        s.tube("Brass", p0, p1, 0.18, 6, caps=False)
    face = [(cx + 0.02, cy + math.cos(2 * math.pi * k / 24) * ring, math.sin(2 * math.pi * k / 24) * ring)
            for k in range(24)]
    s.polygon(face_mat, face)
    for k in range(12):
        a = 2 * math.pi * k / 12
        s.box("BlackTrim", (cx + 0.06, cy + math.cos(a) * 1.7, math.sin(a) * 1.7), (0.05, 0.35 if k % 3 == 0 else 0.2, 0.1))
    s.box("BlackTrim", (cx + 0.1, cy + 0.55, 0.3), (0.05, 1.3, 0.14))
    s.box("BlackTrim", (cx + 0.12, cy + 0.2, -0.55), (0.05, 0.12, 1.3))
    for z in (-12, 12):
        for dz in (-1.6, 1.6):
            s.prop("Bookshelf", x + 0.9, z + dz, -90)
    for z in (-24, 24):
        s.prop("FilingCabinet", x + 1.1, z, -90)
    for x2, z2 in ((-26, -26), (26, -26), (-26, 26), (26, 26)):
        s.prop("Plant", x2, z2, (x2 * 7 + z2 * 3) % 360)


def outside(s):
    kit.skyline(s, 0, 0, 60, 60, seed=4, count=14, reach=(1.1, 1.8), height=(30, 90), arc=(-70, 70))


def preview(s):
    """What the game builds itself, for the previews only."""
    s.prop("MeetingTable", 0, 0)
    for i in range(SEATS):
        angle = i * 2 * math.pi / SEATS
        s.prop("OfficeChair", math.sin(angle) * (SEAT_RADIUS + 2.6), math.cos(angle) * (SEAT_RADIUS + 2.6),
               math.degrees(angle))
    s.prop("EvidenceBoard", HALF - 0.9, 0, 90, 1.29, 8)
    s.box("Screen", (0, 10, -HALF + 0.75), (30, 12, 0.3))


def build(s):
    room(s)
    zero_screen(s)
    gallery(s)
    lights(s)
    door(s)
    west_wall(s)
    outside(s)
