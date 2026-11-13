"""38F, where the lifts arrive: the lobby under the atrium (the screening line by the lifts, the
reception desk, the speed gates into the bullpen), the lounge along the south glass, the bullpen
(the detectives' open floor) with the sergeant's office, and along the north the security office,
the observation room behind the one-way mirror, two interview rooms, the copy room and the locker
room; in the east the break room and the night desk.

Every station keeps a clear square in front of it and its screen in view of its room; sheets rest
on tables built with the scene. Walls run so their "n" side is north (walls running east) or east
(walls running south)."""

from maps import city, kit, lightbook, rugs
from maps import geo2d as g2
from maps.venues.agency import fit
from maps.venues.agency import plan as P

Y = P.L1
C = P.CEIL1


def floors(s):
    rooms = P.ROOMS_L1
    looks = {"security": "CarpetTile", "observation": "CarpetTileBlue", "interview_a": "VinylClinic",
             "interview_b": "VinylClinic", "copy": "Linoleum", "lockers": "TerrazzoDark", "break": "WoodFloor",
             "night": "CarpetTileBlue", "sergeant": "WoodFloorDark"}
    for name, poly in rooms.items():
        fit.floor_faces(s, poly, Y, looks[name])
    fit.floor_faces(s, P.LOBBY, Y, "MarbleBlack")
    fit.floor_faces(s, P.LOUNGE, Y, "WoodHerringbone")
    # Finished ceilings (a hair under the office tiles) over the lobby and the lounge.
    for poly in (P.LOBBY, P.LOUNGE):
        fit.ceiling_faces(s, poly, P.CEIL1 - 0.06, "CeilingPlasterDark", holes=[P.rect_of(P.VOID)])
    fit.floor_faces(s, P.BULLPEN, Y, "CarpetNavy", holes=[rooms["sergeant"]])
    taken = [P.rect_of(P.CORE), P.LOBBY, P.BULLPEN, P.LOUNGE] + list(rooms.values())
    holes = [g2.ccw(q) for t in taken for q in g2.convex_pieces(t)]
    for piece in g2.subtract_all([g2.ccw(q) for q in g2.convex_pieces(P.PLATE)], holes):
        if abs(g2.area(piece)) > 0.5:
            city.up_face(s, "CarpetGrey", piece, Y)
    s.zone("interior", P.PLATE, Y, name="38F")


# The north rooms -----------------------------------------------------------------------------------------


def security(s):
    # The south wall onto the bullpen (its blinds shut) with the door, solid at its east end where the roster and the
    # key cabinet hang; the wall to the observation room with the staff door; a wall of monitors on that wall's west
    # face. Both painted dark below a rail, as institutions paint the part that gets kicked.
    fit.partition(s, (-100.0, -48.0), (-58.0, -48.0), Y, C, "PlasterGrey", "PlasterGrey", doors=[(14.0, 5.0)],
                  glass="blinds", spans=[(0.6, 10.7), (19.6, 29.0)], dado_n=("PlasterDark", "BlackTrim"))
    fit.framed(s, -82.0, 6.4, -48.3, 0, 1.5, 4, "BlackTrim", 0.12)  # the floor's evacuation plan, by the door
    fit.partition(s, (-58.0, -75.0), (-58.0, -48.0), Y, C, "PlasterDark", "PlasterGrey", doors=[(23.0, 4.2)],
                  dado_n=("WoodPanel", "BlackTrim", 3.0), dado_s=("PlasterDark", "BlackTrim"))
    # A bulkhead over the monitor wall, carrying their cables (the room's ceiling lights stand clear of it, at x -79).
    s.box("PlasterGrey", (-60.3, C - 0.8, -61.35), (4.0, 1.6, 26.1), skip=("+y",))
    s.box("BlackTrim", (-62.33, C - 1.6, -61.35), (0.1, 0.16, 26.1))  # (its foot 0.08 under the soffit's)
    # The anti-fatigue mat the night shift stands on at the monitors.
    s.box("Rubber", (-63.9, 0.02, -66.5), (3.9, 0.04, 12.4), skip=("-y",))
    # The east end of the south wall: the shift roster on a cork board, the key cabinet, the clock over them, and the
    # radio desk under them.
    s.prop("PinBoard", -66.0, -48.45, 0, 1.0, 5.6)
    s.box("DarkMetal", (-61.4, 6.6, -48.52), (2.6, 3.4, 0.4))
    s.box("BlackTrim", (-61.4, 6.6, -48.73), (2.3, 3.1, 0.03))
    for row in range(3):
        for col in range(4):
            s.box("Brass", (-62.3 + col * 0.6, 7.6 - row * 0.95, -48.8), (0.08, 0.32, 0.08))
    s.sign((-61.4, 5.2, -48.76), 0, 2.2, 0.45, "鍵 KEYS", "GothamBold", (220, 220, 225), None)
    s.prop("WallClock", -64.0, -48.6, 0, 0.7, 10.1)
    top = fit.table(s, -66.5, -49.7, 5.0, 2.2, 0, Y, top="Wood")
    s.prop("Radio", -67.9, -49.6, 0, 1.0, top)
    s.prop("DeskPhone", -65.1, -49.9, 20, 1.0, top)
    s.prop("Chair", -66.5, -51.9, 180)
    # A camera dome in the corner over the staff door: the security office watches itself too.
    s.box("BlackMetal", (-59.2, C - 0.08, -50.2), (0.9, 0.16, 0.9))
    s.lathe("GlassDark", (-59.2, C - 0.6, -50.2), [(0.0, 0.0), (0.26, 0.08), (0.36, 0.25), (0.38, 0.44)], 10,
            caps=(False, True))
    s.station("Camera", "CCTV Wall", -80.0, -71.2, 180, prop="StationCRTBank")
    x = -58.3  # the wall's west face
    s.box("BlackMetal", (x - 0.4, 7.4, -66.5), (0.8, 6.8, 12.8), collide=True, query=False)
    for row in range(2):
        for col in range(4):
            z = -71.4 + col * 3.1
            y = 5.6 + row * 2.9
            s.box("CreamTrim", (x - 1.9, y, z), (2.2, 2.5, 2.9), collide=True, query=False)
            s.box("BlackTrim", (x - 3.02, y, z), (0.05, 2.1, 2.5))
            s.screen((x - 3.1, y, z), 90, 2.3, 1.7, "cctv")
    fit.counter(s, x - 2.4, -66.5, 90, 12.6, d=2.4, h=3.4, top="BlackTrim", body="DarkMetal")
    for z in (-69.5, -63.5):
        s.prop("OfficeChair", x - 5.6, z, -90)
    s.light("point", (x - 3.6, 7.0, -66.5), (110, 160, 255), 16, 0.7)  # the monitors' spill, at their faces
    # Filing cabinets along the west glass, a weapons locker, the duty sergeant's desk.
    for z in (-72.0, -69.5, -67.0, -64.5):
        s.prop("FilingCabinet", -98.0, z, -90)
    # (The weapons locker on the solid east wall, between the monitors' counter and the staff door: on the
    # glass, it stood in a pane.)
    s.box("DarkMetal", (-59.45, 3.6, -57.1), (2.2, 7.2, 5.0), collide=True)
    s.box("BlackTrim", (-60.6, 3.6, -57.1), (0.05, 6.6, 0.1))
    # (its two leaves: handles either side of the meeting line, louvres at the top, a stencilled plate, a plinth)
    for dz in (-0.35, 0.35):
        s.box("Steel", (-60.62, 3.8, -57.1 + dz), (0.08, 0.9, 0.1))
    for k in range(3):
        for dz in (-1.3, 1.3):
            s.box("BlackTrim", (-60.58, 6.3 + k * 0.3, -57.1 + dz), (0.03, 0.08, 1.6), skip=("+x",))
    s.sign((-60.64, 5.0, -57.1), -90, 3.0, 0.45, "武器庫 ARMOURY", "GothamBlack", (210, 200, 160), None)
    s.box("BlackTrim", (-59.45, 0.12, -57.1), (2.3, 0.24, 5.1))
    fit.desk(s, -84.0, -57.0, 90, Y)
    s.prop("CoatStand", -62.5, -51.5, 0)
    # Panels over the CCTV desk (a tired one) and the duty desk; the monitors light the rest.
    fit.ceiling_lights(s, P.ROOMS_L1["security"], C, "panel", [(-80.0, -66.0), (-84.0, -57.0)], spacing=14.0,
                       flicker=[(-80.0, -66.0)], color=fit.COOL, brightness=0.85, shadows=[(-84.0, -57.0)])
    fit.plaque(s, -86.0, 10.6, -47.7, 180, 5.2, 0.9, "警備室 SECURITY")


def observation(s):
    # The one-way mirror onto interview 1 (dark glass: it stops a flash either way).
    # (Walnut panelling up to a rail on the room's three walls; the mirror's sill at 3.2 keeps its casing clear of it.)
    fit.partition(s, (-44.0, -75.0), (-44.0, -48.0), Y, C, "PlasterDark", "PlasterDark", glass="mirror",
                  spans=[(3.0, 14.5)], sill=3.2, head=9.0, dado_s=("WoodPanel", "BlackTrim", 3.0))
    fit.partition(s, (-58.0, -48.0), (-44.0, -48.0), Y, C, "PlasterDark", "PlasterGrey", doors=[(7.0, 4.4)],
                  dado_n=("WoodPanel", "BlackTrim", 3.0))
    # Padded leather over the panelling on the west wall, in squares, so nothing said here carries through to the
    # interview room. (Over the filing cabinet's top, 5.0, and clear of the staff door, z -54.1 to -49.9.)
    for y in (6.45, 8.95):
        for z in (-71.9, -69.4, -66.9, -64.4, -61.9, -59.4, -56.9):
            s.box("Leather", (-57.56, y, z), (0.2, 2.3, 2.3), skip=("-x",))
    fit.framed(s, -55.4, 5.6, -48.3, 0, 1.5, 5, "BlackTrim", 0.12)  # "quiet: do not come in while recording"
    s.prop("WallClock", -44.6, -54.5, 90, 0.6, 7.6)  # (on the mirror's wall, past the glass)
    s.station("Phone", "Wiretap Console", -47.8, -66.0, 90, prop="StationReelToReel")
    s.prop("Chair", -54.5, -71.5, -90)
    top = fit.table(s, -55.8, -57.6, 3.0, 2.2, 90, Y)
    s.prop("CoffeeMachine", -55.8, -58.2, -90, 1.0, top)  # front to the room, back to the wall
    s.box("NeonRed", (-51.0, 10.1, -48.34), (1.2, 0.35, 0.05))  # the red lamp over the door: recording
    s.sign((-51.0, 10.9, -48.36), 0, 3.0, 0.5, "録音中 ON AIR", "GothamBlack", (255, 90, 90), None)
    s.light("point", (-51.0, 9.8, -49.1), (255, 60, 60), 8, 0.5)
    fit.ceiling_lights(s, P.ROOMS_L1["observation"], C, "panel", [(-50.0, -62.0)], spacing=13.5, size=3.0,
                       brightness=0.75, shadows=[(-50.0, -62.0)])


def interview(s, x0, x1, table):
    """An interview room: the bolted table with its cuffs, two chairs, the lamp over it, a camera
    watching from the corner."""
    tx, tz = table
    s.prop("InterrogationTable", tx, tz, 90)
    s.prop("Handcuffs", tx, tz, 90, 1.0, 2.8)
    s.prop("Chair", tx - 3.3, tz, -90)
    s.prop("Chair", tx + 3.3, tz, 90)
    # (the room's only light: one bare lamp low over the table, the corners left dark)
    kit.pendant(s, tx, C, tz, drop=5.6, shade="BlackMetal", color=fit.LAMP, range_=15, brightness=1.6, wide=1.0,
                point=True)
    s.box("BlackMetal", (x1 - 1.2, 11.6, -73.8), (0.8, 0.6, 1.2), 45)
    s.box("NeonRed", (x1 - 1.6, 11.6, -73.4), (0.12, 0.12, 0.05), 45)


def interviews(s):
    fit.partition(s, (-44.0, -58.0), (-8.0, -58.0), Y, C, "PlasterDark", "PlasterGrey", doors=[(9.0, 4.4), (27.0, 4.4)])
    fit.partition(s, (-26.0, -75.0), (-26.0, -58.0), Y, C, "PlasterDark", "PlasterDark")
    fit.partition(s, (-8.0, -75.0), (-8.0, -48.0), Y, C, "PlasterGrey", "PlasterDark")
    interview(s, -44.0, -26.0, (-35.0, -66.5))
    interview(s, -26.0, -8.0, (-19.5, -64.5))
    s.station("Phone", "Interview Recorder", -12.4, -71.4, 180, prop="StationPhoneDesk", spare=True)
    # The hall outside them, walled off from the bullpen with a doorway across from the bench (the bullpen lay open
    # to it and to the corridor round the core, no wall at the corner between them, 2026-10-26), and from the
    # corridor's end too, where a plant stood in the gap (the user's call of 2026-10-27: a solid wall); a bench, the
    # water cooler, a plant in its corner by the copy room, the room plates.
    fit.partition(s, (-44.0, -48.0), (-16.0, -48.0), Y, C, "PlasterGrey", "PlasterGrey", doors=[(14.0, 5.0)])
    fit.partition(s, (-16.0, -48.0), (-8.0, -48.0), Y, C, "PlasterGrey", "PlasterGrey")
    s.prop("Bench", -30.0, -56.6, 180)
    s.prop("WaterCooler", -41.8, -56.9, 180)
    s.prop("Plant", -9.7, -56.2, 0)
    for x, text in ((-38.0, "取調室 1  INTERVIEW 1"), (-14.0, "取調室 2  INTERVIEW 2")):
        fit.plaque(s, x, 10.4, -57.7, 180, 6.0, 0.8, text)
    # The hall: a run of downlights along it, over the bench and the doors, the last one dead.
    fit.ceiling_lights(s, (-44.0, -58.0, -8.0, -48.0), C, "downlight", [(-35.0, -53.0), (-17.0, -53.0)],
                       spacing=9.0, dead=[(-11.0, -53.0)], brightness=0.75, range_=16, shadows=[(-35.0, -53.0)])
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
    s.prop("TrashCan", 21.8, -66.0, 0)
    fit.ceiling_lights(s, P.ROOMS_L1["copy"], C, "panel", [(4.0, -68.0), (12.0, -60.0)], spacing=11.0,
                       dead=[(16.0, -55.0)], color=fit.COOL, brightness=1.1, range_=18, shadows=[(12.0, -60.0)])
    fit.plaque(s, 8.0, 10.6, -47.7, 180, 5.0, 0.9, "複写室 COPY ROOM")


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
    fit.ceiling_lights(s, P.ROOMS_L1["lockers"], C, "tube", [(37.0, -64.0), (37.0, -53.0)], spacing=10.0,
                       color=lightbook.OFFICE, brightness=1.15, range_=18, flicker=[(37.0, -53.0)],
                       shadows=[(37.0, -64.0)])
    fit.plaque(s, 37.0, 10.6, -47.7, 180, 5.4, 0.9, "更衣室 LOCKERS")


def break_room(s):
    # (Walnut below a rail on the break room's side of both its walls.)
    fit.partition(s, (50.0, -75.0), (50.0, -40.0), Y, C, "PlasterLight", "TileMetroGrey", doors=[(31.0, 5.0)],
                  dado_n=("WoodPanel", "Wood"))
    fit.partition(s, (50.0, -40.0), (100.0, -40.0), Y, C, "PlasterLight", "PlasterGrey", doors=[(25.0, 5.0)],
                  dado_n=("WoodPanel", "Wood"))
    # The city at night framed on the west wall past the machines, a clock by the door, a rug in the sofa's corner.
    fit.framed(s, 50.3, 6.4, -52.5, -90, 2.6, 2, "BlackTrim")
    s.prop("WallClock", 56.0, -40.6, 0, 0.7, 8.6)
    rugs.lay(s, 88.0, -47.0, 10.0, 6.0, 0, Y, "RugFieldNavy")
    # Vending machines along the west wall.
    s.prop("VendingBlue", 51.9, -69.8, -90)
    s.prop("VendingWhite", 51.9, -65.4, -90)
    s.prop("VendingMachine", 51.8, -60.9, -90)
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
    s.box("BlackMetal", (88.0, 8.6, -40.45), (7.6, 4.6, 0.3))  # on the wall's face (-40.3), not in it
    s.screen((88.0, 8.6, -40.65), 0, 7.0, 4.0, "news")
    # Over the three tables and the kitchenette; the sofa's corner under the news screen stays dim.
    fit.ceiling_lights(s, P.ROOMS_L1["break"], C, "panel", [(66.0, -60.0), (80.0, -58.0), (94.0, -64.0)],
                       spacing=12.5, dead=[(94.0, -47.0)], brightness=0.85, shadows=[(80.0, -58.0)])
    s.sound("mapOfficeHum", (75.0, 8.0, -58.0), 40.0, 0.2)
    fit.plaque(s, 64.0, 10.6, -40.4, 0, 5.0, 0.9, "休憩室 BREAK ROOM")


def night_desk(s):
    # (solid where the corridor's mouth wall meets it, at z -6: a pane ran through that wall)
    fit.partition(s, (50.0, -40.0), (50.0, 16.3), Y, C, "PlasterGrey", "PlasterGrey", doors=[(20.0, 5.0), (48.0, 5.0)],
                  glass="clear", spans=[(0.6, 17.0), (23.0, 32.5), (35.5, 45.0), (51.0, 55.7)])
    fit.partition(s, (50.3, 16.0), (100.0, 16.0), Y, C, "PlasterGrey", "PlasterLight", doors=[(37.7, 5.0)],
                  dado_s=("WoodPanel", "Wood", 3.0))  # (the lounge's side)
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
    # Over the call log desk and the desk pairs; the row by the east glass is off for the night.
    fit.ceiling_lights(s, P.ROOMS_L1["night"], C, "panel", [(88.0, -29.0), (62.0, -22.0), (62.0, 2.0)],
                       spacing=14.0, flicker=[(62.0, 2.0)], dead=[(88.0, -8.0), (88.0, 6.0)], brightness=0.9,
                       shadows=[(88.0, -29.0)])
    fit.plaque(s, 49.7, 10.6, -26.0, 90, 5.0, 0.9, "夜勤 NIGHT DESK")


# The lobby, the lounge ------------------------------------------------------------------------------------


def lobby(s):
    # The speed gates into the bullpen, in a framed portal through the lobby's west wall, glass either side; the
    # wall runs up to the ceiling and on into the lounge's (the owner, 2026-10-25: the lobby lay open to the bullpen
    # over low glass screens, and the lounge's wall stopped short in a bare end beside the gates).
    # (four gates across the 28-stud portal, flush to its jambs, so each lane between them is 5.5 studs wide)
    for z in (11.5, 19.83, 28.17, 36.5):
        s.prop("TicketGate", -16.0, z, 90)
    fit.partition(s, (-16.0, 2.0), (-16.0, 44.0), Y, C, "PlasterGrey", "PlasterGrey", doors=[(22.0, 28.0)],
                  glass="clear", spans=[(1.2, 6.8), (37.2, 40.8)])
    fit.plaque(s, -15.6, 10.7, 24.0, -90, 8.0, 1.0, "捜査課 BULLPEN")
    fit.plaque(s, -16.4, 10.7, 24.0, 90, 8.0, 1.0, "ロビー LOBBY")
    # The screening line by the lifts: the walk-through detector and the baggage belt.
    s.prop("MetalDetector", 12.0, 7.4, 0)
    for x in (10.15, 13.85):
        s.collider((x, 3.9, 7.4), (0.4, 7.8, 2.2), 0, True, None)
    s.prop("XRayScanner", 22.5, 7.6, 90)
    # Reception: the front desk (the Entrance Cam) facing the lifts; seats for visitors.
    s.station("Camera", "Entrance Cam", 18.0, 26.0, 0, prop="StationReception")
    s.light("point", (15.9, 4.1, 26.85), fit.LAMP, 14, 0.9)  # at the desk lamp's bulb (StationReception)
    for x in (10.0, 30.0):
        s.prop("PlatformBench", x, 34.2, 180)
    for x, z in ((46.8, 12.0), (-13.4, 0.2)):
        s.prop("Plant", x, z, 0)
    for z in (19.0, 33.0):
        s.prop("Planter", 48.4, z, -90)
    s.tip_box(48.3, 26.0, 90)
    # The sign wall facing the lifts, the Agency's name on it; the news over it.
    fit.partition(s, (0.0, 44.0), (34.0, 44.0), Y, C, "WoodPanel", "PlasterGrey", trim=False,
                  dado_s=("WoodPanel", "Wood", 3.0))
    # Walls wherever the lobby's marble meets another floor (the owner, 2026-11-01: the lounge lay open to it on two
    # sides and the corridor's mouths too, so the bell and the planters stood against nothing). Glass onto the lounge,
    # a doorway in each.
    lounge_dado = ("WoodPanel", "Wood", 3.0)
    fit.partition(s, (-16.0, 44.0), (0.0, 44.0), Y, C, "PlasterGrey", "PlasterGrey", doors=[(8.0, 5.0)],
                  glass="clear", dado_s=lounge_dado)
    fit.partition(s, (34.0, 44.0), (50.0, 44.0), Y, C, "PlasterGrey", "PlasterGrey", doors=[(8.0, 5.0)],
                  glass="clear", dado_s=lounge_dado)
    fit.partition(s, (50.0, 16.3), (50.0, 44.0), Y, C, "PlasterGrey", "PlasterGrey", doors=[(23.2, 5.0)],
                  glass="clear", spans=[(0.8, 6.5), (12.0, 19.5)], dado_n=lounge_dado)  # (solid behind the bell, at 9.7)
    for x0, x1 in ((-16.0, -8.0), (42.0, 50.0)):
        fit.partition(s, (x0, -6.0), (x1, -6.0), Y, C, "PlasterGrey", "PlasterGrey", doors=[(4.0, 5.0)])
    s.sign((17.0, 8.6, 43.62), 0, 20.0, 2.2, "THE BUREAU", "GothamBlack", (236, 226, 196), None, (255, 220, 170))
    s.sign((17.0, 6.6, 43.62), 0, 20.0, 1.0, P.TOWER + "  38F", "GothamBold", (190, 190, 196), None)
    s.box("Brass", (17.0, 5.6, 43.66), (18.0, 0.1, 0.05))
    s.box("BlackMetal", (17.0, 11.3, 43.55), (9.6, 3.0, 0.2))
    s.screen((17.0, 11.3, 43.4), 0, 9.0, 2.6, "news")
    # Downlights round the atrium's hole (the pendants light its middle): over the gates, the screening line's end and
    # the sign wall, one kind all round.
    for x, z in ((-10.0, 12.0), (44.0, 6.0), (44.0, 30.0), (14.0, 40.0)):
        fit.downlight(s, x, z, C, range_=16, brightness=1.05)
    s.sound("mapOfficeHum", (18.0, 8.0, 10.0), 50.0, 0.18)
    s.sound("mapCityHum", (18.0, 20.0, 30.0), 70.0, 0.12)


def lounge(s):
    fit.partition(s, (-16.0, 44.0), (-16.0, 75.0), Y, C, "PlasterGrey", "PlasterGrey", doors=[(16.0, 5.0)], glass="clear",
                  spans=[(0.6, 12.8), (19.2, 30.4)], dado_n=("WoodPanel", "Wood", 3.0))
    # The wall of honour along the sign wall's back: its name in brass over the citations and prints framed above the
    # cases.
    s.box("Brass", (17.0, 9.15, 44.36), (24.0, 0.08, 0.05))
    s.sign((17.0, 9.85, 44.38), 180, 22.0, 1.0, "名誉の壁   WALL OF HONOUR", "GothamBold", (196, 170, 112), None)
    for x, left, right in ((6.0, 0, 1), (13.0, 1, 2), (21.0, 0, 3), (28.0, 1, 0)):
        s.prop("DisplayCase", x, 45.8, 180)
        fit.framed(s, x - 1.45, 6.5, 44.3, 180, 1.8, left, "Wood" if left in (0, 1) else "BlackTrim")
        fit.framed(s, x + 1.45, 6.5, 44.3, 180, 1.8, right, "Wood" if right in (0, 1) else "BlackTrim")
    # Sofas facing the glass with low tables, each group on its own rug.
    for x, field in ((-4.0, "RugField"), (14.0, "RugFieldNavy"), (32.0, "RugField")):
        s.prop("Sofa", x, 65.5, 180)
        fit.table(s, x, 70.3, 4.0, 2.4, 0, Y, top="MarbleBlack", h=1.6)
        rugs.lay(s, x, 68.4, 9.0, 7.0, 0, Y, field)
    s.sheet(14.0, 1.65, 70.3, spare=True)
    s.prop("Sofa", 70.0, 30.0, 90)
    fit.table(s, 64.5, 30.0, 3.0, 4.0, 0, Y, top="MarbleBlack", h=1.6)
    rugs.lay(s, 66.5, 30.0, 11.0, 10.0, 0, Y)
    s.prop("Sofa", 74.0, 50.0, -135)
    rugs.lay(s, 75.4, 51.4, 10.0, 7.0, 45, Y, "RugFieldNavy")
    for cx in (5.0, 25.0):  # (the armchair corners: clutter.lower)
        rugs.lay(s, cx, 55.0, 10.0, 7.0, 0, Y, "RugFieldNavy")
    for x, z in ((-13.0, 72.0), (44.0, 72.0), (53.0, 19.0), (96.0, 19.5), (57.0, 70.0)):
        s.prop("Plant", x, z, (x * 7) % 360)
    s.prop("CoatStand", 47.0, 47.5, 0)
    # A coffee bar along the night desk's wall, stools at it; rugs under the corner's sofas.
    top = fit.counter(s, 72.0, 17.5, 180, 14.0, d=2.2, top="Wood", body="WoodPanel")
    s.prop("CoffeeMachine", 68.0, 17.3, 180, 1.0, top)
    for x in (66.5, 70.0, 73.5, 77.0):
        s.prop("BarStool", x, 20.4, 0)
    # Over the bar, a board of what it serves; city photographs along the wall beside it.
    s.box("BlackTrim", (72.0, 7.4, 16.36), (6.4, 2.2, 0.12))
    s.sign((72.0, 7.4, 16.44), 180, 6.0, 1.8, "珈琲  COFFEE\n煎茶  TEA", "GothamBold", (226, 214, 186), None)
    for x, index in ((55.5, 2), (59.5, 3), (94.0, 2)):
        fit.framed(s, x, 6.6, 16.3, 180, 2.2, index, "BlackTrim")
    s.prop("WallClock", 82.0, 16.6, 180, 0.7, 7.6)
    # A coffered ceiling, walnut beams 9 studs apart, a downlight in the cell over each sofa group (the glass and the
    # city light the rest).
    fit.coffers(s, P.LOUNGE, C - 0.06, [-8.5 + 9.0 * k for k in range(13)], [25.5 + 9.0 * k for k in range(6)],
                (0.3, 0.3, 0.3, 1.0, 1.0, 1.0, 0.3))
    for x, z in ((-4.0, 66.0), (14.0, 66.0), (32.0, 66.0), (66.0, 30.0), (77.0, 48.0), (86.0, 21.0)):
        fit.downlight(s, x, z, C, range_=16, brightness=0.95)
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
    # After hours: panels on over the print scanner, the squad's table, the coffee corner and down the middle aisle
    # (the desk lamps light the desks), and the row along the west glass dead. The sergeant's room is not the
    # bullpen's: its ceiling stops at z 53.
    pen = (-100.0, -48.0, -16.0, 53.0)
    fit.ceiling_lights(s, pen, C, "panel",
                       [(-40.0, -10.0), (-86.0, 46.0), (-58.0, 0.0), (-30.0, 20.0), (-65.0, -28.0), (-65.0, 30.0)],
                       spacing=14.0, flicker=[(-58.0, 0.0)], dead=[(-93.0, -41.0), (-93.0, -12.0), (-93.0, 17.0)],
                       brightness=1.05, shadows=[(-40.0, -10.0), (-65.0, 30.0), (-65.0, -28.0)])
    fit.ceiling_lights(s, (-76.0, 53.0, -16.0, 75.0), C, "panel", [(-20.0, 64.0), (-50.0, 64.0)], spacing=14.0,
                       brightness=0.9, shadows=[(-50.0, 64.0)])
    s.sound("mapOfficeHum", (-58.0, 8.0, 10.0), 60.0, 0.2)
    s.sound("mapRainGlass", (-96.0, 6.0, 10.0), 60.0, 0.22)


def sergeant(s):
    fit.partition(s, (-100.0, 53.0), (-76.3, 53.0), Y, C, "PlasterGrey", "WoodPanel", glass="blinds")
    fit.partition(s, (-76.0, 52.7), (-76.0, 75.0), Y, C, "PlasterGrey", "WoodPanel", doors=[(5.3, 4.2)], glass="blinds")
    fit.desk(s, -88.0, 66.0, 180, Y)
    s.prop("Bookshelf", -98.0, 60.0, -90)
    s.prop("Bookshelf", -98.0, 63.4, -90)
    s.prop("FilingCabinet", -79.0, 72.6, 0)  # back to the glass, front to the room
    fit.ceiling_lights(s, P.ROOMS_L1["sergeant"], C, "downlight", [(-88.0, 64.0)], spacing=24.0, brightness=0.8,
                       range_=14, shadows=[(-88.0, 64.0)])
    fit.plaque(s, -75.7, 10.6, 60.5, -90, 4.0, 0.8, "班長室 SERGEANT")


def corridor_lights(s, ceiling):
    """The corridor round the core (both floors): narrow panels down the middle of each leg, turned along it, a pool
    at the corners and the doors with dimmer stretches between, the far end of the north leg dead."""
    legs = [((-16.0, -48.0, 50.0, -40.0), [(-10.0, -44.0), (14.0, -44.0), (38.0, -44.0)], [(46.0, -44.0)]),
            ((-16.0, -40.0, -8.0, 2.0), [(-12.0, -24.0), (-12.0, -4.0)], []),
            ((42.0, -40.0, 50.0, -6.0), [(46.0, -20.0)], [])]
    for rect, over, dead in legs:
        fit.ceiling_lights(s, rect, ceiling, "panel", over, spacing=13.0, size=3.0, dead=dead, brightness=0.7,
                           range_=18)


def corridor(s):
    """The corridor round the core: the bullpen's wall along its west side, fittings, the exit sign, extinguishers,
    the floor guide."""
    # (the lobby's wall carried on south to the interview hall, two doorways into the bullpen: it lay open to the
    # corridor all along here, 2026-10-26)
    fit.partition(s, (-16.0, -48.0), (-16.0, 2.0), Y, C, "PlasterGrey", "PlasterGrey", doors=[(12.0, 5.0), (38.0, 5.0)])
    corridor_lights(s, C)
    kit.extinguisher(s, P.CORE[0] - 0.5, -36.0, 90)
    kit.extinguisher(s, P.CORE[2] + 0.5, -24.0, -90)
    fit.exit_sign(s, P.CORE[0] - 0.5, 10.0, -20.0, 90)
    fit.plaque(s, P.CORE[0] - 0.5, 7.2, -28.0, 90, 7.0, 4.2,
               "38F  案内\nSECURITY / INTERVIEW  ↑\nCOPY / LOCKERS  ↑\nBREAK ROOM / NIGHT DESK  →", (220, 220, 225),
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
