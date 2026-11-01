"""Station looks: what a case-file station is where it stands (a CCTV desk in a control room, a
payphone booth, a hotel's front desk, a police print kit, a lab bench), in place of the standard
console (props_gameplay.Station).

Each is built round the game's own parts, from stationkit's detailed pieces. The game's invisible
desk (5 x 3 x 2.4) stands on the design origin, the worker in front at -Y. The game's screen goes
where the prop says (its `screen` slot: the middle of the screen's face, its size and tilt), set
into a monitor, a terminal or a viewer the prop builds round it, never behind anything. anchor=(0, 0)
places the design origin on the station's spot. Each keeps the box the maps were laid out round
(the size and anchor in ModelCatalog before the 2026-11 rebuild), so every placement still fits."""

import math
import random

import modelkit as mk
import propkit as pk
import stationkit as sk
from common import srgb
from props import prop

LAMP_WARM = (255, 214, 160)


def _feed(prefix, x, y, z, w, h, rgb, rng, dark):
    """A small camera feed's picture on a monitor face at y: the lit screen and a few dark shapes
    in it (a kerb, a doorway, a figure) so it reads as a scene."""
    glow = mk.box(prefix + "Lit", (w, 0.02, h), (x, y + 0.01, z), mat=pk.glow(prefix + "Feed", rgb, 1.6))
    shapes = [mk.box(prefix + "Kerb", (w, 0.006, h * 0.06), (x, y - 0.002, z - h * 0.18), rot=(0, rng.uniform(-14, 14), 0),
                     mat=dark),
              mk.box(prefix + "Door", (w * 0.18, 0.006, h * 0.42), (x + rng.uniform(-0.3, 0.3) * w, y - 0.002, z + h * 0.08),
                     mat=dark),
              mk.box(prefix + "Stamp", (w * 0.36, 0.006, h * 0.06), (x - w * 0.28, y - 0.002, z + h * 0.4), mat=dark)]
    return glow, shapes


CCTV_SCREEN = (0.0, 0.8, 5.4, 4.4, 2.6, 0)


@prop("StationCCTV", pivot="bottom", material="Metal", collide=False, texture=1024, set="Tokyo", anchor=(0, 0),
      screen=CCTV_SCREEN)
def station_cctv():
    """A security office's desk (the kept box: 5.2 across, 3.1 deep, 8.6 high): a grey steel desk
    with its drawer pedestal, and on the steel frame behind it the main monitor (the game's screen,
    where the console's always stood) under three small ones showing camera feeds. On the desk the
    keyboard and mouse, the camera joystick with its buttons, the recorder with its lamps, a radio
    in its charger, the open log with a pen, and a mug."""
    rng = random.Random(41)
    steel = pk.paint("Cctv_Steel", (92, 96, 100), rough=0.45)
    top = pk.plastic("Cctv_Resin", (58, 60, 64), rough=0.5)
    trim = pk.metal("Cctv_Trim", (30, 30, 34), (48, 48, 52), rough=0.4, metallic=0.5)
    shell = pk.plastic("Cctv_Plastic", (26, 27, 30), rough=0.35)
    key = pk.plastic("Cctv_Button", (44, 46, 50), rough=0.5)
    rubber = pk.rubber("Cctv_Rubber")
    paper = mk.noisy("Cctv_Paper", srgb(214, 208, 190), srgb(236, 230, 214), roughness=0.9)
    cover = pk.plastic("Cctv_Cover", (40, 52, 80))
    ink = mk.flat("Cctv_Ink", srgb(30, 30, 50), 0.6)
    mugm = pk.plastic("Cctv_Mug", (196, 192, 182))
    coffee = mk.flat("Cctv_Coffee", srgb(40, 24, 14), 0.1)
    x, y, z, w, h, tilt = CCTV_SCREEN
    parts = sk.steel_desk("Cctv_", top, steel, trim, w=5.2, d=2.6, h=2.95, pedestal=1.5)
    # The frame behind the desk: two posts, a back panel and cross rails, up to 8.55.
    parts += [pk.rounded("Post", (0.18, 0.18, 5.6), (sx * 2.45, 1.38, 5.75), steel, r=0.03) for sx in (-1, 1)]
    parts += [mk.box("BackPanel", (4.74, 0.05, 5.5), (0, 1.43, 5.75), mat=steel),
              mk.box("RailTop", (5.06, 0.2, 0.14), (0, 1.38, 8.48), mat=steel, bevel=0.02),
              mk.box("RailMid", (5.06, 0.2, 0.12), (0, 1.38, 6.92), mat=steel, bevel=0.02)]
    parts += sk.screws("Screw", [(sx * 2.45, 1.28, zz) for sx in (-1, 1) for zz in (3.3, 6.92, 8.48)], trim, r=0.03)
    main, glows = sk.lcd("Main_", CCTV_SCREEN, shell, trim, border=0.09, back=0.2)
    parts += main
    parts += [mk.box("MainArm", (0.5, 0.34, 0.5), (x, 1.24, z), mat=trim, bevel=0.03)]
    # Three small monitors on the top rail, each showing a feed.
    feeds = [(110, 150, 136), (120, 138, 168), (150, 150, 120)]
    for k in range(3):
        fx = -1.55 + k * 1.55
        slot = (fx, 1.0, 7.62, 1.28, 0.78, 0)
        mon, led = sk.lcd(f"Feed{k}_", slot, shell, trim, border=0.07, back=0.16)
        parts += mon
        glows += led
        lit, shapes = _feed(f"Feed{k}", fx, 0.9, 7.62, 1.28, 0.78, feeds[k], rng, trim)
        glows.append(lit)
        parts += shapes
        parts.append(mk.box(f"Feed{k}Arm", (0.3, 0.3, 0.3), (fx, 1.25, 7.62), mat=trim))
    # The recorder under the main monitor, its lamps and display.
    parts += [pk.rounded("Recorder", (2.0, 0.9, 0.36), (-0.2, 0.75, 3.13), shell, r=0.03),
              mk.box("RecDisplay", (0.5, 0.02, 0.14), (-0.75, 0.295, 3.16), mat=trim),
              mk.box("RecTray", (0.8, 0.02, 0.05), (0.3, 0.295, 3.2), mat=trim)]
    for k in range(4):
        glows.append(mk.box("RecLed", (0.04, 0.02, 0.04), (0.8 + k * 0.1, 0.29, 3.06),
                            mat=pk.glow("Cctv_RecLed", (110, 255, 140) if k else (255, 70, 50), 4)))
    glows.append(mk.box("RecTime", (0.44, 0.01, 0.1), (-0.75, 0.283, 3.16), mat=pk.glow("Cctv_Clock", (120, 220, 255), 2.5)))
    parts.append(sk.cable("RecCable", [(0.6, 1.2, 3.1), (0.9, 1.33, 2.9), (1.0, 1.35, 0.4)], rubber, r=0.03))
    # The keyboard, mouse and the camera joystick.
    parts += sk.keyboard("Kb_", -0.35, -0.72, 2.95, shell, key, w=1.9, d=0.66)
    parts += sk.mouse("Ms_", 0.85, -0.7, 2.95, shell, trim, cable_to=(0.7, 0.2, 2.97))
    jx, jy = 1.75, -0.65
    parts += [sk.wedge("JoyBody", [(-0.32, 0.0), (0.32, 0.0), (0.32, 0.2), (-0.32, 0.12)], 0.9, jx, shell, bevel=0.03)]
    parts[-1].location = (jx, jy, 2.95)
    parts += [mk.lathe("JoyBoot", [(0.12, 0.0), (0.1, 0.04), (0.06, 0.1), (0.035, 0.16), (0.0, 0.16)], (jx + 0.15, jy + 0.08, 3.12),
                       mat=rubber, segments=12),
              mk.tube("JoyStick", (jx + 0.15, jy + 0.08, 3.25), (jx + 0.17, jy + 0.06, 3.62), 0.03, mat=trim, verts=8),
              mk.sphere("JoyGrip", 1.0, (jx + 0.17, jy + 0.06, 3.68), scale=(0.07, 0.07, 0.1), mat=rubber, segments=10, rings=6)]
    for k in range(6):
        parts.append(mk.cylinder("JoyKey", 0.035, 0.03, (jx - 0.32 + (k % 3) * 0.11, jy - 0.15 + (k // 3) * 0.15, 3.09 + (k // 3) * 0.02),
                                 mat=key, verts=8))
    # The radio in its charger, the open log and a pen, the mug.
    parts += [pk.rounded("Charger", (0.5, 0.45, 0.16), (-2.1, 0.65, 3.03), shell, r=0.03),
              pk.rounded("Radio", (0.3, 0.2, 0.62), (-2.1, 0.66, 3.4), shell, r=0.04),
              mk.tube("Aerial", (-2.03, 0.66, 3.7), (-2.03, 0.66, 4.05), 0.02, 0.012, mat=rubber, verts=6),
              mk.cylinder("RadioKnob", 0.04, 0.06, (-2.16, 0.66, 3.74), mat=trim, verts=8)]
    glows.append(mk.box("ChargeLed", (0.05, 0.02, 0.03), (-1.95, 0.42, 3.06), mat=pk.glow("Cctv_Charge", (255, 150, 50), 4)))
    parts += sk.open_book("Log_", -1.95, -0.55, 2.95, cover, paper, ink, rng, yaw=6, w=1.0, d=0.7)
    parts += sk.pen("Pen_", (-1.7, -0.85, 3.05), (-1.4, -0.6, 3.05), ink, trim)
    parts += sk.mug("Mug_", 2.25, 0.35, 2.95, mugm, coffee, handle_yaw=-30)
    parts += sk.papers("Memo_", 1.6, 0.55, 2.95, paper, rng, n=3, w=0.7, d=0.9)
    parts += pk.label("RecLabel", "監視録画", 0.07, (0.95, 0.29, 3.22), paper)
    return parts, glows


PHONE_SCREEN = (0.0, 1.15, 5.5, 2.4, 1.4, 0)


@prop("StationPhoneBooth", pivot="bottom", material="SmoothPlastic", collide=False, texture=1024, set="Tokyo",
      anchor=(0, 0), screen=PHONE_SCREEN)
def station_phone_booth():
    """A street telephone booth, its folding door pushed open (-Y): aluminium posts and rails round
    tall glass panes, the roof with its lit 電話 band and a ceiling light, the grey-green public
    phone on its shelf (keypad, coin and card slots, the handset on its hook and its coiled cord),
    the directory in its binder on a chain, the information display (the game's screen) over it,
    and the notices on the glass."""
    alu = pk.metal("Booth_Alu", (176, 180, 184), (210, 214, 218), rough=0.3, metallic=0.8)
    glass = pk.dark_glass("Booth_Glass", (70, 90, 94))
    roof = pk.paint("Booth_Roof", (236, 238, 234), rough=0.4)
    green = pk.paint("Booth_Green", (120, 150, 128), rough=0.35)
    grey = pk.plastic("Booth_Plastic", (196, 200, 196))
    dark = pk.metal("Booth_Dark", (24, 26, 28), (40, 42, 44), rough=0.5, metallic=0.2)
    key = pk.plastic("Booth_Button", (230, 232, 228))
    floor = mk.noisy("Booth_Rubber", srgb(48, 48, 50), srgb(70, 70, 72), roughness=0.9)
    book = pk.plastic("Booth_Book", (226, 200, 80))
    paper = mk.noisy("Booth_Paper", srgb(220, 216, 200), srgb(240, 236, 222), roughness=0.9)
    ink = pk.plastic("Booth_Ink", (30, 90, 50))
    x, y, z, w, h, tilt = PHONE_SCREEN
    parts = [mk.box("Plinth", (5.2, 3.3, 0.16), (0, 0, 0.08), mat=alu, bevel=0.03),
             mk.box("Mat", (4.8, 2.9, 0.02), (0, 0, 0.17), mat=floor)]
    # Posts, rails, roof.
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(pk.rounded("Post", (0.2, 0.2, 8.3), (sx * 2.5, sy * 1.55, 4.3), alu, r=0.05))
    parts += [mk.box("Header", (5.2, 3.3, 0.6), (0, 0, 8.75), mat=roof, bevel=0.04),
              mk.box("Roof", (5.4, 3.4, 0.22), (0, 0, 9.16), mat=roof, bevel=0.06),
              mk.box("RoofCap", (4.6, 2.6, 0.08), (0, 0, 9.3), mat=alu, bevel=0.02)]
    for sx in (-1, 1):  # (each side: rails top, middle and foot, glass in two panes)
        px = sx * 2.5
        for zz in (0.42, 3.1, 8.38):
            parts.append(mk.box("SideRail", (0.12, 2.9, 0.12), (px, 0, zz), mat=alu, bevel=0.02))
        parts += [mk.box("SideGlassLo", (0.04, 2.9, 2.56), (px, 0, 1.76), mat=glass),
                  mk.box("SideGlassHi", (0.04, 2.9, 5.16), (px, 0, 5.74), mat=glass)]
    for zz in (0.42, 3.1, 8.38):
        parts.append(mk.box("BackRail", (4.8, 0.12, 0.12), (0, 1.55, zz), mat=alu, bevel=0.02))
    parts += [mk.box("BackGlassLo", (4.8, 0.04, 2.56), (0, 1.56, 1.76), mat=glass),
              mk.box("BackGlassHi", (4.8, 0.04, 5.16), (0, 1.56, 5.74), mat=glass),
              mk.box("BackPlate", (3.4, 0.06, 5.0), (0, 1.49, 4.6), mat=alu, bevel=0.02)]
    # The folding door, folded back against the left front post.
    for k, (lx, ly, yaw) in enumerate(((-2.22, -1.3, 70), (-2.05, -1.2, -60))):
        leaf = [mk.box("DoorRail", (0.6, 0.08, 7.8), (lx, ly, 4.25), mat=alu, bevel=0.02),
                mk.box("DoorGlass", (0.44, 0.09, 7.2), (lx, ly, 4.25), mat=glass)]
        parts += sk.turn_about(leaf, (lx, ly, 0), yaw)
    # The lit band on the front and the sides, and the ceiling light.
    glows = [mk.box("BandFront", (3.4, 0.02, 0.4), (0, -1.66, 8.75), mat=pk.glow("Booth_Band", (236, 248, 236), 2.4)),
             mk.box("Ceiling", (2.0, 1.2, 0.03), (0, 0, 8.43), mat=pk.glow("Booth_Ceiling", (240, 246, 255), 2.2))]
    parts += pk.label("BandText", "電話", 0.3, (-0.9, -1.68, 8.75), ink)
    parts += pk.label("BandEn", "TELEPHONE", 0.16, (0.65, -1.68, 8.75), ink)
    for sx in (-1, 1):
        glows.append(mk.box("BandSide", (0.02, 2.2, 0.4), (sx * 2.61, 0, 8.75), mat=pk.glow("Booth_Band", (236, 248, 236), 2.4)))
        parts += pk.label("SideText", "電話", 0.3, (sx * 2.63, 0, 8.75), ink, rot=(90, 0, 90 * sx))
    # The shelf and the phone.
    parts += [mk.box("Shelf", (2.8, 0.9, 0.1), (0, 1.05, 3.05), mat=alu, bevel=0.02),
              mk.box("ShelfLip", (2.8, 0.04, 0.16), (0, 0.6, 3.08), mat=alu, bevel=0.01)]
    for sx in (-1, 1):
        parts.append(mk.box("Bracket", (0.06, 0.8, 0.6), (sx * 1.3, 1.1, 2.7), mat=alu))
    px, py = -0.75, 1.15
    parts += [pk.rounded("Phone", (1.15, 0.6, 1.5), (px, py, 3.85), green, r=0.1),
              pk.rounded("PhoneFace", (0.95, 0.04, 1.25), (px, py - 0.31, 3.88), grey, r=0.03),
              mk.box("Lcd", (0.5, 0.02, 0.2), (px, py - 0.335, 4.3), mat=dark),
              mk.box("CoinSlot", (0.06, 0.02, 0.28), (px + 0.33, py - 0.335, 4.1), mat=dark),
              mk.box("CardSlot", (0.42, 0.02, 0.04), (px, py - 0.335, 3.4), mat=dark),
              mk.box("ReturnCup", (0.36, 0.14, 0.16), (px + 0.2, py - 0.36, 3.2), mat=dark, bevel=0.03)]
    for r in range(4):
        for c in range(3):
            parts.append(mk.box("PhKey", (0.13, 0.04, 0.1), (px - 0.18 + c * 0.16, py - 0.34, 4.05 - r * 0.14), mat=key,
                                bevel=0.012))
    hx = px - 0.68
    parts += [mk.box("Hook", (0.1, 0.24, 0.3), (hx + 0.08, py - 0.05, 4.2), mat=dark, bevel=0.02),
              pk.sweep("Handset", [(hx, py - 0.08, 4.5), (hx - 0.04, py - 0.1, 4.25), (hx - 0.04, py - 0.1, 3.75),
                                   (hx, py - 0.08, 3.5)], 0.07, green, sides=8),
              mk.sphere("Ear", 1.0, (hx + 0.02, py - 0.1, 4.52), scale=(0.1, 0.12, 0.14), mat=green, segments=12, rings=6),
              mk.sphere("Mouth", 1.0, (hx + 0.02, py - 0.1, 3.48), scale=(0.1, 0.12, 0.14), mat=green, segments=12, rings=6),
              pk.coil("Cord", (hx + 0.02, py - 0.05, 3.4), (px - 0.5, py - 0.05, 3.3), 5, 0.04, 0.012, dark, sag=0.4)]
    glows.append(mk.box("LcdLit", (0.46, 0.01, 0.16), (px, py - 0.347, 4.3), mat=pk.glow("Booth_Lcd", (190, 240, 170), 2)))
    parts += pk.label("PhoneSign", "公衆電話", 0.09, (px, py - 0.34, 4.48), ink)
    # The directory binder on its chain, a notice taped to the glass.
    parts += [pk.rounded("Directory", (0.95, 0.7, 0.32), (0.85, 1.1, 3.26), book, r=0.04),
              mk.box("DirPages", (0.9, 0.62, 0.24), (0.88, 1.1, 3.26), mat=paper)]
    parts.append(pk.sweep("Chain", [(0.4, 1.3, 3.3), (0.3, 1.42, 3.6), (0.25, 1.45, 4.0)], 0.015, alu, sides=4))
    parts += [mk.box("Notice", (0.7, 0.01, 0.95), (2.1, 1.535, 5.4), rot=(0, 3, 0), mat=paper),
              mk.box("Notice2", (0.5, 0.01, 0.7), (-2.1, 1.535, 5.9), rot=(0, -4, 0), mat=paper)]
    parts += sk.written("NoteInk", 2.1, 1.53, 5.4, ink, random.Random(5), lines=5, w=0.5, d=0.7, upright=True)
    # The information display (the game's screen) on the back plate.
    disp, led = sk.lcd("Info_", PHONE_SCREEN, dark, dark, border=0.12, back=0.16)
    parts += disp
    glows += led
    return parts, glows


RECEPTION_SCREEN = (0.9, -0.5, 4.5, 2.0, 1.25, 12)


@prop("StationReception", pivot="bottom", material="Wood", collide=False, texture=1024, set="Tokyo", anchor=(0, 0),
      screen=RECEPTION_SCREEN)
def station_reception():
    """A front desk: a walnut counter fluted toward the guest (-Y) on a black plinth with a brass
    kick, a pale stone top, the check-in terminal on it (the game's screen), the bell, the open
    register with its pen, a stand of leaflets and the card holder; behind, the worktop with a
    phone, a lamp and papers, and the key wall: pigeonholes with keys on brass tags under the
    brass フロント letters."""
    rng = random.Random(17)
    wood = mk.wood("Recep_Wood", srgb(110, 72, 44), srgb(58, 36, 22), scale=4)
    stone = mk.noisy("Recep_Stone", srgb(200, 196, 188), srgb(232, 228, 220), roughness=0.25)
    brass = pk.metal("Recep_Brass", (176, 140, 72), (214, 176, 96), rough=0.3, metallic=0.9)
    plinth = pk.paint("Recep_Plinth", (24, 22, 22), rough=0.4)
    dark = pk.plastic("Recep_Plastic", (24, 24, 26))
    key = pk.plastic("Recep_Button", (50, 50, 54))
    paper = mk.noisy("Recep_Paper", srgb(222, 216, 198), srgb(240, 236, 222), roughness=0.9)
    cover = pk.plastic("Recep_Cover", (90, 20, 26))
    ink = mk.flat("Recep_Ink", srgb(26, 24, 30), 0.6)
    shade = pk.plastic("Recep_Shade", (232, 222, 196))
    x, y, z, w, h, tilt = RECEPTION_SCREEN
    # The counter toward the guest.
    parts = [mk.box("Front", (5.2, 0.36, 3.3), (0, -1.1, 1.85), mat=wood, bevel=0.03),
             mk.box("Plinth", (5.1, 0.3, 0.2), (0, -1.06, 0.1), mat=plinth),
             mk.box("Kick", (5.14, 0.02, 0.06), (0, -1.225, 0.23), mat=brass),
             mk.box("Counter", (5.3, 1.5, 0.12), (0, -0.7, 3.62), mat=stone, bevel=0.05),
             mk.box("CounterBand", (5.22, 0.06, 0.1), (0, -1.3, 3.51), mat=brass)]
    for k in range(17):
        parts.append(mk.cylinder("Flute", 0.07, 2.9, (-2.4 + k * 0.3, -1.28, 1.9), mat=wood, verts=8))
    # The worktop and cabinet behind it.
    parts += [mk.box("Body", (5.0, 1.5, 2.66), (0, 0.4, 1.4), mat=wood, bevel=0.02),
              mk.box("Work", (5.1, 1.6, 0.1), (0, 0.4, 2.78), mat=wood, bevel=0.02)]
    # The key wall.
    parts += [mk.box("KeyWall", (5.1, 0.16, 4.5), (0, 1.52, 5.05), mat=wood, bevel=0.02),
              mk.box("Crown", (5.2, 0.1, 0.16), (0, 1.44, 7.2), mat=wood, bevel=0.03),
              mk.box("CrownBrass", (5.0, 0.02, 0.04), (0, 1.39, 7.1), mat=brass)]
    for row in range(3):
        for col in range(6):
            kx, kz = -2.0 + col * 0.8, 4.3 + row * 0.75
            parts += [mk.box("Hole", (0.66, 0.02, 0.6), (kx, 1.43, kz), mat=plinth),
                      mk.box("HoleFrame", (0.74, 0.08, 0.06), (kx, 1.41, kz - 0.33), mat=wood)]
            if (row * 6 + col) % 4 != 2:
                parts += [mk.box("KeyHook", (0.04, 0.12, 0.04), (kx, 1.36, kz + 0.18), mat=brass),
                          mk.box("Key", (0.05, 0.02, 0.22), (kx, 1.3, kz + 0.06), mat=brass),
                          pk.rounded("Tag", (0.18, 0.04, 0.24), (kx, 1.31, kz - 0.14), brass, r=0.03)]
    parts += pk.label("Letters", "フロント  RECEPTION", 0.2, (0, 1.38, 6.85), brass)
    # The terminal on the counter.
    term, glows = sk.lcd("Term_", RECEPTION_SCREEN, dark, key, stand_to=3.68, border=0.08, back=0.16, foot=(1.0, 0.6))
    parts += term
    parts += sk.keyboard("Kb_", x, -1.18, 3.68, dark, key, w=1.6, d=0.5, numpad=False)
    # The bell, the register, leaflets, cards.
    parts += [mk.lathe("Bell", [(0.22, 0.0), (0.22, 0.03), (0.2, 0.1), (0.14, 0.18), (0.05, 0.22), (0.0, 0.22)], (-1.95, -1.0, 3.68),
                       mat=brass, segments=18),
              mk.cylinder("BellBase", 0.25, 0.03, (-1.95, -1.0, 3.695), mat=plinth, verts=18),
              mk.cylinder("BellPin", 0.025, 0.08, (-1.95, -1.0, 3.94), mat=brass, verts=6)]
    parts += sk.open_book("Reg_", -0.8, -0.9, 3.68, cover, paper, ink, rng, yaw=-4, w=1.2, d=0.8)
    parts += sk.pen("RegPen", (-0.15, -1.15, 3.71), (0.05, -0.85, 3.71), ink, brass)
    parts.append(sk.cable("PenChain", [(0.05, -0.85, 3.71), (0.15, -0.6, 3.7)], brass, r=0.008, sides=4))
    parts += [mk.box("LeafStand", (0.6, 0.3, 0.45), (-2.25, -0.55, 3.9), rot=(-10, 0, 0), mat=brass, bevel=0.01)]
    for k, rgb in enumerate(((200, 60, 60), (60, 110, 170), (230, 200, 90))):
        parts.append(mk.box(f"Leaflet{k}", (0.17, 0.04, 0.5), (-2.43 + k * 0.18, -0.62, 3.98), rot=(-10, 0, 0),
                            mat=pk.plastic(f"Recep_Leaf{k}", rgb)))
    parts += [mk.box("CardHolder", (0.4, 0.2, 0.12), (2.15, -1.1, 3.74), rot=(-15, 0, 0), mat=brass, bevel=0.01),
              mk.box("Cards", (0.34, 0.06, 0.22), (2.15, -1.08, 3.82), rot=(-15, 0, 0), mat=paper)]
    # On the worktop: a phone, the lamp, papers.
    ph, lines = sk.desk_phone("Ph_", -1.8, 0.45, 2.83, dark, key, dark, yaw=10, lines=2)
    parts += ph
    glows += lines
    parts += sk.papers("Slips_", -0.4, 0.5, 2.83, paper, rng, n=4)
    parts += [mk.lathe("LampBase", [(0.0, 0.0), (0.2, 0.0), (0.2, 0.05), (0.08, 0.12), (0.06, 0.4), (0.09, 0.55), (0.03, 0.6),
                                    (0.03, 1.15), (0.0, 1.15)], (2.1, 0.85, 2.83), mat=brass, segments=14),
              mk.lathe("LampShade", [(0.22, 1.5), (0.4, 1.05), (0.38, 1.05), (0.2, 1.48)], (2.1, 0.85, 2.83), mat=shade, segments=20,
                       caps=False)]
    glows.append(mk.sphere("Bulb", 0.12, (2.1, 0.85, 4.12), mat=pk.glow("Recep_Bulb", LAMP_WARM, 3), segments=10, rings=6))
    return parts, glows


PRINT_SCREEN = (0.4, 0.75, 4.35, 2.8, 1.8, 10)


@prop("StationPrintKit", pivot="bottom", material="Metal", collide=False, texture=1024, set="Tokyo", anchor=(0, 0),
      screen=PRINT_SCREEN)
def station_print_kit():
    """A police evidence table: a grey resin top on square steel legs with a shelf of evidence boxes
    below, the print comparison monitor at the back (the game's screen). At the front left the open
    fingerprint kit: its foam tray with the powder jars, brushes and lifting tape, the lid standing
    up; print cards ruled for ten fingers, the inking slab and roller, sealed evidence bags, the
    photo scale, and at the right the magnifier lamp on its arm, its ring lit."""
    rng = random.Random(23)
    steel = pk.paint("Print_Steel", (70, 74, 80), rough=0.45)
    top = pk.plastic("Print_Resin", (120, 124, 128), rough=0.5)
    case = pk.plastic("Print_Plastic", (28, 30, 34), rough=0.35)
    foam = mk.noisy("Print_Foam", srgb(36, 36, 40), srgb(56, 56, 62), roughness=0.95, kind="rubber")
    trim = pk.metal("Print_Alu", (150, 154, 160), (190, 194, 200), rough=0.3, metallic=0.8)
    dark = pk.plastic("Print_Bezel", (22, 22, 24))
    card = mk.noisy("Print_Card", srgb(226, 224, 214), srgb(244, 242, 234), roughness=0.8)
    ink = mk.flat("Print_Ink", srgb(18, 18, 22), 0.6)
    bag = pk.plastic("Print_Bag", (214, 222, 226), rough=0.15)
    red = pk.plastic("Print_Seal", (190, 30, 36))
    box = mk.noisy("Print_Card2", srgb(160, 124, 82), srgb(188, 150, 104), roughness=0.8, kind="card")
    x, y, z, w, h, tilt = PRINT_SCREEN
    parts = [mk.box("Top", (5.2, 2.6, 0.1), (0, 0, 2.9), mat=top, bevel=0.02),
             mk.box("Edge", (5.16, 2.56, 0.08), (0, 0, 2.81), mat=trim, bevel=0.01),
             mk.box("Apron", (4.8, 2.2, 0.22), (0, 0, 2.66), mat=steel),
             mk.box("Shelf", (4.9, 2.3, 0.06), (0, 0, 0.6), mat=steel, bevel=0.01)]
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts += [mk.box("Leg", (0.14, 0.14, 2.7), (sx * 2.45, sy * 1.15, 1.42), mat=steel, bevel=0.02),
                      mk.cylinder("Leveller", 0.07, 0.06, (sx * 2.45, sy * 1.15, 0.03), mat=trim, verts=10)]
    for k, (bx, bz, rot) in enumerate(((-1.6, 0.63, 4), (-0.1, 0.63, -3), (1.5, 0.63, 2), (-1.55, 1.36, -6))):
        parts += [mk.box(f"EvBox{k}", (1.3, 1.6, 0.72), (bx, 0.2, bz + 0.36), rot=(0, 0, rot), mat=box, bevel=0.02),
                  mk.box(f"EvTape{k}", (1.32, 0.1, 0.73), (bx, 0.2, bz + 0.36), rot=(0, 0, rot), mat=red),
                  mk.box(f"EvLabel{k}", (0.6, 0.01, 0.3), (bx + 0.25, -0.61, bz + 0.4), rot=(0, 0, rot), mat=card)]
    view, glows = sk.lcd("Viewer_", PRINT_SCREEN, dark, ink, stand_to=2.95, border=0.09, back=0.18, foot=(1.4, 0.7),
                         logo="AFIS")
    parts += view
    # The kit: its tray in foam with the jars, the lid open behind.
    kx, ky = -1.65, -0.55
    lid = [pk.rounded("KitLid", (1.5, 0.12, 1.15), (kx, ky + 0.66, 3.82), case, r=0.04),
           mk.box("LidFoam", (1.38, 0.02, 1.03), (kx, ky + 0.595, 3.82), mat=foam)]
    parts += sk.tilt_about(lid, (kx, ky + 0.6, 3.25), 35)
    parts += [pk.rounded("KitTray", (1.5, 1.15, 0.3), (kx, ky, 3.1), case, r=0.04),
              mk.box("KitFoam", (1.38, 1.03, 0.02), (kx, ky, 3.255), mat=foam),
              mk.box("Latch", (0.2, 0.06, 0.1), (kx - 0.5, ky - 0.6, 3.15), mat=trim),
              mk.box("Latch", (0.2, 0.06, 0.1), (kx + 0.5, ky - 0.6, 3.15), mat=trim)]
    for k, rgb in enumerate(((20, 20, 22), (232, 232, 228), (170, 170, 176), (200, 160, 60))):
        jx = kx - 0.6 + k * 0.32
        parts += [mk.lathe(f"Jar{k}", [(0.0, 0.0), (0.11, 0.0), (0.12, 0.03), (0.12, 0.24), (0.09, 0.27), (0.0, 0.27)],
                           (jx, ky - 0.2, 3.22), mat=pk.plastic(f"Print_Jar{k}", rgb), segments=12),
                  mk.cylinder(f"JarLid{k}", 0.1, 0.07, (jx, ky - 0.2, 3.52), mat=case, verts=12, bevel=0.01)]
    for k in range(3):  # (brushes laid in their foam slots)
        bx = kx - 0.45 + k * 0.42
        parts += [mk.tube("BrushHandle", (bx, ky + 0.42, 3.27), (bx + 0.05, ky + 0.02, 3.27), 0.025, mat=ink if k else trim,
                          verts=6),
                  mk.tube("BrushHead", (bx + 0.05, ky + 0.02, 3.27), (bx + 0.07, ky - 0.08, 3.27), 0.04, 0.07,
                          mat=pk.plastic("Print_Fibre", (200, 180, 120) if k != 1 else (40, 40, 44)), verts=8)]
    parts += [mk.cylinder("TapeRoll", 0.14, 0.12, (kx + 0.58, ky - 0.25, 3.32), mat=bag, verts=14),
              mk.cylinder("TapeCore", 0.06, 0.13, (kx + 0.58, ky - 0.25, 3.32), mat=card, verts=10)]
    # Cards, the inking slab and roller, bags and the scale.
    parts += sk.papers("Card_", 0.55, -0.75, 2.95, card, rng, n=3, w=0.95, d=0.7, turn=5, yaw=-4)
    for c in range(5):
        for r in range(2):
            parts.append(mk.box("CardBox", (0.15, 0.2, 0.003), (0.21 + c * 0.17, -0.88 + r * 0.26, 3.0), rot=(0, 0, -4), mat=ink))
    parts += [mk.box("Slab", (0.7, 0.45, 0.04), (1.6, -0.85, 2.97), mat=bag, bevel=0.01),
              mk.box("SlabInk", (0.5, 0.3, 0.005), (1.6, -0.85, 2.993), mat=ink),
              mk.cylinder("Roller", 0.06, 0.34, (1.6, -0.45, 3.02), rot=(0, 90, 0), mat=ink, verts=12),
              mk.tube("RollerYoke", (1.6, -0.45, 3.02), (1.6, -0.2, 3.1), 0.015, mat=trim, verts=5),
              mk.tube("RollerGrip", (1.6, -0.2, 3.1), (1.6, 0.05, 3.15), 0.03, mat=case, verts=8),
              mk.box("ScaleL", (0.6, 0.06, 0.004), (0.3, -1.15, 2.952), mat=card),
              mk.box("ScaleL2", (0.06, 0.4, 0.004), (0.03, -0.98, 2.952), mat=card)]
    for k in range(2):
        parts += [mk.box(f"Bag{k}", (0.6, 0.85, 0.03), (2.2 - k * 0.1, 0.15 + k * 0.1, 2.97 + k * 0.035), rot=(0, 0, 8 - k * 14),
                         mat=bag, bevel=0.01),
                  mk.box(f"BagSeal{k}", (0.6, 0.1, 0.035), (2.2 - k * 0.1, 0.52 + k * 0.1, 2.975 + k * 0.035), rot=(0, 0, 8 - k * 14),
                         mat=red)]
    # The magnifier lamp: clamp, two arms, the ring head lit underneath.
    ax, ay = 2.4, 1.05
    head = (2.2, -0.3, 3.75)
    parts += [mk.box("Clamp", (0.2, 0.3, 0.4), (ax, ay, 2.85), mat=case, bevel=0.03),
              mk.tube("MagArm1", (ax, ay, 3.05), (2.45, 0.5, 4.3), 0.035, mat=trim, verts=8),
              mk.cylinder("MagJoint", 0.06, 0.12, (2.45, 0.5, 4.3), rot=(0, 90, 0), mat=case, verts=10),
              mk.tube("MagArm2", (2.45, 0.5, 4.3), (head[0] + 0.25, head[1] + 0.1, head[2] + 0.05), 0.03, mat=trim, verts=8),
              mk.torus("MagRing", 0.3, 0.06, head, mat=case, major_segments=24, minor_segments=8),
              mk.cylinder("MagLens", 0.25, 0.02, head, mat=bag, verts=20)]
    glows.append(mk.torus("MagLight", 0.3, 0.03, (head[0], head[1], head[2] - 0.06), mat=pk.glow("Print_Lens", (255, 248, 230), 3),
                          major_segments=24, minor_segments=6))
    return parts, glows


LAB_SCREEN = (-0.3, 0.55, 4.7, 3.0, 1.8, 4)


def microscope(prefix, x, y, z, body, dark, chrome, lamp_rgb=(255, 244, 220), yaw=0):
    """A compound microscope standing at z, eyepieces toward -Y: the foot, the curved arm, the stage
    with its clips, the nosepiece of three objectives, the binocular head, focus knobs and the lit
    lamp in the foot. Returns (parts, glows)."""
    parts = [pk.rounded(prefix + "Foot", (0.7, 0.95, 0.18), (x, y + 0.05, z + 0.09), body, r=0.06),
             pk.sweep(prefix + "Arm", [(x, y + 0.42, z + 0.15), (x, y + 0.5, z + 0.6), (x, y + 0.45, z + 1.05), (x, y + 0.25, z + 1.3)],
                      0.12, body, sides=8),
             mk.box(prefix + "Stage", (0.62, 0.55, 0.06), (x, y - 0.02, z + 0.62), mat=dark, bevel=0.01),
             mk.cylinder(prefix + "Condenser", 0.09, 0.2, (x, y - 0.02, z + 0.48), mat=dark, verts=12),
             mk.cylinder(prefix + "Turret", 0.16, 0.08, (x, y + 0.05, z + 1.1), mat=chrome, verts=16)]
    for k in range(3):
        a = math.radians(-60 + k * 60)
        parts.append(mk.tube(prefix + "Objective", (x + math.sin(a) * 0.08, y + 0.05 - math.cos(a) * 0.04, z + 1.06),
                             (x + math.sin(a) * 0.1, y + 0.05 - math.cos(a) * 0.05, z + 0.82 + k * 0.03), 0.035, 0.025, mat=chrome,
                             verts=8))
    for sx in (-1, 1):
        parts += [mk.box(prefix + "Clip", (0.05, 0.24, 0.01), (x + sx * 0.17, y - 0.08, z + 0.656), mat=chrome),
                  mk.cylinder(prefix + "Knob", 0.11, 0.06, (x + sx * 0.14, y + 0.42, z + 0.55), rot=(0, 90, 0), mat=dark, verts=14),
                  mk.tube(prefix + "Eyepiece", (x + sx * 0.06, y + 0.05, z + 1.32), (x + sx * 0.09, y - 0.18, z + 1.52), 0.045, mat=dark,
                          verts=10)]
    parts += [pk.rounded(prefix + "Head", (0.3, 0.36, 0.22), (x, y + 0.12, z + 1.28), body, r=0.05),
              mk.box(prefix + "Slide", (0.36, 0.13, 0.01), (x, y - 0.06, z + 0.656), mat=pk.plastic(prefix + "Slide", (210, 226, 232)))]
    glows = [mk.cylinder(prefix + "Lamp", 0.07, 0.02, (x, y - 0.02, z + 0.19), mat=pk.glow(prefix + "Lamp", lamp_rgb, 3), verts=12)]
    sk.turn_about(parts + glows, (x, y, z), yaw)
    return parts, glows


@prop("StationLabBench", pivot="bottom", material="SmoothPlastic", collide=False, texture=1024, set="Tokyo",
      anchor=(0, 0), screen=LAB_SCREEN)
def station_lab_bench():
    """A lab bench: a black epoxy top with its raised lip on white cabinets (drawers over doors, a
    recessed plinth), a service strip with sockets and a gas tap at the back, a steel shelf of
    reagent bottles above (amber and clear, labelled), the analysis monitor (the game's screen), a
    microscope at the right front, a rack of stoppered test tubes, a flask, a wash bottle and a
    pipette at the left."""
    rng = random.Random(31)
    white = pk.plastic("Lab_White", (226, 228, 228))
    resin = pk.plastic("Lab_Resin", (22, 22, 24), rough=0.25)
    steel = pk.metal("Lab_Steel", (150, 154, 160), (190, 194, 200), rough=0.3, metallic=0.7)
    dark = pk.plastic("Lab_Bezel", (24, 24, 26))
    glass = pk.plastic("Lab_Glass", (176, 204, 212), rough=0.08)
    amber = pk.plastic("Lab_Amber", (120, 60, 20), rough=0.12)
    label = mk.noisy("Lab_Label", srgb(226, 222, 210), srgb(244, 240, 230), roughness=0.8)
    blue = pk.plastic("Lab_Cap", (40, 80, 170))
    x, y, z, w, h, tilt = LAB_SCREEN
    parts = [mk.box("Plinth", (4.8, 2.0, 0.3), (0, 0.1, 0.15), mat=resin),
             mk.box("Carcass", (5.0, 2.3, 2.45), (0, 0.0, 1.53), mat=white, bevel=0.02),
             mk.box("Top", (5.2, 2.6, 0.12), (0, 0, 2.82), mat=resin, bevel=0.02),
             mk.box("Lip", (5.2, 0.08, 0.04), (0, -1.26, 2.9), mat=resin, bevel=0.01)]
    for k in range(4):
        cx = -1.875 + k * 1.25
        parts += sk.drawer(f"Dr{k}", cx, -1.15, 2.4, 1.2, 0.5, white, steel)
        parts += [mk.box(f"Door{k}", (1.16, 0.05, 1.7), (cx, -1.17, 1.15), mat=white, bevel=0.015)]
        parts += pk.handle(f"DoorPull{k}", cx + (0.42 if k % 2 else -0.42), -1.2, 1.6, 0.4, steel, stand=0.06, r=0.02)
    # The service strip and the shelf above.
    parts += [mk.box("Service", (4.9, 0.3, 0.35), (0, 1.12, 3.06), mat=white, bevel=0.03)]
    for k in range(3):
        parts += [mk.box("Socket", (0.3, 0.02, 0.2), (-1.9 + k * 1.3, 0.96, 3.06), mat=label, bevel=0.01),
                  mk.box("SocketPins", (0.12, 0.01, 0.04), (-1.9 + k * 1.3, 0.95, 3.07), mat=dark)]
    parts += [mk.cylinder("GasTap", 0.05, 0.4, (2.1, 1.0, 3.35), mat=steel, verts=10),
              mk.tube("GasNozzle", (2.1, 1.0, 3.5), (2.1, 0.8, 3.45), 0.025, mat=steel, verts=8),
              mk.box("GasLever", (0.22, 0.04, 0.04), (2.1, 1.0, 3.58), mat=pk.plastic("Lab_Lever", (220, 170, 40)))]
    for sx in (-1, 1):
        parts.append(mk.cylinder("Upright", 0.04, 3.7, (sx * 2.42, 1.1, 4.95), mat=steel, verts=10))
    parts += [mk.box("Shelf", (5.0, 0.55, 0.05), (0, 1.03, 6.02), mat=steel, bevel=0.01),
              mk.box("ShelfLip", (5.0, 0.03, 0.12), (0, 0.77, 6.08), mat=steel)]
    for k in range(9):
        bx = -2.15 + k * 0.53
        tall = 0.7 + rng.uniform(-0.12, 0.1)
        m = amber if k % 3 != 1 else glass
        r = 0.16 if k % 2 else 0.19
        parts += [mk.lathe(f"Bottle{k}", [(0.0, 0.0), (r, 0.0), (r, tall * 0.7), (r * 0.5, tall * 0.85), (r * 0.4, tall * 0.88),
                                          (0.0, tall * 0.88)], (bx, 1.03, 6.045), mat=m, segments=12),
                  mk.cylinder(f"BCap{k}", r * 0.45, tall * 0.12, (bx, 1.03, 6.045 + tall * 0.94), mat=blue if k % 3 == 1 else dark,
                              verts=10),
                  mk.box(f"BLabel{k}", (r * 1.2, 0.01, tall * 0.3), (bx, 1.03 - r - 0.003, 6.045 + tall * 0.38), mat=label)]
    # The monitor.
    mon, glows = sk.lcd("Mon_", LAB_SCREEN, dark, resin, stand_to=2.88, border=0.08, back=0.16, foot=(1.4, 0.5),
                         neck_y=0.85)
    parts += mon
    parts += sk.keyboard("Kb_", -0.3, -0.78, 2.88, white, label, w=1.8, d=0.6)
    # The microscope, the tubes, flask, wash bottle and pipette.
    scope, lamp = microscope("Scope_", 1.8, -0.4, 2.88, white, dark, steel)
    parts += scope
    glows += lamp
    rx, ry = -1.95, -0.55
    parts += [mk.box("RackTop", (1.1, 0.36, 0.03), (rx, ry, 3.28), mat=white),
              mk.box("RackBase", (1.1, 0.36, 0.03), (rx, ry, 2.9), mat=white)]
    for sx in (-1, 1):
        parts.append(mk.box("RackEnd", (0.03, 0.36, 0.4), (rx + sx * 0.54, ry, 3.09), mat=white))
    liquids = ((200, 40, 40), (230, 190, 60), (60, 140, 200), (200, 200, 190), (100, 170, 90))
    for k in range(5):
        tx = rx - 0.4 + k * 0.2
        lq = pk.plastic(f"Lab_Liquid{k}", liquids[k], rough=0.1)
        parts += [mk.cylinder(f"Tube{k}", 0.05, 0.62, (tx, ry, 3.22), mat=glass, verts=10),
                  mk.cylinder(f"Liquid{k}", 0.052, 0.28, (tx, ry, 3.05), mat=lq, verts=10),
                  mk.cylinder(f"Stopper{k}", 0.055, 0.07, (tx, ry, 3.56), mat=dark if k % 2 else blue, verts=10)]
    parts.append(mk.lathe("Flask", [(0.0, 0.0), (0.26, 0.0), (0.27, 0.04), (0.08, 0.42), (0.07, 0.58), (0.085, 0.6), (0.0, 0.6)],
                          (-1.35, 0.35, 2.88), mat=glass, segments=16))
    parts.append(mk.cylinder("FlaskLiquid", 0.2, 0.1, (-1.35, 0.35, 2.94), mat=pk.plastic("Lab_Liquid5", (90, 60, 140)),
                             verts=16, radius2=0.15))
    parts += [mk.lathe("WashBottle", [(0.0, 0.0), (0.14, 0.0), (0.14, 0.42), (0.06, 0.5), (0.0, 0.5)], (-2.2, 0.4, 2.88),
                       mat=pk.plastic("Lab_Wash", (230, 236, 236), rough=0.3), segments=12),
              mk.tube("WashSpout", (-2.2, 0.4, 3.38), (-2.05, 0.25, 3.5), 0.015, mat=dark, verts=5),
              mk.tube("Pipette", (-1.05, 0.05, 2.92), (-0.65, 0.25, 2.92), 0.025, 0.01, mat=glass, verts=6),
              mk.sphere("PipetteBulb", 0.05, (-1.08, 0.03, 2.93), mat=pk.plastic("Lab_Bulb", (200, 60, 50)), segments=8, rings=6)]
    parts += sk.papers("Notes_", 0.9, 0.55, 2.88, label, rng, n=3, w=0.7, d=0.9)
    return parts, glows
