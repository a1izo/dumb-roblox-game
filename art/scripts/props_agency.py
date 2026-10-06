"""Agency HQ's props (set "Agency", exported to DeathsGambitModels_Agency.fbx): the three station looks
of the old-school investigation unit (a bank of CRT monitors, a detective's phone desk, a
reel-to-reel wiretap console), the tower's lift doors, the lobby's metal detector and X-ray belt,
the interrogation table, archive and evidence storage, the director's desk, and office things
(water cooler, photocopier, fax, desk phone, coffee machine, coat stand, pin board, rolling
whiteboard, microfilm reader, fume hood).

Built to the semi-real standard (propkit): real sizes at about 3.5 studs to the metre, bevelled
edges, the small parts that make a thing read as real, textured materials baked with ambient
occlusion. Props face -Y and stand on z = 0. Station looks follow props_stations.py: the game's
invisible desk (5 x 3 x 2.4) stands on the design origin with the worker in front at -Y, and the
game's screen goes in the prop's `screen` slot. Tabletop things (fax, phone, coffee machine) stand
on z = 0 too; the map places them at the height of the surface they sit on."""

import math

import modelkit as mk
import propkit as pk
from common import srgb
from props import prop
from props_stations import desk, monitor

LAMP_WARM = (255, 214, 160)


def crt(prefix, x, y, z, w, h, housing, bezel, depth=2.2, screen=None, tilt=0):
    """A CRT monitor whose face (w by h) is centred at (x, y, z) facing -Y: a deep tapered
    housing behind it, a bezel round the face; screen (a material) fills the face when given
    (the game's own screen goes there otherwise)."""
    parts = [mk.box(prefix + "Bezel", (w + 0.5, 0.35, h + 0.5), (x, y + 0.17, z), rot=(-tilt, 0, 0), mat=bezel, bevel=0.08),
             mk.box(prefix + "Body", (w + 0.2, depth * 0.55, h + 0.2), (x, y + 0.35 + depth * 0.27, z), mat=housing,
                    bevel=0.1),
             mk.box(prefix + "Tube", (w * 0.62, depth * 0.45, h * 0.62), (x, y + 0.35 + depth * 0.72, z + 0.05),
                    mat=housing, bevel=0.15)]
    if screen is not None:
        parts.append(mk.box(prefix + "Face", (w, 0.04, h), (x, y - 0.02, z), rot=(-tilt, 0, 0), mat=screen))
    return parts


def feed_colours():
    return [(110, 150, 130), (120, 140, 170), (160, 156, 110), (100, 130, 160), (140, 160, 120), (170, 140, 120),
            (120, 160, 150), (150, 150, 170)]


# Station looks -----------------------------------------------------------------------------------------

CRT_SCREEN = (0.0, -0.1, 4.25, 2.4, 1.8, 4)


@prop("StationCRTBank", pivot="bottom", material="Metal", collide=False, texture=1024, set="Agency", anchor=(0, 0),
      screen=CRT_SCREEN)
def station_crt_bank():
    """The security office's monitor console: a grey steel desk and, on a steel rack behind it,
    a bank of CRT monitors showing camera feeds; the middle one on the desk is the game's screen.
    A keyboard, the switcher panel with its lit buttons, a joystick, the tape log and a mug."""
    steel = pk.metal("Crt_Steel", (70, 72, 78), (98, 100, 108), rough=0.45, metallic=0.5)
    beige = pk.plastic("Crt_Beige", (182, 172, 150))
    bezel = pk.plastic("Crt_Bezel", (60, 58, 54))
    dark = pk.metal("Crt_Dark", (20, 20, 22), (34, 34, 38), rough=0.5, metallic=0.2)
    top = mk.noisy("Crt_Top", srgb(52, 54, 60), srgb(70, 72, 80), scale=10, roughness=0.35)
    paper = pk.plastic("Crt_Paper", (232, 226, 210))
    x, y, z, w, h, tilt = CRT_SCREEN
    parts = desk("Crt_", top, steel)
    parts += crt("Main_", x, y, z, w, h, beige, bezel, depth=2.0, tilt=tilt)
    parts.append(mk.box("MainStand", (1.6, 1.4, 0.3), (x, y + 1.0, 3.05), mat=beige, bevel=0.05))
    # The rack behind: two rows of feeds above the desk and a pair either side of the main one.
    parts += [mk.box("RackPost", (0.18, 0.4, 8.6), (sx * 2.5, 1.25, 4.3), mat=steel) for sx in (-1, 1)]
    parts += [mk.box("RackShelf", (5.2, 1.6, 0.14), (0, 1.25, zz), mat=steel) for zz in (5.6, 7.3)]
    glows = []
    colours = feed_colours()
    k = 0
    for row, zz in ((0, 6.45), (1, 8.1)):
        for col in range(3):
            fx = -1.62 + col * 1.62
            parts += crt(f"Feed{k}_", fx, 0.55, zz, 1.2, 0.9, beige, bezel, depth=1.3)
            glows.append(mk.box(f"FeedLit{k}", (1.2, 0.04, 0.9), (fx, 0.51, zz),
                                mat=pk.glow(f"Crt_Feed{k}", colours[k], 1.8)))
            k += 1
    parts += [mk.box("Keyboard", (2.2, 0.8, 0.12), (-0.3, -0.8, 2.97), rot=(4, 0, 0), mat=beige, bevel=0.03),
              mk.box("Switcher", (1.4, 0.9, 0.3), (1.8, -0.6, 3.05), rot=(8, 0, 0), mat=dark, bevel=0.04),
              mk.box("JoyBase", (0.7, 0.7, 0.2), (-2.0, -0.7, 3.0), mat=dark, bevel=0.05),
              mk.cylinder("Stick", 0.05, 0.5, (-2.0, -0.7, 3.35), mat=steel, verts=8),
              mk.box("Log", (0.9, 1.1, 0.08), (-1.95, 0.4, 2.94), rot=(0, 0, -10), mat=paper),
              mk.cylinder("Mug", 0.16, 0.38, (2.25, 0.5, 3.09), mat=pk.plastic("Crt_Mug", (150, 30, 36)), verts=12)]
    for i in range(6):
        bx = 1.35 + (i % 3) * 0.3
        bz = 3.2 - 0.02 + (i // 3) * 0.0
        by = -0.8 + (i // 3) * 0.3
        glows.append(mk.box("Button", (0.18, 0.18, 0.05), (bx, by, bz + 0.03),
                            mat=pk.glow("Crt_Button", (255, 170, 60) if i % 2 else (120, 255, 150), 3)))
    return parts, glows


PHONE_DESK_SCREEN = (-0.6, 0.15, 4.2, 2.1, 1.6, 6)


@prop("StationPhoneDesk", pivot="bottom", material="Wood", collide=False, texture=1024, set="Agency", anchor=(0, 0),
      screen=PHONE_DESK_SCREEN)
def station_phone_desk():
    """A detective's desk on the phone-records beat: a worn wooden desk with a drawer pedestal,
    the beige records terminal (the game's screen) and its keyboard, a multi-line desk phone with
    lit line buttons, a dot-matrix printer spilling a call log, a card index, files and a lamp."""
    wood = mk.wood("PDesk_Wood", srgb(104, 70, 44), srgb(58, 38, 24), scale=4)
    top = mk.noisy("PDesk_Top", srgb(40, 50, 44), srgb(56, 68, 60), scale=8, roughness=0.45)
    beige = pk.plastic("PDesk_Beige", (186, 176, 154))
    bezel = pk.plastic("PDesk_Bezel", (70, 66, 60))
    dark = pk.metal("PDesk_Dark", (22, 22, 24), (38, 38, 42), rough=0.5, metallic=0.2)
    brass = pk.metal("PDesk_Brass", (150, 118, 60), (200, 164, 90), rough=0.3, metallic=0.9)
    paper = pk.plastic("PDesk_Paper", (236, 232, 218))
    folder = pk.plastic("PDesk_Folder", (170, 140, 90))
    x, y, z, w, h, tilt = PHONE_DESK_SCREEN
    parts = desk("PDesk_", wood, wood)
    parts.append(mk.box("Blotter", (2.8, 1.4, 0.04), (0.2, -0.45, 2.99), mat=top))
    parts.append(mk.box("Pedestal", (1.5, 2.3, 2.7), (1.75, -0.05, 1.35), mat=wood, bevel=0.03))
    for k in range(3):
        parts.append(mk.box("Drawer", (1.35, 0.04, 0.78), (1.75, -1.22, 0.5 + k * 0.88), mat=wood))
        parts += pk.handle("Pull", 1.75, -1.24, 0.7 + k * 0.88, 0.5, brass, vertical=False, stand=0.07, r=0.03)
    parts += crt("Term_", x, y, z, w, h, beige, bezel, depth=1.9, tilt=tilt)
    parts.append(mk.box("TermBase", (1.8, 1.4, 0.26), (x, y + 0.9, 3.03), mat=beige, bevel=0.05))
    parts.append(mk.box("Keyboard", (2.0, 0.75, 0.12), (x, -0.85, 2.98), rot=(4, 0, 0), mat=beige, bevel=0.03))
    # The phone: body, handset on its cradle, the line buttons along the front.
    parts += [pk.rounded("PhoneBody", (1.1, 0.9, 0.35), (1.55, -0.55, 3.07), dark, r=0.07),
              pk.rounded("Handset", (1.0, 0.28, 0.24), (1.55, -0.35, 3.34), dark, r=0.1),
              mk.tube("Cord", (1.05, -0.4, 3.1), (0.9, -0.2, 2.95), 0.025, mat=dark, verts=4)]
    glows = []
    for i in range(5):
        glows.append(mk.box("Line", (0.12, 0.05, 0.09), (1.15 + i * 0.2, -1.0, 3.12),
                            mat=pk.glow("PDesk_Line", (255, 190, 80) if i in (1, 3) else (255, 80, 60), 3)))
    # The printer at the back right, its call log folding down behind the desk.
    parts += [mk.box("Printer", (1.4, 1.0, 0.45), (1.6, 0.75, 3.12), mat=beige, bevel=0.05),
              mk.box("PrinterSlot", (1.1, 0.1, 0.05), (1.6, 0.35, 3.36), mat=dark),
              mk.box("Log", (1.0, 0.04, 1.4), (1.6, 1.3, 2.4), rot=(-8, 0, 0), mat=paper),
              mk.box("LogFold", (1.0, 0.5, 0.05), (1.6, 1.0, 3.4), rot=(35, 0, 0), mat=paper)]
    parts += [mk.box("CardIndex", (0.8, 0.6, 0.45), (-2.1, 0.5, 3.13), mat=dark, bevel=0.04),
              mk.box("Cards", (0.7, 0.5, 0.2), (-2.1, 0.5, 3.4), mat=paper),
              mk.box("Files", (1.0, 1.3, 0.35), (-2.05, -0.55, 3.08), rot=(0, 0, 8), mat=folder),
              mk.box("File2", (1.0, 1.3, 0.05), (-2.0, -0.5, 3.28), rot=(0, 0, -5), mat=paper),
              mk.cylinder("LampBase", 0.22, 0.08, (-2.1, 1.0, 2.99), mat=brass, verts=12),
              mk.tube("LampStem", (-2.1, 1.0, 3.0), (-2.0, 0.9, 4.3), 0.04, mat=brass, verts=6),
              mk.box("LampShade", (1.0, 0.45, 0.3), (-1.85, 0.75, 4.35), rot=(0, 0, 20), mat=pk.plastic("PDesk_Green", (30, 90, 60)),
                     bevel=0.1)]
    glows.append(mk.box("LampBulb", (0.6, 0.2, 0.05), (-1.85, 0.75, 4.18), mat=pk.glow("PDesk_Bulb", LAMP_WARM, 3)))
    return parts, glows


REEL_SCREEN = (-1.25, -0.1, 3.9, 1.8, 1.3, 10)


@prop("StationReelToReel", pivot="bottom", material="Metal", collide=False, texture=1024, set="Agency", anchor=(0, 0),
      screen=REEL_SCREEN)
def station_reel_to_reel():
    """The wiretap console behind the one-way mirror: a steel desk, a small scope monitor showing
    the line (the game's screen), and on a rack at its right a reel-to-reel recorder over a panel
    of VU meters; headphones, a microphone and the tape log on the desk."""
    steel = pk.metal("Reel_Steel", (66, 68, 74), (94, 96, 104), rough=0.45, metallic=0.5)
    alu = pk.metal("Reel_Alu", (160, 164, 170), (196, 200, 206), rough=0.3, metallic=0.8)
    dark = pk.metal("Reel_Dark", (20, 20, 22), (34, 34, 38), rough=0.5, metallic=0.2)
    top = mk.noisy("Reel_Top", srgb(46, 48, 54), srgb(64, 66, 72), scale=10, roughness=0.35)
    tape = pk.plastic("Reel_Tape", (60, 38, 24))
    paper = pk.plastic("Reel_Paper", (232, 226, 210))
    x, y, z, w, h, tilt = REEL_SCREEN
    parts = desk("Reel_", top, steel)
    parts += crt("Scope_", x, y, z, w, h, steel, dark, depth=1.5, tilt=tilt)
    parts.append(mk.box("ScopeBase", (1.4, 1.2, 0.3), (x, y + 0.8, 3.05), mat=steel, bevel=0.04))
    # The rack at the right: the recorder above, the meters below, on the desk top.
    rx = 1.45
    parts += [mk.box("Rack", (2.2, 1.8, 4.6), (rx, 0.35, 5.2), mat=steel, bevel=0.04),
              mk.box("DeckFace", (2.0, 0.06, 2.3), (rx, -0.58, 6.2), mat=alu, bevel=0.02),
              mk.box("MeterFace", (2.0, 0.06, 1.1), (rx, -0.58, 4.1), mat=dark, bevel=0.02)]
    for sx in (-1, 1):
        cx = rx + sx * 0.5
        parts += [mk.cylinder("Reel", 0.46, 0.08, (cx, -0.66, 6.7), rot=(90, 0, 0), mat=alu, verts=24),
                  mk.cylinder("Tape", 0.36, 0.1, (cx, -0.68, 6.7), rot=(90, 0, 0), mat=tape, verts=20),
                  mk.cylinder("Hub", 0.1, 0.16, (cx, -0.72, 6.7), rot=(90, 0, 0), mat=dark, verts=10)]
    parts += [mk.box("Heads", (0.8, 0.12, 0.3), (rx, -0.66, 5.9), mat=dark, bevel=0.03),
              mk.tube("TapeRun", (rx - 0.5, -0.7, 6.3), (rx + 0.5, -0.7, 6.3), 0.02, mat=tape, verts=4)]
    for k in range(5):
        parts.append(mk.cylinder("Knob", 0.08, 0.08, (rx - 0.8 + k * 0.4, -0.64, 5.3), rot=(90, 0, 0), mat=dark, verts=10))
    glows = [mk.box(f"Meter{k}", (0.8, 0.04, 0.6), (rx - 0.45 + k * 0.9, -0.63, 4.15),
                    mat=pk.glow("Reel_Meter", (255, 196, 110), 2.4)) for k in range(2)]
    glows.append(mk.box("RecLamp", (0.14, 0.04, 0.14), (rx + 0.8, -0.63, 5.55), mat=pk.glow("Reel_Rec", (255, 50, 50), 5)))
    # Headphones, the microphone and the log.
    parts += [mk.torus("Band", 0.35, 0.04, (0.2, -0.6, 3.05), rot=(0, 0, 0), mat=dark, major_segments=16,
                       minor_segments=4),
              mk.cylinder("Cup", 0.2, 0.14, (-0.15, -0.6, 3.02), mat=dark, verts=12),
              mk.cylinder("Cup", 0.2, 0.14, (0.55, -0.6, 3.02), mat=dark, verts=12),
              mk.cylinder("MicBase", 0.2, 0.06, (0.6, 0.4, 2.98), mat=dark, verts=12),
              mk.tube("MicStem", (0.6, 0.4, 3.0), (0.5, 0.1, 3.8), 0.03, mat=alu, verts=5),
              mk.cylinder("Mic", 0.1, 0.35, (0.48, 0.02, 3.95), rot=(-60, 0, 0), mat=dark, verts=10),
              mk.box("Log", (1.0, 1.2, 0.06), (-0.2, -0.3, 2.95), rot=(0, 0, 6), mat=paper)]
    return parts, glows


# The lobby -------------------------------------------------------------------------------------------


@prop("ElevatorDoors", pivot="bottom", material="Metal", collide=False, texture=1024, set="Agency")
def elevator_doors():
    """A lift's doors in the core wall: two brushed-steel leaves in a stone surround, the floor
    indicator over them (lit) and the call buttons at the right. Flat against the wall behind."""
    steel = pk.metal("Lift_Steel", (150, 154, 160), (186, 190, 196), rough=0.25, metallic=0.9, scale=40)
    stone = mk.noisy("Lift_Stone", srgb(34, 32, 34), srgb(58, 54, 56), scale=14, roughness=0.3)
    dark = pk.metal("Lift_Dark", (18, 18, 20), (30, 30, 34), rough=0.4, metallic=0.4)
    parts = [mk.box("Surround", (5.8, 0.3, 9.6), (0, 0.2, 4.8), mat=stone, bevel=0.04),
             mk.box("Head", (6.2, 0.5, 0.6), (0, 0.0, 9.3), mat=stone, bevel=0.05)]
    for sx in (-1, 1):
        parts += [mk.box("Leaf", (2.05, 0.12, 8.0), (sx * 1.05, -0.02, 4.0), mat=steel, bevel=0.01),
                  mk.box("Jamb", (0.2, 0.4, 8.2), (sx * 2.25, -0.05, 4.1), mat=steel, bevel=0.02)]
    parts += [mk.box("Seam", (0.03, 0.14, 8.0), (0, -0.05, 4.0), mat=dark),
              mk.box("Sill", (4.6, 0.6, 0.06), (0, -0.2, 0.03), mat=steel),
              mk.box("IndicatorBox", (2.2, 0.2, 0.7), (0, -0.15, 8.75), mat=dark, bevel=0.03),
              mk.box("ButtonPlate", (0.5, 0.12, 1.2), (2.85, -0.05, 4.2), mat=steel, bevel=0.02)]
    glows = [mk.box("Floor", (1.4, 0.04, 0.4), (0, -0.27, 8.75), mat=pk.glow("Lift_Floor", (255, 150, 60), 3)),
             mk.cylinder("Call", 0.1, 0.05, (2.85, -0.13, 4.45), rot=(90, 0, 0), mat=pk.glow("Lift_Call", (255, 244, 220), 3),
                         verts=12),
             mk.cylinder("Call", 0.1, 0.05, (2.85, -0.13, 3.95), rot=(90, 0, 0), mat=pk.glow("Lift_Call", (255, 244, 220), 3),
                         verts=12)]
    return parts, glows


@prop("MetalDetector", pivot="bottom", material="SmoothPlastic", collide=False, texture=512, set="Agency")
def metal_detector():
    """A walk-through metal detector: two grey panels joined by a head with its lit status bar.
    People walk through it (the map puts colliders on its sides)."""
    grey = pk.plastic("Det_Grey", (170, 172, 176))
    dark = pk.metal("Det_Dark", (30, 30, 34), (46, 46, 52), rough=0.5, metallic=0.2)
    parts = []
    for sx in (-1, 1):
        parts += [mk.box("Panel", (0.35, 2.0, 7.2), (sx * 1.75, 0, 3.6), mat=grey, bevel=0.08),
                  mk.box("Foot", (0.6, 2.2, 0.2), (sx * 1.75, 0, 0.1), mat=dark, bevel=0.04)]
    parts.append(mk.box("Head", (3.9, 2.0, 0.6), (0, 0, 7.5), mat=grey, bevel=0.1))
    parts.append(mk.box("HeadFace", (2.6, 0.06, 0.35), (0, -1.02, 7.5), mat=dark))
    glows = [mk.box("Status", (2.2, 0.04, 0.12), (0, -1.06, 7.5), mat=pk.glow("Det_Status", (90, 255, 140), 3))]
    return parts, glows


@prop("XRayScanner", pivot="bottom", material="SmoothPlastic", collide=True, texture=1024, set="Agency")
def xray_scanner():
    """The lobby's baggage X-ray: a rubber belt through a grey tunnel with lead curtains, rollers
    at both ends, the operator's screen on its arm and the trays stacked by the entrance."""
    grey = pk.plastic("Xray_Grey", (178, 180, 184))
    dark = pk.metal("Xray_Dark", (26, 26, 30), (42, 42, 48), rough=0.5, metallic=0.2)
    belt = pk.rubber("Xray_Belt")
    curtain = mk.noisy("Xray_Curtain", srgb(40, 40, 44), srgb(60, 60, 66), scale=30, roughness=0.9)
    tray = pk.plastic("Xray_Tray", (60, 70, 90))
    parts = [mk.box("Tunnel", (3.2, 3.6, 3.4), (0, 0, 2.9), mat=grey, bevel=0.15),
             mk.box("Bed", (2.4, 9.6, 0.5), (0, 0, 2.35), mat=grey, bevel=0.06),
             mk.box("Belt", (2.2, 9.4, 0.06), (0, 0, 2.63), mat=belt)]
    for sy in (-1, 1):
        parts.append(mk.box("Curtain", (2.0, 0.05, 1.3), (0, sy * 1.82, 2.95), mat=curtain))
        parts.append(mk.cylinder("Roller", 0.2, 2.3, (0, sy * 4.7, 2.4), rot=(0, 90, 0), mat=dark, verts=12))
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(mk.box("Leg", (0.2, 0.2, 2.1), (sx * 1.0, sy * 4.3, 1.05), mat=dark))
    parts += [mk.tube("Arm", (1.6, -3.0, 2.6), (2.0, -3.0, 4.6), 0.06, mat=dark, verts=6),
              mk.box("Monitor", (1.4, 0.3, 1.0), (2.0, -3.1, 5.0), rot=(0, 0, -30), mat=dark, bevel=0.05)]
    for k in range(3):
        parts.append(mk.box("Tray", (1.8, 1.4, 0.3), (0, -4.2, 2.8 + k * 0.3), mat=tray, bevel=0.06))
    glows = [mk.box("Picture", (1.2, 0.04, 0.8), (1.94, -3.25, 5.0), rot=(0, 0, -30),
                    mat=pk.glow("Xray_Picture", (120, 170, 230), 2)),
             mk.box("Warning", (1.4, 0.04, 0.25), (0, -1.73, 4.3), mat=pk.glow("Xray_Warn", (255, 190, 60), 3))]
    return parts, glows


# The interrogation rooms, the archive and the evidence lock-up -----------------------------------------


@prop("InterrogationTable", pivot="bottom", material="Metal", collide=True, texture=512, set="Agency")
def interrogation_table():
    """A bolted-down steel table with the cuff ring welded to its middle, a scuffed top, a paper
    cup and a closed case file on it."""
    steel = pk.metal("Int_Steel", (90, 92, 98), (124, 126, 132), rough=0.5, metallic=0.6)
    dark = pk.metal("Int_Dark", (26, 26, 30), (40, 40, 46), rough=0.5, metallic=0.3)
    folder = pk.plastic("Int_Folder", (170, 140, 90))
    cup = pk.plastic("Int_Cup", (226, 222, 212))
    parts = [mk.box("Top", (4.4, 2.8, 0.14), (0, 0, 2.6), mat=steel, bevel=0.03),
             mk.box("Apron", (4.2, 2.6, 0.3), (0, 0, 2.38), mat=steel)]
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts += [mk.box("Leg", (0.16, 0.16, 2.3), (sx * 1.95, sy * 1.15, 1.15), mat=steel),
                      mk.box("Plate", (0.5, 0.5, 0.04), (sx * 1.95, sy * 1.15, 0.02), mat=dark)]
    parts += [mk.torus("Ring", 0.2, 0.04, (0, 0, 2.72), rot=(90, 0, 0), mat=dark, major_segments=12, minor_segments=4),
              mk.box("Folder", (1.1, 1.4, 0.06), (1.2, -0.3, 2.7), rot=(0, 0, 12), mat=folder),
              mk.cylinder("Cup", 0.14, 0.34, (-1.4, 0.5, 2.84), mat=cup, verts=12, radius2=0.11)]
    return parts, []


@prop("ArchiveShelving", pivot="bottom", material="Metal", collide=True, texture=1024, set="Agency")
def archive_shelving():
    """A compact archive unit on its rails: a painted steel carriage with a hand wheel at the end
    and five shelves of box files and bound ledgers, labelled by year."""
    paint = pk.paint("Arch_Paint", (120, 128, 118), rough=0.5)
    steel = pk.metal("Arch_Steel", (140, 142, 148), (176, 178, 184), rough=0.35, metallic=0.7)
    dark = pk.metal("Arch_Dark", (24, 24, 28), (40, 40, 44), rough=0.5, metallic=0.3)
    box_mats = [pk.plastic("Arch_Box1", (150, 124, 84)), pk.plastic("Arch_Box2", (120, 96, 64)),
                pk.plastic("Arch_Box3", (80, 90, 110)), pk.plastic("Arch_Box4", (170, 150, 110))]
    label = pk.plastic("Arch_Label", (236, 232, 220))
    w, d, h = 8.2, 3.0, 7.4
    parts = [mk.box("Base", (w, d, 0.35), (0, 0, 0.18), mat=paint, bevel=0.03),
             mk.box("Top", (w, d, 0.12), (0, 0, h - 0.06), mat=paint, bevel=0.02),
             mk.box("Spine", (w, 0.08, h - 0.4), (0, 0, h / 2), mat=paint)]
    for sx in (-1, 1):
        parts.append(mk.box("End", (0.12, d, h - 0.2), (sx * (w / 2 - 0.06), 0, h / 2), mat=paint, bevel=0.02))
    parts += [mk.cylinder("WheelHub", 0.12, 0.2, (w / 2 + 0.12, 0, 4.2), rot=(0, 90, 0), mat=dark, verts=10),
              mk.torus("Wheel", 0.55, 0.05, (w / 2 + 0.25, 0, 4.2), rot=(0, 90, 0), mat=steel, major_segments=20,
                       minor_segments=5)]
    for k in range(3):
        a = k * 2 * math.pi / 3
        parts.append(mk.tube("WheelSpoke", (w / 2 + 0.25, 0, 4.2),
                             (w / 2 + 0.25, math.cos(a) * 0.55, 4.2 + math.sin(a) * 0.55), 0.03, mat=steel, verts=4))
    shelves = [0.4 + k * 1.4 for k in range(5)]
    seed = 0
    for side in (-1, 1):
        for zz in shelves:
            parts.append(mk.box("Shelf", (w - 0.3, d / 2 - 0.1, 0.06), (0, side * d / 4, zz), mat=steel))
            x0 = -w / 2 + 0.3
            while x0 < w / 2 - 0.9:
                seed += 7
                bw = 0.55 + (seed % 5) * 0.08
                bh = 0.95 + (seed % 3) * 0.1
                parts.append(mk.box("BoxFile", (bw, d / 2 - 0.3, bh), (x0 + bw / 2, side * d / 4, zz + 0.03 + bh / 2),
                                    mat=box_mats[seed % 4], bevel=0.02))
                if seed % 2 == 0:
                    parts.append(mk.box("Tag", (bw * 0.6, 0.02, 0.2),
                                        (x0 + bw / 2, side * (d / 2 - 0.14), zz + 0.03 + bh * 0.7), mat=label))
                x0 += bw + 0.06
    return parts, []


@prop("EvidenceCage", pivot="bottom", material="Metal", collide=True, texture=1024, set="Agency")
def evidence_cage():
    """A bay of the evidence lock-up: a wire-mesh cage with a padlocked door, steel shelves inside
    holding tagged evidence bags, boxes and a bagged typewriter."""
    steel = pk.metal("Cage_Steel", (110, 112, 118), (150, 152, 158), rough=0.4, metallic=0.7)
    dark = pk.metal("Cage_Dark", (24, 24, 28), (40, 40, 46), rough=0.5, metallic=0.3)
    bag = mk.noisy("Cage_Bag", srgb(200, 206, 210), srgb(230, 232, 236), scale=20, roughness=0.2)
    tag = pk.plastic("Cage_Tag", (220, 40, 40))
    boxm = pk.plastic("Cage_Box", (150, 124, 84))
    w, d, h = 8.0, 3.4, 8.2
    parts = []
    # The frame and mesh: posts, rails and a grid of wires on the front and sides.
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(mk.box("Post", (0.14, 0.14, h), (sx * w / 2, sy * d / 2, h / 2), mat=steel))
    for zz in (0.1, h - 0.1):
        parts.append(mk.box("RailF", (w, 0.1, 0.12), (0, -d / 2, zz), mat=steel))
        parts.append(mk.box("RailB", (w, 0.1, 0.12), (0, d / 2, zz), mat=steel))
    for k in range(1, 20):
        xx = -w / 2 + w * k / 20
        parts.append(mk.box("WireV", (0.025, 0.025, h - 0.2), (xx, -d / 2, h / 2), mat=steel))
    for k in range(1, 20):
        zz = h * k / 20
        parts.append(mk.box("WireH", (w, 0.025, 0.025), (0, -d / 2, zz), mat=steel))
        for sx in (-1, 1):
            parts.append(mk.box("WireS", (0.025, d, 0.025), (sx * w / 2, 0, zz), mat=steel))
    parts += [mk.box("Back", (w, 0.06, h), (0, d / 2, h / 2), mat=steel),
              mk.box("DoorFrame", (0.12, 0.2, h - 0.6), (1.2, -d / 2 - 0.08, h / 2), mat=dark),
              mk.box("Hasp", (0.3, 0.14, 0.2), (1.2, -d / 2 - 0.16, 4.2), mat=dark),
              mk.box("Padlock", (0.28, 0.12, 0.34), (1.2, -d / 2 - 0.26, 4.0), mat=pk.metal("Cage_Brass", (160, 130, 70),
                                                                                           (200, 170, 100), 0.3, 0.9))]
    for zz in (0.4, 2.6, 4.8, 7.0):
        parts.append(mk.box("Shelf", (w - 0.3, d - 0.4, 0.08), (0, 0.1, zz), mat=steel))
        for k in range(5):
            bx = -w / 2 + 0.9 + k * 1.55
            if (k + int(zz)) % 3 == 0:
                parts.append(mk.box("Box", (1.3, 1.6, 1.0), (bx, 0.3, zz + 0.54), mat=boxm, bevel=0.03))
            else:
                parts += [mk.box("Bag", (1.0, 0.6, 1.3), (bx, 0.0, zz + 0.7), rot=(0, 0, (k * 17) % 20 - 10), mat=bag,
                                 bevel=0.08),
                          mk.box("BagTag", (0.3, 0.04, 0.4), (bx + 0.2, -0.34, zz + 0.9), mat=tag)]
    return parts, []


# The director and the office ----------------------------------------------------------------------------


@prop("ExecutiveDesk", pivot="bottom", material="Wood", collide=True, texture=1024, set="Agency")
def executive_desk():
    """The director's desk: dark walnut with a green leather inlay, pedestals of drawers, a brass
    banker's lamp, a pen stand, the nameplate facing the visitor and a closed dossier."""
    wood = mk.wood("Exec_Wood", srgb(70, 40, 26), srgb(34, 18, 12), scale=5)
    leather = mk.noisy("Exec_Leather", srgb(26, 60, 42), srgb(40, 80, 58), scale=20, roughness=0.6)
    brass = pk.metal("Exec_Brass", (150, 118, 60), (206, 170, 96), rough=0.25, metallic=0.9)
    dark = pk.metal("Exec_Dark", (20, 20, 22), (34, 34, 38), rough=0.5, metallic=0.2)
    folder = pk.plastic("Exec_Folder", (120, 30, 34))
    w, d, h = 6.6, 3.2, 2.7
    parts = [mk.box("Top", (w, d, 0.16), (0, 0, h - 0.08), mat=wood, bevel=0.04),
             mk.box("Inlay", (w - 1.2, d - 0.9, 0.02), (0, 0.1, h + 0.005), mat=leather),
             mk.box("Modesty", (w - 3.2, 0.12, 1.8), (0, -d / 2 + 0.3, h - 1.0), mat=wood)]
    for sx in (-1, 1):
        parts.append(mk.box("Pedestal", (1.5, d - 0.2, h - 0.16), (sx * (w / 2 - 0.85), 0, (h - 0.16) / 2), mat=wood,
                            bevel=0.03))
        for k in range(3):
            parts.append(mk.box("Drawer", (1.3, 0.04, 0.65), (sx * (w / 2 - 0.85), d / 2 - 0.08, 0.45 + k * 0.75), mat=wood))
            parts.append(mk.cylinder("Knob", 0.06, 0.1, (sx * (w / 2 - 0.85), d / 2 - 0.02, 0.5 + k * 0.75), rot=(90, 0, 0),
                                     mat=brass, verts=8))
    parts += [mk.cylinder("LampBase", 0.3, 0.1, (-2.3, 0.6, h + 0.05), mat=brass, verts=16),
              mk.tube("LampStem", (-2.3, 0.6, h + 0.1), (-2.3, 0.6, h + 1.3), 0.05, mat=brass, verts=6),
              mk.cylinder("LampShade", 0.45, 1.3, (-2.3, 0.35, h + 1.45), rot=(0, 90, 0), mat=pk.plastic("Exec_Green", (24, 90, 56)),
                          verts=16),
              mk.box("PenStand", (0.7, 0.4, 0.2), (1.3, 0.8, h + 0.1), mat=brass, bevel=0.03),
              mk.tube("Pen", (1.2, 0.8, h + 0.2), (1.1, 0.7, h + 0.9), 0.03, mat=dark, verts=5),
              mk.box("Nameplate", (1.6, 0.35, 0.35), (0.6, -1.25, h + 0.17), rot=(-20, 0, 0), mat=brass, bevel=0.03),
              mk.box("Dossier", (1.2, 1.5, 0.12), (1.4, -0.2, h + 0.06), rot=(0, 0, -8), mat=folder)]
    glows = [mk.box("LampGlow", (1.1, 0.3, 0.05), (-2.3, 0.35, h + 1.2), mat=pk.glow("Exec_Bulb", LAMP_WARM, 3))]
    return parts, glows


@prop("WaterCooler", pivot="bottom", material="SmoothPlastic", collide=True, texture=512, set="Agency")
def water_cooler():
    """A water cooler: a white cabinet with its two taps and drip tray, the blue bottle upside
    down on top, a stack of paper cones at the side."""
    white = pk.plastic("Cool_White", (224, 226, 226))
    blue = mk.noisy("Cool_Blue", srgb(90, 150, 200), srgb(140, 190, 230), scale=4, roughness=0.1)
    dark = pk.metal("Cool_Dark", (40, 40, 44), (60, 60, 66), rough=0.5, metallic=0.2)
    parts = [mk.box("Cabinet", (1.2, 1.2, 3.4), (0, 0, 1.7), mat=white, bevel=0.08),
             mk.box("Recess", (0.8, 0.1, 0.9), (0, -0.58, 2.4), mat=dark),
             mk.box("Tray", (0.8, 0.3, 0.06), (0, -0.66, 1.98), mat=dark),
             mk.lathe("Bottle", [(0.0, 0.0), (0.18, 0.0), (0.2, 0.25), (0.52, 0.5), (0.55, 1.5), (0.45, 1.75), (0.0, 1.8)],
                      (0, 0, 3.4), mat=blue, segments=20),
             mk.cylinder("Cones", 0.12, 0.8, (0.68, 0, 2.6), mat=pk.plastic("Cool_Cones", (236, 234, 228)), verts=10)]
    glows = [mk.cylinder("Tap", 0.06, 0.14, (sx * 0.2, -0.62, 2.7), rot=(90, 0, 0),
                         mat=pk.glow("Cool_Tap", (80, 160, 255) if sx < 0 else (255, 80, 80), 3), verts=8)
             for sx in (-1, 1)]
    return parts, glows


@prop("Photocopier", pivot="bottom", material="SmoothPlastic", collide=True, texture=1024, set="Agency")
def photocopier():
    """A big office photocopier: the cabinet with its paper drawers, the glass lid, the output
    tray with copies in it, and the lit control panel."""
    grey = pk.plastic("Copy_Grey", (196, 196, 192))
    dark = pk.metal("Copy_Dark", (40, 42, 46), (60, 62, 68), rough=0.5, metallic=0.2)
    paper = pk.plastic("Copy_Paper", (238, 236, 228))
    parts = [mk.box("Body", (3.6, 2.4, 3.4), (0, 0, 1.7), mat=grey, bevel=0.1),
             mk.box("Lid", (3.0, 2.2, 0.2), (-0.2, 0, 3.5), mat=dark, bevel=0.04),
             mk.box("Panel", (1.2, 0.8, 0.2), (1.4, -0.9, 3.45), rot=(12, 0, 0), mat=dark, bevel=0.03),
             mk.box("OutTray", (1.3, 1.8, 0.1), (2.3, 0, 2.6), rot=(0, 8, 0), mat=grey),
             mk.box("Copies", (1.0, 1.4, 0.2), (2.3, 0, 2.72), rot=(0, 8, 0), mat=paper)]
    for k in range(3):
        parts.append(mk.box("Drawer", (3.2, 0.06, 0.7), (0, -1.22, 0.5 + k * 0.8), mat=grey))
        parts += pk.handle("Pull", 0, -1.24, 0.75 + k * 0.8, 1.6, dark, vertical=False, stand=0.06, r=0.03)
    parts += pk.feet("Foot", [(-1.5, -1.0), (1.5, -1.0), (-1.5, 1.0), (1.5, 1.0)], dark, r=0.12, h=0.1)
    glows = [mk.box("Screen", (0.6, 0.04, 0.35), (1.3, -1.32, 3.52), rot=(12, 0, 0), mat=pk.glow("Copy_Screen", (120, 220, 170), 2)),
             mk.box("Ready", (0.12, 0.04, 0.12), (1.85, -1.32, 3.52), rot=(12, 0, 0), mat=pk.glow("Copy_Ready", (80, 255, 120), 4))]
    return parts, glows


@prop("FaxMachine", pivot="bottom", material="SmoothPlastic", collide=False, texture=256, set="Agency")
def fax_machine():
    """A fax machine: the beige body, its handset, the paper feed with a curled fax coming out."""
    beige = pk.plastic("Fax_Beige", (190, 182, 162))
    dark = pk.metal("Fax_Dark", (30, 30, 34), (46, 46, 52), rough=0.5, metallic=0.2)
    paper = pk.plastic("Fax_Paper", (238, 236, 226))
    parts = [mk.box("Body", (1.5, 1.3, 0.45), (0, 0, 0.23), mat=beige, bevel=0.06),
             mk.box("Feed", (1.1, 0.3, 0.3), (0, 0.55, 0.55), rot=(-30, 0, 0), mat=beige, bevel=0.03),
             mk.box("Sheet", (0.9, 0.04, 0.8), (0, 0.72, 0.85), rot=(-25, 0, 0), mat=paper),
             pk.rounded("Handset", (0.3, 1.1, 0.2), (-0.62, 0, 0.52), dark, r=0.08),
             mk.box("Keys", (0.6, 0.4, 0.04), (0.35, -0.35, 0.47), mat=dark),
             mk.box("Curl", (0.9, 0.5, 0.03), (0, -0.85, 0.3), rot=(25, 0, 0), mat=paper)]
    glows = [mk.box("Lcd", (0.4, 0.2, 0.03), (0.35, -0.1, 0.47), mat=pk.glow("Fax_Lcd", (120, 220, 140), 2))]
    return parts, glows


@prop("DeskPhone", pivot="bottom", material="SmoothPlastic", collide=False, texture=256, set="Agency")
def desk_phone():
    """A heavy office desk phone: the body, its handset on the cradle, the keypad and line keys."""
    dark = pk.plastic("Dphone_Dark", (30, 30, 34))
    grey = pk.plastic("Dphone_Grey", (90, 92, 96))
    parts = [pk.rounded("Body", (0.9, 0.8, 0.28), (0, 0, 0.14), dark, r=0.06),
             pk.rounded("Handset", (0.85, 0.24, 0.2), (0, 0.18, 0.36), dark, r=0.09),
             mk.box("Keypad", (0.35, 0.3, 0.03), (0.18, -0.22, 0.29), mat=grey),
             mk.tube("Cord", (-0.45, 0.15, 0.15), (-0.55, 0.3, 0.02), 0.02, mat=dark, verts=4)]
    glows = [mk.box("Line", (0.08, 0.04, 0.03), (-0.3, -0.3, 0.29), mat=pk.glow("Dphone_Line", (255, 90, 60), 3))]
    return parts, glows


@prop("CoffeeMachine", pivot="bottom", material="Metal", collide=False, texture=256, set="Agency")
def coffee_machine():
    """A filter coffee machine with its glass jug half full on the lit warming plate."""
    black = pk.plastic("Cof_Black", (24, 24, 26))
    steel = pk.metal("Cof_Steel", (150, 152, 158), (190, 192, 198), rough=0.3, metallic=0.8)
    coffee = pk.plastic("Cof_Coffee", (40, 22, 12))
    parts = [mk.box("Tower", (1.0, 0.8, 1.7), (0, 0.3, 0.85), mat=black, bevel=0.06),
             mk.box("Head", (1.0, 1.3, 0.35), (0, -0.05, 1.55), mat=black, bevel=0.06),
             mk.box("Plate", (1.0, 1.1, 0.12), (0, -0.1, 0.06), mat=black, bevel=0.03),
             mk.cylinder("Jug", 0.36, 0.7, (0, -0.35, 0.47), mat=steel, verts=16),
             mk.cylinder("Coffee", 0.33, 0.35, (0, -0.35, 0.32), mat=coffee, verts=16),
             mk.box("Handle", (0.08, 0.3, 0.45), (0.45, -0.35, 0.5), mat=black)]
    glows = [mk.box("Power", (0.1, 0.04, 0.08), (0.35, -0.12, 1.45), mat=pk.glow("Cof_Power", (255, 60, 40), 4))]
    return parts, glows


@prop("CoatStand", pivot="bottom", material="Wood", collide=True, texture=512, set="Agency")
def coat_stand():
    """A bentwood coat stand with a trench coat and a fedora on its hooks and a wet umbrella
    leaning on its foot."""
    wood = mk.wood("Coat_Wood", srgb(86, 56, 34), srgb(44, 28, 16), scale=6)
    coat = mk.noisy("Coat_Coat", srgb(120, 100, 70), srgb(150, 128, 90), scale=12, roughness=0.8)
    hat = mk.noisy("Coat_Hat", srgb(30, 30, 32), srgb(44, 44, 48), scale=16, roughness=0.8)
    brolly = pk.plastic("Coat_Umbrella", (20, 20, 24))
    parts = [mk.cylinder("Pole", 0.1, 6.2, (0, 0, 3.1), mat=wood, verts=10),
             mk.cylinder("Top", 0.18, 0.2, (0, 0, 6.25), mat=wood, verts=10)]
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        parts.append(mk.tube("Leg", (0, 0, 0.9), (math.cos(a) * 0.9, math.sin(a) * 0.9, 0.02), 0.07, mat=wood, verts=6))
        parts.append(mk.tube("Hook", (0, 0, 5.8), (math.cos(a) * 0.45, math.sin(a) * 0.45, 6.0), 0.04, mat=wood, verts=5))
    parts += [mk.lathe("Coat", [(0.0, 0.0), (0.55, 0.0), (0.5, 2.4), (0.35, 3.0), (0.12, 3.25), (0.0, 3.3)], (0.0, -0.35, 2.55),
                       mat=coat, segments=14),
              mk.cylinder("HatBrim", 0.5, 0.05, (0.35, 0.25, 6.05), mat=hat, verts=18),
              mk.cylinder("HatCrown", 0.3, 0.35, (0.35, 0.25, 6.25), mat=hat, verts=14),
              mk.tube("Umbrella", (0.7, 0.4, 0.05), (0.4, 0.2, 3.1), 0.12, radius_end=0.05, mat=brolly, verts=8)]
    return parts, []


@prop("PinBoard", pivot="centre", material="Wood", collide=False, texture=1024, set="Agency")
def pin_board():
    """A cork board on a wall: a wooden frame, photographs, clippings and index cards pinned to it,
    and red string running between the pins. Faces -Y; the map hangs it by its middle."""
    wood = mk.wood("Pin_Wood", srgb(90, 60, 36), srgb(50, 32, 20), scale=5)
    cork = mk.noisy("Pin_Cork", srgb(150, 110, 70), srgb(180, 140, 96), scale=40, roughness=0.9)
    photo = pk.plastic("Pin_Photo", (60, 62, 66))
    paper = pk.plastic("Pin_Paper", (230, 224, 206))
    red = pk.plastic("Pin_Red", (190, 20, 30))
    w, h = 5.4, 3.4
    parts = [mk.box("Cork", (w, 0.12, h), (0, 0, 0), mat=cork)]
    parts += pk.frame("Frame", w + 0.3, h + 0.3, 0.18, 0.2, (0, -0.02, 0), wood)
    pins = [(-2.0, 1.0), (-0.6, 1.2), (0.9, 0.9), (2.0, 1.1), (-1.6, -0.4), (0.2, -0.1), (1.7, -0.6), (-0.4, -1.1)]
    for k, (px, pz) in enumerate(pins):
        mat = photo if k % 3 == 0 else paper
        size = (0.8, 0.02, 0.6) if k % 3 == 0 else (0.7, 0.02, 0.5)
        parts.append(mk.box("Note", size, (px, -0.08, pz - 0.1), rot=(0, (k * 23) % 14 - 7, 0), mat=mat))
        parts.append(mk.sphere("Pin", 0.06, (px, -0.14, pz + 0.12), mat=red, segments=6, rings=4))
    for a, b in ((0, 5), (5, 2), (1, 5), (5, 6), (4, 7), (3, 6)):
        pa, pb = pins[a], pins[b]
        parts.append(mk.tube("String", (pa[0], -0.15, pa[1] + 0.12), (pb[0], -0.15, pb[1] + 0.12), 0.015, mat=red, verts=4))
    return parts, []


@prop("Whiteboard", pivot="bottom", material="SmoothPlastic", collide=True, texture=1024, set="Agency")
def whiteboard():
    """A rolling whiteboard: an aluminium frame on castors, the board covered in a timeline, names
    struck through and arrows, the marker tray at its foot."""
    alu = pk.metal("Wb_Alu", (170, 172, 178), (206, 208, 212), rough=0.3, metallic=0.8)
    board = pk.plastic("Wb_Board", (236, 238, 238), rough=0.15)
    ink = pk.plastic("Wb_Ink", (30, 40, 70))
    red = pk.plastic("Wb_Red", (180, 30, 36))
    dark = pk.rubber("Wb_Rubber")
    w, h = 6.0, 3.6
    parts = [mk.box("Board", (w, 0.1, h), (0, 0, 4.2), mat=board)]
    parts += pk.frame("Frame", w + 0.2, h + 0.2, 0.12, 0.16, (0, 0, 4.2), alu)
    for sx in (-1, 1):
        parts += [mk.box("Leg", (0.12, 0.12, 6.0), (sx * (w / 2 + 0.1), 0, 3.0), mat=alu),
                  mk.box("Foot", (0.14, 2.0, 0.12), (sx * (w / 2 + 0.1), 0, 0.35), mat=alu)]
        for sy in (-1, 1):
            parts.append(mk.cylinder("Castor", 0.15, 0.12, (sx * (w / 2 + 0.1), sy * 0.9, 0.15), rot=(0, 90, 0), mat=dark,
                                     verts=10))
    parts.append(mk.box("Tray", (w * 0.6, 0.35, 0.08), (0, -0.2, 2.35), mat=alu))
    parts.append(mk.box("Timeline", (w - 0.8, 0.02, 0.05), (0, -0.07, 4.9), mat=ink))
    for k in range(6):
        x = -w / 2 + 0.7 + k * (w - 1.4) / 5
        parts.append(mk.box("Tick", (0.04, 0.02, 0.3), (x, -0.07, 4.9), mat=ink))
        parts.append(mk.box("Word", (0.6, 0.02, 0.07), (x, -0.07, 5.2 + (k % 2) * 0.2), mat=ink))
    for k in range(4):
        parts.append(mk.box("Name", (1.1, 0.02, 0.09), (-1.6 + k * 1.1, -0.07, 3.6 - (k % 2) * 0.4), mat=ink))
        if k % 2 == 0:
            parts.append(mk.box("Strike", (1.3, 0.02, 0.05), (-1.6 + k * 1.1, -0.08, 3.6 - (k % 2) * 0.4),
                                rot=(0, 8, 0), mat=red))
    parts.append(mk.torus("Circle", 0.45, 0.03, (1.9, -0.08, 3.4), rot=(90, 0, 0), mat=red, major_segments=16,
                          minor_segments=3))
    return parts, []


@prop("MicrofilmReader", pivot="bottom", material="SmoothPlastic", collide=True, texture=512, set="Agency")
def microfilm_reader():
    """A microfilm reader on its steel cabinet: the hooded screen showing a page of an old
    newspaper, the film carriers and the reels in a tray."""
    steel = pk.metal("Film_Steel", (90, 94, 100), (120, 124, 130), rough=0.45, metallic=0.5)
    beige = pk.plastic("Film_Beige", (180, 172, 150))
    dark = pk.metal("Film_Dark", (24, 24, 28), (40, 40, 46), rough=0.5, metallic=0.2)
    parts = [mk.box("Cabinet", (2.4, 2.4, 2.7), (0, 0, 1.35), mat=steel, bevel=0.04),
             mk.box("Base", (2.2, 2.0, 0.5), (0, 0.1, 2.95), mat=beige, bevel=0.06),
             mk.box("Hood", (2.2, 1.4, 1.9), (0, 0.4, 4.1), mat=beige, bevel=0.1),
             mk.box("Carrier", (1.4, 0.8, 0.15), (0, -0.6, 3.25), mat=dark, bevel=0.03)]
    for k in range(3):
        parts.append(mk.cylinder("Reel", 0.28, 0.12, (-0.7 + k * 0.7, -0.9, 2.78), mat=dark, verts=14))
    glows = [mk.box("Page", (1.6, 0.04, 1.3), (0, -0.32, 4.15), rot=(-8, 0, 0), mat=pk.glow("Film_Page", (220, 214, 190), 1.6))]
    return parts, glows


@prop("FumeHood", pivot="bottom", material="SmoothPlastic", collide=True, texture=1024, set="Agency",
      lights=[dict(at=(0, -0.3, 6.6), kind="point", color=(220, 236, 255), range=10, brightness=0.8)])
def fume_hood():
    """A lab fume hood: a white cabinet base, the black resin work top inside a steel box with a
    raised glass sash, the lit panel in its roof, the extract duct rising out of the top."""
    white = pk.plastic("Hood_White", (228, 230, 230))
    steel = pk.metal("Hood_Steel", (170, 174, 180), (206, 210, 214), rough=0.3, metallic=0.7)
    resin = mk.noisy("Hood_Resin", srgb(18, 18, 20), srgb(34, 34, 38), scale=10, roughness=0.25)
    glass = pk.dark_glass("Hood_Glass", (70, 90, 100))
    dark = pk.metal("Hood_Dark", (24, 24, 28), (40, 40, 46), rough=0.5, metallic=0.3)
    w, d = 5.2, 2.6
    parts = [mk.box("Base", (w, d, 2.8), (0, 0, 1.4), mat=white, bevel=0.03),
             mk.box("Top", (w + 0.1, d + 0.1, 0.14), (0, 0, 2.87), mat=resin),
             mk.box("Back", (w, 0.12, 4.4), (0, d / 2 - 0.06, 5.1), mat=steel),
             mk.box("Roof", (w, d, 0.6), (0, 0, 7.3), mat=steel, bevel=0.03),
             mk.box("Sash", (w - 0.4, 0.06, 1.6), (0, -d / 2 + 0.1, 6.0), mat=glass),
             mk.box("SashBar", (w - 0.4, 0.14, 0.14), (0, -d / 2 + 0.05, 5.2), mat=steel),
             mk.cylinder("Duct", 0.5, 1.4, (0, 0.2, 8.3), mat=steel, verts=16)]
    for sx in (-1, 1):
        parts.append(mk.box("Side", (0.12, d, 4.4), (sx * (w / 2 - 0.06), 0, 5.1), mat=steel))
    for k in range(3):
        parts.append(mk.box("Door", (1.55, 0.04, 2.3), (-1.65 + k * 1.65, -d / 2 - 0.01, 1.35), mat=white))
        parts += pk.handle("Pull", -1.65 + k * 1.65 + 0.5, -d / 2 - 0.02, 2.0, 0.5, dark, stand=0.07, r=0.03)
    for k in range(4):
        parts.append(mk.cylinder("Flask", 0.2, 0.6, (-1.6 + k * 0.9, 0.3, 3.24), mat=pk.plastic(f"Hood_Flask{k}",
                                                                                              ((180, 60, 40), (40, 120, 80),
                                                                                               (230, 230, 226), (60, 80, 150))[k]),
                                 verts=10, radius2=0.08))
    glows = [mk.box("Panel", (w - 0.6, d - 0.6, 0.04), (0, 0, 6.98), mat=pk.glow("Hood_Panel", (220, 236, 255), 2.4))]
    return parts, glows
