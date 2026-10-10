"""The second pass's dressing for Tokyo's rooms that read empty: the karaoke box (a lounge, a promo
screen between speakers and a costume rack downstairs; a lyric screen over each room's door, a
mirror ball, song books and drinks upstairs), the konbini's third shelf row, magazine rack and ATM,
the department store's cosmetics counters, fitting rooms and racks, the clinic's cooler and plant,
the station hall's machines, benches and kiosk, the police box's chairs, cabinets and notices, and
the drugstore's display counter and waiting chairs.

Every placement keeps the doorways (check_v2's doorway check), the stations' worker sides and the
walking lanes clear."""

from maps import geo2d as g2
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


def koban(s):
    """The police box was a counter and a table in a bare room. It is a small one (14 by 10.5 inside
    its walls: u from -7 to 7 along the front, 1 to 11 deep), and the door, the table and the sight
    lines to the print kit leave the floor no room for more than a filing cabinet in the back corner:
    the rest goes on the walls, a board of wanted notices under its sign on the east one, the duty
    roster on the west."""
    b = I.building("koban")
    e = I.edges_of(b["poly"])[I.edge_towards(b["poly"], (0.46, -0.89))]
    along, back = g2.rot_of((-e.n[0], -e.n[1])), g2.rot_of(e.n)

    def local(u, depth):
        return e.at(e.length / 2 + u, -depth)

    s.prop("FilingCabinet", *local(-5.9, 9.7), along)
    x, z = local(6.84, 5.25)
    s.prop("PinBoard", x, z, back, 1.0, 6.4)
    x, z = local(6.9, 5.25)
    s.sign((x, 9.3, z), back, 5.0, 0.9, "指名手配  WANTED", "GothamBlack", (250, 240, 230), (150, 24, 30))
    x, z = local(-6.84, 6.3)
    s.prop("PinBoard", x, z, along, 1.0, 6.4)
    x, z = local(-6.9, 6.3)
    s.sign((x, 9.3, z), along, 5.0, 0.9, "勤務表  DUTY ROSTER", "GothamBold", (230, 236, 244), (30, 60, 140))


def drugstore(s):
    """One shelf in a 30-stud shop: a display counter along the stair's flank (4 studs of aisle to the
    shelf), chairs and a water cooler for those waiting on the dispensary, a plant in the corner."""
    s.prop("DisplayCase", 62.0, -85.7, 180)
    for z in (-93.0, -90.8):
        s.prop("Chair", 75.6, z, 90)
    s.prop("WaterCooler", 75.9, -88.4, 90)
    s.prop("Plant", 50.4, -92.4, 0, 0.9)


def build(s):
    karaoke(s)
    konbini(s)
    dept_store(s)
    clinic(s)
    station_hall(s)
    koban(s)
    drugstore(s)
