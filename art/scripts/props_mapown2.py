"""The rest of the case maps' own models (see props_mapown.py and maps/ownprops.py): the things that were still the same model in
two or three maps, each made again for the map it stands in. Each keeps the footprint, pivot, collision and lights of what it
stands for, so walk checks, colliders and a room's light hold.

- Bureau HQ: a snack vendor, a drinks cooler, a canteen kiosk, security turnstiles, an honours case, a comparison microscope,
  counter stools, waste bins, a steel planter, evidence racks, a floor lamp, range targets, its own barrier tape.
- Kagegaoka University: a coffee vendor, a canteen chiller, a push-button ticket machine, a stone drinking fountain, a cork
  notice board, granite planters, timber barriers, bamboo scaffold screens, an old telegraph pole, a student's bicycle, a
  soapstone fume hood, a mimeograph, a film reader, a club's amp and microphone, wooden bin stores, a reading lamp, a timber
  bus shelter, and the parked cars under snow.
- Tokyo: a water server and a ward notice board."""

import math
import random

import bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree

import modelkit as mk
import propkit as pk
import stationkit as sk
from common import srgb
from props import BUILDERS, prop
from props_campus import snow
from props_mapown import _axis, _plus, bar, blade, cushion, hoop, lattice, leaf, spline, studs, turned
from props_tokyo import bicycle_parts


def stripes(name, a, b, frequency, roughness=0.4):
    """Clean diagonal bands (barrier tape, hazard marks)."""
    mat = mk.banded(name, srgb(*a), srgb(*b), frequency=frequency, axis="DIAGONAL", roughness=roughness)
    for node in mat.node_tree.nodes:
        if node.bl_idname == "ShaderNodeTexWave":
            node.inputs["Distortion"].default_value = 0.0
        if node.bl_idname == "ShaderNodeValToRGB":
            node.color_ramp.interpolation = "CONSTANT"
            node.color_ramp.elements[1].position = 0.5
    return mat


def tape(name, mat, length=8.4, tall=0.3, sag=0.2, rows=16):
    """A barrier tape hung along X: a ribbon sagging between its ends, a little twisted, both faces."""
    points, faces = [], []
    for k in range(rows + 1):
        t = k / rows
        x = -length / 2 + length * t
        z = -sag * 4 * t * (1 - t) + sag / 2
        y = 0.03 * math.sin(t * 9)
        points += [(x, y - 0.02 * math.sin(t * 7), z - tall / 2), (x, y + 0.02 * math.sin(t * 7), z + tall / 2)]
        if k:
            n = 2 * k
            faces.append((n - 2, n, n + 1, n - 1))
    return blade(name, points, faces, mat, apart=0.01)


# Bureau HQ ----------------------------------------------------------------------------------------------


VENDOR_LIGHT = [dict(at=(0, -2.325, 4.678), kind="spot", face="Front", angle=160, color=(214, 232, 255), range=10.88, brightness=0.8)]
COOLER_LIGHT = [dict(at=(0, -2.105, 4.0), kind="spot", face="Front", angle=160, color=(214, 232, 255), range=10.0, brightness=0.7)]


@prop("SnackVendor", pivot="bottom", material="SmoothPlastic", collide=True, texture=512, set="Agency", exact=True, normal=128,
      lights=VENDOR_LIGHT)
def snack_vendor():
    """The Bureau's snack machine in black steel: five shelves of bags and bars on steel spirals behind an open window, a lit
    strip over them, the keypad, display, card reader and coin slot in the side panel, a push flap over the pick-up bay."""
    steel = pk.metal("SVend_Steel", (22, 23, 26), (46, 48, 52), rough=0.45, metallic=0.6)
    liner = mk.flat("SVend_Plastic", srgb(40, 44, 50), 0.5)
    wire = pk.metal("SVend_Chrome", (120, 124, 130), (176, 180, 186), rough=0.3, metallic=1.0)
    rail = mk.flat("SVendRail_Plastic", srgb(214, 214, 208), 0.5)
    dark = mk.flat("SVendDark_Plastic", srgb(8, 8, 10), 0.6)
    keys = lattice("SVend_Keys", (20, 21, 24), (170, 172, 176), 0.13, _axis("X"), _axis("Z"), share=0.34, roughness=0.5, square=True)
    wraps = [mk.flat(f"SVendWrap{i}_Plastic", srgb(*c), 0.35) for i, c in enumerate(((168, 34, 34), (216, 170, 40), (34, 86, 150), (40, 120, 70),
                                                                                     (210, 206, 196), (120, 60, 130)))]
    rng = random.Random(4)
    front = -1.5
    parts = [mk.box("Body", (4.0, 2.2, 7.1), (0, 0.4, 3.55), mat=steel, bevel=0.03, segments=1),
             mk.box("BackPanel", (2.76, 0.02, 4.7), (-0.5, -0.71, 4.3), mat=liner),
             mk.box("SidePanel", (1.0, 0.82, 7.1), (1.5, -1.09, 3.55), mat=steel, bevel=0.02, segments=1),
             mk.box("PillarL", (0.12, 0.82, 7.1), (-1.94, -1.09, 3.55), mat=steel, bevel=0.015, segments=1),
             mk.box("PillarM", (0.1, 0.82, 7.1), (0.95, -1.09, 3.55), mat=steel, bevel=0.015, segments=1),
             mk.box("Header", (2.8, 0.82, 0.46), (-0.5, -1.09, 6.87), mat=steel, bevel=0.015, segments=1),
             mk.box("Lower", (2.8, 0.82, 1.9), (-0.5, -1.09, 0.95), mat=steel, bevel=0.015, segments=1),
             mk.box("BayShadow", (2.3, 0.02, 0.62), (-0.5, front - 0.012, 1.2), mat=dark),
             mk.box("Flap", (2.2, 0.04, 0.52), (-0.5, front - 0.03, 1.22), rot=(4, 0, 0), mat=liner, bevel=0.012, segments=1),
             mk.box("FlapBar", (0.9, 0.05, 0.05), (-0.5, front - 0.06, 1.38), mat=wire, bevel=0.012, segments=1),
             mk.box("Kick", (4.0, 0.06, 0.26), (0, front - 0.012, 0.13), mat=dark)]
    for level in range(5):
        z = 2.2 + level * 0.88
        parts.append(mk.box("Shelf", (2.76, 0.76, 0.04), (-0.5, -1.09, z), mat=liner))
        parts.append(mk.box("PriceRail", (2.76, 0.02, 0.09), (-0.5, front + 0.03, z - 0.02), mat=rail))
        for col in range(5):
            x = -1.58 + col * 0.54
            coil = [(x + 0.13 * math.cos(a * 1.1), -0.76 - 0.052 * a, z + 0.16 + 0.13 * math.sin(a * 1.1)) for a in range(0, 13)]
            parts.append(bar("Spiral", coil, 0.012, wire, sides=3))
            wrap = rng.choice(wraps)
            tall = rng.uniform(0.46, 0.6)
            for y in (-1.28, -1.02):
                parts.append(mk.box("Packet", (0.4, 0.09, tall), (x, y, z + 0.04 + tall / 2), rot=(0, 0, rng.uniform(-3, 3)), mat=wrap))
    # The side panel.
    px = 1.5
    parts += [mk.box("ScreenBezel", (0.74, 0.03, 0.3), (px, front - 0.012, 5.7), mat=dark),
              mk.box("Keypad", (0.6, 0.016, 0.8), (px, front - 0.008, 4.9), mat=keys),
              mk.box("CardReader", (0.56, 0.08, 0.3), (px, front - 0.04, 4.2), mat=dark, bevel=0.012, segments=1),
              mk.box("CoinSlot", (0.05, 0.02, 0.16), (px - 0.2, front - 0.01, 3.72), mat=wire),
              mk.box("NoteSlot", (0.34, 0.02, 0.05), (px + 0.1, front - 0.01, 3.72), mat=wire),
              mk.box("CoinReturn", (0.4, 0.05, 0.3), (px, front - 0.02, 1.4), mat=wire, bevel=0.012, segments=1)]
    glows = [mk.box("Strip", (2.6, 0.06, 0.04), (-0.5, -1.36, 6.58), mat=pk.glow("SVend_Light", (226, 240, 255), 3)),
             mk.box("Display", (0.64, 0.012, 0.2), (px, front - 0.03, 5.7), mat=pk.glow("SVend_Display", (90, 255, 140), 3))]
    return parts, glows


@prop("BureauCooler", pivot="bottom", material="Metal", collide=True, texture=512, set="Agency", exact=True, normal=128, lights=COOLER_LIGHT)
def bureau_cooler():
    """The break room's three door drinks cooler: a stainless cabinet with aluminium door frames over white-lit shelves of water
    bottles, cans and juice cartons, long bar handles, a louvred compressor grille and a thermometer in the header."""
    steel = pk.metal("BCool_Chrome", (120, 124, 130), (172, 176, 182), rough=0.32, metallic=0.9)
    frame = pk.metal("BCool_Alu", (84, 88, 94), (130, 134, 140), rough=0.35, metallic=0.9)
    liner = mk.flat("BCool_Plastic", srgb(196, 206, 214), 0.4)
    grille = lattice("BCool_Grille", (70, 74, 80), (10, 10, 12), 0.1, _axis("X"), _axis("Z"), share=0.36, roughness=0.45, metallic=0.5, square=True)
    water = mk.noisy("BCoolWater_Plastic", srgb(120, 168, 204), srgb(170, 208, 232), roughness=0.2)
    cap = mk.flat("BCoolCap_Plastic", srgb(30, 70, 150), 0.4)
    cans = [mk.flat(f"BCoolCan{i}_Plastic", srgb(*c), 0.3) for i, c in enumerate(((168, 30, 34), (190, 192, 196), (30, 60, 130)))]
    carton = mk.flat("BCoolCarton_Plastic", srgb(226, 196, 60), 0.5)
    dark = mk.flat("BCoolDark_Plastic", srgb(10, 10, 12), 0.5)
    front = -1.42
    parts = [mk.box("Body", (8.2, 2.3, 7.0), (0, 0.25, 3.5), mat=steel, bevel=0.03, segments=1),
             mk.box("Interior", (7.8, 0.02, 5.2), (0, front + 0.54, 3.65), mat=liner),
             mk.box("Header", (8.2, 0.62, 0.74), (0, -1.06, 6.63), mat=steel, bevel=0.02, segments=1),
             mk.box("Plinth", (8.2, 0.62, 0.96), (0, -1.06, 0.48), mat=steel, bevel=0.02, segments=1),
             mk.box("Grille", (7.6, 0.012, 0.62), (0, front - 0.012, 0.5), mat=grille),
             mk.box("Thermometer", (0.8, 0.02, 0.32), (3.1, front - 0.012, 6.63), mat=dark)]
    for k in range(4):
        parts.append(mk.box("Mullion", (0.16, 0.58, 5.3), (-3.98 + k * 2.653, -1.14, 3.6), mat=steel))
    for k in range(3):
        x = -2.65 + k * 2.653
        for z, wide in ((6.14, 2.5), (1.08, 2.5)):
            parts.append(mk.box("DoorRail", (wide, 0.08, 0.16), (x, front + 0.03, z), mat=frame, bevel=0.012, segments=1))
        for dx in (-1.22, 1.22):
            parts.append(mk.box("DoorStile", (0.1, 0.08, 5.0), (x + dx, front + 0.03, 3.6), mat=frame, bevel=0.012, segments=1))
        parts.append(bar("Handle", [(x + 1.06, front - 0.1, 2.6), (x + 1.06, front - 0.1, 4.6)], 0.04, steel))
        for dz in (2.6, 4.6):
            parts.append(mk.box("HandleFoot", (0.07, 0.1, 0.07), (x + 1.06, front - 0.05, dz), mat=steel))
        for level in range(5):
            z = 1.3 + level * 0.96
            parts.append(mk.box("Shelf", (2.4, 0.5, 0.03), (x, -1.14, z), mat=frame))
            for col in range(6):
                bx = x - 1.0 + col * 0.4
                if k == 0:  # (water)
                    parts.append(mk.soften(mk.lathe("Water", [(0.0, 0.0), (0.13, 0.0), (0.14, 0.05), (0.14, 0.42), (0.06, 0.58), (0.05, 0.66), (0.0, 0.66)],
                                                    (bx, -1.14, z + 0.015), mat=water, segments=6)))
                    parts.append(mk.cylinder("Cap", 0.055, 0.05, (bx, -1.14, z + 0.68), mat=cap, verts=6))
                elif k == 1:  # (cans, two deep)
                    can = cans[(col + level) % 3]
                    for y in (-1.26, -1.02):
                        parts.append(mk.soften(mk.cylinder("Can", 0.12, 0.46, (bx, y, z + 0.245), mat=can, verts=6)))
                else:  # (juice cartons)
                    parts.append(mk.box("Carton", (0.28, 0.3, 0.6), (bx, -1.14, z + 0.315), mat=carton))
    glows = [mk.box("Strip", (7.7, 0.05, 0.04), (0, -0.96, 6.2), mat=pk.glow("BCool_Light", (226, 240, 255), 3)),
             mk.box("Readout", (0.6, 0.012, 0.18), (3.1, front - 0.026, 6.63), mat=pk.glow("BCool_Readout", (120, 200, 255), 3))]
    return parts, glows


@prop("CanteenKiosk", pivot="bottom", material="Metal", collide=True, texture=512, set="Agency", exact=True, normal=128)
def canteen_kiosk():
    """The Bureau canteen's meal kiosk: a brushed steel pedestal on a floor plate, a raked touch screen in a black head, a badge
    reader ringed in light, a card slot and a receipt printer."""
    steel = pk.metal("CKiosk_Chrome", (110, 114, 120), (164, 168, 174), rough=0.34, metallic=0.9)
    black = pk.metal("CKiosk_Iron", (14, 14, 16), (36, 36, 40), rough=0.4, metallic=0.5)
    plastic = mk.flat("CKiosk_Plastic", srgb(26, 27, 30), 0.4)
    bolt = pk.metal("CKiosk_Bolt", (110, 112, 118), (150, 152, 158), rough=0.4, metallic=1.0)
    head = (0, -0.1, 4.46)
    parts = [pk.rounded("Plate", (2.0, 1.7, 0.1), (0, 0, 0.05), black, r=0.03),
             sk.wedge("Column", [(-0.46, 0.1), (0.46, 0.1), (0.42, 3.3), (0.1, 3.7), (-0.42, 3.5)], 1.3, 0.0, steel, bevel=0.02),
             sk.wedge("Shoulder", [(-0.6, 3.0), (0.5, 3.0), (0.5, 3.6), (-0.6, 3.3)], 1.5, 0.0, black, bevel=0.02)]
    screen = pk.rounded("Head", (2.5, 0.2, 1.9), head, black, r=0.05)
    bezel = mk.box("Bezel", (2.2, 0.02, 1.56), (head[0], head[1] - 0.11, head[2]), mat=plastic)
    lit = mk.box("Screen", (2.1, 0.012, 1.46), (head[0], head[1] - 0.122, head[2]), mat=pk.glow("CKiosk_Screen", (120, 180, 220), 2.2))
    sk.tilt_about([screen, bezel, lit], head, 16)
    parts += [screen, bezel]
    parts.append(studs("Anchor", [(sx * 0.85, sy * 0.7, 0.1) for sx in (-1, 1) for sy in (-1, 1)], 0.05, 0.02, bolt))
    # The shelf under the screen: the badge reader, a card slot, the printer.
    parts += [sk.wedge("Ledge", [(-0.86, 3.28), (-0.56, 3.28), (-0.56, 3.5), (-0.86, 3.34)], 1.7, 0.0, black, bevel=0.01),
              mk.box("Slot", (0.5, 0.02, 0.04), (-0.5, -0.74, 3.46), mat=bolt),
              mk.box("Receipt", (0.56, 0.05, 0.1), (0.5, -0.74, 3.46), mat=bolt, bevel=0.012, segments=1)]
    ring = mk.torus("BadgeRing", 0.17, 0.018, (0, -0.862, 3.1), rot=(90, 0, 0), mat=pk.glow("CKiosk_Ring", (120, 220, 170), 3), major_segments=14,
                    minor_segments=4)
    parts.append(mk.cylinder("BadgePad", 0.15, 0.02, (0, -0.48, 3.1), rot=(90, 0, 0), mat=plastic, verts=12))
    ring.location = (0, -0.5, 3.1)
    return parts, [lit, ring]


@prop("BureauTape", pivot="centre", material="Plastic", collide=True, texture=256, set="Agency", exact=True)
def bureau_tape():
    """The Bureau's barrier tape: navy ribbon with white diagonal bands, hung with a little sag."""
    return [tape("Ribbon", stripes("BTape_Band", (16, 24, 58), (222, 224, 228), 0.7))], []


@prop("SecurityGate", pivot="bottom", material="Metal", collide=True, texture=512, set="Agency", exact=True, normal=128)
def security_gate():
    """A lobby security turnstile: a stainless pedestal with a black glass top, smoked flaps closed across the lane, a badge reader
    and status lamp at the entry end, the arrow bars along its sides, a floor plinth."""
    steel = pk.metal("SGate_Chrome", (116, 120, 126), (170, 174, 180), rough=0.32, metallic=0.9)
    black = mk.noisy("SGate_Plastic", srgb(10, 11, 13), srgb(30, 32, 36), roughness=0.14)
    smoke = mk.noisy("SGateFlap_Plastic", srgb(30, 36, 44), srgb(52, 62, 74), roughness=0.12)
    dark = pk.metal("SGate_Iron", (14, 14, 16), (34, 34, 38), rough=0.5, metallic=0.5)
    parts = [pk.rounded("Body", (1.1, 5.0, 3.1), (0, 0, 1.64), steel, r=0.1),
             mk.box("Plinth", (1.0, 4.9, 0.1), (0, 0, 0.05), mat=dark),
             pk.rounded("TopGlass", (1.2, 5.1, 0.12), (0, 0, 3.24), black, r=0.04),
             pk.rounded("ReaderHead", (0.76, 0.86, 0.2), (0, -1.9, 3.38), dark, r=0.05)]
    for sx in (-1, 1):
        parts += [mk.box("Flap", (0.86, 0.06, 1.5), (sx * 0.98, 0.3, 2.1), mat=smoke, bevel=0.02, segments=1),
                  mk.box("FlapHub", (0.1, 0.34, 1.6), (sx * 0.56, 0.3, 2.1), mat=dark, bevel=0.015, segments=1),
                  mk.box("Seam", (0.012, 4.7, 0.03), (sx * 0.553, 0, 1.2), mat=dark)]
    parts.append(mk.box("EndSeam", (0.9, 0.012, 0.03), (0, -2.503, 1.2), mat=dark))
    glows = [mk.box("Reader", (0.5, 0.5, 0.02), (0, -1.9, 3.49), mat=pk.glow("SGate_Reader", (90, 170, 255), 3)),
             mk.box("Lamp", (0.5, 0.012, 0.3), (0, -2.56, 2.7), mat=pk.glow("SGate_Lamp", (90, 255, 170), 3))]
    for sx in (-1, 1):
        glows.append(mk.box("Rail", (0.012, 3.0, 0.05), (sx * 0.556, -0.7, 2.94), mat=pk.glow("SGate_Rail", (90, 170, 255), 2)))
    return parts, glows


@prop("HonorCase", pivot="bottom", material="Metal", collide=True, texture=512, set="Agency", exact=True, normal=128)
def honor_case():
    """The Bureau's honours case: a black steel cabinet with an open brushed steel frame over charcoal felt, the fallen's badges in a
    row, a folded flag, a bronze plaque on its easel, a strip light under the top rail. (Open: glass bakes solid.)"""
    steel = pk.metal("HCase_Iron", (18, 19, 22), (44, 46, 50), rough=0.42, metallic=0.7)
    bright = pk.metal("HCase_Chrome", (120, 124, 130), (172, 176, 182), rough=0.3, metallic=1.0)
    felt = mk.noisy("HCase_Felt", srgb(24, 26, 32), srgb(44, 46, 54), roughness=0.9)
    gold = pk.metal("HCase_Gold", (170, 134, 62), (226, 190, 104), rough=0.25, metallic=1.0)
    bronze = pk.metal("HCase_Brass", (92, 66, 36), (140, 104, 62), rough=0.4, metallic=1.0)
    flag = mk.flat("HCase_Cloth", srgb(22, 30, 66), 0.8)
    star = mk.flat("HCaseStar_Cloth", srgb(216, 214, 206), 0.8)
    wood = mk.wood("HCase_Wood", srgb(70, 44, 27), srgb(44, 27, 17), roughness=0.4)
    parts = [pk.rounded("Cabinet", (5.96, 2.3, 2.2), (0, 0, 1.2), steel, r=0.03),
             mk.box("Kick", (5.8, 2.2, 0.12), (0, 0, 0.06), mat=steel),
             pk.rounded("TopBoard", (6.1, 2.46, 0.1), (0, 0, 2.34), wood, r=0.03),
             mk.box("Felt", (5.8, 2.2, 0.04), (0, 0, 2.4), mat=felt)]
    for k in range(3):
        x = -2.0 + k * 2.0
        parts.append(mk.box("Door", (1.86, 0.04, 1.8), (x, -1.165, 1.2), mat=steel, bevel=0.012, segments=1))
        parts.append(mk.box("Pull", (0.6, 0.05, 0.05), (x, -1.2, 1.9), mat=bright, bevel=0.012, segments=1))
    for x in (-3.0, 3.0):
        for y in (-1.16, 1.16):
            parts.append(mk.box("Corner", (0.08, 0.08, 1.06), (x, y, 2.93), mat=bright))
        parts.append(mk.box("Rail", (0.08, 2.24, 0.08), (x, 0, 3.47), mat=bright))
    for y in (-1.16, 1.16):
        parts.append(mk.box("Rail", (6.08, 0.08, 0.08), (0, y, 3.47), mat=bright))
    z = 2.42
    # The badges, each a shield on the felt.
    shield = [(-0.15, 0.12), (-0.17, -0.02), (-0.09, -0.15), (0.0, -0.2), (0.09, -0.15), (0.17, -0.02), (0.15, 0.12), (0.06, 0.1), (0.0, 0.18), (-0.06, 0.1)]
    for k in range(7):
        x = -1.9 + k * 0.5
        parts.append(mk.extrude_shape("Badge", shield, 0.03, (x, -0.5, z + 0.015), mat=gold))
        parts.append(mk.cylinder("BadgeSeal", 0.06, 0.012, (x, -0.5, z + 0.034), mat=bronze, verts=8))
    # The folded flag and the plaque.
    fold = mk.extrude_shape("FoldedFlag", [(-0.6, 0.0), (0.6, 0.0), (0.0, 0.62)], 0.2, (1.9, 0.35, z + 0.0), rot=(90, 0, 0), mat=flag)
    parts.append(fold)
    parts.append(studs("FlagStar", [(1.9 + dx, 0.24, z + dz) for dx, dz in ((0, 0.28), (-0.17, 0.12), (0.17, 0.12), (0, 0.12))], 0.05, 0.006, star,
                       sides=5, facing=(0, -1, 0)))
    parts += [mk.box("Plaque", (1.5, 0.05, 0.86), (-0.7, 0.4, z + 0.5), rot=(-12, 0, 0), mat=wood, bevel=0.012, segments=1),
              mk.box("PlaquePlate", (1.26, 0.012, 0.64), (-0.7, 0.366, z + 0.5), rot=(-12, 0, 0), mat=bronze),
              mk.box("PlaqueFoot", (0.8, 0.5, 0.05), (-0.7, 0.5, z + 0.025), mat=bright)]
    glows = [mk.box("CaseLight", (5.6, 0.12, 0.04), (0, 0.9, 3.4), mat=pk.glow("HCase_Light", (240, 244, 255), 3))]
    return parts, glows


@prop("ForensicScope", pivot="bottom", material="SmoothPlastic", collide=False, texture=256, set="Agency", exact=True)
def forensic_scope():
    """A comparison microscope from the Bureau's lab: a curved black arm rising off its heavy base, the optical head with two
    objectives side by side over a wide stage, an inclined binocular eyepiece, focus knobs and the lamp in the foot."""
    enamel = mk.noisy("FScope_Plastic", srgb(16, 17, 19), srgb(40, 42, 46), roughness=0.3)
    grey = pk.metal("FScope_Steel", (92, 96, 102), (140, 144, 150), rough=0.34, metallic=0.9)
    chrome = pk.chrome("FScope_Chrome")
    glass = mk.flat("FScope_Glass", srgb(16, 24, 34), 0.1)
    lamp = mk.flat("FScopeLamp_Plastic", srgb(150, 160, 170), 0.2)
    arm = spline([(0, 0.34, 0.08), (0, 0.42, 0.6), (0, 0.4, 1.14), (0, 0.24, 1.44), (0, 0.02, 1.5)], 3)
    parts = [pk.rounded("Base", (0.78, 1.06, 0.1), (0, 0.06, 0.05), enamel, r=0.03),
             bar("Arm", arm, [0.11 - 0.05 * j / (len(arm) - 1) for j in range(len(arm))], enamel),
             pk.rounded("Head", (0.5, 0.34, 0.2), (0, 0.02, 1.46), enamel, r=0.05),
             mk.cylinder("FootLamp", 0.13, 0.05, (0, -0.1, 0.12), mat=lamp, verts=10),
             mk.box("StageArm", (0.16, 0.5, 0.07), (0, 0.24, 0.66), mat=enamel, bevel=0.015, segments=1),
             pk.rounded("Stage", (0.74, 0.5, 0.05), (0, -0.08, 0.7), grey, r=0.012),
             mk.box("Slide", (0.26, 0.1, 0.01), (-0.17, -0.1, 0.73), mat=glass),
             mk.box("Slide", (0.26, 0.1, 0.01), (0.17, -0.1, 0.73), mat=glass),
             turned("Neck", [(0.0, 0.0), (0.075, 0.0), (0.075, 1.0), (0.0, 1.0)], (0, 0.0, 1.54), (0, -0.14, 1.78), enamel)]
    for sx in (-1, 1):
        parts += [turned("Objective", [(0.0, 0.0), (0.03, 0.0), (0.05, 0.3), (0.05, 0.5), (0.07, 0.56), (0.07, 1.0), (0.0, 1.0)], (sx * 0.17, -0.02, 0.86),
                         (sx * 0.17, -0.02, 1.38), grey),
                  mk.cylinder("FocusKnob", 0.1, 0.06, (sx * 0.15, 0.42, 0.52), rot=(0, 90, 0), mat=grey, verts=10),
                  turned("Eyepiece", [(0.0, 0.0), (0.04, 0.0), (0.04, 0.68), (0.056, 0.7), (0.056, 1.0), (0.0, 1.0)], (sx * 0.06, -0.14, 1.76),
                         (sx * 0.085, -0.3, 2.06), chrome, segments=8)]
    return parts, []


@prop("CounterStool", pivot="bottom", material="Metal", collide=True, texture=256, set="Agency", exact=True)
def counter_stool():
    """A canteen counter stool: a chrome pedestal on a round foot, a foot ring, a black vinyl seat with its piped edge."""
    chrome = pk.chrome("CStool_Chrome")
    vinyl = mk.noisy("CStool_Leather", srgb(14, 14, 18), srgb(40, 40, 46), roughness=0.34)
    pipe = mk.noisy("CStoolPipe_Leather", srgb(8, 8, 10), srgb(24, 24, 28), roughness=0.5)
    parts = [mk.lathe("Foot", [(0.0, 0.0), (0.56, 0.0), (0.58, 0.03), (0.36, 0.09), (0.1, 0.16), (0.0, 0.16)], mat=chrome, segments=16),
             turned("Column", [(0.0, 0.0), (0.09, 0.0), (0.07, 0.5), (0.11, 0.8), (0.11, 1.0), (0.0, 1.0)], (0, 0, 0.14), (0, 0, 2.86), chrome, segments=10),
             bar("FootRing", hoop(0.42, 1.0, 14), 0.03, chrome, sides=6),
             mk.soften(mk.lathe("Seat", [(0.0, 2.86), (0.5, 2.86), (0.57, 2.92), (0.58, 3.02), (0.54, 3.12), (0.34, 3.18), (0.0, 3.2)], mat=vinyl, segments=16)),
             bar("Piping", hoop(0.56, 3.0, 16), 0.016, pipe, sides=4)]
    for k in range(3):
        a = math.radians(120 * k)
        parts.append(mk.tube("RingStrut", (0.1 * math.cos(a), 0.1 * math.sin(a), 1.0), (0.42 * math.cos(a), 0.42 * math.sin(a), 1.0), 0.02, mat=chrome, verts=5))
    return parts, []


@prop("OfficeBin", pivot="bottom", material="Metal", collide=True, texture=256, set="Agency", exact=True)
def office_bin():
    """A waste bin in black steel mesh: a rolled rim, a solid foot, its grey liner folded over and crumpled reports inside."""
    mesh = lattice("OBin_Iron", (24, 25, 28), (6, 6, 8), 0.1, lambda n, l, s: _atan(n, l, s), _axis("Z"), share=0.3, roughness=0.5, metallic=0.6)
    rim = pk.metal("OBin_Steel", (34, 36, 40), (60, 62, 68), rough=0.45, metallic=0.8)
    liner = mk.flat("OBinLiner_Plastic", srgb(70, 72, 76), 0.6)
    paper = mk.noisy("OBin_Paper", srgb(206, 204, 196), srgb(236, 234, 226), roughness=0.9)
    parts = [mk.lathe("Mesh", [(0.5, 0.1), (0.62, 2.4)], mat=mesh, segments=16, caps=False),
             mk.lathe("Foot", [(0.0, 0.0), (0.52, 0.0), (0.53, 0.16), (0.0, 0.16)], mat=rim, segments=16),
             bar("Rim", hoop(0.63, 2.42, 16), 0.04, rim, sides=5),
             mk.lathe("Liner", [(0.0, 1.8), (0.56, 1.9), (0.585, 2.42)], mat=liner, segments=16, caps=False)]
    rng = random.Random(2)
    for k in range(6):
        a, r = rng.uniform(0, 6.28), rng.uniform(0.05, 0.34)
        ball = mk.sphere("Crumple", rng.uniform(0.16, 0.22), (r * math.cos(a), r * math.sin(a), 2.0 + rng.uniform(0, 0.28)), mat=paper, segments=6, rings=4)
        parts.append(ball)
    return parts, []


def _atan(nodes, links, split):
    """The angle round the Z axis, in studs round a bin's side (for a grid that wraps a round thing)."""
    node = nodes.new("ShaderNodeMath")
    node.operation = "ARCTAN2"
    links.new(split.outputs["Y"], node.inputs[0])
    links.new(split.outputs["X"], node.inputs[1])
    scale = nodes.new("ShaderNodeMath")
    scale.operation = "MULTIPLY"
    links.new(node.outputs[0], scale.inputs[0])
    scale.inputs[1].default_value = 0.56
    return scale.outputs[0]


@prop("SteelPlanter", pivot="bottom", material="Metal", collide=True, texture=512, set="Agency", exact=True, normal=128, ao=0.3)
def steel_planter():
    """A long atrium planter in brushed steel on short legs: a folded rim, grey pebbles and a hedge of upright snake plants."""
    steel = pk.metal("SPlant_Chrome", (96, 100, 106), (150, 154, 160), rough=0.36, metallic=0.9)
    dark = pk.metal("SPlant_Iron", (18, 18, 20), (40, 40, 44), rough=0.5, metallic=0.6)
    soil = mk.noisy("SPlant_Soil", srgb(24, 22, 20), srgb(46, 42, 38), roughness=1.0)
    pebble = mk.noisy("SPlant_Stone", srgb(90, 92, 96), srgb(140, 142, 146), roughness=0.8)
    leaves = [mk.noisy("SPlant_Leaf", srgb(22, 52, 34), srgb(52, 92, 56), roughness=0.4), mk.noisy("SPlant_LeafPale", srgb(40, 74, 44), srgb(84, 118, 62), roughness=0.4)]
    parts = [pk.rounded("Trough", (6.4, 1.8, 1.3), (0, 0, 0.95), steel, r=0.03),
             mk.box("RimFront", (6.52, 0.1, 0.06), (0, -0.92, 1.62), mat=steel, bevel=0.012, segments=1),
             mk.box("RimBack", (6.52, 0.1, 0.06), (0, 0.92, 1.62), mat=steel, bevel=0.012, segments=1),
             mk.box("RimL", (0.1, 1.74, 0.06), (-3.22, 0, 1.62), mat=steel, bevel=0.012, segments=1),
             mk.box("RimR", (0.1, 1.74, 0.06), (3.22, 0, 1.62), mat=steel, bevel=0.012, segments=1),
             mk.box("Soil", (6.2, 1.66, 0.04), (0, 0, 1.6), mat=soil)]
    for x in (-2.8, 2.8):
        for y in (-0.7, 0.7):
            parts.append(mk.box("Leg", (0.14, 0.14, 0.32), (x, y, 0.16), mat=dark))
    rng = random.Random(77)
    for k in range(34):
        x, y = rng.uniform(-2.9, 2.9), rng.uniform(-0.66, 0.66)
        parts.append(mk.sphere("Pebble", rng.uniform(0.06, 0.1), (x, y, 1.63), scale=(1, 0.8, 0.6), mat=pebble, segments=5, rings=3))
    for k in range(34):
        x, y = rng.uniform(-2.9, 2.9), rng.uniform(-0.55, 0.55)
        a = rng.uniform(0, 6.28)
        out = Vector((0.14 * math.cos(a), 0.14 * math.sin(a), 1.0))
        side = Vector((-math.sin(a), math.cos(a), 0))
        parts.append(leaf("Blade", (x, y, 1.6), out, side, rng.uniform(0.8, 1.26), rng.uniform(0.07, 0.1), 0.05, leaves[k % 2], rows=3, fold=0.3))
    return parts, []


@prop("EvidenceRack", pivot="bottom", material="Metal", collide=True, texture=512, set="Agency", exact=True, normal=128)
def evidence_rack():
    """The evidence room's wire rack: black posts with four wire shelves of sealed paper bags, tagged boxes and labelled jars, a red
    seal on each bag and a string tag on the rail."""
    post = pk.metal("ERack_Iron", (20, 21, 24), (44, 46, 50), rough=0.45, metallic=0.7)
    wire = lattice("ERack_Steel", (10, 10, 12), (120, 124, 130), 0.14, _axis("X"), _axis("Y"), share=0.42, roughness=0.4, metallic=0.8, square=True)
    bag = mk.noisy("ERack_Paper", srgb(170, 142, 100), srgb(204, 176, 130), roughness=0.85)
    box = mk.noisy("ERack_Card", srgb(116, 112, 104), srgb(146, 142, 132), roughness=0.85)
    seal = mk.flat("ERack_Plastic", srgb(160, 24, 30), 0.4)
    tag = mk.noisy("ERack_Label", srgb(214, 208, 190), srgb(238, 232, 214), roughness=0.9)
    jar = mk.noisy("ERackJar_Plastic", srgb(70, 84, 86), srgb(120, 136, 136), roughness=0.16)
    lid = mk.flat("ERackLid_Plastic", srgb(26, 26, 30), 0.4)
    w, d = 5.1, 1.7
    parts = []
    for x in (-w / 2 + 0.07, w / 2 - 0.07):
        for y in (-d / 2 + 0.07, d / 2 - 0.07):
            parts.append(mk.box("Post", (0.14, 0.14, 7.5), (x, y, 3.75), mat=post, bevel=0.015, segments=1))
    rng = random.Random(33)
    levels = (0.5, 2.15, 3.8, 5.45, 7.1)
    for z in levels:
        parts.append(mk.box("Wire", (w - 0.1, d - 0.1, 0.03), (0, 0, z), mat=wire))
        parts.append(mk.box("Lip", (w - 0.1, 0.05, 0.08), (0, -d / 2 + 0.03, z - 0.03), mat=post))
    for n, z in enumerate(levels[:-1]):
        z += 0.02
        x = -w / 2 + 0.34
        while x < w / 2 - 0.6:
            kind = rng.randrange(3)
            if kind == 0:  # (a sealed bag)
                wide, tall = rng.uniform(0.6, 0.8), rng.uniform(0.9, 1.24)
                parts.append(mk.box("Bag", (wide, 0.7, tall), (x + wide / 2, -0.1, z + tall / 2), rot=(0, 0, rng.uniform(-3, 3)), mat=bag, bevel=0.02, segments=1))
                parts.append(mk.box("Seal", (wide + 0.02, 0.72, 0.09), (x + wide / 2, -0.1, z + tall - 0.16), mat=seal))
                parts.append(mk.box("BagLabel", (0.4, 0.008, 0.3), (x + wide / 2, -0.46, z + tall * 0.42), mat=tag))
            elif kind == 1:  # (a box)
                wide, tall = 0.96, 0.84
                parts.append(mk.box("Box", (wide, 1.1, tall), (x + wide / 2, 0.0, z + tall / 2), mat=box, bevel=0.012, segments=1))
                parts.append(mk.box("BoxTape", (wide + 0.01, 0.1, tall + 0.01), (x + wide / 2, -0.28, z + tall / 2), mat=seal))
                parts.append(mk.box("BoxLabel", (0.5, 0.008, 0.28), (x + wide / 2, -0.556, z + tall * 0.6), mat=tag))
            else:  # (two jars)
                wide = 0.76
                for dx in (0.2, 0.56):
                    parts.append(mk.soften(mk.lathe("Jar", [(0.0, 0.0), (0.16, 0.0), (0.17, 0.05), (0.17, 0.5), (0.12, 0.58), (0.0, 0.58)], (x + dx, -0.2, z),
                                                    mat=jar, segments=8)))
                    parts.append(mk.cylinder("JarLid", 0.13, 0.08, (x + dx, -0.2, z + 0.61), mat=lid, verts=8))
                    parts.append(mk.box("JarLabel", (0.2, 0.008, 0.16), (x + dx, -0.372, z + 0.26), mat=tag))
            x += wide + 0.08
    return parts, []


@prop("BureauFloorLamp", pivot="bottom", material="Metal", collide=True, texture=256, set="Agency", exact=True,
      lights=[dict(at=(0, 0, 5.4), kind="point", color=(255, 210, 150), range=15, brightness=0.9)])
def bureau_floor_lamp():
    """An office floor lamp: a black steel tube on a weighted round foot, a grey drum shade over its bulb, the cord down the stem."""
    steel = pk.metal("BLamp_Iron", (20, 21, 24), (46, 48, 52), rough=0.42, metallic=0.8)
    shade = mk.noisy("BLamp_Cloth", srgb(92, 92, 92), srgb(128, 128, 126), roughness=0.9)
    parts = [mk.lathe("Foot", [(0.0, 0.0), (0.7, 0.0), (0.74, 0.04), (0.66, 0.1), (0.1, 0.16), (0.0, 0.16)], mat=steel, segments=16),
             mk.cylinder("Stem", 0.045, 4.9, (0, 0, 2.6), mat=steel, verts=8),
             mk.lathe("Shade", [(0.8, 4.9), (0.64, 5.9)], mat=shade, segments=18, caps=False),
             mk.lathe("ShadeRim", [(0.82, 4.88), (0.82, 4.93)], mat=steel, segments=18, caps=False),
             mk.lathe("ShadeTop", [(0.66, 5.88), (0.66, 5.92), (0.06, 5.92)], mat=steel, segments=18, caps=False),
             bar("Cord", spline([(0.06, 0.0, 0.3), (0.24, 0.04, 0.1), (0.7, 0.3, 0.03), (0.98, 0.3, 0.03)], 2), 0.012, steel, sides=3)]
    glows = [mk.sphere("Bulb", 0.2, (0, 0, 5.4), mat=pk.glow("BLamp_Bulb", (255, 210, 150), 5), segments=10, rings=6)]
    return parts, glows


@prop("RangeTarget", pivot="bottom", material="SmoothPlastic", collide=True, texture=256, set="Agency", exact=True)
def range_target():
    """A firing range target on its steel stand: a card silhouette of head and shoulders with printed scoring rings, clipped to a
    frame on a T foot."""
    steel = pk.metal("RTarget_Iron", (34, 36, 40), (64, 66, 72), rough=0.45, metallic=0.8)
    card = mk.noisy("RTarget_Card", srgb(196, 186, 160), srgb(226, 216, 190), roughness=0.9)
    print_ = mk.flat("RTarget_Print", srgb(20, 20, 24), 0.8)
    white = mk.flat("RTargetRing_Print", srgb(226, 222, 212), 0.8)
    clip = pk.metal("RTarget_Chrome", (120, 124, 130), (176, 180, 186), rough=0.3, metallic=1.0)
    parts = [mk.box("Foot", (1.7, 0.14, 0.1), (0, 0, 0.05), mat=steel, bevel=0.015, segments=1),
             mk.box("FootCross", (0.14, 1.7, 0.1), (0, 0, 0.05), mat=steel, bevel=0.015, segments=1)]
    for x in (-0.78, 0.78):
        parts.append(mk.box("Upright", (0.08, 0.08, 5.9), (x, 0.05, 2.95), mat=steel))
    parts += [mk.box("Rail", (1.64, 0.08, 0.08), (0, 0.05, 5.9), mat=steel), mk.box("Rail", (1.64, 0.08, 0.08), (0, 0.05, 2.2), mat=steel),
              mk.box("Board", (1.5, 0.02, 3.6), (0, 0.0, 4.05), mat=card)]
    outline = [(-0.66, -1.72), (0.66, -1.72), (0.66, -0.3), (0.5, 0.2), (0.24, 0.42), (0.2, 0.68), (0.3, 1.0), (0.2, 1.36), (0.0, 1.5), (-0.2, 1.36), (-0.3, 1.0),
               (-0.2, 0.68), (-0.24, 0.42), (-0.5, 0.2), (-0.66, -0.3)]
    parts.append(mk.extrude_shape("Silhouette", outline, 0.006, (0, -0.016, 4.0), rot=(90, 0, 0), mat=print_))
    for r in (0.5, 0.34, 0.18):
        parts.append(mk.torus("Ring", r, 0.012, (0, -0.024, 3.8), rot=(90, 0, 0), mat=white, major_segments=16, minor_segments=3))
    parts.append(mk.torus("Ring", 0.12, 0.012, (0, -0.024, 5.0), rot=(90, 0, 0), mat=white, major_segments=12, minor_segments=3))
    for x in (-0.5, 0.5):
        parts.append(mk.box("Clip", (0.16, 0.06, 0.2), (x, 0.0, 5.82), mat=clip, bevel=0.012, segments=1))
    return parts, []


# Kagegaoka University -----------------------------------------------------------------------------------


def snow_on(parts, mat, cell=0.3, depth=0.16, flat=0.55, name="SnowCover"):
    """A blanket of snow over whatever stands in `parts`: a grid let down from above lies wherever it lands on something
    facing up, deepest in the middle of a patch and feathered out at its edges, so it rounds over a roof, a seat or a beam."""
    verts, polys = [], []
    for obj in parts:
        if obj.type != "MESH":  # (a label's letters)
            continue
        matrix = obj.matrix_basis
        base = len(verts)
        verts += [matrix @ v.co for v in obj.data.vertices]
        polys += [[base + i for i in p.vertices] for p in obj.data.polygons]
    tree = BVHTree.FromPolygons(verts, polys, all_triangles=False)
    x0, x1 = min(v.x for v in verts), max(v.x for v in verts)
    y0, y1 = min(v.y for v in verts), max(v.y for v in verts)
    top = max(v.z for v in verts) + 1.0
    nx, ny = max(2, int((x1 - x0) / cell) + 1), max(2, int((y1 - y0) / cell) + 1)
    rows = {}
    for j in range(ny + 1):
        for i in range(nx + 1):
            hit = tree.ray_cast(Vector((x0 + i * (x1 - x0) / nx, y0 + j * (y1 - y0) / ny, top)), Vector((0, 0, -1)), 200.0)
            if hit[0] is not None and abs(hit[1].z) >= flat:
                rows[i, j] = hit[0].z
    # How far each point lies from the patch's edge (in cells), so the snow thins to nothing there.
    inner = {key: 1 for key in rows}
    for _ in range(3):
        grown = {}
        for (i, j), d in inner.items():
            near = [inner.get((i + a, j + b), 0) for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1))]
            grown[i, j] = min(near + [d]) + 1 if min(near) else 1
        inner = grown
    rng = random.Random(len(parts))
    bm = bmesh.new()
    made = {}
    for (i, j), z in rows.items():
        thick = depth * (0.25 + 0.75 * (min(inner[i, j], 3) - 1) / 2) * rng.uniform(0.85, 1.15)
        made[i, j] = bm.verts.new((x0 + i * (x1 - x0) / nx, y0 + j * (y1 - y0) / ny, z + 0.012 + thick))
    for (i, j), a in made.items():
        b, c, d = made.get((i + 1, j)), made.get((i + 1, j + 1)), made.get((i, j + 1))
        if b and c and d and max(v.co.z for v in (a, b, c, d)) - min(v.co.z for v in (a, b, c, d)) < cell * 1.2:
            bm.faces.new((a, b, c, d))
    return mk.soften(mk._obj_from_bm(name, bm, mat))


@prop("CupVendor", pivot="bottom", material="SmoothPlastic", collide=True, texture=512, set="Campus", exact=True, normal=128, lights=VENDOR_LIGHT)
def cup_vendor():
    """The student union's paper cup coffee machine: a cream enamel cabinet with a brown band, a dark panel with a steaming cup on it, a
    column of lit selection buttons, the cup bay with a cup waiting on its drip grille, coin slot and return."""
    enamel = pk.plastic("CVend_Plastic", (214, 204, 180))
    band = pk.plastic("CVendBand_Plastic", (96, 58, 34))
    panel = mk.noisy("CVendPanel_Plastic", srgb(22, 16, 12), srgb(44, 32, 24), roughness=0.2)
    steel = pk.chrome("CVend_Chrome")
    dark = mk.flat("CVendDark_Plastic", srgb(10, 9, 8), 0.6)
    cup = mk.flat("CVend_Paper", srgb(232, 226, 210), 0.7)
    coffee = mk.flat("CVendCoffee_Plastic", srgb(44, 24, 12), 0.3)
    steam = mk.flat("CVendSteam_Plastic", srgb(214, 204, 186), 0.6)
    key = pk.plastic("CVendKey_Plastic", (190, 176, 150))
    front = -1.28
    parts = [pk.rounded("Body", (4.0, 2.56, 6.9), (0, 0, 3.55), enamel, r=0.08),
             mk.box("Band", (4.02, 0.02, 0.5), (0, front - 0.004, 6.5), mat=band),
             mk.box("Panel", (2.5, 0.03, 3.1), (-0.62, front - 0.012, 4.4), mat=panel, bevel=0.012, segments=1),
             mk.box("BayFrame", (1.5, 0.05, 1.2), (-0.62, front - 0.02, 1.86), mat=steel, bevel=0.012, segments=1),
             mk.box("Bay", (1.3, 0.02, 1.0), (-0.62, front - 0.05, 1.86), mat=dark),
             mk.box("Drip", (1.1, 0.2, 0.05), (-0.62, front - 0.09, 1.42), mat=steel),
             mk.box("Plinth", (3.9, 2.46, 0.2), (0, 0, 0.1), mat=dark)]
    parts.append(mk.soften(mk.lathe("PaperCup", [(0.0, 1.45), (0.12, 1.45), (0.17, 1.9), (0.0, 1.9)], (-0.62, front - 0.09, 0), mat=cup, segments=10)))
    # The cup drawn on the panel.
    x, z = -0.62, 3.95
    parts.append(mk.extrude_shape("PanelCup", [(-0.6, 0.5), (0.6, 0.5), (0.46, -0.5), (-0.46, -0.5)], 0.012, (x, front - 0.03, z), rot=(90, 0, 0), mat=cup))
    parts.append(mk.box("PanelCoffee", (1.1, 0.006, 0.14), (x, front - 0.04, z + 0.4), mat=coffee))
    parts.append(bar("PanelHandle", [(x + 0.5 + 0.34 * math.sin(k * 0.5), front - 0.034, z + 0.0 + 0.36 * math.cos(k * 0.5)) for k in range(7)], 0.04, cup, sides=4))
    for dx in (-0.3, 0.05, 0.36):
        wisp = [(x + dx + 0.09 * math.sin(k * 1.2), front - 0.034, z + 0.72 + k * 0.12) for k in range(8)]
        parts.append(bar("PanelSteam", wisp, 0.022, steam, sides=3))
    # The buttons, the money.
    lit = pk.glow("CVend_Button", (255, 190, 110), 2.5)
    glows = []
    for k in range(6):
        z2 = 5.5 - k * 0.48
        parts.append(mk.box("Key", (0.8, 0.06, 0.34), (1.26, front - 0.03, z2), mat=key, bevel=0.012, segments=1))
        glows.append(mk.box("KeyLamp", (0.1, 0.012, 0.1), (1.56, front - 0.066, z2), mat=lit))
    parts += [mk.box("CoinPlate", (0.8, 0.03, 0.5), (1.26, front - 0.014, 2.5), mat=steel, bevel=0.01, segments=1),
              mk.box("CoinSlot", (0.05, 0.01, 0.2), (1.26, front - 0.034, 2.55), mat=dark),
              mk.box("CoinReturn", (0.5, 0.05, 0.3), (1.26, front - 0.024, 1.6), mat=steel, bevel=0.012, segments=1)]
    return parts, glows


@prop("CanteenChiller", pivot="bottom", material="Metal", collide=True, texture=512, set="Campus", exact=True, normal=128, lights=COOLER_LIGHT)
def canteen_chiller():
    """The cafeteria's open chiller: a cream steel case with wood trim, five shelves with price rails of milk cartons, sandwiches in
    their wedges and bento boxes, a canvas night blind half down, a lit canopy."""
    case = pk.plastic("CChill_Plastic", (206, 198, 176))
    wood = mk.wood("CChill_Wood", srgb(120, 84, 50), srgb(76, 50, 30), roughness=0.5)
    liner = mk.flat("CChillLiner_Plastic", srgb(190, 196, 192), 0.4)
    rail = pk.metal("CChill_Chrome", (120, 124, 130), (176, 180, 186), rough=0.3, metallic=1.0)
    milk = mk.flat("CChillMilk_Paper", srgb(226, 228, 232), 0.7)
    blue = mk.flat("CChillBlue_Paper", srgb(50, 96, 170), 0.7)
    bread = mk.flat("CChill_Bread", srgb(214, 186, 136), 0.8)
    fill = mk.flat("CChill_Fill", srgb(170, 60, 50), 0.6)
    bento = mk.flat("CChillBento_Plastic", srgb(30, 26, 24), 0.4)
    lid = mk.flat("CChillLid_Plastic", srgb(206, 196, 166), 0.3)
    blind = mk.noisy("CChill_Canvas", srgb(150, 146, 130), srgb(186, 180, 162), roughness=0.9)
    front = -1.4
    parts = [mk.box("Back", (8.2, 0.5, 7.0), (0, 1.25, 3.5), mat=case, bevel=0.02, segments=1),
             mk.box("Interior", (7.7, 0.02, 4.9), (0, 0.98, 3.7), mat=liner),
             mk.box("Canopy", (8.2, 2.9, 0.62), (0, 0.05, 6.69), mat=case, bevel=0.02, segments=1),
             mk.box("Plinth", (8.2, 2.9, 1.14), (0, 0.05, 0.57), mat=case, bevel=0.02, segments=1),
             mk.box("TrimTop", (8.24, 0.05, 0.16), (0, front - 0.02, 6.5), mat=wood),
             mk.box("TrimLow", (8.24, 0.05, 0.3), (0, front - 0.02, 0.9), mat=wood)]
    for x in (-4.0, 4.0):
        parts.append(mk.box("End", (0.2, 2.6, 5.0), (x, 0.0, 3.7), mat=case, bevel=0.02, segments=1))
    rng = random.Random(14)
    for level in range(4):
        z = 1.4 + level * 1.2
        depth = 1.5 + level * -0.18
        y = 0.86 - depth / 2
        parts.append(mk.box("Shelf", (7.7, depth, 0.05), (0, y, z), mat=rail))
        parts.append(mk.box("PriceRail", (7.7, 0.02, 0.1), (0, y - depth / 2 - 0.01, z + 0.03), mat=milk))
        x = -3.6
        fy = y - depth / 2 + 0.3
        while x < 3.0:
            kind = rng.randrange(3)
            if kind == 0 and x < 2.5:  # (milk, two deep)
                for k in range(4):
                    for dy in (0.0, 0.42):
                        parts.append(mk.box("Carton", (0.34, 0.34, 0.66), (x + 0.17 + k * 0.38, fy + dy, z + 0.355), mat=milk))
                    parts.append(mk.box("CartonBand", (0.345, 0.345, 0.14), (x + 0.17 + k * 0.38, fy, z + 0.3), mat=blue))
                x += 1.64
            elif kind == 1 and x < 2.0:  # (sandwiches in their wedges)
                for k in range(3):
                    cx = x + 0.36 + k * 0.62
                    parts.append(mk.extrude_shape("Sandwich", [(-0.3, 0.0), (0.3, 0.0), (0.0, 0.5)], 0.36, (cx, fy, z + 0.03), rot=(90, 0, 0), mat=bread))
                    parts.append(mk.box("Filling", (0.5, 0.38, 0.05), (cx, fy, z + 0.14), mat=fill))
                x += 2.0
            else:  # (bento boxes, a stack of two)
                for k in range(2):
                    for level2 in (0, 1):
                        cx, cz = x + 0.44 + k * 0.84, z + 0.11 + level2 * 0.24
                        parts.append(pk.rounded("Bento", (0.78, 0.6, 0.18), (cx, fy, cz), bento, r=0.03))
                        parts.append(mk.box("BentoLid", (0.72, 0.54, 0.03), (cx, fy, cz + 0.1), mat=lid))
                x += 1.76
    parts += [mk.box("Blind", (3.6, 0.03, 1.0), (2.0, front + 0.05, 5.86), mat=blind), mk.box("BlindBar", (3.7, 0.05, 0.05), (2.0, front + 0.05, 5.34), mat=rail)]
    glows = [mk.box("Strip", (7.6, 0.05, 0.04), (0, -0.8, 6.34), mat=pk.glow("CChill_Light", (255, 236, 204), 3))]
    return parts, glows


@prop("PushTicketer", pivot="bottom", material="Metal", collide=True, texture=256, set="Campus", exact=True)
def push_ticketer():
    """The cafeteria's old meal ticket machine: a green crackle-painted cabinet on legs, rows of square push buttons each under its
    handwritten menu card, the coin slot, the chute a ticket drops into, a lit strip along the top."""
    paint = pk.paint("PTick_Paint", (64, 92, 76), rough=0.5, wear=14)
    steel = pk.metal("PTick_Steel", (110, 112, 118), (160, 162, 168), rough=0.35, metallic=1.0)
    dark = mk.flat("PTick_Dark", srgb(14, 14, 14), 0.7)
    card = mk.noisy("PTick_Card", srgb(214, 206, 180), srgb(238, 232, 210), roughness=0.9)
    writing = mk.flat("PTick_Print", srgb(40, 40, 46), 0.8)
    button = pk.plastic("PTickKey_Plastic", (160, 44, 38))
    parts = [pk.rounded("Body", (2.9, 1.7, 4.5), (0, 0, 3.4), paint, r=0.08)]
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(mk.box("Leg", (0.14, 0.14, 1.2), (sx * 1.26, sy * 0.68, 0.6), mat=steel))
    front = -0.85
    for row in range(5):
        for col in range(3):
            x, z = -0.82 + col * 0.82, 5.0 - row * 0.54
            parts.append(mk.box("Menu", (0.7, 0.012, 0.3), (x, front - 0.008, z + 0.08), mat=card))
            parts.append(mk.box("MenuLine", (0.44, 0.006, 0.05), (x, front - 0.016, z + 0.1), mat=writing))
            parts.append(mk.box("Key", (0.22, 0.05, 0.14), (x, front - 0.024, z - 0.14), mat=button, bevel=0.012, segments=1))
    parts += [mk.box("CoinPlate", (0.8, 0.03, 0.4), (0.66, front - 0.014, 2.22), mat=steel, bevel=0.01, segments=1),
              mk.box("CoinSlot", (0.05, 0.01, 0.2), (0.66, front - 0.032, 2.22), mat=dark),
              mk.box("Chute", (1.1, 0.06, 0.42), (-0.6, front - 0.02, 1.62), mat=steel, bevel=0.012, segments=1),
              mk.box("ChuteMouth", (0.9, 0.012, 0.22), (-0.6, front - 0.056, 1.62), mat=dark)]
    glows = [mk.box("Strip", (2.4, 0.012, 0.1), (0, front - 0.012, 5.48), mat=pk.glow("PTick_Light", (255, 226, 170), 3))]
    return parts, glows


@prop("CampusTape", pivot="centre", material="Plastic", collide=True, texture=256, set="Campus", exact=True)
def campus_tape():
    """The caretaker's barrier tape: red and white ribbon, frayed by the cold, hung with more sag than the police use."""
    return [tape("Ribbon", stripes("CTape_Band", (150, 26, 30), (232, 230, 224), 0.7), sag=0.3, rows=16)], []


@prop("StoneFountain", pivot="bottom", material="Metal", collide=True, texture=256, set="Campus", exact=True)
def stone_fountain():
    """A drinking fountain in grey granite: a tapered pedestal on its step, a dished basin, a brass bubbler and push button."""
    stone = mk.noisy("SFount_Stone", srgb(104, 104, 100), srgb(150, 150, 146), roughness=0.75)
    brass = pk.metal("SFount_Brass", (124, 96, 50), (190, 156, 90), rough=0.32, metallic=1.0)
    parts = [pk.rounded("Step", (1.5, 1.5, 0.2), (0, 0, 0.1), stone, r=0.03),
             mk.cylinder("Pedestal", 0.72, 2.9, (0, 0, 1.65), rot=(0, 0, 45), mat=stone, verts=4, radius2=0.56),
             mk.lathe("Basin", [(0.0, 3.2), (0.3, 3.2), (0.6, 3.1), (0.74, 3.32), (0.74, 3.46), (0.68, 3.5), (0.5, 3.36), (0.0, 3.3)], mat=stone, segments=16),
             mk.lathe("Bubbler", [(0.0, 3.3), (0.09, 3.3), (0.06, 3.52), (0.08, 3.6), (0.04, 3.68), (0.0, 3.68)], mat=brass, segments=8),
             mk.cylinder("Drain", 0.1, 0.01, (0, 0.24, 3.34), mat=brass, verts=8),
             mk.cylinder("PushButton", 0.09, 0.08, (0, -0.56, 2.96), rot=(90, 0, 0), mat=brass, verts=8)]
    return parts, []


@prop("CorkBoard", pivot="centre", material="Wood", collide=True, texture=512, set="Campus", exact=True, normal=128)
def cork_board():
    """A faculty notice board: an oak frame round cork, thick with club flyers, exam notices and a seminar timetable, red and brass pins
    and one curling corner."""
    oak = mk.wood("CBoard_Oak", srgb(112, 78, 46), srgb(72, 48, 28), roughness=0.5)
    cork = mk.noisy("CBoard_Cork", srgb(150, 110, 70), srgb(190, 150, 100), roughness=0.9)
    papers = [mk.noisy(f"CBoard{i}_Paper", srgb(*c), srgb(*[min(255, v + 18) for v in c]), roughness=0.9)
              for i, c in enumerate(((226, 222, 208), (214, 196, 130), (170, 200, 180), (216, 170, 160)))]
    writing = mk.flat("CBoard_Print", srgb(36, 36, 44), 0.8)
    red = pk.plastic("CBoardPin_Plastic", (170, 30, 30))
    w, h = 5.7, 3.7
    parts = [mk.box("Back", (w - 0.2, 0.1, h - 0.2), (0, 0.04, 0), mat=cork)]
    for z in (h / 2 - 0.08, -h / 2 + 0.08):
        parts.append(mk.box("FrameRail", (w, 0.24, 0.16), (0, 0, z), mat=oak, bevel=0.02, segments=1))
    for x in (w / 2 - 0.08, -w / 2 + 0.08):
        parts.append(mk.box("FrameSide", (0.16, 0.24, h - 0.3), (x, 0, 0), mat=oak, bevel=0.02, segments=1))
    rng = random.Random(61)
    pins = []
    for k, (x, z, pw, ph) in enumerate(((-2.0, 0.7, 1.0, 1.3), (-0.8, 0.9, 1.1, 0.9), (0.4, 0.75, 0.9, 1.2), (1.6, 0.8, 1.2, 1.0), (-2.05, -0.8, 1.0, 0.9),
                                        (-0.9, -0.5, 1.0, 1.4), (0.3, -0.75, 1.2, 1.0), (1.7, -0.65, 1.0, 1.3))):
        turn = rng.uniform(-4, 4)
        lift = -0.02 - 0.012 * (k % 3)
        parts.append(mk.box("Flyer", (pw, 0.008, ph), (x, lift, z), rot=(0, turn, 0), mat=papers[k % 4]))
        for j in range(rng.randrange(2, 5)):
            parts.append(mk.box("Line", (pw * rng.uniform(0.4, 0.72), 0.004, 0.06), (x, lift - 0.007, z + ph * 0.32 - j * 0.2), rot=(0, turn, 0), mat=writing))
        pins.append((x, lift - 0.006, z + ph / 2 - 0.08))
    parts.append(studs("Pin", pins, 0.05, 0.02, red, facing=(0, -1, 0)))
    return parts, []


@prop("GranitePlanter", pivot="bottom", material="Concrete", collide=True, texture=512, set="Campus", exact=True, normal=128, ao=0.35)
def granite_planter():
    """A rough granite trough along a campus path, clipped box shrubs in a row and the winter's snow on all of it."""
    stone = mk.noisy("GPlant_Stone", srgb(92, 92, 90), srgb(140, 140, 136), roughness=0.85)
    soil = mk.noisy("GPlant_Soil", srgb(24, 20, 16), srgb(46, 38, 30), roughness=1.0)
    leaf_mat = mk.noisy("GPlant_Leaf", srgb(22, 46, 30), srgb(50, 80, 50), roughness=0.7)
    parts = [pk.rounded("Trough", (6.5, 2.0, 1.5), (0, 0, 0.75), stone, r=0.06),
             mk.box("RimBack", (6.5, 0.16, 0.1), (0, 0.92, 1.53), mat=stone, bevel=0.02, segments=1),
             mk.box("RimFront", (6.5, 0.16, 0.1), (0, -0.92, 1.53), mat=stone, bevel=0.02, segments=1),
             mk.box("RimL", (0.16, 1.7, 0.1), (-3.17, 0, 1.53), mat=stone, bevel=0.02, segments=1),
             mk.box("RimR", (0.16, 1.7, 0.1), (3.17, 0, 1.53), mat=stone, bevel=0.02, segments=1),
             mk.box("Soil", (6.2, 1.7, 0.04), (0, 0, 1.5), mat=soil)]
    rng = random.Random(9)
    for k in range(4):
        x = -2.3 + k * 1.54
        for j in range(7):  # (a clipped mound, built of lumps)
            a = j * 2.4
            r = 0.0 if j == 0 else 0.42
            bush = mk.sphere("Shrub", 1.0, (x + r * math.cos(a), r * 0.8 * math.sin(a), 1.92 + (0.3 if j == 0 else 0.0)), scale=(0.44, 0.44, 0.4), mat=leaf_mat,
                             segments=10, rings=6)
            for v in bush.data.vertices:
                v.co *= 1 + rng.uniform(-0.1, 0.1)
            parts.append(mk.soften(bush))
    white = snow("GPlant")
    parts.append(snow_on(parts[:6], white, cell=0.2, depth=0.1))
    for k in range(4):  # (a cap of snow on each mound)
        x = -2.3 + k * 1.54
        parts.append(cushion("ShrubCap", (1.2, 1.1, 0.3), (x + 0.04 * k, 0.03, 2.44), white, e=0.75, segments=12, rings=6))
    return parts, []


@prop("TimberBarrier", pivot="bottom", material="SmoothPlastic", collide=True, texture=256, set="Campus", exact=True)
def timber_barrier():
    """The grounds staff's timber barrier: two A frames holding a pair of red and white boards, a sandbag on each foot, an amber lantern
    on top, snow along the boards."""
    pine = mk.wood("TBar_Wood", srgb(150, 118, 78), srgb(100, 74, 46), roughness=0.75)
    board = stripes("TBar_Band", (160, 30, 30), (226, 224, 216), 0.9)
    sack = mk.noisy("TBar_Sack", srgb(120, 106, 76), srgb(160, 146, 110), roughness=0.9)
    dark = pk.metal("TBar_Iron", (24, 24, 26), (50, 50, 54), rough=0.5, metallic=0.8)
    parts = []
    for x in (-1.8, 1.8):
        for sy in (-1, 1):
            parts.append(mk.tube("FrameLeg", (x, sy * 1.0, 0.02), (x, sy * 0.06, 2.7), 0.075, mat=pine, verts=5))
        parts.append(mk.box("FrameTie", (0.08, 1.2, 0.1), (x, 0, 1.0), mat=pine))
        parts.append(mk.soften(cushion("Sandbag", (0.56, 1.7, 0.3), (x, 0, 0.17), sack, e=0.6, segments=10, rings=5)))
    parts += [mk.box("BoardTop", (4.1, 0.08, 0.36), (0, -0.14, 2.3), mat=board), mk.box("BoardLow", (4.1, 0.08, 0.36), (0, -0.14, 1.5), mat=board)]
    parts.append(snow_on([p for p in parts if p.name.startswith(("Board", "Sandbag"))], snow("TBar"), cell=0.14, depth=0.09))
    parts.append(mk.cylinder("LampPost", 0.05, 0.3, (1.8, 0, 2.84), mat=dark, verts=6))
    glows = [mk.cylinder("Lantern", 0.13, 0.2, (1.8, 0, 3.08), mat=pk.glow("TBar_Lamp", (255, 150, 40), 3), verts=8)]
    return parts, glows


@prop("ScaffoldScreen", pivot="bottom", material="Concrete", collide=True, texture=512, set="Campus", exact=True, normal=128)
def scaffold_screen():
    """A building site's edge on campus: bamboo poles lashed with rope into a frame, a green debris net tied across it, sandbags and
    concrete feet at the bottom."""
    bamboo = mk.noisy("SScreen_Bamboo", srgb(150, 130, 80), srgb(190, 172, 118), roughness=0.5, kind="wood")
    rope = mk.noisy("SScreen_Rope", srgb(70, 60, 44), srgb(110, 96, 72), roughness=0.9)
    net = lattice("SScreen_Net", (34, 74, 58), (12, 26, 22), 0.2, _axis("X"), _axis("Z"), share=0.2, roughness=0.8, square=True)
    block = mk.noisy("SScreen_Concrete", srgb(96, 94, 90), srgb(136, 134, 128), roughness=0.85)
    parts = [mk.box("Net", (7.7, 0.02, 9.2), (0, 0.04, 5.0), mat=net)]
    for x in (-3.85, -1.3, 1.3, 3.85):
        parts.append(mk.soften(mk.cylinder("Pole", 0.09, 9.9, (x, -0.1, 4.95), mat=bamboo, verts=6)))
        parts.append(mk.soften(mk.tube("Prop", (x, 1.2, 0.18), (x, -0.08, 6.2), 0.06, mat=bamboo, verts=5)))
        parts.append(pk.rounded("Foot", (0.3, 2.5, 0.3), (x, 0.0, 0.15), block, r=0.03))
    for z in (0.9, 3.2, 5.6, 8.0, 9.7):
        parts.append(mk.soften(mk.cylinder("Rail", 0.07, 8.0, (0, -0.2, z), rot=(0, 90, 0), mat=bamboo, verts=6)))
        for x in (-3.85, -1.3, 1.3, 3.85):
            parts.append(mk.torus("Lashing", 0.12, 0.024, (x, -0.17, z), rot=(0, 90, 45), mat=rope, major_segments=7, minor_segments=3))
    return parts, []


@prop("SnowPole", pivot="bottom", material="Concrete", collide=False, texture=512, set="Campus", exact=True, normal=128, anchor=BUILDERS["UtilityPole"]["anchor"])
def snow_pole():
    """A utility pole at the campus edge with the winter on it: snow lying along every crossarm and on the transformer."""
    parts, glows = list(BUILDERS["UtilityPole"]["build"]())[:2]
    return parts + [snow_on(parts, snow("SPole"), cell=0.2, depth=0.12)], glows


@prop("SnowBicycle", pivot="bottom", material="Metal", collide=False, texture=256, set="Campus", exact=True)
def snow_bicycle():
    """A student's green mamachari left out in the snow, drifted over its saddle, basket and rack."""
    parts = bicycle_parts("SB_", 0.0, 0.0, (42, 86, 72))
    return parts + [snow_on(parts, snow("SBike"), cell=0.07, depth=0.08, flat=0.5)], []


@prop("SnowCone", pivot="bottom", material="Plastic", collide=False, texture=256, set="Campus", exact=True)
def snow_cone():
    """A traffic cone on the campus drive with a cap of snow and the drift round its foot."""
    parts, glows = list(BUILDERS["TrafficCone"]["build"]())[:2]
    return parts + [snow_on(parts, snow("SConeS"), cell=0.06, depth=0.08, flat=0.3)], glows


def parked(key, prefix, cell=0.24, depth=0.26):
    """A map's car left out overnight: the model the streets use with the snow lying on it."""
    parts, glows = list(BUILDERS[key]["build"]())[:2]
    return parts + [snow_on(parts, snow(prefix), cell=cell, depth=depth, flat=0.76)], glows


@prop("SnowTaxi", pivot="bottom", material="SmoothPlastic", collide=True, texture=512, set="Campus", exact=True, normal=128)
def snow_taxi():
    """A taxi waiting at the campus gate under a night's snow."""
    return parked("Taxi", "STaxi")


@prop("SnowKeiTruck", pivot="bottom", material="SmoothPlastic", collide=True, texture=512, set="Campus", exact=True, normal=128)
def snow_kei_truck():
    """A grounds staff kei truck, snowed in."""
    return parked("KeiTruck", "SKei")


@prop("SnowPoliceCar", pivot="bottom", material="SmoothPlastic", collide=True, texture=512, set="Campus", exact=True, normal=128, lights=BUILDERS["PoliceCar"]["lights"])
def snow_police_car():
    """A police car at the campus edge with fresh snow on its roof and bonnet."""
    return parked("PoliceCar", "SPolice")


@prop("SoapstoneHood", pivot="bottom", material="SmoothPlastic", collide=True, texture=512, set="Campus", exact=True, normal=128,
      lights=[dict(at=(0, -0.265, 6.6), kind="point", color=(220, 236, 255), range=10, brightness=0.8)])
def soapstone_hood():
    """The chemistry building's old fume hood: an oak cupboard base, a black soapstone bench, a white tiled chamber behind a raised wooden
    sash on brass chains and counterweights, gas taps, a retort on its stand, the duct going up through the top."""
    oak = mk.wood("SHood_Oak", srgb(120, 84, 50), srgb(76, 50, 30), roughness=0.5)
    soap = mk.noisy("SHood_Stone", srgb(20, 22, 24), srgb(50, 52, 54), roughness=0.4)
    tile = lattice("SHood_Tile", (206, 204, 196), (120, 120, 116), 0.5, _axis("X"), _plus("Y", "Z"), share=0.92, roughness=0.3, square=True)
    brass = pk.metal("SHood_Brass", (124, 96, 50), (190, 156, 90), rough=0.32, metallic=1.0)
    duct = pk.metal("SHood_Galv", (96, 100, 102), (140, 144, 146), rough=0.5, metallic=0.8)
    glass = mk.noisy("SHoodGlass_Plastic", srgb(60, 96, 86), srgb(110, 150, 136), roughness=0.14)
    parts = [mk.box("Base", (5.2, 2.5, 2.7), (0, 0.1, 1.35), mat=oak),
             pk.rounded("Bench", (5.3, 2.7, 0.2), (0, 0, 2.8), soap, r=0.03),
             mk.box("BackTile", (4.8, 0.06, 4.4), (0, 1.12, 5.1), mat=tile),
             mk.box("Top", (5.3, 2.8, 0.5), (0, 0, 7.7), mat=oak, bevel=0.02, segments=1),
             mk.cylinder("Duct", 0.5, 1.0, (0, 0.4, 8.4), mat=duct, verts=12),
             mk.torus("DuctBand", 0.52, 0.03, (0, 0.4, 8.2), mat=duct, major_segments=12, minor_segments=3)]
    for x in (-2.55, 2.55):
        parts.append(mk.box("Side", (0.2, 2.5, 4.7), (x, 0.1, 5.2), mat=oak, bevel=0.02, segments=1))
        parts.append(bar("Chain", [(x * 0.94, -1.1, 7.44), (x * 0.94, -1.1, 6.4)], 0.016, brass, sides=4))
    for k, x in enumerate((-1.74, 0.0, 1.74)):
        parts.append(mk.box("Door", (1.6, 0.05, 2.2), (x, -1.17, 1.4), mat=oak, bevel=0.012, segments=1))
        parts.append(mk.box("DoorField", (1.24, 0.03, 1.76), (x, -1.2, 1.4), mat=oak, bevel=0.012, segments=1))
        parts.append(mk.sphere("Knob", 0.05, (x + 0.6, -1.22, 1.6), mat=brass, segments=6, rings=4))
    # The sash, raised: its frame alone, the glass bakes solid.
    parts += [mk.box("SashTop", (4.9, 0.1, 0.14), (0, -1.1, 7.3), mat=oak), mk.box("SashBottom", (4.9, 0.1, 0.16), (0, -1.1, 6.3), mat=oak)]
    for x in (-1.6, 0.0, 1.6):
        parts.append(mk.box("Glazing", (0.06, 0.08, 1.0), (x, -1.1, 6.8), mat=oak))
    for x in (-2.0, -1.5, 1.7):
        parts.append(turned("GasTap", [(0.0, 0.0), (0.05, 0.0), (0.03, 0.3), (0.03, 0.4), (0.06, 0.45), (0.0, 0.5)], (x, 0.96, 2.9), (x, 0.96, 3.4), brass, segments=6))
    # A retort on its stand.
    parts += [pk.rounded("StandFoot", (0.8, 0.5, 0.05), (0.3, 0.2, 2.93), soap, r=0.015),
              mk.cylinder("StandRod", 0.025, 2.0, (0.1, 0.32, 3.9), mat=brass, verts=6),
              mk.soften(mk.lathe("Flask", [(0.0, 3.4), (0.14, 3.42), (0.3, 3.62), (0.28, 3.84), (0.09, 4.08), (0.07, 4.36), (0.09, 4.38), (0.0, 4.38)], (0.5, 0.2, 0),
                                 mat=glass, segments=10)),
              bar("Clamp", [(0.1, 0.32, 4.2), (0.5, 0.2, 4.2)], 0.02, brass, sides=4)]
    glows = [mk.box("HoodLight", (3.4, 0.2, 0.05), (0, 0.2, 7.42), mat=pk.glow("SHood_Light", (220, 236, 255), 3))]
    return parts, glows


@prop("Mimeograph", pivot="bottom", material="SmoothPlastic", collide=True, texture=512, set="Campus", exact=True, normal=128)
def mimeograph():
    """The print club's duplicator: a cast green machine on a steel stand, its big stencil drum, the hand crank, a feed tray of blank paper and
    a tray of copies coming out, a stack of finished sheets beside it on the table."""
    steel = pk.metal("Mime_Steel", (60, 62, 68), (96, 98, 104), rough=0.42, metallic=0.8)
    paint = pk.paint("Mime_Paint", (60, 84, 72), rough=0.42, wear=14)
    black = pk.metal("Mime_Iron", (16, 16, 18), (40, 40, 44), rough=0.5, metallic=0.7)
    chrome = pk.chrome("Mime_Chrome")
    paper = mk.noisy("Mime_Paper", srgb(214, 208, 192), srgb(240, 236, 222), roughness=0.9)
    writing = mk.flat("Mime_Print", srgb(40, 56, 110), 0.8)
    knob = pk.plastic("MimeKnob_Plastic", (140, 34, 30))
    rng = random.Random(3)
    parts = [pk.rounded("Table", (4.7, 2.4, 0.16), (0, 0, 2.2), steel, r=0.03),
             mk.box("Shelf", (4.3, 2.0, 0.08), (0, 0, 0.7), mat=steel, bevel=0.012, segments=1),
             pk.rounded("Case", (1.8, 1.6, 0.74), (-0.6, 0.1, 2.65), paint, r=0.06),
             mk.soften(mk.cylinder("Drum", 0.56, 1.44, (-0.6, 0.1, 3.0), rot=(0, 90, 0), mat=black, verts=16)),
             mk.cylinder("DrumCapL", 0.6, 0.06, (-1.34, 0.1, 3.0), rot=(0, 90, 0), mat=chrome, verts=16),
             mk.cylinder("DrumCapR", 0.6, 0.06, (0.14, 0.1, 3.0), rot=(0, 90, 0), mat=chrome, verts=16),
             mk.cylinder("CrankHub", 0.1, 0.1, (0.22, 0.1, 3.0), rot=(0, 90, 0), mat=chrome, verts=8),
             mk.box("CrankArm", (0.05, 0.08, 0.66), (0.29, 0.1, 2.72), mat=chrome, bevel=0.012, segments=1),
             turned("CrankGrip", [(0.0, 0.0), (0.06, 0.0), (0.075, 0.5), (0.06, 1.0), (0.0, 1.0)], (0.3, 0.1, 2.44), (0.62, 0.1, 2.44), knob),
             sk.wedge("FeedTray", [(0.66, 2.56), (1.1, 2.86), (1.12, 2.92), (0.68, 2.64)], 1.3, -0.6, chrome),
             mk.box("Copies", (1.3, 0.56, 0.05), (-0.6, -0.9, 2.46), mat=chrome, bevel=0.012, segments=1)]
    for k in range(6):
        parts.append(mk.box("BlankSheet", (1.16, 0.46, 0.012), (-0.6, 0.9, 2.78 + k * 0.016), rot=(-34, 0, 0), mat=paper))
    parts += sk.papers("Copy", -0.6, -0.9, 2.49, paper, rng, n=3, w=1.1, d=0.5, spread=0.03)
    parts += sk.written("Copy", -0.6, -0.9, 2.545, writing, rng, lines=4, w=0.9, d=0.42)
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(mk.box("Leg", (0.12, 0.12, 2.12), (sx * 2.2, sy * 1.06, 1.06), mat=steel))
    for k in range(4):
        parts += sk.papers(f"Stack{k}", 1.3 + (k % 2) * 0.06, 0.1, 2.28 + k * 0.06, paper, rng, n=2, w=1.5, d=1.04, turn=4)
    parts += sk.written("Stack", 1.33, 0.1, 2.58, writing, rng, lines=6, w=1.2, d=0.8)
    return parts, []


@prop("FilmReader", pivot="bottom", material="SmoothPlastic", collide=True, texture=256, set="Campus", exact=True)
def film_reader():
    """The library's microfilm reader: a grey crackle hood with its dim screen on an oak stand, the film carriage with its hand wheel and a drawer of
    reels below."""
    oak = mk.wood("FRead_Oak", srgb(112, 78, 46), srgb(72, 48, 28), roughness=0.5)
    hood = pk.paint("FRead_Paint", (84, 88, 84), rough=0.5, wear=12)
    dark = mk.flat("FRead_Dark", srgb(16, 16, 16), 0.5)
    steel = pk.metal("FRead_Steel", (110, 112, 118), (160, 162, 168), rough=0.35, metallic=1.0)
    parts = [pk.rounded("TableTop", (2.4, 2.3, 0.12), (0, 0, 2.5), oak, r=0.03),
             mk.box("Drawer", (2.1, 0.06, 0.36), (0, -0.98, 2.22), mat=oak, bevel=0.012, segments=1),
             mk.box("Apron", (2.2, 2.0, 0.4), (0, 0.04, 2.24), mat=oak),
             mk.sphere("DrawerKnob", 0.05, (0, -1.04, 2.22), mat=steel, segments=6, rings=4),
             sk.wedge("Hood", [(-0.8, 2.56), (0.86, 2.56), (0.86, 4.9), (0.5, 5.06), (-0.5, 4.92), (-0.8, 4.2)], 2.1, 0.0, hood, bevel=0.03),
             mk.box("ScreenFrame", (1.7, 0.03, 1.3), (0, -0.7, 3.94), rot=(-12, 0, 0), mat=dark),
             mk.box("Carriage", (1.4, 0.7, 0.14), (0, -0.46, 2.66), mat=steel, bevel=0.012, segments=1),
             mk.cylinder("HandWheel", 0.2, 0.08, (1.1, -0.3, 2.86), rot=(0, 90, 0), mat=dark, verts=10),
             mk.cylinder("WheelGrip", 0.03, 0.14, (1.17, -0.42, 2.94), rot=(0, 90, 0), mat=steel, verts=6)]
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(turned("TableLeg", [(0.0, 0.0), (0.05, 0.0), (0.09, 0.2), (0.07, 0.8), (0.1, 1.0), (0.0, 1.0)], (sx * 1.02, sy * 0.96, 0), (sx * 1.02, sy * 0.96, 2.06),
                                oak, segments=6))
    lit = mk.box("Screen", (1.56, 0.012, 1.16), (0, -0.722, 3.94), rot=(-12, 0, 0), mat=pk.glow("FRead_Screen", (220, 214, 190), 2))
    return parts, [lit]


@prop("ClubAmp", pivot="bottom", material="SmoothPlastic", collide=True, texture=256, set="Campus", exact=True)
def club_amp():
    """The light music club's stack: a valve head on a two speaker cabinet in worn black tolex, cloth grille, chrome corners, control knobs, a leather
    handle, the red jewel lamp."""
    tolex = mk.noisy("CAmp_Leather", srgb(14, 14, 16), srgb(40, 38, 40), roughness=0.6)
    grille = lattice("CAmp_Cloth", (70, 62, 44), (36, 32, 26), 0.09, _axis("X"), _axis("Z"), share=0.32, roughness=0.9, square=True)
    panel = pk.metal("CAmp_Brass", (150, 126, 80), (200, 176, 124), rough=0.4, metallic=1.0)
    knob = mk.flat("CAmpKnob_Plastic", srgb(14, 14, 16), 0.3)
    chrome = pk.chrome("CAmp_Chrome")
    parts = [pk.rounded("Cabinet", (1.86, 1.6, 2.5), (0, 0, 1.3), tolex, r=0.07),
             mk.box("Grille", (1.6, 0.02, 2.2), (0, -0.805, 1.3), mat=grille),
             pk.rounded("Head", (1.8, 1.3, 0.92), (0, 0, 3.02), tolex, r=0.06),
             mk.box("Panel", (1.6, 0.02, 0.4), (0, -0.655, 2.98), mat=panel),
             pk.rounded("Handle", (0.76, 0.1, 0.06), (0, 0, 3.52), tolex, r=0.025)]
    for k in range(6):
        parts.append(mk.cylinder("Knob", 0.06, 0.07, (-0.62 + k * 0.22, -0.69, 2.98), rot=(90, 0, 0), mat=knob, verts=8))
    for sx in (-1, 1):
        for sy in (-1, 1):
            for z in (0.09, 2.52):
                parts.append(mk.sphere("Corner", 0.1, (sx * 0.87, sy * 0.74, z), mat=chrome, segments=6, rings=4))
    glows = [mk.sphere("Jewel", 0.05, (0.72, -0.68, 2.98), mat=pk.glow("CAmp_Lamp", (255, 60, 40), 4), segments=6, rings=4)]
    return parts, glows


@prop("ClubMic", pivot="bottom", material="Metal", collide=True, texture=256, set="Campus", exact=True)
def club_mic():
    """A boom microphone stand from the light music club: a three legged foot, the upright and counterweighted boom, an old chrome ball microphone, the
    cable taped down the stem."""
    black = pk.metal("CMic_Iron", (20, 20, 22), (44, 44, 48), rough=0.45, metallic=0.8)
    chrome = pk.chrome("CMic_Chrome")
    cable = mk.flat("CMicCable_Plastic", srgb(14, 14, 16), 0.6)
    parts = [mk.cylinder("Upright", 0.05, 3.9, (0, 0.6, 2.25), mat=black, verts=8), mk.lathe("Hub", [(0.0, 0.3), (0.1, 0.3), (0.1, 0.5), (0.0, 0.5)], (0, 0.6, 0), mat=black, segments=8)]
    for k in range(3):
        a = math.radians(90 + 120 * k)
        parts.append(mk.tube("TripodLeg", (0, 0.6, 0.4), (0.68 * math.cos(a), 0.6 + 0.68 * math.sin(a), 0.03), 0.035, mat=black, verts=6))
    parts += [bar("Boom", [(0, 1.44, 3.92), (0, 0.6, 4.2), (0, -1.1, 4.8)], 0.03, black, sides=6),
              mk.lathe("Weight", [(0.0, 0.0), (0.12, 0.0), (0.12, 0.3), (0.0, 0.3)], (0, 1.3, 3.84), mat=chrome, segments=8),
              mk.cylinder("Clutch", 0.09, 0.2, (0, 0.6, 4.2), rot=(0, 90, 0), mat=chrome, verts=8),
              turned("MicBody", [(0.0, 0.0), (0.05, 0.0), (0.07, 0.5), (0.1, 1.0), (0.0, 1.0)], (0, -1.1, 4.8), (0, -1.36, 4.9), black),
              mk.soften(mk.sphere("MicBall", 0.14, (0, -1.44, 4.93), mat=chrome, segments=10, rings=7)),
              bar("Cable", spline([(0, -1.1, 4.78), (0, -0.4, 4.3), (0.06, 0.56, 4.0), (0.06, 0.56, 1.0), (0.3, 0.8, 0.03), (0.68, 1.0, 0.03)], 2), 0.016, cable, sides=3)]
    return parts, []


@prop("BinStore", pivot="bottom", material="WoodPlanks", collide=True, texture=256, set="Campus", exact=True)
def bin_store():
    """A wooden store for the campus's rubbish and recycling: slatted cedar round three bins, hinged lids with their round and slotted openings, stencilled
    signs, snow lying along the top."""
    cedar = mk.wood("BStore_Wood", srgb(120, 86, 52), srgb(78, 54, 32), roughness=0.7)
    frame = mk.wood("BStore_Oak", srgb(84, 58, 36), srgb(54, 36, 22), roughness=0.7)
    dark = mk.flat("BStore_Dark", srgb(12, 12, 12), 0.8)
    plates = [mk.flat(f"BStorePlate{i}_Plastic", srgb(*c), 0.5) for i, c in enumerate(((180, 170, 60), (60, 110, 160), (60, 130, 80)))]
    parts = [mk.box("Plinth", (3.5, 1.3, 0.14), (0, 0, 0.07), mat=frame)]
    for k in range(9):
        z = 0.32 + k * 0.26
        parts.append(mk.box("SlatFront", (3.5, 0.05, 0.22), (0, -0.62, z), mat=cedar))
        parts.append(mk.box("SlatBack", (3.5, 0.05, 0.22), (0, 0.62, z), mat=cedar))
    for x in (-1.72, -0.58, 0.58, 1.72):
        parts.append(mk.box("Post", (0.12, 1.3, 2.5), (x, 0, 1.3), mat=frame))
    tops = []
    for k, x in enumerate((-1.15, 0.0, 1.15)):
        lid = sk.wedge("Lid", [(-0.68, 2.54), (0.68, 2.54), (0.68, 3.08), (-0.68, 2.74)], 1.08, x, frame, bevel=0.012)
        tops.append(lid)
        parts.append(lid)
        parts.append(mk.cylinder("Opening", 0.22, 0.012, (x, -0.2, 2.86), rot=(-14, 0, 0), mat=dark, verts=10) if k != 1 else mk.box("Slot", (0.6, 0.14, 0.012), (x, -0.2, 2.86),
                                                                                                                                   rot=(-14, 0, 0), mat=dark))
        parts.append(mk.box("Plate", (0.6, 0.012, 0.36), (x, -0.655, 1.5), mat=plates[k]))
    parts.append(snow_on(tops, snow("BStore"), cell=0.12, depth=0.1))
    return parts, []


@prop("ReadingLamp", pivot="bottom", material="Metal", collide=True, texture=256, set="Campus", exact=True,
      lights=[dict(at=(0, 0, 5.4), kind="point", color=(255, 210, 150), range=15, brightness=0.9)])
def reading_lamp():
    """A library standard lamp: a turned brass stem on a stepped foot, a pleated cream shade, its pull chain."""
    brass = pk.metal("RLamp_Brass", (124, 96, 50), (190, 156, 90), rough=0.32, metallic=1.0)
    shade = lattice("RLamp_Cloth", (204, 190, 160), (160, 144, 116), 0.1, lambda n, l, s: _around(n, l, s), _axis("Z"), share=0.7, roughness=0.9)
    parts = [mk.lathe("Foot", [(0.0, 0.0), (0.72, 0.0), (0.74, 0.06), (0.5, 0.12), (0.46, 0.18), (0.16, 0.24), (0.08, 0.4), (0.0, 0.4)], mat=brass, segments=16),
             turned("Stem", [(0.0, 0.0), (0.05, 0.0), (0.035, 0.2), (0.06, 0.24), (0.035, 0.3), (0.035, 0.7), (0.06, 0.74), (0.035, 0.8), (0.03, 1.0), (0.0, 1.0)],
                    (0, 0, 0.36), (0, 0, 5.0), brass, segments=8),
             mk.lathe("Shade", [(0.9, 4.96), (0.5, 5.9)], mat=shade, segments=24, caps=False),
             mk.lathe("ShadeTop", [(0.5, 5.9), (0.5, 5.94), (0.06, 5.94)], mat=brass, segments=16, caps=False),
             bar("PullChain", [(0.12, 0.0, 5.0), (0.12, 0.0, 4.6)], 0.01, brass, sides=3),
             mk.sphere("PullBall", 0.03, (0.12, 0.0, 4.58), mat=brass, segments=6, rings=4)]
    glows = [mk.sphere("Bulb", 0.2, (0, 0, 5.4), mat=pk.glow("RLamp_Bulb", (255, 210, 150), 5), segments=10, rings=6)]
    return parts, glows


def _around(nodes, links, split):
    """The angle round the Z axis (for a pleat round a shade)."""
    node = nodes.new("ShaderNodeMath")
    node.operation = "ARCTAN2"
    links.new(split.outputs["Y"], node.inputs[0])
    links.new(split.outputs["X"], node.inputs[1])
    scale = nodes.new("ShaderNodeMath")
    scale.operation = "MULTIPLY"
    links.new(node.outputs[0], scale.inputs[0])
    scale.inputs[1].default_value = 0.6
    return scale.outputs[0]


@prop("TimberShelter", pivot="bottom", material="WoodPlanks", collide=False, solids=True, texture=512, set="Campus", exact=True, normal=128, lights=BUILDERS["BusShelter"]["lights"])
def timber_shelter():
    """The campus bus shelter: a cedar frame boarded at the back and ends, a bench along the boards, a grey tiled roof with snow lying thick on it, a caged lamp
    under the ridge, a framed timetable."""
    cedar = mk.wood("TShelter_Wood", srgb(116, 82, 50), srgb(74, 50, 30), roughness=0.7)
    post = mk.wood("TShelter_Oak", srgb(84, 58, 36), srgb(54, 36, 22), roughness=0.7)
    tile = mk.noisy("TShelter_Stone", srgb(50, 52, 56), srgb(84, 86, 90), roughness=0.6)
    card = mk.noisy("TShelter_Paper", srgb(214, 208, 192), srgb(238, 232, 216), roughness=0.9)
    writing = mk.flat("TShelter_Print", srgb(36, 36, 44), 0.8)
    iron = pk.metal("TShelter_Iron", (24, 24, 26), (50, 50, 54), rough=0.5, metallic=0.8)
    parts = []
    for x in (-6.0, -2.0, 2.0, 6.0):
        parts.append(mk.box("BackPost", (0.3, 0.3, 7.4), (x, 1.9, 3.7), mat=post, bevel=0.02, segments=1))
    for x in (-6.0, 6.0):
        parts.append(mk.box("FrontPost", (0.3, 0.3, 7.0), (x, -1.3, 3.5), mat=post, bevel=0.02, segments=1))
        for k in range(10):
            parts.append(mk.box("EndBoard", (0.08, 3.0, 0.36), (x, 0.3, 0.5 + k * 0.42), mat=cedar))
    for k in range(13):
        parts.append(mk.box("BackBoard", (11.6, 0.08, 0.5), (0, 1.94, 0.5 + k * 0.54), mat=cedar))
    parts += [mk.box("Bench", (9.6, 1.1, 0.14), (0, 1.2, 1.6), mat=cedar, bevel=0.015, segments=1), mk.box("BenchBack", (9.6, 0.1, 0.5), (0, 1.84, 2.4), mat=post)]
    for x in (-4.4, 0.0, 4.4):
        parts.append(mk.box("BenchLeg", (0.16, 0.9, 1.54), (x, 1.3, 0.77), mat=post))
    roof = sk.wedge("Roof", [(-2.25, 7.0), (2.25, 7.6), (2.25, 7.92), (-2.25, 7.3)], 12.4, 0.0, tile, bevel=0.02)
    parts.append(roof)
    for k in range(9):
        y = -2.0 + k * 0.5
        parts.append(mk.box("TileRow", (12.4, 0.46, 0.06), (0, y, 7.34 + (y + 2.25) * 0.133), rot=(7.6, 0, 0), mat=tile, bevel=0.012, segments=1))
    parts.append(mk.box("Fascia", (12.3, 0.12, 0.4), (0, -2.2, 6.9), mat=post))
    parts.append(snow_on(parts[-11:-1], snow("TShelter"), cell=0.5, depth=0.3))
    parts += [mk.box("Timetable", (1.6, 0.06, 1.1), (-3.6, 1.86, 3.5), mat=post, bevel=0.012, segments=1), mk.box("TimetableSheet", (1.36, 0.012, 0.88), (-3.6, 1.824, 3.5), mat=card)]
    for k in range(6):
        parts.append(mk.box("TimeLine", (1.0, 0.004, 0.05), (-3.6, 1.814, 3.8 - k * 0.12), mat=writing))
    parts.append(mk.cylinder("LampCap", 0.3, 0.1, (0, 0.2, 6.95), mat=iron, verts=10))
    for k in range(4):
        a = math.radians(45 + 90 * k)
        parts.append(mk.tube("LampCage", (0.24 * math.cos(a), 0.2 + 0.24 * math.sin(a), 6.9), (0.2 * math.cos(a), 0.2 + 0.2 * math.sin(a), 6.46), 0.014, mat=iron, verts=4))
    glows = [mk.sphere("LampBulb", 0.17, (0, 0.2, 6.68), mat=pk.glow("TShelter_Bulb", (236, 240, 255), 4), segments=8, rings=6)]
    return parts, glows


@prop("CampusBusSign", pivot="bottom", material="Metal", collide=False, solids=True, texture=256, set="Campus", exact=True, anchor=(0, 0))
def campus_bus_sign():
    """The campus bus stop's sign: a cast iron post in a concrete foot, a round enamel plate, a lit timetable box, a cap of snow on the plate."""
    iron = pk.metal("CSign_Iron", (24, 26, 28), (54, 56, 60), rough=0.5, metallic=0.8)
    enamel = pk.plastic("CSign_Plastic", (34, 84, 120))
    white = mk.flat("CSignDisc_Plastic", srgb(232, 232, 226), 0.3)
    block = mk.noisy("CSign_Concrete", srgb(96, 94, 90), srgb(136, 134, 128), roughness=0.85)
    parts = [pk.rounded("Foot", (1.5, 1.4, 0.3), (0, 0, 0.15), block, r=0.03),
             turned("Post", [(0.0, 0.0), (0.12, 0.0), (0.08, 0.05), (0.06, 0.5), (0.05, 1.0), (0.0, 1.0)], (0, 0, 0.3), (0, 0, 8.2), iron, segments=8),
             mk.cylinder("Plate", 0.82, 0.08, (0, 0, 8.3), rot=(90, 0, 0), mat=enamel, verts=20),
             mk.cylinder("PlateDisc", 0.56, 0.1, (0, 0, 8.3), rot=(90, 0, 0), mat=white, verts=20),
             pk.rounded("TimeBox", (0.86, 0.3, 1.5), (0, -0.2, 4.0), iron, r=0.03)]
    parts.append(snow_on(parts[2:3], snow("CSign"), cell=0.09, depth=0.08, flat=0.3))
    glows = [mk.box("TimePanel", (0.7, 0.012, 1.3), (0, -0.356, 4.0), mat=pk.glow("CSign_Panel", (240, 244, 250), 2.5))]
    return parts, glows


@prop("SchoolClock", pivot="centre", material="Wood", collide=False, texture=256, set="Campus", exact=True)
def school_clock():
    """The auditorium's schoolhouse clock: a long oak regulator case, an enamel dial lit from behind, black hands, a brass pendulum in its glazed door."""
    oak = mk.wood("SClock_Oak", srgb(96, 62, 36), srgb(58, 38, 22), roughness=0.45)
    brass = pk.metal("SClock_Brass", (124, 96, 50), (190, 156, 90), rough=0.32, metallic=1.0)
    black = mk.flat("SClock_Print", srgb(16, 16, 18), 0.7)
    dark = mk.flat("SClock_Dark", srgb(20, 16, 12), 0.8)
    parts = [mk.cylinder("Bezel", 1.2, 0.3, (0, 0, 1.2), rot=(90, 0, 0), mat=oak, verts=24),
             mk.torus("Rim", 1.02, 0.05, (0, -0.2, 1.2), rot=(90, 0, 0), mat=brass, major_segments=24, minor_segments=4),
             pk.rounded("Case", (1.5, 0.5, 3.0), (0, 0.06, -0.9), oak, r=0.04),
             mk.box("Door", (1.0, 0.02, 2.0), (0, -0.2, -0.9), mat=dark),
             mk.box("Plinth", (1.7, 0.56, 0.16), (0, 0.06, -2.34), mat=oak, bevel=0.02, segments=1),
             mk.cylinder("Bob", 0.26, 0.04, (0, -0.226, -1.5), rot=(90, 0, 0), mat=brass, verts=14),
             mk.box("Rod", (0.03, 0.012, 1.2), (0, -0.222, -0.86), mat=brass)]
    for k in range(12):
        a = math.radians(30 * k)
        parts.append(mk.box("Hour", (0.05, 0.012, 0.18), (0.8 * math.sin(a), -0.212, 1.2 + 0.8 * math.cos(a)), rot=(0, 30 * k, 0), mat=black))
    parts += [mk.box("HourHand", (0.07, 0.012, 0.56), (0.2, -0.222, 1.34), rot=(0, 30, 0), mat=black),
              mk.box("MinuteHand", (0.05, 0.012, 0.8), (-0.3, -0.226, 1.42), rot=(0, -40, 0), mat=black),
              mk.cylinder("Boss", 0.06, 0.02, (0, -0.232, 1.2), rot=(90, 0, 0), mat=brass, verts=8)]
    glows = [mk.cylinder("Dial", 1.0, 0.012, (0, -0.2, 1.2), rot=(90, 0, 0), mat=pk.glow("SClock_Dial", (244, 240, 226), 1.6), verts=24)]
    return parts, glows


# Tokyo --------------------------------------------------------------------------------------------------


@prop("WaterServer", pivot="bottom", material="SmoothPlastic", collide=True, texture=256, set="Tokyo", exact=True)
def water_server():
    """A Japanese office water server: a slim white cabinet with a blue bottle on top, red and blue taps over a drip tray, a hot water lock and cup holder at its side."""
    body = pk.plastic("WServer_Plastic", (226, 226, 222))
    dark = mk.flat("WServerDark_Plastic", srgb(40, 42, 46), 0.4)
    bottle = mk.noisy("WServerBottle_Plastic", srgb(86, 150, 210), srgb(150, 200, 236), roughness=0.14)
    hot = pk.plastic("WServerHot_Plastic", (190, 30, 30))
    cold = pk.plastic("WServerCold_Plastic", (30, 90, 180))
    cup = mk.flat("WServer_Paper", srgb(232, 228, 214), 0.7)
    parts = [pk.rounded("Cabinet", (1.2, 1.4, 3.4), (0, 0, 1.76), body, r=0.09),
             mk.box("Recess", (0.9, 0.04, 0.9), (0, -0.7, 2.5), mat=dark),
             mk.box("Tray", (0.9, 0.3, 0.06), (0, -0.74, 2.08), mat=dark, bevel=0.012, segments=1),
             mk.soften(mk.lathe("Bottle", [(0.0, 3.46), (0.2, 3.46), (0.26, 3.6), (0.58, 3.82), (0.6, 4.04), (0.6, 4.86), (0.5, 5.1), (0.0, 5.14)], mat=bottle, segments=14)),
             mk.lathe("Collar", [(0.0, 3.44), (0.4, 3.44), (0.42, 3.54), (0.0, 3.54)], mat=body, segments=14)]
    for x, m in ((-0.22, hot), (0.22, cold)):
        parts.append(mk.box("Tap", (0.2, 0.14, 0.22), (x, -0.76, 2.84), mat=m, bevel=0.03, segments=1))
    parts.append(mk.cylinder("CupTube", 0.12, 1.1, (0.7, 0.2, 2.5), mat=body, verts=10))
    parts.append(mk.soften(mk.lathe("CupStack", [(0.0, 1.9), (0.09, 1.9), (0.12, 2.0), (0.0, 2.0)], (0.7, 0.2, 0), mat=cup, segments=8)))
    return parts, [mk.box("PowerLamp", (0.08, 0.012, 0.05), (0.34, -0.7, 3.1), mat=pk.glow("WServer_Lamp", (120, 220, 170), 3))]


@prop("WardBoard", pivot="centre", material="Wood", collide=True, texture=512, set="Tokyo", exact=True, normal=128)
def ward_board():
    """A neighbourhood association's notice board: a little tin roof over a framed cream panel of posters and rotas, each with a block of print and a coloured band."""
    frame = pk.paint("WBoard_Paint", (52, 62, 58), rough=0.5, wear=12)
    roof = pk.metal("WBoard_Galv", (96, 100, 104), (140, 144, 146), rough=0.5, metallic=0.7)
    panel = mk.flat("WBoard_Paper", srgb(214, 208, 190), 0.9)
    colours = [mk.flat(f"WBoardSheet{i}_Paper", srgb(*c), 0.8) for i, c in enumerate(((232, 226, 206), (214, 226, 232), (240, 214, 170), (226, 188, 180)))]
    bands = [mk.flat(f"WBoardBand{i}_Plastic", srgb(*c), 0.6) for i, c in enumerate(((168, 40, 40), (40, 90, 150), (60, 120, 80)))]
    writing = mk.flat("WBoard_Print", srgb(36, 36, 44), 0.8)
    w, h = 5.7, 3.7
    parts = [mk.box("Back", (w - 0.2, 0.08, h - 0.4), (0, 0.06, -0.1), mat=panel)]
    for z in (h / 2 - 0.32, -h / 2 + 0.08):
        parts.append(mk.box("Rail", (w, 0.2, 0.14), (0, 0, z), mat=frame, bevel=0.015, segments=1))
    for x in (w / 2 - 0.07, -w / 2 + 0.07):
        parts.append(mk.box("Side", (0.14, 0.2, h - 0.4), (x, 0, -0.1), mat=frame, bevel=0.015, segments=1))
    parts.append(sk.wedge("Roof", [(-0.15, h / 2 - 0.26), (0.15, h / 2 - 0.26), (0.15, h / 2), (-0.15, h / 2 - 0.06)], w, 0.0, roof, bevel=0.01))
    rng = random.Random(45)
    for k, (x, z, sw, sh) in enumerate(((-2.0, 0.45, 1.1, 1.3), (-0.75, 0.5, 1.1, 1.2), (0.5, 0.45, 1.1, 1.3), (1.8, 0.5, 1.2, 1.2), (-1.5, -0.95, 1.3, 1.0), (0.1, -0.95, 1.4, 1.0),
                                       (1.75, -0.95, 1.2, 1.0))):
        parts.append(mk.box("Sheet", (sw, 0.008, sh), (x, 0.0, z), mat=colours[k % 4]))
        parts.append(mk.box("Band", (sw - 0.1, 0.004, 0.2), (x, -0.006, z + sh / 2 - 0.2), mat=bands[k % 3]))
        for j in range(rng.randrange(3, 6)):
            parts.append(mk.box("Line", (sw * rng.uniform(0.5, 0.8), 0.004, 0.05), (x, -0.006, z + sh / 2 - 0.44 - j * 0.15), mat=writing))
    return parts, []
