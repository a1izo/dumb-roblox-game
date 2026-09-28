"""Kagegaoka University's props (set "Campus", exported to InkboundModels_Campus.fbx): a winter
campus on the eve of the entrance exam.

- Six station looks: the camera post in the pond hollow, the green public phone in the
  cafeteria, the student newspaper's desk, the library's book-return counter, the exam paper
  vault, and the forensic medicine lab's autopsy table.
- The grounds under snow: bare ginkgos, a pine in its yukizuri snow ropes, clipped shrubs,
  stone lanterns, a snowman, snow scoops and salt, the Meiji-style campus lamp, a notice
  board, a tatekan signboard.
- The exam: the check-in tent, kerosene heaters, exam desks, the lectern, sign stands and
  queue posts.
- The rooms: the library's reading table, card catalogue and book cart; the science
  building's skeleton, specimen cabinet and microscope; the club house's kotatsu, shoe lockers,
  drum kit, piano, film projector and typewriter; the cafeteria's tray return and an umbrella
  stand.
- Outside: the tennis court's umpire chair and snowed-on net, and the founder's bust.

Built to the semi-real standard (propkit): real sizes at about 3.5 studs to the metre, bevelled
edges, baked colour and ambient occlusion. Props face -Y and stand on z = 0. Station looks
follow props_stations.py: the game's invisible desk (5 x 3 x 2.4) stands on the design origin
with the worker in front at -Y, and the game's screen goes in the prop's `screen` slot.
Tabletop things (microscope, typewriter) stand on z = 0 too; the map lifts them to the surface.

Every glow material has a name of its own per colour (modelkit reuses a material by name within
a build, whatever colour is asked for)."""

import math
import random

import modelkit as mk
import propkit as pk
from common import srgb
from props import prop
from props_stations import desk, monitor

LAMP_WARM = (255, 210, 150)
SNOW_A, SNOW_B = (214, 222, 236), (246, 248, 252)


def snow(prefix="Cps"):
    return mk.noisy(prefix + "_Snow", srgb(*SNOW_A), srgb(*SNOW_B), scale=22, roughness=0.85)


def cap(name, size, loc, mat, r=0.12):
    """A soft cushion of snow lying on something."""
    return pk.rounded(name, size, loc, mat, r=min(r, min(size) / 2 - 0.01))


def crt(prefix, x, y, z, w, h, housing, bezel, depth=2.0, tilt=0):
    """A CRT monitor round a screen slot centred at (x, y, z) facing -Y (the game's screen fills
    the face): a bezel, the deep body and the tube behind it."""
    return [mk.box(prefix + "Bezel", (w + 0.5, 0.35, h + 0.5), (x, y + 0.17, z), rot=(-tilt, 0, 0), mat=bezel, bevel=0.08),
            mk.box(prefix + "Body", (w + 0.2, depth * 0.55, h + 0.2), (x, y + 0.35 + depth * 0.27, z), mat=housing,
                   bevel=0.1),
            mk.box(prefix + "Tube", (w * 0.62, depth * 0.45, h * 0.62), (x, y + 0.35 + depth * 0.72, z + 0.05),
                   mat=housing, bevel=0.15)]


# Station looks -----------------------------------------------------------------------------------------

CAMPOST_SCREEN = (0.0, -0.16, 3.95, 2.2, 1.5, 0)


@prop("StationCameraPost", pivot="bottom", material="Metal", collide=False, texture=1024, set="Campus", anchor=(0, 0),
      screen=CAMPOST_SCREEN)
def station_camera_post():
    """Campus security's camera post in the pond hollow: a weatherproof equipment box as wide as
    the station's desk, a hooded monitor cabinet on it (the game's screen), and behind them a
    steel pole with the camera on its arm looking out over the pond. Snow on every top."""
    steel = pk.paint("Cam_Steel", (104, 116, 110), rough=0.5)
    dark = pk.metal("Cam_Dark", (24, 26, 28), (40, 42, 46), rough=0.5, metallic=0.3)
    galv = pk.metal("Cam_Galv", (120, 124, 128), (152, 156, 160), rough=0.45, metallic=0.5)
    concrete = mk.noisy("Cam_Concrete", srgb(108, 106, 102), srgb(136, 134, 130), scale=12, roughness=0.85)
    white = pk.plastic("Cam_White", (226, 228, 226))
    plate = pk.plastic("Cam_Plate", (236, 200, 40))
    ink = pk.plastic("Cam_Ink", (20, 20, 20))
    sn = snow("Cam")
    x, y, z, w, h, tilt = CAMPOST_SCREEN
    parts = [mk.box("Plinth", (5.3, 2.9, 0.3), (0, 0, 0.15), mat=concrete, bevel=0.04),
             mk.box("Box", (5.0, 2.6, 2.1), (0, 0, 1.35), mat=steel, bevel=0.05),
             mk.box("BoxLid", (5.2, 2.8, 0.14), (0, 0, 2.45), mat=steel, bevel=0.03)]
    parts += pk.louvres("Vent", -1.4, -1.31, 1.3, 1.6, 1.0, dark)
    parts += pk.handle("Pull", 1.5, -1.31, 1.4, 0.7, dark, vertical=True, stand=0.08, r=0.04)
    parts.append(mk.box("Seam", (0.04, 0.03, 1.9), (0.4, -1.31, 1.35), mat=dark))
    parts += pk.label("Warning", "防犯カメラ作動中", 0.2, (1.1, -1.33, 2.0), ink, plate=plate)
    # The monitor cabinet on the box, its hood keeping the snow off the screen.
    parts += [mk.box("Cabinet", (2.9, 1.3, 2.8), (x, 0.55, 3.85), mat=steel, bevel=0.05),
              mk.box("Bezel", (w + 0.4, 0.12, h + 0.4), (x, -0.06, z), mat=dark, bevel=0.03),
              mk.box("Hood", (3.1, 1.1, 0.1), (x, -0.35, 5.35), rot=(-12, 0, 0), mat=steel, bevel=0.02),
              mk.box("CabTop", (3.0, 1.4, 0.1), (x, 0.55, 5.3), mat=steel)]
    # The pole, the arm and the camera.
    parts += [mk.cylinder("PoleFoot", 0.3, 0.4, (1.9, 0.9, 2.7), mat=galv, verts=12),
              mk.cylinder("Pole", 0.17, 11.0, (1.9, 0.9, 8.0), mat=galv, verts=12, radius2=0.13),
              mk.tube("Arm", (1.9, 0.9, 12.8), (1.9, -0.6, 13.1), 0.09, mat=galv, verts=8),
              mk.box("CamMount", (0.3, 0.3, 0.5), (1.9, -0.6, 12.85), mat=dark),
              mk.box("Camera", (0.7, 1.9, 0.62), (1.9, -1.1, 12.5), rot=(-18, 0, 0), mat=white, bevel=0.08),
              mk.box("Visor", (0.86, 1.3, 0.08), (1.9, -1.35, 12.95), rot=(-18, 0, 0), mat=white),
              mk.cylinder("Lens", 0.2, 0.1, (1.9, -2.03, 12.2), rot=(72, 0, 0), mat=dark, verts=12)]
    for k in range(3):
        parts.append(mk.tube("Conduit", (1.8, 0.95, 3.0 + k * 0.01), (1.2, 0.95, 2.5), 0.05, mat=dark, verts=5))
    # Snow on the tops.
    parts += [cap("SnowBoxL", (1.9, 2.6, 0.24), (-1.55, 0.05, 2.6), sn),
              cap("SnowBoxR", (0.9, 2.2, 0.2), (2.05, -0.2, 2.6), sn),
              cap("SnowHood", (2.9, 1.1, 0.2), (x, -0.3, 5.5), sn),
              cap("SnowCam", (0.6, 1.4, 0.18), (1.9, -1.2, 12.95), sn),
              cap("SnowPlinth", (5.2, 0.4, 0.12), (0, -1.35, 0.33), sn, r=0.05)]
    glows = [mk.box("Led", (0.14, 0.04, 0.14), (1.2, -0.13, 5.0), mat=pk.glow("Cam_LedGreen", (80, 255, 140), 5)),
             mk.cylinder("Rec", 0.06, 0.04, (1.9, -2.06, 12.55), rot=(72, 0, 0), mat=pk.glow("Cam_LedRed", (255, 40, 40), 6),
                         verts=8)]
    return parts, glows


PUBPHONE_SCREEN = (0.9, 1.05, 4.95, 2.3, 1.4, 0)


@prop("StationPublicPhone", pivot="bottom", material="Wood", collide=False, texture=1024, set="Campus", anchor=(0, 0),
      screen=PUBPHONE_SCREEN)
def station_public_phone():
    """The cafeteria's public telephone corner: a wooden shelf unit with the directories in its
    cubby, the grey-green digital public phone with its little LCD and handset on it, and on the
    tiled back panel the lit 公衆電話 sign and the call information display (the game's
    screen)."""
    wood = mk.wood("Pub_Wood", srgb(128, 88, 56), srgb(74, 48, 30), scale=4)
    tile = mk.noisy("Pub_Tile", srgb(196, 196, 186), srgb(218, 218, 208), scale=30, roughness=0.3)
    green = pk.paint("Pub_Green", (90, 128, 104), rough=0.35)
    grey = pk.plastic("Pub_Grey", (170, 176, 172))
    dark = pk.metal("Pub_Dark", (22, 24, 24), (38, 40, 40), rough=0.5, metallic=0.2)
    book = pk.plastic("Pub_Book", (220, 196, 90))
    book2 = pk.plastic("Pub_Book2", (200, 60, 50))
    ink = pk.plastic("Pub_Ink", (250, 250, 246))
    x, y, z, w, h, tilt = PUBPHONE_SCREEN
    parts = [mk.box("Body", (5.0, 2.4, 2.8), (0, 0.05, 1.4), mat=wood, bevel=0.04),
             mk.box("Top", (5.2, 2.6, 0.12), (0, 0.05, 2.86), mat=wood, bevel=0.03),
             mk.box("Cubby", (2.2, 0.1, 1.3), (1.2, -1.16, 1.1), mat=dark),
             mk.box("Back", (5.0, 0.2, 4.8), (0, 1.25, 5.3), mat=tile),
             mk.box("SignBox", (3.2, 0.5, 0.8), (0, 1.0, 7.4), mat=green, bevel=0.05)]
    for k, m in enumerate((book, book2, book)):
        parts.append(mk.box("Directory", (0.5, 1.6, 1.1), (0.5 + k * 0.6, -0.2, 1.1), mat=m, bevel=0.03))
    # The phone.
    px = -1.3
    parts += [pk.rounded("Phone", (1.3, 0.9, 1.8), (px, 0.55, 3.8), green, r=0.12),
              pk.rounded("PhoneFace", (1.1, 0.1, 1.2), (px, 0.08, 3.85), grey, r=0.04),
              pk.rounded("Handset", (0.3, 0.32, 1.35), (px - 0.83, 0.4, 3.9), green, r=0.1),
              mk.box("Keypad", (0.6, 0.05, 0.55), (px + 0.1, 0.02, 3.55), mat=dark),
              mk.box("CoinSlot", (0.36, 0.05, 0.08), (px + 0.3, 0.02, 4.3), mat=dark),
              mk.box("CardSlot", (0.5, 0.05, 0.05), (px - 0.2, 0.02, 3.2), mat=dark),
              mk.tube("Cord", (px - 0.83, 0.4, 3.2), (px - 0.55, 0.3, 3.05), 0.03, mat=dark, verts=4)]
    parts += monitor("Info_", x, y, z, w, h, tilt, dark, stand=False)
    parts += pk.label("SignText", "公衆電話", 0.42, (0, 0.73, 7.4), ink)
    glows = [mk.box("SignGlow", (3.0, 0.04, 0.62), (0, 0.74, 7.4), mat=pk.glow("Pub_Sign", (120, 220, 150), 2.2)),
             mk.box("Lcd", (0.6, 0.04, 0.26), (px, 0.02, 4.2), mat=pk.glow("Pub_Lcd", (170, 240, 160), 2))]
    return parts, glows


NEWS_SCREEN = (-0.7, 0.1, 4.2, 2.1, 1.6, 6)


@prop("StationNewsDesk", pivot="bottom", material="Wood", collide=False, texture=1024, set="Campus", anchor=(0, 0),
      screen=NEWS_SCREEN)
def station_news_desk():
    """The student newspaper's desk: a scarred wooden desk buried in proofs, a beige word
    processor (the game's screen), a black rotary phone, an answering machine blinking red,
    stacked back issues, a mug of pens and a clip lamp."""
    wood = mk.wood("News_Wood", srgb(112, 76, 46), srgb(60, 40, 24), scale=4)
    beige = pk.plastic("News_Beige", (190, 180, 158))
    bezel = pk.plastic("News_Bezel", (70, 66, 60))
    dark = pk.metal("News_Dark", (18, 18, 20), (32, 32, 36), rough=0.4, metallic=0.2)
    paper = pk.plastic("News_Paper", (230, 226, 212))
    newsprint = mk.noisy("News_Print", srgb(196, 192, 180), srgb(222, 218, 206), scale=40, roughness=0.9)
    red = pk.plastic("News_Mug", (170, 40, 40))
    x, y, z, w, h, tilt = NEWS_SCREEN
    parts = desk("News_", wood, wood)
    parts.append(mk.box("Pedestal", (1.5, 2.3, 2.7), (1.75, -0.05, 1.35), mat=wood, bevel=0.03))
    parts += crt("WP_", x, y, z, w, h, beige, bezel, depth=1.8, tilt=tilt)
    parts += [mk.box("WPBase", (1.9, 1.4, 0.26), (x, y + 0.9, 3.03), mat=beige, bevel=0.05),
              mk.box("Keyboard", (2.1, 0.8, 0.12), (x, -0.85, 2.98), rot=(4, 0, 0), mat=beige, bevel=0.03)]
    # The rotary phone and the answering machine.
    parts += [pk.rounded("PhoneBody", (0.9, 1.0, 0.45), (1.55, -0.45, 3.12), dark, r=0.12),
              mk.cylinder("Dial", 0.3, 0.06, (1.55, -0.62, 3.36), rot=(20, 0, 0), mat=paper, verts=16),
              pk.rounded("Handset", (1.1, 0.3, 0.26), (1.55, -0.35, 3.48), dark, r=0.1),
              mk.box("Machine", (1.1, 0.8, 0.3), (1.6, 0.6, 3.05), mat=beige, bevel=0.05),
              mk.box("Cassette", (0.6, 0.05, 0.14), (1.5, 0.19, 3.1), mat=dark)]
    # Proofs and back issues.
    rng = random.Random(7)
    for k in range(6):
        parts.append(mk.box("Proof", (1.2, 1.6, 0.03), (-2.0 + rng.uniform(-0.2, 0.2), -0.3 + rng.uniform(-0.2, 0.2),
                                                           2.95 + k * 0.03), rot=(0, 0, rng.uniform(-12, 12)), mat=paper))
    parts += [mk.box("Stack", (1.6, 2.2, 1.1), (-1.6, 2.1, 0.55), mat=newsprint, bevel=0.03),
              mk.box("Stack2", (1.6, 2.2, 0.8), (1.0, 2.1, 0.4), rot=(0, 0, 8), mat=newsprint, bevel=0.03),
              mk.cylinder("Mug", 0.2, 0.45, (-2.2, 0.8, 3.12), mat=red, verts=12)]
    for k in range(3):
        parts.append(mk.tube("Pen", (-2.2 + k * 0.08 - 0.08, 0.8, 3.2), (-2.25 + k * 0.1, 0.75, 3.75), 0.03, mat=dark,
                             verts=4))
    parts += [mk.box("ClipBase", (0.3, 0.3, 0.3), (-2.4, 1.1, 3.05), mat=dark),
              mk.tube("ClipArm", (-2.4, 1.1, 3.2), (-2.1, 0.7, 4.6), 0.04, mat=dark, verts=5),
              mk.lathe("ClipShade", [(0.1, 0), (0.35, -0.4), (0.0, -0.4)], (-2.05, 0.6, 4.75), mat=dark, segments=12)]
    glows = [mk.box("MsgLed", (0.1, 0.04, 0.1), (1.95, 0.19, 3.12), mat=pk.glow("News_Led", (255, 40, 40), 6)),
             mk.cylinder("ClipBulb", 0.22, 0.04, (-2.05, 0.6, 4.36), mat=pk.glow("News_Bulb", LAMP_WARM, 3), verts=12)]
    return parts, glows


BOOKRET_SCREEN = (0.9, 0.25, 4.75, 2.2, 1.4, 10)


@prop("StationBookReturn", pivot="bottom", material="Wood", collide=False, texture=1024, set="Campus", anchor=(0, 0),
      screen=BOOKRET_SCREEN)
def station_book_return():
    """The library's book-return counter: oak panelling toward the reader with the brass return
    slot, the circulation terminal on it (the game's screen), a fingerprint kit opened on a
    returned book, a UV lamp glowing violet, the date stamp and a pile of returns."""
    oak = mk.wood("Ret_Oak", srgb(150, 106, 64), srgb(92, 60, 34), scale=4)
    top = mk.noisy("Ret_Top", srgb(60, 44, 34), srgb(80, 60, 46), scale=10, roughness=0.3)
    brass = pk.metal("Ret_Brass", (160, 126, 64), (206, 170, 96), rough=0.3, metallic=0.9)
    dark = pk.metal("Ret_Dark", (20, 20, 22), (34, 34, 38), rough=0.5, metallic=0.2)
    case = pk.metal("Ret_Case", (26, 28, 32), (44, 46, 52), rough=0.4)
    card = pk.plastic("Ret_Card", (240, 238, 230))
    ink = pk.plastic("Ret_Ink", (30, 26, 20))
    x, y, z, w, h, tilt = BOOKRET_SCREEN
    parts = [mk.box("Front", (5.2, 0.35, 3.4), (0, -1.1, 1.7), mat=oak, bevel=0.04),
             mk.box("Plinth", (5.3, 0.5, 0.3), (0, -1.05, 0.15), mat=top),
             mk.box("Counter", (5.4, 1.3, 0.14), (0, -0.85, 3.47), mat=top, bevel=0.03),
             mk.box("Work", (5.0, 1.8, 0.12), (0, 0.4, 2.88), mat=oak),
             mk.box("Body", (5.0, 1.8, 2.8), (0, 0.4, 1.4), mat=oak),
             mk.box("Slot", (1.6, 0.06, 0.9), (-1.2, -1.3, 2.4), mat=brass, bevel=0.03),
             mk.box("SlotMouth", (1.2, 0.07, 0.18), (-1.2, -1.32, 2.55), mat=dark)]
    parts += pk.label("SlotLabel", "返却 RETURNS", 0.16, (-1.2, -1.34, 2.15), ink)
    for k in range(4):
        parts.append(mk.box("Panel", (1.1, 0.06, 1.8), (-1.8 + k * 1.2, -1.29, 1.2), mat=oak, bevel=0.02))
    parts += monitor("Term_", x, y, z, w, h, tilt, dark, stand_to=2.94)
    # The print kit on a returned book, the UV lamp, stamp and returns.
    parts += [mk.box("Book", (1.1, 1.5, 0.2), (-1.0, -0.2, 3.04), rot=(0, 0, -8), mat=pk.plastic("Ret_Cover", (40, 70, 110))),
              mk.box("Case", (1.4, 0.9, 0.3), (-2.0, 0.6, 3.05), mat=case, bevel=0.04),
              mk.box("Lid", (1.4, 0.08, 0.9), (-2.0, 1.1, 3.4), rot=(-20, 0, 0), mat=case)]
    for k, rgb in enumerate(((20, 20, 22), (230, 230, 226), (190, 150, 50))):
        parts.append(mk.cylinder(f"Jar{k}", 0.12, 0.28, (-2.4 + k * 0.35, 0.55, 3.34), mat=pk.plastic(f"Ret_Jar{k}", rgb),
                                 verts=10))
    parts += [mk.tube("Brush", (-0.6, -0.5, 3.18), (-0.3, -0.1, 3.18), 0.03, mat=dark, verts=5),
              mk.box("Cards", (0.8, 0.6, 0.04), (0.2, -0.5, 2.96), rot=(0, 0, 5), mat=card),
              mk.box("UVLamp", (0.35, 1.0, 0.3), (-0.2, 0.5, 3.1), rot=(0, 0, 30), mat=dark, bevel=0.05),
              mk.cylinder("Stamp", 0.12, 0.35, (2.2, -0.6, 3.1), mat=dark, verts=10),
              mk.cylinder("StampKnob", 0.16, 0.14, (2.2, -0.6, 3.34), mat=brass, verts=10)]
    rng = random.Random(3)
    for k in range(5):
        c = rng.choice(((110, 40, 36), (40, 60, 90), (60, 80, 50), (140, 120, 80), (70, 50, 70)))
        parts.append(mk.box(f"Return{k}", (1.0, 1.4, 0.26), (2.1 + rng.uniform(-0.1, 0.1), 0.9, 3.0 + k * 0.27),
                            rot=(0, 0, rng.uniform(-10, 10)), mat=pk.plastic(f"Ret_Ret{k}", c)))
    glows = [mk.box("UVGlow", (0.28, 0.7, 0.03), (-0.2, 0.5, 2.94), rot=(0, 0, 30), mat=pk.glow("Ret_UV", (150, 90, 255), 4))]
    return parts, glows


VAULT_SCREEN = (1.2, 0.35, 4.4, 2.2, 1.4, 8)


@prop("StationVault", pivot="bottom", material="Metal", collide=False, texture=1024, set="Campus", anchor=(0, 0),
      screen=VAULT_SCREEN)
def station_vault():
    """Student affairs' exam paper vault: a round steel vault door in its heavy frame against the
    wall, and in front the steel table where tomorrow's sealed exam boxes wait, a print-lifting
    kit and a torch beside them, and the access terminal (the game's screen)."""
    steel = pk.metal("Vault_Steel", (96, 100, 106), (132, 136, 142), rough=0.35, metallic=0.8)
    frame = pk.metal("Vault_Frame", (54, 56, 60), (78, 80, 86), rough=0.45, metallic=0.6)
    chrome = pk.chrome("Vault_Chrome")
    dark = pk.metal("Vault_Dark", (20, 20, 22), (34, 34, 38), rough=0.5, metallic=0.2)
    top = mk.noisy("Vault_Top", srgb(120, 122, 126), srgb(150, 152, 156), scale=10, roughness=0.4)
    cardboard = mk.noisy("Vault_Box", srgb(160, 120, 76), srgb(186, 146, 100), scale=16, roughness=0.8)
    seal = pk.plastic("Vault_Seal", (180, 30, 36))
    label = pk.plastic("Vault_Label", (240, 238, 228))
    x, y, z, w, h, tilt = VAULT_SCREEN
    dx, dz, r = -1.0, 4.6, 2.5
    parts = [mk.box("Frame", (7.0, 0.9, 9.0), (-0.4, 1.9, 4.5), mat=frame, bevel=0.06),
             mk.cylinder("Door", r, 0.6, (dx, 1.25, dz), rot=(90, 0, 0), mat=steel, verts=40, bevel=0.06),
             mk.torus("DoorRing", r - 0.2, 0.1, (dx, 0.95, dz), rot=(90, 0, 0), mat=chrome, major_segments=40,
                      minor_segments=6),
             mk.cylinder("Hub", 0.45, 0.3, (dx, 0.8, dz), rot=(90, 0, 0), mat=chrome, verts=20),
             mk.torus("Wheel", 1.1, 0.09, (dx, 0.6, dz), rot=(90, 0, 0), mat=chrome, major_segments=24, minor_segments=6)]
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        parts.append(mk.tube("Spoke", (dx, 0.62, dz), (dx + math.cos(a) * 1.1, 0.62, dz + math.sin(a) * 1.1), 0.06,
                             mat=chrome, verts=6))
    for k in range(12):
        a = 2 * math.pi * k / 12
        parts.append(mk.cylinder("Bolt", 0.13, 0.2, (dx + math.cos(a) * (r - 0.45), 0.9, dz + math.sin(a) * (r - 0.45)),
                                 rot=(90, 0, 0), mat=chrome, verts=8))
    parts += [mk.box("Hinge", (0.5, 0.7, 1.2), (dx + r + 0.1, 1.2, dz + 1.2), mat=frame, bevel=0.05),
              mk.box("Hinge", (0.5, 0.7, 1.2), (dx + r + 0.1, 1.2, dz - 1.2), mat=frame, bevel=0.05)]
    parts += desk("Vault_", top, steel, modesty=False)
    parts += monitor("Access_", x, y, z, w, h, tilt, dark)
    # The sealed exam boxes and the print kit.
    for k, (bx, by, bz, rot) in enumerate(((-1.8, 0.2, 2.9, 4), (-1.8, 0.2, 3.7, -6), (-0.3, 0.3, 2.9, -3))):
        parts += [mk.box(f"ExamBox{k}", (1.5, 1.2, 0.8), (bx, by, bz + 0.4), rot=(0, 0, rot), mat=cardboard, bevel=0.03),
                  mk.box(f"Seal{k}", (0.22, 1.24, 0.82), (bx, by, bz + 0.4), rot=(0, 0, rot), mat=seal),
                  mk.box(f"Label{k}", (0.8, 0.02, 0.4), (bx + 0.35, by - 0.61, bz + 0.45), rot=(0, 0, rot), mat=label)]
    parts += [mk.box("KitCase", (1.1, 0.8, 0.26), (0.9, -0.75, 3.03), mat=dark, bevel=0.04),
              mk.box("Tape", (0.3, 0.3, 0.3), (1.8, -0.8, 3.05), mat=label, bevel=0.1),
              mk.cylinder("Torch", 0.1, 0.9, (-0.9, -0.8, 3.0), rot=(0, 90, 20), mat=dark, verts=10)]
    glows = [mk.box("KeyLed", (0.12, 0.04, 0.12), (2.4, 1.43, 6.2), mat=pk.glow("Vault_LedRed", (255, 50, 40), 5)),
             mk.box("KeyLed2", (0.12, 0.04, 0.12), (2.7, 1.43, 6.2), mat=pk.glow("Vault_LedGreen", (80, 255, 140), 5))]
    parts.append(mk.box("Keypad", (0.9, 0.1, 1.3), (2.55, 1.42, 5.6), mat=dark, bevel=0.03))
    return parts, glows


AUTOPSY_SCREEN = (1.5, 1.0, 5.2, 2.2, 1.4, 6)


@prop("StationAutopsy", pivot="bottom", material="Metal", collide=False, texture=1024, set="Campus", anchor=(0, 0),
      screen=AUTOPSY_SCREEN,
      lights=[dict(at=(0, -0.1, 8.1), kind="spot", face="Bottom", angle=70, color=(230, 240, 255), range=14,
                   brightness=1.3)])
def station_autopsy():
    """The forensic medicine lab's autopsy table: a stainless top with its raised lip and drain
    on a pedestal, a folded sheet and the head block, the surgical lamp swung over it, an
    instrument tray on its stand, the hanging scale, and the findings monitor on its arm (the
    game's screen)."""
    steel = pk.metal("Aut_Steel", (160, 164, 170), (200, 204, 210), rough=0.25, metallic=0.9)
    dark = pk.metal("Aut_Dark", (22, 24, 26), (40, 42, 46), rough=0.5, metallic=0.3)
    white = pk.plastic("Aut_White", (230, 232, 230))
    sheet = pk.plastic("Aut_Sheet", (214, 226, 224))
    x, y, z, w, h, tilt = AUTOPSY_SCREEN
    parts = [mk.box("Base", (2.4, 1.6, 0.2), (0, 0, 0.1), mat=steel, bevel=0.04),
             mk.cylinder("Pedestal", 0.55, 2.4, (0, 0, 1.4), mat=steel, verts=16),
             mk.box("Top", (5.4, 2.5, 0.2), (0, 0, 2.8), mat=steel, bevel=0.05)]
    for sy in (-1, 1):
        parts.append(mk.box("LipL", (5.4, 0.12, 0.2), (0, sy * 1.2, 3.0), mat=steel))
    for sx in (-1, 1):
        parts.append(mk.box("LipE", (0.12, 2.5, 0.2), (sx * 2.65, 0, 3.0), mat=steel))
    parts += [mk.cylinder("Drain", 0.18, 0.04, (2.3, 0, 2.92), mat=dark, verts=12),
              mk.box("HeadBlock", (0.6, 1.0, 0.35), (-2.2, 0, 3.05), mat=dark, bevel=0.1),
              mk.box("Sheet", (1.2, 1.9, 0.18), (1.4, 0.1, 3.0), mat=sheet, bevel=0.06)]
    # The surgical lamp on its column at the back left, its arm over the table.
    parts += [mk.cylinder("ColBase", 0.7, 0.2, (-2.9, 1.8, 0.1), mat=white, verts=16),
              mk.cylinder("Column", 0.16, 8.8, (-2.9, 1.8, 4.5), mat=white, verts=12),
              mk.tube("Arm1", (-2.9, 1.8, 8.9), (-1.2, 0.6, 9.0), 0.1, mat=white, verts=8),
              mk.tube("Arm2", (-1.2, 0.6, 9.0), (0, -0.1, 8.7), 0.09, mat=white, verts=8),
              mk.lathe("LampHead", [(0.2, 0.3), (0.95, 0.0), (1.0, -0.15), (0.0, -0.15)], (0, -0.1, 8.5), mat=white,
                       segments=24)]
    # The instrument tray on its stand, front right.
    parts += [mk.cylinder("TrayFoot", 0.5, 0.1, (3.3, -1.1, 0.05), mat=steel, verts=12),
              mk.cylinder("TrayPost", 0.07, 3.3, (3.3, -1.1, 1.7), mat=steel, verts=8),
              mk.box("Tray", (1.6, 1.1, 0.1), (3.0, -1.1, 3.35), mat=steel, bevel=0.03)]
    for k in range(5):
        parts.append(mk.box("Tool", (0.06, 0.8, 0.04), (2.55 + k * 0.2, -1.1, 3.42), mat=steel))
    # The hanging scale and the monitor on its arm, back right.
    parts += [mk.cylinder("ScalePole", 0.1, 8.0, (2.9, 1.8, 4.0), mat=white, verts=10),
              mk.tube("ScaleArm", (2.9, 1.8, 7.6), (2.9, 0.9, 7.6), 0.06, mat=white, verts=6),
              mk.cylinder("ScaleDial", 0.45, 0.2, (2.9, 0.9, 6.9), rot=(90, 0, 0), mat=white, verts=16),
              mk.lathe("ScaleDish", [(0.0, 0.0), (0.7, 0.15), (0.75, 0.3)], (2.9, 0.9, 5.9), mat=steel, segments=16),
              mk.tube("MonArm", (2.9, 1.8, 5.8), (x + 0.3, y + 0.3, z), 0.07, mat=dark, verts=6)]
    parts += monitor("Findings_", x, y, z, w, h, tilt, dark, stand=False)
    glows = [mk.cylinder("LampGlow", 0.85, 0.04, (0, -0.1, 8.33), mat=pk.glow("Aut_Lamp", (230, 240, 255), 4), verts=24)]
    return parts, glows


# The grounds under snow ------------------------------------------------------------------------------


def _limb(parts, snowy, rng, start, direction, length, radius, depth, bark, spread, rise, droop, tips):
    """A limb as two bent tapered tubes, then its children (like the Tokyo trees), recording each
    segment for the snow that settles on the flatter ones."""
    dx, dy, dz = direction
    end = (start[0] + dx * length, start[1] + dy * length, start[2] + dz * length)
    mid = (start[0] + dx * length * 0.5 + rng.uniform(-0.3, 0.3) * length * 0.12,
           start[1] + dy * length * 0.5 + rng.uniform(-0.3, 0.3) * length * 0.12,
           start[2] + dz * length * 0.5 + length * 0.04)
    tip_r = radius * 0.62
    verts = 7 if radius > 0.25 else 5
    parts.append(mk.tube("Limb", start, mid, radius, (radius + tip_r) / 2, mat=bark, verts=verts))
    parts.append(mk.tube("Limb", mid, end, (radius + tip_r) / 2, tip_r, mat=bark, verts=verts))
    snowy.append((start, mid, radius))
    snowy.append((mid, end, (radius + tip_r) / 2))
    if depth == 0:
        tips.append(end)
        return
    base = math.atan2(dy, dx)
    count = 2 if depth > 1 else rng.choice((2, 3))
    for k in range(count):
        yaw = base + rng.uniform(-spread, spread) + (k - (count - 1) / 2) * spread * 0.8
        pitch = math.atan2(dz, math.hypot(dx, dy)) + rng.uniform(-0.2, 0.2) + rise - droop * (3 - depth) * 0.2
        pitch = max(-0.3, min(1.4, pitch))
        nd = (math.cos(pitch) * math.cos(yaw), math.cos(pitch) * math.sin(yaw), math.sin(pitch))
        _limb(parts, snowy, rng, end, nd, length * rng.uniform(0.6, 0.76), tip_r, depth - 1, bark, spread, rise, droop,
              tips)


def _snow_on(parts, snowy, sn, rng, min_r=0.12, steep=0.85):
    """Snow lying along the top of every limb that is thick enough and not too steep."""
    for a, b, r in snowy:
        run = math.dist(a, b)
        if r < min_r or run < 0.3:
            continue
        rise = (b[2] - a[2]) / run
        if rise > steep:
            continue
        lift = r * 0.75
        parts.append(mk.tube("Snow", (a[0], a[1], a[2] + lift), (b[0], b[1], b[2] + lift * 0.9), r * 0.62, r * 0.5, mat=sn,
                             verts=5))


@prop("GinkgoBare", pivot="bottom", material="SmoothPlastic", collide=False, texture=1024, set="Campus", anchor=(0, 0))
def ginkgo_bare():
    """A winter ginkgo of the avenue, its leaves long gone: a tall straight trunk with limbs all
    the way up it, rising steeply and shorter towards the top (the ginkgo's columnar crown),
    snow lying along the flatter limbs, a snowy ring round its foot."""
    rng = random.Random(29)
    bark = mk.noisy("Gnk_Bark", srgb(52, 46, 42), srgb(92, 84, 76), scale=10, roughness=0.9, stretch=(1, 1, 0.25))
    sn = snow("Gnk")
    parts, snowy, tips = [], [], []
    trunk_h, trunk_r = 24.0, 0.95
    parts.append(mk.cylinder("Flare", trunk_r * 1.6, 0.8, (0, 0, 0.4), mat=bark, verts=10, radius2=trunk_r))
    parts.append(mk.tube("Trunk", (0, 0, 0.7), (0.2, -0.1, trunk_h), trunk_r, 0.28, mat=bark, verts=10))
    levels = 11
    for k in range(levels):
        t = k / (levels - 1)
        zz = 7.0 + t * (trunk_h - 8.0)
        yaw = k * 2.4 + rng.uniform(-0.3, 0.3)
        pitch = 0.55 + t * 0.5
        d = (math.cos(pitch) * math.cos(yaw), math.cos(pitch) * math.sin(yaw), math.sin(pitch))
        r = trunk_r * (0.5 - 0.28 * t)
        length = 7.0 - 4.2 * t
        start = (0.2 * zz / trunk_h, -0.1 * zz / trunk_h, zz)
        _limb(parts, snowy, rng, start, d, length, r, 2, bark, 0.4, 0.35, 0.1, tips)
    _snow_on(parts, snowy, sn, rng)
    for tip in tips[::3]:
        parts.append(mk.sphere("TipSnow", 0.22, (tip[0], tip[1], tip[2] + 0.1), scale=(1, 1, 0.6), mat=sn, segments=6,
                               rings=4))
    parts.append(mk.cylinder("FootSnow", 1.9, 0.2, (0, 0, 0.1), mat=sn, verts=16, radius2=1.4))
    return parts, []


@prop("PineYukizuri", pivot="bottom", material="SmoothPlastic", collide=False, texture=1024, set="Campus", anchor=(0, 0))
def pine_yukizuri():
    """A black pine in its winter yukizuri: a leaning, twisting trunk with its needles in flat
    dark pads on long level branches, snow on every pad, and over it all the straw ropes fanned
    down from a bamboo mast to hold the branches up under the snow."""
    rng = random.Random(41)
    bark = mk.noisy("Pine_Bark", srgb(46, 38, 34), srgb(84, 70, 60), scale=12, roughness=0.9)
    needles = [mk.noisy("Pine_Needle1", srgb(20, 40, 28), srgb(40, 64, 42), scale=30, roughness=0.8),
               mk.noisy("Pine_Needle2", srgb(24, 46, 30), srgb(48, 72, 48), scale=30, roughness=0.8)]
    sn = snow("Pine")
    bamboo = mk.noisy("Pine_Bamboo", srgb(150, 132, 84), srgb(186, 168, 112), scale=20, roughness=0.6)
    rope = mk.noisy("Pine_Rope", srgb(170, 150, 100), srgb(206, 188, 136), scale=30, roughness=0.9)
    parts = [mk.cylinder("Flare", 1.1, 0.6, (0, 0, 0.3), mat=bark, verts=10, radius2=0.7),
             mk.tube("Trunk1", (0, 0, 0.5), (0.8, 0.3, 5.0), 0.7, 0.55, mat=bark, verts=9),
             mk.tube("Trunk2", (0.8, 0.3, 5.0), (0.2, 0.6, 10.0), 0.55, 0.38, mat=bark, verts=9),
             mk.tube("Trunk3", (0.2, 0.6, 10.0), (0.5, 0.4, 13.5), 0.38, 0.2, mat=bark, verts=8)]
    pads = []
    for k in range(9):
        t = k / 8
        zz = 3.5 + t * 9.5
        yaw = k * 2.2 + rng.uniform(-0.3, 0.3)
        length = 6.5 - 3.8 * t + rng.uniform(-0.5, 0.5)
        sx = 0.8 - 0.6 * t
        start = (sx, 0.3 + 0.3 * t, zz)
        end = (start[0] + math.cos(yaw) * length, start[1] + math.sin(yaw) * length, zz + rng.uniform(-0.3, 0.8))
        parts.append(mk.tube("Branch", start, end, 0.28 - 0.15 * t, 0.12, mat=bark, verts=6))
        pads.append((end, 2.2 - 1.1 * t))
        mid = ((start[0] + end[0]) / 2, (start[1] + end[1]) / 2, (start[2] + end[2]) / 2 + 0.3)
        pads.append((mid, 1.4 - 0.6 * t))
    pads.append(((0.5, 0.4, 13.8), 1.4))
    for (cx, cy, cz), r in pads:
        parts.append(mk.sphere("Pad", r, (cx, cy, cz), scale=(1, 1, 0.38), mat=rng.choice(needles), segments=9, rings=5))
        parts.append(mk.sphere("PadSnow", r * 0.85, (cx, cy, cz + r * 0.22), scale=(1, 1, 0.22), mat=sn, segments=9,
                               rings=4))
    # The yukizuri: a bamboo mast from the trunk head, ropes fanned down to the pads and to a ring.
    top = (0.5, 0.4, 19.5)
    parts.append(mk.tube("Mast", (0.5, 0.4, 12.0), top, 0.12, 0.09, mat=bamboo, verts=6))
    parts.append(mk.cylinder("MastCap", 0.3, 0.5, (top[0], top[1], top[2] + 0.2), mat=rope, verts=8, radius2=0.05))
    for (cx, cy, cz), r in pads[::2]:
        parts.append(mk.tube("Rope", top, (cx, cy, cz + r * 0.3), 0.035, mat=rope, verts=3))
    for k in range(10):
        a = 2 * math.pi * k / 10
        parts.append(mk.tube("Rope", top, (0.5 + math.cos(a) * 6.5, 0.4 + math.sin(a) * 6.5, 3.0), 0.035, mat=rope, verts=3))
    parts.append(mk.cylinder("FootSnow", 1.6, 0.2, (0, 0, 0.1), mat=sn, verts=16, radius2=1.2))
    return parts, []


@prop("ShrubSnow", pivot="bottom", material="SmoothPlastic", collide=True, texture=512, set="Campus")
def shrub_snow():
    """A clipped azalea mound under snow: lumpy dark leaves, a thick white cap on top."""
    leaf = mk.noisy("Shrub_Leaf", srgb(22, 40, 26), srgb(44, 66, 40), scale=30, roughness=0.8)
    sn = snow("Shrub")
    parts = []
    for k, (x, y, r) in enumerate(((-0.9, 0.1, 1.5), (0.8, -0.1, 1.35), (0.0, 0.3, 1.2))):
        body = mk.sphere(f"Mound{k}", r, (x, y, r * 0.7), scale=(1.1, 0.9, 0.75), mat=leaf, segments=10, rings=6)
        mk.displace_noise(body, strength=0.12, scale=0.8, name="ShrubNoise")
        parts.append(body)
        parts.append(mk.sphere(f"Cap{k}", r * 0.9, (x, y, r * 0.95), scale=(1.1, 0.9, 0.52), mat=sn, segments=10, rings=5))
    return parts, []


@prop("StoneLantern", pivot="bottom", material="Slate", collide=True, texture=512, set="Campus",
      lights=[dict(at=(0, 0, 3.95), kind="point", color=(255, 180, 110), range=9, brightness=0.55)])
def stone_lantern():
    """A kasuga stone lantern: hexagonal base, a round pillar, the platform, the fire box with its
    windows (a candle burning inside), the curled roof under a cap of snow, the jewel on top."""
    granite = mk.noisy("Toro_Stone", srgb(96, 94, 90), srgb(132, 128, 122), scale=14, roughness=0.9)
    moss = mk.noisy("Toro_Moss", srgb(60, 72, 56), srgb(96, 104, 86), scale=18, roughness=0.9)
    sn = snow("Toro")
    dark = pk.metal("Toro_Dark", (18, 16, 14), (30, 28, 26), rough=0.8, metallic=0.0)
    parts = [mk.cylinder("Base", 1.1, 0.5, (0, 0, 0.25), mat=moss, verts=6),
             mk.cylinder("Base2", 0.8, 0.3, (0, 0, 0.65), mat=granite, verts=6),
             mk.cylinder("Pillar", 0.35, 1.9, (0, 0, 1.75), mat=granite, verts=12),
             mk.cylinder("Platform", 0.95, 0.35, (0, 0, 2.87), mat=granite, verts=6, radius2=0.8),
             mk.cylinder("FireBox", 0.72, 1.3, (0, 0, 3.7), mat=granite, verts=6),
             mk.lathe("Roof", [(0.2, 0.0), (1.35, 0.08), (1.45, 0.22), (1.2, 0.3), (0.5, 0.75), (0.2, 0.85), (0.0, 0.85)],
                      (0, 0, 4.35), mat=granite, segments=6),
             mk.lathe("RoofSnow", [(0.0, 0.0), (1.3, 0.1), (1.1, 0.34), (0.4, 0.62), (0.0, 0.66)], (0, 0, 4.63), mat=sn,
                      segments=6),
             mk.sphere("Jewel", 0.28, (0, 0, 5.45), scale=(1, 1, 1.2), mat=granite, segments=8, rings=6)]
    glows = []
    for k, rot in enumerate((0, 180)):
        a = math.radians(rot)
        glows.append(mk.box(f"Window{k}", (0.6, 0.04, 0.7), (0, math.cos(a) * -0.64, 3.7),
                            mat=pk.glow("Toro_Flame", (255, 170, 90), 3)))
    parts.append(mk.box("Grate", (0.64, 1.34, 0.04), (0, 0, 3.4), mat=dark))
    return parts, glows


@prop("Snowman", pivot="bottom", material="SmoothPlastic", collide=True, texture=512, set="Campus")
def snowman():
    """A students' yukidaruma: two snowballs, charcoal eyes and brows, a red bucket for a hat,
    a knitted scarf in the university's colours."""
    sn = snow("Snowman")
    coal = pk.metal("Snowman_Coal", (12, 12, 14), (28, 28, 30), rough=0.9, metallic=0.0)
    bucket = pk.paint("Snowman_Bucket", (176, 40, 36), rough=0.4)
    scarf = mk.noisy("Snowman_Scarf", srgb(40, 50, 90), srgb(70, 80, 130), scale=20, roughness=0.9)
    body = mk.sphere("Body", 1.4, (0, 0, 1.25), scale=(1, 1, 0.92), mat=sn, segments=16, rings=10)
    mk.displace_noise(body, strength=0.06, scale=0.6, name="SnowNoise")
    head = mk.sphere("Head", 1.0, (0, 0, 3.05), scale=(1, 1, 0.95), mat=sn, segments=16, rings=10)
    parts = [body, head,
             mk.cylinder("Bucket", 0.62, 0.9, (0.05, 0.05, 4.2), rot=(0, 8, 0), mat=bucket, verts=14, radius2=0.72),
             mk.torus("Scarf", 0.82, 0.18, (0, 0, 2.28), mat=scarf, major_segments=18, minor_segments=6),
             mk.box("ScarfEnd", (0.36, 0.1, 0.9), (0.45, -0.88, 1.9), rot=(8, 0, -10), mat=scarf)]
    for sx in (-1, 1):
        parts.append(mk.sphere("Eye", 0.1, (sx * 0.32, -0.9, 3.25), mat=coal, segments=8, rings=6))
        parts.append(mk.box("Brow", (0.28, 0.06, 0.07), (sx * 0.34, -0.9, 3.45), rot=(0, sx * 12, 0), mat=coal))
    for k in range(3):
        parts.append(mk.sphere("Button", 0.1, (0, -1.35, 1.0 + k * 0.4), mat=coal, segments=8, rings=6))
    return parts, []


@prop("SnowTools", pivot="bottom", material="SmoothPlastic", collide=True, texture=512, set="Campus")
def snow_tools():
    """Snow clearing kit by a door: two wide plastic snow scoops and a shovel leaning on a stack of
    de-icing salt bags."""
    red = pk.plastic("STool_Red", (190, 50, 44))
    blue = pk.plastic("STool_Blue", (50, 90, 170))
    wood = mk.wood("STool_Wood", srgb(170, 130, 84), srgb(120, 88, 54), scale=5)
    bag = mk.noisy("STool_Bag", srgb(214, 214, 206), srgb(236, 236, 228), scale=20, roughness=0.8)
    ink = pk.plastic("STool_Ink", (40, 70, 150))
    steel = pk.metal("STool_Steel", (110, 114, 118), (150, 154, 158), rough=0.4, metallic=0.6)
    sn = snow("STool")
    parts = []
    for k in range(3):
        parts.append(pk.rounded(f"Bag{k}", (2.2, 1.4, 0.6), (0, 0.3, 0.3 + k * 0.58), bag, r=0.2,
                                rot=(0, 0, (k - 1) * 6)))
    parts += pk.label("BagText", "融雪剤", 0.3, (0, -0.42, 1.45), ink)
    for k, (m, x) in enumerate(((red, -0.9), (blue, 0.2))):
        parts += [mk.box(f"Blade{k}", (1.7, 0.1, 1.5), (x, -0.75, 0.9), rot=(18, 0, 4), mat=m, bevel=0.04),
                  mk.tube(f"Shaft{k}", (x, -0.55, 1.6), (x + 0.1, -0.1, 4.2), 0.07, mat=wood, verts=6),
                  mk.box(f"Grip{k}", (0.6, 0.12, 0.12), (x + 0.1, -0.1, 4.25), mat=m)]
    parts += [mk.box("Spade", (0.8, 0.08, 1.0), (1.3, -0.6, 0.6), rot=(12, 0, -6), mat=steel, bevel=0.03),
              mk.tube("SpadeShaft", (1.3, -0.5, 1.1), (1.4, 0.0, 3.5), 0.06, mat=wood, verts=6),
              cap("BagSnow", (2.0, 1.2, 0.18), (0, 0.3, 1.82), sn)]
    return parts, []


@prop("CampusLamp", pivot="bottom", material="Metal", collide=False, texture=512, set="Campus", anchor=(0, 0),
      lights=[dict(at=(0, 0, 10.4), kind="point", color=LAMP_WARM, range=24, brightness=1.35)])
def campus_lamp():
    """A Meiji-style cast-iron lamp standard: a fluted base, the slender post with its ladder bar,
    a four-sided glass lantern with its gas mantle glowing, a pointed cap with snow on it."""
    iron = pk.metal("CLamp_Iron", (24, 26, 28), (44, 46, 50), rough=0.55, metallic=0.5)
    glass = pk.dark_glass("CLamp_Glass", (70, 64, 50))
    sn = snow("CLamp")
    parts = [mk.lathe("Base", [(0.62, 0.0), (0.62, 0.3), (0.5, 0.45), (0.42, 1.4), (0.3, 1.7), (0.24, 2.0), (0.0, 2.0)],
                      (0, 0, 0), mat=iron, segments=12),
             mk.cylinder("Post", 0.17, 7.2, (0, 0, 5.6), mat=iron, verts=10, radius2=0.12),
             mk.box("LadderBar", (1.6, 0.12, 0.12), (0, 0, 8.4), mat=iron, bevel=0.03),
             mk.cylinder("Collar", 0.28, 0.4, (0, 0, 9.3), mat=iron, verts=10),
             mk.box("LampFloor", (1.0, 1.0, 0.12), (0, 0, 9.55), mat=iron)]
    for sx in (-1, 1):
        parts.append(mk.sphere("BarEnd", 0.12, (sx * 0.8, 0, 8.4), mat=iron, segments=8, rings=6))
    for rot in (0, 90, 180, 270):
        a = math.radians(rot)
        parts.append(mk.box("Pane", (0.78, 0.04, 1.3), (math.sin(a) * 0.44, -math.cos(a) * 0.44, 10.25), rot=(0, 0, rot),
                            mat=glass))
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(mk.box("Post", (0.08, 0.08, 1.4), (sx * 0.47, sy * 0.47, 10.25), mat=iron))
    roof = mk.lathe("Cap", [(0.0, 0.0), (0.72, 0.0), (0.72, 0.1), (0.2, 0.7), (0.06, 1.0), (0.0, 1.0)], (0, 0, 10.95),
                    mat=iron, segments=4)
    roof_snow = mk.lathe("CapSnow", [(0.0, 0.0), (0.66, 0.02), (0.2, 0.55), (0.0, 0.62)], (0, 0, 11.0), mat=sn, segments=4)
    for obj in (roof, roof_snow):
        obj.rotation_euler = (0, 0, math.radians(45))
    parts += [roof, roof_snow, mk.sphere("Finial", 0.1, (0, 0, 12.05), mat=iron, segments=8, rings=6)]
    glows = [mk.box("Mantle", (0.6, 0.6, 0.9), (0, 0, 10.2), mat=pk.glow("CLamp_Glow", (255, 214, 150), 4))]
    return parts, glows


@prop("NoticeBoard", pivot="bottom", material="Wood", collide=True, texture=1024, set="Campus")
def notice_board():
    """A campus keijiban: a glass-fronted case on two timber legs under its own little roof, full
    of notices and club posters behind the glass; snow on the roof."""
    wood = mk.wood("NBoard_Wood", srgb(96, 66, 42), srgb(56, 38, 24), scale=4)
    cork = mk.noisy("NBoard_Cork", srgb(150, 110, 70), srgb(176, 136, 92), scale=40, roughness=0.9)
    glass = pk.dark_glass("NBoard_Glass", (60, 70, 76))
    slate = mk.noisy("NBoard_Roof", srgb(40, 44, 48), srgb(60, 64, 68), scale=16, roughness=0.6)
    sn = snow("NBoard")
    parts = [mk.box("LegL", (0.35, 0.35, 6.2), (-2.6, 0.1, 3.1), mat=wood),
             mk.box("LegR", (0.35, 0.35, 6.2), (2.6, 0.1, 3.1), mat=wood),
             mk.box("Case", (5.4, 0.5, 3.4), (0, 0.1, 4.2), mat=wood, bevel=0.04),
             mk.box("Cork", (5.0, 0.05, 3.0), (0, -0.16, 4.2), mat=cork),
             mk.box("Glass", (5.0, 0.03, 3.0), (0, -0.2, 4.2), mat=glass),
             mk.box("Roof", (6.2, 1.4, 0.16), (0, 0.0, 6.35), rot=(-10, 0, 0), mat=slate, bevel=0.03),
             cap("RoofSnow", (6.0, 1.2, 0.22), (0, 0.05, 6.52), sn)]
    rng = random.Random(12)
    colours = [(236, 232, 220), (250, 220, 90), (230, 120, 110), (140, 190, 230), (236, 236, 236), (170, 220, 150)]
    for k in range(9):
        w, h = rng.uniform(0.8, 1.3), rng.uniform(0.9, 1.4)
        x = -2.0 + (k % 4) * 1.3 + rng.uniform(-0.1, 0.1)
        z = 4.9 - (k // 4) * 1.3 + rng.uniform(-0.1, 0.1)
        parts.append(mk.box(f"Poster{k}", (w, 0.02, h), (x, -0.17, z), rot=(0, rng.uniform(-4, 4), 0),
                            mat=pk.plastic(f"NBoard_Poster{k}", colours[k % len(colours)])))
    return parts, []


@prop("Tatekan", pivot="bottom", material="Wood", collide=True, texture=512, set="Campus")
def tatekan():
    """A student tatekan: a big whitewashed plywood board on a rough timber frame leaning back,
    painted with a black border (the map writes its brush lettering on it); snow along its top."""
    ply = mk.noisy("Tate_Ply", srgb(214, 208, 196), srgb(236, 232, 222), scale=18, roughness=0.9)
    timber = mk.wood("Tate_Timber", srgb(150, 116, 76), srgb(104, 78, 50), scale=5)
    black = pk.paint("Tate_Black", (20, 20, 22), rough=0.8)
    sn = snow("Tate")
    lean = 8
    parts = [mk.box("Board", (6.0, 0.2, 8.4), (0, 0.3, 4.6), rot=(lean, 0, 0), mat=ply)]
    for sx in (-1, 1):
        parts += [mk.box("Border", (0.2, 0.22, 8.2), (sx * 2.85, 0.28, 4.6), rot=(lean, 0, 0), mat=black),
                  mk.box("Strut", (0.3, 0.3, 8.8), (sx * 2.7, 0.6, 4.4), rot=(lean, 0, 0), mat=timber),
                  mk.tube("Leg", (sx * 2.7, 1.2, 8.2), (sx * 2.7, 3.2, 0.1), 0.15, mat=timber, verts=6)]
    for zz in (0.55, 8.6):
        parts.append(mk.box("BorderH", (5.9, 0.22, 0.2), (0, 0.28 + (zz - 4.6) * math.sin(math.radians(lean)), zz),
                            rot=(lean, 0, 0), mat=black))
    parts.append(cap("TopSnow", (6.1, 0.6, 0.25), (0, 0.95, 8.95), sn))
    return parts, []


# The exam -------------------------------------------------------------------------------------------


@prop("EventTent", pivot="bottom", material="Fabric", collide=False, texture=1024, set="Campus")
def event_tent():
    """A white check-in tent: an aluminium frame, a peaked canopy with a navy valance, canvas walls
    at the back and sides, the check-in table under it in a white cloth; snow on the canopy."""
    canvas = mk.noisy("Tent_Canvas", srgb(222, 224, 226), srgb(240, 242, 244), scale=14, roughness=0.8)
    navy = pk.plastic("Tent_Navy", (36, 50, 96))
    alu = pk.metal("Tent_Alu", (150, 154, 160), (190, 194, 200), rough=0.35, metallic=0.8)
    cloth = mk.noisy("Tent_Cloth", srgb(232, 232, 228), srgb(248, 248, 244), scale=20, roughness=0.9)
    sn = snow("Tent")
    hw, eave, peak = 5.0, 8.0, 10.6
    parts = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(mk.box("Leg", (0.22, 0.22, eave), (sx * hw, sy * hw, eave / 2), mat=alu))
            parts.append(mk.box("Foot", (0.6, 0.6, 0.06), (sx * hw, sy * hw, 0.03), mat=alu))
    corners = [(-hw, -hw), (hw, -hw), (hw, hw), (-hw, hw)]
    for i in range(4):
        (ax, ay), (bx, by) = corners[i], corners[(i + 1) % 4]
        parts.append(mk.tube("Rafter", (ax, ay, eave), (0, 0, peak), 0.06, mat=alu, verts=5))
        # The canopy, one triangle per side (a flattened pyramid), and the valance along its edge.
        mx, my = (ax + bx) / 2, (ay + by) / 2
        length = math.dist((ax, ay), (bx, by))
        parts.append(mk.box("Valance", (length + 0.2, 0.06, 0.6) if ay == by else (0.06, length + 0.2, 0.6),
                            (mx * 1.01, my * 1.01, eave - 0.3), mat=navy))
    roof = mk.lathe("Canopy", [(hw * 1.414, 0.0), (hw * 1.414 + 0.1, 0.06), (0.0, peak - eave + 0.06)], (0, 0, eave),
                    mat=canvas, segments=4)
    roof.rotation_euler = (0, 0, math.radians(45))
    parts.append(roof)
    snow_roof = mk.lathe("CanopySnow", [(hw * 1.2, 0.0), (0.0, (peak - eave) * 0.86)], (0, 0, eave + 0.45), mat=sn,
                         segments=4)
    snow_roof.rotation_euler = (0, 0, math.radians(45))
    parts.append(snow_roof)
    parts += [mk.box("Back", (2 * hw, 0.05, eave - 0.6), (0, hw, (eave - 0.6) / 2 + 0.3), mat=canvas),
              mk.box("SideL", (0.05, 2 * hw, eave - 3.0), (-hw, 0, (eave - 3.0) / 2 + 2.7), mat=canvas),
              mk.box("SideR", (0.05, 2 * hw, eave - 3.0), (hw, 0, (eave - 3.0) / 2 + 2.7), mat=canvas)]
    # The check-in table.
    parts += [mk.box("Table", (6.0, 2.4, 0.12), (0, 1.4, 2.6), mat=cloth),
              mk.box("ClothFront", (6.0, 0.05, 2.3), (0, 0.2, 1.45), mat=cloth),
              mk.box("ClothSideL", (0.05, 2.4, 2.3), (-3.0, 1.4, 1.45), mat=cloth),
              mk.box("ClothSideR", (0.05, 2.4, 2.3), (3.0, 1.4, 1.45), mat=cloth)]
    return parts, []


@prop("KeroseneHeater", pivot="bottom", material="Metal", collide=True, texture=512, set="Campus",
      lights=[dict(at=(0, 0, 1.3), kind="point", color=(255, 140, 70), range=12, brightness=0.9)])
def kerosene_heater():
    """A round Japanese kerosene stove: the enamel body on its base, the chimney guard of rings with
    the burner glowing orange through it, the carrying handle, and a kettle warming on top."""
    enamel = pk.paint("Heat_Enamel", (190, 186, 172), rough=0.35)
    dark = pk.metal("Heat_Dark", (30, 30, 32), (50, 50, 54), rough=0.5, metallic=0.5)
    chrome = pk.chrome("Heat_Chrome")
    kettle = pk.metal("Heat_Kettle", (150, 150, 146), (186, 186, 180), rough=0.3, metallic=0.9)
    parts = [mk.cylinder("Base", 0.95, 0.5, (0, 0, 0.25), mat=enamel, verts=24, bevel=0.05),
             mk.cylinder("Tank", 0.85, 0.3, (0, 0, 0.65), mat=dark, verts=24),
             mk.cylinder("Top", 0.9, 0.12, (0, 0, 2.2), mat=enamel, verts=24),
             mk.cylinder("Burner", 0.5, 1.3, (0, 0, 1.45), mat=dark, verts=20)]
    for k in range(6):
        parts.append(mk.torus("Guard", 0.82, 0.04, (0, 0, 0.95 + k * 0.22), mat=chrome, major_segments=24,
                              minor_segments=4))
    for k in range(8):
        a = 2 * math.pi * k / 8
        parts.append(mk.tube("GuardBar", (math.cos(a) * 0.82, math.sin(a) * 0.82, 0.85),
                             (math.cos(a) * 0.82, math.sin(a) * 0.82, 2.15), 0.03, mat=chrome, verts=4))
    parts += [mk.torus("Handle", 0.5, 0.05, (0, 0, 2.28), rot=(90, 0, 0), mat=chrome, major_segments=16, minor_segments=4),
              mk.lathe("Kettle", [(0.0, 0.0), (0.5, 0.02), (0.55, 0.3), (0.4, 0.55), (0.15, 0.6), (0.0, 0.62)], (0.2, 0.1, 2.26),
                       mat=kettle, segments=16),
              mk.tube("Spout", (0.6, 0.1, 2.45), (0.95, 0.1, 2.7), 0.06, 0.04, mat=kettle, verts=6),
              mk.box("Knob", (0.3, 0.1, 0.2), (0, -0.95, 0.5), mat=dark)]
    glows = [mk.cylinder("Flame", 0.52, 0.6, (0, 0, 1.55), mat=pk.glow("Heat_Glow", (255, 120, 40), 4), verts=20)]
    return parts, glows


@prop("ExamDesk", pivot="bottom", material="Wood", collide=True, texture=512, set="Campus")
def exam_desk():
    """An exam hall desk with its seat behind: a wooden top on a steel frame, the book rack under
    it, the candidate's number card, a pencil case, pencils, an eraser and the exam booklet face
    down, waiting for tomorrow."""
    wood = mk.wood("EDesk_Wood", srgb(170, 126, 80), srgb(120, 84, 50), scale=5)
    steel = pk.metal("EDesk_Steel", (70, 72, 76), (100, 102, 108), rough=0.45, metallic=0.5)
    card = pk.plastic("EDesk_Card", (242, 240, 232))
    ink = pk.plastic("EDesk_Ink", (24, 24, 26))
    case = pk.plastic("EDesk_Case", (40, 60, 110))
    pencil = pk.plastic("EDesk_Pencil", (230, 190, 50))
    parts = [mk.box("Top", (3.4, 1.7, 0.12), (0, -0.2, 2.6), mat=wood),
             mk.box("Rack", (3.2, 1.3, 0.06), (0, -0.1, 2.2), mat=steel),
             mk.box("Seat", (1.6, 1.3, 0.12), (0, 1.35, 1.55), mat=wood),
             mk.box("Backrest", (1.6, 0.1, 1.0), (0, 2.0, 2.3), rot=(-8, 0, 0), mat=wood)]
    for sx in (-1, 1):
        parts += [mk.box("Leg", (0.12, 0.12, 2.55), (sx * 1.55, -0.8, 1.28), mat=steel),
                  mk.box("Leg", (0.12, 0.12, 2.55), (sx * 1.55, 0.4, 1.28), mat=steel),
                  mk.box("Runner", (0.12, 2.6, 0.12), (sx * 0.7, 0.9, 0.06), mat=steel),
                  mk.box("SeatPost", (0.1, 0.1, 1.5), (sx * 0.7, 1.35, 0.75), mat=steel)]
    parts += [mk.box("Number", (0.8, 0.05, 0.4), (1.1, -0.95, 2.86), rot=(-15, 0, 0), mat=card),
              mk.box("Booklet", (1.0, 1.3, 0.05), (-0.1, -0.2, 2.69), rot=(0, 0, 3), mat=card),
              mk.box("NumStripe", (0.6, 0.02, 0.1), (1.1, -0.98, 2.88), rot=(-15, 0, 0), mat=ink),
              mk.box("PencilCase", (1.0, 0.3, 0.2), (-1.1, -0.7, 2.76), mat=case),
              mk.box("Eraser", (0.25, 0.14, 0.1), (1.2, -0.3, 2.71), mat=card)]
    for k in range(2):
        parts.append(mk.cylinder(f"Pencil{k}", 0.05, 1.0, (-1.1 + k * 0.15, -0.35, 2.7), rot=(0, 90, 0), mat=pencil,
                                 verts=5))
    return parts, []


@prop("Lectern", pivot="bottom", material="Wood", collide=True, texture=512, set="Campus")
def lectern():
    """The proctor's lectern: a panelled oak stand with a sloped top, a gooseneck microphone and a
    small reading lamp over the instructions."""
    oak = mk.wood("Lect_Oak", srgb(130, 90, 54), srgb(78, 52, 30), scale=4)
    dark = pk.metal("Lect_Dark", (20, 20, 22), (36, 36, 40), rough=0.5, metallic=0.4)
    brass = pk.metal("Lect_Brass", (160, 126, 64), (206, 170, 96), rough=0.3, metallic=0.9)
    paper = pk.plastic("Lect_Paper", (236, 232, 218))
    parts = [mk.box("Base", (2.6, 2.0, 0.3), (0, 0, 0.15), mat=oak, bevel=0.03),
             mk.box("Body", (2.2, 1.6, 3.6), (0, 0, 2.0), mat=oak, bevel=0.03),
             mk.box("Top", (2.5, 1.9, 0.12), (0, 0.05, 3.95), rot=(-14, 0, 0), mat=oak, bevel=0.03),
             mk.box("Ledge", (2.4, 0.12, 0.2), (0, -0.85, 3.78), mat=oak),
             mk.box("Papers", (1.2, 1.4, 0.04), (-0.2, 0.05, 4.04), rot=(-14, 0, 3), mat=paper),
             mk.box("Crest", (1.0, 0.05, 1.0), (0, -0.82, 2.5), mat=brass, bevel=0.02),
             mk.cylinder("MicBase", 0.14, 0.2, (0.7, 0.3, 4.15), mat=dark, verts=10),
             mk.tube("MicNeck", (0.7, 0.3, 4.2), (0.6, -0.4, 5.1), 0.03, mat=dark, verts=5),
             mk.cylinder("Mic", 0.08, 0.3, (0.58, -0.52, 5.15), rot=(-60, 0, 0), mat=dark, verts=8),
             mk.tube("LampNeck", (-0.9, 0.6, 4.3), (-0.5, 0.2, 4.9), 0.03, mat=brass, verts=5),
             mk.box("LampHood", (0.8, 0.3, 0.14), (-0.4, 0.1, 4.95), mat=brass, bevel=0.04)]
    glows = [mk.box("LampBulb", (0.6, 0.2, 0.03), (-0.4, 0.1, 4.87), mat=pk.glow("Lect_Bulb", LAMP_WARM, 3))]
    return parts, glows


@prop("ExamSignStand", pivot="bottom", material="Wood", collide=True, texture=512, set="Campus")
def exam_sign_stand():
    """A tall standing sign for the exam: a white board framed in black on its A-frame easel (the
    map writes the vertical brush lettering on it)."""
    board = mk.noisy("ESign_Board", srgb(232, 230, 222), srgb(246, 244, 238), scale=18, roughness=0.8)
    black = pk.paint("ESign_Black", (22, 22, 24), rough=0.6)
    wood = mk.wood("ESign_Wood", srgb(120, 84, 50), srgb(80, 54, 32), scale=5)
    sn = snow("ESign")
    parts = [mk.box("Board", (2.4, 0.12, 6.2), (0, 0.2, 3.6), rot=(6, 0, 0), mat=board),
             mk.box("Frame", (2.7, 0.1, 6.5), (0, 0.28, 3.6), rot=(6, 0, 0), mat=black),
             mk.tube("BackLegL", (-1.0, 0.8, 6.2), (-1.0, 2.2, 0.05), 0.08, mat=wood, verts=6),
             mk.tube("BackLegR", (1.0, 0.8, 6.2), (1.0, 2.2, 0.05), 0.08, mat=wood, verts=6),
             mk.box("Brace", (2.0, 0.08, 0.08), (0, 1.5, 3.0), mat=wood),
             cap("TopSnow", (2.6, 0.5, 0.18), (0, 0.55, 6.82), sn)]
    return parts, []


@prop("QueuePosts", pivot="bottom", material="Metal", collide=False, texture=256, set="Campus")
def queue_posts():
    """Two queue stanchions with the red belt pulled between them (6 studs apart)."""
    chrome = pk.chrome("Queue_Chrome")
    dark = pk.metal("Queue_Dark", (26, 26, 28), (44, 44, 48), rough=0.5, metallic=0.3)
    belt = pk.plastic("Queue_Belt", (170, 30, 36))
    parts = [mk.box("Belt", (6.0, 0.04, 0.25), (0, 0, 3.0), mat=belt)]
    for sx in (-1, 1):
        parts += [mk.cylinder("Base", 0.55, 0.12, (sx * 3.0, 0, 0.06), mat=dark, verts=16),
                  mk.cylinder("Post", 0.1, 3.1, (sx * 3.0, 0, 1.6), mat=chrome, verts=10),
                  mk.cylinder("Head", 0.16, 0.3, (sx * 3.0, 0, 3.2), mat=chrome, verts=10)]
    return parts, []


# The library ------------------------------------------------------------------------------------------


@prop("ReadingTable", pivot="bottom", material="Wood", collide=False, texture=1024, set="Campus",
      lights=[dict(at=(-2.5, 0, 3.7), kind="point", color=(255, 220, 170), range=11, brightness=0.55),
              dict(at=(2.5, 0, 3.7), kind="point", color=(255, 220, 170), range=11, brightness=0.55)])
def reading_table():
    """A long oak reading table from the old reading room: turned legs, a centre rail with four
    banker's lamps in green glass, a few open books and a pencil left behind."""
    oak = mk.wood("RTable_Oak", srgb(140, 96, 56), srgb(84, 56, 32), scale=4)
    brass = pk.metal("RTable_Brass", (160, 126, 64), (206, 170, 96), rough=0.3, metallic=0.9)
    green = pk.plastic("RTable_Green", (30, 100, 60), rough=0.15)
    paper = pk.plastic("RTable_Paper", (236, 230, 212))
    parts = [mk.box("Top", (10.0, 4.0, 0.18), (0, 0, 2.66), mat=oak, bevel=0.04),
             mk.box("Apron", (9.4, 3.4, 0.5), (0, 0, 2.3), mat=oak),
             mk.box("Rail", (9.0, 0.3, 0.5), (0, 0, 3.0), mat=oak, bevel=0.03)]
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(mk.lathe("Leg", [(0.22, 0.0), (0.26, 0.3), (0.18, 0.6), (0.2, 1.4), (0.16, 2.1), (0.2, 2.3),
                                          (0.0, 2.3)], (sx * 4.5, sy * 1.6, 0), mat=oak, segments=10))
    glows = []
    for k, x in enumerate((-3.6, -1.2, 1.2, 3.6)):
        parts += [mk.cylinder("LampBase", 0.3, 0.1, (x, 0, 3.3), mat=brass, verts=12),
                  mk.cylinder("LampStem", 0.04, 0.8, (x, 0, 3.7), mat=brass, verts=6),
                  mk.box("LampShade", (1.3, 0.55, 0.28), (x, 0, 4.15), mat=green, bevel=0.12, segments=3)]
        glows.append(mk.box(f"Bulb{k}", (1.0, 0.4, 0.03), (x, 0, 3.99), mat=pk.glow("RTable_Bulb", (255, 222, 170), 3)))
    for k, (x, y, rot) in enumerate(((-2.5, -1.2, 8), (2.8, 1.1, -12), (0.4, -1.3, 4))):
        parts += [mk.box(f"BookL{k}", (0.9, 1.3, 0.06), (x - 0.46, y, 2.8), rot=(0, 4, rot), mat=paper),
                  mk.box(f"BookR{k}", (0.9, 1.3, 0.06), (x + 0.46, y, 2.8), rot=(0, -4, rot), mat=paper)]
    parts.append(mk.cylinder("Pencil", 0.04, 0.8, (1.0, -1.0, 2.78), rot=(0, 90, 30), mat=pk.plastic("RTable_Pencil",
                                                                                                     (220, 180, 40)), verts=6))
    return parts, glows


@prop("CardCatalog", pivot="bottom", material="Wood", collide=True, texture=1024, set="Campus")
def card_catalog():
    """The library's card catalogue: an oak cabinet of small drawers on a plinth, each with its
    brass pull and label frame."""
    oak = mk.wood("Card_Oak", srgb(146, 102, 60), srgb(90, 60, 34), scale=4)
    brass = pk.metal("Card_Brass", (160, 126, 64), (206, 170, 96), rough=0.3, metallic=0.9)
    card = pk.plastic("Card_Label", (236, 230, 212))
    parts = [mk.box("Plinth", (5.0, 2.0, 0.6), (0, 0, 0.3), mat=oak, bevel=0.03),
             mk.box("Body", (4.8, 1.8, 3.9), (0, 0, 2.55), mat=oak, bevel=0.03),
             mk.box("Cornice", (5.1, 2.1, 0.2), (0, 0, 4.6), mat=oak, bevel=0.04)]
    cols, rows = 8, 7
    for c in range(cols):
        for r in range(rows):
            x = -2.1 + c * 0.6
            z = 0.95 + r * 0.52
            parts += [mk.box("Drawer", (0.54, 0.05, 0.46), (x, -0.92, z), mat=oak),
                      mk.box("Frame", (0.26, 0.03, 0.12), (x, -0.96, z + 0.1), mat=brass),
                      mk.box("Label", (0.2, 0.02, 0.08), (x, -0.97, z + 0.1), mat=card),
                      mk.box("Pull", (0.14, 0.06, 0.05), (x, -0.98, z - 0.08), mat=brass)]
    return parts, []


@prop("BookCart", pivot="bottom", material="Wood", collide=True, texture=512, set="Campus")
def book_cart():
    """A library book trolley: two sloped shelves of books waiting to go back, on four casters."""
    wood = mk.wood("BCart_Wood", srgb(140, 100, 60), srgb(96, 64, 38), scale=4)
    steel = pk.metal("BCart_Steel", (80, 82, 86), (110, 112, 118), rough=0.4, metallic=0.6)
    rubber = pk.rubber("BCart_Rubber")
    parts = [mk.box("Base", (3.2, 1.4, 0.12), (0, 0, 0.55), mat=wood),
             mk.box("Spine", (3.2, 0.12, 2.6), (0, 0, 1.9), mat=wood),
             mk.box("ShelfA", (3.2, 0.7, 0.1), (0, -0.35, 1.9), rot=(-12, 0, 0), mat=wood),
             mk.box("ShelfB", (3.2, 0.7, 0.1), (0, 0.35, 1.9), rot=(12, 0, 0), mat=wood)]
    for sx in (-1, 1):
        parts.append(mk.box("End", (0.1, 1.4, 2.8), (sx * 1.6, 0, 1.8), mat=wood))
        for sy in (-1, 1):
            parts += [mk.cylinder("Caster", 0.2, 0.14, (sx * 1.4, sy * 0.55, 0.2), rot=(0, 90, 0), mat=rubber, verts=10),
                      mk.box("Fork", (0.08, 0.3, 0.3), (sx * 1.4, sy * 0.55, 0.4), mat=steel)]
    rng = random.Random(9)
    colours = [(110, 40, 36), (40, 60, 90), (60, 80, 50), (140, 120, 80), (70, 50, 70), (180, 160, 120)]
    for side, sy in ((0, -1), (1, 1)):
        for level, zz in ((0, 0.62), (1, 1.95)):
            x = -1.45
            while x < 1.45:
                w = rng.uniform(0.18, 0.32)
                h = rng.uniform(0.7, 1.0)
                c = colours[rng.randrange(len(colours))]
                parts.append(mk.box("Book", (w, 0.55, h), (x + w / 2, sy * 0.33, zz + h / 2),
                                    rot=(sy * 12 if level else 0, 0, 0),
                                    mat=pk.plastic(f"BCart_Book{colours.index(c)}", c)))
                x += w + 0.02
    return parts, []


# The science building ---------------------------------------------------------------------------------


@prop("SkeletonModel", pivot="bottom", material="SmoothPlastic", collide=True, texture=512, set="Campus")
def skeleton_model():
    """The anatomy skeleton on its rolling stand: skull and jaw, spine, rib cage, pelvis, arms
    and legs, hanging from the stand's hook."""
    bone = mk.noisy("Skel_Bone", srgb(214, 204, 180), srgb(236, 228, 208), scale=20, roughness=0.6)
    steel = pk.metal("Skel_Steel", (140, 144, 150), (180, 184, 190), rough=0.3, metallic=0.8)
    dark = pk.metal("Skel_Dark", (20, 20, 22), (34, 34, 38), rough=0.6, metallic=0.2)
    parts = [mk.cylinder("StandHub", 0.2, 0.2, (0, 0, 0.35), mat=steel, verts=10),
             mk.cylinder("StandPole", 0.06, 5.2, (0, 0.5, 2.9), mat=steel, verts=8),
             mk.tube("Hook", (0, 0.5, 5.5), (0, 0.1, 5.6), 0.04, mat=steel, verts=5)]
    for k in range(5):
        a = 2 * math.pi * k / 5
        parts += [mk.tube("StandLeg", (0, 0, 0.35), (math.cos(a) * 0.9, math.sin(a) * 0.9, 0.12), 0.05, mat=steel, verts=5),
                  mk.sphere("Wheel", 0.1, (math.cos(a) * 0.9, math.sin(a) * 0.9, 0.1), mat=dark, segments=8, rings=6)]
    parts += [mk.sphere("Skull", 0.42, (0, 0.05, 5.2), scale=(0.85, 1.0, 1.0), mat=bone, segments=14, rings=10),
              mk.box("Jaw", (0.5, 0.4, 0.2), (0, -0.12, 4.78), mat=bone, bevel=0.08),
              mk.sphere("SocketL", 0.1, (-0.15, -0.3, 5.22), mat=dark, segments=8, rings=6),
              mk.sphere("SocketR", 0.1, (0.15, -0.3, 5.22), mat=dark, segments=8, rings=6)]
    for k in range(16):
        parts.append(mk.cylinder("Vertebra", 0.1, 0.12, (0, 0.1, 4.62 - k * 0.14), mat=bone, verts=8))
    for k in range(6):
        zz = 4.35 - k * 0.16
        rr = 0.42 + 0.06 * math.sin(k / 5 * math.pi)
        parts.append(mk.torus("Rib", rr, 0.04, (0, -0.1, zz), mat=bone, major_segments=14, minor_segments=4))
    parts += [mk.sphere("Pelvis", 0.42, (0, 0, 2.3), scale=(1.2, 0.7, 0.55), mat=bone, segments=12, rings=8),
              mk.box("Clavicle", (1.0, 0.1, 0.08), (0, -0.1, 4.45), mat=bone)]
    for sx in (-1, 1):
        parts += [mk.tube("Humerus", (sx * 0.55, 0, 4.4), (sx * 0.65, -0.05, 3.3), 0.06, mat=bone, verts=6),
                  mk.tube("Forearm", (sx * 0.65, -0.05, 3.3), (sx * 0.7, -0.2, 2.3), 0.05, mat=bone, verts=6),
                  mk.box("Hand", (0.18, 0.1, 0.4), (sx * 0.7, -0.22, 2.05), mat=bone),
                  mk.tube("Femur", (sx * 0.3, 0, 2.15), (sx * 0.28, -0.02, 1.15), 0.07, mat=bone, verts=6),
                  mk.tube("Shin", (sx * 0.28, -0.02, 1.15), (sx * 0.27, 0.0, 0.62), 0.06, mat=bone, verts=6),
                  mk.box("Foot", (0.18, 0.45, 0.1), (sx * 0.27, -0.15, 0.56), mat=bone)]
    return parts, []


@prop("SpecimenShelf", pivot="bottom", material="Wood", collide=True, texture=1024, set="Campus")
def specimen_shelf():
    """A tall glazed specimen cabinet: dark oak with four shelves of jars in yellowed spirit, each
    with its label, behind glazing bars."""
    oak = mk.wood("Spec_Oak", srgb(88, 60, 36), srgb(50, 34, 20), scale=4)
    back = mk.noisy("Spec_Back", srgb(26, 24, 22), srgb(40, 36, 32), scale=10, roughness=0.8)
    lid = pk.metal("Spec_Lid", (60, 62, 66), (90, 92, 96), rough=0.4, metallic=0.6)
    label = pk.plastic("Spec_Label", (230, 222, 196))
    fluids = [(190, 170, 90), (170, 160, 110), (150, 170, 120), (200, 180, 120)]
    parts = [mk.box("Plinth", (5.0, 1.6, 0.4), (0, 0, 0.2), mat=oak),
             mk.box("Back", (4.8, 0.1, 6.8), (0, 0.72, 3.8), mat=back),
             mk.box("Top", (5.2, 1.8, 0.3), (0, 0, 7.35), mat=oak, bevel=0.04)]
    for sx in (-1, 1):
        parts.append(mk.box("Side", (0.14, 1.6, 7.0), (sx * 2.45, 0, 3.7), mat=oak))
    for k in range(5):
        parts.append(mk.box("Shelf", (4.8, 1.4, 0.1), (0, 0.05, 0.5 + k * 1.6), mat=oak))
        parts.append(mk.box("Bar", (4.9, 0.08, 0.08), (0, -0.78, 0.5 + k * 1.6), mat=oak))
    for sx in (-1.2, 0.0, 1.2):
        parts.append(mk.box("Mullion", (0.08, 0.08, 7.0), (sx, -0.78, 3.7), mat=oak))
    rng = random.Random(21)
    for row in range(4):
        zz = 0.55 + row * 1.6
        x = -2.1
        while x < 2.0:
            r = rng.uniform(0.18, 0.3)
            h = rng.uniform(0.6, 1.2)
            f = rng.randrange(len(fluids))
            parts += [mk.cylinder("Jar", r, h, (x + r, 0.05, zz + h / 2), mat=pk.plastic(f"Spec_Fluid{f}", fluids[f]),
                                  verts=10),
                      mk.cylinder("JarLid", r + 0.02, 0.08, (x + r, 0.05, zz + h + 0.04), mat=lid, verts=10),
                      mk.box("JarLabel", (r * 1.2, 0.02, 0.2), (x + r, 0.05 - r - 0.01, zz + h * 0.5), mat=label)]
            x += 2 * r + 0.12
    return parts, []


@prop("Microscope", pivot="bottom", material="SmoothPlastic", collide=False, texture=256, set="Campus")
def microscope():
    """A bench microscope: base, arm, stage with a slide, turret and binocular head."""
    white = pk.plastic("Micro_White", (228, 230, 230))
    dark = pk.metal("Micro_Dark", (22, 22, 24), (38, 38, 42), rough=0.5, metallic=0.3)
    steel = pk.metal("Micro_Steel", (150, 154, 160), (190, 194, 200), rough=0.3, metallic=0.8)
    glass = pk.plastic("Micro_Slide", (190, 220, 226))
    parts = [mk.box("Base", (0.9, 1.3, 0.2), (0, 0.1, 0.1), mat=white, bevel=0.05),
             mk.box("Arm", (0.3, 0.35, 1.5), (0, 0.5, 0.9), mat=white, bevel=0.05),
             mk.box("Stage", (0.8, 0.7, 0.1), (0, 0.0, 0.7), mat=dark),
             mk.box("Slide", (0.5, 0.2, 0.02), (0, -0.05, 0.76), mat=glass),
             mk.cylinder("Turret", 0.2, 0.3, (0, 0.05, 1.2), mat=steel, verts=12),
             mk.tube("Head", (0, 0.3, 1.45), (0, 0.0, 1.75), 0.16, mat=white, verts=10)]
    for sx in (-1, 1):
        parts.append(mk.cylinder("Eye", 0.07, 0.35, (sx * 0.12, -0.12, 1.9), rot=(-35, 0, 0), mat=dark, verts=8))
    parts.append(mk.cylinder("Focus", 0.16, 0.5, (0, 0.5, 0.6), rot=(0, 90, 0), mat=dark, verts=12))
    return parts, []


# The club house and the cafeteria ---------------------------------------------------------------------


@prop("Kotatsu", pivot="bottom", material="Fabric", collide=False, texture=1024, set="Campus")
def kotatsu():
    """A club room's kotatsu: the low table over its thick quilt, a board top (1.25 high), a bowl of
    mikan, four floor cushions round it. The map gives the table its collider."""
    quilt = mk.noisy("Kot_Quilt", srgb(130, 50, 60), srgb(170, 90, 80), scale=12, roughness=0.95)
    wood = mk.wood("Kot_Wood", srgb(150, 110, 70), srgb(100, 70, 44), scale=4)
    cushion = mk.noisy("Kot_Cushion", srgb(60, 70, 120), srgb(90, 100, 150), scale=14, roughness=0.95)
    orange = pk.plastic("Kot_Mikan", (240, 140, 30), rough=0.5)
    bowl = pk.plastic("Kot_Bowl", (200, 190, 170))
    parts = [pk.rounded("Quilt", (4.2, 4.2, 1.05), (0, 0, 0.55), quilt, r=0.3),
             mk.box("Board", (3.5, 3.5, 0.14), (0, 0, 1.18), mat=wood, bevel=0.03),
             mk.lathe("Bowl", [(0.0, 0.0), (0.4, 0.02), (0.6, 0.3), (0.55, 0.32), (0.0, 0.1)], (0.8, 0.6, 1.25), mat=bowl,
                      segments=16)]
    for k, (dx, dy) in enumerate(((0.7, 0.55), (0.95, 0.6), (0.82, 0.8), (0.8, 0.62))):
        parts.append(mk.sphere(f"Mikan{k}", 0.17, (dx, dy, 1.45 + (0.14 if k == 3 else 0)), scale=(1, 1, 0.85), mat=orange,
                               segments=10, rings=6))
    for k, (x, y) in enumerate(((0, -3.2), (0, 3.2), (-3.2, 0), (3.2, 0))):
        parts.append(pk.rounded(f"Cushion{k}", (1.9, 1.9, 0.32), (x, y, 0.16), cushion, r=0.14, rot=(0, 0, k * 7)))
    return parts, []


@prop("ShoeLockers", pivot="bottom", material="Wood", collide=True, texture=1024, set="Campus")
def shoe_lockers():
    """A getabako at the club house door: a wooden rack of shoe cubbies, sneakers and loafers in
    some, a row of green slippers on the step below."""
    wood = mk.wood("Shoe_Wood", srgb(150, 110, 70), srgb(104, 74, 46), scale=4)
    dark = mk.noisy("Shoe_Dark", srgb(40, 32, 26), srgb(56, 46, 38), scale=10, roughness=0.8)
    slipper = pk.plastic("Shoe_Slipper", (60, 110, 70))
    shoes = [pk.plastic("Shoe_White", (230, 230, 226)), pk.plastic("Shoe_Black", (30, 30, 32)),
             pk.plastic("Shoe_Brown", (110, 70, 40)), pk.plastic("Shoe_Red", (170, 50, 44))]
    parts = [mk.box("Back", (6.0, 0.12, 5.0), (0, 0.64, 2.5), mat=dark),
             mk.box("Top", (6.2, 1.5, 0.14), (0, 0, 5.05), mat=wood, bevel=0.03),
             mk.box("Step", (6.2, 1.6, 0.4), (0, -1.3, 0.2), mat=wood, bevel=0.03)]
    rows, cols = 4, 6
    for c in range(cols + 1):
        parts.append(mk.box("Divider", (0.1, 1.3, 4.3), (-3.0 + c * 1.0, 0, 2.95), mat=wood))
    for r in range(rows + 1):
        parts.append(mk.box("Shelf", (6.0, 1.3, 0.1), (0, 0, 0.8 + r * 1.07), mat=wood))
    rng = random.Random(4)
    for r in range(rows):
        for c in range(cols):
            if rng.random() < 0.55:
                m = rng.choice(shoes)
                x = -2.5 + c * 1.0
                zz = 0.85 + r * 1.07
                for sx in (-0.18, 0.18):
                    parts.append(mk.box("Shoe", (0.3, 1.0, 0.32), (x + sx, -0.05, zz + 0.16), mat=m))
    for k in range(6):
        parts.append(mk.box("Slipper", (0.34, 0.9, 0.12), (-2.6 + k * 1.05, -1.3, 0.46), mat=slipper))
    return parts, []


@prop("DrumKit", pivot="bottom", material="SmoothPlastic", collide=True, texture=1024, set="Campus")
def drum_kit():
    """The light music club's drum kit: bass drum, snare, two rack toms and a floor tom, the
    hi-hat and a crash cymbal on their stands, the throne."""
    wrap = pk.plastic("Drum_Wrap", (120, 20, 30), rough=0.2)
    head = pk.plastic("Drum_Head", (236, 232, 222))
    chrome = pk.chrome("Drum_Chrome")
    brass = pk.metal("Drum_Cymbal", (180, 146, 70), (220, 184, 100), rough=0.25, metallic=0.95)
    dark = pk.metal("Drum_Dark", (20, 20, 22), (34, 34, 38), rough=0.5, metallic=0.3)
    parts = [mk.cylinder("Bass", 1.0, 1.2, (0, -0.2, 1.05), rot=(90, 0, 0), mat=wrap, verts=24),
             mk.cylinder("BassHead", 0.96, 0.04, (0, -0.82, 1.05), rot=(90, 0, 0), mat=head, verts=24)]
    for k, (x, y, z, r, d) in enumerate(((-0.6, -0.1, 2.35, 0.55, 0.6), (0.6, -0.1, 2.35, 0.6, 0.65))):
        parts += [mk.cylinder(f"Tom{k}", r, d, (x, y, z), rot=(-20, 0, 0), mat=wrap, verts=20),
                  mk.cylinder(f"TomHead{k}", r - 0.02, 0.04, (x, y - 0.1, z + d / 2 * 0.94), rot=(-20, 0, 0), mat=head,
                              verts=20)]
    parts += [mk.cylinder("Floor", 0.75, 1.0, (1.6, 0.6, 1.3), mat=wrap, verts=20),
              mk.cylinder("FloorHead", 0.73, 0.04, (1.6, 0.6, 1.82), mat=head, verts=20),
              mk.cylinder("Snare", 0.6, 0.45, (-1.1, 0.8, 1.9), mat=chrome, verts=20),
              mk.cylinder("SnareHead", 0.58, 0.04, (-1.1, 0.8, 2.14), mat=head, verts=20)]
    for x, y, z, r in ((-2.0, 0.6, 3.2, 0.7), (1.9, -0.6, 4.2, 0.9)):
        parts += [mk.cylinder("Stand", 0.05, z, (x, y, z / 2), mat=chrome, verts=6),
                  mk.cylinder("Cymbal", r, 0.04, (x, y, z), mat=brass, verts=24, radius2=0.1)]
        for k in range(3):
            a = 2 * math.pi * k / 3
            parts.append(mk.tube("Tripod", (x, y, 0.6), (x + math.cos(a) * 0.6, y + math.sin(a) * 0.6, 0.02), 0.03,
                                 mat=chrome, verts=4))
    parts.append(mk.cylinder("HatBottom", 0.7, 0.04, (-2.0, 0.6, 3.1), mat=brass, verts=24, radius2=0.1))
    parts += [mk.cylinder("Throne", 0.6, 0.25, (-0.2, 2.2, 1.9), mat=dark, verts=16),
              mk.cylinder("ThronePost", 0.08, 1.8, (-0.2, 2.2, 0.9), mat=chrome, verts=6)]
    return parts, []


@prop("UprightPiano", pivot="bottom", material="SmoothPlastic", collide=True, texture=1024, set="Campus")
def upright_piano():
    """An upright piano in black lacquer, its fall open on the keys, the music desk with a score,
    the pedals and a bench."""
    lacquer = mk.noisy("Piano_Black", srgb(10, 10, 12), srgb(26, 26, 30), scale=8, roughness=0.12)
    ivory = pk.plastic("Piano_Ivory", (236, 232, 220))
    ebony = pk.plastic("Piano_Ebony", (16, 16, 18))
    brass = pk.metal("Piano_Brass", (170, 136, 70), (210, 176, 100), rough=0.3, metallic=0.9)
    paper = pk.plastic("Piano_Paper", (236, 230, 212))
    parts = [mk.box("Case", (5.2, 2.0, 4.6), (0, 0.4, 2.3), mat=lacquer, bevel=0.05),
             mk.box("Keybed", (5.0, 1.0, 0.3), (0, -0.9, 2.45), mat=lacquer, bevel=0.03),
             mk.box("Keys", (4.7, 0.8, 0.1), (0, -0.95, 2.65), mat=ivory),
             mk.box("Fall", (4.9, 0.6, 0.08), (0, -0.2, 3.1), rot=(60, 0, 0), mat=lacquer),
             mk.box("Desk", (2.4, 0.1, 0.9), (0, -0.62, 3.6), rot=(-12, 0, 0), mat=lacquer),
             mk.box("Score", (2.0, 0.04, 0.8), (0, -0.68, 3.62), rot=(-12, 0, 0), mat=paper)]
    for k in range(34):
        if k % 7 in (2, 6):
            continue
        parts.append(mk.box("Black", (0.08, 0.5, 0.1), (-2.25 + k * 0.137, -0.8, 2.75), mat=ebony))
    for sx in (-1, 1):
        parts.append(mk.box("Leg", (0.25, 0.25, 2.3), (sx * 2.3, -1.25, 1.15), mat=lacquer))
    for k in range(3):
        parts.append(mk.box("Pedal", (0.15, 0.5, 0.06), (-0.4 + k * 0.4, -0.7, 0.35), mat=brass))
    parts += [pk.rounded("Bench", (3.0, 1.2, 0.3), (0, -2.6, 1.7), lacquer, r=0.08),
              mk.box("BenchLeg", (0.2, 0.2, 1.6), (-1.3, -2.6, 0.8), mat=lacquer),
              mk.box("BenchLeg", (0.2, 0.2, 1.6), (1.3, -2.6, 0.8), mat=lacquer)]
    return parts, []


@prop("FilmProjector", pivot="bottom", material="Metal", collide=True, texture=512, set="Campus")
def film_projector():
    """The film club's 16 mm projector on its trolley: grey body, two reels on their arms, the
    lens throwing its beam (lit), the cable, a can of film on the shelf."""
    grey = pk.paint("Proj_Grey", (80, 86, 90), rough=0.4)
    dark = pk.metal("Proj_Dark", (22, 22, 24), (38, 38, 42), rough=0.5, metallic=0.3)
    alu = pk.metal("Proj_Alu", (160, 164, 170), (196, 200, 206), rough=0.3, metallic=0.8)
    film = pk.plastic("Proj_Film", (40, 30, 24))
    parts = [mk.box("Trolley", (2.0, 2.4, 0.1), (0, 0, 2.4), mat=dark),
             mk.box("Shelf", (1.8, 2.2, 0.1), (0, 0, 0.9), mat=dark),
             mk.cylinder("Can", 0.6, 0.2, (0, 0.2, 1.05), mat=alu, verts=20),
             mk.box("Body", (1.2, 1.8, 1.2), (0, 0, 3.05), mat=grey, bevel=0.1),
             mk.cylinder("Lens", 0.22, 0.8, (0.2, -1.2, 3.1), rot=(90, 0, 0), mat=dark, verts=14)]
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(mk.box("Leg", (0.1, 0.1, 2.4), (sx * 0.9, sy * 1.1, 1.2), mat=dark))
    for sy, zz in ((-0.6, 4.4), (0.8, 4.3)):
        parts += [mk.tube("ReelArm", (0, sy * 0.4, 3.6), (0, sy, zz), 0.05, mat=dark, verts=5),
                  mk.cylinder("Reel", 0.7, 0.1, (0.1, sy, zz), rot=(0, 90, 0), mat=alu, verts=20),
                  mk.cylinder("ReelFilm", 0.5, 0.12, (0.1, sy, zz), rot=(0, 90, 0), mat=film, verts=16)]
    glows = [mk.cylinder("Beam", 0.18, 0.04, (0.2, -1.62, 3.1), rot=(90, 0, 0), mat=pk.glow("Proj_Lamp", (255, 244, 220), 5),
                         verts=12)]
    return parts, glows


@prop("Typewriter", pivot="bottom", material="Metal", collide=False, texture=256, set="Campus")
def typewriter():
    """A manual typewriter with a page in it."""
    body = pk.paint("Type_Body", (40, 60, 56), rough=0.35)
    dark = pk.metal("Type_Dark", (18, 18, 20), (32, 32, 36), rough=0.5, metallic=0.3)
    paper = pk.plastic("Type_Paper", (240, 236, 224))
    parts = [mk.box("Base", (1.5, 1.2, 0.3), (0, 0, 0.15), mat=body, bevel=0.06),
             mk.box("Deck", (1.5, 0.8, 0.3), (0, -0.2, 0.35), rot=(12, 0, 0), mat=body, bevel=0.06),
             mk.cylinder("Platen", 0.14, 1.6, (0, 0.35, 0.62), rot=(0, 90, 0), mat=dark, verts=12),
             mk.box("Page", (0.9, 0.03, 0.9), (0, 0.42, 1.05), rot=(-10, 0, 0), mat=paper)]
    for r in range(3):
        for c in range(9):
            parts.append(mk.cylinder("Key", 0.05, 0.06, (-0.6 + c * 0.15 + r * 0.05, -0.3 - r * 0.12, 0.5 - r * 0.03),
                                     mat=dark, verts=6))
    return parts, []


@prop("TrayReturn", pivot="bottom", material="Metal", collide=True, texture=512, set="Campus")
def tray_return():
    """The cafeteria's tray return: a stainless rack of shelves full of plastic trays and bowls,
    its 返却口 plate on top."""
    steel = pk.metal("Tray_Steel", (170, 174, 180), (206, 210, 214), rough=0.3, metallic=0.8)
    tray = pk.plastic("Tray_Tray", (170, 110, 60))
    bowl = pk.plastic("Tray_Bowl", (226, 222, 212))
    plate = pk.plastic("Tray_Plate", (30, 60, 110))
    ink = pk.plastic("Tray_Ink", (240, 240, 236))
    parts = [mk.box("Top", (6.0, 2.0, 0.1), (0, 0, 5.0), mat=steel)]
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(mk.box("Post", (0.12, 0.12, 5.0), (sx * 2.9, sy * 0.9, 2.5), mat=steel))
    for k in range(5):
        zz = 0.5 + k * 1.0
        parts.append(mk.box("Rail", (5.8, 1.9, 0.05), (0, 0, zz), mat=steel))
        for j in range(3):
            if (k + j) % 3 == 2:
                continue
            x = -1.9 + j * 1.9
            parts.append(mk.box("Tray", (1.7, 1.3, 0.06), (x, 0, zz + 0.06), mat=tray, bevel=0.02))
            parts.append(mk.lathe("Bowl", [(0.0, 0.0), (0.25, 0.02), (0.35, 0.25), (0.3, 0.26), (0.0, 0.05)],
                                  (x - 0.3, 0.1, zz + 0.1), mat=bowl, segments=10))
    parts += [mk.box("Plate", (2.2, 0.08, 0.6), (0, -0.9, 5.4), mat=plate)]
    parts += pk.label("PlateText", "返却口", 0.34, (0, -0.95, 5.4), ink)
    return parts, []


@prop("UmbrellaStand", pivot="bottom", material="Metal", collide=True, texture=256, set="Campus")
def umbrella_stand():
    """A steel umbrella stand by a door, full of clear vinyl umbrellas and a couple of dark ones."""
    steel = pk.metal("Umb_Steel", (120, 124, 128), (160, 164, 168), rough=0.35, metallic=0.7)
    vinyl = mk.noisy("Umb_Vinyl", srgb(200, 206, 210), srgb(226, 230, 232), scale=10, roughness=0.15)
    black = pk.plastic("Umb_Black", (24, 24, 28))
    navy = pk.plastic("Umb_Navy", (30, 40, 80))
    handle = pk.plastic("Umb_Handle", (230, 230, 226))
    parts = [mk.cylinder("Bin", 0.65, 1.5, (0, 0, 0.75), mat=steel, verts=16),
             mk.torus("Rim", 0.65, 0.04, (0, 0, 1.5), mat=steel, major_segments=16, minor_segments=4)]
    rng = random.Random(8)
    for k in range(6):
        a = 2 * math.pi * k / 6
        x, y = math.cos(a) * 0.35, math.sin(a) * 0.35
        m = black if k == 2 else navy if k == 4 else vinyl
        tilt_x, tilt_y = rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3)
        top = (x + tilt_x, y + tilt_y, 3.3 + rng.uniform(-0.2, 0.2))
        parts += [mk.tube("Canopy", (x, y, 0.6), top, 0.2, 0.12, mat=m, verts=8),
                  mk.tube("Shaft", top, (top[0], top[1], top[2] + 0.4), 0.03, mat=handle, verts=5),
                  mk.torus("Crook", 0.14, 0.04, (top[0] + 0.14, top[1], top[2] + 0.45), rot=(90, 0, 0), mat=handle,
                           major_segments=10, minor_segments=4)]
    return parts, []


# Outside ------------------------------------------------------------------------------------------------


@prop("UmpireChair", pivot="bottom", material="Metal", collide=True, texture=512, set="Campus")
def umpire_chair():
    """The tennis court's umpire chair: a tall green steel frame with its ladder, the seat and its
    little writing shelf, snow on the seat and the rungs."""
    green = pk.paint("Ump_Green", (40, 80, 60), rough=0.4)
    wood = mk.wood("Ump_Wood", srgb(150, 110, 70), srgb(100, 70, 44), scale=4)
    sn = snow("Ump")
    parts = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(mk.tube("Leg", (sx * 1.2, sy * 1.2, 0.0), (sx * 0.8, sy * 0.8, 5.5), 0.1, mat=green, verts=8))
    for k in range(6):
        zz = 0.8 + k * 0.8
        parts.append(mk.box("Rung", (1.9 - k * 0.07, 0.12, 0.1), (0, -1.15 + k * 0.06, zz), mat=green))
        if k % 2 == 0:
            parts.append(cap("RungSnow", (1.7 - k * 0.07, 0.14, 0.08), (0, -1.15 + k * 0.06, zz + 0.09), sn, r=0.03))
    parts += [mk.box("Platform", (2.0, 2.0, 0.14), (0, 0, 5.55), mat=wood),
              mk.box("Seat", (1.4, 1.2, 0.14), (0, 0.3, 6.3), mat=wood),
              mk.box("SeatPost", (0.14, 0.14, 0.8), (0, 0.3, 5.9), mat=green),
              mk.box("Backrest", (1.4, 0.12, 1.2), (0, 0.9, 7.0), mat=wood),
              mk.box("Shelf", (1.4, 0.5, 0.08), (0, -0.7, 6.8), rot=(-10, 0, 0), mat=wood),
              cap("SeatSnow", (1.3, 1.1, 0.2), (0, 0.3, 6.46), sn),
              cap("PlatformSnow", (1.8, 0.7, 0.14), (0, -0.55, 5.69), sn)]
    for sx in (-1, 1):
        parts.append(mk.tube("Arm", (sx * 0.7, 0.9, 6.3), (sx * 0.7, -0.3, 6.8), 0.05, mat=green, verts=6))
    return parts, []


@prop("TennisNet", pivot="bottom", material="Fabric", collide=True, texture=512, set="Campus")
def tennis_net():
    """A tennis net left up for the winter, sagging under a line of snow along its white tape,
    between its two green posts (40 studs apart)."""
    green = pk.paint("Net_Green", (40, 80, 60), rough=0.4)
    net = mk.banded("Net_Mesh", srgb(14, 16, 16), srgb(46, 50, 48), frequency=180.0, axis="X", roughness=0.9)
    tape = pk.plastic("Net_Tape", (236, 236, 230))
    sn = snow("Net")
    half = 20.0
    parts = []
    for sx in (-1, 1):
        parts += [mk.cylinder("Post", 0.18, 3.8, (sx * half, 0, 1.9), mat=green, verts=10),
                  mk.cylinder("PostCap", 0.22, 0.1, (sx * half, 0, 3.85), mat=green, verts=10),
                  cap("PostSnow", (0.4, 0.4, 0.16), (sx * half, 0, 3.98), sn)]
    segments = 8
    for k in range(segments):
        u0, u1 = k / segments, (k + 1) / segments
        x0, x1 = -half + 2 * half * u0, -half + 2 * half * u1
        z0 = 3.4 - 0.5 * math.sin(math.pi * u0)
        z1 = 3.4 - 0.5 * math.sin(math.pi * u1)
        mid_x, mid_z = (x0 + x1) / 2, (z0 + z1) / 2
        length = math.hypot(x1 - x0, z1 - z0)
        angle = math.degrees(math.atan2(z1 - z0, x1 - x0))
        parts += [mk.box("Tape", (length + 0.02, 0.08, 0.28), (mid_x, 0, mid_z), rot=(0, -angle, 0), mat=tape),
                  mk.box("Mesh", (length + 0.02, 0.02, mid_z - 0.35), (mid_x, 0, (mid_z - 0.1) / 2 + 0.1), mat=net),
                  cap(f"TapeSnow{k}", (length, 0.22, 0.14), (mid_x, 0, mid_z + 0.2), sn, r=0.05)]
    return parts, []


@prop("BustStatue", pivot="bottom", material="Slate", collide=True, texture=1024, set="Campus")
def bust_statue():
    """The founder's bronze bust on a granite plinth, the plaque on its face, snow on his head and
    shoulders and on the plinth's top."""
    granite = mk.noisy("Bust_Granite", srgb(70, 70, 72), srgb(104, 104, 108), scale=16, roughness=0.7)
    bronze = mk.noisy("Bust_Bronze", srgb(46, 60, 50), srgb(90, 80, 56), scale=10, roughness=0.45, metallic=0.7)
    brass = pk.metal("Bust_Plaque", (150, 120, 60), (196, 160, 90), rough=0.3, metallic=0.9)
    ink = pk.plastic("Bust_Ink", (30, 26, 20))
    sn = snow("Bust")
    parts = [mk.box("Step", (3.0, 3.0, 0.5), (0, 0, 0.25), mat=granite, bevel=0.04),
             mk.box("Plinth", (2.2, 2.2, 4.0), (0, 0, 2.5), mat=granite, bevel=0.04),
             mk.box("PlinthCap", (2.5, 2.5, 0.3), (0, 0, 4.65), mat=granite, bevel=0.04),
             mk.sphere("Shoulders", 1.0, (0, 0, 5.3), scale=(1.1, 0.6, 0.55), mat=bronze, segments=16, rings=10),
             mk.cylinder("Neck", 0.3, 0.6, (0, 0.05, 5.8), mat=bronze, verts=12),
             mk.sphere("Head", 0.5, (0, 0.05, 6.45), scale=(0.85, 0.95, 1.05), mat=bronze, segments=16, rings=12),
             mk.box("Nose", (0.14, 0.2, 0.25), (0, -0.4, 6.4), mat=bronze, bevel=0.05),
             mk.box("Plaque", (1.4, 0.06, 0.8), (0, -1.12, 3.4), mat=brass, bevel=0.02),
             cap("HeadSnow", (0.7, 0.8, 0.2), (0, 0.05, 6.93), sn),
             cap("ShoulderSnowL", (0.8, 0.9, 0.14), (-0.6, 0, 5.72), sn),
             cap("ShoulderSnowR", (0.8, 0.9, 0.14), (0.6, 0, 5.72), sn),
             cap("PlinthSnow", (2.3, 2.3, 0.18), (0, 0, 4.88), sn)]
    parts += pk.label("PlaqueText", "創立者", 0.26, (0, -1.16, 3.5), ink)
    return parts, []
