"""The Great Auditorium (大講堂) and its clock tower, set up for tomorrow's entrance exam.

- You go in through the arched portal at the tower's foot, into a stone vestibule, and on
  into the foyer.
- The foyer's checkered floor runs the width of the building. At its west end is the exam
  headquarters (入試本部), behind clear glass: the Exam HQ Switchboard, the seat charts and
  the night's news on a CRT. At its east end is the proctors' room, its blinds shut, with the
  Proctor Booth and the hall's camera monitors.
- Behind the foyer is the exam hall: 45 numbered desks in five blocks with aisles between
  them, facing the stage (look-only), the lectern and the great clock.
- Outside: brick Gothic with buttresses, a snowy gable roof, and the tower rising to its clock
  and spire."""

from maps import kit
from maps.venues.campus import fit, masonry
from maps.venues.campus import plan as P

A = P.AUDITORIUM
X0, Z0, X1, Z1 = P.inner(A)  # -64.6, -108.6, 24.6, -63.4
FOYER_N = P.FOYER_Z[0]  # -78: the partition between the hall and the foyer
C = P.CEIL


def exterior(s):
    def pane(face, u, level):
        """The exam hall's high windows are clear glass, so the snowy night shows through them
        from the hall (the foyer's upper floor keeps its lit and dark panes)."""
        del level
        if face == "n":
            return "Glass"
        if face in ("e", "w"):
            a, _ = masonry.face_line(A, face)
            z = a[1] + u if face == "e" else a[1] - u
            return "Glass" if z < FOYER_N else None
        return None

    masonry.shell(s, A, P.EAVES["auditorium"], P.DOORS["auditorium"] + [("s", -20.0, 6.0)], brick="BrickRed",
                  storeys=[0.0, P.GF], avoid={"s": [(masonry.along(A, "s", -20.0), 20.0)]}, pane=pane, seed=3)
    masonry.gable_roof(s, A, P.EAVES["auditorium"], 12.0, gable="BrickRed", along_x=True)
    for z in (-77.0, -86.0, -103.0):
        masonry.buttress(s, A[0], z, (-1, 0), 17.0)
        masonry.buttress(s, A[2], z, (1, 0), 17.0)
    # The side doors' lamps and names.
    for x, rot in ((A[0], 90), (A[2], -90)):
        fit.wall_lamp(s, x - (0.3 if rot == 90 else -0.3), 13.0, -94.0, rot, color=fit.WARM, range_=20, brightness=1.0)
    # The tower: the vestibule's walls, then the tower above it.
    masonry.shell(s, P.TOWER, P.GF, P.DOORS["tower"][:1], brick="BrickRed", storeys=[0.0], skip=("n",),
                  ground_windows=("e", "w"), window_w=2.6, spacing=7.0, cornice=False, seed=4)
    masonry.clock_tower(s, P.TOWER, P.TOWER_TOP)
    tx0, tz0, tx1, tz1 = P.TOWER
    fit.plaque(s, (tx0 + tx1) / 2, 16.2, tz1 + 0.05, 180, 11.0, 1.6, "大講堂  GREAT AUDITORIUM", (236, 214, 150),
               (26, 20, 18), font="Garamond")
    for x in (tx0 + 3.0, tx1 - 3.0):
        fit.wall_lamp(s, x, 7.5, tz1 + 0.3, 180, color=fit.WARM, range_=22, brightness=1.2)


def vestibule(s):
    x0, z0, x1, z1 = P.TOWER[0] + P.WALL_T, P.TOWER[1], P.TOWER[2] - P.WALL_T, P.TOWER[3] - P.WALL_T
    fit.floor_faces(s, P.box(x0, z0, x1, z1), 0.0, "Stone")
    # (Higher than the other rooms' ceilings: the tower door's arch rises to 13.2.)
    vc = 13.8
    fit.ceiling_faces(s, P.box(x0, z0, x1, z1), vc, "WoodPanel")
    s.collider(((x0 + x1) / 2, vc + 0.1, (z0 + z1) / 2), (x1 - x0, 0.2, z1 - z0), 0, True, None)
    s.zone("interior", P.box(x0, z0, x1, z1), 0.0, name="the clock tower")
    s.look_zone("UniversityCampus_Inside", (x0, 0.0, z0), (x1, vc, z1))
    kit.pendant(s, (x0 + x1) / 2, vc, (z0 + z1) / 2, drop=4.3, shade="Brass", color=fit.WARM, range_=22,
                brightness=1.1, wide=1.1)
    s.prop("UmbrellaStand", x0 + 1.2, z1 - 1.4, 0)
    s.prop("Plant", x1 - 2.0, z1 - 2.0, 0)


def foyer(s):
    # Floors, ceilings and the partitions.
    fit.floor_faces(s, P.box(X0, FOYER_N + 0.3, X1, Z1), 0.0, "Terrazzo",
                    holes=[P.rect_of(P.EXAM_HQ), P.rect_of(P.PROCTOR)])
    fit.floor_faces(s, P.rect_of(P.EXAM_HQ), 0.0, "CarpetTile")
    fit.floor_faces(s, P.rect_of(P.PROCTOR), 0.0, "WoodFloorDark")
    # Coffered plaster over the foyer; the two offices keep their office tiles.
    fit.ceiling_faces(s, P.box(X0, FOYER_N + 0.3, X1, Z1), C, "CeilingPlaster",
                      holes=[P.rect_of(P.EXAM_HQ), P.rect_of(P.PROCTOR)])
    for r in (P.EXAM_HQ, P.PROCTOR):
        fit.ceiling_faces(s, P.rect_of(r), C, "Ceiling")
    fit.coffers(s, P.EXAM_HQ[2] + 0.3, FOYER_N + 0.3, P.PROCTOR[0] - 0.3, Z1, C, spacing=8.0)
    s.collider(((X0 + X1) / 2, C + 0.5, (FOYER_N + Z1) / 2), (X1 - X0, 1.0, Z1 - FOYER_N), 0, True, None)
    fit.partition(s, (X0, FOYER_N), (X1, FOYER_N), 0.0, P.HALL_H, "WoodPanel", "PlasterLight",
                  doors=[(-32.0 - X0, 6.0), (-8.0 - X0, 6.0)])
    fit.partition(s, (-44.0, FOYER_N + 0.3), (-44.0, Z1), 0.0, C, "PlasterLight", "PlasterGrey", doors=[(7.7, 4.4)],
                  glass="clear")
    fit.partition(s, (4.0, FOYER_N + 0.3), (4.0, Z1), 0.0, C, "PlasterGrey", "PlasterLight", doors=[(7.7, 4.4)],
                  glass="blinds")
    s.zone("interior", P.box(X0, FOYER_N, X1, Z1), 0.0, name="the foyer")
    s.look_zone("UniversityCampus_Inside", (X0, 0.0, FOYER_N), (X1, C, Z1))
    # The foyer itself: exam signs, the seat chart, benches, the great clock over the hall's doors.
    s.prop("StationClock", -20.0, -77.35, 180, 1.0, 10.8)
    fit.plaque(s, -32.0, 10.2, -77.6, 180, 5.4, 0.9, "試験場 A  HALL A")
    fit.plaque(s, -8.0, 10.2, -77.6, 180, 5.4, 0.9, "試験場 B  HALL B")
    for x in (-40.0, 0.0):
        s.prop("ExamSignStand", x, -74.0, 180)
    s.sign((-40.0, 5.2, -73.75), 180, 1.8, 4.4, "入\n学\n試\n験\n会\n場", "GothamBlack", (20, 20, 22), None)
    s.sign((0.0, 5.2, -73.75), 180, 1.8, 4.4, "受\n験\n生\n入\n口", "GothamBlack", (20, 20, 22), None)
    s.prop("NoticeBoard", -30.0, -64.2, 0)
    s.sign((-30.0, 4.3, -64.45), 0, 4.6, 2.6, "座席表  SEAT CHART\n受験番号 10001 - 10240", "GothamBold", (30, 30, 34),
           (236, 232, 222))
    for x in (-38.0, -2.0):
        s.prop("Bench", x, -64.5, 0)
    s.prop("DisplayCase", -15.4, -76.2, 180)
    s.prop("CoatStand", 2.0, -66.0, 0)
    s.prop("Plant", -25.0, -76.2, 0)
    for x in (-34.0, -20.0, -6.0):
        kit.pendant(s, x, C, -70.5, drop=3.0, shade="Brass", color=fit.WARM, range_=20, brightness=1.0, wide=1.2)
    fit.plaque(s, -43.7, 10.2, -66.0, -90, 5.2, 0.9, "入試本部  EXAM HQ", (250, 240, 220), (120, 24, 30))
    fit.plaque(s, 3.7, 10.2, -66.0, 90, 5.2, 0.9, "試験監督室  PROCTORS")


def exam_hq(s):
    """The exam headquarters: the switchboard, the table where tomorrow is planned (a sheet on it),
    seat charts on the walls, sealed boxes, the heater, the news on a CRT."""
    s.station("Phone", "Exam HQ Switchboard", -62.2, -70.5, -90, prop="StationPhoneDesk")
    top = fit.table(s, -51.0, -72.5, 7.0, 3.0, 0, 0.0, top="Wood")
    fit.chairs_round(s, -51.0, -72.5, 7.0, 3.0, 0)
    s.sheet(-49.5, top, -72.5)
    s.prop("Whiteboard", -52.0, -64.6, 0)
    s.prop("FilingCabinet", -63.3, -76.0, -90)
    s.prop("KeroseneHeater", -46.2, -76.2, 0)
    s.prop("Crate", -46.4, -64.7, 8, 0.6)
    # The CRT on its stand, the late news on it.
    s.box("BlackMetal", (-58.5, 1.6, -64.4), (3.4, 3.2, 1.6), 0, collide=True)
    s.box("CreamTrim", (-58.5, 4.4, -64.6), (3.0, 2.4, 2.0), 0)
    s.screen((-58.5, 4.4, -65.65), 0, 2.4, 1.8, "news")
    fit.panel(s, -54.0, -72.0, C, brightness=0.9, range_=20)
    fit.panel(s, -60.0, -66.0, C, brightness=0.7, range_=16)
    s.sound("mapHeaterHum", (-46.2, 2.0, -76.2), 16.0, 0.25)


def proctor(s):
    """The proctors' room, blinds shut: the Proctor Booth's CCTV desk and the hall's cameras on a
    rack of monitors, the duty desk, a heater."""
    s.station("Camera", "Proctor Booth", 22.4, -70.5, 90, prop="StationCCTV")
    s.box("BlackMetal", (14.0, 7.5, -77.1), (12.0, 5.2, 0.6))
    for k in range(3):
        s.screen((10.0 + k * 4.0, 7.5, -76.75), 180, 3.4, 2.4, "cctv")
    fit.desk(s, 9.0, -65.2, 0)
    s.prop("FilingCabinet", 23.3, -65.0, 90)
    s.prop("KeroseneHeater", 6.2, -76.0, 0)
    s.prop("CoatStand", 23.0, -76.4, 0)
    fit.panel(s, 14.0, -70.0, C, color=fit.COOL, brightness=0.75, range_=18)


# The exam hall ---------------------------------------------------------------------------------------------

HALL_Z0, HALL_Z1 = Z0, FOYER_N - 0.3  # -108.6 .. -78.3
STAGE_Z = P.STAGE[3]  # -101: the stage's front edge
DESK_ROWS = (-95.0, -90.0, -85.0)
DESK_BLOCKS = [-55.8 + k * 15.2 for k in range(5)]  # the west edge of each block of three desks


def exam_hall(s):
    H = P.HALL_H
    fit.floor_faces(s, P.box(X0, STAGE_Z, X1, HALL_Z1), 0.0, "WoodFloor")
    fit.ceiling_faces(s, P.box(X0, HALL_Z0, X1, HALL_Z1), H, "CeilingPlaster")
    fit.coffers(s, X0, HALL_Z0, X1, HALL_Z1, H, spacing=11.15, depth=0.9, w=0.8)
    s.collider(((X0 + X1) / 2, H + 0.5, (HALL_Z0 + HALL_Z1) / 2), (X1 - X0, 1.0, HALL_Z1 - HALL_Z0), 0, True, None)
    for x in (X0 + 22.3, X0 + 44.6, X0 + 66.9):
        s.box("WoodPanel", (x, H - 0.6, (HALL_Z0 + HALL_Z1) / 2), (1.0, 1.2, HALL_Z1 - HALL_Z0), skip=("+y",))
    s.zone("interior", P.box(X0, STAGE_Z, X1, HALL_Z1), 0.0, name="the exam hall")
    s.look_zone("UniversityCampus_Inside", (X0, 0.0, HALL_Z0), (X1, H, HALL_Z1))
    # The stage (look-only): its front, its boards, the guard along its edge.
    sx0, sz0, sx1, sz1 = P.STAGE
    s.box("WoodPanel", ((sx0 + sx1) / 2, 0.6, (sz0 + sz1) / 2), (sx1 - sx0, 1.2, sz1 - sz0), collide=True,
          mats={"+y": "WoodFloorDark"})
    s.collider(((sx0 + sx1) / 2, 7.0, sz1 + 0.2), (sx1 - sx0, 12.0, 0.4), 0, False, None)
    s.zone("offlimits", P.box(sx0, sz0, sx1, sz1), 1.2, name="the stage")
    s.prop("Lectern", -20.0, -104.8, 180, 1.0, 1.2)
    top = 1.2 + 2.75
    s.box("Wood", (0.0, top - 0.1, -106.5), (12.0, 0.2, 2.6))
    for dx in (-5.6, 5.6):
        s.box("BlackMetal", (dx, 1.2 + 1.35, -106.5), (0.2, 2.7, 2.2))
    for x in (-3.0, 0.0, 3.0):
        s.prop("Chair", x, -107.9, 180, 1.0, 1.2)
    # The blackboard and the great clock on the back wall; the room's name.
    s.box("WoodPanel", (-20.0, 9.0, Z0 + 0.3), (26.0, 8.0, 0.4))
    s.box("BlackTrim", (-20.0, 9.0, Z0 + 0.52), (25.0, 7.2, 0.06))
    s.sign((-20.0, 10.2, Z0 + 0.6), 180, 22.0, 2.4, "入学試験  第一日", "GothamBold", (226, 226, 216), None)
    s.sign((-20.0, 7.6, Z0 + 0.6), 180, 22.0, 1.4, "試験開始  9:30     携帯電話の電源を切ること", "GothamBold",
           (200, 200, 190), None)
    kit.wall_clock(s, -20.0, 16.5, Z0 + 0.35, 180, 1.8)
    # The desks: five blocks of three, three rows, aisles between the blocks.
    for bx in DESK_BLOCKS:
        for row, z in enumerate(DESK_ROWS):
            for k in range(3):
                s.prop("ExamDesk", bx + 1.8 + k * 3.6, z, 0)
    # Radiators under the windows, the notices on the walls.
    for x in (X0 + 0.9, X1 - 0.9):
        s.box("DarkMetal", (x, 1.4, -81.5), (0.8, 2.2, 4.0), 0, collide=True)
    for x in (X0 + 0.3, X1 - 0.3):
        fit.plaque(s, x, 9.0, -100.6, -90 if x < 0 else 90, 5.0, 1.6, "試験中  静粛に\nEXAM IN PROGRESS", (240, 236, 226),
                   (110, 24, 28))
    for x in (-45.0, -20.0, 5.0):
        for z in (-97.0, -86.0):
            kit.pendant(s, x, H, z, drop=6.0, shade="Brass", color=fit.WARM, range_=34, brightness=1.4, wide=1.6)
    fit.downlight(s, -20.0, -104.8, H, range_=22, brightness=1.0, angle=60)
    s.sound("clockTick", (-20.0, 16.0, -107.0), 40.0, 0.3)


def build(s, g):
    del g
    exterior(s)
    vestibule(s)
    foyer(s)
    exam_hq(s)
    proctor(s)
    exam_hall(s)
