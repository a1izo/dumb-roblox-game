"""Student life: the club house and the cafeteria, with the alley between them.

The club house (部室棟) is a 1960s concrete block, its windows lit late and tatekan signboards
out front. Inside:
- the entrance with its shoe lockers;
- the newsroom (the Student Newspaper Phone, a radio muttering);
- the film club, its projector running a reel on the wall;
- off the corridor, the kotatsu room (a sheet on the kotatsu), the band room with its drums and
  piano, and the locker room with the spare Club Locker Prints.

The cafeteria (学生食堂) has long tables, the meal-ticket machines by the door, the green public
phone (the Cafeteria Payphone) on the east wall, and the serving counter with the tray return,
the kitchen behind it look-only.

The alley between them runs to the campus wall. The club house's vending machines stand in it,
and the drop point is behind them."""

from maps import kit
from maps.venues.campus import fit, masonry
from maps.venues.campus import plan as P

C = P.CEIL
CLUB = P.CLUB
KX0, KZ0, KX1, KZ1 = P.inner(CLUB)  # -148.6, 59.4, -89.4, 108.6
CAF = P.CAFETERIA
FX0, FZ0, FX1, FZ1 = P.inner(CAF)  # -78.6, 59.4, -41.4, 108.6


def ceiling(s, r, mat="Ceiling"):
    x0, z0, x1, z1 = r
    fit.ceiling_faces(s, P.box(x0, z0, x1, z1), C, mat)
    s.collider(((x0 + x1) / 2, C + 0.5, (z0 + z1) / 2), (x1 - x0, 1.0, z1 - z0), 0, True, None)


def poster(s, x, y, z, rot, w, h, mat):
    p = fit.turn(rot, 0, -0.04)
    s.box(mat, (x + p[0], y, z + p[1]), (w, h, 0.03), rot)


# The club house --------------------------------------------------------------------------------------------


def club_exterior(s):
    masonry.shell(s, CLUB, P.EAVES["club"], P.DOORS["club"], brick="Concrete", inside="PlasterGrey",
                  storeys=[0.0, P.GF, P.GF + P.UP], arch=None, window_w=5.0, spacing=8.0, door_top=fit.DOOR_H,
                  lit=0.55, seed=11, trim="ConcreteDark", cornice=False)
    masonry.flat_roof(s, CLUB, P.EAVES["club"])
    fit.plaque(s, -118.0, 10.4, CLUB[1] - 0.05, 0, 7.0, 1.1, "部室棟  CLUB HOUSE", (236, 232, 222), (30, 30, 34))
    fit.wall_lamp(s, -113.0, 9.6, CLUB[1] - 0.3, 0, color=fit.WARM, range_=20, brightness=1.0)
    # Tatekan along the front, each with its brush lettering.
    for x, text, colour in ((-144.0, "軽音楽部\n部員募集中!!", (30, 30, 34)), (-135.0, "映画研究会\n冬の上映会", (150, 24, 30)),
                            (-101.0, "がんばれ\n受験生!!", (150, 24, 30))):
        s.prop("Tatekan", x, 55.6, 0)
        s.sign((x, 4.4, 55.45), 0, 5.2, 6.4, text, "GothamBlack", colour, None)
    for x in (-126.0, -124.0):
        s.prop("Bicycle", x, 55.0, 0)
    s.prop("BikeRack", -110.0, 55.0, 0)


def club_rooms(s):
    for r, mat in ((P.CLUB_ENTRY, "Concrete"), (P.CLUB_CORRIDOR, "ConcreteDark"), (P.NEWSROOM, "CarpetGrey"),
                   (P.FILM_CLUB, "CarpetRed"), (P.KOTATSU, "WoodFloor"), (P.BAND_ROOM, "WoodFloorDark"),
                   (P.LOCKER_ROOM, "TileMetroGrey")):
        fit.floor_faces(s, P.rect_of(r), 0.0, mat)
    ceiling(s, (KX0, KZ0, KX1, KZ1))
    fit.partition(s, (KX0, 71.0), (KX1, 71.0), 0.0, C, "PlasterGrey", "PlasterGrey",
                  doors=[(-138.0 - KX0, 4.4), (-118.0 - KX0, 8.0), (-99.0 - KX0, 4.4)], glass="clear",
                  spans=[(0.8, 7.6), (13.6, 19.8)])
    fit.partition(s, (-128.0, KZ0), (-128.0, 70.7), 0.0, C, "PlasterGrey", "PlasterGrey")
    fit.partition(s, (-108.0, KZ0), (-108.0, 70.7), 0.0, C, "PlasterGrey", "PlasterGrey")
    fit.partition(s, (KX0, 77.0), (KX1, 77.0), 0.0, C, "PlasterGrey", "PlasterGrey",
                  doors=[(-139.0 - KX0, 4.4), (-119.0 - KX0, 4.4), (-99.0 - KX0, 4.4)])
    fit.partition(s, (-129.0, 77.3), (-129.0, KZ1), 0.0, C, "PlasterGrey", "PlasterGrey")
    fit.partition(s, (-109.0, 77.3), (-109.0, KZ1), 0.0, C, "PlasterGrey", "PlasterGrey")
    for r, name in ((P.CLUB_ENTRY, "the club house"), (P.CLUB_CORRIDOR, "the club house"), (P.NEWSROOM, "the newsroom"),
                    (P.FILM_CLUB, "the film club"), (P.KOTATSU, "the kotatsu room"), (P.BAND_ROOM, "the band room"),
                    (P.LOCKER_ROOM, "the locker room")):
        s.zone("interior", P.rect_of(r), 0.0, name=name)
    s.look_zone("UniversityCampus_Inside", (KX0, 0.0, KZ0), (KX1, C, KZ1))
    # The entrance and the corridor.
    s.prop("ShoeLockers", -126.2, 64.7, -90)
    s.prop("UmbrellaStand", -110.0, 61.0, 0)
    s.prop("PinBoard", -108.44, 64.7, 90, 1.0, 6.0)
    # Club posters along the corridor: on its north wall (facing south) and its south wall.
    for x, y, rot, w, h, mat in ((-133.0, 6.4, 180, 2.0, 2.8, "RedTrim"), (-124.0, 6.2, 180, 2.2, 3.0, "PaintYellow"),
                                 (-94.0, 6.4, 180, 2.2, 3.0, "WhiteTrim"), (-146.0, 6.0, 0, 2.2, 3.0, "PaintYellow"),
                                 (-132.0, 6.2, 0, 2.4, 3.2, "WhiteTrim"), (-113.0, 6.0, 0, 2.0, 2.6, "RedTrim"),
                                 (-104.0, 6.4, 0, 2.2, 3.0, "PaintYellow")):
        poster(s, x, y, 71.3 if rot == 180 else 76.7, rot, w, h, mat)
    s.hood(-146.4, 74.0)
    for x in (-140.0, -118.0, -98.0):
        kit.tube_light(s, x, C, 74.0, length=6.0, range_=16, brightness=0.6)
    fit.exit_sign(s, KX1 - 0.3, 10.0, 74.0, 90)


def newsroom(s):
    s.station("Phone", "Student Newspaper Phone", -138.0, 62.8, 180, prop="StationNewsDesk")
    top = fit.table(s, -133.0, 61.6, 5.0, 2.4, 0, 0.0)
    s.prop("Typewriter", -133.5, 61.6, 180, 1.0, top)
    s.prop("PinBoard", -128.44, 66.5, 90, 1.0, 6.6)
    s.prop("FilingCabinet", -130.4, 67.9, 90)
    kit.pendant(s, -138.0, C, 64.7, drop=3.5, shade="BlackMetal", color=fit.WARM, range_=16, brightness=0.9, wide=0.9)
    s.sound("mapNewsRadio", (-131.0, 3.0, 62.0), 20.0, 0.3)
    fit.plaque(s, -138.0, 10.2, 71.3, 180, 4.4, 0.8, "新聞部  NEWSPAPER")


def film_club(s):
    s.prop("FilmProjector", -104.5, 64.7, -90)
    s.box("BlackMetal", (KX1 - 0.25, 6.5, 64.7), (0.3, 5.1, 8.6))
    s.screen((KX1 - 0.45, 6.5, 64.7), 90, 8.0, 4.5, "film")
    for z in (62.2, 67.2):
        s.prop("Chair", -98.5, z, -90)
    poster(s, -106.0, 7.0, 70.7, 180, 2.4, 3.4, "RedTrim")
    s.light("point", (-96.0, 6.0, 64.7), (200, 210, 255), 12, 0.5)
    fit.plaque(s, -99.0, 10.2, 71.3, 180, 4.4, 0.8, "映画研究会  FILM CLUB")


def kotatsu_room(s):
    s.polygon("FabricRed", [(-146.0, 0.08, 100.0), (-132.0, 0.08, 100.0), (-132.0, 0.08, 88.0), (-146.0, 0.08, 88.0)])
    s.prop("Kotatsu", -139.0, 94.0, 0)
    s.collider((-139.0, 0.625, 94.0), (3.5, 1.25, 3.5), 0, True, "Wood")
    s.sheet(-139.6, 1.3, 93.4)
    s.prop("Sofa", -147.0, 102.0, -90)
    s.prop("KeroseneHeater", -146.4, 80.0, 0)
    for z in (84.0, 87.4):
        s.prop("Bookshelf", -130.2, z, 90)
    s.box("BlackMetal", (-139.0, 1.2, 107.6), (4.0, 2.4, 1.6), collide=True)
    s.box("CreamTrim", (-139.0, 3.6, 107.4), (3.0, 2.4, 2.0))
    s.screen((-139.0, 3.6, 106.35), 0, 2.4, 1.8, "news")
    kit.pendant(s, -139.0, C, 94.0, drop=4.5, shade="Brass", color=fit.WARM, range_=18, brightness=1.0, wide=1.0)
    fit.plaque(s, -139.0, 10.2, 76.7, 0, 4.4, 0.8, "囲碁将棋部  GO CLUB")


def band_room(s):
    s.prop("DrumKit", -119.0, 101.0, 0)
    s.prop("UprightPiano", -126.4, 86.0, -90)
    for x in (-113.0, -124.0):
        s.box("BlackMetal", (x, 1.4, 106.8), (2.4, 2.8, 1.6), collide=True)
        s.box("Fabric", (x, 1.5, 105.98), (2.0, 2.0, 0.04))
    s.prop("Sofa", -113.4, 80.2, 180)
    poster(s, -110.6, 7.0, 95.0, 90, 3.0, 4.0, "PaintYellow")
    kit.pendant(s, -119.0, C, 92.0, drop=4.0, shade="BlackMetal", color=fit.WARM, range_=18, brightness=0.9, wide=1.0)
    fit.panel(s, -119.0, 82.0, C, brightness=0.7, range_=16)
    s.sound("mapPianoFar", (-124.0, 4.0, 88.0), 34.0, 0.35)
    fit.plaque(s, -119.0, 10.2, 76.7, 0, 4.4, 0.8, "軽音楽部  BAND ROOM")


def locker_room(s):
    for z in (82.0, 88.2, 94.4):
        s.prop("CoinLockers", KX1 - 1.4, z, 90)
    for z in (88.0, 94.2):
        s.prop("CoinLockers", -107.6, z, -90)
    s.prop("Bench", -99.0, 91.0, 90)
    s.station("Fingerprint", "Club Locker Prints", -99.0, 106.3, 0, prop="StationPrintKit", spare=True)
    for z in (84.0, 98.0):
        kit.tube_light(s, -99.0, C, z, length=6.0, rot=90, range_=16, brightness=0.6)
    fit.plaque(s, -99.0, 10.2, 76.7, 0, 4.4, 0.8, "更衣室  LOCKERS")


# The cafeteria -------------------------------------------------------------------------------------------------

TABLES = [(-68.0, 66.0), (-68.0, 74.0), (-68.0, 82.0), (-68.0, 90.0), (-52.0, 66.0), (-52.0, 74.0)]


def cafeteria(s):
    masonry.shell(s, CAF, P.EAVES["cafeteria"], P.DOORS["cafeteria"], brick="FacadeTile", inside="PlasterLight",
                  storeys=[0.0], arch=None, window_w=6.0, spacing=8.0, trim="ConcreteDark", cornice=False, seed=13)
    masonry.flat_roof(s, CAF, P.EAVES["cafeteria"])
    fit.plaque(s, -60.0, 11.4, CAF[1] - 0.05, 0, 8.0, 1.2, "学生食堂  CAFETERIA", (236, 232, 222), (120, 40, 30))
    fit.wall_lamp(s, -54.0, 9.6, CAF[1] - 0.3, 0, color=fit.WARM, range_=20, brightness=1.0)
    fit.floor_faces(s, P.rect_of(P.DINING), 0.0, "TileChecker")
    fit.floor_faces(s, P.rect_of(P.KITCHEN), 0.0, "TileWhite")
    ceiling(s, (FX0, FZ0, FX1, FZ1))
    s.zone("interior", P.rect_of(P.DINING), 0.0, name="the cafeteria")
    s.look_zone("UniversityCampus_Inside", (FX0, 0.0, FZ0), (FX1, C, FZ1))
    # The serving counter closes off the kitchen.
    fit.counter(s, (FX0 + FX1) / 2, 97.2, 0, FX1 - FX0, d=2.4, h=3.5, top="Steel", body="WhiteTrim")
    s.prop("TrayReturn", -73.0, 94.8, 0)
    s.prop("RecycleBins", -62.0, 95.2, 0)
    s.prop("MealTicketMachine", -68.0, 60.5, 180)
    s.prop("MealTicketMachine", -52.0, 60.5, 180)
    s.prop("UmbrellaStand", -65.0, 61.0, 0)
    s.prop("DrinkFridge", FX0 + 1.5, 72.0, -90)
    s.station("Phone", "Cafeteria Payphone", -43.1, 88.0, 90, prop="StationPublicPhone")
    for x, z in TABLES:
        top = fit.table(s, x, z, 12.0, 3.0, 0, 0.0, top="WhiteTrim", legs="Steel")
        fit.chairs_round(s, x, z, 12.0, 3.0, 0)
    s.sheet(-66.0, 2.8, 82.0)
    # The kitchen, seen over the counter: ranges, pots, the rice cooker, the menu.
    for x in (-72.0, -60.0, -48.0):
        s.box("BlackMetal", (x, 1.7, 104.0), (8.0, 3.4, 4.0), collide=True, mats={"+y": "Steel"})
        s.cylinder("Steel", (x - 1.5, 3.4, 104.0), 1.1, 1.6, 12)
        s.box("Steel", (x, 11.0, 104.0), (8.4, 1.4, 4.4))
    for k, text in enumerate(("カレーライス  ¥380", "日替わり定食  ¥450", "きつねうどん  ¥280")):
        s.sign((-72.0 + k * 12.0, 7.8, FZ1 - 0.3), 0, 10.0, 1.4, text, "GothamBold", (255, 236, 200), (60, 30, 20),
               (255, 200, 140))
    for x, z in ((-68.0, 70.0), (-52.0, 70.0), (-68.0, 86.0), (-52.0, 86.0)):
        fit.panel(s, x, z, C, brightness=0.85, range_=20)
    for x in (-66.0, -54.0):
        fit.panel(s, x, 103.0, C, color=fit.COOL, brightness=0.7, range_=16)
    s.sound("mapHeaterHum", (-60.0, 3.0, 100.0), 18.0, 0.15)


def alley(s):
    """The club house's vending machines in the alley, the drop point behind them."""
    s.prop("RecycleBins", -86.2, 85.5, -90)
    s.prop("VendingBlue", -86.4, 90.2, -90)
    s.prop("VendingWhite", -86.4, 94.6, -90)
    s.prop("VendingMachine", -86.6, 99.0, -90)
    s.drop_point("behind the club house vending machines", -86.6, 105.4)
    fit.wall_lamp(s, -87.7, 9.4, 96.0, -90, color=fit.WARM, range_=18, brightness=0.9)
    s.sound("mapCityHum", (-84.0, 6.0, 104.0), 40.0, 0.2)


def build(s, g):
    del g
    club_exterior(s)
    club_rooms(s)
    newsroom(s)
    film_club(s)
    kotatsu_room(s)
    band_room(s)
    locker_room(s)
    cafeteria(s)
    alley(s)
