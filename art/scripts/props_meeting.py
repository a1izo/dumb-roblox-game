"""The meeting room's props (set "Meeting", exported to InkboundModels_Meeting.fbx): the Agency's
war room, where every case's survivors meet round one table under one hard light and Zero speaks
from the screen.

- The table and its seats: the round war table (walnut, a leather ring, brass inlay and Zero's red
  ring set in it) and the high-backed leather chairs.
- Round the walls: glazed bookcases, a sideboard with the decanters, a drinks trolley, club
  chairs, a floor globe, the speaker columns either side of Zero's screen, cast-iron radiators
  under the windows, a wall clock just past midnight, archive boxes of old case files.
- Lamps: a brass standard lamp and a green banker's lamp.

Built to the semi-real standard (propkit): real sizes at about 3.5 studs to the metre, bevelled
edges, baked colour and ambient occlusion. Props face -Y and stand on z = 0 (the clock hangs by its
middle). Every glow material has a name of its own per colour (modelkit reuses a material by name
within a build)."""

import math
import random

import modelkit as mk
import propkit as pk
from common import srgb
from props import prop

LAMP_WARM = (255, 210, 150)
ZERO_RED = (255, 36, 52)


def walnut(prefix):
    return mk.wood(prefix + "_Walnut", srgb(96, 62, 40), srgb(44, 26, 16), scale=3.5)


def leather(prefix, rgb=(74, 20, 22)):
    r, g, b = rgb
    return mk.noisy(prefix + "_Leather", srgb(max(0, r - 26), max(0, g - 10), max(0, b - 10)), srgb(r, g, b), scale=16,
                    roughness=0.55)


def brass(prefix):
    return pk.metal(prefix + "_Brass", (134, 102, 50), (188, 152, 84), rough=0.3, metallic=1.0, scale=20)


def chrome(prefix):
    return pk.metal(prefix + "_Chrome", (120, 124, 130), (186, 190, 196), rough=0.2, metallic=1.0, scale=30)


# The table and its seats ------------------------------------------------------------------------------------


@prop("WarTable", pivot="bottom", material="Wood", collide=False, texture=1024, set="Meeting")
def war_table():
    """The Agency's round war table, 26 studs across: a walnut top with a moulded edge and a brass
    band round it, a ring of oxblood leather inlaid between brass lines, Zero's red ring glowing
    in the wood inside it and Zero's mark in brass at the centre; a turned pedestal with eight
    curved brackets under the top. (The map gives it round colliders; the prop itself does not
    collide, so the game's stand-in box never covers the seats.)"""
    wood = walnut("Wtb")
    dark = mk.wood("Wtb_Dark", srgb(52, 32, 20), srgb(24, 14, 8), scale=3)
    hide = leather("Wtb")
    metal = brass("Wtb")
    black = mk.flat("Wtb_Black", srgb(16, 14, 14), 0.5)
    r = 13.05
    parts = [mk.lathe("Top", [(0.0, 2.9), (r - 0.35, 2.9), (r, 3.02), (r, 3.14), (r - 0.15, 3.25), (0.0, 3.25)],
                      mat=wood, segments=72),
             mk.torus("Band", r - 0.02, 0.05, (0, 0, 3.08), mat=metal, major_segments=72, minor_segments=5),
             mk.lathe("Inlay", [(12.2, 3.25), (12.2, 3.268), (9.6, 3.268), (9.6, 3.25)], mat=hide, segments=72)]
    for rr in (12.25, 9.55):
        parts.append(mk.torus("Line", rr, 0.045, (0, 0, 3.262), mat=metal, major_segments=64, minor_segments=4))
    # Zero's mark in the middle: a brass disc with a dark 0 set in it.
    parts += [mk.cylinder("Medal", 1.7, 0.03, (0, 0, 3.262), mat=metal, verts=36),
              mk.cylinder("MedalRing", 1.85, 0.02, (0, 0, 3.255), mat=black, verts=36)]
    zero = mk.torus("Zero", 0.85, 0.16, (0, 0, 3.28), mat=black, major_segments=28, minor_segments=5)
    zero.scale = (0.68, 1.0, 0.25)
    parts.append(zero)
    # The pedestal and its brackets.
    parts.append(mk.lathe("Pedestal", [(0.0, 0.0), (5.0, 0.0), (5.0, 0.22), (4.5, 0.4), (3.3, 0.62), (2.3, 0.95),
                                       (1.85, 1.35), (1.75, 2.1), (2.1, 2.4), (2.9, 2.7), (3.1, 2.9), (0.0, 2.9)],
                          mat=dark, segments=40))
    for k in range(8):
        a = 2 * math.pi * k / 8 + math.pi / 8
        c, s = math.cos(a), math.sin(a)
        pts = [(c * 2.0, s * 2.0, 2.2), (c * 4.2, s * 4.2, 2.62), (c * 6.4, s * 6.4, 2.86), (c * 7.4, s * 7.4, 2.9)]
        for t in range(3):
            parts.append(mk.tube("Bracket", pts[t], pts[t + 1], 0.2 - t * 0.04, 0.16 - t * 0.04, mat=dark, verts=6))
    parts.append(mk.torus("Foot", 4.9, 0.06, (0, 0, 0.2), mat=metal, major_segments=48, minor_segments=4))
    glows = [mk.torus("RedRing", 8.9, 0.07, (0, 0, 3.255), mat=pk.glow("Wtb_Red", ZERO_RED, 5), major_segments=72,
                      minor_segments=4)]
    return parts, glows


@prop("WarChair", pivot="bottom", material="Leather", collide=True, texture=1024, set="Meeting")
def war_chair():
    """A high-backed executive chair in buttoned oxblood leather: a chrome five-star base on
    castors, the seat, the tall tufted back leaning a little, padded arms on chrome."""
    hide = leather("Wch")
    dark = pk.metal("Wch_Dark", (18, 18, 20), (34, 34, 38), rough=0.5, metallic=0.3)
    metal = chrome("Wch")
    button = mk.flat("Wch_Button", srgb(30, 8, 10), 0.4)
    parts = [mk.cylinder("Hub", 0.28, 0.25, (0, 0, 0.42), mat=metal, verts=12),
             mk.cylinder("Column", 0.12, 1.1, (0, 0, 1.0), mat=metal, verts=10),
             mk.cylinder("Shroud", 0.22, 0.5, (0, 0, 0.8), mat=dark, verts=12, radius2=0.16)]
    for k in range(5):
        a = 2 * math.pi * k / 5 + math.pi / 2
        c, s = math.cos(a), math.sin(a)
        parts.append(mk.tube("Leg", (c * 0.2, s * 0.2, 0.42), (c * 1.08, s * 1.08, 0.3), 0.09, 0.06, mat=metal, verts=6))
        parts.append(mk.sphere("Castor", 0.15, (c * 1.1, s * 1.1, 0.15), scale=(1, 0.7, 1), mat=dark, segments=8, rings=6))
    parts += [pk.rounded("Seat", (2.1, 2.0, 0.5), (0, -0.05, 1.72), hide, r=0.18),
              pk.rounded("SeatPan", (1.8, 1.7, 0.16), (0, -0.05, 1.42), dark, r=0.05)]
    back = pk.rounded("Back", (2.05, 0.55, 3.2), (0, 0.92, 3.55), hide, r=0.24, rot=(-8, 0, 0))
    parts.append(back)
    parts.append(pk.rounded("Headroll", (1.9, 0.62, 0.55), (0, 1.1, 5.0), hide, r=0.24, rot=(-8, 0, 0)))
    # Buttons in the tufting (on the front of the back, tilted with it).
    tilt = math.radians(-8)
    for row in range(3):
        for col in range(3 if row % 2 == 0 else 2):
            x = (col - (1 if row % 2 == 0 else 0.5)) * 0.55
            zl = 2.7 + row * 0.62
            yl = 0.92 - 0.28
            # Rotate the local point about the back's centre by the tilt.
            dz, dy = zl - 3.55, yl - 0.92
            wy = 0.92 + dy * math.cos(tilt) - dz * math.sin(tilt)
            wz = 3.55 + dy * math.sin(tilt) + dz * math.cos(tilt)
            parts.append(mk.sphere("Button", 0.06, (x, wy - 0.02, wz), mat=button, segments=6, rings=4))
    for sx in (-1, 1):
        parts += [mk.tube("ArmPost", (sx * 1.0, 0.3, 1.7), (sx * 1.05, 0.1, 2.55), 0.06, mat=metal, verts=6),
                  mk.tube("ArmPost", (sx * 1.0, -0.6, 1.7), (sx * 1.05, -0.55, 2.55), 0.06, mat=metal, verts=6),
                  pk.rounded("ArmPad", (0.36, 1.35, 0.22), (sx * 1.05, -0.2, 2.62), hide, r=0.1)]
    return parts, []


# Round the walls --------------------------------------------------------------------------------------------


@prop("Sideboard", pivot="bottom", material="Wood", collide=True, texture=1024, set="Meeting")
def sideboard():
    """A long walnut sideboard with four panelled doors and brass pulls; on it a silver tray with a
    decanter and tumblers, an ice bucket, a cigar box and a stack of case folders."""
    wood = walnut("Sdb")
    dark = mk.wood("Sdb_Dark", srgb(52, 32, 20), srgb(24, 14, 8), scale=3)
    metal = brass("Sdb")
    silver = chrome("Sdb")
    amber = pk.dark_glass("Sdb_Amber", tint=(58, 30, 12))
    glass = pk.dark_glass("Sdb_Glass", tint=(40, 46, 52))
    folder = mk.noisy("Sdb_Folder", srgb(150, 128, 88), srgb(186, 164, 120), scale=20, roughness=0.8)
    tape = mk.flat("Sdb_Tape", srgb(150, 22, 30), 0.6)
    w, d, h = 10.0, 2.2, 3.3
    parts = [mk.box("Plinth", (w - 0.3, d - 0.3, 0.3), (0, 0.05, 0.15), mat=dark, bevel=0.03),
             mk.box("Body", (w, d, h - 0.5), (0, 0, 0.3 + (h - 0.5) / 2), mat=wood, bevel=0.04),
             mk.box("Top", (w + 0.3, d + 0.25, 0.18), (0, 0, h - 0.09), mat=wood, bevel=0.05)]
    for k in range(4):
        x = -w / 2 + w / 8 + k * w / 4
        parts += [mk.box("Door", (w / 4 - 0.25, 0.08, h - 1.0), (x, -d / 2 - 0.02, 0.3 + (h - 0.5) / 2), mat=wood,
                         bevel=0.03),
                  mk.box("Panel", (w / 4 - 0.8, 0.06, h - 1.6), (x, -d / 2 - 0.07, 0.3 + (h - 0.5) / 2), mat=dark,
                         bevel=0.05)]
        parts += pk.handle("Pull", x + (0.7 if k % 2 == 0 else -0.7), -d / 2 - 0.06, 1.9, 0.5, metal, stand=0.1, r=0.035)
    top = h
    parts += [mk.cylinder("Tray", 1.2, 0.06, (-2.5, 0.1, top + 0.03), mat=silver, verts=24),
              mk.lathe("Decanter", [(0.0, 0.0), (0.42, 0.02), (0.46, 0.5), (0.3, 0.85), (0.14, 1.0), (0.14, 1.25),
                                    (0.0, 1.25)], (-2.8, 0.2, top + 0.06), mat=amber, segments=12),
              mk.sphere("Stopper", 0.16, (-2.8, 0.2, top + 1.42), mat=glass, segments=8, rings=6)]
    for k, (x, y) in enumerate(((-2.0, -0.3), (-1.8, 0.4), (-2.3, 0.6))):
        parts.append(mk.cylinder("Tumbler", 0.18, 0.42, (x, y, top + 0.27), mat=glass, verts=10, radius2=0.2))
    parts += [mk.cylinder("IceBucket", 0.42, 0.7, (-0.5, 0.3, top + 0.35), mat=silver, verts=16, radius2=0.48),
              mk.box("CigarBox", (1.1, 0.7, 0.35), (1.2, 0.4, top + 0.175), mat=dark, bevel=0.03)]
    for k in range(5):
        parts.append(mk.box("Folder", (1.6, 1.15, 0.08), (3.5 + (k % 2) * 0.08, 0.1, top + 0.05 + k * 0.09),
                            rot=(0, 0, (k * 7) % 11 - 5), mat=folder))
    parts.append(mk.box("Tape", (0.12, 1.2, 0.5), (3.5, 0.1, top + 0.25), mat=tape))
    return parts, []


@prop("FloorGlobe", pivot="bottom", material="Wood", collide=True, texture=1024, set="Meeting")
def floor_globe():
    """A library globe on its walnut stand: three curved legs, the broad horizon ring, the brass
    meridian and the old sepia-and-slate world turning on its tilted axis."""
    wood = walnut("Glb")
    metal = brass("Glb")
    world = mk.noisy("Glb_World", srgb(60, 74, 82), srgb(170, 146, 100), scale=2.6, detail=4, roughness=0.5)
    parts = [mk.sphere("World", 1.1, (0, 0, 3.4), mat=world, segments=24, rings=16),
             mk.lathe("Horizon", [(1.25, 2.95), (1.65, 2.95), (1.65, 3.12), (1.25, 3.12)], mat=wood, segments=32)]
    meridian = mk.torus("Meridian", 1.2, 0.05, (0, 0, 3.4), rot=(0, 23, 0), mat=metal, major_segments=36, minor_segments=4)
    meridian.rotation_euler = (math.radians(90), math.radians(23), 0)
    parts.append(meridian)
    for k in range(3):
        a = 2 * math.pi * k / 3 + math.pi / 2
        c, s = math.cos(a), math.sin(a)
        pts = [(c * 1.45, s * 1.45, 2.95), (c * 1.35, s * 1.35, 1.9), (c * 0.9, s * 0.9, 0.9), (c * 1.3, s * 1.3, 0.1)]
        for t in range(3):
            parts.append(mk.tube("Leg", pts[t], pts[t + 1], 0.13, 0.11, mat=wood, verts=7))
    parts += [mk.cylinder("Stretcher", 0.9, 0.12, (0, 0, 0.9), mat=wood, verts=16),
              mk.cylinder("Finial", 0.18, 0.5, (0, 0, 0.55), mat=metal, verts=8, radius2=0.05),
              mk.tube("Axis", (-0.47, 0, 2.3), (0.47, 0, 4.5), 0.03, mat=metal, verts=5)]
    return parts, []


@prop("SpeakerColumn", pivot="bottom", material="Wood", collide=True, texture=1024, set="Meeting")
def speaker_column():
    """One of the tall speaker columns either side of Zero's screen: a walnut cabinet with a black
    cloth front over three drivers, brass bands, and a small red lamp at its head that lights when
    Zero speaks."""
    wood = walnut("Spk")
    cloth = mk.noisy("Spk_Cloth", srgb(16, 16, 18), srgb(30, 30, 32), scale=60, roughness=0.95)
    metal = brass("Spk")
    rim = pk.metal("Spk_Rim", (22, 22, 24), (40, 40, 44), rough=0.5, metallic=0.3)
    w, d, h = 2.4, 1.8, 9.0
    parts = [mk.box("Plinth", (w + 0.2, d + 0.2, 0.3), (0, 0, 0.15), mat=wood, bevel=0.04),
             mk.box("Cabinet", (w, d, h - 0.6), (0, 0, 0.3 + (h - 0.6) / 2), mat=wood, bevel=0.05),
             mk.box("Cap", (w + 0.25, d + 0.25, 0.3), (0, 0, h - 0.15), mat=wood, bevel=0.05),
             mk.box("Grille", (w - 0.4, 0.06, h - 2.0), (0, -d / 2 - 0.02, 0.3 + (h - 0.6) / 2 - 0.2), mat=cloth, bevel=0.02)]
    for z in (1.0, h - 1.1):
        parts.append(mk.box("Band", (w + 0.02, d + 0.02, 0.12), (0, 0, z), mat=metal))
    for k, (z, r) in enumerate(((2.6, 0.75), (4.6, 0.75), (6.4, 0.45))):
        parts.append(mk.torus("Driver", r, 0.05, (0, -d / 2 - 0.06, z), rot=(90, 0, 0), mat=rim, major_segments=24,
                              minor_segments=4))
    glows = [mk.sphere("Lamp", 0.11, (0, -d / 2 - 0.05, h - 0.55), mat=pk.glow("Spk_Red", ZERO_RED, 6), segments=8, rings=6)]
    return parts, glows


@prop("BookcaseTall", pivot="bottom", material="Wood", collide=True, texture=1024, set="Meeting")
def bookcase_tall():
    """A tall walnut bookcase with glazing bars over its upper shelves (full of old law books and
    case binders), a cupboard below and a moulded cornice."""
    rng = random.Random(12)
    wood = walnut("Bkc")
    dark = mk.wood("Bkc_Dark", srgb(40, 24, 14), srgb(18, 10, 6), scale=3)
    metal = brass("Bkc")
    spines = [mk.noisy(f"Bkc_Book{k}", srgb(*a), srgb(*b), scale=30, roughness=0.7) for k, (a, b) in enumerate((
        ((70, 16, 18), (104, 28, 28)), ((22, 44, 32), (40, 70, 50)), ((24, 30, 52), (40, 50, 84)),
        ((70, 50, 30), (110, 82, 52)), ((30, 28, 26), (52, 48, 44))))]
    gold = mk.flat("Bkc_Gilt", srgb(170, 136, 70), 0.4, 0.8)
    w, d, h = 4.2, 1.6, 9.0
    parts = [mk.box("Back", (w, 0.12, h - 0.4), (0, d / 2 - 0.06, (h - 0.4) / 2 + 0.2), mat=dark),
             mk.box("Plinth", (w + 0.1, d + 0.05, 0.4), (0, 0, 0.2), mat=wood, bevel=0.03),
             mk.box("Cornice", (w + 0.4, d + 0.3, 0.35), (0, -0.1, h - 0.17), mat=wood, bevel=0.06),
             mk.box("Frieze", (w + 0.1, d + 0.1, 0.25), (0, 0, h - 0.47), mat=dark, bevel=0.02)]
    for sx in (-1, 1):
        parts.append(mk.box("Side", (0.16, d, h - 0.6), (sx * (w / 2 - 0.08), 0, (h - 0.6) / 2 + 0.2), mat=wood,
                            bevel=0.02))
    # The cupboard below.
    parts.append(mk.box("Cupboard", (w - 0.3, 0.1, 2.4), (0, -d / 2 + 0.05, 1.6), mat=wood, bevel=0.03))
    for sx in (-1, 1):
        parts.append(mk.box("CupPanel", (w / 2 - 0.55, 0.06, 1.8), (sx * (w / 4 - 0.05), -d / 2 - 0.02, 1.6), mat=dark,
                            bevel=0.04))
        parts.append(mk.sphere("Knob", 0.08, (sx * 0.25, -d / 2 - 0.08, 1.7), mat=metal, segments=8, rings=6))
    # Shelves and books.
    shelf_z = [2.85, 4.4, 5.95, 7.5]
    for z in shelf_z:
        parts.append(mk.box("Shelf", (w - 0.3, d - 0.2, 0.1), (0, 0.05, z), mat=wood))
    for z0, z1 in zip(shelf_z, shelf_z[1:] + [h - 0.6]):
        x = -w / 2 + 0.25
        while x < w / 2 - 0.4:
            bw = rng.uniform(0.16, 0.34)
            bh = min(z1 - z0 - 0.15, rng.uniform(0.9, 1.35))
            lean = 0 if rng.random() > 0.1 else rng.uniform(-9, 9)
            parts.append(mk.box("Book", (bw, d - 0.5, bh), (x + bw / 2, 0.05, z0 + 0.05 + bh / 2), rot=(0, lean, 0),
                                mat=rng.choice(spines)))
            if rng.random() < 0.4:
                parts.append(mk.box("Gilt", (bw * 0.8, 0.02, 0.06), (x + bw / 2, -d / 2 + 0.24, z0 + 0.05 + bh * 0.75),
                                    mat=gold))
            x += bw + rng.uniform(0.0, 0.03)
    # The glazing bars over the upper shelves (no glass: it would bake opaque over the books).
    for sx in (-1, 1):
        cx = sx * (w / 4 - 0.02)
        parts += pk.frame("Door", w / 2 - 0.15, h - 3.5, 0.14, 0.08, (cx, -d / 2 + 0.02, 2.75 + (h - 3.5) / 2), wood)
        parts.append(mk.box("Bar", (0.05, 0.05, h - 3.7), (cx, -d / 2, 2.75 + (h - 3.5) / 2), mat=wood))
        for k in range(1, 3):
            parts.append(mk.box("Bar", (w / 2 - 0.3, 0.05, 0.05), (cx, -d / 2, 2.75 + k * (h - 3.5) / 3), mat=wood))
    return parts, []


@prop("ClubChair", pivot="bottom", material="Leather", collide=True, texture=1024, set="Meeting")
def club_chair():
    """A deep leather club chair: rounded arms rolled over at the front with brass nail heads, a
    low back, a thick seat cushion, short turned feet."""
    hide = leather("Clb", (60, 34, 22))
    wood = walnut("Clb")
    metal = brass("Clb")
    parts = [pk.rounded("Base", (3.2, 3.0, 1.2), (0, 0, 0.9), hide, r=0.3),
             pk.rounded("Cushion", (2.2, 2.4, 0.55), (0, -0.2, 1.72), hide, r=0.22),
             pk.rounded("Back", (3.0, 0.7, 1.9), (0, 1.2, 2.25), hide, r=0.32, rot=(-6, 0, 0))]
    for sx in (-1, 1):
        parts += [pk.rounded("Arm", (0.6, 3.0, 1.4), (sx * 1.35, 0, 1.95), hide, r=0.28),
                  mk.cylinder("Roll", 0.42, 0.6, (sx * 1.35, -1.35, 2.25), rot=(0, 90, 0), mat=hide, verts=12)]
        for k in range(9):
            a = math.pi * k / 8
            parts.append(mk.sphere("Nail", 0.04, (sx * 1.35 + math.cos(a) * 0.45 * 0.9, -1.58, 2.25 + math.sin(a) * 0.45),
                                   mat=metal, segments=5, rings=3))
        for y in (-1.2, 1.2):
            parts.append(mk.cylinder("Foot", 0.14, 0.3, (sx * 1.3, y, 0.15), mat=wood, verts=8, radius2=0.1))
    return parts, []


@prop("DrinksTrolley", pivot="bottom", material="Metal", collide=True, texture=512, set="Meeting")
def drinks_trolley():
    """A brass drinks trolley: two dark glass shelves on a tubular frame with a handle, small
    wheels, bottles and glasses."""
    metal = brass("Trl")
    glass = pk.dark_glass("Trl_Glass", tint=(30, 34, 40))
    rubber = pk.rubber("Trl_Rubber")
    bottles = [pk.dark_glass("Trl_Bottle1", tint=(40, 60, 30)), pk.dark_glass("Trl_Bottle2", tint=(70, 36, 14)),
               pk.dark_glass("Trl_Bottle3", tint=(26, 26, 34))]
    label = mk.flat("Trl_Label", srgb(214, 200, 160), 0.7)
    w, d = 3.2, 1.6
    parts = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(mk.tube("Post", (sx * w / 2, sy * d / 2, 0.35), (sx * w / 2, sy * d / 2, 2.8), 0.05, mat=metal,
                                 verts=8))
            parts.append(mk.cylinder("Wheel", 0.2, 0.1, (sx * w / 2, sy * d / 2, 0.2), rot=(90, 0, 0), mat=rubber, verts=12))
    for z in (0.8, 2.3):
        parts.append(mk.box("Shelf", (w, d, 0.05), (0, 0, z), mat=glass))
        for sx in (-1, 1):
            parts.append(mk.tube("Rail", (sx * w / 2, -d / 2, z + 0.04), (sx * w / 2, d / 2, z + 0.04), 0.04, mat=metal,
                                 verts=6))
        for sy in (-1, 1):
            parts.append(mk.tube("Rail", (-w / 2, sy * d / 2, z + 0.04), (w / 2, sy * d / 2, z + 0.04), 0.04, mat=metal,
                                 verts=6))
    parts.append(mk.tube("Handle", (w / 2 + 0.3, -d / 2, 2.8), (w / 2 + 0.3, d / 2, 2.8), 0.05, mat=metal, verts=8))
    for sy in (-1, 1):
        parts.append(mk.tube("HandleArm", (w / 2, sy * d / 2, 2.8), (w / 2 + 0.3, sy * d / 2, 2.8), 0.04, mat=metal,
                             verts=6))
    for k, x in enumerate((-1.1, -0.5, 0.2)):
        parts += pk.bottle(f"Bottle{k}", x, 0.1, 2.33, bottles[k], metal, r=0.22, h=1.3)
        parts.append(mk.cylinder("Label", 0.225, 0.35, (x, 0.1, 2.33 + 0.45), mat=label, verts=12))
    for k in range(3):
        parts.append(mk.cylinder("Glass", 0.16, 0.36, (0.9 + k * 0.35, -0.3, 2.33 + 0.18), mat=glass, verts=10,
                                 radius2=0.18))
    return parts, []


@prop("Radiator", pivot="bottom", material="Metal", collide=True, texture=512, set="Meeting")
def radiator():
    """A cast-iron column radiator under a window, painted a worn cream, its valve and pipe at one
    end."""
    paint = pk.paint("Rad_Paint", (170, 160, 138), rough=0.6, wear=26)
    iron = pk.metal("Rad_Iron", (30, 30, 32), (54, 52, 50), rough=0.6, metallic=0.5)
    w, h = 5.4, 2.8
    count = 14
    parts = []
    for k in range(count):
        x = -w / 2 + w * (k + 0.5) / count
        parts.append(pk.rounded("Column", (w / count - 0.06, 0.7, h - 0.5), (x, 0, 0.35 + (h - 0.5) / 2), paint, r=0.12))
    for z in (0.55, h - 0.25):
        parts.append(mk.tube("Header", (-w / 2, 0, z), (w / 2, 0, z), 0.14, mat=paint, verts=8))
    for sx in (-1, 1):
        parts.append(mk.box("Foot", (0.35, 0.8, 0.35), (sx * (w / 2 - 0.4), 0, 0.175), mat=paint, bevel=0.04))
    parts += [mk.tube("Pipe", (w / 2, 0, 0.55), (w / 2 + 0.5, 0, 0.55), 0.12, mat=iron, verts=8),
              mk.tube("PipeDown", (w / 2 + 0.5, 0, 0.55), (w / 2 + 0.5, 0, 0.0), 0.12, mat=iron, verts=8),
              mk.cylinder("Valve", 0.2, 0.35, (w / 2 + 0.25, 0, 0.85), mat=iron, verts=10),
              mk.cylinder("Wheel", 0.28, 0.06, (w / 2 + 0.25, 0, 1.08), mat=iron, verts=12)]
    return parts, []


@prop("WallClock", pivot="centre", material="Wood", collide=False, texture=512, set="Meeting")
def wall_clock():
    """The war room's wall clock: a walnut case, a brass bezel, a cream dial with bold hour marks,
    its hands standing at three minutes past midnight."""
    wood = walnut("Wcl")
    metal = brass("Wcl")
    dial = mk.noisy("Wcl_Dial", srgb(212, 200, 172), srgb(232, 224, 204), scale=20, roughness=0.6)
    ink = mk.flat("Wcl_Ink", srgb(16, 14, 14), 0.5)
    red = mk.flat("Wcl_Red", srgb(150, 20, 28), 0.5)
    r = 1.6
    parts = [mk.cylinder("Case", r, 0.4, (0, 0.2, 0), rot=(90, 0, 0), mat=wood, verts=40, bevel=0.06),
             mk.torus("Bezel", r - 0.1, 0.1, (0, -0.02, 0), rot=(90, 0, 0), mat=metal, major_segments=40, minor_segments=6),
             mk.cylinder("Dial", r - 0.18, 0.02, (0, -0.01, 0), rot=(90, 0, 0), mat=dial, verts=40)]
    for k in range(60):
        a = 2 * math.pi * k / 60
        big = k % 5 == 0
        length = 0.28 if big else 0.1
        rr = r - 0.34 - length / 2
        parts.append(mk.box("Mark", (0.07 if big else 0.025, 0.02, length), (math.sin(a) * rr, -0.03, math.cos(a) * rr),
                            rot=(0, math.degrees(a), 0), mat=ink))
    # 00:03: the hour hand a hair past twelve, the minute hand three minutes on.
    hour = math.radians(1.5)
    minute = math.radians(18)
    parts += [mk.box("Hour", (0.12, 0.03, 0.8), (math.sin(hour) * 0.34, -0.06, math.cos(hour) * 0.34), rot=(0, math.degrees(hour), 0),
                     mat=ink),
              mk.box("Minute", (0.07, 0.03, 1.12), (math.sin(minute) * 0.5, -0.08, math.cos(minute) * 0.5),
                     rot=(0, math.degrees(minute), 0), mat=ink),
              mk.box("Second", (0.02, 0.02, 1.2), (math.sin(math.radians(200)) * 0.45, -0.1, math.cos(math.radians(200)) * 0.45),
                     rot=(0, 200, 0), mat=red),
              mk.cylinder("Pin", 0.07, 0.1, (0, -0.1, 0), rot=(90, 0, 0), mat=metal, verts=8)]
    return parts, []


@prop("CaseFiles", pivot="bottom", material="SmoothPlastic", collide=True, texture=512, set="Meeting")
def case_files():
    """Archive boxes of old case files stacked in a corner: stencilled numbers, string-tied folders
    on top, one lid askew."""
    rng = random.Random(4)
    card = mk.noisy("Csf_Card", srgb(130, 110, 80), srgb(168, 146, 108), scale=18, roughness=0.9)
    grey = mk.noisy("Csf_Grey", srgb(96, 96, 94), srgb(126, 124, 120), scale=18, roughness=0.9)
    ink = mk.flat("Csf_Ink", srgb(24, 22, 20), 0.6)
    folder = mk.noisy("Csf_Folder", srgb(160, 138, 96), srgb(196, 176, 130), scale=20, roughness=0.8)
    string = mk.flat("Csf_String", srgb(150, 24, 30), 0.7)
    parts = []
    boxes = [(-0.65, 0.0, 0.0, card), (0.65, 0.05, 0.0, grey), (-0.6, -0.05, 1.0, grey), (0.7, 0.0, 1.0, card),
             (0.0, 0.1, 2.0, card)]
    for k, (x, y, z, m) in enumerate(boxes):
        yaw = rng.uniform(-4, 4)
        parts.append(mk.box(f"Box{k}", (1.25, 1.7, 0.95), (x, y, z + 0.475), rot=(0, 0, yaw), mat=m, bevel=0.02))
        parts.append(mk.box(f"Lid{k}", (1.3, 1.75, 0.18), (x, y, z + 0.9), rot=(0, 0, yaw + (6 if k == 4 else 0)), mat=m,
                            bevel=0.02))
        parts.append(mk.box(f"Stencil{k}", (0.6, 0.02, 0.25), (x, y - 0.86, z + 0.5), rot=(0, 0, yaw), mat=ink))
        parts.append(mk.box(f"Hole{k}", (0.35, 0.03, 0.12), (x, y - 0.86, z + 0.78), rot=(0, 0, yaw), mat=ink))
    for k in range(3):
        parts.append(mk.box("Folder", (1.0, 1.4, 0.07), (0.05, 0.1, 3.0 + k * 0.08), rot=(0, 0, k * 9 - 6), mat=folder))
    # The red string tied round the folders, crossing on top.
    parts += [mk.box("Tie", (0.03, 1.42, 0.3), (0.05, 0.1, 3.08), rot=(0, 0, 3), mat=string),
              mk.box("Tie", (1.02, 0.03, 0.3), (0.05, 0.1, 3.08), rot=(0, 0, 3), mat=string),
              mk.box("Knot", (0.12, 0.12, 0.06), (0.05, 0.1, 3.25), mat=string)]
    return parts, []


@prop("FloorLamp", pivot="bottom", material="Metal", collide=False, texture=512, set="Meeting",
      lights=[dict(at=(0, 0, 5.4), kind="point", color=LAMP_WARM, range=15, brightness=0.9)])
def floor_lamp():
    """A brass standard lamp: a weighted base, a reeded pole, a pleated parchment drum shade with
    the bulb glowing under it."""
    metal = brass("Flp")
    shade = mk.banded("Flp_Shade", srgb(176, 156, 118), srgb(206, 188, 150), frequency=80, axis="X", roughness=0.8)
    parts = [mk.lathe("Base", [(0.0, 0.0), (0.75, 0.0), (0.75, 0.08), (0.5, 0.2), (0.14, 0.3), (0.0, 0.3)], mat=metal,
                      segments=20),
             mk.cylinder("Pole", 0.06, 5.0, (0, 0, 2.8), mat=metal, verts=8),
             mk.sphere("Knuckle", 0.12, (0, 0, 2.2), mat=metal, segments=8, rings=6),
             mk.lathe("Shade", [(1.05, 4.9), (0.72, 6.1), (0.68, 6.1), (1.0, 4.9)], mat=shade, segments=24)]
    glows = [mk.sphere("Bulb", 0.22, (0, 0, 5.3), mat=pk.glow("Flp_Bulb", LAMP_WARM, 4), segments=10, rings=8)]
    return parts, glows


@prop("BankerLamp", pivot="bottom", material="Metal", collide=False, texture=256, set="Meeting",
      lights=[dict(at=(0, -0.2, 1.1), kind="point", color=LAMP_WARM, range=9, brightness=0.6)])
def banker_lamp():
    """A green banker's lamp: a brass base and stem, the long green glass shade, its pull chain."""
    metal = brass("Bnk")
    green = mk.noisy("Bnk_Green", srgb(20, 70, 44), srgb(40, 110, 70), scale=12, roughness=0.15)
    parts = [pk.rounded("Base", (1.3, 0.8, 0.14), (0, 0, 0.07), metal, r=0.05),
             mk.tube("Stem", (0, 0.1, 0.14), (0, 0.1, 1.05), 0.04, mat=metal, verts=6),
             mk.tube("Yoke", (-0.4, 0.05, 1.05), (0.4, 0.05, 1.05), 0.03, mat=metal, verts=6)]
    shade = mk.cylinder("Shade", 0.34, 1.3, (0, -0.05, 1.12), rot=(0, 90, 0), mat=green, verts=16)
    parts.append(shade)
    parts += [mk.tube("Chain", (0.3, -0.25, 1.05), (0.3, -0.25, 0.65), 0.012, mat=metal, verts=3),
              mk.sphere("Pull", 0.04, (0.3, -0.25, 0.63), mat=metal, segments=6, rings=4)]
    glows = [mk.box("Bulb", (1.0, 0.16, 0.06), (0, -0.05, 0.84), mat=pk.glow("Bnk_Bulb", LAMP_WARM, 3))]
    return parts, glows
