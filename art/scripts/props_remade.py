"""Older props of each map remade to the standard of props_mapown.py, under their old keys: the ones players pass most that were still a few boxes,
several of them on a 1024 texture their shapes never earned. Footprints, heights, lights and what stands on them are the old ones.

- Kagegaoka University: the exam desks, stone lanterns, the club house's shoe lockers, the upright piano.
- Bureau HQ: the whiteboards, photocopiers, fume hoods, the director's desk, the baggage X-ray.
- Tokyo: the road barricades and traffic cones."""

import math
import random

from mathutils import Vector

import modelkit as mk
import propkit as pk
import stationkit as sk
from common import srgb
from props import prop
from props_campus import snow
from props_mapown import _axis, bar, card_frame, cushion, lattice, loop, spline, studs, turned
from props_mapown2 import snow_on, stripes

LAMP_WARM = (255, 210, 150)


# Kagegaoka University -----------------------------------------------------------------------------------


@prop("ExamDesk", pivot="bottom", material="Wood", collide=True, texture=512, set="Campus", exact=True, normal=128)
def exam_desk():
    """An exam hall desk with its seat behind: a laminate top with its oak edge and pencil groove on a bent steel frame, a wire book rack, the seat and
    back one sweep of bent plywood on the frame's runners, the candidate's number card, a pencil case, sharpened pencils, an eraser and the booklet
    face down, waiting for tomorrow."""
    top_mat = mk.wood("EDesk_Wood", srgb(170, 126, 80), srgb(126, 90, 54), roughness=0.4)
    edge = mk.wood("EDesk_Oak", srgb(120, 84, 50), srgb(84, 58, 34), roughness=0.45)
    ply = mk.wood("EDeskPly_Wood", srgb(156, 114, 70), srgb(112, 80, 48), roughness=0.5)
    steel = pk.metal("EDesk_Steel", (56, 60, 66), (96, 100, 108), rough=0.42, metallic=0.7)
    rack = lattice("EDesk_Rack", (10, 10, 12), (110, 114, 120), 0.2, _axis("X"), _axis("Y"), share=0.44, roughness=0.4, metallic=0.7, square=True)
    rubber = pk.rubber("EDesk_Rubber")
    card = mk.noisy("EDesk_Card", srgb(226, 222, 210), srgb(244, 240, 230), roughness=0.9)
    cover = mk.flat("EDesk_Paper", srgb(214, 206, 182), 0.9)
    writing = mk.flat("EDesk_Print", srgb(30, 30, 36), 0.8)
    case = pk.plastic("EDesk_Plastic", (40, 60, 110))
    pencil = pk.plastic("EDeskPencil_Plastic", (230, 190, 50))
    tip = mk.flat("EDesk_Tip", srgb(30, 26, 22), 0.6)
    eraser = pk.plastic("EDeskRubber_Plastic", (226, 226, 220))
    parts = [pk.rounded("Top", (3.4, 1.7, 0.08), (0, -0.2, 2.62), top_mat, r=0.02),
             mk.box("TopEdge", (3.36, 1.66, 0.05), (0, -0.2, 2.56), mat=edge),
             mk.box("Groove", (2.8, 0.05, 0.006), (0, 0.56, 2.661), mat=tip),
             mk.box("Rack", (3.0, 1.3, 0.03), (0, -0.14, 2.14), mat=rack),
             mk.box("RackLip", (3.0, 0.04, 0.12), (0, -0.78, 2.18), mat=steel)]
    for sx in (-1, 1):
        x = sx * 1.5
        frame = spline([(x, -0.92, 0.07), (x, -0.86, 1.2), (x, -0.8, 2.3), (x, -0.5, 2.5), (x, 0.3, 2.5), (x, 0.42, 2.2), (x, 0.46, 0.4), (x, 0.52, 0.07)], 2)
        parts.append(bar("DeskFrame", frame, 0.055, steel, sides=5))
        parts.append(mk.box("DeskRunner", (0.1, 1.5, 0.08), (x, -0.2, 0.05), mat=steel, bevel=0.015, segments=1))
        px = sx * 0.66
        run = spline([(px, 2.04, 2.7), (px, 1.94, 1.9), (px, 1.86, 1.44), (px, 1.8, 0.8), (px, 1.86, 0.1), (px, 1.4, 0.055), (px, 0.5, 0.055)], 2)
        parts.append(bar("SeatFrame", run, 0.05, steel, sides=5))
        parts.append(mk.tube("SeatPost", (px, 0.92, 0.06), (px, 0.92, 1.46), 0.045, mat=steel, verts=5))
        for y, zz in ((-0.2, 0.0), (1.2, 0.0)):
            parts.append(mk.box("Glide", (0.14, 0.26, 0.03), (x if y < 0 else px, y, 0.015), mat=rubber))
    parts.append(sk.wedge("SeatShell", [(0.66, 1.56), (0.72, 1.5), (1.72, 1.48), (1.9, 1.56), (2.0, 2.0), (2.08, 2.88), (1.98, 2.9), (1.88, 2.06), (1.76, 1.62), (0.72, 1.6)], 1.66, 0.0,
                          ply, bevel=0.014))
    # The desk's things.
    z = 2.663
    number = mk.box("NumberCard", (0.8, 0.02, 0.36), (1.0, -0.95, z + 0.16), rot=(-16, 0, 0), mat=card)
    parts += [number, mk.box("NumberPrint", (0.42, 0.006, 0.14), (1.0, -0.966, z + 0.16), rot=(-16, 0, 0), mat=writing),
              mk.box("Booklet", (1.0, 1.3, 0.05), (-0.2, -0.2, z + 0.025), rot=(0, 0, 3), mat=cover),
              mk.box("BookletBand", (0.84, 0.3, 0.004), (-0.2, 0.06, z + 0.052), rot=(0, 0, 3), mat=writing),
              pk.rounded("PencilCase", (0.8, 0.28, 0.1), (1.12, 0.3, z + 0.05), case, r=0.04),
              mk.box("Eraser", (0.2, 0.1, 0.07), (0.86, -0.2, z + 0.035), rot=(0, 0, 18), mat=eraser)]
    for k, (x, r) in enumerate(((0.5, 4), (0.62, -6))):
        parts += sk.pen(f"Pencil{k}", (x + 0.3, -0.5 + k * 0.1, z + 0.025), (x + 0.4, 0.1 + k * 0.1, z + 0.025), pencil, cap=None, r=0.02)
    parts.append(mk.cylinder("PencilTip", 0.012, 0.03, (0.8, -0.54, z + 0.025), rot=(90, 0, 0), mat=tip, verts=5))
    return parts, []


@prop("StoneLantern", pivot="bottom", material="Slate", collide=True, texture=512, set="Campus", exact=True, normal=128,
      lights=[dict(at=(0, 0, 3.95), kind="point", color=(255, 180, 110), range=9, brightness=0.55)])
def stone_lantern():
    """A kasuga stone lantern: a hexagonal base with its carved lotus step, a tall round pillar with two bands, the platform, the fire box with a deer panel
    and its lit windows, the broad curled roof with its six corners turned up, the jewel on top, snow lying on all of it."""
    stone = mk.noisy("SLantern_Stone", srgb(86, 88, 84), srgb(132, 134, 126), roughness=0.85)
    moss = mk.noisy("SLanternMoss_Stone", srgb(52, 66, 46), srgb(84, 100, 66), roughness=0.9)
    dark = mk.flat("SLantern_Dark", srgb(14, 12, 10), 0.9)
    parts = [mk.lathe("Footing", [(0.0, 0.0), (1.16, 0.0), (1.16, 0.16), (1.0, 0.24), (0.0, 0.24)], mat=moss, segments=6),
             mk.lathe("Lotus", [(0.0, 0.24), (0.9, 0.24), (0.86, 0.42), (0.64, 0.6), (0.44, 0.64), (0.0, 0.64)], mat=stone, segments=12),
             mk.lathe("Pillar", [(0.0, 0.64), (0.34, 0.64), (0.3, 0.9), (0.33, 0.96), (0.28, 1.04), (0.26, 2.2), (0.3, 2.26), (0.26, 2.34), (0.3, 2.74), (0.0, 2.74)], mat=stone, segments=10),
             mk.lathe("Platform", [(0.0, 2.72), (0.46, 2.74), (0.8, 2.92), (0.84, 3.02), (0.76, 3.1), (0.0, 3.1)], mat=stone, segments=6),
             mk.lathe("FireBox", [(0.0, 3.1), (0.56, 3.1), (0.56, 3.98), (0.0, 3.98)], mat=stone, segments=6),
             mk.lathe("RoofRim", [(0.0, 3.98), (1.3, 4.06), (1.42, 4.2), (1.3, 4.24), (0.86, 4.5), (0.42, 4.9), (0.3, 5.06), (0.0, 5.1)], mat=stone, segments=6),
             mk.lathe("Jewel", [(0.0, 5.08), (0.26, 5.1), (0.32, 5.2), (0.2, 5.4), (0.26, 5.48), (0.16, 5.66), (0.0, 5.78)], mat=stone, segments=10)]
    for k in range(6):
        a = math.radians(60 * k)
        c, s = math.cos(a), math.sin(a)
        parts.append(mk.soften(mk.tube("RoofCurl", (1.2 * c, 1.2 * s, 4.16), (1.46 * c, 1.46 * s, 4.34), 0.1, 0.06, mat=stone, verts=5)))
    glows = []
    fire = pk.glow("SLantern_Fire", (255, 170, 90), 3)
    for k in (0, 3):  # (windows front and back, the deer panels at the sides stay stone)
        a = math.radians(-90 + 60 * k)
        c, s = math.cos(a), math.sin(a)
        turn = math.degrees(a) + 90
        glows.append(mk.box("Window", (0.42, 0.02, 0.56), (0.5 * c, 0.5 * s, 3.54), rot=(0, 0, turn), mat=fire))
    for k in (1, 2, 4, 5):
        a = math.radians(-90 + 60 * k)
        c, s = math.cos(a), math.sin(a)
        parts.append(mk.box("Panel", (0.4, 0.02, 0.5), (0.492 * c, 0.492 * s, 3.54), rot=(0, 0, math.degrees(a) + 90), mat=dark))
    parts.append(snow_on(parts[3:7], snow("SLantern"), cell=0.13, depth=0.12, flat=0.5))
    return parts, glows


@prop("ShoeLockers", pivot="bottom", material="Wood", collide=True, texture=512, set="Campus", exact=True, normal=128)
def shoe_lockers():
    """A getabako at the club house door: a pine rack of numbered shoe cubbies, sneakers and loafers in some, a name card under each, a low step with a row of
    green guest slippers."""
    pine = mk.wood("GBox_Wood", srgb(154, 116, 72), srgb(108, 78, 46), roughness=0.55)
    back = mk.flat("GBox_Dark", srgb(30, 22, 16), 0.8)
    step = mk.wood("GBoxStep_Wood", srgb(116, 84, 50), srgb(78, 54, 32), roughness=0.5)
    card = mk.noisy("GBox_Card", srgb(214, 206, 180), srgb(238, 232, 210), roughness=0.9)
    canvas = [mk.flat(f"GBoxShoe{i}_Plastic", srgb(*c), 0.5) for i, c in enumerate(((210, 210, 204), (40, 60, 110), (150, 40, 40)))]
    leather = mk.noisy("GBox_Leather", srgb(24, 16, 12), srgb(56, 36, 24), roughness=0.4)
    slipper = pk.plastic("GBoxSlipper_Plastic", (54, 110, 80))
    rng = random.Random(21)
    w, h, y0 = 6.1, 5.1, 0.46
    parts = [mk.box("Back", (w, 0.06, h), (0, y0 + 0.92, h / 2), mat=back),
             mk.box("Step", (6.2, 1.1, 0.16), (0, -0.87, 0.08), mat=step, bevel=0.02, segments=1)]
    for k in range(7):
        parts.append(mk.box("Upright", (0.08, 1.9, h), (-w / 2 + 0.04 + k * (w - 0.08) / 6, y0, h / 2), mat=pine))
    for k in range(7):
        z = 0.04 + k * (h - 0.08) / 6
        parts.append(mk.box("Shelf", (w, 1.9, 0.08), (0, y0, z), mat=pine))
    number = 1
    for row in range(6):
        z = 0.08 + row * (h - 0.08) / 6
        for col in range(6):
            x = -w / 2 + 0.55 + col * (w - 0.08) / 6
            parts.append(mk.box("NameCard", (0.5, 0.012, 0.13), (x, y0 - 0.956, z - 0.0 + 0.0), mat=card))
            kind = rng.randrange(4)
            if kind == 1:  # (sneakers, a pair)
                m = rng.choice(canvas)
                for dx in (-0.17, 0.17):
                    parts.append(cushion("Sneaker", (0.3, 1.0, 0.3), (x + dx, y0 + 0.1, z + 0.2), m, e=0.6, segments=8, rings=4))
                    parts.append(mk.box("Sole", (0.3, 0.98, 0.05), (x + dx, y0 + 0.1, z + 0.065), mat=canvas[0]))
            elif kind == 2:  # (loafers)
                for dx in (-0.17, 0.17):
                    parts.append(cushion("Loafer", (0.28, 0.96, 0.24), (x + dx, y0 + 0.1, z + 0.16), leather, e=0.5, segments=8, rings=4))
            number += 1
    for k in range(5):
        x = -2.4 + k * 1.2
        for dx in (-0.2, 0.2):
            parts.append(pk.rounded("Slipper", (0.32, 0.86, 0.06), (x + dx, -0.86, 0.19), slipper, r=0.025))
            parts.append(sk.wedge("SlipperVamp", [(-0.06, 0.2), (0.3, 0.2), (0.28, 0.3), (0.0, 0.34), (-0.06, 0.3)], 0.3, x + dx, slipper))
            parts[-1].location = (x + dx, -1.12, 0.02)
    return parts, []


@prop("UprightPiano", pivot="bottom", material="SmoothPlastic", collide=True, texture=512, set="Campus", exact=True, normal=128)
def upright_piano():
    """A black lacquer upright: the top lid and panel, the fall folded back from a real keyboard of white keys and raised black ones, the music desk with an open
    score, turned legs on brass castors, three brass pedals, a padded adjustable bench."""
    lacquer = mk.noisy("Piano_Plastic", srgb(8, 8, 10), srgb(30, 30, 34), roughness=0.12)
    key_white = mk.flat("PianoKey_Plastic", srgb(232, 228, 216), 0.3)
    gap = lattice("PianoKeys_Plastic", (232, 228, 216), (30, 28, 26), 0.1, _axis("X"), _axis("Y"), share=0.97, roughness=0.3, square=True)
    black = mk.flat("PianoBlack_Plastic", srgb(10, 10, 12), 0.25)
    brass = pk.metal("Piano_Brass", (124, 96, 50), (190, 156, 90), rough=0.32, metallic=1.0)
    felt = mk.flat("Piano_Felt", srgb(120, 24, 28), 0.9)
    pad = mk.noisy("Piano_Leather", srgb(16, 16, 18), srgb(40, 40, 44), roughness=0.45)
    pages = mk.noisy("Piano_Paper", srgb(214, 206, 186), srgb(236, 230, 212), roughness=0.9)
    staves = mk.flat("Piano_Print", srgb(40, 40, 46), 0.8)
    rng = random.Random(31)
    w = 5.1
    fy = 0.2  # (the case's front face above the keys)
    parts = [pk.rounded("Case", (w, 1.2, 3.9), (0, 1.0, 2.0), lacquer, r=0.04),
             mk.box("Plinth", (w, 1.3, 0.2), (0, 0.98, 0.1), mat=lacquer),
             pk.rounded("TopLid", (w + 0.08, 1.3, 0.1), (0, 1.0, 4.0), lacquer, r=0.03),
             mk.box("KeyBed", (w - 0.2, 1.0, 0.24), (0, -0.04, 2.1), mat=lacquer),
             mk.box("KeySlip", (w - 0.2, 0.05, 0.3), (0, -0.56, 2.08), mat=lacquer),
             mk.box("Keys", (w - 0.5, 0.96, 0.04), (0, -0.06, 2.24), mat=gap),
             mk.box("Felt", (w - 0.5, 0.03, 0.03), (0, 0.42, 2.27), mat=felt),
             mk.box("Fall", (w - 0.4, 0.06, 0.6), (0, 0.42, 2.66), rot=(-16, 0, 0), mat=lacquer)]
    for k in range(36):
        if k % 7 in (2, 6):
            continue
        x = -(w - 0.6) / 2 + (k + 0.7) * (w - 0.6) / 36
        parts.append(mk.box("BlackKey", (0.075, 0.56, 0.06), (x, 0.1, 2.28), mat=black))
    for sx in (-1, 1):
        parts += [mk.box("Cheek", (0.14, 1.0, 0.5), (sx * (w / 2 - 0.05), -0.04, 2.2), mat=lacquer, bevel=0.02, segments=1),
                  turned("Leg", [(0.0, 0.0), (0.06, 0.0), (0.11, 0.1), (0.08, 0.5), (0.12, 0.84), (0.14, 1.0), (0.0, 1.0)], (sx * 2.34, -0.42, 0.14), (sx * 2.34, -0.42, 1.98), lacquer),
                  mk.cylinder("Castor", 0.09, 0.14, (sx * 2.34, -0.42, 0.07), mat=brass, verts=8)]
    for k in range(3):
        x = -0.3 + k * 0.3
        parts += [mk.box("Pedal", (0.13, 0.5, 0.05), (x, 0.26, 0.2), rot=(10, 0, 0), mat=brass, bevel=0.012, segments=1)]
    # The music desk and its score.
    parts.append(mk.box("MusicDesk", (2.2, 0.06, 0.8), (0, 0.33, 3.24), rot=(-10, 0, 0), mat=lacquer, bevel=0.012, segments=1))
    parts.append(mk.box("MusicLedge", (2.2, 0.16, 0.03), (0, 0.22, 2.84), mat=lacquer))
    for side in (-1, 1):
        parts.append(mk.box("ScorePage", (0.72, 0.012, 0.92), (side * 0.37, 0.28, 3.3), rot=(-10, 0, side * 2), mat=pages))
        for k in range(6):
            parts.append(mk.box("Stave", (0.58, 0.004, 0.035), (side * 0.37, 0.27, 3.66 - k * 0.14), rot=(-10, 0, 0), mat=staves))
    # The bench.
    parts += [cushion("BenchPad", (2.4, 1.0, 0.22), (0, -2.0, 1.6), pad, e=0.4, segments=12, rings=6), mk.box("BenchFrame", (2.3, 0.9, 0.12), (0, -2.0, 1.44), mat=lacquer, bevel=0.012, segments=1)]
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(turned("BenchLeg", [(0.0, 0.0), (0.05, 0.0), (0.08, 0.2), (0.06, 0.8), (0.09, 1.0), (0.0, 1.0)], (sx * 1.0, -2.0 + sy * 0.34, 0.0), (sx * 1.0, -2.0 + sy * 0.34, 1.4), lacquer, segments=6))
    return parts, []


# Bureau HQ ----------------------------------------------------------------------------------------------


@prop("Whiteboard", pivot="bottom", material="SmoothPlastic", collide=True, texture=512, set="Agency", exact=True, normal=128)
def whiteboard():
    """A case board on wheels: an aluminium frame on braked castors, an enamel board with photographs under magnets, a marked timeline, names struck through and red
    arrows between them, the marker tray at its foot with pens and a duster."""
    alu = pk.metal("WBoard_Alu", (130, 134, 140), (176, 180, 186), rough=0.34, metallic=1.0)
    enamel = mk.noisy("WBoard_Plastic", srgb(212, 216, 216), srgb(236, 238, 238), roughness=0.14)
    photo = [mk.noisy(f"WBoardPhoto{i}_Paper", srgb(*c), srgb(*[v + 40 for v in c]), roughness=0.3) for i, c in enumerate(((40, 42, 46), (70, 64, 60), (54, 60, 66)))]
    white = mk.flat("WBoardBack_Paper", srgb(232, 230, 222), 0.8)
    pen = mk.flat("WBoardPen_Plastic", srgb(24, 28, 40), 0.5)
    red = pk.plastic("WBoardRed_Plastic", (170, 26, 30))
    blue = pk.plastic("WBoardBlue_Plastic", (36, 70, 150))
    tyre = pk.rubber("WBoard_Tyre")
    felt = mk.flat("WBoard_Felt", srgb(60, 60, 64), 0.9)
    rng = random.Random(16)
    cz, wide, tall = 3.8, 5.8, 3.8
    parts = [mk.box("Board", (wide - 0.1, 0.05, tall - 0.1), (0, 0, cz), mat=enamel)]
    for z in (cz + tall / 2 - 0.04, cz - tall / 2 + 0.04):
        parts.append(mk.box("FrameRail", (wide, 0.11, 0.09), (0, 0, z), mat=alu, bevel=0.012, segments=1))
    for x in (-wide / 2 + 0.04, wide / 2 - 0.04):
        parts.append(mk.box("FrameSide", (0.09, 0.11, tall - 0.16), (x, 0, cz), mat=alu, bevel=0.012, segments=1))
    for side in (-1, 1):
        x = side * 3.08
        parts += [mk.box("Post", (0.12, 0.12, 5.9), (x, 0, 3.0), mat=alu, bevel=0.015, segments=1),
                  mk.box("Foot", (0.14, 2.0, 0.12), (x, 0, 0.3), mat=alu, bevel=0.015, segments=1),
                  mk.cylinder("Pivot", 0.09, 0.3, (side * 2.96, 0, cz), rot=(0, 90, 0), mat=alu, verts=8)]
        for y in (-0.9, 0.9):
            parts.append(mk.soften(mk.cylinder("Castor", 0.12, 0.1, (x, y, 0.12), rot=(0, 90, 0), mat=tyre, verts=10)))
            parts.append(mk.box("Brake", (0.1, 0.1, 0.1), (x, y, 0.26), mat=alu))
    parts.append(mk.box("Cross", (6.0, 0.1, 0.12), (0, 0, 0.8), mat=alu, bevel=0.015, segments=1))
    # The case laid out: photographs, the timeline, names and arrows.
    face = -0.03
    spots = [(-2.2, 4.9), (-0.9, 4.9), (0.5, 4.8), (1.9, 4.9), (-1.6, 3.1), (0.1, 3.0)]
    pins = []
    for k, (x, z) in enumerate(spots):
        turn = rng.uniform(-3, 3)
        parts.append(mk.box("PhotoBack", (0.86, 0.008, 1.08), (x, face - 0.002, z), rot=(0, turn, 0), mat=white))
        parts.append(mk.box("Photo", (0.74, 0.006, 0.76), (x, face - 0.009, z + 0.1), rot=(0, turn, 0), mat=photo[k % 3]))
        parts.append(mk.box("Caption", (0.56, 0.004, 0.05), (x, face - 0.008, z - 0.42), rot=(0, turn, 0), mat=pen))
        pins.append((x, face - 0.012, z + 0.48))
    parts.append(studs("Magnet", pins, 0.08, 0.03, red, facing=(0, -1, 0)))
    parts.append(mk.box("Timeline", (4.8, 0.004, 0.05), (0, face - 0.002, 4.05), mat=pen))
    for k in range(7):
        parts.append(mk.box("Tick", (0.05, 0.004, 0.2), (-2.3 + k * 0.76, face - 0.002, 4.05), mat=pen))
    # Struck through suspects, arrows.
    for x, z in ((1.7, 3.3), (1.7, 2.9), (2.2, 3.1)):
        parts.append(mk.box("NameLine", (0.9, 0.004, 0.07), (x, face - 0.002, z), mat=blue))
    for x, z in ((1.7, 3.3), (2.2, 3.1)):
        parts.append(mk.box("Strike", (1.0, 0.004, 0.04), (x, face - 0.004, z), rot=(0, 7, 0), mat=red))
    for a, b in (((-2.2, 4.3), (-1.6, 3.7)), ((-0.9, 4.3), (0.1, 3.6)), ((0.5, 4.3), (1.7, 3.5))):
        (ax, az), (bx, bz) = a, b
        length = math.hypot(bx - ax, bz - az)
        angle = -math.degrees(math.atan2(bz - az, bx - ax))
        parts.append(mk.box("Arrow", (length, 0.004, 0.05), ((ax + bx) / 2, face - 0.002, (az + bz) / 2), rot=(0, angle, 0), mat=red))
    # The tray.
    tray = cz - tall / 2 - 0.05
    parts.append(mk.box("Tray", (4.6, 0.3, 0.05), (0, -0.2, tray), mat=alu, bevel=0.012, segments=1))
    parts.append(mk.box("TrayLip", (4.6, 0.03, 0.09), (0, -0.34, tray + 0.05), mat=alu))
    for x, m in ((-1.4, pen), (-1.1, red), (-0.8, blue)):
        parts.append(mk.cylinder("Marker", 0.045, 0.56, (x, -0.2, tray + 0.07), rot=(90, 0, 0), mat=m, verts=6))
    parts.append(pk.rounded("Duster", (0.56, 0.22, 0.12), (1.2, -0.2, tray + 0.09), felt, r=0.03))
    return parts, []


@prop("Photocopier", pivot="bottom", material="SmoothPlastic", collide=True, texture=512, set="Agency", exact=True, normal=128)
def photocopier():
    """The office's big copier: a two tone cabinet on castors with three labelled paper drawers, a document feeder on top with originals in its tray, a tilted touch panel,
    the side catch tray of copies, vents and an access door."""
    shell = pk.plastic("Copier_Plastic", (206, 206, 200))
    dark = pk.plastic("CopierDark_Plastic", (54, 56, 60))
    black = mk.flat("CopierBlack_Plastic", srgb(14, 14, 16), 0.5)
    vent = lattice("CopierVent_Plastic", (54, 56, 60), (14, 14, 16), 0.09, _axis("Y"), _axis("Z"), share=0.5, roughness=0.5, square=True)
    paper = mk.noisy("Copier_Paper", srgb(222, 220, 212), srgb(242, 240, 232), roughness=0.9)
    tyre = pk.rubber("Copier_Tyre")
    glass = mk.noisy("CopierGlass_Plastic", srgb(20, 30, 38), srgb(40, 56, 66), roughness=0.1)
    rng = random.Random(6)
    front = -1.2
    parts = [pk.rounded("Cabinet", (3.6, 2.4, 2.2), (-0.5, 0, 1.3), shell, r=0.05),
             mk.box("Plinth", (3.4, 2.2, 0.2), (-0.5, 0, 0.12), mat=dark),
             pk.rounded("Body", (3.6, 2.4, 0.5), (-0.5, 0, 2.66), dark, r=0.04),
             pk.rounded("Feeder", (3.0, 2.0, 0.34), (-0.6, 0.1, 3.08), shell, r=0.06),
             mk.box("Platen", (2.6, 1.6, 0.02), (-0.6, 0.1, 2.92), mat=glass)]
    for k in range(3):
        z = 0.56 + k * 0.62
        parts += [mk.box("Drawer", (3.3, 0.05, 0.54), (-0.5, front - 0.02, z), mat=shell, bevel=0.012, segments=1),
                  mk.box("DrawerPull", (0.9, 0.05, 0.1), (-0.5, front - 0.05, z + 0.12), mat=dark, bevel=0.012, segments=1),
                  mk.box("SizeTag", (0.26, 0.008, 0.14), (0.7, front - 0.05, z), mat=paper)]
    for sx, sy in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
        parts.append(mk.soften(mk.cylinder("Castor", 0.09, 0.08, (-0.5 + sx * 1.56, sy * 0.96, 0.09), rot=(0, 90, 0), mat=tyre, verts=8)))
    # The panel on its arm.
    panel_at = (0.72, -0.86, 3.04)
    panel = pk.rounded("Panel", (1.2, 0.76, 0.1), panel_at, black, r=0.03)
    panel.rotation_euler = (math.radians(24), 0, 0)
    parts.append(panel)
    parts.append(mk.box("PanelArm", (0.5, 0.5, 0.2), (0.72, -0.8, 2.92), mat=dark))
    lit = mk.box("Screen", (0.9, 0.5, 0.012), (panel_at[0], panel_at[1], panel_at[2] + 0.056), rot=(24, 0, 0), mat=pk.glow("Copier_Screen", (120, 220, 170), 2))
    # The feeder's tray of originals, the catch tray of copies.
    parts.append(sk.wedge("FeedTray", [(0.5, 3.26), (1.2, 3.54), (1.22, 3.6), (0.52, 3.34)], 2.2, -0.6, shell))
    for k in range(5):
        parts.append(mk.box("Original", (1.8, 0.66, 0.012), (-0.6, 0.86, 3.4 + k * 0.016), rot=(21, 0, 0), mat=paper))
    parts.append(sk.wedge("Catch", [(-0.9, 1.5), (0.9, 1.5), (0.9, 1.6), (-0.9, 1.64)], 1.2, 1.9, dark))
    for k in range(8):
        parts.append(mk.box("Copy", (1.04, 1.5, 0.012), (1.9 + rng.uniform(-0.02, 0.02), rng.uniform(-0.02, 0.02), 1.66 + k * 0.016), mat=paper))
    parts.append(mk.box("Vent", (0.012, 1.4, 0.7), (-2.306, 0.1, 1.5), mat=vent))
    parts.append(mk.box("DoorSeam", (3.4, 0.008, 0.02), (-0.5, front - 0.002, 2.2), mat=black))
    return parts, [lit]


@prop("FumeHood", pivot="bottom", material="SmoothPlastic", collide=True, texture=512, set="Agency", exact=True, normal=128,
      lights=[dict(at=(0, -0.3, 6.6), kind="point", color=(220, 236, 255), range=10, brightness=0.8)])
def fume_hood():
    """The forensic lab's fume hood: a white enamel base of doors, a black resin work top with a cup sink and gas taps, a stainless chamber with baffle slots behind a raised sash on
    its side tracks, an airflow gauge and switches, a lit panel in the roof, the steel duct and damper rising out of the top."""
    enamel = pk.plastic("FHood_Plastic", (214, 216, 214))
    resin = mk.noisy("FHoodResin_Plastic", srgb(12, 13, 14), srgb(32, 34, 36), roughness=0.3)
    steel = pk.metal("FHood_Chrome", (126, 130, 134), (176, 180, 186), rough=0.32, metallic=0.9)
    dark = pk.metal("FHood_Iron", (22, 24, 26), (48, 50, 54), rough=0.45, metallic=0.7)
    slots = lattice("FHood_Slots", (126, 130, 134), (10, 10, 12), 0.16, _axis("Z"), _axis("X"), share=0.22, roughness=0.34, metallic=0.8, square=True)
    duct = pk.metal("FHood_Galv", (96, 100, 102), (140, 144, 146), rough=0.5, metallic=0.8)
    glass = mk.noisy("FHoodGlass_Plastic", srgb(70, 96, 110), srgb(120, 150, 164), roughness=0.14)
    gauge = mk.flat("FHood_Paper", srgb(226, 226, 220), 0.5)
    parts = [mk.box("Base", (5.2, 2.5, 2.7), (0, 0.08, 1.35), mat=enamel, bevel=0.02, segments=1),
             pk.rounded("Top", (5.3, 2.72, 0.14), (0, 0, 2.77), resin, r=0.02),
             mk.box("BackPanel", (4.8, 0.05, 4.2), (0, 1.1, 5.0), mat=slots),
             mk.box("Roof", (5.3, 2.72, 0.5), (0, 0, 7.76), mat=steel, bevel=0.03, segments=1),
             mk.box("Header", (5.3, 0.1, 0.8), (0, -1.28, 7.5), mat=enamel),
             mk.cylinder("Duct", 0.46, 1.0, (0, 0.3, 8.5), mat=duct, verts=12),
             mk.cylinder("Damper", 0.52, 0.14, (0, 0.3, 8.2), mat=duct, verts=12),
             mk.lathe("CupSink", [(0.16, 2.82), (0.16, 2.84), (0.12, 2.84)], (1.7, 0.4, 0), mat=steel, segments=10, caps=False),
             mk.cylinder("SinkHole", 0.12, 0.01, (1.7, 0.4, 2.835), mat=dark, verts=10)]
    for x in (-2.55, 2.55):
        parts.append(mk.box("Side", (0.2, 2.5, 4.72), (x, 0.08, 5.2), mat=enamel, bevel=0.02, segments=1))
        parts.append(mk.box("Track", (0.08, 0.1, 3.6), (x * 0.96, -1.18, 5.4), mat=dark))
    for k, x in enumerate((-1.74, 0.0, 1.74)):
        parts += [mk.box("Door", (1.62, 0.05, 2.2), (x, -1.2, 1.42), mat=enamel, bevel=0.012, segments=1),
                  mk.box("DoorPull", (0.5, 0.05, 0.06), (x, -1.235, 2.3), mat=steel, bevel=0.012, segments=1)]
    # The sash, raised, its glass left out: it bakes solid.
    for z in (6.4, 7.0):
        parts.append(mk.box("Sash", (4.8, 0.08, 0.14), (0, -1.16, z), mat=dark, bevel=0.012, segments=1))
    parts.append(mk.box("SashBar", (4.5, 0.06, 0.06), (0, -1.22, 6.3), mat=steel))
    # Taps, the gauge, a flask.
    for x in (-2.1, -1.7):
        parts.append(turned("GasTap", [(0.0, 0.0), (0.05, 0.0), (0.03, 0.3), (0.03, 0.4), (0.06, 0.45), (0.0, 0.5)], (x, 0.9, 2.84), (x, 0.9, 3.34), steel, segments=6))
    parts += [mk.cylinder("Gauge", 0.2, 0.05, (2.3, -1.26, 3.6), rot=(90, 0, 0), mat=dark, verts=12), mk.cylinder("GaugeFace", 0.16, 0.012, (2.3, -1.29, 3.6), rot=(90, 0, 0), mat=gauge, verts=12),
              mk.box("SwitchPlate", (0.3, 0.03, 0.6), (2.3, -1.25, 3.0), mat=dark), mk.soften(mk.lathe("Flask", [(0.0, 2.84), (0.3, 2.86), (0.34, 2.96), (0.1, 3.5), (0.08, 3.8), (0.1, 3.82), (0.0, 3.82)], (-0.4, 0.3, 0), mat=glass, segments=10))]
    glows = [mk.box("RoofLight", (3.6, 0.3, 0.05), (0, -0.3, 7.48), mat=pk.glow("FHood_Light", (220, 236, 255), 3)),
             mk.box("Status", (0.1, 0.012, 0.06), (2.3, -1.274, 3.2), mat=pk.glow("FHood_Status", (90, 255, 140), 3))]
    return parts, glows


@prop("ExecutiveDesk", pivot="bottom", material="Wood", collide=True, texture=512, set="Agency", exact=True, normal=128)
def executive_desk():
    """The director's desk, its back to the visitor: dark walnut with a moulded edge and a tooled green leather top, pedestals of drawers with brass pulls on the director's side, fielded
    panels toward the room, a brass banker's lamp, a pen stand, the nameplate facing the visitor, a dossier with its red tab and a telephone."""
    wood = mk.wood("Exec_Wood", srgb(70, 40, 26), srgb(34, 18, 12), scale=5)
    field = mk.wood("ExecField_Wood", srgb(84, 50, 32), srgb(46, 26, 16), scale=5)
    leather = mk.noisy("Exec_Leather", srgb(24, 56, 40), srgb(44, 84, 60), scale=20, roughness=0.5)
    gilt = pk.metal("Exec_Gold", (150, 118, 60), (200, 168, 96), rough=0.4, metallic=1.0)
    brass = pk.metal("Exec_Brass", (150, 118, 60), (206, 170, 96), rough=0.25, metallic=0.9)
    dark = pk.metal("Exec_Dark", (20, 20, 22), (34, 34, 38), rough=0.5, metallic=0.2)
    folder = mk.noisy("Exec_Folder", srgb(120, 30, 34), srgb(150, 44, 46), roughness=0.7)
    green = mk.noisy("ExecShade_Plastic", srgb(18, 74, 46), srgb(34, 110, 72), roughness=0.14)
    paper = mk.noisy("Exec_Paper", srgb(214, 208, 192), srgb(238, 232, 216), roughness=0.9)
    w, d, h = 6.6, 3.2, 2.7
    parts = [pk.rounded("Top", (w, d, 0.12), (0, 0, h - 0.06), wood, r=0.04),
             mk.box("TopMould", (w - 0.12, d - 0.12, 0.08), (0, 0, h - 0.16), mat=field, bevel=0.02, segments=1),
             mk.box("Inlay", (w - 1.0, d - 0.8, 0.014), (0, 0.06, h + 0.002), mat=leather),
             mk.box("Apron", (w - 3.2, d - 0.3, 0.3), (0, 0, h - 0.34), mat=wood),
             mk.box("Modesty", (w - 3.2, 0.1, 1.9), (0, -d / 2 + 0.3, h - 1.15), mat=wood)]
    for y in (d / 2 - 0.4 + 0.04, -d / 2 + 0.4 + 0.08):
        parts.append(mk.box("Tooling", (w - 1.08, 0.012, 0.004), (0, y, h + 0.011), mat=gilt))
    for x in (-(w - 1.08) / 2, (w - 1.08) / 2):
        parts.append(mk.box("Tooling", (0.012, d - 0.86, 0.004), (x, 0.06, h + 0.011), mat=gilt))
    for side in (-1, 1):
        x = side * (w / 2 - 0.85)
        parts += [mk.box("Pedestal", (1.5, d - 0.3, h - 0.3), (x, 0, (h - 0.3) / 2 + 0.06), mat=wood),
                  pk.rounded("Plinth", (1.6, d - 0.2, 0.16), (x, 0, 0.08), wood, r=0.02),
                  mk.box("Field", (1.2, 0.03, 1.8), (x, -d / 2 + 0.135, 1.3), mat=field, bevel=0.012, segments=1)]
        for k in range(3):
            z = 0.56 + k * 0.72
            parts += [mk.box("Drawer", (1.3, 0.05, 0.64), (x, d / 2 - 0.13, z), mat=field, bevel=0.012, segments=1),
                      mk.box("Pull", (0.46, 0.06, 0.05), (x, d / 2 - 0.09, z + 0.12), mat=brass, bevel=0.012, segments=1),
                      mk.box("KeyPlate", (0.08, 0.012, 0.14), (x, d / 2 - 0.1, z - 0.14), mat=brass)]
    # On it.
    lx, ly = -2.3, 0.6
    parts += [mk.lathe("LampFoot", [(0.0, h), (0.32, h), (0.34, h + 0.03), (0.28, h + 0.07), (0.08, h + 0.12), (0.05, h + 0.18), (0.0, h + 0.18)], (lx, ly, 0), mat=brass, segments=14),
              bar("LampStem", spline([(lx, ly, h + 0.16), (lx, ly - 0.01, h + 0.8), (lx, ly - 0.1, h + 1.2), (lx, ly - 0.26, h + 1.34)], 3), 0.03, brass, sides=5),
              mk.soften(mk.cylinder("LampShade", 0.17, 1.2, (lx, ly - 0.28, h + 1.36), rot=(0, 90, 0), mat=green, verts=10)),
              pk.rounded("PenStand", (0.7, 0.36, 0.12), (1.3, 0.8, h + 0.07), brass, r=0.03),
              mk.tube("Pen", (1.2, 0.8, h + 0.12), (1.06, 0.66, h + 0.86), 0.025, mat=dark, verts=5),
              mk.tube("Pen", (1.4, 0.8, h + 0.12), (1.54, 0.66, h + 0.86), 0.025, mat=dark, verts=5),
              mk.box("Nameplate", (1.6, 0.05, 0.3), (0.6, -1.3, h + 0.17), rot=(-20, 0, 0), mat=brass, bevel=0.012, segments=1),
              mk.box("NameplateBase", (1.7, 0.3, 0.04), (0.6, -1.26, h + 0.03), mat=wood, bevel=0.012, segments=1),
              mk.box("Dossier", (1.2, 1.5, 0.1), (1.4, -0.2, h + 0.06), rot=(0, 0, -8), mat=folder, bevel=0.012, segments=1),
              mk.box("DossierPapers", (1.1, 1.42, 0.03), (1.4, -0.2, h + 0.125), rot=(0, 0, -8), mat=paper)]
    phone, lamps = sk.desk_phone("Phone", -0.9, 0.9, h + 0.016, dark, gilt, dark, yaw=180)
    parts += phone
    glows = [mk.box("LampGlow", (1.0, 0.14, 0.03), (lx, ly - 0.3, h + 1.18), mat=pk.glow("Exec_Bulb", LAMP_WARM, 4))] + lamps
    return parts, glows


@prop("XRayScanner", pivot="bottom", material="SmoothPlastic", collide=True, texture=512, set="Agency", exact=True, normal=128)
def xray_scanner():
    """The lobby's baggage X-ray: a rounded steel tunnel over a rubber belt, slatted lead curtains at both mouths, roller tables on legs running out each end, the operator's screen and
    keyboard on an arm, warning plates, a stack of grey trays waiting at the entrance."""
    grey = pk.plastic("Xray_Plastic", (176, 178, 182))
    panel = pk.plastic("XrayPanel_Plastic", (92, 96, 104))
    dark = pk.metal("Xray_Iron", (26, 26, 30), (46, 46, 52), rough=0.5, metallic=0.5)
    belt = pk.rubber("Xray_Rubber")
    curtain = mk.noisy("Xray_Leather", srgb(22, 22, 26), srgb(46, 46, 52), roughness=0.8)
    tray = pk.plastic("XrayTray_Plastic", (66, 72, 84))
    roller = pk.chrome("Xray_Chrome")
    yellow = mk.flat("XrayWarn_Plastic", srgb(226, 180, 30), 0.5)
    print_ = mk.flat("Xray_Print", srgb(20, 20, 22), 0.7)
    keys = lattice("Xray_Keys", (12, 12, 14), (64, 66, 72), 0.1, _axis("X"), _axis("Y"), share=0.4, roughness=0.5, square=True)
    parts = [pk.rounded("Tunnel", (3.3, 3.6, 3.3), (0, 0, 3.0), grey, r=0.3),
             mk.box("Skirt", (3.1, 3.5, 2.0), (0, 0, 1.0), mat=panel, bevel=0.02, segments=1),
             pk.rounded("Bed", (2.5, 9.6, 0.34), (0, 0, 2.38), panel, r=0.05),
             mk.box("Belt", (2.0, 9.4, 0.04), (0, 0, 2.57), mat=belt),
             mk.box("TunnelMouth", (2.3, 0.06, 1.7), (0, -1.79, 3.42), mat=dark),
             mk.box("TunnelMouth", (2.3, 0.06, 1.7), (0, 1.79, 3.42), mat=dark)]
    for sy in (-1, 1):
        for k in range(7):
            parts.append(mk.box("CurtainStrip", (0.3, 0.03, 1.5), (-0.96 + k * 0.32, sy * 1.84, 3.42), mat=curtain))
        for k in range(5):
            parts.append(mk.soften(mk.cylinder("Roller", 0.08, 2.1, (0, sy * (2.5 + k * 0.5), 2.6), rot=(0, 90, 0), mat=roller, verts=8)))
        parts.append(mk.box("SideRailL", (0.08, 3.0, 0.16), (-1.14, sy * 3.3, 2.66), mat=dark))
        parts.append(mk.box("SideRailR", (0.08, 3.0, 0.16), (1.14, sy * 3.3, 2.66), mat=dark))
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(mk.box("Leg", (0.2, 0.2, 2.2), (sx * 1.0, sy * 4.3, 1.1), mat=dark))
            parts.append(mk.cylinder("LegFoot", 0.16, 0.05, (sx * 1.0, sy * 4.3, 0.025), mat=dark, verts=8))
    # The warning plate over the entrance, the operator's station.
    parts += [mk.box("WarnPlate", (1.5, 0.02, 0.34), (0, -1.81, 4.42), mat=yellow), mk.box("WarnPrint", (1.1, 0.006, 0.12), (0, -1.824, 4.42), mat=print_)]
    parts += [bar("ScreenArm", spline([(1.2, -3.0, 2.4), (1.6, -3.0, 3.2), (1.9, -3.0, 4.4)], 2), 0.06, dark, sides=5),
              pk.rounded("Monitor", (1.44, 0.14, 1.0), (1.98, -3.1, 4.96), dark, r=0.03),
              mk.box("KeyShelf", (0.7, 1.1, 0.05), (1.84, -3.0, 3.34), mat=dark),
              mk.box("KeyTops", (0.52, 0.86, 0.02), (1.84, -3.0, 3.38), mat=keys)]
    for k in range(4):
        parts.append(mk.box("Tray", (1.7, 1.3, 0.18), (0, -4.1, 2.74 + k * 0.17), mat=tray, bevel=0.03, segments=1))
    parts[-1].scale = (1.03, 1.03, 1)
    glows = [mk.box("Picture", (1.26, 0.012, 0.84), (1.98, -3.176, 4.96), mat=pk.glow("Xray_Picture", (120, 170, 230), 2)),
             mk.box("Beacon", (0.8, 0.1, 0.1), (0, -1.0, 4.66), mat=pk.glow("Xray_Warn", (255, 190, 60), 3))]
    return parts, glows


# Tokyo --------------------------------------------------------------------------------------------------


@prop("Barricade", pivot="bottom", material="SmoothPlastic", collide=True, texture=512, set="Tokyo", exact=True, normal=128)
def barricade():
    """A Tokyo road-works barricade: two yellow and black boards bolted to folded steel A frames, rubber feet weighted with sandbags, a contractor's plate, a flashing amber lamp on its bracket."""
    board = stripes("Barr_Band", (230, 180, 30), (22, 22, 24), 0.8, roughness=0.5)
    steel = pk.metal("Barr_Steel", (52, 54, 58), (90, 92, 98), rough=0.46, metallic=0.8)
    rubber = pk.rubber("Barr_Rubber")
    sack = mk.noisy("Barr_Sack", srgb(120, 106, 76), srgb(160, 146, 110), roughness=0.9)
    plate = mk.flat("Barr_Plastic", srgb(226, 224, 216), 0.5)
    writing = mk.flat("Barr_Print", srgb(30, 40, 90), 0.7)
    bolt = pk.metal("Barr_Bolt", (110, 112, 118), (150, 152, 158), rough=0.4, metallic=1.0)
    amber = pk.plastic("BarrLens_Plastic", (200, 120, 20))
    parts = [pk.rounded("BoardTop", (4.2, 0.08, 0.4), (0, -0.1, 2.42), board, r=0.02), pk.rounded("BoardLow", (4.2, 0.08, 0.34), (0, -0.1, 1.5), board, r=0.02),
             mk.box("Plate", (0.8, 0.02, 0.28), (0.9, -0.15, 1.5), mat=plate), mk.box("PlateLine", (0.56, 0.006, 0.08), (0.9, -0.163, 1.5), mat=writing)]
    for x in (-1.6, 1.6):
        for sy in (-1, 1):
            parts.append(mk.tube("FrameLeg", (x, sy * 0.96, 0.08), (x, sy * 0.05, 2.76), 0.055, mat=steel, verts=6))
        parts += [mk.box("FrameHead", (0.14, 0.26, 0.1), (x, 0, 2.76), mat=steel, bevel=0.015, segments=1), mk.box("Brace", (0.06, 1.3, 0.05), (x, 0, 0.96), mat=steel),
                  mk.box("FootRubber", (0.3, 2.1, 0.08), (x, 0, 0.04), mat=rubber, bevel=0.015, segments=1), cushion("Sandbag", (0.6, 1.0, 0.26), (x, 0.5, 0.2), sack, e=0.6, segments=10, rings=5)]
    parts.append(studs("Bolt", [(sx * 1.6, -0.145, z) for sx in (-1, 1) for z in (2.42, 1.5)], 0.05, 0.016, bolt, facing=(0, -1, 0)))
    parts += [mk.box("LampBracket", (0.1, 0.1, 0.34), (1.6, 0, 2.96), mat=steel), mk.cylinder("LampBase", 0.17, 0.1, (1.6, 0, 3.08), mat=amber, verts=10)]
    return parts, [mk.soften(mk.sphere("Lamp", 0.15, (1.6, 0, 3.16), mat=pk.glow("Barr_Lamp", (255, 140, 30), 3), segments=8, rings=5))]


@prop("TrafficCone", pivot="bottom", material="Plastic", collide=False, texture=512, set="Tokyo", exact=True)
def traffic_cone():
    """A road cone: a moulded orange body with its ridges and open top, two reflective white sleeves, a black rubber base with its corners and a hollow stepped into it."""
    orange = mk.noisy("Cone_Plastic", srgb(190, 70, 20), srgb(232, 100, 30), roughness=0.4)
    sleeve = mk.flat("ConeSleeve_Plastic", srgb(232, 232, 226), 0.3)
    rubber = pk.rubber("Cone_Rubber")
    profile = [(0.46, 0.14), (0.4, 0.34), (0.36, 0.5), (0.3, 0.86), (0.25, 1.1), (0.2, 1.42), (0.15, 1.72), (0.11, 2.02), (0.1, 2.14), (0.075, 2.14), (0.075, 2.0)]
    parts = [mk.soften(mk.lathe("Body", profile, mat=orange, segments=14, caps=False)),
             mk.lathe("SleeveLow", [(0.37, 0.76), (0.345, 0.96)], mat=sleeve, segments=14, caps=False),
             mk.lathe("SleeveHigh", [(0.245, 1.34), (0.215, 1.56)], mat=sleeve, segments=14, caps=False),
             pk.rounded("Base", (1.2, 1.2, 0.1), (0, 0, 0.05), rubber, r=0.04),
             mk.lathe("BaseCollar", [(0.5, 0.1), (0.52, 0.12), (0.47, 0.17)], mat=rubber, segments=14, caps=False)]
    parts[1].scale = parts[2].scale = (1.01, 1.01, 1.0)
    return parts, []
