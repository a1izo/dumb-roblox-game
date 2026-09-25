"""Agency HQ (map id TaskForceHQ): an open-plan office in the middle with six rooms around it.
x -80..80, z -60..60, ceiling at 14. Local coordinates match src/server/Maps/TaskForceHQ.luau:
the rooms, doors and furniture stand where they always did, so the stations, sheets, drop
points and hoods (built by the game) keep their places and sight lines.
"""

import math

from maps import kit

H = 14
ROOM_TRIM = {"base": "BlackTrim", "wainscot": ("PlasterDark", 3.8), "rail": "Steel", "crown": "WhiteTrim"}

VIEWS = [
    ((-6, 9, 44), (6, 2, -30), 16),
    ((-44, 7.5, -44), (-72, 2, -8), 18),
    ((44, 7.5, -44), (72, 2, -6), 18),
    ((0, 60, 0), (0, 0, 0.01), 12),
    ((-44, 7.5, 44), (-72, 2, 26), 18),
    ((44, 7.5, 52), (74, 2, 22), 18),
]


def window(at, w=8):
    return {"at": at, "w": w, "bottom": 4.5, "top": 11.5, "kind": "window", "frame": "BlackMetal",
            "mullions": "BlackMetal", "cols": 2, "rows": 2, "blinds": True, "blinds_side": -1, "slat": "CreamTrim",
            "sill": "WhiteTrim"}


def door(at, w):
    return {"at": at, "w": w, "bottom": 0, "top": 9, "kind": "door", "frame": "Wood"}


def shell(s):
    floors = [
        ((-40, -60, 40, 60), "CarpetGrey"),
        ((-80, -60, -40, -20), "Concrete"),
        ((-80, -20, -40, 20), "TileChecker"),
        ((-80, 20, -40, 60), "WoodFloorDark"),
        ((40, -60, 80, -20), "TileWhite"),
        ((40, -20, 80, 20), "MarbleWhite"),
        ((40, 20, 80, 60), "MetalFloor"),
    ]
    for (x1, z1, x2, z2), mat in floors:
        kit.floor(s, x1, z1, x2, z2, mat)
    # Outer walls: n points out of the building; windows look out on the city.
    north = [window(80 + x) for x in (-24, -8, 8, 24, 52, 68)]
    east = [window(60 + z) for z in (-50, -34, 12, 28)]
    south = [window(80 - x) for x in (-72, -56, -24, -8, 8, 24)]
    west = [window(60 - z) for z in (2, 12, 32, 48)]
    outer = [((-80, -60), (80, -60), north), ((80, -60), (80, 60), east), ((80, 60), (-80, 60), south),
             ((-80, 60), (-80, -60), west)]
    for a, b, ops in outer:
        kit.wall(s, a, b, H, core="ConcreteDark", side_s="PlasterGrey", openings=ops, trim_s=ROOM_TRIM)
    # Office side walls with a door into every side room (as in the part-built map).
    for x in (-40, 40):
        doors = [door(20, 8), door(60, 10), door(100, 8)]
        kit.wall(s, (x, -60), (x, 60), H, core="PlasterGrey", side_n="PlasterGrey", side_s="PlasterGrey",
                 openings=doors, trim_n=ROOM_TRIM, trim_s=ROOM_TRIM)
    for x1, x2 in ((-80, -40), (40, 80)):
        for z in (-20, 20):
            kit.wall(s, (x1, z), (x2, z), H, core="PlasterGrey", openings=[door(20, 8)], trim_n=ROOM_TRIM,
                     trim_s=ROOM_TRIM)
    # Suspended ceiling everywhere, with light panels where the old lights hung.
    kit.ceiling(s, -80, -60, 80, 60, H, "Ceiling")
    for x in (-26, 0, 26):
        for z in (-40, -14, 14, 40):
            kit.panel_light(s, x, H, z, 6, 2.5, range_=30, brightness=1.0)
    for x in (-60, 60):
        for z in (-40, 0, 40):
            kit.panel_light(s, x, H, z, 5, 2.5, range_=32, brightness=1.05, color=kit.COOL if x > 0 and z > 20 else kit.WARM)
    # Red strips along the top of the long walls.
    for z in (-59.4, 59.4):
        s.box("NeonRed", (0, H - 0.4, z), (60, 0.12, 0.12))
        s.light("point", (0, H - 1, z * 0.97), (255, 40, 60), 14, 0.5)
    s.box("NeonBlue", (79.4, 12, 0), (0.12, 0.12, 30))
    kit.skyline(s, 0, 0, 80, 62, seed=11, count=30, reach=(1.35, 2.0), height=(40, 120))


def open_office(s):
    for x in (-30, -18, 18, 30):
        s.prop("Desk", x, -52, 180)
        s.prop("OfficeChair", x, -49.2, 0)
        s.prop("Desk", x, 52, 0)
        s.prop("OfficeChair", x, 49.2, 180)
    # Cubicle partitions (as tall as before, so sight lines do not change).
    for x in (-26, 26):
        for z0, z1 in ((-24, -8), (8, 24)):
            partition(s, x, z0, z1)
    for x in (-12, 12):
        for z in (-26, 26):
            kit.column_square(s, x, z, H, 3, "PlasterLight", trim="BlackTrim")
    s.prop("Table", 0, 0, 0)  # full size: a paper sheet rests on it at 2.8
    s.box("DarkMetal", (0, 3.1, 0.6), (2.4, 0.8, 1.4), collide=True)  # a speakerphone console
    s.box("NeonGreen", (0, 3.52, 0.25), (1.6, 0.05, 0.3))
    for x, z in ((-36, -56), (36, -56), (-36, 56), (36, 56)):
        s.prop("Plant", x, z, (x * 5 + z) % 360)
    for x in (-34, 34):
        for z in (-36, 36):
            s.prop("TrashCan", x, z, 0)
    # Water cooler and a noticeboard on the office walls.
    for x, face in ((-39.5, 1), (39.5, -1)):
        s.box("Wood", (x + face * 0.1, 6.5, -48), (0.2, 3.6, 5))
        s.box("Paper", (x + face * 0.22, 6.5, -48), (0.05, 3.2, 4.6))
        for dz, dy in ((-1.4, 0.6), (0.4, -0.5), (1.5, 0.8)):
            s.box("Paper", (x + face * 0.26, 6.5 + dy, -48 + dz), (0.03, 1.0, 1.1))
            s.box("NeonRed", (x + face * 0.29, 7.0 + dy, -48 + dz), (0.04, 0.12, 0.12))


def partition(s, x, z0, z1):
    length = z1 - z0
    mid = (z0 + z1) / 2
    s.box("Fabric", (x, 3, mid), (0.5, 6, length), collide=True)
    s.box("Steel", (x, 6.05, mid), (0.6, 0.1, length + 0.1))
    for z in (z0, z1):
        s.box("Steel", (x, 3, z), (0.6, 6, 0.12))


def security_office(s):
    # The monitor wall on the north wall (where the blue screens always glowed).
    z = -59.5
    for i in range(4):
        for j in range(2):
            x = -71 + i * 6
            y = 6.4 + j * 3.4
            s.box("BlackMetal", (x, y, z + 0.35), (5.4, 3.2, 0.5))
            s.box("NeonBlue" if (i + j) % 3 else "NeonCool", (x, y, z + 0.62), (4.8, 2.7, 0.04))
    s.light("point", (-62, 7.5, -56), (80, 150, 255), 22, 1.2)
    s.box("BlackMetal", (-62, 3.8, z + 0.4), (24, 0.3, 0.8))
    s.prop("Desk", -58, -54, 180)
    s.prop("OfficeChair", -58, -51.2, 0)
    s.prop("FilingCabinet", -77, -26, -90)
    s.prop("FilingCabinet", -44, -26, 180)
    s.prop("FilingCabinet", -77, -30, -90)
    # A weapons locker and a coat rack by the door.
    s.box("DarkMetal", (-78.6, 3.5, -46), (2.2, 7, 4), collide=True)
    s.box("BlackTrim", (-77.45, 3.5, -46), (0.05, 6.4, 0.1))


def break_room(s):
    s.prop("VendingMachine", -78.2, -12, -90)
    s.prop("VendingMachine", -78.2, -7, -90)
    kit.counter(s, -70, -17.5, 180, 8, top="Wood", body="CreamTrim")
    # Fridge and coffee machine on the counter.
    s.box("Steel", (-64.6, 3.6, -18.1), (2.6, 7.2, 2.6), collide=True)
    s.box("BlackTrim", (-64.6, 4.9, -16.78), (2.4, 0.05, 0.05))
    s.box("BlackMetal", (-68, 4.3, -18.2), (1.2, 1.6, 1.0))
    s.box("NeonOrange", (-68, 4.7, -17.68), (0.3, 0.1, 0.03))
    for dx in (-66.5, -66):
        s.cylinder("WhiteTrim", (dx, 3.5, -18), 0.2, 0.45, 10)
    s.prop("Table", -66, -2, 0)
    s.prop("Chair", -66, -5, 180)
    s.prop("Chair", -66, 1, 0)
    s.prop("Sofa", -76, 10, -90)
    s.prop("Plant", -44, 16, 30)
    kit.pendant(s, -66, H, -2, drop=5, shade="RedTrim", range_=18, brightness=1.0, wide=1.3)


def archive(s):
    for x, z, w in ((-60, 32, 10), (-60, 48, 10), (-46, 32, 6), (-46, 48, 6)):
        count = max(1, round(w / 3.2))
        unit = w / count
        for i in range(count):
            s.prop("Bookshelf", x - w / 2 + unit * (i + 0.5), z, 0, unit / 3.2)
    s.prop("Table", -50, 55, 0)
    s.prop("Chair", -50, 52.2, 0)
    s.prop("FilingCabinet", -77, 24, -90)
    for z in (32, 48):
        kit.pendant(s, -54, H, z - 8, drop=4, shade="Brass", range_=16, brightness=0.8, wide=1.0)


def forensics(s):
    kit.counter(s, 62, -57, 180, 14, top="MarbleWhite", body="WhiteTrim")
    kit.counter(s, 56, -30, 0, 10, top="MarbleWhite", body="WhiteTrim")
    # Microscope, sample racks and a light box on the benches.
    s.box("BlackMetal", (56, 4.0, -30), (0.6, 1.0, 0.6))
    s.cylinder("Steel", (56, 4.5, -30.2), 0.12, 0.8, 8)
    s.box("NeonCyan", (52, 3.6, -30), (1.4, 0.1, 0.9))
    for i in range(5):
        s.cylinder("Glass", (58.5 + i * 0.35, 3.5, -57), 0.12, 0.6, 8)
    s.box("NeonCool", (60, 7.2, -59.45), (5.6, 3.2, 0.05))  # X-ray light box between the windows
    s.box("BlackMetal", (60, 7.2, -59.52), (6.0, 3.6, 0.1))
    s.prop("FilingCabinet", 77, -26, 90)
    s.prop("FilingCabinet", 44, -57, 0)
    s.box("Steel", (78.6, 3.6, -40), (2.4, 7.2, 3.6), collide=True)  # evidence fridge
    s.light("point", (56, 8, -30), kit.COOL, 18, 0.8)


def reception(s):
    kit.counter(s, 64, 4, 90, 10, top="MarbleBlack", body="Wood")
    s.box("Brass", (62.78, 1.8, 4), (0.04, 0.2, 9.6))
    s.prop("Sofa", 50, 16.5, 0)
    s.prop("Plant", 76, -16, 20)
    s.prop("Plant", 44, 16, 60)
    # The agency's name on a lit panel behind the desk.
    s.box("WoodPanel", (79.4, 8, -8), (0.2, 5, 16))
    s.sign((79.2, 9, -8), 90, 14, 3, "AGENCY HQ", "GothamBlack", (235, 235, 235), None, (200, 220, 255))
    s.box("NeonCool", (79.25, 6.8, -8), (0.05, 0.08, 12))


def server_room(s):
    for x in (50, 54, 58, 62):
        s.prop("ServerRack", x, 30, 180)
        s.prop("ServerRack", x, 50, 0)
    # Cable trays over the rack rows.
    for z in (30, 50):
        s.box("DarkMetal", (56, 11, z), (16, 0.2, 1.4))
        for x in (48, 56, 64):
            s.tube("DarkMetal", (x, 11, z), (x, H, z), 0.05, 5)
        for k in range(6):
            s.tube("RedTrim" if k % 2 else "BlackTrim", (48.5, 11.2, z - 0.4 + k * 0.16), (63.5, 11.2, z - 0.4 + k * 0.16),
                   0.06, 5)
    for z in (36, 44):
        s.light("point", (56, 6, z), (120, 170, 255), 18, 0.7)


def dressing(s):
    """Whiteboards, photos, clocks, exit signs, extinguishers and vents on the walls."""
    # Open office: faces of the x = -40 wall look east (rot -90), of x = 40 west (rot 90).
    kit.whiteboard(s, -39.5, 7, -24, -90, 8, 3.6)
    kit.whiteboard(s, -39.5, 7, 22, -90, 8, 3.6)
    kit.whiteboard(s, 39.5, 7, 22, 90, 8, 3.6)
    for z in (-54, 16, 54):
        kit.picture(s, 39.5, 7.2, z, 90, 2.4, 3.0)
    kit.wall_clock(s, 0, 11, -59.5, 180, 1.1)
    kit.wall_clock(s, 0, 11, 59.5, 0, 1.1)
    for x, z, rot in ((-39.5, -34, -90), (39.5, -34, 90), (-39.5, 46, -90), (39.5, 46, 90)):
        kit.exit_sign(s, x, 10, z, rot)
    for x, z, rot in ((-39.5, -12, -90), (39.5, 12, 90)):
        kit.extinguisher(s, x, z, rot)
    for x in (-60, 60):
        for z, rot in ((-59.5, 180), (59.5, 0)):
            kit.vent(s, x + 12, 12.3, z, rot)
    # Side rooms.
    kit.picture(s, -79.5, 7.5, -30, -90, 3, 2.2, "BlackMetal", "Screen")  # security: a map of the city
    kit.whiteboard(s, -40.5, 7, -30, 90, 6, 3.2)
    kit.picture(s, -40.5, 7, 12, 90, 2.4, 3.0)
    kit.wall_clock(s, -60, 10, -19.5, 180, 0.9)
    kit.picture(s, -79.5, 7.5, 52, -90, 2.6, 3.2)
    kit.whiteboard(s, 40.5, 7, -48, -90, 6, 3.2)
    kit.picture(s, 40.5, 7.5, 10, -90, 3.4, 2.4)
    kit.picture(s, 40.5, 7.5, 16, -90, 2.4, 3.0)
    kit.extinguisher(s, 40.5, 52, -90)
    kit.exit_sign(s, 60, 10, 19.5, 0)


def preview(s):
    """What the game builds itself (stations, tip box, board), for the previews only."""
    stations = [(-74, -40, -90), (74, -40, 90), (-74, 40, -90), (74, 40, 90), (-16, -8, 180), (16, 8, 0),
                (-52, 10, 90), (48, -10, -90)]
    for x, z, rot in stations:
        s.prop("Station", x, z, rot)
        turn = kit.ry(rot)
        p = turn((0, 0, 0.8))
        s.box("Screen", (x + p[0], 5.4, z + p[2]), (4.4, 2.6, 0.3), rot)
    s.prop("TipBox", 74, 10, 90)
    s.prop("EvidenceBoard", 39.35, -24, 90, 1.0, 7)


def build(s):
    shell(s)
    open_office(s)
    security_office(s)
    break_room(s)
    archive(s)
    forensics(s)
    reception(s)
    server_room(s)
    dressing(s)
