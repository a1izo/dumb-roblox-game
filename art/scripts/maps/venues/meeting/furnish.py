"""The war room's furnishings: the round table and its twelve chairs, Zero's screen wall with its
speaker columns and red neon, the case wall of pinned photographs and red string round the
evidence board, the west wall's bookcases, sideboard and clock, radiators under the windows, the
corners' club chairs, globe, drinks trolley and old case files; the sconces and lamps. The anchors
for what the game builds (the screen, the board, the seats, the Specters' spots) go in here too."""

import math
import random

from maps import kit
from maps.venues.meeting import plan as P

IN = P.IN


def table(s):
    s.prop("WarTable", 0.0, 0.0, 0.0)
    # Round colliders for the table (the prop does not collide): six turned bars make a disc.
    for k in range(6):
        s.collider((0.0, 1.65, 0.0), (2 * P.TABLE_R, 3.3, 7.0), k * 30.0, True, "Wood")
    for x, z, rot in P.chairs():
        s.prop("WarChair", x, z, rot)
    for k, (x, z, rot) in enumerate(P.seats()):
        s.anchor(f"seat{k + 1}", x, 0.0, z, rot)
        s.spawn(x, z, 0.0, rot=rot)
    s.anchor("centre", 0.0, 0.0, 0.0, 0.0)


def screen_wall(s):
    x, y, z, rot, w, h = P.SCREEN
    s.anchor("screen", x, y, z, rot, w=w, h=h)
    face = -IN
    # The bezel round the game's screen, a dais of shadow under it, the red neon either side.
    for bx in (-w / 2 - 0.7, w / 2 + 0.7):
        s.box("BlackMetal", (bx, y, face + 0.35), (1.4, h + 2.8, 0.7))
    for by in (y - h / 2 - 0.7, y + h / 2 + 0.7):
        s.box("BlackMetal", (0.0, by, face + 0.35), (w + 2.8, 1.4, 0.7))
    s.box("Screen", (0.0, y, face + 0.05), (w + 0.2, h + 0.2, 0.1))
    for nx in (-w / 2 - 1.7, w / 2 + 1.7):
        s.box("NeonRed", (nx, y, face + 0.15), (0.16, h + 1.0, 0.16))
        s.light("point", (nx, y, face + 1.4), (255, 40, 60), 12, 0.7)
    for sx in (-1, 1):
        s.prop("SpeakerColumn", sx * P.SPEAKERS[0], P.SPEAKERS[1], 0.0)
    s.box("Brass", (0.0, 2.2, face + 0.08), (7.0, 0.9, 0.12))
    s.sign((0.0, 2.2, face + 0.16), 180, 6.6, 0.75, "THE AGENCY  ·  WAR ROOM", "SpecialElite", (30, 22, 14), None)


def case_wall(s):
    """The east wall: the board (the game's), and round it photographs, clippings and index cards
    pinned to the damask, red string strung between the pins."""
    x, y, z, rot, w, h = P.BOARD
    s.anchor("board", x, y, z, rot, w=w, h=h)
    face = IN - 0.06
    rng = random.Random(55)
    pins = []
    for zc, yc in ((14.5, 8.5), (19.5, 6.0), (16.0, 4.0), (21.5, 9.5), (13.5, 10.5), (18.5, 11.0), (-13.0, 9.0),
                   (-15.5, 5.5), (-12.0, 4.2), (-16.3, 11.0), (24.3, 5.0), (13.0, 6.5)):
        wz, hy = rng.uniform(1.4, 2.3), rng.uniform(1.6, 2.4)
        mat = rng.choice(("Photo", "PhotoPale", "Paper"))
        tilt = rng.uniform(-6, 6)
        s.obox(mat, (face, yc, zc), (0.04, hy, wz), (1, 0, 0), (0, math.cos(math.radians(tilt)), math.sin(math.radians(tilt))),
               (0, -math.sin(math.radians(tilt)), math.cos(math.radians(tilt))))
        if mat != "Paper":
            s.box("PhotoPale", (face - 0.03, yc - hy / 2 + 0.25, zc), (0.03, 0.35, wz * 0.9))
        pin = (face - 0.1, yc + hy / 2 - 0.2, zc)
        s.box("RedTrim", pin, (0.14, 0.14, 0.14))
        pins.append(pin)
    board_pins = [(face - 0.12, y + h / 2 - 0.6, z + w / 2 - 0.8), (face - 0.12, y - h / 2 + 0.8, z + w / 2 - 1.2),
                  (face - 0.12, y + h / 2 - 0.9, z - w / 2 + 0.8), (face - 0.12, y - 1.0, z - w / 2 + 1.0)]
    links = [(0, 1), (1, 2), (0, 4), (4, 5), (3, 5), (2, 10), (6, 7), (7, 8), (6, 9)]
    for a, b in links:
        s.tube("RedString", pins[a], pins[b], 0.025, 4)
    for k, bp in enumerate(board_pins):
        target = pins[(0, 2, 6, 8)[k]]
        s.tube("RedString", bp, target, 0.025, 4)


def west_wall(s):
    x = -IN
    s.prop("Sideboard", x + 1.3, 0.0, -90.0)
    for z in (-7.8, -12.4, 7.8, 12.4):
        s.prop("BookcaseTall", x + 0.95, z, -90.0)
    s.prop("WallClock", x + 0.3, 0.0, -90.0, 1.0, 9.6)
    s.prop("BankerLamp", x + 1.6, -3.4, -90.0, 1.0, 3.3)
    for z in (-22.0, 22.0):
        s.prop("FilingCabinet", x + 1.1, z, -90.0)


def south_wall(s):
    z = IN
    for x in P.WINDOWS:
        s.prop("Radiator", x, z - 0.45, 0.0)
    # The corners: club chairs round the trolley, the globe.
    s.prop("ClubChair", -23.5, 24.0, 150.0)
    s.prop("ClubChair", -26.0, 17.5, 110.0)
    s.prop("DrinksTrolley", -26.8, 24.5, 90.0)
    s.prop("FloorLamp", -26.8, 12.8, 0.0)
    s.prop("FloorGlobe", 25.0, 24.0, 30.0)
    s.prop("FloorLamp", 26.8, 18.5, 0.0)


def corners(s):
    s.prop("CaseFiles", 26.5, -26.8, 190.0)
    s.prop("CaseFiles", -26.4, -26.6, 170.0)
    s.prop("FloorLamp", -24.0, -26.8, 0.0)


def lights(s):
    y = 8.0
    for zz in (-18.7, 27.6):
        kit.sconce(s, IN - 0.05, y, zz, 90, range_=14, brightness=0.8)
    for xx in (-9.5, 9.5):
        kit.sconce(s, xx, y, IN - 0.05, 0, range_=14, brightness=0.8)
    for zz in (-19.0, 19.0):
        kit.sconce(s, -IN + 0.05, y, zz, -90, range_=14, brightness=0.8)
    for xx in (-25.0, 25.0):
        kit.sconce(s, xx, y, -IN + 0.05, 180, range_=14, brightness=0.8)
    # A red glow under the wainscot rail, round the room (between its features).
    for (ax, az), (bx, bz) in (((-28.8, -29.35), (-17.5, -29.35)), ((17.5, -29.35), (28.8, -29.35)),
                               ((-28.8, 29.35), (28.8, 29.35)), ((-29.35, -28.8), (-29.35, 28.8)),
                               ((29.35, -18.5), (29.35, -10.0)), ((29.35, 10.0), (29.35, 28.8))):
        s.box("NeonRed", ((ax + bx) / 2, 0.85, (az + bz) / 2), (max(0.1, abs(bx - ax)), 0.1, max(0.1, abs(bz - az))))
    for x, z in ((0.0, 27.0), (-27.0, 0.0), (27.0, 20.0)):
        s.light("point", (x, 1.2, z), (255, 40, 60), 12, 0.5)


def spots(s):
    for k, (x, z, rot) in enumerate(P.gallery_spots()):
        s.anchor(f"gallery{k + 1}", x, P.GALLERY_Y, z, rot)


def build(s):
    table(s)
    screen_wall(s)
    case_wall(s)
    west_wall(s)
    south_wall(s)
    corners(s)
    lights(s)
    spots(s)
