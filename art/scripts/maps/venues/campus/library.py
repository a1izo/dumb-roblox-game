"""The General Library (総合図書館), open late in exam season.

- Its west door opens onto the circulation hall, where the Book Return Prints station stands at
  the return counter by the card catalogue.
- North of the hall is the microfilm room.
- East of it is the reading room, double height:
  - long oak tables under their green lamps, and tall windows onto the snow;
  - along its north side, a gallery at y 12, with a stair up each end wall;
  - off the gallery, behind clear glass, the rare books room with the Rare Books Ink Lab.
- Under the gallery and the rare books room lie the stacks: rows of shelves, a hood among them,
  and the back corner.

Stairs are solid underneath with guards on their rails; the gallery's edge has a railing with
its guard."""

from maps import city, kit
from maps.venues.campus import fit, masonry
from maps.venues.campus import plan as P

L = P.LIBRARY
X0, Z0, X1, Z1 = P.inner(L)  # 41.4, -108.6, 148.6, -41.4
C = P.CEIL
H = P.READING_H
GY = P.GALLERY_Y
SLAB = GY - 0.8  # the underside of the gallery and the rare books room's floor


def exterior(s):
    def pane(face, u, level):
        del level
        if face == "e":
            return "Glass"
        if face == "s" and u < 78.0:
            return "Glass"
        if face == "n" and u > 32.0:
            return "Glass"
        return None

    masonry.shell(s, L, P.EAVES["library"], P.DOORS["library"], brick="BrickRed", storeys=[0.0, P.GF], pane=pane,
                  seed=5)
    masonry.gable_roof(s, L, P.EAVES["library"], 12.0, gable="BrickRed", along_x=True)
    fit.plaque(s, L[0] - 0.05, 13.0, -52.0, 90, 9.0, 1.3, "総合図書館  GENERAL LIBRARY", (236, 214, 150), (26, 20, 18),
               font="Garamond")
    fit.plaque(s, 110.0, 13.0, L[3] + 0.05, 180, 7.0, 1.1, "閲覧室  READING ROOM", (236, 214, 150), (26, 20, 18),
               font="Garamond")
    fit.wall_lamp(s, L[0] - 0.3, 9.8, -48.0, 90, color=fit.WARM, range_=20, brightness=1.0)
    fit.wall_lamp(s, 104.5, 9.8, L[3] + 0.3, 180, color=fit.WARM, range_=20, brightness=1.0)


def rooms(s):
    """Floors, ceilings, the partitions and the gallery's slab."""
    fit.floor_faces(s, P.rect_of(P.CIRCULATION), 0.0, "MarbleWhite")
    fit.floor_faces(s, P.rect_of(P.MICROFILM), 0.0, "CarpetGrey")
    fit.floor_faces(s, P.rect_of(P.READING), 0.0, "WoodFloor")
    fit.floor_faces(s, P.rect_of(P.STACKS), 0.0, "WoodFloorDark")
    for r in (P.CIRCULATION, P.MICROFILM):
        fit.ceiling_faces(s, P.rect_of(r), C, "Ceiling")
    s.collider(((X0 + 72.0) / 2, C + 0.5, (Z0 + Z1) / 2), (72.0 - X0, 1.0, Z1 - Z0), 0, True, None)
    fit.ceiling_faces(s, P.box(72.0, Z0, X1, Z1), H, "Ceiling")
    s.collider(((72.0 + X1) / 2, H + 0.5, (Z0 + Z1) / 2), (X1 - 72.0, 1.0, Z1 - Z0), 0, True, None)
    # The slab of the gallery and the rare books room over the stacks, and its underside.
    upper = P.box(72.0, Z0, X1, P.GALLERY[3])
    city.floor(s, upper, GY, 0.8, "WoodFloorDark")
    fit.floor_faces(s, P.rect_of(P.GALLERY), GY, "WoodFloorDark")
    fit.floor_faces(s, P.rect_of(P.RARE_BOOKS), GY, "CarpetRed")
    fit.ceiling_faces(s, upper, SLAB, "Ceiling")
    city.vquad(s, "WoodPanel", (72.0, P.GALLERY[3]), (X1, P.GALLERY[3]), SLAB, GY, (0, 1))
    s.box("Wood", ((72.0 + X1) / 2, GY + 0.1, P.GALLERY[3] - 0.1), (X1 - 72.0, 0.2, 0.3))
    # Partitions: circulation | microfilm; the reading room's west wall; stacks | reading room;
    # rare books | gallery.
    fit.partition(s, (X0, -64.0), (72.0, -64.0), 0.0, C, "PlasterLight", "PlasterLight", doors=[(66.0 - X0, 4.4)])
    fit.partition(s, (72.0, Z0), (72.0, Z1), 0.0, H, "PlasterLight", "PlasterLight",
                  doors=[(-96.0 - Z0, 4.4), (-52.0 - Z0, 8.0)])
    fit.partition(s, (72.0, -84.0), (X1, -84.0), 0.0, SLAB, "WoodPanel", "WoodPanel",
                  doors=[(89.0 - 72.0, 4.4), (131.0 - 72.0, 4.4)])
    fit.partition(s, (72.0, -84.0), (X1, -84.0), GY, H, "PlasterLight", "WoodPanel", doors=[(110.0 - 72.0, 4.4)],
                  glass="clear")
    for r, name in ((P.CIRCULATION, "the circulation desk"), (P.MICROFILM, "the microfilm room"),
                    (P.READING, "the reading room"), (P.STACKS, "the stacks")):
        s.zone("interior", P.rect_of(r), 0.0, name=name)
    s.zone("interior", P.rect_of(P.GALLERY), GY, name="the gallery")
    s.zone("interior", P.rect_of(P.RARE_BOOKS), GY, name="the rare books room")
    s.look_zone("UniversityCampus_Inside", (X0, 0.0, Z0), (72.0, C, Z1))
    s.look_zone("UniversityCampus_Inside", (72.0, 0.0, Z0), (X1, H, Z1))


def circulation(s):
    s.station("Fingerprint", "Book Return Prints", 52.0, -61.4, 180, prop="StationBookReturn")
    for x in (48.0, 57.0):
        s.prop("CardCatalog", x, -42.6, 0)
    s.prop("BookCart", 66.0, -45.5, 90)
    s.prop("UmbrellaStand", 43.0, -45.0, 0)
    s.prop("CoatStand", 43.0, -58.0, 0)
    s.prop("Plant", 69.5, -61.8, 0)
    s.prop("Bench", 64.0, -61.9, 180)
    for x in (50.0, 63.0):
        kit.pendant(s, x, C, -52.0, drop=3.0, shade="Brass", color=fit.WARM, range_=20, brightness=1.0, wide=1.1)
    fit.plaque(s, 52.0, 9.8, -63.7, 180, 5.0, 0.9, "返却  RETURNS")
    s.sound("mapHeaterHum", (60.0, 3.0, -44.0), 14.0, 0.15)


def microfilm(s):
    for z in (-100.0, -93.0, -86.0):
        s.prop("MicrofilmReader", X0 + 1.4, z, -90)
        s.prop("Chair", X0 + 4.4, z, 90)
    for x in (46.0, 49.4, 52.8, 56.2, 59.6):
        s.prop("Bookshelf", x, -65.0, 0)
    top = fit.table(s, 60.0, -76.0, 6.0, 3.0, 0, 0.0)
    fit.chairs_round(s, 60.0, -76.0, 6.0, 3.0, 0)
    s.sheet(60.0, top, -76.0, spare=True)
    fit.panel(s, 56.0, -92.0, C, brightness=0.8, range_=18)
    fit.panel(s, 56.0, -74.0, C, on=False)


def reading_room(s, g):
    for x in (92.0, 110.0, 128.0):
        for z in (-66.0, -53.0):
            s.prop("ReadingTable", x, z, 0)
            s.collider((x, 1.4, z), (10.0, 2.8, 4.0), 0, True, "WoodFloor")
            fit.chairs_round(s, x, z, 10.0, 4.0, 0)
    s.sheet(110.0, 2.85, -53.0)
    # Shelves under the gallery, between the stacks' doors.
    for x in (78.0, 81.4, 97.0, 100.4, 103.8, 116.2, 119.6, 123.0, 139.0, 142.4):
        s.prop("Bookshelf", x, -83.0, 180)
    # The gallery: a stair up each end wall, the railing between their heads.
    for x, width, z0, z1 in P.GALLERY_STAIRS:
        fit.stairs(s, g, (x, z0), (x, z1), 0.0, GY, width, "WoodFloorDark", "WoodPanel", step=0.7)
    edge = P.GALLERY[3]
    fit.railing(s, [(76.5, edge - 0.2), (144.1, edge - 0.2)], GY, h=3.4, mat="BlackMetal")
    for x in (82.0, 100.0, 120.0, 138.0):
        s.prop("Bookshelf", x, -83.0, 180, 1.0, GY)
    for x in (90.0, 110.0, 130.0):
        kit.pendant(s, x, H, -60.0, drop=9.0, shade="Brass", color=fit.WARM, range_=36, brightness=1.3, wide=1.8)
    for x in (86.0, 134.0):
        fit.wall_lamp(s, x, GY + 7.0, -83.7, 180, color=fit.WARM, range_=16, brightness=0.7)
    # Downlights set in the gallery's underside, over the shelves under it.
    for x in (90.0, 110.0, 130.0):
        fit.downlight(s, x, -80.0, SLAB, range_=16, brightness=0.8)
    s.sound("mapHeaterHum", (110.0, 3.0, -44.0), 20.0, 0.12)


def stacks(s):
    """Double-sided stacks running north to south, aisles between them."""
    for x in (84.0, 94.0, 104.0, 116.0, 126.0, 136.0):
        for k in range(5):
            z = -103.4 + k * 3.2
            s.prop("Bookshelf", x - 0.9, z, 90)
            s.prop("Bookshelf", x + 0.9, z, -90)
    s.hood(78.0, -106.0)
    for x in (89.0, 110.0, 131.0):
        kit.tube_light(s, x, SLAB, -96.0, length=6.0, rot=90, range_=18, brightness=0.65)
    kit.tube_light(s, 145.0, SLAB, -100.0, length=4.0, rot=90, range_=12, brightness=0.4)


def rare_books(s):
    s.station("Forensics", "Rare Books Ink Lab", 110.0, -106.4, 180, y=GY, prop="StationLabBench")
    s.station("Camera", "Library CCTV", 146.4, -96.0, 90, y=GY, prop="StationCCTV", spare=True)
    for x in (92.0, 128.0):
        s.prop("DisplayCase", x, -96.0, 0, 1.0, GY)
    for x in (76.0, 79.4, 82.8):
        s.prop("Bookshelf", x, -107.6, 180, 1.0, GY)
    top = fit.table(s, 96.0, -88.5, 6.0, 3.0, 0, GY)
    s.prop("Microscope", 97.0, -88.5, 0, 1.0, top)
    s.prop("Chair", 96.0, -86.2, 180, 1.0, GY)
    for x in (92.0, 110.0, 128.0):
        kit.pendant(s, x, H, -97.0, drop=6.0, shade="Brass", color=fit.WARM, range_=24, brightness=1.0, wide=1.2)
    fit.plaque(s, 110.0, GY + 10.4, -83.7, 180, 6.0, 0.9, "貴重書庫  RARE BOOKS")


def build(s, g):
    exterior(s)
    rooms(s)
    circulation(s)
    microfilm(s)
    reading_room(s, g)
    stacks(s)
    rare_books(s)
