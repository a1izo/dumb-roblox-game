"""39F, the Agency's own floor (the lifts do not stop here): the operations deck round the atrium
facing the video wall, the director's glass office in the cut corner, and along the glass the
forensics lab, the evidence lock-up, the server room, the archive, the canteen, the analysts'
office and the training room.

As on 38F, every station keeps a clear square in front of it and its screen in view; sheets rest on
tables built with the scene."""

from maps import city, kit
from maps import geo2d as g2
from maps.venues.agency import fit
from maps.venues.agency import plan as P
from maps.venues.agency.lower import COLUMNS

Y = P.L2
C = P.CEIL2


# Everything placed from here stands on 39F's floor unless told otherwise.
def prop(s, key, x, z, rot=0.0, scale=1.0, y=None):
    s.prop(key, x, z, rot, scale, Y if y is None else y)


def station(s, *args, **kw):
    kw.setdefault("y", Y)
    s.station(*args, **kw)


def drop_point(s, name, x, z, **kw):
    kw.setdefault("y", Y + 0.15)
    s.drop_point(name, x, z, **kw)


def hood(s, x, z, **kw):
    kw.setdefault("y", Y + 0.6)
    s.hood(x, z, **kw)


def floors(s):
    rooms = P.ROOMS_L2
    looks = {"forensics": "TileWhite", "lockup": "ConcreteDark", "server": "MetalFloor", "archive": "CarpetGrey",
             "canteen": "WoodFloor", "training": "CarpetGrey", "director": "WoodFloorDark"}
    for name, poly in rooms.items():
        fit.floor_faces(s, poly, Y, looks[name])
    fit.floor_faces(s, P.ANALYSTS, Y, "CarpetNavy")
    fit.floor_faces(s, P.OPS, Y, "CarpetNavy", holes=[P.rect_of(P.VOID)])
    taken = [P.rect_of(P.CORE), P.ANALYSTS, P.OPS, P.rect_of(P.VOID)] + list(rooms.values())
    holes = [g2.ccw(q) for t in taken for q in g2.convex_pieces(t)]
    for piece in g2.subtract_all([g2.ccw(q) for q in g2.convex_pieces(P.PLATE)], holes):
        if abs(g2.area(piece)) > 0.5:
            city.up_face(s, "CarpetGrey", piece, Y)
    for piece in g2.subtract_all([g2.ccw(q) for q in g2.convex_pieces(P.PLATE)], [g2.ccw(P.rect_of(P.VOID))]):
        s.zone("interior", piece, Y, name="39F")
    for x, z in COLUMNS:
        kit.column_square(s, x, z, C - Y, 2.4, "PlasterLight", trim="BlackTrim", base=Y)
    kit.column_square(s, 75.0, -12.0, C - Y, 2.4, "PlasterLight", trim="BlackTrim", base=Y)


# The north rooms -------------------------------------------------------------------------------------------


def forensics(s):
    fit.partition(s, (-100.0, -48.0), (-50.0, -48.0), Y, C, "PlasterLight", "PlasterGrey",
                  doors=[(12.0, 5.0), (40.0, 5.0)], glass="clear")
    fit.partition(s, (-50.0, -75.0), (-50.0, -48.0), Y, C, "ConcreteDark", "PlasterLight")
    station(s, "Fingerprint", "Print Analyzer", -86.0, -70.8, 180, prop="StationPrintKit")
    station(s, "Forensics", "Ink Analysis Bench", -66.0, -70.8, 180, prop="StationLabBench")
    for z in (-70.0, -62.0):
        prop(s, "FumeHood", -97.4, z, -90)
    # An island bench in the middle with its microscopes and sample racks.
    top = fit.counter(s, -76.0, -58.5, 0, 12.0, d=3.0, y=Y, top="BlackTrim", body="WhiteTrim")
    for x in (-80.0, -72.0):
        s.box("WhiteTrim", (x, top + 0.1, -58.5), (0.9, 0.2, 1.2))
        s.box("WhiteTrim", (x, top + 0.8, -58.1), (0.3, 1.4, 0.3))
        s.cylinder("BlackMetal", (x, top + 1.5, -58.4), 0.1, 0.5, 8)
    for k in range(6):
        s.cylinder("Glass", (-77.0 + k * 0.4, top, -59.4), 0.14, 0.7, 8)
    s.box("NeonGreen", (-75.4, top + 0.35, -59.4), (0.9, 0.05, 0.2))
    # The crime scene they are rebuilding: tape round a square, a chalk outline, evidence markers.
    cx, cz = -58.0, -56.0
    for (ax, az), (bx, bz) in (((cx - 4, cz - 3), (cx + 4, cz - 3)), ((cx + 4, cz - 3), (cx + 4, cz + 3)),
                               ((cx + 4, cz + 3), (cx - 4, cz + 3))):
        length = abs(bx - ax) + abs(bz - az)
        prop(s, "PoliceTape", (ax + bx) / 2, (az + bz) / 2, fit.facing(bz - az, -(bx - ax)), length / 8.45, Y + 3.0)
    for (px, pz) in ((cx - 4, cz - 3), (cx + 4, cz - 3), (cx + 4, cz + 3), (cx - 4, cz + 3)):
        s.box("Steel", (px, Y + 1.6, pz), (0.2, 3.2, 0.2), collide=True)
    for x0, z0, x1, z1 in ((-60.0, -57.0, -57.0, -57.0), (-57.0, -57.0, -56.0, -55.2), (-60.0, -57.0, -61.0, -55.0),
                           (-60.0, -57.5, -59.0, -58.6)):
        s.tube("WhiteTrim", (x0, Y + 0.03, z0), (x1, Y + 0.03, z1), 0.06, 4)
    for k, (px, pz) in enumerate(((-56.5, -54.5), (-59.5, -54.0), (-61.0, -57.8))):
        s.box("PaintYellow", (px, Y + 0.2, pz), (0.4, 0.4, 0.3))
    prop(s, "Mannequin", -58.5, -55.4, -60)
    s.box("Steel", (-52.2, Y + 3.6, -72.0), (2.6, 7.2, 3.0), collide=True)  # the evidence fridge
    s.box("BlackTrim", (-53.52, Y + 4.6, -72.0), (0.05, 0.1, 2.0))
    s.box("BlackMetal", (-50.35, Y + 8.0, -61.0), (0.1, 3.6, 6.0))  # the X-ray light box on the east wall
    s.box("NeonCool", (-50.42, Y + 8.0, -61.0), (0.04, 3.2, 5.6))
    for x, z in ((-86.0, -64.0), (-66.0, -64.0), (-76.0, -54.0)):
        fit.panel(s, x, z, C, color=fit.COOL, brightness=0.9, range_=20, flicker=True)
    fit.plaque(s, -88.0, Y + 10.6, -47.7, 0, 6.0, 0.9, "鑑識課 FORENSICS")


def lockup(s):
    fit.partition(s, (-50.0, -48.0), (-16.0, -48.0), Y, C, "ConcreteDark", "PlasterGrey", doors=[(17.0, 4.4)])
    fit.partition(s, (-16.0, -75.0), (-16.0, -48.0), Y, C, "PlasterGrey", "ConcreteDark")
    for x in (-44.0, -35.0, -26.0):
        prop(s, "EvidenceCage", x, -71.9, 180)
    for z in (-62.0,):
        prop(s, "EvidenceCage", -47.5, z, -90)
    top = fit.counter(s, -24.0, -52.5, 180, 7.0, d=2.2, y=Y, top="Wood", body="DarkMetal")
    prop(s, "DeskPhone", -26.0, -52.5, 180, 1.0, top)
    s.box("Paper", (-22.0, top + 0.03, -52.5), (1.0, 0.05, 1.3))
    station(s, "Fingerprint", "Evidence Print Kit", -20.0, -62.5, 90, prop="StationPrintKit", spare=True)
    hood(s, -47.0, -51.5)
    for x in (-40.0, -26.0):
        kit.tube_light(s, x, C, -62.0, length=7.0, rot=90, range_=18, brightness=0.75)
    fit.plaque(s, -33.0, Y + 10.6, -47.7, 0, 6.0, 0.9, "証拠品保管庫 EVIDENCE")


def server_room(s):
    fit.partition(s, (-16.0, -48.0), (30.0, -48.0), Y, C, "PlasterGrey", "PlasterGrey", doors=[(9.0, 4.4)],
                  glass="clear", spans=[(12.0, 45.4)])
    fit.partition(s, (30.0, -75.0), (30.0, -48.0), Y, C, "PlasterGrey", "PlasterGrey")
    for row_z, rot in ((-71.5, 180), (-63.5, 0), (-60.2, 180)):
        for k in range(8):
            prop(s, "ServerRack", 3.0 + k * 3.1, row_z, rot)
    # Cable trays over the rows, blue light from the racks.
    for z in (-71.5, -61.8):
        s.box("DarkMetal", (13.8, C - 2.2, z), (26.0, 0.2, 1.4))
        for x in (2.0, 13.8, 25.6):
            s.tube("DarkMetal", (x, C - 2.2, z), (x, C, z), 0.05, 5)
    for x in (6.0, 20.0):
        s.light("point", (x, Y + 6.0, -67.5), (100, 150, 255), 16, 0.6)
    station(s, "Phone", "Records Terminal", -9.0, -58.0, -90, prop="StationPhoneDesk")
    drop_point(s, "the server rack alcove", 28.4, -73.2)
    fit.panel(s, -9.0, -62.0, C, color=fit.COOL, brightness=0.8, range_=18, flicker=True)  # the server room
    fit.panel(s, 14.0, -54.0, C, color=fit.COOL, brightness=0.5, range_=16)
    s.sound("mapServerHum", (14.0, Y + 6.0, -66.0), 34.0, 0.3)
    fit.plaque(s, -7.0, Y + 10.6, -47.7, 0, 6.0, 0.9, "サーバー室 SERVERS")


def archive(s):
    fit.partition(s, (30.0, -48.0), (100.0, -48.0), Y, C, "PlasterGrey", "PlasterLight", doors=[(10.0, 4.4), (50.0, 4.4)],
                  glass="frosted", spans=[(13.0, 47.2)])
    # Rolling shelving in columns north to south, aisles between them.
    for x in (54.0, 61.0, 68.0, 75.0, 82.0, 89.0):
        for z in (-69.2, -60.4):
            prop(s, "ArchiveShelving", x, z, 90)
    # The examiner's corner at the west end: the station, microfilm readers, a reading table.
    station(s, "Forensics", "Document Examiner", 37.0, -70.8, 180, prop="StationLabBench")
    for z in (-62.0, -58.0):
        prop(s, "MicrofilmReader", 31.7, z, -90)
    top = fit.table(s, 42.0, -55.0, 6.0, 3.0, 0, Y)
    fit.chairs_round(s, 42.0, -55.0, 6.0, 3.0, 0, Y)
    s.sheet(42.0, top, -55.0)
    drop_point(s, "the archive's back corner", 97.2, -72.8)
    for x, z in ((37.0, -64.0), (44.0, -54.0)):
        fit.panel(s, x, z, C, brightness=0.8, range_=18)
    for x in (57.5, 71.5, 85.5):
        fit.panel(s, x, -64.8, C, w=3.0, brightness=0.55, range_=16, rot=90)
    fit.plaque(s, 40.0, Y + 10.6, -47.7, 0, 5.0, 0.9, "資料室 ARCHIVE")


# The east, the director ------------------------------------------------------------------------------------


def canteen(s):
    fit.partition(s, (50.0, -48.0), (50.0, 16.0), Y, C, "PlasterLight", "PlasterGrey", doors=[(18.0, 5.0), (54.0, 5.0)],
                  glass="clear")
    fit.partition(s, (50.0, 16.0), (100.0, 16.0), Y, C, "PlasterLight", "PlasterGrey", doors=[(5.0, 4.4)],
                  glass="frosted", spans=[(10.4, 49.4)])
    prop(s, "MealTicketMachine", 53.2, -45.6, 180)
    top = fit.counter(s, 72.0, -45.8, 180, 14.0, d=2.4, y=Y, top="WhiteTrim", body="WoodPanel")
    prop(s, "CoffeeMachine", 68.0, -45.9, 180, 1.0, top)
    prop(s, "DrinkFridge", 88.0, -46.4, 180)
    prop(s, "VendingWhite", 97.3, -40.0, 90)  # front to the room, back to the glass
    for x, z in ((62.0, -34.0), (62.0, -20.0), (84.0, -27.0), (62.0, -6.0), (84.0, -13.0), (84.0, 1.0)):
        fit.table(s, x, z, 5.0, 3.0, 0, Y)
        fit.chairs_round(s, x, z, 5.0, 3.0, 0, Y)
    s.sheet(62.0, Y + 2.8, -20.0, spare=True)
    # A bar along the east glass with stools.
    top = fit.counter(s, 97.8, -14.0, 90, 30.0, d=1.6, h=3.5, y=Y, top="Wood", body="BlackTrim")
    for k in range(8):
        prop(s, "BarStool", 95.6, -27.0 + k * 3.7, -90, 1.0, Y)
    prop(s, "WaterCooler", 53.0, 12.4, 0)
    hood(s, 96.5, 12.5, spare=True)
    for x, z in ((62.0, -27.0), (84.0, -20.0), (62.0, 0.0)):
        fit.panel(s, x, z, C, brightness=0.85, range_=20)
    fit.panel(s, 88.0, -34.0, C, on=False)
    fit.panel(s, 88.0, 4.0, C, on=False)
    fit.plaque(s, 49.7, Y + 10.6, -40.0, 90, 5.0, 0.9, "食堂 CANTEEN")


def director(s):
    fit.partition(s, (60.0, 16.0), (60.0, 75.0), Y, C, "WoodPanel", "PlasterGrey", doors=[(14.0, 4.4)], glass="frosted",
                  spans=[(18.0, 52.0)])
    prop(s, "ExecutiveDesk", 80.0, 34.0, 0)
    s.light("point", (82.3, Y + 4.2, 33.7), fit.LAMP, 14, 0.9)
    prop(s, "OfficeChair", 80.0, 37.3, 0)
    for x in (77.5, 82.5):
        prop(s, "Chair", x, 29.4, 180)
    for k in range(10):
        prop(s, "Bookshelf", 63.0 + k * 3.3, 17.3, 180)
    top = fit.table(s, 66.0, 62.0, 4.0, 2.6, 45, Y, top="WoodPanel")
    s.sheet(66.0, top, 62.0)
    prop(s, "Sofa", 70.0, 52.0, -135)
    prop(s, "Plant", 61.9, 68.5, 0)
    prop(s, "Plant", 97.0, 19.5, 0)
    prop(s, "CoatStand", 62.8, 21.5, 0)
    kit.picture(s, 60.35, Y + 7.6, 23.0, -90, 4.0, 3.0, "Wood", "Paper")
    for x, z in ((80.0, 30.0), (72.0, 56.0)):
        fit.downlight(s, x, z, C, range_=16, brightness=0.8)
    drop_point(s, "under the director's window", 90.0, 40.0, spare=True)
    fit.plaque(s, 59.7, Y + 10.6, 27.0, 90, 5.0, 0.9, "局長室 DIRECTOR")


# The west ------------------------------------------------------------------------------------------------------


def analysts(s):
    fit.partition(s, (-16.0, -6.0), (-16.0, 40.0), Y, C, "PlasterGrey", "PlasterGrey", doors=[(12.0, 5.0), (36.0, 5.0)],
                  glass="clear")
    rows = [(-90.0, -36.0), (-58.0, -36.0), (-30.0, -36.0), (-90.0, -14.0), (-58.0, -18.0), (-30.0, -18.0),
            (-90.0, 12.0), (-58.0, 18.0), (-30.0, 20.0)]
    for i, (x, z) in enumerate(rows):
        fit.desk_pair(s, x, z, 90, Y, (i % 3 == 0, i % 2 == 1))
    for x, z in ((-90.0, -25.0), (-58.0, -27.0), (-90.0, 1.0), (-58.0, 8.0)):
        fit.screen_divider(s, x, z, 0, 9.0, Y)
    # The map table in the middle, whiteboards, files, the ringing phone nobody answers.
    top = fit.table(s, -72.0, 20.0, 6.0, 4.0, 0, Y, top="Paper")
    for k, (dx, dz) in enumerate(((-1.6, -0.8), (0.9, 0.4), (1.8, -1.2), (-0.4, 1.1))):
        s.box("NeonRed", (-72.0 + dx, top + 0.04, 20.0 + dz), (0.3, 0.06, 0.3))
    prop(s, "Whiteboard", -44.0, 12.5, 180)
    prop(s, "Whiteboard", -86.0, 30.0, 0)
    for z in (-44.4, -41.9):
        prop(s, "FilingCabinet", -97.9, z, -90)
    for x, z in ((-96.8, 36.5), (-19.0, -4.0)):
        prop(s, "Plant", x, z, 30)
    prop(s, "CoatStand", -20.0, 36.0, 0)
    hood(s, -97.0, 25.0)
    for x, z in ((-72.0, 20.0), (-58.0, -28.0), (-30.0, 0.0)):
        fit.panel(s, x, z, C, brightness=0.8, range_=20)
    fit.panel(s, -86.0, 8.0, C, brightness=0.6, range_=18)
    for x, z in ((-86.0, -26.0), (-44.0, -8.0), (-30.0, 30.0)):
        fit.panel(s, x, z, C, on=False)
    s.sound("mapOfficeHum", (-58.0, Y + 8.0, 0.0), 60.0, 0.18)
    s.sound("mapPhoneRing", (-86.0, Y + 4.0, -12.0), 26.0, 0.1)
    s.sound("mapRainGlass", (-96.0, Y + 6.0, 0.0), 60.0, 0.22)


def training(s):
    fit.partition(s, (-100.0, 40.0), (-16.0, 40.0), Y, C, "PlasterGrey", "PlasterGrey", doors=[(16.0, 5.0), (70.0, 5.0)],
                  glass="clear")
    fit.partition(s, (-16.0, 40.0), (-16.0, 75.0), Y, C, "PlasterGrey", "PlasterGrey", doors=[(20.0, 5.0)], glass="blinds",
                  spans=[(0.6, 3.6), (23.3, 34.4)])
    # Rows of chairs facing the pull-down screen hung in front of the west glass.
    for x in (-84.0, -78.0, -72.0, -66.0):
        for z in (48.0, 52.0, 56.0, 62.0, 66.0):
            prop(s, "Chair", x, z, 90)
    s.box("DarkMetal", (-97.6, Y + 11.8, 57.0), (0.8, 0.5, 18.0))
    s.box("Paper", (-97.6, Y + 7.8, 57.0), (0.06, 7.6, 16.0))
    s.screen((-97.5, Y + 7.8, 57.0), -90, 15.4, 7.0, "map")
    s.box("BlackMetal", (-91.5, Y + 2.2, 44.5), (1.6, 4.4, 1.2), collide=True)  # the lectern
    top = fit.table(s, -58.0, 57.0, 3.0, 4.0, 0, Y)
    s.box("BlackMetal", (-58.0, top + 0.3, 57.0), (1.2, 0.6, 1.4))  # the projector
    prop(s, "Whiteboard", -40.0, 70.0, 180)
    hood(s, -30.0, 72.5, spare=True)
    for x in (-84.0, -66.0):
        fit.panel(s, x, 57.0, C, brightness=0.55, range_=18)
    fit.panel(s, -36.0, 57.0, C, on=False)
    fit.plaque(s, -30.0, Y + 10.6, 40.3, 180, 5.0, 0.9, "研修室 TRAINING")


# The operations deck -----------------------------------------------------------------------------------------


def ops(s):
    x0, z0, x1, z1 = P.VOID
    station(s, "Camera", "Street Feed", 17.0, 39.0, 180, prop="StationCCTV")
    station(s, "Camera", "Satellite Feed", 44.0, 46.0, 90, prop="StationCCTV", spare=True)
    # Command desks facing the video wall across the atrium.
    for x in (0.0, 8.0, 26.0, 34.0):
        fit.desk(s, x, 40.0, 180, Y, lamp=x in (0.0, 34.0))
    for x in (4.0, 12.0, 22.0, 30.0):
        fit.desk(s, x, 50.0, 180, Y, lamp=x in (12.0, 22.0))
    # The big map table behind them, the case on it.
    top = fit.table(s, 17.0, 62.0, 10.0, 6.0, 0, Y, top="Paper")
    fit.chairs_round(s, 17.0, 62.0, 10.0, 6.0, 0, Y)
    s.sheet(15.0, top, 62.0)
    for dx, dz in ((-3.0, -1.5), (1.0, 0.8), (3.5, -0.6), (-1.2, 2.0)):
        s.box("NeonRed", (17.0 + dx, top + 0.04, 62.0 + dz), (0.3, 0.06, 0.3))
    s.tube("RedTrim", (14.0, top + 0.05, 60.5), (18.0, top + 0.05, 62.8), 0.03, 4)
    # Pin boards on the training room's wall, plants, the balconies' ends.
    for z in (48.0, 56.0):
        prop(s, "PinBoard", -15.55, z, -90, 1.0, Y + 7.4)
    for x, z in ((-12.0, 72.0), (56.0, 72.0), (46.0, 22.0), (-12.0, 2.0)):
        prop(s, "Plant", x, z, 45)
    prop(s, "WaterCooler", 47.5, 36.0, -90)
    for x, z in ((0.0, 45.0), (17.0, 45.0), (34.0, 45.0), (17.0, 56.0), (44.0, 10.0), (-10.0, 20.0),
                 (-10.0, -1.0), (30.0, -1.0), (8.0, 70.0), (40.0, 68.0)):
        fit.downlight(s, x, z, C, range_=16, brightness=0.8)
    s.sound("mapCityHum", (17.0, Y + 8.0, 70.0), 70.0, 0.12)
    s.sound("mapSirenFar", (40.0, Y + 8.0, 72.0), 90.0, 0.07)
    s.sound("mapRainGlass", (17.0, Y + 6.0, 73.0), 50.0, 0.22)
    fit.plaque(s, P.CORE[2] + 0.5, Y + 10.6, -20.0, -90, 6.0, 0.9, "39F  作戦室 OPERATIONS")


def corridor(s):
    for x in (-12.0, 22.0, 46.0):
        fit.panel(s, x, -44.0, C, w=3.0, brightness=0.7, range_=18, rot=90)
    for z in (-30.0, -14.0):
        fit.panel(s, -12.0, z, C, w=3.0, brightness=0.7, range_=18)
        fit.panel(s, 46.0, z, C, w=3.0, brightness=0.7, range_=18)
    kit.extinguisher(s, P.CORE[2] + 0.5, -24.0, -90)


def build(s, g):
    floors(s)
    forensics(s)
    lockup(s)
    server_room(s)
    archive(s)
    canteen(s)
    director(s)
    analysts(s)
    training(s)
    ops(s)
    corridor(s)
