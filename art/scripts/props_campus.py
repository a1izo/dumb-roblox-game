"""Kagegaoka University's props (set "Campus", exported to DeathsGambitModels_Campus.fbx): a winter
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
import stationkit as sk
from common import srgb
from props import prop

LAMP_WARM = (255, 210, 150)
SNOW_A, SNOW_B = (214, 222, 236), (246, 248, 252)


def snow(prefix="Cps"):
    return mk.noisy(prefix + "_Snow", srgb(*SNOW_A), srgb(*SNOW_B), scale=22, roughness=0.85)


def cap(name, size, loc, mat, r=0.12):
    """A soft cushion of snow lying on something."""
    return pk.rounded(name, size, loc, mat, r=min(r, min(size) / 2 - 0.01))


# Station looks -----------------------------------------------------------------------------------------

CAMPOST_SCREEN = (0.0, -0.16, 3.95, 2.2, 1.5, 0)


@prop("StationCameraPost", pivot="bottom", material="Metal", collide=False, texture=1024, set="Campus", anchor=(0, 0),
      screen=CAMPOST_SCREEN)
def station_camera_post():
    """Campus security's camera post in the pond hollow: on a concrete plinth a green steel equipment
    cabinet with two doors (hinges, a padlocked hasp, louvres, the warning plate), a weatherproof
    monitor housing on it with its rain hood (the game's screen), and behind them a galvanised pole
    with its junction box and conduit, the camera on its bracket in a sunshield looking out over the
    pond. Snow on every top."""
    steel = pk.paint("Cam_Steel", (92, 112, 100), rough=0.5)
    dark = pk.metal("Cam_Dark", (24, 26, 28), (40, 42, 46), rough=0.5, metallic=0.3)
    galv = pk.metal("Cam_Galv", (120, 124, 128), (152, 156, 160), rough=0.45, metallic=0.6)
    concrete = mk.noisy("Cam_Concrete", srgb(108, 106, 102), srgb(136, 134, 130), roughness=0.85)
    white = pk.plastic("Cam_White", (222, 224, 222))
    plate = pk.plastic("Cam_Plate", (236, 200, 40))
    ink = pk.plastic("Cam_Ink", (20, 20, 20))
    glass = pk.dark_glass("Cam_Glass", (30, 36, 44))
    sn = snow("Cam")
    x, y, z, w, h, tilt = CAMPOST_SCREEN
    parts = [mk.box("Plinth", (5.3, 2.9, 0.3), (0, 0, 0.15), mat=concrete, bevel=0.05),
             mk.box("Box", (5.0, 2.5, 2.05), (0, 0.05, 1.33), mat=steel, bevel=0.04),
             mk.box("BoxLid", (5.2, 2.7, 0.12), (0, 0.05, 2.42), mat=steel, bevel=0.03),
             mk.box("Drip", (5.16, 0.04, 0.06), (0, -1.28, 2.33), mat=steel)]
    for sx in (-1, 1):  # (two doors meeting in the middle, hinged at the ends)
        dx = sx * 1.22
        parts += [mk.box("Door", (2.38, 0.04, 1.85), (dx, -1.215, 1.33), mat=steel, bevel=0.015)]
        parts += pk.hinge("Hinge", sx * 2.42, -1.25, 1.85, 0.3, dark) + pk.hinge("Hinge", sx * 2.42, -1.25, 0.8, 0.3, dark)
        parts += pk.louvres("Vent", sx * 1.6, -1.24, 1.0, 0.9, 0.7, steel, count=5)
    parts += [mk.box("Hasp", (0.2, 0.04, 0.3), (0.0, -1.25, 1.45), mat=dark),
              mk.torus("Shackle", 0.07, 0.015, (0.0, -1.3, 1.36), rot=(90, 0, 0), mat=galv, major_segments=12, minor_segments=4),
              pk.rounded("Padlock", (0.18, 0.08, 0.2), (0.0, -1.31, 1.22), pk.metal("Cam_Brass", (170, 136, 70), (210, 176, 96), 0.3, 0.9),
                         r=0.03)]
    parts += pk.handle("Pull", -0.3, -1.24, 1.45, 0.5, dark, vertical=True, stand=0.07, r=0.025)
    parts += pk.handle("Pull", 0.3, -1.24, 1.45, 0.5, dark, vertical=True, stand=0.07, r=0.025)
    parts += pk.label("Warning", "防犯カメラ作動中", 0.15, (-1.22, -1.245, 2.0), ink, plate=plate)
    # The monitor housing on the cabinet, its hood keeping the snow off the screen.
    parts += [mk.box("Cabinet", (2.9, 1.5, 2.6), (x, 0.65, 3.78), mat=steel, bevel=0.04),
              mk.box("Hood", (3.1, 1.2, 0.08), (x, -0.25, 5.2), rot=(-10, 0, 0), mat=steel, bevel=0.02)]
    for sx in (-1, 1):
        parts.append(sk.wedge("HoodSide", [(-0.85, 4.48), (0.35, 4.48), (0.35, 5.22), (-0.85, 5.12)], 0.05, sx * 1.5, steel))
    mon, glows = sk.lcd("Mon_", CAMPOST_SCREEN, dark, dark, border=0.14, back=0.12)
    parts += mon
    parts += sk.screws("Screw", [(x + sx * 1.35, -0.12, z + sz * 0.88) for sx in (-1, 1) for sz in (-1, 1)], galv, r=0.03)
    # The pole, its box and conduit, the bracket and the camera.
    px, py = 1.9, 1.05
    parts += [mk.cylinder("PoleFoot", 0.32, 0.12, (px, py, 2.54), mat=galv, verts=16),
              mk.cylinder("Pole", 0.17, 10.6, (px, py, 7.84), mat=galv, verts=14, radius2=0.13),
              pk.rounded("JBox", (0.5, 0.3, 0.6), (px, py - 0.24, 4.2), galv, r=0.03),
              mk.cylinder("PoleCap", 0.15, 0.08, (px, py, 13.18), mat=galv, verts=12),
              mk.tube("Conduit", (px + 0.12, py - 0.18, 2.5), (px + 0.12, py - 0.18, 3.9), 0.04, mat=dark, verts=6),
              mk.tube("Conduit2", (px - 0.05, py - 0.18, 4.5), (px - 0.05, py - 0.18, 12.3), 0.03, mat=dark, verts=6)]
    for zz in (5.5, 8.0, 10.5):
        parts.append(mk.torus("Band", 0.16, 0.02, (px, py, zz), mat=galv, major_segments=14, minor_segments=4))
    cy, cz = -0.9, 12.45
    parts += [mk.tube("Arm", (px, py - 0.12, 12.75), (px, cy, 12.85), 0.07, mat=galv, verts=8),
              mk.box("ArmPlate", (0.3, 0.06, 0.4), (px, py - 0.12, 12.75), mat=galv),
              mk.cylinder("Swivel", 0.08, 0.2, (px, cy + 0.0, 12.75), mat=dark, verts=10)]
    cam = [pk.rounded("Housing", (0.55, 1.4, 0.5), (px, cy - 0.15, cz), white, r=0.08),
           mk.box("Sunshield", (0.7, 1.6, 0.05), (px, cy - 0.25, cz + 0.3), mat=white, bevel=0.01),
           mk.cylinder("LensRing", 0.2, 0.06, (px, cy - 0.87, cz - 0.02), rot=(90, 0, 0), mat=dark, verts=16),
           mk.cylinder("Lens", 0.16, 0.02, (px, cy - 0.9, cz - 0.02), rot=(90, 0, 0), mat=glass, verts=16),
           cap("SnowShield", (0.62, 1.4, 0.14), (px, cy - 0.25, cz + 0.39), sn)]
    led = [mk.cylinder("Rec", 0.04, 0.02, (px + 0.16, cy - 0.89, cz + 0.15), rot=(90, 0, 0), mat=pk.glow("Cam_LedRed", (255, 40, 40), 6),
                       verts=8)]
    sk.tilt_about(cam + led, (px, cy, cz), -16)
    parts += cam + [sk.cable("CamCable", [(px, cy + 0.5, cz - 0.2), (px - 0.05, py - 0.1, 12.3)], dark, r=0.025)]
    glows += led
    glows.append(mk.box("CabLed", (0.06, 0.02, 0.06), (x + 1.25, -0.1, 4.75), mat=pk.glow("Cam_LedGreen", (80, 255, 140), 5)))
    # Snow on the tops.
    parts += [cap("SnowBoxL", (2.0, 2.5, 0.22), (-1.55, 0.05, 2.58), sn),
              cap("SnowBoxR", (0.9, 2.0, 0.18), (2.1, -0.2, 2.56), sn),
              cap("SnowHood", (2.9, 1.0, 0.18), (x, -0.25, 5.34), sn),
              cap("SnowCab", (2.7, 1.1, 0.16), (x, 0.85, 5.16), sn),
              cap("SnowPlinth", (5.2, 0.35, 0.1), (0, -1.32, 0.34), sn, r=0.04)]
    return parts, glows


PUBPHONE_SCREEN = (0.9, 1.05, 4.95, 2.3, 1.4, 0)


def public_phone(prefix, x, y, z, green, face, dark, key, ink, glow_rgb=(170, 240, 160)):
    """Japan's grey-green digital public phone standing at z, face to -Y: the body, its face plate with
    the little LCD, the keypad, coin and card slots and the coin return, the handset on its hook at
    the left and its coiled cord. Returns (parts, glows)."""
    parts = [pk.rounded(prefix + "Body", (1.25, 0.8, 1.85), (x, y, z + 0.925), green, r=0.12),
             pk.rounded(prefix + "Face", (1.05, 0.04, 1.4), (x + 0.05, y - 0.41, z + 1.0), face, r=0.03),
             mk.box(prefix + "Lcd", (0.55, 0.02, 0.2), (x + 0.05, y - 0.435, z + 1.5), mat=dark),
             mk.box(prefix + "CoinSlot", (0.06, 0.02, 0.3), (x + 0.42, y - 0.435, z + 1.25), mat=dark),
             mk.box(prefix + "CardSlot", (0.45, 0.02, 0.04), (x + 0.05, y - 0.435, z + 0.55), mat=dark),
             mk.box(prefix + "Return", (0.4, 0.16, 0.18), (x + 0.25, y - 0.47, z + 0.28), mat=dark, bevel=0.03)]
    for r in range(4):
        for c in range(3):
            parts.append(mk.box(prefix + "Key", (0.13, 0.04, 0.1), (x - 0.12 + c * 0.16, y - 0.44, z + 1.22 - r * 0.14), mat=key,
                                bevel=0.012))
    hx = x - 0.72
    parts += [mk.box(prefix + "Hook", (0.1, 0.3, 0.3), (hx + 0.1, y - 0.1, z + 1.4), mat=dark, bevel=0.02),
              pk.sweep(prefix + "Handset", [(hx, y - 0.15, z + 1.62), (hx - 0.04, y - 0.17, z + 1.35), (hx - 0.04, y - 0.17, z + 0.85),
                                            (hx, y - 0.15, z + 0.6)], 0.07, green, sides=8),
              mk.sphere(prefix + "Ear", 1.0, (hx + 0.02, y - 0.17, z + 1.64), scale=(0.1, 0.12, 0.14), mat=green, segments=12, rings=6),
              mk.sphere(prefix + "Mouth", 1.0, (hx + 0.02, y - 0.17, z + 0.58), scale=(0.1, 0.12, 0.14), mat=green, segments=12,
                        rings=6),
              pk.coil(prefix + "Cord", (hx + 0.02, y - 0.12, z + 0.5), (x - 0.5, y - 0.1, z + 0.35), 5, 0.04, 0.012, dark, sag=0.3)]
    parts += pk.label(prefix + "Sign", "公衆電話", 0.09, (x + 0.05, y - 0.435, z + 1.67), ink)
    glows = [mk.box(prefix + "LcdLit", (0.5, 0.01, 0.16), (x + 0.05, y - 0.447, z + 1.5), mat=pk.glow(prefix + "Lcd", glow_rgb, 2))]
    return parts, glows


@prop("StationPublicPhone", pivot="bottom", material="Wood", collide=False, texture=1024, set="Campus", anchor=(0, 0),
      screen=PUBPHONE_SCREEN)
def station_public_phone():
    """The cafeteria's public telephone corner: a wooden counter unit (a cubby of directories, a
    drawer, its kick plinth), the grey-green public phone on it, a coin tray and a memo pad on its
    chain, and on the tiled back panel the lit 公衆電話 sign box and the call information display
    (the game's screen) with a notice of rates beside it."""
    rng = random.Random(83)
    wood = mk.wood("Pub_Wood", srgb(128, 88, 56), srgb(74, 48, 30), scale=4)
    tile = mk.noisy("Pub_Tile", srgb(196, 196, 186), srgb(218, 218, 208), roughness=0.3)
    grout = mk.flat("Pub_Grout", srgb(150, 150, 142), 0.8)
    green = pk.paint("Pub_Green", (120, 150, 128), rough=0.35)
    face = pk.plastic("Pub_Plastic", (196, 200, 196))
    dark = pk.metal("Pub_Dark", (22, 24, 24), (38, 40, 40), rough=0.5, metallic=0.2)
    key = pk.plastic("Pub_Button", (230, 232, 228))
    ink = pk.plastic("Pub_Ink", (30, 90, 50))
    white = pk.plastic("Pub_White", (246, 246, 242))
    paper = mk.noisy("Pub_Paper", srgb(222, 218, 202), srgb(240, 236, 222), roughness=0.9)
    alu = pk.metal("Pub_Alu", (170, 174, 180), (206, 210, 216), rough=0.3, metallic=0.8)
    x, y, z, w, h, tilt = PUBPHONE_SCREEN
    parts = [mk.box("Body", (2.5, 2.3, 2.55), (-1.25, 0.0, 1.43), mat=wood, bevel=0.03),
             mk.box("Plinth", (4.9, 2.2, 0.16), (0, 0.05, 0.08), mat=dark),
             mk.box("Top", (5.2, 2.5, 0.1), (0, 0.0, 2.75), mat=wood, bevel=0.03),
             mk.box("CubbyFloor", (2.42, 2.3, 0.1), (1.25, 0.0, 0.21), mat=wood),
             mk.box("CubbyShelf", (2.36, 2.1, 0.06), (1.25, 0.05, 1.42), mat=wood),
             mk.box("CubbyBack", (2.42, 0.06, 2.55), (1.25, 1.12, 1.43), mat=wood),
             mk.box("CubbySide", (0.08, 2.3, 2.55), (2.46, 0.0, 1.43), mat=wood, bevel=0.02)]
    for k, rgb in enumerate(((226, 196, 80), (200, 60, 50), (230, 220, 200), (60, 90, 160), (226, 196, 80))):
        book = pk.plastic(f"Pub_Book{k % 4}", rgb)
        parts += [pk.rounded(f"DirBook{k}", (0.3, 0.95, 1.0), (0.35 + k * 0.38, -0.5, 0.77), book, r=0.03),
                  mk.box(f"DirSpine{k}", (0.2, 0.01, 0.3), (0.35 + k * 0.38, -0.98, 0.95), mat=paper)]
        if k < 4:
            parts.append(pk.rounded(f"DirBookT{k}", (0.95, 0.85, 0.16), (1.2 + (k % 2) * 0.05, -0.45, 1.53 + k * 0.165), book, r=0.02,
                                    rot=(0, 0, (-5, 3, -2, 6)[k])))
    parts += sk.drawer("Drawer", -1.3, -1.15, 2.25, 2.0, 0.45, wood, alu)
    for k in range(2):
        parts.append(mk.box("Panel", (0.95, 0.04, 1.2), (-1.8 + k * 1.0, -1.17, 1.15), mat=wood, bevel=0.02))
    # The tiled back panel with its grout lines, the sign box over it.
    parts.append(mk.box("Back", (5.0, 0.22, 4.9), (0, 1.26, 5.25), mat=tile))
    for k in range(1, 10):
        parts.append(mk.box("GroutH", (4.98, 0.01, 0.025), (0, 1.145, 2.8 + k * 0.49), mat=grout))
    for k in range(1, 10):
        parts.append(mk.box("GroutV", (0.025, 0.01, 4.88), (-2.5 + k * 0.5, 1.145, 5.25), mat=grout))
    parts += [pk.rounded("SignBox", (3.2, 0.5, 0.75), (-0.2, 0.92, 7.25), green, r=0.05)]
    parts += pk.label("SignText", "公衆電話", 0.4, (-0.55, 0.64, 7.25), white)
    parts += pk.label("SignEn", "PUBLIC PHONE", 0.12, (0.95, 0.64, 7.25), white)
    glows = [mk.box("SignGlow", (3.0, 0.02, 0.6), (-0.2, 0.66, 7.25), mat=pk.glow("Pub_Sign", (120, 220, 150), 2.2))]
    # The phone and the things beside it.
    ph, lcd = public_phone("Ph_", -1.3, 0.35, 2.8, green, face, dark, key, ink)
    parts += ph
    glows += lcd
    parts += [mk.box("CoinTray", (0.6, 0.45, 0.06), (-0.2, -0.6, 2.83), mat=alu, bevel=0.01),
              mk.cylinder("Coin", 0.06, 0.012, (-0.3, -0.62, 2.87), mat=pk.metal("Pub_Brass", (170, 140, 80), (210, 180, 110), 0.3, 0.9),
                          verts=10),
              mk.cylinder("Coin", 0.07, 0.012, (-0.12, -0.55, 2.87), mat=alu, verts=10)]
    parts += sk.papers("Memo_", 0.65, -0.5, 2.8, paper, rng, n=5, w=0.5, d=0.65, spread=0.02)
    parts += sk.pen("MemoPen", (0.95, -0.8, 2.84), (1.1, -0.45, 2.84), dark, alu)
    parts.append(sk.cable("MemoChain", [(1.1, -0.45, 2.84), (1.25, -0.2, 2.82)], alu, r=0.008, sides=4))
    info, led = sk.lcd("Info_", PUBPHONE_SCREEN, dark, dark, border=0.12, back=0.1)
    parts += info
    glows += led
    parts += [mk.box("Rates", (0.8, 0.012, 1.1), (-2.0, 1.138, 4.9), rot=(0, -2, 0), mat=paper)]
    parts += sk.written("RatesInk", -2.0, 1.132, 4.9, dark, rng, lines=7, w=0.6, d=0.9, upright=True)
    return parts, glows


NEWS_SCREEN = (-0.7, 0.1, 4.2, 2.1, 1.6, 6)


@prop("StationNewsDesk", pivot="bottom", material="Wood", collide=False, texture=1024, set="Campus", anchor=(0, 0),
      screen=NEWS_SCREEN)
def station_news_desk():
    """The student newspaper's desk: a scarred wooden desk buried in proofs, a beige word processor
    (the game's screen) and its keyboard, a black rotary phone, an answering machine blinking red, a
    mug of pens and a red pencil, scissors and a glue pot, a clip lamp on the desk's edge, and behind
    it bundles of back issues tied with string."""
    rng = random.Random(7)
    wood = mk.wood("News_Wood", srgb(112, 76, 46), srgb(60, 40, 24), scale=4)
    top = mk.wood("News_Oak", srgb(100, 68, 42), srgb(56, 36, 22), scale=4)
    beige = pk.plastic("News_Plastic", (190, 180, 158))
    bezel = pk.plastic("News_Bezel", (70, 66, 60))
    dark = pk.plastic("News_Dark", (18, 18, 20), rough=0.25)
    key = pk.plastic("News_Button", (214, 206, 188))
    brass = pk.metal("News_Brass", (150, 118, 60), (200, 164, 90), rough=0.3, metallic=0.9)
    paper = mk.noisy("News_Paper", srgb(222, 218, 204), srgb(240, 236, 224), roughness=0.9)
    newsprint = mk.noisy("News_Print", srgb(190, 186, 172), srgb(216, 212, 200), roughness=0.9)
    ink = mk.flat("News_Ink", srgb(26, 24, 30), 0.6)
    red = pk.plastic("News_Mug", (170, 40, 40))
    string = mk.flat("News_String", srgb(170, 150, 110), 0.9)
    x, y, z, w, h, tilt = NEWS_SCREEN
    parts = sk.wood_desk("News_", wood, top, brass, w=5.2, d=2.6, h=2.95, pedestal=1.5)
    wp, glows = sk.crt("WP_", NEWS_SCREEN, beige, bezel, dark, depth=1.8, base_to=2.95, border=0.2, chin=0.14)
    parts += wp
    parts += sk.keyboard("Kb_", x, -0.85, 2.95, beige, key, w=2.0, d=0.66, numpad=False)
    # The rotary phone.
    rx, ry = 1.55, -0.5
    parts += [mk.lathe("PhoneBody", [(0.0, 0.0), (0.42, 0.0), (0.44, 0.04), (0.38, 0.22), (0.28, 0.34), (0.0, 0.36)],
                       (rx, ry, 2.95), mat=dark, segments=18),
              mk.cylinder("Dial", 0.2, 0.03, (rx, ry - 0.2, 3.22), rot=(-38, 0, 0), mat=paper, verts=18),
              mk.cylinder("DialCentre", 0.07, 0.035, (rx, ry - 0.2, 3.23), rot=(-38, 0, 0), mat=dark, verts=12)]
    for k in range(10):
        a = math.radians(60 + k * 27)
        hx, hz = math.cos(a) * 0.14, math.sin(a) * 0.14
        hole = (rx + hx, ry - 0.2 - hz * math.sin(math.radians(38)) - 0.012, 3.22 + hz * math.cos(math.radians(38)))
        parts.append(mk.cylinder("DialHole", 0.028, 0.01, hole, rot=(-38, 0, 0), mat=dark, verts=8))
    parts += [pk.sweep("Handset", [(rx - 0.48, ry + 0.08, 3.38), (rx - 0.3, ry + 0.1, 3.47), (rx + 0.3, ry + 0.1, 3.47),
                                   (rx + 0.48, ry + 0.08, 3.38)], 0.065, dark, sides=8),
              mk.sphere("Ear", 1.0, (rx - 0.48, ry + 0.08, 3.36), scale=(0.11, 0.14, 0.07), mat=dark, segments=12, rings=6),
              mk.sphere("Mouth", 1.0, (rx + 0.48, ry + 0.08, 3.36), scale=(0.11, 0.14, 0.07), mat=dark, segments=12, rings=6),
              pk.coil("Cord", (rx - 0.5, ry + 0.0, 3.3), (rx - 0.6, ry + 0.3, 2.97), 5, 0.04, 0.012, dark)]
    # The answering machine.
    parts += [pk.rounded("Machine", (1.0, 0.75, 0.28), (1.65, 0.6, 3.09), beige, r=0.04),
              mk.box("CassetteLid", (0.55, 0.3, 0.02), (1.55, 0.6, 3.235), mat=pk.plastic("News_Smoke", (80, 70, 60))),
              mk.box("Cassette", (0.45, 0.24, 0.02), (1.55, 0.6, 3.22), mat=dark)]
    for k in range(4):
        parts.append(mk.box("MachKey", (0.12, 0.08, 0.03), (1.95 + (k % 2) * 0.14, 0.45 + (k // 2) * 0.12, 3.24), mat=key))
    glows.append(mk.box("MsgLed", (0.06, 0.06, 0.02), (2.0, 0.78, 3.235), mat=pk.glow("News_Led", (255, 40, 40), 6)))
    # Proofs, the mug of pens, red pencil, scissors and glue.
    for k in range(7):
        parts.append(mk.box("Proof", (1.0, 1.35, 0.012), (-2.0 + rng.uniform(-0.15, 0.15), -0.45 + rng.uniform(-0.15, 0.15),
                                                          2.96 + k * 0.016), rot=(0, 0, rng.uniform(-14, 14)), mat=paper))
    top_z = 2.96 + 7 * 0.016
    for k in range(4):
        parts.append(mk.box("Column", (0.26, 1.0, 0.004), (-2.3 + k * 0.3, -0.45, top_z), rot=(0, 0, 3), mat=newsprint))
    parts.append(mk.box("Headline", (1.0, 0.16, 0.005), (-2.0, 0.12, top_z + 0.002), rot=(0, 0, 3), mat=ink))
    parts += sk.mug("Mug_", 0.75, -1.0, 2.95, red)
    for k in range(4):
        parts += sk.pen(f"MugPen{k}", (0.75 + (k - 1.5) * 0.06, -1.0 + (k % 2) * 0.05, 3.05),
                        (0.7 + (k - 1.5) * 0.12, -1.05 + (k % 2) * 0.1, 3.55), dark if k % 2 else pk.plastic(f"News_Pen{k}", (40, 70, 160)))
    parts.append(mk.tube("RedPencil", (-2.4, -0.9, top_z + 0.02), (-2.0, -1.05, top_z + 0.02), 0.02, mat=pk.plastic("News_Pencil", (190, 30, 30)), verts=6))
    for sgn in (-1, 1):
        parts += [mk.box("Blade", (0.5, 0.05, 0.012), (-1.95, -0.6 + sgn * 0.02, top_z + 0.01), rot=(0, 0, 20 + sgn * 8),
                         mat=pk.chrome("News_Chrome")),
                  mk.torus("Bow", 0.07, 0.018, (-2.25, -0.71 + sgn * 0.08, top_z + 0.02), mat=dark, major_segments=12,
                           minor_segments=4)]
    parts += [mk.cylinder("GluePot", 0.12, 0.25, (2.3, -1.0, 3.08), mat=pk.plastic("News_Glue", (230, 230, 220)), verts=12),
              mk.cylinder("GlueLid", 0.13, 0.05, (2.3, -1.0, 3.22), mat=pk.plastic("News_Lid", (210, 160, 40)), verts=12)]
    # The clip lamp on the desk's left edge.
    lamp, bulb = sk.desk_lamp("Clip_", -2.4, 1.05, 2.95, dark, dark, LAMP_WARM, reach=(0.0, -0.6), rise=1.35)
    parts += lamp
    glows += bulb
    # Bundles of back issues behind the desk, tied with string.
    for k, (bx, by, bz, yaw, hgt) in enumerate(((-1.5, 2.4, 0.0, 4, 1.0), (0.4, 2.5, 0.0, -6, 0.8), (-1.4, 2.3, 1.0, -3, 0.7),
                                                (1.7, 2.6, 0.0, 10, 1.1))):
        stack = [mk.box(f"Bundle{k}", (1.5, 1.1, hgt), (bx, by, bz + hgt / 2), mat=newsprint, bevel=0.03),
                 mk.box(f"TieA{k}", (1.52, 0.03, hgt + 0.02), (bx, by, bz + hgt / 2), mat=string),
                 mk.box(f"TieB{k}", (0.03, 1.12, hgt + 0.02), (bx, by, bz + hgt / 2), mat=string)]
        for j in range(int(hgt / 0.1)):
            stack.append(mk.box(f"Fold{k}", (1.52, 0.004, 0.02), (bx, by - 0.552, bz + 0.05 + j * 0.1), mat=paper))
        parts += sk.turn_about(stack, (bx, by, 0), yaw)
    return parts, glows


BOOKRET_SCREEN = (0.9, 0.25, 4.75, 2.2, 1.4, 10)


@prop("StationBookReturn", pivot="bottom", material="Wood", collide=False, texture=1024, set="Campus", anchor=(0, 0),
      screen=BOOKRET_SCREEN)
def station_book_return():
    """The library's book-return counter: raised oak panels in their mouldings toward the reader, the
    brass return slot with its flap, a dark counter top; behind it the worktop with the circulation
    terminal (the game's screen) and its keyboard, a fingerprint kit opened on a returned book, the
    handheld UV lamp glowing violet, the date stamp on its pad, a book truck's worth of returns and
    a box of catalogue cards."""
    rng = random.Random(3)
    oak = mk.wood("Ret_Oak", srgb(150, 106, 64), srgb(92, 60, 34), scale=4)
    top = mk.wood("Ret_Walnut", srgb(70, 48, 32), srgb(44, 30, 20), scale=4)
    brass = pk.metal("Ret_Brass", (160, 126, 64), (206, 170, 96), rough=0.3, metallic=0.9)
    dark = pk.plastic("Ret_Dark", (22, 22, 24))
    key = pk.plastic("Ret_Button", (40, 40, 44))
    case = pk.plastic("Ret_Case", (30, 32, 36))
    foam = mk.noisy("Ret_Foam", srgb(36, 36, 40), srgb(56, 56, 62), roughness=0.95, kind="rubber")
    card = mk.noisy("Ret_Card", srgb(226, 224, 214), srgb(244, 242, 234), roughness=0.8)
    pages = mk.noisy("Ret_Paper", srgb(222, 214, 192), srgb(238, 232, 214), roughness=0.9)
    ink = mk.flat("Ret_Ink", srgb(30, 26, 20), 0.6)
    x, y, z, w, h, tilt = BOOKRET_SCREEN
    parts = [mk.box("Front", (5.2, 0.3, 3.2), (0, -1.15, 1.75), mat=oak, bevel=0.03),
             mk.box("Plinth", (5.3, 0.4, 0.2), (0, -1.1, 0.1), mat=top),
             mk.box("Counter", (5.4, 1.2, 0.12), (0, -0.9, 3.41), mat=top, bevel=0.04),
             mk.box("Work", (5.0, 1.8, 0.1), (0, 0.55, 2.89), mat=oak, bevel=0.02),
             mk.box("Body", (5.0, 1.8, 2.75), (0, 0.55, 1.42), mat=oak, bevel=0.02)]
    for k in range(4):  # (raised panels in their frames, the slot in the second)
        px = -1.95 + k * 1.3
        parts += pk.frame(f"PanelFrame{k}", 1.15, 2.5, 0.08, 0.05, (px, -1.32, 1.6), oak)
        if k != 1:
            parts.append(mk.box(f"Panel{k}", (0.9, 0.04, 2.25), (px, -1.315, 1.6), mat=oak, bevel=0.06))
    sx = -0.65
    parts += [mk.box("SlotPlate", (1.0, 0.04, 0.7), (sx, -1.32, 2.3), mat=brass, bevel=0.02),
              mk.box("SlotMouth", (0.8, 0.02, 0.12), (sx, -1.345, 2.4), mat=dark),
              mk.box("SlotFlap", (0.84, 0.03, 0.16), (sx, -1.35, 2.45), rot=(-25, 0, 0), mat=brass, bevel=0.01),
              mk.box("SlotPanel", (0.9, 0.04, 1.4), (sx, -1.315, 1.1), mat=oak, bevel=0.06)]
    parts += pk.label("SlotLabel", "返却 RETURNS", 0.1, (sx, -1.345, 2.1), ink)
    parts += sk.screws("SlotScrew", [(sx + a * 0.42, -1.345, 2.3 + b * 0.28) for a in (-1, 1) for b in (-1, 1)], brass, r=0.025)
    # The terminal and keyboard on the worktop.
    term, glows = sk.lcd("Term_", BOOKRET_SCREEN, dark, key, stand_to=2.94, border=0.08, back=0.16, foot=(1.2, 0.5))
    parts += term
    parts += sk.keyboard("Kb_", x, -0.06, 2.94, dark, key, w=1.8, d=0.48)
    # On the counter: the returned book with the kit, the UV lamp, the stamp.
    parts += sk.book("Ret_", -1.0, -0.9, 3.47, pk.plastic("Ret_Cover", (40, 70, 110)), pages, yaw=-8, w=0.85, d=1.0)
    parts += [mk.box("PrintDust", (0.3, 0.3, 0.004), (-0.95, -0.95, 3.633), rot=(0, 0, -8), mat=pk.plastic("Ret_Powder", (60, 60, 64)))]
    parts += [pk.rounded("KitCase", (1.1, 0.75, 0.22), (-2.1, -0.85, 3.58), case, r=0.03),
              mk.box("KitFoam", (1.0, 0.65, 0.02), (-2.1, -0.85, 3.69), mat=foam)]
    for k, rgb in enumerate(((20, 20, 22), (230, 230, 226), (190, 150, 50))):
        parts += [mk.lathe(f"Jar{k}", [(0.0, 0.0), (0.09, 0.0), (0.1, 0.02), (0.1, 0.2), (0.0, 0.2)], (-2.4 + k * 0.28, -0.95, 3.69),
                           mat=pk.plastic(f"Ret_Jar{k}", rgb), segments=10),
                  mk.cylinder(f"JarLid{k}", 0.09, 0.05, (-2.4 + k * 0.28, -0.95, 3.91), mat=case, verts=10)]
    parts += [mk.tube("Brush", (-0.6, -1.25, 3.5), (-0.25, -1.0, 3.5), 0.02, mat=dark, verts=6),
              mk.tube("BrushHead", (-0.6, -1.25, 3.5), (-0.68, -1.31, 3.5), 0.03, 0.05, mat=pk.plastic("Ret_Fibre", (200, 180, 120)),
                      verts=8)]
    uv = [pk.rounded("UVLamp", (0.3, 0.95, 0.2), (0.15, -0.85, 3.57), case, r=0.06),
          mk.box("UVGrip", (0.26, 0.4, 0.04), (0.15, -0.6, 3.68), mat=pk.rubber("Ret_Rubber"))]
    uvg = [mk.box("UVGlow", (0.2, 0.55, 0.02), (0.15, -0.95, 3.675), mat=pk.glow("Ret_UV", (150, 90, 255), 4))]
    sk.turn_about(uv + uvg, (0.15, -0.85, 3.47), 25)
    parts += uv
    glows += uvg
    parts += [mk.box("StampPad", (0.45, 0.32, 0.05), (2.05, -0.75, 3.495), mat=case, bevel=0.01),
              mk.box("StampInk", (0.38, 0.25, 0.005), (2.05, -0.75, 3.523), mat=pk.plastic("Ret_Ink2", (40, 40, 120))),
              mk.cylinder("Stamp", 0.09, 0.3, (2.2, -1.1, 3.62), mat=dark, verts=10),
              mk.lathe("StampKnob", [(0.0, 0.0), (0.12, 0.0), (0.14, 0.06), (0.1, 0.14), (0.0, 0.16)], (2.2, -1.1, 3.77), mat=brass,
                       segments=12),
              mk.box("StampFoot", (0.25, 0.18, 0.05), (2.2, -1.1, 3.495), mat=dark)]
    # The returns at the back of the worktop, the card box.
    for k in range(6):
        c = rng.choice(((110, 40, 36), (40, 60, 90), (60, 80, 50), (140, 120, 80), (70, 50, 70), (30, 30, 34)))
        parts += sk.book(f"Rt{k}_", -1.8 + rng.uniform(-0.06, 0.06), 0.95, 2.94 + k * 0.2, pk.plastic(f"Ret_Ret{k}", c), pages,
                         yaw=rng.uniform(-10, 10), w=0.8, d=1.05, h=0.19)
    parts += [mk.box("CardBox", (0.7, 1.0, 0.35), (-0.5, 0.95, 3.11), mat=top, bevel=0.02),
              mk.box("CatCards", (0.6, 0.9, 0.2), (-0.5, 0.95, 3.3), mat=card),
              mk.box("CatGuide", (0.6, 0.02, 0.28), (-0.5, 0.7, 3.32), mat=pk.plastic("Ret_Guide", (190, 70, 60)))]
    return parts, glows


VAULT_SCREEN = (1.2, 0.35, 4.4, 2.2, 1.4, 8)


@prop("StationVault", pivot="bottom", material="Metal", collide=False, texture=1024, set="Campus", anchor=(0, 0),
      screen=VAULT_SCREEN)
def station_vault():
    """Student affairs' exam paper vault: a round steel vault door set in its heavy stepped frame in
    the wall (the locking bolts round its edge, the three-spoke wheel, the combination dial with its
    marks, the great hinge), the keypad lit beside it; in front, the steel table with tomorrow's
    sealed exam boxes, the access terminal (the game's screen), a print-lifting kit, a torch and the
    clipboard of who signed in."""
    rng = random.Random(97)
    steel = pk.metal("Vault_Steel", (110, 114, 120), (146, 150, 156), rough=0.3, metallic=0.85)
    frame = pk.metal("Vault_Frame", (54, 56, 60), (78, 80, 86), rough=0.45, metallic=0.6)
    chrome = pk.chrome("Vault_Chrome")
    dark = pk.plastic("Vault_Dark", (22, 22, 24))
    top = pk.plastic("Vault_Resin", (120, 122, 126), rough=0.5)
    body = pk.paint("Vault_Paint", (70, 74, 80), rough=0.45)
    trim = pk.metal("Vault_Trim", (30, 30, 34), (48, 48, 52), rough=0.4, metallic=0.5)
    cardboard = mk.noisy("Vault_Card", srgb(160, 120, 76), srgb(186, 146, 100), roughness=0.8)
    seal = pk.plastic("Vault_Seal", (180, 30, 36))
    label = mk.noisy("Vault_Label", srgb(230, 228, 218), srgb(244, 242, 234), roughness=0.8)
    ink = mk.flat("Vault_Ink", srgb(24, 24, 28), 0.6)
    x, y, z, w, h, tilt = VAULT_SCREEN
    dx, dz, r = -1.0, 4.6, 2.5
    parts = [mk.box("Frame", (7.0, 0.5, 9.0), (-0.4, 2.1, 4.5), mat=frame, bevel=0.06),
             mk.box("FrameFace", (6.6, 0.1, 8.6), (-0.4, 1.8, 4.5), mat=frame, bevel=0.04),
             mk.cylinder("Jamb", r + 0.35, 0.2, (dx, 1.65, dz), rot=(90, 0, 0), mat=steel, verts=48, bevel=0.04),
             mk.cylinder("Door", r, 0.5, (dx, 1.3, dz), rot=(90, 0, 0), mat=steel, verts=48, bevel=0.06),
             mk.cylinder("DoorStep", r - 0.35, 0.12, (dx, 1.0, dz), rot=(90, 0, 0), mat=steel, verts=48, bevel=0.03),
             mk.torus("DoorRing", r - 0.2, 0.06, (dx, 1.03, dz), rot=(90, 0, 0), mat=chrome, major_segments=48, minor_segments=6),
             mk.cylinder("Hub", 0.42, 0.2, (dx, 0.86, dz), rot=(90, 0, 0), mat=chrome, verts=24, bevel=0.03)]
    for k in range(3):  # (the wheel: three spokes with their knobbed handles)
        a = math.radians(90 + k * 120)
        tip = (dx + math.cos(a) * 1.15, 0.72, dz + math.sin(a) * 1.15)
        parts += [mk.tube("Spoke", (dx, 0.78, dz), tip, 0.06, 0.05, mat=chrome, verts=8),
                  mk.sphere("Knob", 0.11, tip, mat=chrome, segments=12, rings=8)]
    for k in range(14):
        a = 2 * math.pi * k / 14
        parts.append(mk.cylinder("Bolt", 0.12, 0.16, (dx + math.cos(a) * (r - 0.15), 1.0, dz + math.sin(a) * (r - 0.15)), rot=(90, 0, 0),
                                 mat=chrome, verts=10))
    # The combination dial above the wheel, with its marks.
    cx, cz = dx, dz + 1.55
    parts += [mk.cylinder("DialRing", 0.3, 0.06, (cx, 0.95, cz), rot=(90, 0, 0), mat=chrome, verts=24),
              mk.cylinder("Dial", 0.24, 0.1, (cx, 0.9, cz), rot=(90, 0, 0), mat=dark, verts=24, bevel=0.015),
              mk.cylinder("DialGrip", 0.1, 0.08, (cx, 0.82, cz), rot=(90, 0, 0), mat=chrome, verts=12)]
    for k in range(20):
        a = 2 * math.pi * k / 20
        ln = 0.06 if k % 5 else 0.1
        parts.append(mk.box("DialMark", (0.012, 0.01, ln), (cx + math.sin(a) * (0.22 - ln / 2), 0.848, cz + math.cos(a) * (0.22 - ln / 2)),
                            rot=(0, math.degrees(a), 0), mat=chrome))
    parts += [mk.box("HingeBody", (0.6, 0.8, 3.0), (dx + r + 0.25, 1.25, dz), mat=frame, bevel=0.06),
              mk.cylinder("HingePin", 0.2, 3.2, (dx + r + 0.25, 0.95, dz), mat=chrome, verts=16)]
    parts += [mk.box("MakerPlate", (1.0, 0.03, 0.3), (dx, 0.835, dz - 1.4), mat=pk.metal("Vault_Brass", (170, 136, 70), (210, 176, 96), 0.3, 0.9))]
    parts += pk.label("Maker", "KAGEGAOKA SAFE CO.", 0.06, (dx, 0.82, dz - 1.4), ink)
    # The keypad on the frame at the right.
    kx, kz = 2.55, 5.8
    parts += [pk.rounded("Keypad", (0.8, 0.12, 1.2), (kx, 1.68, kz), dark, r=0.04)]
    for rr in range(4):
        for c in range(3):
            parts.append(mk.box("PadKey", (0.16, 0.04, 0.13), (kx - 0.22 + c * 0.22, 1.605, kz - 0.05 - rr * 0.18), mat=chrome, bevel=0.01))
    glows = [mk.box("KeyLed", (0.08, 0.02, 0.08), (kx - 0.15, 1.6, kz + 0.45), mat=pk.glow("Vault_LedRed", (255, 50, 40), 5)),
             mk.box("KeyLed2", (0.08, 0.02, 0.08), (kx + 0.15, 1.6, kz + 0.45), mat=pk.glow("Vault_LedGreen", (80, 255, 140), 5))]
    # The table, terminal, boxes, kit, torch and clipboard.
    parts += sk.steel_desk("Vault_", top, body, trim, w=5.2, d=2.2, h=2.95, pedestal=0, y0=-0.2, modesty=False)
    term, led = sk.lcd("Access_", VAULT_SCREEN, dark, ink, stand_to=2.95, border=0.08, back=0.16, foot=(1.2, 0.6))
    parts += term
    glows += led
    parts += sk.keyboard("Kb_", 0.95, -0.65, 2.95, dark, pk.plastic("Vault_Button", (44, 46, 50)), w=1.5, d=0.55, numpad=False)
    for k, (bx, by, bz, rot) in enumerate(((-1.75, -0.1, 2.95, 4), (-1.75, -0.1, 3.75, -6), (-0.35, 0.0, 2.95, -3))):
        box = [mk.box(f"ExamBox{k}", (1.4, 1.1, 0.8), (bx, by, bz + 0.4), mat=cardboard, bevel=0.02),
               mk.box(f"Seal{k}", (0.2, 1.12, 0.82), (bx, by, bz + 0.4), mat=seal),
               mk.box(f"SealT{k}", (1.42, 0.2, 0.82), (bx, by, bz + 0.4), mat=seal),
               mk.box(f"Label{k}", (0.7, 0.01, 0.35), (bx + 0.35, by - 0.556, bz + 0.45), mat=label),
               mk.box(f"Stamp{k}", (0.22, 0.008, 0.22), (bx - 0.4, by - 0.555, bz + 0.5), mat=seal)]
        box += sk.written(f"LabelInk{k}", bx + 0.35, by - 0.561, bz + 0.45, ink, rng, lines=3, w=0.5, d=0.3, upright=True)
        parts += sk.turn_about(box, (bx, by, bz), rot)
    parts += [pk.rounded("KitCase", (1.0, 0.7, 0.24), (-0.55, -0.95, 3.07), dark, r=0.03),
              mk.box("TapeRoll", (0.26, 0.26, 0.12), (-1.3, -1.05, 3.01), mat=label, bevel=0.1),
              mk.tube("Torch", (-2.4, -1.05, 3.03), (-1.75, -0.95, 3.03), 0.07, mat=dark, verts=12),
              mk.tube("TorchHead", (-2.4, -1.05, 3.04), (-2.55, -1.08, 3.04), 0.07, 0.1, mat=chrome, verts=12)]
    parts += [mk.box("Clipboard", (0.8, 1.1, 0.03), (2.1, -0.5, 2.965), rot=(0, 0, -6), mat=cardboard),
              mk.box("ClipSheet", (0.72, 0.95, 0.008), (2.1, -0.55, 2.985), rot=(0, 0, -6), mat=label),
              mk.box("Clip", (0.35, 0.12, 0.06), (2.12, 0.0, 3.0), rot=(0, 0, -6), mat=chrome, bevel=0.01)]
    parts += sk.written("ClipInk", 2.1, -0.55, 2.99, ink, rng, lines=8, w=0.55, d=0.8, yaw=-6)
    return parts, glows


AUTOPSY_SCREEN = (1.5, 1.0, 5.2, 2.2, 1.4, 6)


@prop("StationAutopsy", pivot="bottom", material="Metal", collide=False, texture=1024, set="Campus", anchor=(0, 0),
      screen=AUTOPSY_SCREEN,
      lights=[dict(at=(0, -0.1, 8.1), kind="spot", face="Bottom", angle=70, color=(230, 240, 255), range=14,
                   brightness=1.3)])
def station_autopsy():
    """The forensic medicine lab's autopsy table: a stainless top with its raised lip, the drain
    grille along its length and the drain at its foot on a fluted pedestal, a spray hose coiled on
    its hook, a folded sheet and the head block; the surgical lamp swung over it on its column (the
    lit lamp), an instrument tray on its stand with the scalpel, forceps and scissors laid out, the
    hanging scale with its dial and dish, and the findings monitor on its arm (the game's screen)."""
    steel = pk.metal("Aut_Steel", (160, 164, 170), (200, 204, 210), rough=0.25, metallic=0.9)
    dark = pk.metal("Aut_Dark", (22, 24, 26), (40, 42, 46), rough=0.5, metallic=0.3)
    white = pk.plastic("Aut_White", (230, 232, 230))
    sheet = mk.noisy("Aut_Cloth", srgb(200, 214, 212), srgb(222, 234, 232), roughness=0.8)
    rubber = pk.rubber("Aut_Rubber")
    face = pk.plastic("Aut_Face", (240, 240, 236))
    ink = mk.flat("Aut_Ink", srgb(20, 20, 24), 0.6)
    x, y, z, w, h, tilt = AUTOPSY_SCREEN
    parts = [mk.box("Base", (2.4, 1.6, 0.16), (0, 0, 0.08), mat=steel, bevel=0.04),
             mk.lathe("Pedestal", [(0.0, 0.16), (0.7, 0.16), (0.58, 0.4), (0.5, 0.5), (0.5, 2.4), (0.7, 2.6), (0.0, 2.6)], (0, 0, 0),
                      mat=steel, segments=20),
             mk.box("Top", (5.4, 2.5, 0.14), (0, 0, 2.75), mat=steel, bevel=0.04),
             mk.box("Basin", (5.0, 2.1, 0.02), (0, 0, 2.83), mat=steel)]
    for sy in (-1, 1):
        parts.append(mk.box("LipL", (5.4, 0.1, 0.24), (0, sy * 1.2, 2.94), mat=steel, bevel=0.02))
    for sx in (-1, 1):
        parts.append(mk.box("LipE", (0.1, 2.3, 0.24), (sx * 2.65, 0, 2.94), mat=steel, bevel=0.02))
    for k in range(18):  # (the drain grille's holes down the middle)
        parts.append(mk.cylinder("Hole", 0.05, 0.005, (-2.0 + k * 0.24, 0.0, 2.843), mat=dark, verts=8))
    parts += [mk.cylinder("Drain", 0.18, 0.01, (2.3, 0, 2.845), mat=dark, verts=14),
              mk.torus("DrainRing", 0.18, 0.02, (2.3, 0, 2.85), mat=steel, major_segments=14, minor_segments=4),
              pk.rounded("HeadBlock", (0.55, 0.9, 0.3), (-2.15, 0, 2.99), rubber, r=0.12),
              pk.rounded("Sheet", (1.2, 1.8, 0.16), (1.35, 0.1, 2.92), sheet, r=0.06),
              pk.rounded("SheetFold", (1.1, 1.7, 0.1), (1.4, 0.12, 3.04), sheet, r=0.04)]
    # The spray hose on its hook at the foot end.
    parts += [mk.box("HoseHook", (0.1, 0.25, 0.3), (2.75, -0.95, 2.65), mat=steel),
              pk.coil("Hose", (2.78, -0.95, 2.6), (2.85, -0.8, 1.2), 3, 0.18, 0.035, rubber),
              mk.tube("Nozzle", (2.8, -0.98, 2.62), (2.8, -1.1, 2.95), 0.05, mat=steel, verts=8)]
    # The surgical lamp on its column at the back left, its arm over the table.
    parts += [mk.cylinder("ColBase", 0.7, 0.16, (-2.9, 1.8, 0.08), mat=white, verts=20, bevel=0.03),
              mk.cylinder("Column", 0.15, 8.7, (-2.9, 1.8, 4.5), mat=white, verts=14),
              mk.cylinder("ColJoint", 0.22, 0.3, (-2.9, 1.8, 8.85), mat=white, verts=14),
              mk.tube("Arm1", (-2.9, 1.8, 8.9), (-1.2, 0.6, 8.95), 0.09, mat=white, verts=10),
              mk.sphere("Knuckle", 0.13, (-1.2, 0.6, 8.95), mat=white, segments=12, rings=8),
              mk.tube("Arm2", (-1.2, 0.6, 8.95), (0, -0.1, 8.72), 0.08, mat=white, verts=10),
              mk.lathe("LampHead", [(0.0, 0.38), (0.25, 0.36), (0.9, 0.12), (1.0, 0.0), (1.0, -0.12), (0.0, -0.12)], (0, -0.1, 8.5),
                       mat=white, segments=32),
              mk.tube("LampHandle", (0, -0.1, 8.38), (0, -0.1, 8.15), 0.06, mat=dark, verts=10)]
    glows = []
    for k in range(6):
        a = 2 * math.pi * k / 6
        glows.append(mk.cylinder("LampCell", 0.22, 0.03, (math.cos(a) * 0.6, -0.1 + math.sin(a) * 0.6, 8.37),
                                 mat=pk.glow("Aut_Lamp", (230, 240, 255), 4), verts=14))
    glows.append(mk.cylinder("LampCentre", 0.2, 0.03, (0, -0.1, 8.37), mat=pk.glow("Aut_Lamp", (230, 240, 255), 4), verts=14))
    # The instrument tray on its stand, front right.
    parts += [mk.cylinder("TrayFoot", 0.45, 0.08, (3.3, -1.1, 0.05), mat=steel, verts=14),
              mk.cylinder("TrayPost", 0.06, 3.2, (3.3, -1.1, 1.68), mat=steel, verts=10),
              mk.box("Tray", (1.5, 1.0, 0.04), (3.0, -1.1, 3.3), mat=steel, bevel=0.01)]
    for sx in (-1, 1):
        parts.append(mk.box("TrayRim", (1.5, 0.04, 0.08), (3.0, -1.1 + sx * 0.5, 3.34), mat=steel))
        parts.append(mk.box("TrayRimE", (0.04, 1.0, 0.08), (3.0 + sx * 0.75, -1.1, 3.34), mat=steel))
    parts += [mk.box("Scalpel", (0.04, 0.6, 0.02), (2.5, -1.1, 3.33), mat=steel),
              mk.box("Blade", (0.05, 0.12, 0.01), (2.5, -1.45, 3.33), mat=pk.chrome("Aut_Chrome")),
              mk.box("ForcepsA", (0.03, 0.65, 0.02), (2.78, -1.1, 3.33), rot=(0, 0, 2), mat=steel),
              mk.box("ForcepsB", (0.03, 0.65, 0.02), (2.84, -1.1, 3.33), rot=(0, 0, -2), mat=steel),
              mk.box("ScissorA", (0.04, 0.55, 0.02), (3.15, -1.2, 3.33), rot=(0, 0, 6), mat=steel),
              mk.box("ScissorB", (0.04, 0.55, 0.02), (3.2, -1.2, 3.335), rot=(0, 0, -6), mat=steel),
              mk.torus("ScissorBow", 0.06, 0.015, (3.12, -0.85, 3.33), mat=steel, major_segments=10, minor_segments=4),
              mk.torus("ScissorBow", 0.06, 0.015, (3.26, -0.85, 3.33), mat=steel, major_segments=10, minor_segments=4),
              mk.box("Gauze", (0.4, 0.4, 0.04), (3.5, -0.85, 3.34), mat=sheet)]
    # The hanging scale and the monitor on its arm, back right.
    parts += [mk.cylinder("ScalePole", 0.09, 8.0, (2.9, 1.9, 4.0), mat=white, verts=10),
              mk.cylinder("ScaleFoot", 0.5, 0.08, (2.9, 1.9, 0.04), mat=white, verts=14),
              mk.tube("ScaleArm", (2.9, 1.9, 7.6), (2.9, 0.7, 7.6), 0.06, mat=white, verts=8),
              mk.cylinder("ScaleCase", 0.45, 0.2, (2.9, 0.7, 6.9), rot=(90, 0, 0), mat=white, verts=24, bevel=0.03),
              mk.cylinder("ScaleFace", 0.38, 0.01, (2.9, 0.595, 6.9), rot=(90, 0, 0), mat=face, verts=24),
              mk.box("ScaleNeedle", (0.012, 0.006, 0.3), (2.93, 0.585, 6.95), rot=(0, 25, 0), mat=pk.plastic("Aut_Red", (200, 30, 30))),
              mk.lathe("ScaleDish", [(0.0, 0.0), (0.7, 0.15), (0.75, 0.3), (0.72, 0.3), (0.0, 0.03)], (2.9, 0.7, 6.0), mat=steel,
                       segments=20, caps=False),
              mk.tube("ScaleRod", (2.9, 0.7, 7.62), (2.9, 0.7, 7.3), 0.035, mat=white, verts=6),
              mk.tube("MonArm", (2.9, 1.9, 5.6), (x + 0.4, y + 0.4, z), 0.07, mat=dark, verts=8),
              mk.cylinder("MonJoint", 0.1, 0.2, (2.9, 1.9, 5.6), mat=dark, verts=10)]
    for k in range(20):
        a = 2 * math.pi * k / 20
        ln = 0.05 if k % 5 else 0.09
        parts.append(mk.box("ScaleMark", (0.012, 0.008, ln), (2.9 + math.sin(a) * (0.33 - ln / 2), 0.588, 6.9 + math.cos(a) * (0.33 - ln / 2)),
                            rot=(0, math.degrees(a), 0), mat=ink))
    for k in range(3):  # (the dish's chains, from under the dial to its rim)
        a = 2 * math.pi * k / 3
        parts.append(mk.tube("ScaleChain", (2.9, 0.7, 6.45), (2.9 + math.cos(a) * 0.7, 0.7 + math.sin(a) * 0.7, 6.28), 0.012,
                             mat=steel, verts=4))
    parts.append(mk.tube("ScaleHook", (2.9, 0.7, 6.7), (2.9, 0.7, 6.45), 0.02, mat=steel, verts=6))
    mon, led = sk.lcd("Findings_", AUTOPSY_SCREEN, dark, dark, border=0.08, back=0.16)
    parts += mon
    glows += led
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


@prop("PineYukizuri", pivot="bottom", material="SmoothPlastic", collide=False, solids=True, texture=1024, set="Campus", anchor=(0, 0))
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
    """A clipped azalea mound under snow: dozens of small clumps of dark leaves crowded over a dark core (so it reads
    as a bush, leaf by leaf, and never as a ball), the snow lying in soft cushions on the clumps along its top, a few
    bare twigs poking through."""
    from props_lobby import _blob

    rng = random.Random(17)
    leaves = [mk.noisy("Shrub_Leaf", srgb(18, 36, 22), srgb(50, 76, 46), scale=70, roughness=0.8),
              mk.noisy("Shrub_Leaf2", srgb(24, 44, 26), srgb(58, 84, 50), scale=70, roughness=0.8)]
    core_mat = mk.noisy("Shrub_Core", srgb(12, 24, 16), srgb(28, 44, 28), scale=40, roughness=0.9)
    sn = snow("Shrub")
    twig = mk.noisy("Shrub_Twig", srgb(40, 32, 28), srgb(72, 60, 50), scale=20, roughness=0.9)
    mounds = ((-0.8, 0.1, 1.0), (0.75, -0.08, 0.95), (0.0, 0.2, 1.05), (-1.35, -0.05, 0.62), (1.4, 0.05, 0.62))
    core = _blob("Core", [("ellipsoid", (x, y, r * 0.62), r * 0.92, (1.15, 0.95, 0.8)) for x, y, r in mounds], 0.12, 0.5,
                 core_mat)
    parts = [core]
    # Clumps over each mound's surface (its upper half and shoulders), a cushion of snow on the ones on top.
    for x, y, r in mounds:
        for k in range(int(15 * r * r) + 5):
            a = rng.uniform(0, 2 * math.pi)
            up = rng.uniform(0.0, 1.0)  # (even over the dome: as many on top as round the sides)
            e = math.acos(1 - up)  # (from straight up to round the side)
            px = x + math.sin(e) * math.cos(a) * r * 1.0
            py = y + math.sin(e) * math.sin(a) * r * 0.92
            pz = r * 0.62 + math.cos(e) * r * 0.78
            cr = rng.uniform(0.34, 0.46) * (0.85 + 0.3 * r)
            clump = mk.sphere("Clump", cr, (px, py, pz), scale=(1, 1, 0.8), mat=rng.choice(leaves), segments=8, rings=6)
            mk.displace_noise(clump, strength=cr * 0.4, scale=cr * 0.6, name="ShrubClump")
            parts.append(clump)
            if math.cos(e) > 0.5:
                cushion = mk.sphere("Snow", cr * 1.1, (px, py, pz + cr * 0.45), scale=(1.1, 1.05, 0.45), mat=sn,
                                    segments=12, rings=6)
                mk.displace_noise(cushion, strength=cr * 0.25, scale=cr * 0.8, name="ShrubSnowLump")
                parts.append(cushion)
    for k in range(6):
        x, y, r = mounds[k % len(mounds)]
        a = rng.uniform(0, 2 * math.pi)
        base = (x + math.cos(a) * r * 0.3, y + math.sin(a) * r * 0.25, r * 1.1)
        tip = (base[0] + math.cos(a) * 0.35, base[1] + math.sin(a) * 0.3, base[2] + rng.uniform(0.35, 0.55))
        parts.append(mk.tube("Twig", base, tip, 0.035, 0.008, mat=twig, verts=5))
    return parts, []


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
      lights=[dict(at=(0, 0, 10.4), kind="spot", face="Bottom", angle=120, color=LAMP_WARM, range=26,
                   brightness=2.2)])  # a post's head: shaded above (maps/lightbook.py)
def campus_lamp():
    """A Meiji-style cast-iron lamp standard: a fluted base, the slender post with its ladder bar,
    a four-sided lantern, its frosted panes lit by the mantle, a pointed cap with snow on it."""
    iron = pk.metal("CLamp_Iron", (24, 26, 28), (44, 46, 50), rough=0.55, metallic=0.5)
    lit = pk.glow("CLamp_Glow", (255, 214, 150), 4)
    sn = snow("CLamp")
    parts = [mk.lathe("Base", [(0.62, 0.0), (0.62, 0.3), (0.5, 0.45), (0.42, 1.4), (0.3, 1.7), (0.24, 2.0), (0.0, 2.0)],
                      (0, 0, 0), mat=iron, segments=12),
             mk.cylinder("Post", 0.17, 7.2, (0, 0, 5.6), mat=iron, verts=10, radius2=0.12),
             mk.box("LadderBar", (1.6, 0.12, 0.12), (0, 0, 8.4), mat=iron, bevel=0.03),
             mk.cylinder("Collar", 0.28, 0.4, (0, 0, 9.3), mat=iron, verts=10),
             mk.box("LampFloor", (1.0, 1.0, 0.12), (0, 0, 9.55), mat=iron)]
    for sx in (-1, 1):
        parts.append(mk.sphere("BarEnd", 0.12, (sx * 0.8, 0, 8.4), mat=iron, segments=8, rings=6))
    glows = []
    for rot in (0, 90, 180, 270):  # (the panes of frosted glass, lit from the mantle inside)
        a = math.radians(rot)
        glows.append(mk.box("Pane", (0.88, 0.04, 1.3), (math.sin(a) * 0.44, -math.cos(a) * 0.44, 10.25), rot=(0, 0, rot),
                            mat=lit))
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(mk.box("Post", (0.08, 0.08, 1.4), (sx * 0.47, sy * 0.47, 10.25), mat=iron))
    roof = mk.lathe("Cap", [(0.0, 0.0), (0.72, 0.0), (0.72, 0.1), (0.2, 0.7), (0.06, 1.0), (0.0, 1.0)], (0, 0, 10.95),
                    mat=iron, segments=4)
    roof_snow = mk.lathe("CapSnow", [(0.0, 0.0), (0.66, 0.02), (0.2, 0.55), (0.0, 0.62)], (0, 0, 11.0), mat=sn, segments=4)
    for obj in (roof, roof_snow):
        obj.rotation_euler = (0, 0, math.radians(45))
    parts += [roof, roof_snow, mk.sphere("Finial", 0.1, (0, 0, 12.05), mat=iron, segments=8, rings=6)]
    return parts, glows


@prop("NoticeBoard", pivot="bottom", material="Wood", collide=True, texture=1024, set="Campus")
def notice_board():
    """A campus keijiban: a glass-fronted case on two timber legs under its own little roof, full
    of notices and club posters behind the glass; snow on the roof."""
    wood = mk.wood("NBoard_Wood", srgb(96, 66, 42), srgb(56, 38, 24), scale=4)
    cork = mk.noisy("NBoard_Cork", srgb(150, 110, 70), srgb(176, 136, 92), scale=40, roughness=0.9)
    slate = mk.noisy("NBoard_Roof", srgb(40, 44, 48), srgb(60, 64, 68), scale=16, roughness=0.6)
    sn = snow("NBoard")
    parts = [mk.box("LegL", (0.35, 0.35, 6.2), (-2.6, 0.1, 3.1), mat=wood),
             mk.box("LegR", (0.35, 0.35, 6.2), (2.6, 0.1, 3.1), mat=wood),
             mk.box("Case", (5.4, 0.5, 3.4), (0, 0.1, 4.2), mat=wood, bevel=0.04),
             mk.box("Cork", (5.0, 0.05, 3.0), (0, -0.16, 4.2), mat=cork),
             mk.box("Roof", (6.2, 1.4, 0.16), (0, 0.0, 6.35), rot=(-10, 0, 0), mat=slate, bevel=0.03),
             cap("RoofSnow", (6.0, 1.2, 0.22), (0, 0.05, 6.52), sn)]
    # The glass front as its frame alone (glass bakes solid: a pane hid every notice).
    parts += pk.frame("GlassFrame", 5.2, 3.2, 0.1, 0.08, (0, -0.24, 4.2), wood)
    # The notices: four across, three down inside the cork, each turned a little and pinned at its top, printed
    # with a heading and lines of text.
    rng = random.Random(12)
    colours = [(236, 232, 220), (250, 220, 90), (230, 120, 110), (140, 190, 230), (236, 236, 236), (170, 220, 150)]
    ink = pk.plastic("NBoard_Ink", (40, 40, 46))
    pins = [pk.plastic("NBoard_PinRed", (210, 40, 40)), pk.plastic("NBoard_PinBlue", (40, 90, 210))]
    for k in range(12):
        col, row = k % 4, k // 4
        w, h = rng.uniform(0.85, 1.1), rng.uniform(0.75, 0.88)
        x = -1.85 + col * 1.23 + rng.uniform(-0.06, 0.06)
        z = 5.15 - row * 0.95 + rng.uniform(-0.05, 0.05)
        turn = rng.uniform(-4, 4)
        y = -0.196 - 0.004 * (k % 3)  # (in front of the cork's face, -0.185)
        parts.append(mk.box(f"Poster{k}", (w, 0.02, h), (x, y, z), rot=(0, turn, 0),
                            mat=pk.plastic(f"NBoard_Poster{k % len(colours)}", colours[k % len(colours)])))
        lines = [(0.0, h * 0.3, w * 0.7, 0.07)] + [(0.0, h * 0.1 - n * 0.13, w * rng.uniform(0.5, 0.75), 0.03)
                                                   for n in range(3)]
        for dx, dz, lw, lh in lines:
            a_ = math.radians(turn)
            parts.append(mk.box("Print", (lw, 0.01, lh), (x + dx * math.cos(a_) + dz * math.sin(a_), y - 0.013,
                                                          z - dx * math.sin(a_) + dz * math.cos(a_)),
                                rot=(0, turn, 0), mat=ink))
        parts.append(mk.cylinder("Pin", 0.045, 0.06, (x, y - 0.035, z + h / 2 - 0.08), rot=(90, 0, 0),
                                 mat=pins[k % 2], verts=8))
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
    parts.append(cap("TopSnow", (6.1, 0.6, 0.25), (0, 0.92, 8.84), sn))
    return parts, []


# The exam -------------------------------------------------------------------------------------------


@prop("EventTent", pivot="bottom", material="Fabric", collide=False, solids=True, texture=1024, set="Campus")
def event_tent():
    """A white check-in tent pitched in the snow: an aluminium frame on telescoping legs, each foot weighed down with
    a sandbag; a peaked canopy sagging a little between its rafters, seamed along them, a cap at its peak; a navy
    valance in scallops with a white band; canvas walls at the back and sides, the front's flaps rolled up and tied;
    guy ropes from the corners to stakes in the snow; the check-in table under it in a pleated white cloth, a
    clipboard, a laptop, a stack of pamphlets and a cup on it; snow on the canopy and drifted round the feet."""
    canvas = mk.noisy("Tent_Canvas", srgb(222, 224, 226), srgb(240, 242, 244), scale=14, roughness=0.8)
    navy = pk.plastic("Tent_Navy", (36, 50, 96))
    white = pk.plastic("Tent_White", (236, 238, 240))
    alu = pk.metal("Tent_Alu", (150, 154, 160), (190, 194, 200), rough=0.35, metallic=0.8)
    cloth = mk.noisy("Tent_Cloth", srgb(232, 232, 228), srgb(248, 248, 244), scale=20, roughness=0.9)
    sand = mk.noisy("Tent_Sandbag", srgb(30, 30, 32), srgb(52, 52, 56), scale=18, roughness=0.9)
    rope = pk.plastic("Tent_Rope", (200, 196, 180))
    dark = pk.plastic("Tent_Dark", (30, 32, 36))
    paper = pk.plastic("Tent_Paper", (240, 236, 224))
    sn = snow("Tent")
    hw, eave, peak = 5.0, 8.0, 10.6
    parts = []
    corners = [(-hw, -hw), (hw, -hw), (hw, hw), (-hw, hw)]
    for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        x, y = sx * hw, sy * hw
        # a telescoping leg: the thick lower tube, the thinner upper one, the clamp between, a corner fitting
        parts += [mk.box("Leg", (0.24, 0.24, 4.4), (x, y, 2.2), mat=alu, bevel=0.03),
                  mk.box("LegUpper", (0.18, 0.18, eave - 4.2), (x, y, 4.2 + (eave - 4.2) / 2), mat=alu, bevel=0.02),
                  mk.box("Clamp", (0.32, 0.32, 0.22), (x, y, 4.3), mat=dark, bevel=0.04),
                  mk.box("Corner", (0.4, 0.4, 0.3), (x, y, eave), mat=dark, bevel=0.05),
                  mk.box("Foot", (0.6, 0.6, 0.06), (x, y, 0.03), mat=alu)]
        # a sandbag over the foot, slumped; snow drifted against it
        bag = pk.rounded("Sandbag", (1.0, 0.6, 0.38), (x - sx * 0.05, y + sy * 0.42, 0.22), sand, r=0.16)
        mk.displace_noise(bag, strength=0.04, scale=0.5, name="TentBag")
        parts.append(bag)
        parts.append(mk.sphere("Drift", 0.6, (x + sx * 0.3, y + sy * 0.3, 0.02), scale=(1.4, 1.1, 0.35), mat=sn,
                               segments=12, rings=6))
        # the guy rope from the corner fitting out to its stake
        sx2, sy2 = x + sx * 3.2, y + sy * 3.2
        parts.append(pk.sweep("GuyRope", [(x, y, eave - 0.1), ((x + sx2) / 2, (y + sy2) / 2, eave * 0.45),
                                           (sx2, sy2, 0.25)], 0.025, rope, sides=4))
        parts.append(mk.cylinder("Stake", 0.06, 0.5, (sx2, sy2, 0.15), mat=alu, verts=6))
    # the frame round the eaves, between the corners
    for k in range(4):
        (ax, ay), (bx, by) = corners[k], corners[(k + 1) % 4]
        parts.append(mk.tube("Eave", (ax, ay, eave - 0.05), (bx, by, eave - 0.05), 0.07, mat=alu, verts=6))
        parts.append(mk.tube("Rafter", (ax, ay, eave), (0, 0, peak), 0.06, mat=alu, verts=5))
    # The canopy, a flattened pyramid sagging a little between the rafters, seamed along them, capped at the peak.
    roof = mk.lathe("Canopy", [(hw * 1.414 + 0.1, 0.06), (hw * 1.05, 0.62), (hw * 0.55, 1.5), (0.0, peak - eave + 0.06)],
                    (0, 0, eave), mat=canvas, segments=4)
    roof.rotation_euler = (0, 0, math.radians(45))
    parts.append(roof)
    for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        parts.append(mk.tube("Seam", (sx * (hw + 0.02), sy * (hw + 0.02), eave + 0.1), (0, 0, peak + 0.08), 0.045,
                             mat=white, verts=4))
    parts.append(mk.cylinder("PeakCap", 0.35, 0.3, (0, 0, peak + 0.1), mat=navy, verts=12, radius2=0.12))
    snow_roof = mk.lathe("CanopySnow", [(hw * 1.2, 0.0), (hw * 0.8, 0.62), (0.0, (peak - eave) * 0.86)],
                         (0, 0, eave + 0.45), mat=sn, segments=4)
    snow_roof.rotation_euler = (0, 0, math.radians(45))
    parts.append(snow_roof)
    # The valance: a navy band in scallops round the eaves, a white stripe along its top.
    for k in range(4):
        (ax, ay), (bx, by) = corners[k], corners[(k + 1) % 4]
        along_x = ay == by
        mx, my = (ax + bx) / 2 * 1.012, (ay + by) / 2 * 1.012
        length = 2 * hw + 0.2
        parts.append(mk.box("Valance", (length, 0.06, 0.42) if along_x else (0.06, length, 0.42), (mx, my, eave - 0.21),
                            mat=navy))
        parts.append(mk.box("Stripe", (length - 0.02, 0.07, 0.08) if along_x else (0.07, length - 0.02, 0.08),
                            (mx, my, eave - 0.045),
                            mat=white))
        for t in range(8):  # the scallops hanging from it
            u = -hw + (t + 0.5) * (2 * hw / 8)
            at = (u, my, eave - 0.48) if along_x else (mx, u, eave - 0.48)
            parts.append(mk.cylinder("Scallop", 0.62, 0.05, at, rot=(90, 0, 0) if along_x else (0, 90, 0), mat=navy,
                                     verts=16))
    # The walls: canvas at the back and the sides (to above the table), the front's flaps rolled up and tied.
    parts += [mk.box("Back", (2 * hw, 0.05, eave - 0.6), (0, hw, (eave - 0.6) / 2 + 0.3), mat=canvas),
              mk.box("SideL", (0.05, 2 * hw, eave - 3.0), (-hw, 0, (eave - 3.0) / 2 + 2.7), mat=canvas),
              mk.box("SideR", (0.05, 2 * hw, eave - 3.0), (hw, 0, (eave - 3.0) / 2 + 2.7), mat=canvas)]
    for sx in (-1, 1):
        parts.append(mk.cylinder("Roll", 0.28, hw - 0.4, (sx * hw / 2, -hw + 0.05, eave - 0.85), rot=(0, 90, 0),
                                 mat=canvas, verts=12))
        for dx in (-1.2, 1.2):
            parts.append(mk.torus("Tie", 0.31, 0.03, (sx * hw / 2 + dx, -hw + 0.05, eave - 0.85), rot=(0, 90, 0),
                                  mat=navy, major_segments=12, minor_segments=4))
    # The check-in table in its pleated cloth, the things on it.
    top = 2.66
    parts += [mk.box("Table", (6.0, 2.4, 0.12), (0, 1.4, top - 0.06), mat=cloth),
              mk.box("ClothSideL", (0.05, 2.4, 2.6), (-3.0, 1.4, 1.3), mat=cloth),
              mk.box("ClothSideR", (0.05, 2.4, 2.6), (3.0, 1.4, 1.3), mat=cloth)]
    front = mk.box("ClothFront", (6.0, 0.05, 2.6), (0, 0.2, 1.3), mat=cloth)
    for v in front.data.vertices:  # (pleats down the cloth's front, fading towards its top)
        if v.co.y < 0:
            v.co.y -= 0.06 * math.sin(v.co.x * math.tau / 0.75) * (1 - (v.co.z + 1.3) / 2.6)
    parts.append(front)
    parts += [mk.box("Clipboard", (0.7, 0.95, 0.04), (-1.6, 1.0, top + 0.02), rot=(0, 0, 8), mat=dark),
              mk.box("ClipSheet", (0.62, 0.8, 0.02), (-1.6, 0.98, top + 0.05), rot=(0, 0, 8), mat=paper),
              mk.box("LaptopBase", (1.3, 0.9, 0.06), (0.7, 1.5, top + 0.03), rot=(0, 0, -6), mat=dark),
              mk.box("LaptopLid", (1.3, 0.05, 0.85), (0.74, 1.95, top + 0.44), rot=(-14, 0, -6), mat=dark),
              mk.box("Pamphlets", (0.8, 0.6, 0.2), (2.3, 1.1, top + 0.1), rot=(0, 0, 14), mat=white),
              mk.cylinder("Cup", 0.14, 0.32, (-0.4, 1.7, top + 0.16), mat=white, verts=12, radius2=0.12)]
    glows = [mk.box("Screen", (1.18, 0.02, 0.72), (0.74, 1.92, top + 0.45), rot=(-14, 0, -6),
                    mat=pk.glow("Tent_Screen", (150, 190, 240), 1.6))]
    return parts, glows


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


@prop("ReadingTable", pivot="bottom", material="Wood", collide=True, texture=1024, set="Campus",
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
    # (a real skull, sockets and teeth carved: a ball with two dark dots for eyes read as a cartoon)
    parts += pk.skull("Skull", (0, 0.02, 5.12), 0.34, bone, dark, segments=24, teeth=6)
    for z in (4.76, 4.88):  # (the neck's vertebrae up into the skull's base)
        parts.append(mk.cylinder("Neck", 0.08, 0.12, (0, 0.1, z), mat=bone, verts=8))
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
                  mk.box("Hand", (0.18, 0.1, 0.4), (sx * 0.7, -0.21, 2.12), mat=bone, bevel=0.03),
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


@prop("Kotatsu", pivot="bottom", material="Fabric", collide=True, texture=1024, set="Campus")
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


@prop("DrumKit", pivot="bottom", material="SmoothPlastic", collide=True, texture=1024, set="Campus")
def drum_kit():
    """The light music club's drum kit: bass drum, snare, two rack toms and a floor tom, the
    hi-hat and a crash cymbal on their stands, the throne."""
    wrap = pk.plastic("Drum_Wrap", (120, 20, 30), rough=0.2)
    head = pk.plastic("Drum_Head", (236, 232, 222))
    chrome = pk.chrome("Drum_Chrome")
    brass = pk.metal("Drum_Cymbal", (180, 146, 70), (220, 184, 100), rough=0.25, metallic=0.95)
    dark = pk.metal("Drum_Dark", (20, 20, 22), (34, 34, 38), rough=0.5, metallic=0.3)
    parts = [mk.cylinder("Bass", 1.0, 1.2, (0, -0.2, 1.0), rot=(90, 0, 0), mat=wrap, verts=24),
             mk.cylinder("BassHead", 0.96, 0.04, (0, -0.82, 1.0), rot=(90, 0, 0), mat=head, verts=24)]
    for x in (-0.6, 0.6):
        parts.append(mk.tube("TomMount", (x * 0.4, -0.2, 1.9), (x, -0.05, 2.2), 0.04, mat=chrome, verts=6))
    for k, (x, y, z, r, d) in enumerate(((-0.6, -0.1, 2.35, 0.55, 0.6), (0.6, -0.1, 2.35, 0.6, 0.65))):
        parts += [mk.cylinder(f"Tom{k}", r, d, (x, y, z), rot=(-20, 0, 0), mat=wrap, verts=20),
                  mk.cylinder(f"TomHead{k}", r - 0.02, 0.04, (x, y - 0.1, z + d / 2 * 0.94), rot=(-20, 0, 0), mat=head,
                              verts=20)]
    parts += [mk.cylinder("Floor", 0.75, 1.0, (1.6, 0.6, 1.3), mat=wrap, verts=20),
              mk.cylinder("FloorHead", 0.73, 0.04, (1.6, 0.6, 1.82), mat=head, verts=20),
              mk.cylinder("Snare", 0.6, 0.45, (-1.1, 0.8, 1.9), mat=chrome, verts=20),
              mk.cylinder("SnareHead", 0.58, 0.04, (-1.1, 0.8, 2.14), mat=head, verts=20),
              mk.cylinder("SnarePost", 0.04, 1.1, (-1.1, 0.8, 1.15), mat=chrome, verts=6)]
    for k in range(3):
        a = 2 * math.pi * (k + 0.5) / 3
        parts += [mk.tube("FloorLeg", (1.6 + math.cos(a) * 0.76, 0.6 + math.sin(a) * 0.76, 1.55),
                          (1.6 + math.cos(a) * 0.95, 0.6 + math.sin(a) * 0.95, 0.02), 0.03, mat=chrome, verts=4),
                  mk.tube("SnareFoot", (-1.1, 0.8, 0.62), (-1.1 + math.cos(a) * 0.55, 0.8 + math.sin(a) * 0.55, 0.02),
                          0.03, mat=chrome, verts=4)]
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


@prop("FilmProjector", pivot="bottom", material="Metal", collide=True, texture=512, set="Campus")
def film_projector():
    """The film club's 16 mm projector on its trolley: a grey body with the lamp house behind, its vents louvred,
    the lens barrel out of the front with its focus ring, the beam lit at its glass; two spoked reels high on their
    arms, film wound on the front one, the strip running down to the gate and back up to the take-up reel; the
    switches on its side, the cable; a can of film and a spare reel on the shelf."""
    grey = pk.paint("Proj_Grey", (80, 86, 90), rough=0.4)
    dark = pk.metal("Proj_Dark", (22, 22, 24), (38, 38, 42), rough=0.5, metallic=0.3)
    alu = pk.metal("Proj_Alu", (160, 164, 170), (196, 200, 206), rough=0.3, metallic=0.8)
    film = pk.plastic("Proj_Film", (40, 30, 24))
    white = pk.plastic("Proj_White", (226, 222, 212))
    parts = [mk.box("Trolley", (2.0, 2.4, 0.1), (0, 0, 2.4), mat=dark),
             mk.box("Shelf", (1.8, 2.2, 0.1), (0, 0, 0.9), mat=dark),
             mk.cylinder("Can", 0.6, 0.2, (-0.2, 0.3, 1.05), mat=alu, verts=24),
             mk.box("CanLabel", (0.5, 0.02, 0.12), (-0.2, -0.31, 1.05), mat=white),
             pk.rounded("Body", (1.1, 1.6, 1.1), (0, -0.1, 3.0), grey, r=0.12),
             pk.rounded("LampHouse", (0.9, 0.8, 1.0), (0, 0.95, 3.05), grey, r=0.1),
             mk.box("Gate", (0.08, 0.5, 0.6), (0.58, -0.3, 3.1), mat=dark, bevel=0.02),
             mk.cylinder("Barrel", 0.2, 0.7, (0.1, -1.15, 3.1), rot=(90, 0, 0), mat=dark, verts=16),
             mk.cylinder("FocusRing", 0.24, 0.14, (0.1, -1.05, 3.1), rot=(90, 0, 0), mat=alu, verts=16),
             mk.cylinder("LensHood", 0.24, 0.12, (0.1, -1.46, 3.1), rot=(90, 0, 0), mat=dark, verts=16)]
    for k in range(5):  # the lamp house's louvres
        parts.append(mk.box("Louvre", (0.92, 0.05, 0.08), (0, 1.36, 2.75 + k * 0.15), rot=(30, 0, 0), mat=dark))
    for k, x in enumerate((-0.25, 0.0)):  # switches on the side
        parts.append(mk.box("Switch", (0.12, 0.06, 0.16), (x, -0.92, 2.7), mat=dark, bevel=0.02))
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(mk.box("Leg", (0.1, 0.1, 2.4), (sx * 0.9, sy * 1.1, 1.2), mat=dark))
            parts.append(mk.cylinder("Caster", 0.1, 0.08, (sx * 0.9, sy * 1.1, 0.1), rot=(0, 90, 0), mat=dark, verts=10))
    # The reels: a rim, a hub and five spokes each (the gaps between them open), on arms up from the body.
    reels = [(-0.55, 4.45, 0.5), (0.75, 4.35, 0.18)]  # (y, z, the film wound on it, its radius)
    for sy, zz, wound in reels:
        parts.append(mk.tube("ReelArm", (0.1, sy * 0.5, 3.5), (0.1, sy, zz), 0.05, mat=dark, verts=6))
        for side in (-1, 1):
            parts.append(mk.torus("Rim", 0.66, 0.03, (0.1 + side * 0.06, sy, zz), rot=(0, 90, 0), mat=alu,
                                  major_segments=28, minor_segments=4))
            for k in range(5):
                a = k * math.tau / 5
                end = (0.1 + side * 0.06, sy + math.cos(a) * 0.64, zz + math.sin(a) * 0.64)
                parts.append(mk.tube("Spoke", (0.1 + side * 0.06, sy, zz), end, 0.04, mat=alu, verts=4))
        parts += [mk.cylinder("Hub", 0.14, 0.2, (0.1, sy, zz), rot=(0, 90, 0), mat=alu, verts=12),
                  mk.cylinder("Wound", wound, 0.1, (0.1, sy, zz), rot=(0, 90, 0), mat=film, verts=24)]
    # the film's path: off the front reel down to the gate, and from the gate back up to the take-up reel
    f_reel, t_reel = reels[0], reels[1]
    parts += [mk.tube("Strip", (0.1, f_reel[0] + 0.3, f_reel[1] - 0.42), (0.58, -0.4, 3.4), 0.02, mat=film, verts=4),
              mk.tube("Strip", (0.58, -0.2, 2.8), (0.62, 0.3, 2.62), 0.02, mat=film, verts=4),
              mk.tube("Strip", (0.62, 0.3, 2.62), (0.1, t_reel[0] - 0.1, t_reel[1] - 0.17), 0.02, mat=film, verts=4)]
    parts.append(pk.sweep("Cable", [(-0.5, 1.2, 2.8), (-0.85, 1.25, 2.2), (-0.95, 1.0, 1.2), (-0.9, 0.6, 0.3),
                                    (-1.2, 0.2, 0.02)], 0.04, dark, sides=5))
    parts.append(mk.cylinder("SpareReel", 0.45, 0.1, (0.45, -0.55, 1.0), mat=alu, verts=20))
    glows = [mk.cylinder("Beam", 0.17, 0.04, (0.1, -1.53, 3.1), rot=(90, 0, 0), mat=pk.glow("Proj_Lamp", (255, 244, 220), 5),
                         verts=16)]
    return parts, glows


@prop("Typewriter", pivot="bottom", material="Metal", collide=True, texture=256, set="Campus")
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
              mk.box("Shelf", (1.5, 0.5, 0.08), (0, -0.62, 6.82), rot=(-10, 0, 0), mat=wood),
              cap("SeatSnow", (1.3, 1.1, 0.2), (0, 0.3, 6.46), sn),
              cap("PlatformSnow", (1.8, 0.7, 0.14), (0, -0.55, 5.69), sn)]
    for sx in (-1, 1):
        parts.append(mk.tube("Arm", (sx * 0.7, 0.9, 6.3), (sx * 0.7, -0.62, 6.78), 0.05, mat=green, verts=6))
    return parts, []


@prop("TennisNet", pivot="bottom", material="Fabric", collide=True, texture=512, set="Campus")
def tennis_net():
    """A tennis net left up for the winter between its two green posts (40 studs apart): a real mesh of cord you can
    see through, sagging to the middle under its white tape and a line of snow, the cable along its foot, the centre
    strap holding it down, the winder's handle on one post."""
    green = pk.paint("Net_Green", (40, 80, 60), rough=0.4)
    cord = mk.noisy("Net_Cord", srgb(20, 22, 22), srgb(44, 48, 46), scale=40, roughness=0.9)
    tape = pk.plastic("Net_Tape", (236, 236, 230))
    steel = pk.metal("Net_Steel", (120, 122, 128), (170, 172, 178), rough=0.3, metallic=0.9)
    sn = snow("Net")
    half = 20.0

    def top(x):
        return 3.4 - 0.5 * math.sin(math.pi * (x + half) / (2 * half))

    parts = []
    for sx in (-1, 1):
        parts += [mk.cylinder("Post", 0.18, 3.8, (sx * half, 0, 1.9), mat=green, verts=10),
                  mk.cylinder("PostCap", 0.22, 0.1, (sx * half, 0, 3.85), mat=green, verts=10),
                  mk.cylinder("PostFoot", 0.21, 0.12, (sx * half, 0, 0.06), mat=green, verts=10),
                  cap("PostSnow", (0.4, 0.4, 0.16), (sx * half, 0, 3.98), sn)]
    # (the winder on the right post's side, off the court's line so the net is no longer than its posts: its
    # drum, the crank hanging from it and the crank's grip)
    parts += [mk.cylinder("Winder", 0.12, 0.3, (half, -0.3, 2.6), rot=(90, 0, 0), mat=steel, verts=10),
              mk.tube("Crank", (half, -0.45, 2.6), (half, -0.45, 2.25), 0.03, mat=steel, verts=6),
              mk.cylinder("Grip", 0.05, 0.22, (half, -0.56, 2.25), rot=(90, 0, 0), mat=green, verts=8)]
    # The mesh: cords up and down every half stud, and cords across that follow the sag.
    segs = 16
    x = -half + 0.5
    while x < half - 0.25:
        parts.append(mk.box("CordUp", (0.035, 0.035, top(x) - 0.3), (x, 0, (top(x) + 0.3) / 2), mat=cord))
        x += 0.5
    for row in range(1, 7):
        f = row / 7
        for k in range(segs):
            x0, x1 = -half + 2 * half * k / segs, -half + 2 * half * (k + 1) / segs
            z0, z1 = 0.3 + f * (top(x0) - 0.45), 0.3 + f * (top(x1) - 0.45)
            mid_x, mid_z = (x0 + x1) / 2, (z0 + z1) / 2
            length = math.hypot(x1 - x0, z1 - z0)
            angle = math.degrees(math.atan2(z1 - z0, x1 - x0))
            parts.append(mk.box("CordAcross", (length + 0.04, 0.035, 0.035), (mid_x, 0, mid_z), rot=(0, -angle, 0),
                                mat=cord))
    for k in range(segs):
        x0, x1 = -half + 2 * half * k / segs, -half + 2 * half * (k + 1) / segs
        z0, z1 = top(x0), top(x1)
        mid_x, mid_z = (x0 + x1) / 2, (z0 + z1) / 2
        length = math.hypot(x1 - x0, z1 - z0)
        angle = math.degrees(math.atan2(z1 - z0, x1 - x0))
        parts += [mk.box("Tape", (length + 0.03, 0.09, 0.3), (mid_x, 0, mid_z - 0.08), rot=(0, -angle, 0), mat=tape),
                  mk.box("Foot", (length + 0.03, 0.06, 0.06), (mid_x, 0, 0.3), mat=cord),
                  cap(f"TapeSnow{k}", (length, 0.22, 0.13), (mid_x, 0, mid_z + 0.12), sn, r=0.05)]
    # The centre strap down to its anchor in the ground.
    parts += [mk.box("Strap", (0.16, 0.1, top(0.0) - 0.1), (0, 0, (top(0.0) + 0.1) / 2), mat=tape),
              mk.box("Anchor", (0.4, 0.3, 0.1), (0, 0, 0.05), mat=steel)]
    return parts, []


@prop("BustStatue", pivot="bottom", material="Slate", collide=True, texture=1024, set="Campus")
def bust_statue():
    """The founder's bronze bust on a granite plinth, the plaque on its face, snow on his head and
    shoulders and on the plinth's top. The bust sculpted as one surface: an old man's head (the domed crown,
    the heavy brow over sunken eyes, the long nose, the moustache over a firm mouth, the jaw and the ears),
    the neck in a high collar, the shoulders and chest in a buttoned coat cut off square, on a round socle."""
    from props_lobby import _blob

    granite = mk.noisy("Bust_Granite", srgb(70, 70, 72), srgb(104, 104, 108), scale=16, roughness=0.7)
    bronze = mk.noisy("Bust_Bronze", srgb(46, 60, 50), srgb(90, 80, 56), scale=10, roughness=0.45, metallic=0.7)
    brass = pk.metal("Bust_Plaque", (150, 120, 60), (196, 160, 90), rough=0.3, metallic=0.9)
    ink = pk.plastic("Bust_Ink", (30, 26, 20))
    sn = snow("Bust")
    parts = [mk.box("Step", (3.0, 3.0, 0.5), (0, 0, 0.25), mat=granite, bevel=0.04),
             mk.box("Plinth", (2.2, 2.2, 4.0), (0, 0, 2.5), mat=granite, bevel=0.04),
             mk.box("PlinthCap", (2.5, 2.5, 0.3), (0, 0, 4.65), mat=granite, bevel=0.04),
             mk.lathe("Socle", [(0.0, 0.0), (0.62, 0.0), (0.62, 0.08), (0.5, 0.16), (0.46, 0.3), (0.0, 0.3)],
                      (0, 0.05, 4.8), mat=bronze, segments=24)]
    hz = 6.35  # the head's middle
    bust = _blob("Bust", [
        # the chest and shoulders, a herm's block narrowing to the cut, the collar up round the neck
        ("ellipsoid", (0, 0.08, 5.32), 0.6, (1.3, 0.7, 0.62)),
        ("ellipsoid", (-0.5, 0.1, 5.5), 0.3, (1.15, 0.9, 0.7)),
        ("ellipsoid", (0.5, 0.1, 5.5), 0.3, (1.15, 0.9, 0.7)),
        ("capsule", (0, 0.1, 5.55), (0, 0.06, 5.98), 0.22),
        ("ellipsoid", (0, 0.1, 5.76), 0.25, (1.1, 1.0, 0.5)),
        # the head: the crown, the face, the jaw
        ("ellipsoid", (0, 0.1, hz + 0.1), 0.42, (0.84, 0.98, 0.95)),
        ("ellipsoid", (0, -0.1, hz - 0.1), 0.34, (0.78, 0.8, 1.0)),
        ("ellipsoid", (0, -0.08, hz - 0.34), 0.24, (0.95, 0.85, 0.6)),
        # a little brow, nose, moustache and chin; the ears
        ("ellipsoid", (0, -0.36, hz + 0.06), 0.13, (1.6, 0.5, 0.4)),
        ("capsule", (0, -0.4, hz + 0.0), (0, -0.47, hz - 0.13), 0.045),
        ("ellipsoid", (0, -0.43, hz - 0.2), 0.08, (1.5, 0.5, 0.42)),
        ("ellipsoid", (0, -0.31, hz - 0.44), 0.09, (1.0, 0.8, 0.7)),
        ("ellipsoid", (-0.37, 0.08, hz - 0.02), 0.08, (0.45, 0.85, 1.3)),
        ("ellipsoid", (0.37, 0.08, hz - 0.02), 0.08, (0.45, 0.85, 1.3)),
        ("hollow", (-0.14, -0.39, hz - 0.02), 0.045, (1.3, 0.8, 0.8)),
        ("hollow", (0.14, -0.39, hz - 0.02), 0.045, (1.3, 0.8, 0.8)),
    ], 0.045, 0.45, bronze)
    parts.append(bust)
    # the coat's lapels and its buttons on the chest
    for sx in (-1, 1):
        lapel = mk.box("Lapel", (0.24, 0.05, 0.42), (sx * 0.17, -0.42, 5.42), rot=(14, 0, sx * -18), mat=bronze, bevel=0.02)
        parts.append(lapel)
    for k in range(2):
        parts.append(mk.sphere("Button", 0.04, (0, -0.44, 5.26 - k * 0.18), mat=bronze, segments=8, rings=6))
    parts += [mk.box("Plaque", (1.4, 0.06, 0.8), (0, -1.12, 3.4), mat=brass, bevel=0.02),
              # (the snow on the head and shoulders in soft drifts lying into the bronze)
              mk.sphere("HeadSnow", 0.3, (0, 0.08, hz + 0.43), scale=(1.0, 1.15, 0.32), mat=sn, segments=14, rings=8),
              mk.sphere("ShoulderSnowL", 0.28, (-0.56, 0.12, 5.68), scale=(1.2, 1.0, 0.3), mat=sn, segments=12, rings=6),
              mk.sphere("ShoulderSnowR", 0.28, (0.56, 0.12, 5.68), scale=(1.2, 1.0, 0.3), mat=sn, segments=12, rings=6),
              cap("PlinthSnow", (2.3, 2.3, 0.18), (0, 0, 4.88), sn)]
    parts += pk.label("PlaqueText", "創立者", 0.26, (0, -1.16, 3.5), ink)
    return parts, []
