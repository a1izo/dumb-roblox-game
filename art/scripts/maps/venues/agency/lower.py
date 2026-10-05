"""38F, where the lifts arrive: the lobby under the atrium (the screening line by the lifts, the
reception desk, the speed gates into the bullpen), the lounge along the south glass, the bullpen
(the detectives' open floor) with the sergeant's office, and along the north the security office,
the observation room behind the one-way mirror, two interview rooms, the copy room and the locker
room; in the east the break room and the night desk.

Every station keeps a clear square in front of it and its screen in view of its room; sheets rest
on tables built with the scene. Walls run so their "n" side is north (walls running east) or east
(walls running south)."""

from maps import city, kit
from maps import geo2d as g2
from maps.venues.agency import fit
from maps.venues.agency import plan as P

Y = P.L1
C = P.CEIL1


def floors(s):
    rooms = P.ROOMS_L1
    looks = {"security": "CarpetGrey", "observation": "CarpetGrey", "interview_a": "TileMetroGrey",
             "interview_b": "TileMetroGrey", "copy": "CarpetGrey", "lockers": "TileMetroGrey", "break": "WoodFloor",
             "night": "CarpetNavy", "sergeant": "WoodFloorDark"}
    for name, poly in rooms.items():
        fit.floor_faces(s, poly, Y, looks[name])
    fit.floor_faces(s, P.LOBBY, Y, "MarbleBlack")
    fit.floor_faces(s, P.LOUNGE, Y, "WoodFloorDark")
    fit.floor_faces(s, P.BULLPEN, Y, "CarpetNavy", holes=[rooms["sergeant"]])
    taken = [P.rect_of(P.CORE), P.LOBBY, P.BULLPEN, P.LOUNGE] + list(rooms.values())
    holes = [g2.ccw(q) for t in taken for q in g2.convex_pieces(t)]
    for piece in g2.subtract_all([g2.ccw(q) for q in g2.convex_pieces(P.PLATE)], holes):
        if abs(g2.area(piece)) > 0.5:
            city.up_face(s, "CarpetGrey", piece, Y)
    s.zone("interior", P.PLATE, Y, name="38F")


# The north rooms -----------------------------------------------------------------------------------------


def security(s):
    # The south wall onto the bullpen (its blinds shut) with the door; the wall to the observation
    # room with the staff door; a wall of monitors on that wall's west face.
    fit.partition(s, (-100.0, -48.0), (-58.0, -48.0), Y, C, "PlasterGrey", "PlasterGrey", doors=[(14.0, 5.0)],
                  glass="blinds")
    fit.partition(s, (-58.0, -75.0), (-58.0, -48.0), Y, C, "PlasterDark", "PlasterGrey", doors=[(23.0, 4.2)])
    s.station("Camera", "CCTV Wall", -80.0, -71.2, 180, prop="StationCRTBank")
    x = -58.3  # the wall's west face
    s.box("BlackMetal", (x - 0.4, 7.4, -66.5), (0.8, 6.8, 12.8))
    for row in range(2):
        for col in range(4):
            z = -71.4 + col * 3.1
            y = 5.6 + row * 2.9
            s.box("CreamTrim", (x - 1.9, y, z), (2.2, 2.5, 2.9))
            s.box("BlackTrim", (x - 3.02, y, z), (0.05, 2.1, 2.5))
            s.screen((x - 3.1, y, z), 90, 2.3, 1.7, "cctv")
    fit.counter(s, x - 2.4, -66.5, 90, 12.6, d=2.4, h=3.4, top="BlackTrim", body="DarkMetal")
    for z in (-69.5, -63.5):
        s.prop("OfficeChair", x - 5.6, z, -90)
    s.light("point", (x - 5.0, 6.5, -66.5), (110, 160, 255), 18, 0.8)
    # Filing cabinets along the west glass, a weapons locker, the duty sergeant's desk.
    for z in (-72.0, -69.5, -67.0, -64.5):
        s.prop("FilingCabinet", -98.0, z, -90)
    s.box("DarkMetal", (-98.0, 3.6, -56.0), (2.2, 7.2, 5.0), collide=True)
    s.box("BlackTrim", (-96.85, 3.6, -56.0), (0.05, 6.6, 0.1))
    fit.desk(s, -84.0, -57.0, 90, Y)
    s.prop("CoatStand", -62.5, -51.5, 0)
    fit.panel(s, -80.0, -63.0, C, color=fit.COOL, brightness=0.8, range_=20, flicker=True)  # the CCTV wall's tube
    fit.panel(s, -70.0, -56.0, C, on=False)
    fit.panel(s, -92.0, -54.0, C, on=False)
    fit.plaque(s, -86.0, 10.6, -47.7, 0, 5.2, 0.9, "警備室 SECURITY")


def observation(s):
    # The one-way mirror onto interview 1 (dark glass: it stops a flash either way).
    fit.partition(s, (-44.0, -75.0), (-44.0, -48.0), Y, C, "PlasterDark", "PlasterDark", glass="mirror",
                  spans=[(3.0, 14.5)], sill=3.0, head=9.0)
    fit.partition(s, (-58.0, -48.0), (-44.0, -48.0), Y, C, "PlasterDark", "PlasterGrey", doors=[(7.0, 4.4)])
    s.station("Phone", "Wiretap Console", -47.8, -66.0, 90, prop="StationReelToReel")
    s.prop("Chair", -54.5, -71.5, -90)
    top = fit.table(s, -55.8, -55.0, 3.0, 2.2, 90, Y)
    s.prop("CoffeeMachine", -55.8, -55.6, -90, 1.0, top)  # front to the room, back to the wall
    s.box("NeonRed", (-51.0, 10.1, -48.34), (1.2, 0.35, 0.05))  # the red lamp over the door: recording
    s.sign((-51.0, 10.9, -48.36), 0, 3.0, 0.5, "録音中 ON AIR", "GothamBlack", (255, 90, 90), None)
    s.light("point", (-51.0, 9.6, -50.0), (255, 60, 60), 8, 0.5)
    fit.panel(s, -52.0, -62.0, C, w=3.0, color=fit.WARM, brightness=0.55, range_=14)


def interview(s, x0, x1, table):
    """An interview room: the bolted table with its cuffs, two chairs, the lamp over it, a camera
    watching from the corner."""
    tx, tz = table
    s.prop("InterrogationTable", tx, tz, 90)
    s.prop("Handcuffs", tx, tz, 90, 1.0, 2.8)
    s.prop("Chair", tx - 3.3, tz, -90)
    s.prop("Chair", tx + 3.3, tz, 90)
    kit.pendant(s, tx, C, tz, drop=4.6, shade="BlackMetal", color=(255, 226, 180), range_=16, brightness=1.4,
                wide=1.0)
    s.box("BlackMetal", (x1 - 1.2, 11.6, -73.8), (0.8, 0.6, 1.2), 45)
    s.box("NeonRed", (x1 - 1.6, 11.6, -73.4), (0.12, 0.12, 0.05), 45)


def interviews(s):
    fit.partition(s, (-44.0, -58.0), (-8.0, -58.0), Y, C, "PlasterDark", "PlasterGrey", doors=[(9.0, 4.4), (27.0, 4.4)])
    fit.partition(s, (-26.0, -75.0), (-26.0, -58.0), Y, C, "PlasterDark", "PlasterDark")
    fit.partition(s, (-8.0, -75.0), (-8.0, -48.0), Y, C, "PlasterGrey", "PlasterDark")
    interview(s, -44.0, -26.0, (-35.0, -66.5))
    interview(s, -26.0, -8.0, (-19.5, -64.5))
    s.station("Phone", "Interview Recorder", -12.4, -71.4, 180, prop="StationPhoneDesk", spare=True)
    # The hall outside them: a bench, the water cooler, the room plates.
    s.prop("Bench", -30.0, -56.6, 180)
    s.prop("WaterCooler", -41.8, -56.9, 180)
    s.prop("Plant", -11.6, -55.2, 0)
    for x, text in ((-38.0, "取調室 1  INTERVIEW 1"), (-14.0, "取調室 2  INTERVIEW 2")):
        fit.plaque(s, x, 10.4, -57.7, 180, 6.0, 0.8, text)
    fit.panel(s, -26.0, -53.0, C, w=5.0, brightness=0.7, range_=18)
    kit.wall_clock(s, -26.0, 10.6, -57.7, 180, 0.9)


def copy_room(s):
    fit.partition(s, (-8.0, -48.0), (24.0, -48.0), Y, C, "PlasterLight", "PlasterGrey", doors=[(16.0, 5.0)],
                  glass="clear")
    fit.partition(s, (24.0, -75.0), (24.0, -48.0), Y, C, "PlasterGrey", "PlasterLight")
    for x in (-2.0, 6.0):
        s.prop("Photocopier", x, -71.4, 180)
    top = fit.counter(s, 16.0, -72.4, 180, 9.0, d=2.2, top="WhiteTrim", body="PlasterGrey")
    s.prop("FaxMachine", 13.5, -72.4, 180, 1.0, top)
    s.prop("FaxMachine", 17.5, -72.4, 180, 1.0, top)
    # Pigeonholes on the west wall, paper stock, a table for sorting the post.
    s.box("Wood", (-7.1, 6.0, -62.0), (0.6, 5.6, 9.0), collide=True)
    for row in range(5):
        for col in range(6):
            s.box("Paper", (-6.75, 3.6 + row * 1.05, -65.8 + col * 1.5), (0.1, 0.6, 1.1))
    s.prop("Crate", 20.5, -53.0, 15)
    fit.table(s, 8.0, -60.0, 6.0, 3.0, 0, Y)
    s.sheet(8.0, 2.8, -60.0, spare=True)
    s.hood(21.0, -60.0, spare=True)
    s.prop("TrashCan", 21.8, -66.0, 0)
    fit.panel(s, 0.0, -64.0, C, color=fit.COOL, brightness=0.8)
    fit.panel(s, 14.0, -58.0, C, on=False)
    fit.plaque(s, 8.0, 10.6, -47.7, 0, 5.0, 0.9, "複写室 COPY ROOM")


def lockers(s):
    fit.partition(s, (24.0, -48.0), (50.0, -48.0), Y, C, "TileMetroGrey", "PlasterGrey", doors=[(13.0, 4.4)])
    for z in (-70.8, -64.6, -58.4):
        s.prop("CoinLockers", 48.3, z, 90)
    for z in (-70.8, -64.6):
        s.prop("CoinLockers", 25.7, z, -90)
    s.prop("Bench", 29.4, -67.7, 90)  # each bench faces a bank of lockers
    s.prop("Bench", 44.6, -64.6, -90)
    fit.closed_door(s, 24.3, -55.0, -90, Y, 4.0, "Steel", sign="シャワー SHOWERS")
    s.prop("CoatStand", 44.5, -51.5, 0)
    s.hood(28.5, -52.5)
    fit.panel(s, 37.0, -64.0, C, color=fit.COOL, brightness=0.75)
    fit.plaque(s, 37.0, 10.6, -47.7, 0, 5.4, 0.9, "更衣室 LOCKERS")


def break_room(s):
    fit.partition(s, (50.0, -75.0), (50.0, -40.0), Y, C, "PlasterLight", "TileMetroGrey", doors=[(31.0, 5.0)])
    fit.partition(s, (50.0, -40.0), (100.0, -40.0), Y, C, "PlasterLight", "PlasterGrey", doors=[(25.0, 5.0)])
    # Vending machines along the west wall; the gap behind the last one is the drop point.
    s.prop("VendingBlue", 51.9, -69.8, -90)
    s.prop("VendingWhite", 51.9, -65.4, -90)
    s.prop("VendingMachine", 51.8, -60.9, -90)
    s.drop_point("behind the vending machines", 52.4, -73.2)
    # The kitchenette along the east glass: counter, sink, coffee; the fridge, the cooler.
    top = fit.counter(s, 97.3, -63.0, 90, 18.0, d=2.4, top="WhiteTrim", body="WoodPanel")
    s.prop("CoffeeMachine", 97.4, -66.0, 90, 1.0, top)
    s.box("Steel", (97.3, top + 0.06, -60.0), (2.0, 0.05, 2.6))
    s.prop("DrinkFridge", 86.0, -72.6, 180)
    s.prop("WaterCooler", 76.5, -73.2, 180)
    for x, z in ((66.0, -66.0), (66.0, -53.0), (80.0, -58.0)):
        fit.table(s, x, z, 5.0, 3.0, 0, Y)
        fit.chairs_round(s, x, z, 5.0, 3.0, 0, Y)
    s.sheet(80.0, 2.8, -58.0)
    s.prop("Sofa", 88.0, -44.2, 180)
    s.prop("Plant", 97.2, -43.2, 0)
    s.box("BlackMetal", (88.0, 8.6, -40.15), (7.6, 4.6, 0.3))
    s.screen((88.0, 8.6, -40.4), 0, 7.0, 4.0, "news")
    for x, z in ((64.0, -60.0), (84.0, -64.0)):
        fit.panel(s, x, z, C, brightness=0.95, range_=20)
    fit.panel(s, 90.0, -50.0, C, on=False)
    s.sound("mapOfficeHum", (75.0, 8.0, -58.0), 40.0, 0.2)
    fit.plaque(s, 64.0, 10.6, -40.4, 0, 5.0, 0.9, "休憩室 BREAK ROOM")


def night_desk(s):
    fit.partition(s, (50.0, -40.0), (50.0, 16.0), Y, C, "PlasterGrey", "PlasterGrey", doors=[(20.0, 5.0), (48.0, 5.0)],
                  glass="clear")
    fit.partition(s, (50.0, 16.0), (100.0, 16.0), Y, C, "PlasterGrey", "PlasterLight", doors=[(38.0, 5.0)])
    s.station("Phone", "Call Log Desk", 88.0, -29.0, 0, prop="StationPhoneDesk")
    kit.column_square(s, 75.0, -12.0, C, 2.4, "PlasterLight", trim="BlackTrim")
    for x, z, rot in ((62.0, -30.0, 0), (62.0, -14.0, 0), (88.0, -8.0, 90), (62.0, 2.0, 0)):
        fit.desk_pair(s, x, z, rot, Y)
    s.prop("Whiteboard", 75.0, -24.0, 180)
    s.prop("Whiteboard", 88.0, 6.5, 0)
    for z in (-21.0, -18.5, -16.0):
        s.prop("FilingCabinet", 97.8, z, 90)  # fronts to the room, backs to the glass
    for x in (60.0, 76.0):
        s.prop("PinBoard", x, 15.55, 0, 1.0, 7.4)
    s.prop("CoatStand", 96.5, 12.0, 0)
    s.prop("Plant", 53.2, 12.8, 0)
    for x, z in ((88.0, -26.0), (70.0, -4.0)):
        fit.panel(s, x, z, C, brightness=0.8, flicker=x == 70.0)
    fit.panel(s, 62.0, -22.0, C, on=False)
    fit.panel(s, 88.0, 6.0, C, on=False)
    fit.plaque(s, 49.7, 10.6, -26.0, 90, 5.0, 0.9, "夜勤 NIGHT DESK")


# The lobby, the lounge ------------------------------------------------------------------------------------


def lobby(s):
    # The speed gates into the bullpen, glass screens either side.
    for z in (12.0, 18.0, 24.0, 30.0, 36.0):
        s.prop("TicketGate", -16.0, z, 90)
    for z0, z1 in ((2.4, 9.8), (38.2, 43.8)):
        fit.balcony(s, [(-16.0, z0), (-16.0, z1)], Y, h=7.0, guard=False)
    # The screening line by the lifts: the walk-through detector and the baggage belt.
    s.prop("MetalDetector", 12.0, 7.4, 0)
    for x in (10.15, 13.85):
        s.collider((x, 3.9, 7.4), (0.4, 7.8, 2.2), 0, True, None)
    s.prop("XRayScanner", 22.5, 7.6, 90)
    # Reception: the front desk (the Entrance Cam) facing the lifts; seats for visitors.
    s.station("Camera", "Entrance Cam", 18.0, 26.0, 0, prop="StationReception")
    s.light("point", (20.1, 4.4, 26.8), fit.LAMP, 14, 0.9)
    for x in (10.0, 30.0):
        s.prop("PlatformBench", x, 34.2, 180)
    for x, z in ((46.8, -3.2), (46.8, 41.0), (-12.8, -3.2)):
        s.prop("Plant", x, z, 0)
    for z in (19.0, 33.0):
        s.prop("Planter", 48.4, z, -90)
    s.tip_box(48.3, 26.0, 90)
    # The sign wall facing the lifts, the Agency's name on it; the news over it.
    fit.partition(s, (0.0, 44.0), (34.0, 44.0), Y, C, "WoodPanel", "PlasterGrey", trim=False)
    s.sign((17.0, 8.6, 43.62), 0, 20.0, 2.2, "THE AGENCY", "GothamBlack", (236, 226, 196), None, (255, 220, 170))
    s.sign((17.0, 6.6, 43.62), 0, 20.0, 1.0, P.TOWER + "  38F", "GothamBold", (190, 190, 196), None)
    s.box("Brass", (17.0, 5.6, 43.66), (18.0, 0.1, 0.05))
    s.box("BlackMetal", (17.0, 11.3, 43.55), (9.6, 3.0, 0.2))
    s.screen((17.0, 11.3, 43.4), 0, 9.0, 2.6, "news")
    for x in (6.0, 28.0):
        s.cylinder("DarkMetal", (x, C - 0.12, 40.0), 0.5, 0.12, 12)
        s.light("spot", (x, C - 0.4, 40.0), fit.WARM, 16, 1.1, False, "Bottom", 60)
    for x, z in ((-10.0, -1.0), (-10.0, 20.0), (44.0, 2.0), (44.0, 20.0), (44.0, 36.0), (-10.0, 32.0)):
        fit.downlight(s, x, z, C, range_=16, brightness=0.75)
    s.sound("mapOfficeHum", (18.0, 8.0, 10.0), 50.0, 0.18)
    s.sound("mapCityHum", (18.0, 20.0, 30.0), 70.0, 0.12)


def lounge(s):
    fit.partition(s, (-16.0, 44.0), (-16.0, 75.0), Y, C, "PlasterGrey", "PlasterGrey", doors=[(16.0, 5.0)], glass="clear",
                  spans=[(0.6, 12.8), (19.2, 30.4)])
    # Commendations along the sign wall's back; sofas facing the glass with low tables.
    for x in (6.0, 13.0, 21.0, 28.0):
        s.prop("DisplayCase", x, 45.8, 180)
    for x in (-4.0, 14.0, 32.0):
        s.prop("Sofa", x, 65.5, 180)
        fit.table(s, x, 70.3, 4.0, 2.4, 0, Y, top="MarbleBlack", h=1.6)
    s.sheet(14.0, 1.65, 70.3, spare=True)
    s.prop("Sofa", 70.0, 30.0, 90)
    fit.table(s, 64.5, 30.0, 3.0, 4.0, 0, Y, top="MarbleBlack", h=1.6)
    s.prop("Sofa", 74.0, 50.0, -135)
    for x, z in ((-13.0, 72.0), (44.0, 72.0), (53.0, 19.0), (96.0, 19.5), (57.0, 70.0)):
        s.prop("Plant", x, z, (x * 7) % 360)
    s.prop("CoatStand", 47.0, 47.5, 0)
    # A coffee bar along the night desk's wall, stools at it; rugs under the corner's sofas.
    top = fit.counter(s, 72.0, 17.5, 180, 14.0, d=2.2, top="Wood", body="WoodPanel")
    s.prop("CoffeeMachine", 68.0, 17.3, 180, 1.0, top)
    for x in (66.5, 70.0, 73.5, 77.0):
        s.prop("BarStool", x, 20.4, 0)
    s.polygon("FabricRed", [(60.0, 0.08, 36.0), (74.0, 0.08, 36.0), (74.0, 0.08, 24.0), (60.0, 0.08, 24.0)])
    s.polygon("Fabric", [(66.0, 0.08, 56.0), (80.0, 0.08, 56.0), (80.0, 0.08, 44.0), (66.0, 0.08, 44.0)])
    s.hood(88.0, 22.0, spare=True)
    for x, z in ((-4.0, 62.0), (14.0, 62.0), (32.0, 62.0), (66.0, 36.0), (80.0, 24.0), (60.0, 56.0)):
        fit.downlight(s, x, z, C, range_=15, brightness=0.8)
    s.sound("mapRainGlass", (30.0, 6.0, 72.0), 50.0, 0.25)


# The bullpen ----------------------------------------------------------------------------------------------

COLUMNS = [(-72.0, -28.0), (-72.0, 4.0), (-72.0, 36.0), (-44.0, -28.0), (-44.0, 4.0), (-44.0, 36.0)]


def bullpen(s):
    for x, z in COLUMNS:
        kit.column_square(s, x, z, C, 2.4, "PlasterLight", trim="BlackTrim")
    # Desk pairs in rows, low screens between the rows.
    rows = [(-90.0, -36.0), (-58.0, -36.0), (-30.0, -37.0),
            (-90.0, -14.0), (-58.0, -18.0),
            (-90.0, 12.0), (-58.0, 18.0), (-30.0, 20.0),
            (-90.0, 30.0), (-58.0, 44.0)]
    for i, (x, z) in enumerate(rows):
        fit.desk_pair(s, x, z, 90, Y, (i % 2 == 0, i % 3 == 0))
    for x, z in ((-90.0, -25.0), (-90.0, 1.0), (-90.0, 21.0), (-58.0, -27.0), (-58.0, 31.0)):
        fit.screen_divider(s, x, z, 0, 9.0, Y)
    s.station("Fingerprint", "Print Scanner", -40.0, -10.0, 180, prop="StationPrintKit")
    # The squad's table, whiteboards, files and the coffee corner by the lounge.
    top = fit.table(s, -86.0, 46.0, 8.0, 4.0, 0, Y)
    fit.chairs_round(s, -86.0, 46.0, 8.0, 4.0, 0, Y)
    s.sheet(-85.0, top, 46.0)
    s.prop("Whiteboard", -76.0, 40.5, -90)
    s.prop("Whiteboard", -30.0, 5.0, 0)
    for z in (-44.4, -41.9, -39.4):
        s.prop("FilingCabinet", -97.9, z, -90)
    for z in (66.5, 69.0):  # against the sergeant's wall, clear of its door (z 58 to 62), fronts to the room
        s.prop("FilingCabinet", -74.6, z, -90)
    top = fit.counter(s, -17.5, 68.5, 90, 8.0, d=2.2, top="Wood", body="WoodPanel")
    s.prop("CoffeeMachine", -17.6, 67.0, 90, 1.0, top)
    s.prop("WaterCooler", -17.4, 55.0, 90)
    s.prop("Photocopier", -22.0, -44.0, -90)
    for x, z in ((-96.8, 50.0), (-19.0, 50.0), (-50.0, 71.6)):
        s.prop("Plant", x, z, 30)
    for x, z in ((-66.0, -45.5), (-96.0, 38.0), (-26.0, -24.0)):
        s.prop("CoatStand", x, z, 0)
    for x, z in ((-80.0, -24.0), (-52.0, 10.0), (-80.0, 29.0), (-24.0, 30.0)):
        s.prop("TrashCan", x, z, 0)
    # After hours: a few panels on over the station and the table, the rest off.
    for x, z in ((-40.0, -14.0), (-86.0, 46.0), (-58.0, 0.0), (-24.0, 40.0)):
        fit.panel(s, x, z, C, brightness=0.85, range_=20, flicker=(x, z) in ((-58.0, 0.0), (-24.0, 40.0)))
    for x, z in ((-86.0, 8.0), (-58.0, 30.0)):
        fit.panel(s, x, z, C, brightness=0.6, range_=18)
    for x, z in ((-86.0, -26.0), (-58.0, -30.0), (-30.0, -34.0), (-86.0, 64.0)):
        fit.panel(s, x, z, C, on=False)
    s.sound("mapOfficeHum", (-58.0, 8.0, 10.0), 60.0, 0.2)
    s.sound("mapRainGlass", (-96.0, 6.0, 10.0), 60.0, 0.22)


def sergeant(s):
    fit.partition(s, (-100.0, 53.0), (-76.0, 53.0), Y, C, "PlasterGrey", "WoodPanel", glass="blinds")
    fit.partition(s, (-76.0, 53.0), (-76.0, 75.0), Y, C, "PlasterGrey", "WoodPanel", doors=[(5.0, 4.2)], glass="blinds")
    fit.desk(s, -88.0, 66.0, 180, Y)
    s.prop("Bookshelf", -98.0, 60.0, -90)
    s.prop("Bookshelf", -98.0, 63.4, -90)
    s.prop("FilingCabinet", -79.0, 72.6, 0)  # back to the glass, front to the room
    s.drop_point("the sergeant's office", -97.2, 72.3, spare=True)
    fit.panel(s, -88.0, 61.0, C, w=3.0, brightness=0.6, range_=14)
    fit.plaque(s, -75.7, 10.6, 60.5, -90, 4.0, 0.8, "班長室 SERGEANT")


def corridor(s):
    """The corridor round the core: fittings, the exit sign, extinguishers, the floor guide."""
    for x in (-12.0, 22.0, 46.0):
        fit.panel(s, x, -44.0, C, w=3.0, brightness=0.7, range_=18, rot=90)
    for z in (-30.0, -14.0):
        fit.panel(s, -12.0, z, C, w=3.0, brightness=0.7, range_=18)
        fit.panel(s, 46.0, z, C, w=3.0, brightness=0.7, range_=18)
    kit.extinguisher(s, P.CORE[0] - 0.5, -36.0, 90)
    kit.extinguisher(s, P.CORE[2] + 0.5, -24.0, -90)
    fit.exit_sign(s, P.CORE[0] - 0.5, 10.0, -20.0, 90)
    fit.plaque(s, P.CORE[0] - 0.5, 7.2, -28.0, 90, 7.0, 4.2,
               "38F  案内\nSECURITY · INTERVIEW  ↑\nCOPY · LOCKERS  ↑\nBREAK ROOM · NIGHT DESK  →", (220, 220, 225),
               (20, 22, 28))
    s.prop("Bench", 48.85, -33.0, 90, 0.9)  # against the outer wall: the corridor stays 6 wide


def build(s, g):
    floors(s)
    security(s)
    observation(s)
    interviews(s)
    copy_room(s)
    lockers(s)
    break_room(s)
    night_desk(s)
    lobby(s)
    lounge(s)
    bullpen(s)
    sergeant(s)
    corridor(s)
