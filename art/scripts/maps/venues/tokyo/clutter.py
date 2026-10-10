"""The second pass's dressing for Tokyo's rooms that read empty: the karaoke box (a lounge, a promo
screen between speakers and a costume rack downstairs; a lyric screen over each room's door, a
mirror ball, song books and drinks upstairs), the konbini's third shelf row, magazine rack and ATM,
the department store's cosmetics counters, fitting rooms and racks, the clinic's cooler and plant,
and the station hall's machines, benches and kiosk.

Every placement keeps the doorways (check_v2's doorway check), the stations' worker sides and the
walking lanes clear."""

from maps.venues.tokyo import interiors as I

UP, CEIL = I.UP, I.CEIL
ROOM_TOP = UP + CEIL - 1.0  # the first floor's ceiling


def karaoke(s):
    # Downstairs: a lounge by the windows (a second sofa facing the first over a low table), the promo
    # screen on the west wall between two speakers over the console, a rack of costumes for hire.
    s.prop("Sofa", 86.0, 77.6, 0)
    top = I.table(s, 86.0, 73.3, 5.0, 2.4, 0)
    s.prop("DrinksTray", 85.0, 73.2, 20, 1.0, top)
    s.prop("SongBook", 87.6, 73.6, -10, 1.0, top)
    s.screen((79.6, 7.2, 75.0), -90, 6.0, 3.4, "karaoke")
    s.prop("KaraokeConsole", 80.4, 75.0, -90)
    for z in (71.0, 79.0):
        s.prop("KaraokeSpeaker", 80.0, z, -90)
    s.prop("ClothesRack", 103.0, 90.6, 90)
    s.sign((105.4, 9.0, 90.6), 90, 5.0, 1.0, "コスプレ貸出  COSTUMES", "GothamBlack", (255, 220, 240), (120, 20, 90),
           glow=(255, 120, 200))
    s.prop("Plant", 104.4, 67.6, 0)
    # Upstairs: each room's lyric screen over its door, a mirror ball, the table's song book, tambourine
    # and drinks, a mic on its stand by the sofa.
    for z, door_z in ((69.0, 70.3), (77.0, 77.0)):
        s.screen((86.45, UP + 10.2, door_z), -90, 4.0, 2.2, "karaoke")
        s.prop("MirrorBall", 96.0, z, 0, 1.0, ROOM_TOP - 1.7)
        top = UP + 2.8
        s.prop("SongBook", 95.4, z - 0.6, 15, 1.0, top)
        s.prop("Tambourine", 97.0, z + 0.8, 0, 1.0, top)
        s.prop("DrinksTray", 96.6, z - 0.2, -10, 1.0, top)
        s.prop("MicStand", 91.5, z - 1.8, -90, 1.0, UP)
        s.light("spot", (96.0, ROOM_TOP - 3.6, z), (255, 120, 220), 16, 0.8, False, "Bottom", 70)


def konbini(s):
    s.prop("StoreShelf", 38.0, -29.8, 90)
    s.prop("MagazineRack", 27.0, -44.7, 180)
    s.prop("ATM", 21.0, -38.0, -95)  # square to the slanted west wall


def dept_store(s):
    # Ground floor (the store is a wedge: its north and south walls slant): two cosmetics counters with
    # their backs to those walls, each clear of that wall's door (the south one east of the street door,
    # off the escalators' flank), a mannequin by the tip.
    s.prop("CosmeticsCounter", 40.5, -66.0, -7)
    s.prop("CosmeticsCounter", 34.0, -89.8, 170)
    s.prop("Mannequin", -7.6, -77.0, -90)
    # First floor: two fitting rooms against the north wall west of the escalators' well, a rack and a
    # mannequin.
    for x in (2.0, 6.2):
        s.prop("FittingRoom", x, -71.3 + (x - 2.0) * 0.115, -7, 1.0, UP)
    s.prop("ClothesRack", 30.0, -67.0, 180, 1.0, UP)
    s.prop("Mannequin", 31.0, -90.5, 0, 1.0, UP)


def clinic(s):
    s.prop("WaterCooler", 49.9, -86.0, -90, 1.0, UP)
    s.prop("Plant", 75.2, -81.4, 0, 1.0, UP)
    s.sign((49.0 + 0.3, UP + 9.0, -88.0), -90, 4.0, 0.9, "診察室  EXAM ROOM", "GothamBold", (40, 60, 80), (230, 240, 244))


def station_hall(s):
    # The west wall: drinks machines and their bins; benches either side of the stairs down; a news kiosk
    # in the south-west corner.
    s.prop("VendingBlue", -149.0, -78.0, -90)
    s.prop("VendingWhite", -149.0, -73.5, -90)
    s.prop("RecycleBins", -149.8, -69.6, -90)
    for x in (-136.0, -128.0):
        s.prop("PlatformBench", x, -86.0, 0)
        s.prop("PlatformBench", x, -44.0, 180)
    s.prop("ShopCounter", -146.5, -100.0, -90)


def build(s):
    karaoke(s)
    konbini(s)
    dept_store(s)
    clinic(s)
    station_hall(s)
