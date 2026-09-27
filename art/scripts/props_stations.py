"""Station looks: what a case-file station is where it stands (a CCTV desk in a control room, a
payphone booth, a hotel's front desk, a police print kit, a lab bench), in place of the standard
console (props_gameplay.Station).

Each is built round the game's own parts. The game's invisible desk (5 x 3 x 2.4) stands on the
design origin, the worker in front at -Y. The game's screen goes where the prop says (its
`screen` slot: the middle of the screen's face, its size and tilt), set into a monitor, a
terminal or a viewer the prop builds round it, never behind anything. anchor=(0, 0) places the
design origin on the station's spot."""

import modelkit as mk
import propkit as pk
from common import srgb
from props import prop


def monitor(prefix, x, y, z, w, h, tilt, housing, stand=True, stand_to=2.95):
    """A monitor round a screen slot: the face at (x, y, z) facing -Y (the game's screen sits on
    it), a housing and bezel just behind, a neck and foot down to the desk at stand_to."""
    import math

    a = math.radians(tilt)
    back = 0.18
    cy, cz = y + back / 2 * math.cos(a), z - back / 2 * math.sin(a) * 0 + 0.0
    parts = [mk.box(prefix + "Housing", (w + 0.3, back + 0.12, h + 0.3), (x, cy + 0.06, cz), rot=(-tilt, 0, 0), mat=housing,
                    bevel=0.05)]
    if stand:
        parts += [mk.box(prefix + "Neck", (0.25, 0.2, z - h / 2 - stand_to + 0.2), (x, y + 0.35, (z - h / 2 + stand_to) / 2),
                         mat=housing),
                  mk.box(prefix + "Foot", (1.1, 0.8, 0.08), (x, y + 0.35, stand_to + 0.04), mat=housing, bevel=0.03)]
    return parts


def desk(prefix, top_mat, body_mat, h=2.9, w=5.2, d=2.6, modesty=True):
    parts = [mk.box(prefix + "Top", (w, d, 0.14), (0, 0, h - 0.07), mat=top_mat, bevel=0.03)]
    for sx in (-1, 1):
        parts.append(mk.box(prefix + "Side", (0.12, d - 0.2, h - 0.14), (sx * (w / 2 - 0.1), 0, (h - 0.14) / 2),
                            mat=body_mat, bevel=0.02))
    if modesty:
        parts.append(mk.box(prefix + "Modesty", (w - 0.3, 0.08, h - 1.0), (0, d / 2 - 0.15, (h - 0.14) / 2 + 0.3),
                            mat=body_mat))
    return parts


CCTV_SCREEN = (0.0, 0.35, 4.35, 3.2, 1.9, 6)


@prop("StationCCTV", pivot="bottom", material="Metal", collide=False, texture=1024, set="Tokyo", anchor=(0, 0),
      screen=CCTV_SCREEN)
def station_cctv():
    """A security desk: a steel desk with its drawer pedestal, the main monitor (the game's screen),
    a rack of six small camera feeds behind it, keyboard, joystick controller, a phone, a mug and
    the log book."""
    steel = pk.metal("Cctv_Steel", (60, 62, 68), (90, 92, 100), rough=0.45, metallic=0.5)
    top = mk.noisy("Cctv_Top", srgb(40, 42, 48), srgb(60, 62, 68), scale=10, roughness=0.3)
    dark = pk.metal("Cctv_Dark", (18, 18, 20), (32, 32, 36), rough=0.5, metallic=0.2)
    paper = pk.plastic("Cctv_Paper", (230, 226, 214))
    x, y, z, w, h, tilt = CCTV_SCREEN
    parts = desk("Cctv_", top, steel)
    parts.append(mk.box("Pedestal", (1.4, 2.2, 2.6), (1.8, -0.1, 1.3), mat=steel, bevel=0.03))
    for k in range(3):
        parts.append(mk.box("DrawerFront", (1.3, 0.04, 0.8), (1.8, -1.22, 0.5 + k * 0.85), mat=steel))
        parts += pk.handle("Pull", 1.8, -1.24, 0.75 + k * 0.85, 0.6, dark, vertical=False, stand=0.08, r=0.03)
    parts += monitor("Main_", x, y, z, w, h, tilt, dark)
    # The rack of camera feeds behind the main monitor, clear of it.
    parts.append(mk.box("Rack", (5.0, 0.4, 2.2), (0, 1.25, 6.5), mat=steel, bevel=0.03))
    parts += [mk.box("RackLeg", (0.2, 0.3, 3.6), (sx * 2.3, 1.25, 4.6), mat=steel) for sx in (-1, 1)]
    glows = []
    feeds = [(90, 150, 130), (110, 140, 170), (150, 150, 110), (100, 130, 160), (130, 150, 120), (160, 140, 120)]
    for k in range(6):
        fx = -1.6 + (k % 3) * 1.6
        fz = 7.05 - (k // 3) * 1.1
        parts.append(mk.box("Feed", (1.45, 0.3, 1.0), (fx, 1.02, fz), mat=dark, bevel=0.04))
        glows.append(mk.box("FeedLit", (1.25, 0.05, 0.8), (fx, 0.86, fz), mat=pk.glow(f"Cctv_Feed{k}", feeds[k], 2)))
    parts += [
        mk.box("Keyboard", (2.0, 0.7, 0.1), (-0.4, -0.75, 2.97), rot=(3, 0, 0), mat=dark, bevel=0.02),
        mk.box("JoyBase", (0.8, 0.7, 0.2), (1.6, -0.75, 3.0), mat=dark, bevel=0.05),
        mk.cylinder("Stick", 0.06, 0.5, (1.6, -0.75, 3.35), mat=steel, verts=8),
        mk.box("Phone", (0.8, 0.7, 0.25), (-2.0, 0.2, 3.02), mat=dark, bevel=0.06),
        mk.box("LogBook", (0.9, 1.2, 0.08), (-2.0, -0.7, 2.94), rot=(0, 0, 8), mat=paper),
        mk.cylinder("Mug", 0.17, 0.4, (2.2, 0.4, 3.1), mat=pk.plastic("Cctv_Mug", (200, 196, 188)), verts=12),
    ]
    glows.append(mk.box("Led", (0.1, 0.04, 0.1), (2.05, -0.08, 3.08), mat=pk.glow("Cctv_Led", (255, 60, 60), 5)))
    return parts, glows


PHONE_SCREEN = (0.0, 1.15, 5.5, 2.4, 1.4, 0)


@prop("StationPhoneBooth", pivot="bottom", material="SmoothPlastic", collide=False, texture=1024, set="Tokyo",
      anchor=(0, 0), screen=PHONE_SCREEN)
def station_phone_booth():
    """A public telephone booth, open to the front (-Y): a steel frame with tinted glass sides and
    back, a lit 電話 TELEPHONE roof sign, the green payphone on its shelf with the directory
    beneath, the information display (the game's screen) over it."""
    frame = pk.metal("Booth_Frame", (170, 174, 180), (206, 210, 214), rough=0.3, metallic=0.5)
    glass = pk.dark_glass("Booth_Glass", (60, 80, 84))
    green = pk.paint("Booth_Green", (40, 120, 70), rough=0.35)
    dark = pk.metal("Booth_Dark", (20, 22, 24), (36, 38, 40), rough=0.5, metallic=0.2)
    paper = pk.plastic("Booth_Book", (230, 220, 190))
    x, y, z, w, h, tilt = PHONE_SCREEN
    parts = [mk.box("Floor", (5.2, 3.2, 0.12), (0, 0, 0.06), mat=frame),
             mk.box("Roof", (5.4, 3.4, 0.35), (0, 0, 9.2), mat=green, bevel=0.08),
             mk.box("Back", (5.0, 0.1, 8.8), (0, 1.55, 4.6), mat=glass),
             mk.box("BackPanel", (3.2, 0.12, 4.0), (0, 1.45, 4.6), mat=frame)]
    for sx in (-1, 1):
        parts += [mk.box("Side", (0.08, 3.0, 7.0), (sx * 2.55, 0, 4.8), mat=glass),
                  mk.box("PostF", (0.18, 0.18, 9.0), (sx * 2.55, -1.55, 4.6), mat=frame),
                  mk.box("PostB", (0.18, 0.18, 9.0), (sx * 2.55, 1.55, 4.6), mat=frame),
                  mk.box("Rail", (0.1, 3.0, 0.14), (sx * 2.55, 0, 1.2), mat=frame)]
    parts += [mk.box("Shelf", (2.6, 1.0, 0.14), (0, 1.0, 3.1), mat=frame, bevel=0.03),
              mk.box("Directory", (1.4, 0.9, 0.35), (0.6, 1.0, 2.6), mat=paper, bevel=0.04),
              pk.rounded("Phone", (1.2, 0.6, 1.6), (-0.9, 1.15, 3.95), green, r=0.12),
              pk.rounded("Handset", (0.3, 0.3, 1.3), (-1.55, 0.95, 4.0), green, r=0.1),
              mk.box("Keypad", (0.6, 0.05, 0.6), (-0.8, 0.83, 3.75), mat=dark),
              mk.box("CoinSlot", (0.4, 0.05, 0.1), (-0.8, 0.83, 4.45), mat=dark),
              mk.tube("Cord", (-1.5, 0.95, 3.4), (-1.1, 0.9, 3.3), 0.03, mat=dark, verts=4)]
    parts += monitor("Info_", x, y, z, w, h, tilt, dark, stand=False)
    ink = pk.plastic("Booth_Ink", (24, 60, 30))
    glows = [mk.box("RoofSign", (4.6, 0.05, 0.5), (0, -1.72, 9.2), mat=pk.glow("Booth_Sign", (220, 255, 220), 3))]
    parts += pk.label("SignText", "電話 TELEPHONE", 0.28, (0, -1.76, 9.2), ink)
    return parts, glows


RECEPTION_SCREEN = (0.9, -0.5, 4.5, 2.0, 1.25, 12)


@prop("StationReception", pivot="bottom", material="Wood", collide=False, texture=1024, set="Tokyo", anchor=(0, 0),
      screen=RECEPTION_SCREEN)
def station_reception():
    """A front desk: a wooden counter with a pale stone top toward the guest (-Y), the check-in
    terminal on it facing the guest (the game's screen), a bell, the guest book, a desk phone and
    a small shaded lamp; behind, the lower worktop and the key rack on its panel."""
    wood = mk.wood("Recep_Wood", srgb(120, 80, 50), srgb(64, 40, 26), scale=4)
    stone = mk.noisy("Recep_Stone", srgb(206, 202, 194), srgb(230, 226, 218), scale=16, roughness=0.25)
    brass = pk.metal("Recep_Brass", (176, 140, 72), (214, 176, 96), rough=0.3, metallic=0.9)
    dark = pk.metal("Recep_Dark", (20, 20, 22), (34, 34, 38), rough=0.5, metallic=0.2)
    paper = pk.plastic("Recep_Paper", (236, 230, 214))
    x, y, z, w, h, tilt = RECEPTION_SCREEN
    parts = [mk.box("Front", (5.2, 0.4, 3.6), (0, -1.1, 1.8), mat=wood, bevel=0.05),
             mk.box("Counter", (5.3, 1.0, 0.14), (0, -0.95, 3.67), mat=stone, bevel=0.03),
             mk.box("Work", (5.0, 1.6, 0.1), (0, 0.4, 2.8), mat=wood),
             mk.box("Body", (5.0, 1.6, 2.75), (0, 0.4, 1.38), mat=wood),
             mk.box("KeyPanel", (5.0, 0.2, 3.4), (0, 1.5, 5.6), mat=wood, bevel=0.03),
             mk.cylinder("Bell", 0.22, 0.2, (-1.8, -1.0, 3.84), mat=brass, verts=16),
             mk.box("Book", (1.0, 0.7, 0.08), (-0.8, -0.95, 3.78), rot=(0, 0, 6), mat=paper),
             pk.rounded("Phone", (0.7, 0.6, 0.25), (-1.9, 0.5, 2.98), dark, r=0.06),
             mk.cylinder("LampBase", 0.2, 0.08, (2.1, 0.8, 2.89), mat=brass, verts=12),
             mk.cylinder("LampStem", 0.04, 1.1, (2.1, 0.8, 3.45), mat=brass, verts=6),
             mk.lathe("LampShade", [(0.25, 0), (0.4, -0.45), (0.0, -0.45)], (2.1, 0.8, 4.35), mat=paper, segments=16)]
    parts += monitor("Term_", x, y, z, w, h, tilt, dark, stand_to=3.74)
    for row in range(2):
        for col in range(6):
            kx, kz = -2.0 + col * 0.8, 6.6 + row * 0.8
            parts += [mk.box("Hook", (0.12, 0.2, 0.12), (kx, 1.35, kz), mat=brass),
                      mk.box("Tag", (0.2, 0.05, 0.4), (kx, 1.28, kz - 0.3), mat=brass)]
    glows = [mk.sphere("Bulb", 0.14, (2.1, 0.8, 4.0), mat=pk.glow("Recep_Bulb", (255, 214, 160), 3), segments=8, rings=6)]
    return parts, glows


PRINT_SCREEN = (0.4, 0.75, 4.35, 2.8, 1.8, 10)


@prop("StationPrintKit", pivot="bottom", material="Metal", collide=False, texture=1024, set="Tokyo", anchor=(0, 0),
      screen=PRINT_SCREEN)
def station_print_kit():
    """A police evidence table: the lit print viewer at the back (the game's screen), an open
    fingerprint kit with its powders and brushes at the front left, print cards, ink pad and
    roller, a magnifier lamp at the right."""
    steel = pk.metal("Print_Steel", (60, 62, 68), (92, 94, 102), rough=0.45, metallic=0.5)
    top = mk.noisy("Print_Top", srgb(150, 152, 156), srgb(180, 182, 186), scale=10, roughness=0.4)
    case = pk.metal("Print_Case", (20, 22, 26), (40, 42, 48), rough=0.4)
    foam = mk.noisy("Print_Foam", srgb(40, 40, 44), srgb(60, 60, 66), scale=40, roughness=0.95)
    card = pk.plastic("Print_Card", (240, 238, 230))
    dark = pk.metal("Print_Dark", (20, 20, 22), (34, 34, 38), rough=0.5, metallic=0.2)
    x, y, z, w, h, tilt = PRINT_SCREEN
    parts = desk("Print_", top, steel)
    parts += monitor("Viewer_", x, y, z, w, h, tilt, dark)
    parts += [mk.box("Case", (2.0, 1.2, 0.35), (-1.3, -0.55, 3.1), mat=case, bevel=0.04),
              mk.box("Foam", (1.8, 1.0, 0.05), (-1.3, -0.55, 3.28), mat=foam),
              mk.box("Lid", (2.0, 0.1, 1.2), (-1.3, 0.1, 3.5), rot=(-15, 0, 0), mat=case, bevel=0.03)]
    for k, rgb in enumerate(((20, 20, 22), (230, 230, 226), (200, 150, 40))):
        parts.append(mk.cylinder("Jar", 0.14, 0.3, (-1.9 + k * 0.4, -0.7, 3.4), mat=pk.plastic(f"Print_Jar{k}", rgb), verts=10))
    parts += [mk.tube("Brush", (-0.8, -0.8, 3.32), (-0.5, -0.4, 3.32), 0.03, mat=dark, verts=5),
              mk.box("Cards", (1.0, 0.7, 0.05), (1.4, -0.7, 2.94), rot=(0, 0, -6), mat=card),
              mk.box("InkPad", (0.6, 0.4, 0.1), (0.4, -0.85, 2.96), mat=dark, bevel=0.02),
              mk.cylinder("Roller", 0.08, 0.5, (0.4, -0.45, 3.0), rot=(0, 90, 0), mat=dark, verts=8),
              mk.cylinder("LampBase", 0.25, 0.1, (2.2, 0.4, 2.95), mat=steel, verts=12),
              mk.tube("LampArm1", (2.2, 0.4, 3.0), (2.35, 0.0, 4.2), 0.05, mat=steel, verts=6),
              mk.tube("LampArm2", (2.35, 0.0, 4.2), (2.3, -0.6, 3.9), 0.05, mat=steel, verts=6),
              mk.torus("Lens", 0.3, 0.06, (2.3, -0.6, 3.8), mat=steel, major_segments=16, minor_segments=4)]
    glows = [mk.cylinder("LensGlow", 0.26, 0.03, (2.3, -0.6, 3.8), mat=pk.glow("Print_Lens", (255, 244, 220), 2), verts=16)]
    return parts, glows


LAB_SCREEN = (-0.3, 0.55, 4.7, 3.0, 1.8, 4)


@prop("StationLabBench", pivot="bottom", material="SmoothPlastic", collide=False, texture=1024, set="Tokyo",
      anchor=(0, 0), screen=LAB_SCREEN)
def station_lab_bench():
    """A lab bench: a black resin top on white cabinets, a shelf of reagent bottles behind, the
    analysis monitor on it (the game's screen), a microscope at the right front, a rack of test
    tubes at the left, a pipette stand."""
    white = pk.plastic("Lab_White", (232, 234, 234))
    resin = mk.noisy("Lab_Resin", srgb(18, 18, 20), srgb(34, 34, 38), scale=10, roughness=0.25)
    steel = pk.metal("Lab_Steel", (150, 154, 160), (190, 194, 200), rough=0.3, metallic=0.6)
    dark = pk.metal("Lab_Dark", (20, 20, 22), (34, 34, 38), rough=0.5, metallic=0.2)
    glass = mk.noisy("Lab_Glass", srgb(150, 190, 200), srgb(190, 220, 226), scale=4, roughness=0.1)
    x, y, z, w, h, tilt = LAB_SCREEN
    parts = [mk.box("Cabinets", (5.0, 2.4, 2.8), (0, 0, 1.4), mat=white, bevel=0.03),
             mk.box("Top", (5.2, 2.6, 0.16), (0, 0, 2.88), mat=resin, bevel=0.03),
             mk.box("Shelf", (5.0, 0.6, 0.1), (0, 1.0, 6.1), mat=white),
             mk.box("ShelfBack", (5.0, 0.1, 3.4), (0, 1.3, 4.6), mat=white)]
    for sx in (-1, 1):
        parts.append(mk.box("ShelfPost", (0.12, 0.6, 3.3), (sx * 2.45, 1.0, 4.6), mat=steel))
    for k in range(4):
        parts.append(mk.box("Door", (1.15, 0.04, 2.3), (-1.85 + k * 1.23, -1.21, 1.35), mat=white))
        parts += pk.handle("Pull", -1.85 + k * 1.23 + 0.4, -1.23, 2.0, 0.5, steel, stand=0.08, r=0.03)
    for k, rgb in enumerate(((140, 60, 30), (40, 90, 60), (230, 230, 226), (60, 60, 140), (140, 30, 40), (200, 170, 60))):
        parts += pk.bottle("Reagent", -2.1 + k * 0.85, 1.0, 6.15, pk.plastic(f"Lab_Reagent{k}", rgb), dark, r=0.18, h=0.8)
    parts += monitor("Scope_", x, y, z, w, h, tilt, dark)
    # The microscope: base, arm, stage, turret and eyepieces, at the right front.
    mx, my = 1.8, -0.35
    parts += [mk.box("MBase", (0.9, 1.2, 0.2), (mx, my, 3.06), mat=white, bevel=0.05),
              mk.box("MArm", (0.3, 0.3, 1.5), (mx, my + 0.4, 3.8), mat=white, bevel=0.05),
              mk.box("MStage", (0.8, 0.7, 0.1), (mx, my - 0.05, 3.6), mat=dark),
              mk.cylinder("MTurret", 0.2, 0.3, (mx, my - 0.05, 4.2), mat=steel, verts=12),
              mk.tube("MTube", (mx, my + 0.1, 4.35), (mx, my - 0.3, 4.9), 0.1, mat=white, verts=10),
              mk.cylinder("MEye", 0.07, 0.3, (mx, my - 0.35, 5.0), rot=(-40, 0, 0), mat=dark, verts=8)]
    parts.append(mk.box("Rack", (1.2, 0.4, 0.3), (-1.8, -0.6, 3.1), mat=white))
    for k in range(5):
        parts.append(mk.cylinder("Tube", 0.06, 0.7, (-2.25 + k * 0.22, -0.6, 3.4), mat=glass, verts=8))
    glows = [mk.box("TubeGlow", (0.9, 0.05, 0.2), (-1.8, -0.82, 3.4), mat=pk.glow("Lab_Sample", (80, 255, 140), 2))]
    return parts, glows
