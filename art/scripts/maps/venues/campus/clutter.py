"""The second pass's dressing for the campus rooms that read empty: the science corridor's notice
boards, benches and founder's bust; lab benches, fume hoods and shelves in the labs; more shelves
and a reading table in the rare books room; the Law hall's notices and bench; the seminar room's
lectern; the band's mics and monitors; the kotatsu room's TV, shoe lockers and lamp; the film club's
second row; the newsroom's shelves and pin board; the foyer's queue posts; the guard's desk; the
vestibule's bench; posters along the club corridor.

Every placement keeps the doorways, the stations' worker sides and the walking lanes clear."""

from maps.venues.campus import fit
from maps.venues.campus import plan as P

GY = P.GALLERY_Y


def science(s):
    # The corridor: notices between the doors, a bench by the forensic lab, a water cooler, the
    # founder's bust at the far end.
    for z in (48.0, 84.0):
        s.prop("NoticeBoard", 50.2, z, -90)
    s.prop("Bench", 67.0, 45.0, 90)
    s.prop("WaterCooler", 66.9, 64.0, 90)
    s.prop("BustStatue", 58.0, 106.4, 180)
    s.prop("Plant", 65.4, 104.6, 0)
    # The forensic lab: two fume hoods on the south wall, a second microscope table, a whiteboard.
    for x in (80.0, 96.0):
        s.prop("FumeHood", x, 38.9, 180)
    top = fit.table(s, 76.0, 56.0, 6.0, 2.6, 0)
    s.prop("Microscope", 75.0, 56.2, 180, 1.0, top)
    s.prop("Typewriter", 77.4, 56.0, 180, 1.0, top)
    s.prop("OfficeChair", 75.0, 58.6, 180)
    s.prop("Whiteboard", 106.4, 61.2, -90)
    # The chemistry lab: specimen shelves on the north wall, a whiteboard by the door.
    for x in (116.0, 122.0, 128.0):
        s.prop("SpecimenShelf", x, 71.0, 0)
    s.prop("Whiteboard", 109.6, 66.0, 90)


def library(s):
    # The rare books room: shelves along the north wall's east end, a reading table with a lamp.
    for x in (131.0, 134.4, 137.8, 141.2):
        s.prop("Bookshelf", x, -107.6, 180, 1.0, GY)
    s.prop("ReadingTable", 112.0, -93.0, 0, 1.0, GY)
    s.collider((112.0, GY + 1.4, -93.0), (10.0, 2.8, 4.0), 0, True, "WoodFloor")
    fit.chairs_round(s, 112.0, -93.0, 10.0, 4.0, 0, GY)


def law(s):
    s.prop("NoticeBoard", -97.2, -78.0, -90)
    s.prop("Bench", -96.8, -100.0, -90)
    s.prop("BustStatue", -90.6, -106.6, 0)
    # The seminar room: a lectern at the chalkboard, a coat stand by the door.
    s.prop("Lectern", -145.0, -86.0, -90)
    s.prop("CoatStand", -123.4, -85.4, 0)


def clubs(s):
    # The band room: two vocal mics in front of the drums, a monitor speaker either side.
    for x in (-123.0, -115.0):
        s.prop("MicStand", x, 94.0, 0)
    for x in (-127.4, -110.8):
        s.prop("KaraokeSpeaker", x, 98.0, 180)
    # The kotatsu room: a TV on the north wall, shoe lockers by the door, a floor lamp in the corner.
    s.screen((-139.0, 6.5, 108.3), 0, 5.0, 3.0, "news")
    s.box("BlackTrim", (-139.0, 6.5, 108.45), (5.4, 3.4, 0.2))
    s.prop("ShoeLockers", -133.4, 78.6, 180)
    s.prop("FloorLamp", -147.2, 107.2, 0)
    # The film club: a second row of chairs behind the first.
    for z in (62.2, 64.7):
        s.prop("Chair", -99.6, z, -90)
    s.sign((-107.7, 7.0, 64.7), -90, 3.2, 4.4, "冬の上映会\nWINTER SCREENING", "GothamBlack", (240, 230, 210), (90, 20, 30))
    # The newsroom: a bookshelf of back issues, the pin board of leads, a bundle of papers.
    s.prop("Bookshelf", -147.7, 66.0, -90)
    s.prop("PinBoard", -144.0, 70.5, 0, 1.0, 6.5)
    s.prop("Crate", -129.6, 64.6, 0, 0.5)
    # The club corridor: posters on its north wall (only posters: it is 6 wide).
    for x, text, colour in ((-142.0, "囲碁部\nGO CLUB", (30, 30, 34)), (-122.0, "写真部\nPHOTO CLUB", (40, 70, 120)),
                            (-104.0, "軽音楽部\nLIVE 12/24", (150, 24, 30))):
        s.sign((x, 6.5, 76.65), 0, 3.0, 3.6, text, "GothamBlack", (240, 236, 226), colour)


def foyer(s):
    # Queue posts guiding the candidates to the halls' doors, a plant by the exam office.
    for x in (-26.0, -14.0):
        s.prop("QueuePosts", x, -71.0, 90)
    # The vestibule: a bench along its west wall.
    s.prop("Bench", -27.4, -56.0, -90)


def booth(s):
    s.prop("FilingCabinet", 15.2, 105.3, 90)


def build(s):
    science(s)
    library(s)
    law(s)
    clubs(s)
    foyer(s)
    booth(s)
