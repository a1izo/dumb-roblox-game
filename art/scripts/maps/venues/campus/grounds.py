"""The campus grounds on the eve of the exam, every lamp placed by hand.

- The ginkgo avenue: bare ginkgos in two rows, snow along their branches, Meiji-style lamps
  between them. By the gate stand the check-in tents, their kerosene heaters glowing, with
  queue posts and exam signs.
- The guard booth sits inside the red gate: Gate CCTV, and the tip box under its window. A
  police cordon is taped across the gate.
- The forecourt: the evidence board in its kiosk among the seat-chart boards, the founder's
  bust, the frozen fountain, benches.
- The pond hollow: pines in their yukizuri, stone lanterns, clipped shrubs under snow, the
  campus security camera post (the Pond Camera Post), the drop point beside the bridge's foot,
  a hood among the pines.
- The tennis court, look-only behind its chain-link fence: the net sagging under snow, the
  umpire's chair, the roller shed beside it.
- The bike shed, a hot-drinks machine, the avenue's phone box (a spare), snowmen, snow scoops,
  steam from vents, sounds.

Props with an anchor (the trees) are placed so their trunk stands on the spot asked for."""

import math
import random

from maps import catalog
from maps import geo2d as g2
from maps.mesher import cross, norm
from maps.venues.campus import fit, masonry
from maps.venues.campus import plan as P

CAT = catalog.load()
HY = P.HOLLOW_Y


def place(s, key, x, z, rot=0.0, y=0.0, scale=1.0):
    """A prop whose anchor (a trunk's or a pole's foot) stands on (x, z)."""
    ax, az = CAT.get(key, {}).get("anchor", [0.0, 0.0])
    a = math.radians(rot)
    wx = (ax * math.cos(a) + az * math.sin(a)) * scale
    wz = (-ax * math.sin(a) + az * math.cos(a)) * scale
    s.prop(key, x - wx, z - wz, rot, scale, y)


def ginkgo(s, x, z, rot, y=0.0, snow=False):
    place(s, "GinkgoBare", x, z, rot, y)
    s.collider((x, y + 5.0, z), (1.8, 10.0, 1.8), 0, True, None)
    if snow:
        s.emitter("branchsnow", (x, y + 16.0, z), 0, (10.0, 1.0, 10.0))


def pine(s, x, z, rot, y=0.0, snow=False):
    place(s, "PineYukizuri", x, z, rot, y)
    s.collider((x, y + 5.0, z), (1.6, 10.0, 1.6), 0, True, None)
    if snow:
        s.emitter("branchsnow", (x, y + 10.0, z), 0, (9.0, 1.0, 9.0))


def lamp(s, x, z, y=0.0):
    place(s, "CampusLamp", x, z, 0, y)
    s.collider((x, y + 5.0, z), (0.8, 10.0, 0.8), 0, True, None)


# The avenue and the gate --------------------------------------------------------------------------------


def avenue(s):
    rng = random.Random(17)
    skip = {(P.GINKGO_X[0], 8.0), (P.GINKGO_X[1], 22.0), (P.GINKGO_X[1], 92.0)}
    for k, z in enumerate(P.GINKGO_Z):
        for x in P.GINKGO_X:
            if (x, z) in skip:
                continue
            ginkgo(s, x, z, rng.uniform(0, 360), snow=(k % 3 == 1))
    for x, z in ((-33.6, -13.0), (-6.4, 1.0), (-33.6, 15.0), (-6.4, 29.0), (-33.6, 43.0), (-6.4, 57.0),
                 (-33.6, 71.0), (-6.4, 85.0), (-33.6, 99.0)):
        lamp(s, x, z)
    s.prop("Bench", -35.4, 26.0, -90)
    # The hot-drinks machine and the recycling by the avenue.
    s.prop("VendingBlue", -5.2, 46.6, 90)  # its front to the avenue
    s.prop("RecycleBins", -5.8, 53.5, 90)
    s.station("Phone", "Avenue Phone Box", -6.0, 40.0, 90, prop="StationPhoneBooth", spare=True)


def tents(s):
    """The check-in tents east of the avenue, facing it, their heaters on."""
    for x, z in ((6.0, 71.0), (20.0, 71.0)):
        s.prop("EventTent", x, z, 90)
        for dx in (-5.0, 5.0):
            for dz in (-5.0, 5.0):
                s.collider((x + dx, 4.0, z + dz), (0.3, 8.0, 0.3), 0, True, None)
        s.collider((x + 1.4, 1.35, z), (2.4, 2.7, 6.0), 0, True, "WhiteTrim")
        s.prop("KeroseneHeater", x - 2.0, z + 3.2, 0)
        s.prop("Chair", x + 3.6, z - 1.5, -90)
    s.prop("QueuePosts", -1.8, 71.0, 90)
    s.prop("ExamSignStand", 13.0, 62.4, 0)
    s.sign((13.0, 4.8, 62.1), 0, 2.0, 4.2, "受\n付", "GothamBlack", (20, 20, 22), None)
    s.sound("mapHeaterHum", (13.0, 3.0, 71.0), 22.0, 0.3)
    fit.plaque(s, 13.0, 9.2, 76.4, 0, 8.0, 1.0, "受験生受付  CANDIDATES' CHECK-IN", (250, 240, 220), (40, 50, 96))


def gate(s):
    masonry.red_gate(s, P.GATE[0], P.GATE[2], (P.GATE[1] + P.GATE[3]) / 2, depth=P.GATE[3] - P.GATE[1], h=12.0)
    # The cordon across the gate: the case closes the campus tonight.
    rng = random.Random(5)
    a, b = (P.GATE[0] + 1.6, P.Z1 - 0.8), (P.GATE[2] - 1.6, P.Z1 - 0.8)
    length = math.dist(a, b)
    count = max(1, round(length / 8.0))
    step = length / count
    for k in range(count):
        cx = a[0] + step * (k + 0.5)
        s.prop("SiteFence", cx, a[1], 180, step / 8.0)
        s.collider((cx, 5.0, a[1]), (step + 0.2, 10.0, 0.6), 0, True, None)
        s.collider((cx, 30.0, a[1]), (step + 0.2, 40.0, 0.6), 0, False, None)
        s.prop("PoliceTape", cx, a[1] - 0.5, 180, 1.0, 3.6 + 0.2 * (k % 2))
    for k in range(4):
        x = a[0] + length * (k + 0.5) / 4
        if k % 2 == 0:
            s.prop("Barricade", x, a[1] - 3.2, 180 + rng.uniform(-8, 8))
        else:
            s.prop("TrafficCone", x + rng.uniform(-1, 1), a[1] - 3.0, rng.uniform(0, 90))
    for x, text in ((-35.8, "入\n学\n試\n験\n会\n場"), (-12.4, "影\nヶ\n丘\n大\n学")):
        s.prop("ExamSignStand", x, 101.0, 180)
        s.sign((x, 4.9, 101.3), 180, 1.8, 4.6, text, "GothamBlack", (20, 20, 22), None)
    s.prop("PostBox", -36.4, 95.0, 90)
    lamp(s, -36.5, 90.0)


def booth(s):
    r = P.BOOTH
    masonry.booth(s, r, P.DOORS["booth"][0])
    x0, z0, x1, z1 = P.inner(r)
    fit.floor_faces(s, P.box(x0, z0, x1, z1), 0.0, "ConcreteDark")
    fit.ceiling_faces(s, P.box(x0, z0, x1, z1), 9.4, "Ceiling")
    s.collider(((x0 + x1) / 2, 9.9, (z0 + z1) / 2), (x1 - x0, 1.0, z1 - z0), 0, True, None)
    s.zone("interior", P.box(x0, z0, x1, z1), 0.0, name="the guard booth")
    s.look_zone("UniversityCampus_Inside", (x0, 0.0, z0), (x1, 9.4, z1))
    s.station("Camera", "Gate CCTV", x1 - 2.3, 100.0, 90, prop="StationCRTBank")
    s.prop("KeroseneHeater", x0 + 1.4, z1 - 1.4, 0)
    s.prop("CoatStand", x0 + 1.2, z0 + 1.2, 0)
    fit.panel(s, (x0 + x1) / 2, (z0 + z1) / 2, 9.4, w=3.0, color=fit.COOL, brightness=0.8, range_=14)
    s.tip_box(8.0, r[1] - 1.4, 0)
    fit.plaque(s, 8.0, 8.4, r[1] - 0.05, 0, 4.0, 0.8, "守衛所  GUARD")
    fit.wall_lamp(s, r[0] - 0.3, 7.6, 97.0, 90, color=fit.WARM, range_=18, brightness=1.0)


# The forecourt ------------------------------------------------------------------------------------------------


def forecourt(s):
    # The evidence board in its kiosk, between the boards of seat charts.
    bx, bz = -49.0, -44.0
    for dx in (-6.9, 6.9):
        s.box("Wood", (bx + dx, 4.75, bz - 0.3), (0.5, 9.5, 0.5), collide=True)
    masonry.gable_roof(s, (bx - 7.4, bz - 1.4, bx + 7.4, bz + 0.6), 9.5, 0.9, gable="Wood", overhang=0.5, along_x=True)
    s.board(bx, 5.4, bz, 180, 12.0, 7.0)
    fit.downlight(s, bx, bz - 0.3, 9.4, range_=14, brightness=1.0, angle=70)
    for x, text in ((-61.5, "座席表 A\n10001 - 10120"), (-36.5, "座席表 B\n10121 - 10240")):
        s.prop("NoticeBoard", x, bz - 0.4, 180)
        s.sign((x, 4.3, bz - 0.1), 180, 4.6, 2.6, text, "GothamBold", (30, 30, 34), (236, 232, 222))
    s.prop("BustStatue", -58.0, -56.0, 150)
    for x in (0.0, 16.0):
        s.prop("Bench", x, -39.4, 0)
    for x, z in ((-40.0, -60.0), (0.0, -60.0), (22.0, -44.0), (-62.0, -52.0), (-24.0, -34.0), (6.0, -33.0)):
        lamp(s, x, z)
    s.prop("SnowTools", -33.0, -60.4, 180)
    s.prop("Snowman", 20.0, -58.0, 200)
    for x in (-50.0, 10.0):
        s.prop("ShrubSnow", x, -60.8, 0)


# The pond hollow -------------------------------------------------------------------------------------------------


def hollow(s):
    for x, z, snow in ((-141.0, -30.0, True), (-126.0, 36.0, False), (-72.0, -28.0, True), (-62.0, 36.0, False),
                       (-143.0, 24.0, False), (-90.0, -31.0, False)):
        pine(s, x, z, (x * 7 + z * 3) % 360, HY, snow)
    for x, z in ((-132.0, -16.0), (-112.0, -15.0), (-80.0, -15.0), (-128.0, 20.0), (-86.0, 19.0)):
        s.prop("StoneLantern", x, z, 0, 1.0, HY)
    for x, z in ((-146.0, -12.0), (-146.0, 6.0), (-112.0, 40.0), (-78.0, 40.5), (-56.0, -20.0), (-56.0, -6.0),
                 (-100.0, -34.5), (-132.0, -34.5)):
        s.prop("ShrubSnow", x, z, (x + z) % 180, 1.0, HY)
    s.station("Camera", "Pond Camera Post", -60.0, 24.0, 90, y=HY, prop="StationCameraPost")
    s.drop_point("under the pond bridge", -99.4, -20.4, y=HY + 0.15)
    s.hood(-138.0, -24.0, y=HY + 0.6)
    s.prop("Snowman", -110.0, -24.0, 30, 1.0, HY)
    for x, z in ((-70.0, 12.5), (-126.0, -26.0), (-96.0, 34.0), (-140.0, 30.0), (-100.0, -27.0), (-80.0, -27.0)):
        lamp(s, x, z, HY)
    for x in (-124.0, -90.0):
        s.emitter("rivermist", (x, HY + 0.4, 2.0), 0)
    s.sound("mapWindSnow", (-100.0, 4.0, 0.0), 70.0, 0.35)


# The tennis court, the sheds ------------------------------------------------------------------------------------


def chain_link(s, a, b, h, pitch=1.6, wire=0.06):
    """A chain-link fence's diamond mesh from a to b, h high: two sets of diagonal wires, `pitch`
    apart along the ground."""
    length = math.dist(a, b)
    t = ((b[0] - a[0]) / length, 0.0, (b[1] - a[1]) / length)
    out = (-t[2], 0.0, t[0])

    def world(u, y):
        return (a[0] + t[0] * u, y, a[1] + t[2] * u)

    for sign in (1, -1):
        c = -h if sign == 1 else 0.0
        end = length if sign == 1 else length + h
        while c <= end:
            # sign 1: the wire u - y = c; sign -1: u + y = c.
            y0, y1 = (max(0.0, -c), min(h, length - c)) if sign == 1 else (max(0.0, c - length), min(h, c))
            if y1 - y0 > 0.1:
                p0 = world(c + y0 if sign == 1 else c - y0, y0)
                p1 = world(c + y1 if sign == 1 else c - y1, y1)
                ux = norm((p1[0] - p0[0], p1[1] - p0[1], p1[2] - p0[2]))
                centre = ((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2, (p0[2] + p1[2]) / 2)
                s.obox("ChainLink", centre, (math.dist(p0, p1), wire, wire), ux, out, norm(cross(ux, out)),
                       skip=("+x", "-x"))
            c += pitch


def court(s):
    x0, z0, x1, z1 = P.COURT
    corners = [(x0, z0), (x1, z0), (x1, z1), (x0, z1)]
    h = 10.0
    for i in range(4):
        a, b = corners[i], corners[(i + 1) % 4]
        length = math.dist(a, b)
        d = ((b[0] - a[0]) / length, (b[1] - a[1]) / length)
        rot = g2.rot_of(d)
        mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
        chain_link(s, a, b, h - 0.2)
        for yy in (0.2, h / 2, h - 0.1):
            s.box("DarkMetal", (mid[0], yy, mid[1]), (length, 0.14, 0.14), rot)
        count = max(1, round(length / 6.0))
        for k in range(count + 1):
            px, pz = a[0] + d[0] * length * k / count, a[1] + d[1] * length * k / count
            s.box("DarkMetal", (px, h / 2, pz), (0.22, h, 0.22), rot)
        s.box("Snow", (mid[0], h + 0.08, mid[1]), (length, 0.14, 0.26), rot)
        s.collider((mid[0], h / 2, mid[1]), (length, h, 0.5), rot, False, None)
        s.collider((mid[0], h + 10.0, mid[1]), (length, 20.0, 0.5), rot, False, None)
    cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
    s.prop("TennisNet", cx, cz, 90)
    s.prop("UmpireChair", cx, z1 - 3.0, 180)
    # The court's white lines, mostly under the snow.
    for zz in (cz - 18.0, cz + 18.0):
        s.box("WhiteTrim", (cx - 12.0, 0.06, zz), (22.0, 0.06, 0.3), skip=("-y",))
    for xx in (cx - 36.0, cx + 36.0):
        s.box("WhiteTrim", (xx, 0.06, cz + 6.0), (0.3, 0.06, 16.0), skip=("-y",))
    lamp(s, x0 - 3.0, cz - 10.0)
    lamp(s, x1 + 5.4, cz - 12.0)
    # The roller shed outside the fence's west side, a spare drop point behind it.
    rx, rz = 62.0, 8.0
    s.box("Shutter", (rx, 2.6, rz), (4.0, 5.2, 8.0), collide=True, mats={"+y": "Slate"})
    s.box("Snow", (rx, 5.28, rz), (4.2, 0.16, 8.2), skip=("-y",))
    s.drop_point("behind the tennis court's roller shed", rx - 3.4, rz, spare=True)


def bike_shed(s):
    x0, z0, x1, z1 = P.BIKE_SHED
    for x in (x0 + 0.4, (x0 + x1) / 2, x1 - 0.4):
        for z in (z0 + 0.4, z1 - 0.4):
            s.box("DarkMetal", (x, 4.0, z), (0.3, 8.0, 0.3), collide=True)
    s.box("DarkMetal", ((x0 + x1) / 2, 8.2, (z0 + z1) / 2), (x1 - x0 + 1.0, 0.3, z1 - z0 + 1.2))
    s.box("Snow", ((x0 + x1) / 2, 8.45, (z0 + z1) / 2), (x1 - x0 + 0.8, 0.2, z1 - z0 + 1.0), skip=("-y",))
    s.collider(((x0 + x1) / 2, 8.2, (z0 + z1) / 2), (x1 - x0, 0.6, z1 - z0), 0, True, None)
    s.prop("BikeRack", (x0 + x1) / 2 + 3.0, z0 + 3.0, 0)
    for k, x in enumerate((x0 + 13.0, x0 + 15.0, x0 + 17.0)):
        s.prop("Bicycle", x, z0 + 3.4, 180 * (k % 2))
    s.drop_point("the bike shed", x0 + 2.0, (z0 + z1) / 2, spare=True)
    s.light("point", ((x0 + x1) / 2, 7.4, (z0 + z1) / 2), (220, 230, 255), 16, 0.8)
    s.box("NeonCool", ((x0 + x1) / 2, 7.95, (z0 + z1) / 2), (3.0, 0.1, 0.4))


# Lamps along the other paths, the lawns' dressing -----------------------------------------------------------


def lawns(s):
    for x, z in (
            # West and east side paths (10 and 14 wide), the library's path (12), the east path (8, along the wall).
            (-68.5, -104.0), (-68.5, -72.0), (37.5, -104.0), (37.5, -72.0), (40.0, -30.5), (90.0, -30.5),
            (132.0, -30.5), (147.4, 4.0),
            # The east cross path (12): along its north edge.
            (22.0, 24.5), (60.0, 24.5), (100.0, 24.5), (136.0, 24.5),
            # The south path (14): along the hollow's rim; the north-rim path (12): along the rim too.
            (-140.0, 47.0), (-110.0, 47.0), (-80.0, 47.0), (-50.0, 47.0), (-130.0, -41.0), (-100.0, -41.0),
            (-76.0, -41.0),
            # The science path (12), the gate plaza, the alley (8, against the cafeteria wall), the open lawns.
            (38.5, 64.0), (30.0, 96.0), (-82.4, 64.0), (16.0, 10.0), (32.0, -14.0), (34.0, 104.0)):
        lamp(s, x, z)
    for x, z, rot in ((30.0, 10.0, 20), (-44.0, 30.0, 300)):
        s.prop("Snowman", x, z, rot)
    for x, z, rot in ((-84.6, 57.0, 0), (54.0, 34.6, 180), (-60.0, 56.6, 0)):
        s.prop("SnowTools", x, z, rot)
    for x, z in ((34.0, -44.0), (-60.0, -34.5), (-12.0, -34.5), (44.0, 32.0)):
        s.prop("ShrubSnow", x, z, (x * 3) % 180)
    for x, z in ((30.0, 48.0), (-60.0, 20.0)):
        s.box("BlackMetal", (x, 0.08, z), (2.4, 0.16, 2.4), skip=("-y",))
        for k in range(5):
            s.box("DarkMetal", (x - 1.0 + k * 0.5, 0.17, z), (0.12, 0.04, 2.2))
        s.emitter("steam", (x, 0.2, z))
    for x, z in ((-20.0, 20.0), (50.0, -8.0), (-20.0, 96.0)):
        s.sound("mapWindSnow", (x, 6.0, z), 60.0, 0.3)
    s.sound("mapTowerBell", (-20.0, P.CLOCK_Y, -55.0), 600.0, 0.9, loop=False)


def build(s):
    avenue(s)
    tents(s)
    gate(s)
    booth(s)
    forecourt(s)
    hollow(s)
    court(s)
    bike_shed(s)
    lawns(s)
