"""The two faculties.

Law & Letters (法文館), dark brick with pointed windows and a hipped roof:
- The arcade along its east face leads into its long entrance hall. The stair up is roped off.
- Student affairs lies behind service windows. Tomorrow's sealed exam papers wait there in the
  Exam Paper Vault.
- The seminar room has its chalkboard; the professor's office is lined with books.

The Faculty of Science (理学部), red brick with round-arched windows:
- Its hall runs north to south. Its stair is roped off; the back corridor has a hood.
- The forensic medicine lab (the Forensic Medicine Lab's autopsy table) has glass onto the hall.
- The chemistry lab lies beyond it, with the spare Chemistry Lab Bench, fume hoods and benches
  (a sheet on one).
- The specimen room is lined with jars; the lecture room is shut."""

from maps import kit
from maps.venues.campus import fit, masonry
from maps.venues.campus import plan as P

C = P.CEIL


def ceiling(s, r, mat="Ceiling"):
    x0, z0, x1, z1 = r
    fit.ceiling_faces(s, P.box(x0, z0, x1, z1), C, mat)
    s.collider(((x0 + x1) / 2, C + 0.5, (z0 + z1) / 2), (x1 - x0, 1.0, z1 - z0), 0, True, None)


def closed_stair(s, g, x, z_foot, z_top, width=5.0, landing_z=None, mat="Stone", side="WoodPanel"):
    """A stair up to the storeys nobody visits: it climbs from z_foot to z_top (reaching 11), a
    landing block beyond it against the wall, its foot roped off."""
    fit.stairs(s, g, (x, z_foot), (x, z_top), 0.0, 11.0, width, mat, side, step=0.7)
    if landing_z is not None:
        z0, z1 = sorted((z_top, landing_z))
        s.box(mat, (x, 5.5, (z0 + z1) / 2), (width, 11.0, z1 - z0), collide=True, mats={"+y": mat})
    dz = 0.4 if z_top < z_foot else -0.4
    fit.roped_off(s, (x - width / 2, z_foot + dz), (x + width / 2, z_foot + dz))


# Law & Letters ------------------------------------------------------------------------------------------

LAW = P.LAW
LX0, LZ0, LX1, LZ1 = P.inner(LAW)  # -148.6, -108.6, -83.4, -51.4


def law_exterior(s):
    masonry.shell(s, LAW, P.EAVES["law"], P.DOORS["law"], brick="BrickDark", storeys=[0.0, P.GF, P.GF + P.UP],
                  seed=6)
    masonry.hip_roof(s, LAW, P.EAVES["law"], 10.0)
    masonry.arcade(s, P.ARCADE, h=12.0, brick="BrickDark")
    fit.plaque(s, LAW[2] + 0.05, 10.8, -80.0, -90, 7.0, 1.2, "法文館  LAW & LETTERS", (236, 214, 150), (26, 20, 18),
               font="Garamond")
    fit.wall_lamp(s, -95.0, 9.8, LAW[3] + 0.3, 180, color=fit.WARM, range_=20, brightness=1.0)


def law_rooms(s, g):
    for r, mat in ((P.LAW_HALL, "Stone"), (P.AFFAIRS, "WoodFloor"), (P.SEMINAR, "CarpetRed"),
                   (P.PROFESSOR, "WoodFloorDark")):
        fit.floor_faces(s, P.rect_of(r), 0.0, mat)
    ceiling(s, (LX0, LZ0, LX1, LZ1))
    fit.partition(s, (-98.0, LZ0), (-98.0, LZ1), 0.0, C, "PlasterLight", "PlasterLight",
                  doors=[(-90.0 - LZ0, 4.4), (-66.0 - LZ0, 5.0)], glass="clear", spans=[(30.0, 39.3), (45.9, 56.4)])
    fit.partition(s, (LX0, -80.0), (-98.0, -80.0), 0.0, C, "PlasterLight", "PlasterLight", doors=[(-126.0 - LX0, 4.4)])
    fit.partition(s, (-122.0, LZ0), (-122.0, -80.3), 0.0, C, "WoodPanel", "PlasterLight")
    for r, name in ((P.LAW_HALL, "Law & Letters"), (P.AFFAIRS, "student affairs"), (P.SEMINAR, "the seminar room"),
                    (P.PROFESSOR, "the professor's office")):
        s.zone("interior", P.rect_of(r), 0.0, name=name)
    s.look_zone("UniversityCampus_Inside", (LX0, 0.0, LZ0), (LX1, C, LZ1))
    # The hall: the roped-off stair along its outer wall, benches, the faculty's notices.
    closed_stair(s, g, -85.9, -84.0, -100.0, landing_z=LZ0)
    s.prop("Bench", -97.0 + 1.0, -58.0, -90)
    s.prop("DisplayCase", -97.0 + 1.3, -73.0, -90)
    s.prop("UmbrellaStand", -85.0, -53.0, 0)
    s.prop("Plant", -85.2, -76.0, 0)
    for z in (-60.0, -76.0, -92.0):
        kit.pendant(s, -91.0, C, z, drop=3.0, shade="Brass", color=fit.WARM, range_=20, brightness=1.0, wide=1.1)
    fit.plaque(s, -97.7, 10.2, -60.0, -90, 5.4, 0.9, "学務課  STUDENT AFFAIRS")


def affairs(s):
    s.station("Fingerprint", "Exam Paper Vault", -140.0, -77.2, 180, prop="StationVault")
    for x, z in ((-126.0, -70.0), (-114.0, -70.0), (-126.0, -59.5), (-114.0, -59.5)):
        fit.desk(s, x, z, 0, lamp=x == -126.0)
    for x in (-146.2, -143.7):
        s.prop("FilingCabinet", x, -52.6, 0)
    s.prop("Photocopier", -104.0, -53.0, 0)
    s.prop("Whiteboard", -147.5, -62.0, -90)
    s.prop("KeroseneHeater", -106.0, -76.0, 0)
    s.prop("CoatStand", -101.0, -78.0, 0)
    for z in (-73.5, -71.0):
        s.prop("Crate", -146.6, z, 12 * (z > -72), 0.6)
    for x, z in ((-120.0, -66.0), (-130.0, -55.0)):
        fit.panel(s, x, z, C, brightness=0.85, range_=20)
    fit.panel(s, -106.0, -60.0, C, on=False)
    s.sound("mapHeaterHum", (-106.0, 2.0, -76.0), 14.0, 0.2)


def seminar(s):
    top = fit.table(s, -135.0, -94.0, 14.0, 4.0, 0, 0.0)
    fit.chairs_round(s, -135.0, -94.0, 14.0, 4.0, 0)
    s.sheet(-136.0, top, -94.0, spare=True)
    # The chalkboard on the west wall, today's lecture still on it.
    s.box("WoodPanel", (LX0 + 0.3, 7.0, -94.0), (0.4, 6.0, 16.0))
    s.box("BlackTrim", (LX0 + 0.52, 7.0, -94.0), (0.06, 5.2, 15.0))
    s.sign((LX0 + 0.6, 8.2, -94.0), -90, 13.0, 1.6, "刑法 第三十八条  罪を犯す意思", "GothamBold", (224, 224, 214), None)
    s.sign((LX0 + 0.6, 6.2, -94.0), -90, 13.0, 1.2, "INTENT  →  MOTIVE  →  OPPORTUNITY", "GothamBold", (200, 200, 190),
           None)
    for z in (-104.0, -100.6):
        s.prop("Bookshelf", -123.2, z, 90)
    for x in (-132.0, -138.0):
        kit.pendant(s, x, C, -94.0, drop=3.5, shade="BlackMetal", color=fit.WARM, range_=18, brightness=0.9, wide=1.0)


def professor(s):
    s.prop("ExecutiveDesk", -110.0, -101.0, 180)
    s.prop("OfficeChair", -110.0, -104.2, 180)
    s.light("point", (-107.8, 4.2, -101.2), fit.LAMP, 14, 0.9)
    for x in (-119.4, -116.0, -104.0, -100.6):
        s.prop("Bookshelf", x, -107.6, 180)
    s.prop("Sofa", -110.0, -83.0, 0)
    s.prop("CoatStand", -100.0, -83.0, 0)
    s.prop("KeroseneHeater", -119.8, -86.0, 0)
    kit.pendant(s, -110.0, C, -94.0, drop=3.5, shade="Brass", color=fit.WARM, range_=18, brightness=0.8, wide=1.0)


# The Faculty of Science --------------------------------------------------------------------------------

SCI = P.SCIENCE
SX0, SZ0, SX1, SZ1 = P.inner(SCI)  # 49.4, 37.4, 148.6, 108.6


def science_exterior(s):
    masonry.shell(s, SCI, P.EAVES["science"], P.DOORS["science"], brick="BrickRed", storeys=[0.0, P.GF, P.GF + P.UP],
                  arch="round", seed=7)
    masonry.hip_roof(s, SCI, P.EAVES["science"], 10.0)
    fit.plaque(s, 58.0, 13.0, SCI[1] - 0.05, 0, 8.0, 1.2, "理学部  FACULTY OF SCIENCE", (236, 214, 150), (26, 20, 18),
               font="Garamond")
    fit.wall_lamp(s, 63.0, 9.8, SCI[1] - 0.3, 0, color=fit.WARM, range_=20, brightness=1.0)
    fit.wall_lamp(s, SCI[0] - 0.3, 9.8, 78.0, 90, color=fit.WARM, range_=20, brightness=1.0)


def science_rooms(s, g):
    for r, mat in ((P.SCI_HALL, "TileMetroGrey"), (P.FORENSIC, "TileWhite"), (P.CHEMISTRY, "TileWhite"),
                   (P.SPECIMENS, "WoodFloorDark"), (P.LECTURE_ROOM, "WoodFloor")):
        fit.floor_faces(s, P.rect_of(r), 0.0, mat)
    ceiling(s, (SX0, SZ0, SX1, SZ1))
    fit.partition(s, (68.0, SZ0), (68.0, SZ1), 0.0, C, "TileWhite", "PlasterLight",
                  doors=[(55.0 - SZ0, 5.0), (90.0 - SZ0, 4.4)], glass="clear", spans=[(2.0, 14.3), (20.9, 33.8)])
    fit.partition(s, (68.0, 72.0), (SX1, 72.0), 0.0, C, "TileWhite", "PlasterLight", doors=[(88.0 - 68.0, 4.4)])
    fit.partition(s, (108.0, SZ0), (108.0, 71.7), 0.0, C, "TileWhite", "TileWhite", doors=[(55.0 - SZ0, 4.4)])
    fit.partition(s, (108.0, 72.3), (108.0, SZ1), 0.0, C, "PlasterLight", "PlasterLight")
    fit.closed_door(s, 107.7, 90.0, 90, 0.0, 4.0, "WoodPanel", sign="講義室 LECTURE ROOM")
    for r, name in ((P.SCI_HALL, "the Faculty of Science"), (P.FORENSIC, "the forensic medicine lab"),
                    (P.CHEMISTRY, "the chemistry lab"), (P.SPECIMENS, "the specimen room")):
        s.zone("interior", P.rect_of(r), 0.0, name=name)
    s.look_zone("UniversityCampus_Inside", (SX0, 0.0, SZ0), (108.0, C, SZ1))
    s.look_zone("UniversityCampus_Inside", (108.0, 0.0, SZ0), (SX1, C, 72.0))
    # The hall: the roped-off stair at its south end, the back corridor's hood, a bench, notices.
    closed_stair(s, g, 52.2, 90.0, 104.0, landing_z=SZ1, mat="TileMetroGrey")
    s.hood(62.0, 104.0)
    s.prop("Bench", 50.4 + 0.9, 60.0, -90)
    s.prop("DisplayCase", 66.3, 80.0, 90)
    s.prop("Plant", 50.8, 40.0, 0)
    for z in (48.0, 66.0, 84.0, 100.0):
        fit.panel(s, 58.0, z, C, color=fit.COOL, brightness=0.75, range_=18, rot=90)
    fit.plaque(s, 67.7, 10.2, 46.0, 90, 5.8, 0.9, "法医学教室  FORENSIC MEDICINE", (240, 236, 226), (26, 40, 60))


def forensic(s):
    s.station("Forensics", "Forensic Medicine Lab", 88.0, 56.0, 0, prop="StationAutopsy")
    # The morgue fridge on the east wall: two rows of three steel doors.
    s.box("Steel", (106.4, 4.2, 44.0), (2.6, 8.4, 11.0), collide=True)
    for row in range(2):
        for col in range(3):
            z = 40.4 + col * 3.6
            y = 2.4 + row * 3.8
            s.box("DarkMetal", (105.05, y, z), (0.06, 3.2, 3.2))
            s.box("Steel", (104.95, y, z + 1.2), (0.12, 0.8, 0.2))
    s.box("BlackMetal", (100.0, 7.6, 71.6), (6.0, 3.6, 0.3))
    s.box("NeonCool", (100.0, 7.6, 71.42), (5.6, 3.2, 0.04))
    s.prop("SpecimenShelf", 76.0, 70.8, 0)
    s.prop("SkeletonModel", 72.0, 66.0, 150)
    top = fit.table(s, 99.0, 64.0, 6.0, 3.0, 0, 0.0, top="WhiteTrim", legs="Steel")
    s.prop("Microscope", 99.5, 64.0, 180, 1.0, top)
    s.prop("OfficeChair", 99.0, 61.4, 180)
    s.prop("FilingCabinet", 69.4, 40.0, -90)
    for x, z in ((80.0, 46.0), (96.0, 46.0), (88.0, 66.0)):
        fit.panel(s, x, z, C, color=fit.COOL, brightness=0.8, range_=20)
    fit.plaque(s, 107.7, 10.2, 62.0, 90, 5.0, 0.9, "化学実験室  CHEMISTRY", (240, 236, 226), (26, 40, 60))


def chemistry(s):
    s.station("Forensics", "Chemistry Lab Bench", 118.0, 39.9, 180, prop="StationLabBench", spare=True)
    for z in (44.0, 52.0, 60.0, 68.0):
        s.prop("FumeHood", 147.2, z, 90)
    tops = []
    for z in (51.0, 63.0):
        tops.append(fit.counter(s, 125.0, z, 0, 16.0, d=3.0, h=3.5, top="BlackTrim", body="WhiteTrim"))
    s.sheet(121.0, tops[1], 63.0)
    for x in (119.0, 131.0):
        s.prop("Microscope", x, 51.0, 180, 1.0, tops[0])
        for j in range(4):
            s.cylinder("Glass", (x + 2.0 + j * 0.45, tops[0], 51.4), 0.16, 0.8, 8)
    # A periodic table on the wall toward the specimen room.
    for k in range(18):
        for row in range(7):
            if row == 0 and 0 < k < 17 or row in (1, 2) and 1 < k < 12:
                continue
            s.box("PaintYellow" if (k + row) % 3 == 0 else "WhiteTrim", (116.0 + k * 0.9, 9.8 - row * 0.62, 71.62),
                  (0.8, 0.5, 0.05))
    # The safety shower and the eye wash by the door.
    s.tube("Steel", (110.0, 0.0, 70.8), (110.0, 9.0, 70.8), 0.12, 8)
    s.cylinder("PaintYellow", (110.0, 9.0, 70.0), 0.7, 0.3, 12)
    s.tube("PaintYellow", (110.0, 7.0, 70.4), (110.0, 5.6, 70.0), 0.04, 5)
    for x, z in ((118.0, 45.0), (132.0, 45.0), (125.0, 66.0), (141.0, 56.0)):
        fit.panel(s, x, z, C, color=fit.COOL, brightness=0.8, range_=20)


def specimens(s):
    for x in (74.0, 80.0, 86.0, 94.0, 100.0):
        s.prop("SpecimenShelf", x, 107.4, 0)
    s.prop("DisplayCase", 88.0, 90.0, 0)
    s.prop("DisplayCase", 88.0, 96.5, 180)
    s.prop("SkeletonModel", 104.0, 78.0, -120)
    top = fit.table(s, 76.0, 80.0, 6.0, 3.0, 90, 0.0)
    s.prop("Microscope", 76.0, 79.0, -90, 1.0, top)
    for x, z in ((80.0, 90.0), (98.0, 90.0), (88.0, 102.0), (88.0, 80.0)):
        fit.panel(s, x, z, C, color=fit.COOL, brightness=0.75, range_=18)


def build(s, g):
    law_exterior(s)
    law_rooms(s, g)
    affairs(s)
    seminar(s)
    professor(s)
    science_exterior(s)
    science_rooms(s, g)
    forensic(s)
    chemistry(s)
    specimens(s)
