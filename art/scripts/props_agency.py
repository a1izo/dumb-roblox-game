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
import random

import modelkit as mk
import propkit as pk
import stationkit as sk
from common import srgb
from props import prop

LAMP_WARM = (255, 214, 160)


# Station looks -----------------------------------------------------------------------------------------

CRT_SCREEN = (0.0, -0.1, 4.25, 2.4, 1.8, 4)


@prop("StationCRTBank", pivot="bottom", material="Metal", collide=False, texture=1024, set="Agency", anchor=(0, 0),
      screen=CRT_SCREEN)
def station_crt_bank():
    """The security office's monitor console: a grey steel desk and, on a steel rack standing behind
    it, two shelves of CRT monitors showing camera feeds; the big one on the desk is the game's
    screen. On the desk the keyboard, the switcher with its lit buttons, a camera joystick, a pair of
    tape recorders with their cassettes, the tape log, and a mug."""
    rng = random.Random(61)
    steel = pk.paint("Crt_Steel", (96, 98, 102), rough=0.45)
    top = pk.plastic("Crt_Resin", (64, 66, 70), rough=0.5)
    trim = pk.metal("Crt_Trim", (30, 30, 34), (48, 48, 52), rough=0.4, metallic=0.5)
    beige = pk.plastic("Crt_Plastic", (184, 176, 156))
    bezel = pk.plastic("Crt_Bezel", (64, 62, 58))
    dark = pk.plastic("Crt_Dark", (24, 24, 26))
    key = pk.plastic("Crt_Button", (210, 204, 188))
    paper = mk.noisy("Crt_Paper", srgb(214, 208, 190), srgb(236, 230, 214), roughness=0.9)
    cover = pk.plastic("Crt_Cover", (30, 60, 50))
    ink = mk.flat("Crt_Ink", srgb(28, 28, 40), 0.6)
    mugm = pk.plastic("Crt_Mug", (150, 30, 36))
    coffee = mk.flat("Crt_Coffee", srgb(40, 24, 14), 0.1)
    parts = sk.steel_desk("Crt_", top, steel, trim, w=5.2, d=2.6, h=2.95, pedestal=1.5)
    main, glows = sk.crt("Main_", CRT_SCREEN, beige, bezel, dark, depth=2.0, base_to=2.95, border=0.18, chin=0.14)
    parts += main
    # The rack behind: four posts on the floor, two shelves cantilevered over the desk.
    for sx in (-1, 1):
        parts += [pk.rounded("RackPost", (0.16, 0.16, 8.7), (sx * 2.5, 1.75, 4.35), steel, r=0.03),
                  mk.box("RackFoot", (0.2, 0.5, 0.06), (sx * 2.5, 1.75, 0.03), mat=trim, bevel=0.01),
                  mk.box("RackArm", (0.1, 1.5, 0.1), (sx * 2.45, 1.05, 5.58), mat=steel),
                  mk.box("RackArm", (0.1, 1.5, 0.1), (sx * 2.45, 1.05, 7.23), mat=steel)]
    for zz in (5.68, 7.33):
        parts += [mk.box("RackShelf", (5.0, 1.6, 0.08), (0, 1.25, zz - 0.03), mat=steel, bevel=0.01),
                  mk.box("ShelfLip", (5.0, 0.04, 0.1), (0, 0.46, zz - 0.04), mat=steel)]
    parts.append(mk.box("RackTop", (5.16, 0.2, 0.12), (0, 1.75, 8.64), mat=steel, bevel=0.02))
    colours = [(110, 150, 130), (120, 140, 170), (160, 156, 110), (100, 130, 160), (140, 160, 120), (170, 140, 120)]
    k = 0
    for zz in (6.45, 8.1):
        for col in range(3):
            fx = -1.62 + col * 1.62
            slot = (fx, 0.6, zz, 1.2, 0.9, 0)
            mon, led = sk.crt(f"Feed{k}_", slot, beige, bezel, dark, depth=1.3, base_to=zz - 0.76, border=0.14, chin=0.1)
            parts += mon
            glows += led
            glows.append(mk.box(f"FeedLit{k}", (1.2, 0.02, 0.9), (fx, 0.51, zz), mat=pk.glow(f"Crt_Feed{k}", colours[k], 1.8)))
            parts += [mk.box(f"FeedKerb{k}", (1.2, 0.006, 0.05), (fx, 0.498, zz - 0.18), rot=(0, rng.uniform(-15, 15), 0), mat=dark),
                      mk.box(f"FeedPost{k}", (0.08, 0.006, 0.5), (fx + rng.uniform(-0.4, 0.4), 0.498, zz + 0.05), mat=dark),
                      mk.box(f"FeedTime{k}", (0.4, 0.006, 0.05), (fx - 0.33, 0.498, zz + 0.36), mat=dark)]
            parts += pk.label(f"FeedNo{k}", f"CAM {k + 1:02d}", 0.06, (fx + 0.45, 0.455, zz - 0.52), key)
            k += 1
    parts.append(sk.cable("RackLoom", [(-2.3, 1.95, 8.4), (-2.35, 2.0, 5.0), (-2.3, 1.95, 0.3)], dark, r=0.06))
    # The keyboard, the switcher, the joystick.
    parts += sk.keyboard("Kb_", -0.2, -0.85, 2.95, beige, key, w=2.0, d=0.66)
    sw = [sk.wedge("Switcher", [(-0.38, 0.0), (0.38, 0.0), (0.38, 0.24), (-0.38, 0.12)], 1.3, 0, dark, bevel=0.03)]
    sw[0].location = (1.85, -0.7, 2.95)
    parts += sw
    for i in range(8):
        bx, by = 1.4 + (i % 4) * 0.3, -0.85 + (i // 4) * 0.3
        bz = 2.95 + 0.14 + (by + 0.7 + 0.38) / 0.76 * 0.1
        glows.append(mk.box("Button", (0.18, 0.18, 0.05), (bx, by, bz), rot=(-9, 0, 0),
                            mat=pk.glow("Crt_Button", (255, 170, 60) if i in (2, 5) else (120, 255, 150), 2.5)))
    parts += [mk.lathe("JoyBoot", [(0.12, 0.0), (0.1, 0.04), (0.06, 0.1), (0.035, 0.16), (0.0, 0.16)], (-2.0, -0.7, 3.05),
                       mat=pk.rubber("Crt_Rubber"), segments=12),
              pk.rounded("JoyBase", (0.6, 0.6, 0.1), (-2.0, -0.7, 3.0), dark, r=0.03),
              mk.tube("Stick", (-2.0, -0.7, 3.18), (-2.0, -0.72, 3.55), 0.03, mat=trim, verts=8),
              mk.sphere("Grip", 1.0, (-2.0, -0.72, 3.62), scale=(0.07, 0.07, 0.1), mat=dark, segments=10, rings=6)]
    # Two cassette recorders stacked at the back right, tapes beside them.
    for k in range(2):
        rz = 2.95 + k * 0.36
        parts += [pk.rounded(f"Deck{k}", (1.1, 0.8, 0.34), (1.95, 0.8, rz + 0.17), dark, r=0.03),
                  mk.box(f"DeckDoor{k}", (0.5, 0.02, 0.2), (1.8, 0.395, rz + 0.18), mat=trim),
                  mk.box(f"DeckWindow{k}", (0.3, 0.01, 0.08), (1.8, 0.383, rz + 0.2), mat=paper)]
        for j in range(4):
            parts.append(mk.box(f"DeckKey{k}", (0.08, 0.04, 0.05), (2.2 + j * 0.09, 0.39, rz + 0.12), mat=key))
        glows.append(mk.box(f"DeckRec{k}", (0.04, 0.02, 0.04), (2.3, 0.39, rz + 0.25), mat=pk.glow("Crt_Rec", (255, 60, 50), 4)))
    for k in range(3):
        parts.append(pk.rounded(f"Cassette{k}", (0.42, 0.28, 0.06), (1.75 + rng.uniform(-0.04, 0.04), -0.1 + k * 0.02, 2.98 + k * 0.065),
                                mat=dark if k % 2 else paper, r=0.01, rot=(0, 0, rng.uniform(-10, 10))))
    parts += sk.open_book("Log_", -1.95, 0.25, 2.95, cover, paper, ink, rng, yaw=-8, w=1.0, d=0.7)
    parts += sk.pen("Pen_", (-1.75, 0.0, 3.05), (-1.5, 0.2, 3.05), ink, trim)
    parts += sk.mug("Mug_", -2.25, 0.95, 2.95, mugm, coffee, handle_yaw=200)
    return parts, glows


PHONE_DESK_SCREEN = (-0.6, 0.15, 4.2, 2.1, 1.6, 6)


@prop("StationPhoneDesk", pivot="bottom", material="Wood", collide=False, texture=1024, set="Agency", anchor=(0, 0),
      screen=PHONE_DESK_SCREEN)
def station_phone_desk():
    """A detective's desk on the phone-records beat: a worn wooden desk with turned legs, its drawer
    pedestal and a leather blotter, the beige records terminal (the game's screen) with its
    keyboard, a multi-line desk phone with lit line lamps, a dot-matrix printer spilling its call
    log over the back, a card index, case folders, a green banker's lamp, a mug and a notepad."""
    rng = random.Random(67)
    wood = mk.wood("PDesk_Wood", srgb(104, 70, 44), srgb(58, 38, 24), scale=4)
    top = mk.wood("PDesk_Oak", srgb(92, 62, 40), srgb(52, 34, 22), scale=4)
    leather = mk.noisy("PDesk_Leather", srgb(30, 48, 40), srgb(48, 68, 58), roughness=0.6)
    beige = pk.plastic("PDesk_Plastic", (186, 176, 154))
    bezel = pk.plastic("PDesk_Bezel", (70, 66, 60))
    dark = pk.plastic("PDesk_Dark", (22, 22, 24))
    key = pk.plastic("PDesk_Button", (214, 206, 188))
    brass = pk.metal("PDesk_Brass", (150, 118, 60), (200, 164, 90), rough=0.3, metallic=0.9)
    paper = mk.noisy("PDesk_Paper", srgb(222, 218, 202), srgb(240, 236, 222), roughness=0.9)
    folder = mk.noisy("PDesk_Folder", srgb(168, 136, 86), srgb(196, 164, 110), roughness=0.8)
    ink = mk.flat("PDesk_Ink", srgb(26, 24, 30), 0.6)
    green = pk.plastic("PDesk_Green", (24, 90, 60), rough=0.15)
    mugm = pk.plastic("PDesk_Mug", (226, 222, 210))
    coffee = mk.flat("PDesk_Coffee", srgb(40, 24, 14), 0.1)
    x, y, z, w, h, tilt = PHONE_DESK_SCREEN
    parts = sk.wood_desk("PDesk_", wood, top, brass, w=5.2, d=2.6, h=2.95, pedestal=1.5, blotter=leather)
    term, glows = sk.crt("Term_", PHONE_DESK_SCREEN, beige, bezel, dark, depth=1.9, base_to=2.97, border=0.2, chin=0.14)
    parts += term
    parts += sk.keyboard("Kb_", x, -0.85, 2.97, beige, key, w=2.0, d=0.66)
    ph, lines = sk.desk_phone("Ph_", 1.6, -0.35, 2.97, dark, key, dark, yaw=-12, lines=5)
    parts += ph
    glows += lines
    # The printer at the back right, its paper fed from a box under the desk and the log spilling back.
    parts += [pk.rounded("Printer", (1.3, 0.9, 0.42), (1.6, 0.75, 3.18), beige, r=0.05),
              mk.box("PrinterLid", (1.0, 0.5, 0.04), (1.6, 0.85, 3.41), rot=(-8, 0, 0), mat=pk.plastic("PDesk_Smoke", (90, 80, 70))),
              mk.cylinder("Platen", 0.06, 1.1, (1.6, 1.2, 3.38), rot=(0, 90, 0), mat=dark, verts=10),
              mk.box("PrinterKnob", (0.05, 0.12, 0.12), (2.27, 1.1, 3.3), mat=dark)]
    glows.append(mk.box("PrinterLed", (0.05, 0.02, 0.03), (1.1, 0.29, 3.25), mat=pk.glow("PDesk_Led", (120, 255, 150), 4)))
    log = [(1.6, 1.22, 3.45), (1.6, 1.4, 3.3), (1.6, 1.5, 2.9), (1.6, 1.55, 2.2), (1.6, 1.62, 1.4)]
    for a, b in zip(log, log[1:]):
        mid = tuple((p + q) / 2 for p, q in zip(a, b))
        run = math.dist(a, b)
        ang = math.degrees(math.atan2(b[1] - a[1], -(b[2] - a[2])))
        parts.append(mk.box("Log", (1.0, 0.012, run + 0.02), mid, rot=(-ang, 0, 0), mat=paper))
    parts += [mk.box("LogPile", (1.0, 0.7, 0.3), (1.6, 1.9, 0.15), rot=(0, 0, 4), mat=paper)]
    for k in range(6):
        parts.append(mk.box("LogFold", (1.0, 0.012, 0.7), (1.6, 1.9, 0.32 + k * 0.012), rot=(90, 0, 4), mat=paper))
    # The card index, case folders, notepad, the mug and the banker's lamp.
    parts += [pk.rounded("CardIndex", (0.7, 0.6, 0.42), (-2.2, 0.25, 3.18), dark, r=0.03),
              mk.box("IndexCards", (0.6, 0.5, 0.12), (-2.2, 0.25, 3.43), mat=paper),
              mk.box("IndexTab", (0.6, 0.03, 0.18), (-2.2, 0.1, 3.48), mat=folder)]
    for k in range(3):
        parts += sk.folder(f"Case{k}_", -2.08 + rng.uniform(-0.03, 0.03), -0.65, 2.97 + k * 0.09, folder, paper,
                           yaw=rng.uniform(-5, 5), tab=pk.plastic(f"PDesk_Tab{k}", ((200, 40, 40), (40, 90, 160), (220, 180, 60))[k]))
    parts += sk.papers("Pad_", 0.75, -0.75, 2.97, paper, rng, n=2, w=0.6, d=0.85)
    parts += sk.written("PadInk", 0.75, -0.75, 3.0, ink, rng, lines=5, w=0.45, d=0.7)
    parts += sk.pen("Pen_", (0.95, -1.05, 3.0), (1.05, -0.65, 3.0), ink, brass)
    parts += sk.mug("Mug_", 2.25, -0.05, 2.97, mugm, coffee, handle_yaw=-40)
    lx, ly = -2.2, 1.0
    parts += [mk.lathe("LampBase", [(0.0, 0.0), (0.32, 0.0), (0.32, 0.05), (0.12, 0.12), (0.0, 0.12)], (lx, ly, 2.97), mat=brass,
                       segments=18),
              mk.tube("LampStem", (lx, ly, 3.08), (lx, ly - 0.05, 3.95), 0.035, mat=brass, verts=8),
              mk.tube("LampYoke", (lx - 0.2, ly - 0.05, 4.0), (lx + 0.25, ly - 0.05, 4.0), 0.02, mat=brass, verts=6),
              mk.lathe("LampShade", [(0.2, 0.18), (0.2, 0.02), (0.15, -0.02), (0.0, -0.02)], (lx, ly - 0.15, 4.12), mat=green,
                       segments=16)]
    parts[-1].scale = (2.0, 1.0, 1.0)
    glows.append(mk.box("LampBulb", (0.5, 0.18, 0.03), (lx, ly - 0.15, 4.11), mat=pk.glow("PDesk_Bulb", LAMP_WARM, 3)))
    parts += [mk.tube("LampChain", (lx + 0.15, ly - 0.3, 4.12), (lx + 0.15, ly - 0.34, 3.85), 0.008, mat=brass, verts=4)]
    return parts, glows


REEL_SCREEN = (-1.25, -0.1, 3.9, 1.8, 1.3, 10)


def reel(prefix, x, y, z, r, flange, hub, tape, wound):
    """A tape reel facing -Y at (x, y, z): two flanges with three windows each, the hub, and the
    tape wound round it out to `wound` of the radius."""
    parts = [mk.cylinder(prefix + "Tape", r * wound, 0.07, (x, y + 0.02, z), rot=(90, 0, 0), mat=tape, verts=24),
             mk.cylinder(prefix + "Hub", r * 0.18, 0.14, (x, y - 0.02, z), rot=(90, 0, 0), mat=hub, verts=12)]
    for k in range(3):
        a = math.radians(90 + k * 120)
        parts.append(mk.tube(prefix + "Spoke", (x + math.cos(a) * r * 0.17, y - 0.03, z + math.sin(a) * r * 0.17),
                             (x + math.cos(a) * r * 0.95, y - 0.03, z + math.sin(a) * r * 0.95), r * 0.11, mat=flange, verts=6))
    parts += [mk.torus(prefix + "Rim", r * 0.96, 0.025, (x, y - 0.03, z), rot=(90, 0, 0), mat=flange, major_segments=28,
                       minor_segments=4),
              mk.torus(prefix + "RimBack", r * 0.96, 0.025, (x, y + 0.07, z), rot=(90, 0, 0), mat=flange, major_segments=28,
                       minor_segments=4)]
    return parts


@prop("StationReelToReel", pivot="bottom", material="Metal", collide=False, texture=1024, set="Agency", anchor=(0, 0),
      screen=REEL_SCREEN)
def station_reel_to_reel():
    """The wiretap console behind the one-way mirror: a steel desk, the small monitor showing the
    line (the game's screen), and at its right a rack with the reel-to-reel recorder (two windowed
    reels, the tape run past its guide rollers and the head block, the transport keys) over a panel
    of lit VU meters with their needles and knobs. Headphones on their cord, a microphone on its
    stand, the tape log, spare tape boxes."""
    rng = random.Random(71)
    steel = pk.paint("Reel_Steel", (86, 88, 94), rough=0.45)
    top = pk.plastic("Reel_Resin", (56, 58, 62), rough=0.5)
    trim = pk.metal("Reel_Trim", (30, 30, 34), (48, 48, 52), rough=0.4, metallic=0.5)
    alu = pk.metal("Reel_Alu", (170, 174, 180), (206, 210, 216), rough=0.25, metallic=0.9)
    dark = pk.plastic("Reel_Dark", (22, 22, 24))
    key = pk.plastic("Reel_Button", (200, 200, 196))
    tape = pk.plastic("Reel_Tape", (60, 38, 24), rough=0.3)
    paper = mk.noisy("Reel_Paper", srgb(222, 218, 202), srgb(240, 236, 222), roughness=0.9)
    card = mk.noisy("Reel_Card", srgb(150, 120, 80), srgb(180, 150, 104), roughness=0.8)
    ink = mk.flat("Reel_Ink", srgb(26, 24, 30), 0.6)
    cover = pk.plastic("Reel_Cover", (110, 30, 30))
    parts = sk.steel_desk("Reel_", top, steel, trim, w=5.2, d=2.6, h=2.95, pedestal=1.5)
    scope, glows = sk.crt("Scope_", REEL_SCREEN, steel, dark, dark, depth=1.5, base_to=2.95, border=0.14, chin=0.12)
    parts += scope
    # The rack at the right on the desk top.
    rx, front = 1.45, -0.55
    parts += [mk.box("Rack", (2.2, 1.7, 4.5), (rx, front + 0.85, 5.2), mat=steel, bevel=0.03),
              mk.box("DeckFace", (2.02, 0.04, 2.45), (rx, front - 0.02, 6.05), mat=alu, bevel=0.01),
              mk.box("MeterFace", (2.02, 0.04, 1.3), (rx, front - 0.02, 4.1), mat=dark, bevel=0.01),
              mk.box("PatchFace", (2.02, 0.04, 0.6), (rx, front - 0.02, 3.25), mat=dark, bevel=0.01)]
    for sx in (-1, 1):
        parts += [mk.box("RackEar", (0.1, 0.03, 4.4), (rx + sx * 1.05, front - 0.035, 5.2), mat=trim)]
        parts += sk.screws("RackScrew", [(rx + sx * 1.05, front - 0.05, zz) for zz in (3.2, 4.1, 5.2, 6.3, 7.2)], alu, r=0.025)
    # The recorder: reels, guides, heads, keys.
    for sx in (-1, 1):
        parts += reel(f"Reel{sx}_", rx + sx * 0.5, front - 0.1, 6.65, 0.46, alu, dark, tape, 0.72 if sx < 0 else 0.45)
    parts += [mk.cylinder("GuideL", 0.06, 0.12, (rx - 0.45, front - 0.08, 5.95), rot=(90, 0, 0), mat=alu, verts=10),
              mk.cylinder("GuideR", 0.06, 0.12, (rx + 0.45, front - 0.08, 5.95), rot=(90, 0, 0), mat=alu, verts=10),
              pk.rounded("HeadBlock", (0.6, 0.14, 0.26), (rx, front - 0.08, 5.92), dark, r=0.03),
              mk.box("TapeRunL", (0.012, 0.02, 0.5), (rx - 0.82, front - 0.1, 6.2), rot=(0, -40, 0), mat=tape),
              mk.box("TapeRun", (0.9, 0.02, 0.06), (rx, front - 0.155, 5.92), mat=tape),
              mk.box("TapeRunR", (0.012, 0.02, 0.5), (rx + 0.75, front - 0.1, 6.2), rot=(0, 35, 0), mat=tape)]
    for k in range(5):
        parts.append(mk.box("Transport", (0.22, 0.08, 0.14), (rx - 0.5 + k * 0.25, front - 0.06, 5.45), mat=key, bevel=0.015))
    for k in range(2):
        mx = rx - 0.48 + k * 0.96
        glows.append(mk.box(f"Meter{k}", (0.78, 0.02, 0.5), (mx, front - 0.045, 4.25), mat=pk.glow("Reel_Meter", (255, 196, 110), 2.2)))
        parts += [mk.box(f"MeterRim{k}", (0.86, 0.05, 0.58), (mx, front - 0.02, 4.25), mat=trim),
                  mk.box(f"Needle{k}", (0.012, 0.006, 0.42), (mx - 0.06 + k * 0.1, front - 0.058, 4.18), rot=(0, (-25, 18)[k], 0),
                         mat=dark),
                  mk.box(f"MeterRed{k}", (0.2, 0.006, 0.03), (mx + 0.24, front - 0.058, 4.42), mat=pk.plastic("Reel_Red", (190, 30, 30)))]
    for k in range(6):
        parts.append(mk.cylinder("Knob", 0.07, 0.08, (rx - 0.8 + k * 0.32, front - 0.08, 3.7), rot=(90, 0, 0), mat=alu, verts=12))
    for k in range(8):
        parts.append(mk.cylinder("Jack", 0.03, 0.04, (rx - 0.85 + k * 0.24, front - 0.06, 3.25), rot=(90, 0, 0), mat=alu, verts=8))
    parts.append(sk.cable("Patch", [(rx - 0.61, front - 0.08, 3.25), (rx - 0.3, front - 0.22, 3.05), (rx + 0.11, front - 0.08, 3.25)],
                          pk.plastic("Reel_PatchRed", (170, 30, 30)), r=0.018, sides=5))
    glows.append(mk.box("RecLamp", (0.1, 0.02, 0.1), (rx + 0.8, front - 0.05, 5.45), mat=pk.glow("Reel_Rec", (255, 50, 50), 5)))
    # Headphones, microphone, the log, tape boxes.
    hx, hy = -0.2, -0.75
    parts += [pk.sweep("Band", [(hx - 0.32, hy, 3.02), (hx - 0.3, hy + 0.1, 3.14), (hx, hy + 0.2, 3.2), (hx + 0.3, hy + 0.1, 3.14),
                                (hx + 0.32, hy, 3.02)], 0.03, dark, sides=6),
              mk.cylinder("Cup", 0.17, 0.12, (hx - 0.35, hy - 0.05, 3.01), mat=dark, verts=14, bevel=0.03),
              mk.cylinder("Cup", 0.17, 0.12, (hx + 0.35, hy - 0.05, 3.01), mat=dark, verts=14, bevel=0.03),
              sk.cable("PhoneCord", [(hx + 0.4, hy, 3.0), (0.4, -0.3, 2.97), (rx - 0.85, front - 0.08, 3.25)], dark, r=0.015, sides=4)]
    parts += [mk.cylinder("MicBase", 0.18, 0.06, (-2.4, -0.75, 2.98), mat=dark, verts=14, bevel=0.02),
              mk.tube("MicStem", (-2.4, -0.75, 3.0), (-2.38, -0.85, 3.55), 0.025, mat=alu, verts=6),
              mk.lathe("Mic", [(0.0, 0.0), (0.06, 0.02), (0.08, 0.25), (0.07, 0.3), (0.0, 0.32)], (-2.37, -0.9, 3.55), mat=alu, segments=12)]
    parts += sk.open_book("Log_", -1.3, -0.8, 2.95, cover, paper, ink, rng, yaw=8, w=1.0, d=0.66)
    parts += sk.pen("Pen_", (-0.9, -1.15, 2.98), (-0.62, -0.95, 2.98), ink, alu)
    for k in range(3):
        parts.append(pk.rounded(f"TapeBox{k}", (0.48, 0.48, 0.1), (0.06, 0.7, 3.0 + k * 0.105), card, r=0.01,
                                rot=(0, 0, rng.uniform(-3, 3))))
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
             mk.box("Head", (6.2, 0.5, 0.62), (0, 0.0, 9.31), mat=stone, bevel=0.05)]
    for sx in (-1, 1):
        parts += [mk.box("Leaf", (2.05, 0.12, 8.0), (sx * 1.05, -0.02, 4.0), mat=steel, bevel=0.01),
                  mk.box("Jamb", (0.2, 0.4, 8.2), (sx * 2.25, -0.05, 4.1), mat=steel, bevel=0.02)]
    parts += [mk.box("Seam", (0.03, 0.14, 8.0), (0, -0.05, 4.0), mat=dark),
              mk.box("Sill", (4.6, 0.6, 0.06), (0, -0.2, 0.03), mat=steel),
              mk.box("IndicatorBox", (2.2, 0.2, 0.7), (0, -0.15, 8.75), mat=dark, bevel=0.03),
              mk.box("ButtonPlate", (0.5, 0.12, 1.2), (2.85, -0.005, 4.2), mat=steel, bevel=0.02)]
    glows = [mk.box("Floor", (1.4, 0.04, 0.4), (0, -0.27, 8.75), mat=pk.glow("Lift_Floor", (255, 150, 60), 3)),
             mk.cylinder("Call", 0.1, 0.05, (2.85, -0.13, 4.45), rot=(90, 0, 0), mat=pk.glow("Lift_Call", (255, 244, 220), 3),
                         verts=12),
             mk.cylinder("Call", 0.1, 0.05, (2.85, -0.13, 3.95), rot=(90, 0, 0), mat=pk.glow("Lift_Call", (255, 244, 220), 3),
                         verts=12)]
    return parts, glows


@prop("MetalDetector", pivot="bottom", material="SmoothPlastic", collide=False, texture=512, set="Agency")
def metal_detector():
    """A walk-through metal detector: two grey panels joined by a head with its lit status bar, a column of zone
    lights down each panel's inner edge, the control box with its readout and keys on the head, a rubber mat
    through it. People walk through it (the map puts colliders on its sides)."""
    grey = pk.plastic("Det_Grey", (170, 172, 176))
    dark = pk.metal("Det_Dark", (30, 30, 34), (46, 46, 52), rough=0.5, metallic=0.2)
    rubber = pk.rubber("Det_Mat")
    parts = [mk.box("Mat", (3.2, 3.2, 0.06), (0, 0, 0.03), mat=rubber, bevel=0.02)]  # (the floor mat through it)
    for sx in (-1, 1):
        parts += [mk.box("Panel", (0.35, 2.0, 7.2), (sx * 1.75, 0, 3.6), mat=grey, bevel=0.08),
                  mk.box("Foot", (0.6, 2.2, 0.2), (sx * 1.75, 0, 0.1), mat=dark, bevel=0.04),
                  # the strip down each panel's inner edge where its zone lights sit
                  mk.box("ZoneStrip", (0.06, 0.22, 6.2), (sx * 1.56, -0.86, 3.7), mat=dark)]
    parts.append(mk.box("Head", (3.9, 2.0, 0.6), (0, 0, 7.5), mat=grey, bevel=0.1))
    parts.append(mk.box("HeadFace", (2.6, 0.06, 0.35), (0, -1.02, 7.5), mat=dark))
    # the control box on the head: its small readout, its keypad
    parts += [pk.rounded("Control", (1.2, 0.8, 0.5), (1.1, -0.3, 8.04), dark, r=0.06),
              mk.box("Keys", (0.5, 0.05, 0.24), (1.3, -0.72, 8.04), mat=grey)]
    glows = [mk.box("Status", (2.2, 0.04, 0.12), (0, -1.06, 7.5), mat=pk.glow("Det_Status", (90, 255, 140), 3)),
             mk.box("Readout", (0.4, 0.04, 0.18), (0.8, -0.72, 8.06), mat=pk.glow("Det_Readout", (255, 170, 60), 2.5))]
    # the zone lights, a column down each inner edge (green: clear)
    for sx in (-1, 1):
        for k in range(8):
            glows.append(mk.box("Zone", (0.04, 0.12, 0.42), (sx * 1.52, -0.86, 1.2 + k * 0.72),
                                mat=pk.glow("Det_Zone", (90, 255, 140), 2.2)))
    return parts, glows


# The interrogation rooms, the archive and the evidence lock-up -----------------------------------------


@prop("InterrogationTable", pivot="bottom", material="Metal", collide=True, texture=512, set="Agency")
def interrogation_table():
    """A bolted-down steel table: a scuffed top with a rolled edge on its apron, square legs braced low between
    them, each foot's plate bolted to the floor; the cuff bar welded to the middle of the top on its plate; a paper
    cup, a closed case file with a pen on it, an ashtray with two stubbed-out ends."""
    steel = pk.metal("Int_Steel", (90, 92, 98), (124, 126, 132), rough=0.5, metallic=0.6)
    dark = pk.metal("Int_Dark", (26, 26, 30), (40, 40, 46), rough=0.5, metallic=0.3)
    folder = pk.plastic("Int_Folder", (170, 140, 90))
    cup = pk.plastic("Int_Cup", (226, 222, 212))
    glass = pk.metal("Int_Ashtray", (120, 126, 130), (160, 166, 170), rough=0.1, metallic=0.2)
    ash = pk.plastic("Int_Ash", (70, 68, 66))
    butt = pk.plastic("Int_Butt", (220, 200, 160))
    parts = [mk.box("Top", (4.4, 2.8, 0.14), (0, 0, 2.6), mat=steel, bevel=0.03),
             mk.box("Apron", (4.2, 2.6, 0.3), (0, 0, 2.38), mat=steel)]
    for sx in (-1, 1):
        parts.append(mk.tube("Edge", (sx * 2.2, -1.4, 2.6), (sx * 2.2, 1.4, 2.6), 0.08, mat=steel, verts=8))
        for sy in (-1, 1):
            parts += [mk.box("Leg", (0.16, 0.16, 2.3), (sx * 1.95, sy * 1.15, 1.15), mat=steel),
                      mk.box("Plate", (0.5, 0.5, 0.04), (sx * 1.95, sy * 1.15, 0.02), mat=dark)]
            for bx in (-1, 1):
                for by in (-1, 1):
                    parts.append(mk.cylinder("Bolt", 0.035, 0.04, (sx * 1.95 + bx * 0.17, sy * 1.15 + by * 0.17, 0.06),
                                             mat=dark, verts=6))
        # the braces low between the legs, along the ends and down the length
        parts.append(mk.box("BraceEnd", (0.08, 2.3, 0.1), (sx * 1.95, 0, 0.5), mat=steel))
    parts.append(mk.box("BraceLong", (3.9, 0.08, 0.1), (0, 0, 0.5), mat=steel))
    for sx in (-1, 1):
        parts.append(mk.box("BraceFoot", (0.1, 0.1, 0.1), (sx * 1.95, 0, 0.5), mat=steel))
    # the cuff bar on its welded plate
    parts += [mk.box("BarPlate", (0.7, 0.3, 0.03), (0, 0, 2.685), mat=dark),
              mk.tube("BarLeg", (-0.22, 0, 2.69), (-0.22, 0, 2.86), 0.035, mat=dark, verts=6),
              mk.tube("BarLeg", (0.22, 0, 2.69), (0.22, 0, 2.86), 0.035, mat=dark, verts=6),
              mk.tube("Bar", (-0.25, 0, 2.86), (0.25, 0, 2.86), 0.035, mat=dark, verts=6),
              mk.box("Folder", (1.1, 1.4, 0.06), (1.2, -0.3, 2.7), rot=(0, 0, 12), mat=folder),
              mk.tube("Pen", (0.95, -0.55, 2.745), (1.45, -0.2, 2.745), 0.02, mat=dark, verts=6),
              mk.cylinder("Cup", 0.14, 0.34, (-1.4, 0.5, 2.84), mat=cup, verts=12, radius2=0.11),
              mk.lathe("Ashtray", [(0.0, 0.0), (0.28, 0.0), (0.3, 0.08), (0.24, 0.1), (0.2, 0.03), (0.0, 0.03)],
                       (-1.3, -0.6, 2.67), mat=glass, segments=16),
              mk.cylinder("Ash", 0.19, 0.02, (-1.3, -0.6, 2.71), mat=ash, verts=12)]
    for k, (dx, dy, rz) in enumerate(((-0.05, 0.04, 20), (0.08, -0.06, -35))):
        parts.append(mk.tube("Butt", (-1.3 + dx - 0.08, -0.6 + dy, 2.72), (-1.3 + dx + 0.12, -0.6 + dy + 0.03 * k, 2.75),
                             0.025, mat=butt, verts=6))
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
    parts = [mk.box("Base", (w - 0.04, d - 0.04, 0.35), (0, 0, 0.18), mat=paint, bevel=0.03),
             mk.box("Top", (w, d, 0.12), (0, 0, h - 0.06), mat=paint, bevel=0.02),
             mk.box("Spine", (w - 0.2, 0.08, h - 0.4), (0, 0, h / 2), mat=paint)]
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


@prop("WaterCooler", pivot="bottom", material="SmoothPlastic", collide=True, texture=512, set="Agency")
def water_cooler():
    """A water cooler: a white cabinet with rounded corners on four feet, a vent grille down its side; the dispensing
    bay set into its front, two lever taps in it (the cold one's cap blue, the hot one's red behind its child lock),
    a grated drip tray under them, a lamp over each tap; the blue bottle upside down in its collar on top, ribbed;
    a tube of paper cones on the side."""
    white = pk.plastic("Cool_White", (224, 226, 226))
    blue = mk.noisy("Cool_Blue", srgb(90, 150, 200), srgb(140, 190, 230), scale=4, roughness=0.1)
    dark = pk.metal("Cool_Dark", (40, 40, 44), (60, 60, 66), rough=0.5, metallic=0.2)
    grey = pk.plastic("Cool_Grey", (150, 152, 156))
    cones = pk.plastic("Cool_Cones", (236, 234, 228))
    parts = [pk.rounded("Cabinet", (1.2, 1.2, 3.3), (0, 0, 1.75), white, r=0.12),
             mk.box("Bay", (0.86, 0.06, 1.0), (0, -0.62, 2.4), mat=dark, bevel=0.04),
             mk.box("BayRoof", (0.86, 0.18, 0.06), (0, -0.68, 2.88), mat=white),
             mk.box("Tray", (0.8, 0.32, 0.06), (0, -0.76, 1.96), mat=dark, bevel=0.02),
             mk.lathe("Collar", [(0.0, 0.0), (0.42, 0.0), (0.4, 0.12), (0.22, 0.16), (0.0, 0.16)], (0, 0, 3.4), mat=grey,
                      segments=20),
             mk.lathe("Bottle", [(0.0, 0.08), (0.17, 0.08), (0.2, 0.3), (0.52, 0.55), (0.55, 1.5), (0.45, 1.75),
                                 (0.0, 1.8)], (0, 0, 3.4), mat=blue, segments=24)]
    for z in (3.95, 4.3, 4.65):  # the bottle's ribs
        parts.append(mk.torus("Rib", 0.55, 0.025, (0, 0, z), mat=blue, major_segments=24, minor_segments=4))
    for k in range(5):  # the drip tray's grate
        parts.append(mk.box("Grate", (0.03, 0.3, 0.02), (-0.3 + k * 0.15, -0.76, 2.0), mat=grey))
    for sx, cap in ((-1, (60, 130, 230)), (1, (220, 50, 50))):
        x = sx * 0.2
        parts += [mk.box("TapBody", (0.12, 0.16, 0.14), (x, -0.7, 2.62), mat=grey, bevel=0.03),
                  mk.cylinder("Spout", 0.035, 0.12, (x, -0.74, 2.5), mat=grey, verts=8),
                  mk.box("Lever", (0.1, 0.05, 0.22), (x, -0.8, 2.7), rot=(-20, 0, 0), mat=pk.plastic(f"Cool_Cap{sx}", cap),
                         bevel=0.02)]
    parts.append(mk.box("Lock", (0.06, 0.06, 0.06), (0.32, -0.79, 2.72), mat=pk.plastic("Cool_Lock", (220, 50, 50))))
    for sy in range(6):  # the vent grille down the side
        parts.append(mk.box("Vent", (0.02, 0.6, 0.04), (0.61, 0.0, 0.8 + sy * 0.12), mat=dark))
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(mk.cylinder("Foot", 0.08, 0.1, (sx * 0.45, sy * 0.45, 0.05), mat=dark, verts=10))
    parts += [mk.cylinder("ConeTube", 0.13, 0.9, (-0.73, 0.1, 2.55), mat=pk.plastic("Cool_Tube", (200, 210, 220)),
                          verts=12),
              mk.cylinder("Cones", 0.11, 0.3, (-0.73, 0.1, 1.95), mat=cones, verts=12, radius2=0.03),
              mk.box("TubeBracket", (0.14, 0.12, 0.6), (-0.64, 0.1, 2.55), mat=grey)]
    glows = [mk.box("Lamp", (0.08, 0.02, 0.05), (sx * 0.2, -0.66, 2.98),
                    mat=pk.glow("Cool_Lamp", (80, 200, 120) if sx < 0 else (255, 120, 60), 3)) for sx in (-1, 1)]
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
    """A heavy office desk phone: its body sloping up to the back, a grid of twelve keys and a row of line keys on
    the slope, a paper label strip, the handset lying in its cradle along the left with the coiled cord curling off
    to the side, the message lamp lit."""
    dark = pk.plastic("Dphone_Dark", (30, 30, 34))
    key = pk.plastic("Dphone_Key", (196, 194, 188))
    grey = pk.plastic("Dphone_Grey", (70, 72, 76))
    paper = pk.plastic("Dphone_Paper", (236, 232, 218))
    ink = pk.plastic("Dphone_Ink", (40, 40, 44))
    slope = math.degrees(math.atan2(0.17, 0.61))

    def on_slope(y):
        return 0.13 + (y + 0.36) * 0.17 / 0.61

    parts = [mk.extrude_shape("Body", [(-0.4, 0.0), (0.4, 0.0), (0.4, 0.27), (0.25, 0.31), (-0.36, 0.13), (-0.4, 0.08)],
                              0.95, rot=(90, 0, 90), mat=dark, bevel=0.03),
             pk.rounded("Foot", (0.9, 0.74, 0.03), (0, 0.0, 0.015), grey, r=0.01)]
    # Twelve keys in four rows on the right of the slope, five line keys beside them, the label strip.
    for row in range(4):
        y = -0.26 + row * 0.11
        for col in range(3):
            parts.append(pk.rounded("Key", (0.075, 0.07, 0.035), (0.08 + col * 0.1, y, on_slope(y) + 0.02), key, r=0.01,
                                    rot=(slope, 0, 0)))
    for k in range(5):
        y = -0.27 + k * 0.09
        parts.append(pk.rounded("LineKey", (0.05, 0.05, 0.03), (0.4, y, on_slope(y) + 0.02), grey, r=0.008,
                                rot=(slope, 0, 0)))
    parts.append(mk.box("Label", (0.3, 0.1, 0.01), (0.18, 0.18, on_slope(0.18) + 0.006), rot=(slope, 0, 0), mat=paper))
    parts += pk.label("LabelText", "INT 214", 0.035, (0.18, 0.18, on_slope(0.18) + 0.013), ink, rot=(90 + slope, 0, 0))
    # The handset in its cradle: two rests, the grip between its two cups, lying along the slope.
    hy, hx = -0.02, -0.25
    lift = 0.13
    for y in (-0.26, 0.22):
        parts.append(pk.rounded("Rest", (0.22, 0.07, 0.1), (hx, y, on_slope(y) + 0.04), grey, r=0.02, rot=(slope, 0, 0)))
    parts += [pk.rounded("Grip", (0.13, 0.5, 0.08), (hx, hy, on_slope(hy) + lift), dark, r=0.035, rot=(slope, 0, 0)),
              pk.rounded("Ear", (0.2, 0.18, 0.12), (hx, 0.27, on_slope(0.27) + lift - 0.02), dark, r=0.05,
                         rot=(slope, 0, 0)),
              pk.rounded("Mouth", (0.2, 0.18, 0.12), (hx, -0.31, on_slope(-0.31) + lift - 0.02), dark, r=0.05,
                         rot=(slope, 0, 0)),
              pk.coil("Cord", (hx - 0.08, -0.36, on_slope(-0.36) + 0.05), (-0.5, 0.2, 0.06), 9, 0.025, 0.008, dark,
                      sag=0.03)]
    glows = [mk.box("Message", (0.06, 0.04, 0.03), (0.4, 0.2, on_slope(0.2) + 0.03), rot=(slope, 0, 0),
                    mat=pk.glow("Dphone_Line", (255, 90, 60), 3))]
    return parts, glows


@prop("CoffeeMachine", pivot="bottom", material="Metal", collide=False, texture=256, set="Agency")
def coffee_machine():
    """An office filter coffee machine: a black tower with its water tank behind (its gauge a window of blue), the
    brewing head over the lower plate with the filter basket's handle out of its side, the glass jug under it half
    full, its black lid and handle; a second jug, full, keeping warm on the plate on top; the switch and its lamp."""
    black = pk.plastic("Cof_Black", (24, 24, 26))
    steel = pk.metal("Cof_Steel", (150, 152, 158), (190, 192, 198), rough=0.3, metallic=0.8)
    coffee = pk.plastic("Cof_Coffee", (40, 22, 12))
    glass = mk.noisy("Cof_Glass", srgb(60, 52, 46), srgb(96, 86, 78), scale=6, roughness=0.08)
    water = pk.plastic("Cof_Water", (80, 130, 190))
    parts = [pk.rounded("Tower", (1.0, 0.75, 1.8), (0, 0.32, 0.9), black, r=0.06),
             mk.box("Gauge", (0.08, 0.3, 0.9), (0.51, 0.35, 0.95), mat=water),
             pk.rounded("Head", (1.0, 1.25, 0.38), (0, -0.05, 1.62), black, r=0.06),
             mk.box("Basket", (0.08, 0.12, 0.16), (0.53, -0.3, 1.55), mat=black, bevel=0.02),
             pk.rounded("Base", (1.0, 1.25, 0.14), (0, -0.05, 0.07), black, r=0.04),
             mk.cylinder("Plate", 0.36, 0.03, (0, -0.32, 0.155), mat=steel, verts=20),
             mk.cylinder("TopPlate", 0.32, 0.03, (0, 0.32, 1.815), mat=steel, verts=20)]
    for at, z0, fill in (((0, -0.32), 0.17, 0.45), ((0, 0.32), 1.83, 0.8)):
        x, y = at
        parts += [mk.lathe("Jug", [(0.0, 0.0), (0.3, 0.0), (0.34, 0.12), (0.34, 0.42), (0.26, 0.58), (0.2, 0.66),
                                   (0.0, 0.66)], (x, y, z0), mat=glass, segments=18),
                  mk.lathe("Brew", [(0.0, 0.0), (0.33, 0.0), (0.345, 0.12), (0.345, 0.66 * fill - 0.06), (0.0, 0.66 * fill - 0.06)],
                           (x, y, z0 + 0.03), mat=coffee, segments=18),
                  mk.cylinder("Lid", 0.21, 0.07, (x, y, z0 + 0.69), mat=black, verts=14),
                  mk.box("JugHandle", (0.06, 0.12, 0.42), (x + 0.42, y, z0 + 0.36), mat=black, bevel=0.02),
                  mk.box("HandleArm", (0.12, 0.08, 0.06), (x + 0.37, y, z0 + 0.55), mat=black)]
    parts.append(mk.box("Switch", (0.14, 0.04, 0.1), (0.25, -0.69, 0.07), mat=black, bevel=0.01))
    glows = [mk.box("Power", (0.08, 0.02, 0.05), (0.25, -0.715, 0.07), mat=pk.glow("Cof_Power", (255, 60, 40), 4))]
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
    # The coat hangs by its collar from the front-right hook, its back to the pole: a flat garment with
    # shoulders, sleeves, lapels, a belt and buttons; the hat (a grey felt fedora) hangs tipped on the
    # back-left hook. (They were a round tan lathe with the hat sat on its top: a capsule in a top hat.)
    dark = mk.noisy("Coat_Trim", srgb(92, 76, 52), srgb(112, 94, 66), scale=12, roughness=0.8)
    band = pk.plastic("Coat_HatBand", (18, 18, 20))

    def hung(objs, hook_angle, face_turn):
        """Moves pieces built round a hook tip at the origin (front to -Y) onto that hook."""
        hx, hy = math.cos(hook_angle) * 0.318, math.sin(hook_angle) * 0.318
        c, s_ = math.cos(face_turn), math.sin(face_turn)
        for o in objs:
            x, y, z = o.location
            o.location = (hx + x * c - y * s_, hy + x * s_ + y * c, z)
            o.rotation_euler[2] += face_turn
        return objs

    body = mk.lathe("Coat", [(0.0, 0.0), (0.66, 0.0), (0.6, 1.2), (0.55, 2.4), (0.6, 3.2), (0.5, 3.35), (0.0, 3.4)],
                    (0.0, -0.2, 2.25), mat=coat, segments=16)
    body.scale = (1.0, 0.36, 1.0)
    coat_parts = [body,
                  mk.box("Collar", (0.56, 0.36, 0.26), (0.0, -0.2, 5.72), mat=dark, bevel=0.08),
                  mk.box("Loop", (0.07, 0.03, 0.24), (0.0, -0.03, 5.92), mat=dark)]
    for sx in (-1, 1):
        coat_parts += [
            mk.box("Shoulder", (0.62, 0.34, 0.2), (sx * 0.3, -0.2, 5.52), rot=(0, sx * 14, 0), mat=coat, bevel=0.07),
            mk.tube("Sleeve", (sx * 0.6, -0.2, 5.45), (sx * 0.66, -0.24, 3.55), 0.17, radius_end=0.14, mat=coat, verts=10),
            mk.tube("Cuff", (sx * 0.66, -0.24, 3.6), (sx * 0.665, -0.245, 3.4), 0.15, mat=dark, verts=10),
            mk.box("Lapel", (0.2, 0.04, 1.05), (sx * 0.15, -0.43, 5.0), rot=(0, sx * 18, 0), mat=dark),
        ]
        for k in range(3):
            coat_parts.append(mk.sphere("Button", 0.045, (sx * 0.17, -0.43, 4.35 - k * 0.42), mat=band, segments=8, rings=6))
    coat_parts += [mk.box("Belt", (1.2, 0.5, 0.13), (0.0, -0.2, 3.95), mat=dark, bevel=0.03),
                   mk.box("BeltEnd", (0.12, 0.035, 0.62), (0.26, -0.46, 3.62), rot=(0, -8, 0), mat=dark)]
    parts += hung(coat_parts, -math.pi / 4, math.pi / 4)
    hat_parts = [mk.cylinder("HatBrim", 0.46, 0.04, (0.0, -0.3, 5.92), mat=hat, verts=20),
                 mk.lathe("HatCrown", [(0.0, 0.0), (0.29, 0.0), (0.28, 0.22), (0.23, 0.33), (0.1, 0.35), (0.0, 0.31)],
                          (0.0, -0.3, 5.94), mat=hat, segments=16),
                 mk.cylinder("HatBand", 0.292, 0.08, (0.0, -0.3, 5.99), mat=band, verts=16)]
    # tipped forward off its hook: the brim's back edge on the hook, the crown leaning out
    for o in hat_parts:
        x, y, z = o.location
        a = math.radians(24)
        dy, dz = y, z - 5.92
        o.location = (x, dy * math.cos(a) - dz * math.sin(a), 5.92 + dy * math.sin(a) + dz * math.cos(a))
        o.rotation_euler[0] += a
    parts += hung(hat_parts, 3 * math.pi / 4, -3 * math.pi / 4)
    parts.append(mk.tube("Umbrella", (0.7, 0.4, 0.05), (0.4, 0.2, 3.1), 0.12, radius_end=0.05, mat=brolly, verts=8))
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


@prop("MicrofilmReader", pivot="bottom", material="SmoothPlastic", collide=True, texture=512, set="Agency")
def microfilm_reader():
    """A microfilm reader on its steel cabinet: two drawers of film boxes below (handles, card holders), the deck
    with its glass film carrier between two reels of film, the column at the back, the big hooded screen showing a
    page of an old newspaper, its focus and wind knobs at the side."""
    steel = pk.metal("Film_Steel", (90, 94, 100), (120, 124, 130), rough=0.45, metallic=0.5)
    beige = pk.plastic("Film_Beige", (180, 172, 150))
    dark = pk.metal("Film_Dark", (24, 24, 28), (40, 40, 46), rough=0.5, metallic=0.2)
    chrome = pk.chrome("Film_Chrome")
    film = pk.plastic("Film_Film", (54, 36, 24))
    card = pk.plastic("Film_Card", (232, 226, 206))
    glass = pk.dark_glass("Film_Glass", (40, 50, 56))
    parts = [pk.rounded("Cabinet", (2.4, 2.3, 2.62), (0, 0.05, 1.37), steel, r=0.05)]
    parts += pk.feet("Feet", [(sx * 1.05, sy * 1.0) for sx in (-1, 1) for sy in (-1, 1)], dark, r=0.1, h=0.08)
    for k, z in enumerate((0.78, 2.02)):
        parts += [pk.rounded("Drawer", (2.12, 0.06, 1.1), (0, -1.12, z), steel, r=0.02),
                  mk.box("Pull", (0.7, 0.08, 0.08), (0, -1.2, z + 0.2), mat=chrome),
                  mk.box("Holder", (0.5, 0.03, 0.3), (0, -1.16, z - 0.15), mat=chrome),
                  mk.box("Card", (0.44, 0.02, 0.24), (0, -1.175, z - 0.15), mat=card)]
    parts += [pk.rounded("Deck", (2.2, 2.0, 0.42), (0, 0.1, 2.89), beige, r=0.06),
              mk.box("Carrier", (1.1, 0.7, 0.04), (0, -0.45, 3.12), mat=glass),
              mk.box("RailF", (1.2, 0.05, 0.05), (0, -0.82, 3.13), mat=chrome),
              mk.box("RailB", (1.2, 0.05, 0.05), (0, -0.08, 3.13), mat=chrome),
              pk.rounded("Column", (1.0, 0.6, 0.5), (0, 0.78, 3.34), beige, r=0.06)]
    for sx in (-1, 1):
        x = sx * 0.78
        parts += [mk.cylinder("Spindle", 0.03, 0.2, (x, -0.45, 3.2), mat=chrome, verts=8),
                  mk.cylinder("Flange", 0.3, 0.02, (x, -0.45, 3.13), mat=dark, verts=20),
                  mk.cylinder("Flange", 0.3, 0.02, (x, -0.45, 3.27), mat=dark, verts=20),
                  mk.cylinder("Wound", 0.22, 0.12, (x, -0.45, 3.2), mat=film, verts=18),
                  mk.box("Strip", (0.3, 0.16, 0.01), (sx * 0.5, -0.45, 3.15), mat=film)]
    # The hood: the screen's housing, a visor round the screen, the knobs at its right.
    parts += [pk.rounded("Hood", (2.2, 1.5, 1.85), (0, 0.45, 4.15), beige, r=0.12),
              mk.box("VisorTop", (2.1, 0.42, 0.08), (0, -0.48, 4.98), mat=beige),
              mk.box("VisorL", (0.08, 0.42, 1.6), (-1.01, -0.48, 4.2), mat=beige),
              mk.box("VisorR", (0.08, 0.42, 1.6), (1.01, -0.48, 4.2), mat=beige)]
    parts += pk.frame("Bezel", 1.8, 1.5, 0.1, 0.06, (0, -0.31, 4.2), dark)
    for z in (3.55, 3.9):
        parts += [mk.cylinder("Knob", 0.11, 0.08, (1.14, 0.3, z), rot=(0, 90, 0), mat=dark, verts=14),
                  mk.cylinder("KnobCap", 0.05, 0.04, (1.2, 0.3, z), rot=(0, 90, 0), mat=chrome, verts=10)]
    glows = [mk.box("Page", (1.6, 0.04, 1.3), (0, -0.32, 4.2), mat=pk.glow("Film_Page", (220, 214, 190), 1.6))]
    return parts, glows
