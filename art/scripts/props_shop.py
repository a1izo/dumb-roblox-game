"""The things the shop's styles, forms and emotes hold or show (Core set; see props.py): the quill and the
knife of Diavolo's writing styles, Ace's gavel, chess king and sugar cube, the coin and the apple of two
emotes, and what three Deathsinger forms wear (a chain, a cloak of crow feathers, a marionette's
control bar). Each is small and plain enough to be held in a hand or hung on a ghost, and is seen up close
in the shop's "Your look"."""

import math

import bpy
from mathutils import Matrix, Vector

import modelkit as mk
import propkit as pk
from common import srgb
from props import BRASS_A, BRASS_B, prop

IVORY_A, IVORY_B = srgb(206, 198, 180), srgb(236, 230, 214)
EBONY_A, EBONY_B = srgb(14, 13, 13), srgb(36, 33, 32)
IRON_A, IRON_B = srgb(30, 30, 33), srgb(62, 60, 60)


@prop("Quill", pivot="centre", material="SmoothPlastic", collide=False, texture=256)
def quill():
    """A long black writing quill with a steel nib: Diavolo's Bleeding Quill (the red is the game's ink)."""
    vane = mk.noisy("Qu_Feather", srgb(18, 17, 19), srgb(44, 42, 46), roughness=0.7, kind="cloth")
    shaft = mk.noisy("Qu_Bone", srgb(170, 164, 150), srgb(214, 208, 194), roughness=0.5)
    nib = mk.noisy("Qu_Steel", srgb(90, 92, 98), srgb(150, 152, 160), roughness=0.3, metallic=1.0)
    parts = [mk.tube("Shaft", (0, 0, -1.0), (0, 0, 1.15), 0.035, 0.012, mat=shaft, verts=8),
             mk.lathe("Nib", [(0.035, -1.0), (0.03, -1.12), (0.0, -1.26)], mat=nib, segments=8)]
    # The vane: two curved blades of feather either side of the shaft, widest two thirds of the way up.
    for side in (-1, 1):
        grid = []
        for j in range(9):
            t = j / 8
            z = -0.55 + 1.75 * t
            width = 0.26 * math.sin(math.pi * min(1.0, t * 1.15)) + 0.02
            row = []
            for i in range(4):
                u = i / 3
                row.append((side * (0.02 + width * u), -0.04 * u * u, z + 0.08 * u))
            grid.append(row)
        parts.append(mk.sheet("Vane", grid, vane))
    return parts, []


@prop("Knife", pivot="centre", material="Metal", collide=False, texture=256)
def knife():
    """A plain kitchen knife, worn: The Knife, Diavolo's style that carves the name instead of writing it."""
    steel = mk.noisy("Kn_Steel", srgb(120, 122, 128), srgb(186, 188, 194), roughness=0.25, metallic=1.0)
    handle = mk.noisy("Kn_Wood", srgb(34, 24, 18), srgb(66, 46, 34), roughness=0.6, kind="dark_wood")
    rivet = mk.flat("Kn_Brass", BRASS_B, 0.4, metallic=1.0)
    blade = [(0.0, 0.0), (1.25, 0.0), (1.42, 0.05), (1.3, 0.16), (0.9, 0.24), (0.0, 0.26)]
    parts = [mk.extrude_shape("Blade", blade, 0.025, loc=(0.0, 0.0, -0.13), rot=(90, 0, 0), mat=steel, bevel=0.008),
             pk.rounded("Handle", (0.9, 0.11, 0.22), (-0.47, 0.0, 0.0), handle, r=0.04),
             mk.box("Bolster", (0.06, 0.09, 0.27), (-0.01, 0.0, 0.0), mat=steel, bevel=0.01)]
    for x in (-0.25, -0.65):
        parts.append(mk.cylinder("Rivet", 0.025, 0.13, (x, 0.0, 0.0), rot=(90, 0, 0), mat=rivet, verts=8))
    return parts, []


@prop("Gavel", pivot="centre", material="Wood", collide=False, texture=256)
def gavel():
    """A judge's gavel in dark polished wood with brass bands: Ace's Gavel."""
    wood = mk.noisy("Gv_Wood", srgb(40, 24, 16), srgb(84, 52, 34), roughness=0.35, kind="dark_wood")
    brass = mk.noisy("Gv_Brass", BRASS_B, BRASS_A, roughness=0.3, metallic=1.0)
    parts = [mk.cylinder("Head", 0.24, 0.95, (0, 0, 0.62), rot=(0, 90, 0), mat=wood, verts=16, bevel=0.03),
             mk.tube("Handle", (0, 0, 0.5), (0, 0, -0.95), 0.06, 0.075, mat=wood, verts=10),
             mk.sphere("Knob", 0.09, (0, 0, -0.97), mat=wood, segments=10, rings=6)]
    for x in (-0.36, 0.36):
        parts.append(mk.cylinder("Band", 0.25, 0.06, (x, 0, 0.62), rot=(0, 90, 0), mat=brass, verts=16))
    return parts, []


@prop("ChessKing", pivot="bottom", material="SmoothPlastic", collide=False, texture=256)
def chess_king():
    """A black chess king, lacquered: Ace's Checkmate (it tips over on the arrest)."""
    ebony = mk.noisy("Ck_Ebony", EBONY_A, EBONY_B, roughness=0.25, kind="dark_wood")
    felt = mk.flat("Ck_Felt", srgb(30, 50, 34), 0.95)
    profile = [(0.0, 0.0), (0.42, 0.0), (0.44, 0.06), (0.4, 0.14), (0.3, 0.2), (0.32, 0.26), (0.22, 0.34), (0.16, 0.7),
               (0.14, 1.0), (0.26, 1.06), (0.27, 1.12), (0.16, 1.16), (0.22, 1.36), (0.24, 1.46), (0.0, 1.48)]
    parts = [mk.lathe("Body", profile, mat=ebony, segments=20),
             mk.cylinder("Felt", 0.41, 0.01, (0, 0, 0.004), mat=felt, verts=20),
             mk.box("CrossV", (0.07, 0.07, 0.34), (0, 0, 1.62), mat=ebony, bevel=0.01),
             mk.box("CrossH", (0.22, 0.07, 0.07), (0, 0, 1.66), mat=ebony, bevel=0.01)]
    return parts, []


@prop("SugarCube", pivot="bottom", material="Sand", collide=False, texture=256)
def sugar_cube():
    """A sugar cube, its corners a little crumbled: Ace's Sweet Justice (L's tower of them)."""
    sugar = mk.noisy("Sc_Sugar", srgb(222, 220, 214), srgb(250, 249, 246), roughness=0.9, kind="stone")
    cube = mk.box("Cube", (0.42, 0.42, 0.42), (0, 0, 0.21), mat=sugar, bevel=0.04, segments=2)
    mk.displace_noise(cube, strength=0.012, scale=0.08, name="SugarGrain")
    return [cube], []


@prop("Coin", pivot="centre", material="Metal", collide=False, texture=256)
def coin():
    """The game's coin, old gold, a skull stamped in its middle: what Coin Flip throws."""
    gold = mk.noisy("Co_Gold", BRASS_B, BRASS_A, roughness=0.3, metallic=1.0)
    parts = [mk.cylinder("Disc", 0.45, 0.06, mat=gold, verts=28, bevel=0.012)]
    for z in (-0.034, 0.034):
        parts.append(mk.torus("Rim", 0.4, 0.018, (0, 0, z), mat=gold, major_segments=28, minor_segments=4))
        parts.append(mk.sphere("Skull", 0.13, (0, 0.02, z), scale=(1.0, 1.1, 0.25), mat=gold, segments=12, rings=6))
        parts.append(mk.box("Jaw", (0.12, 0.08, 0.03), (0, -0.12, z), mat=gold))
    return parts, []


@prop("Apple", pivot="bottom", material="SmoothPlastic", collide=False, texture=256)
def apple():
    """A deep red apple with a short stem and one leaf: what Apple Bite eats."""
    skin = mk.noisy("Ap_Skin", srgb(110, 14, 18), srgb(176, 30, 34), roughness=0.35, kind="plastic")
    stem = mk.flat("Ap_Stick", srgb(54, 40, 26), 0.8)
    leaf = mk.flat("Ap_Leaf", srgb(46, 70, 34), 0.6)
    profile = [(0.0, 0.03), (0.12, 0.0), (0.3, 0.06), (0.42, 0.2), (0.46, 0.38), (0.43, 0.56), (0.32, 0.7), (0.14, 0.74),
               (0.0, 0.66)]
    # (rounded: an apple is held up to the camera in Apple Bite)
    body = mk.lathe("Body", profile, mat=skin, segments=24)
    mk.subdivide(body, 1)
    parts = [body,
             mk.tube("Stem", (0, 0, 0.64), (0.04, 0.02, 0.9), 0.025, 0.018, mat=stem, verts=6),
             mk.sphere("Leaf", 0.14, (0.14, 0.04, 0.84), scale=(1.0, 0.45, 0.08), mat=leaf, segments=10, rings=4)]
    return parts, []


def _bitten(obj, bites, flesh):
    """Bites taken out of a mesh: each (centre, radius) sphere cut away (Blender's exact boolean), the cut faces in
    the flesh's material."""
    obj.data.materials.append(flesh)
    for k, (centre, radius) in enumerate(bites):
        cutter = mk.sphere("BiteCut%d" % k, radius, centre, mat=flesh, segments=20, rings=12)
        mod = obj.modifiers.new("Bite", "BOOLEAN")
        mod.operation = "DIFFERENCE"
        mod.object = cutter
        mod.solver = "EXACT"
        mod.material_mode = "TRANSFER"
        depsgraph = bpy.context.evaluated_depsgraph_get()
        mesh = bpy.data.meshes.new_from_object(obj.evaluated_get(depsgraph))
        obj.modifiers.remove(mod)
        old = obj.data
        obj.data = mesh
        bpy.data.meshes.remove(old)
        bpy.data.objects.remove(cutter)
    return obj


@prop("AppleBitten", pivot="bottom", material="SmoothPlastic", collide=False, texture=256)
def apple_bitten():
    """Apple Bite's apple once it is bitten: the same apple with a big bite out of one side (two overlapping
    tooth-arcs), the pale flesh showing. The bite is on Blender -Y: towards the body when held upright."""
    skin = mk.noisy("Ab_Skin", srgb(110, 14, 18), srgb(176, 30, 34), roughness=0.35, kind="plastic")
    flesh = mk.noisy("Ab_Flesh", srgb(226, 214, 168), srgb(244, 236, 200), roughness=0.55, kind="plastic")
    stem = mk.flat("Ab_Stick", srgb(54, 40, 26), 0.8)
    leaf = mk.flat("Ab_Leaf", srgb(46, 70, 34), 0.6)
    profile = [(0.0, 0.03), (0.12, 0.0), (0.3, 0.06), (0.42, 0.2), (0.46, 0.38), (0.43, 0.56), (0.32, 0.7), (0.14, 0.74),
               (0.0, 0.66)]
    body = mk.lathe("Body", profile, mat=skin, segments=32)
    _bitten(body, [((0.04, -0.5, 0.33), 0.22), ((-0.08, -0.5, 0.5), 0.2)], flesh)
    mk.smooth(body)
    parts = [body,
             mk.tube("Stem", (0, 0, 0.64), (0.04, 0.02, 0.9), 0.025, 0.018, mat=stem, verts=6),
             mk.sphere("Leaf", 0.14, (0.14, 0.04, 0.84), scale=(1.0, 0.45, 0.08), mat=leaf, segments=10, rings=4)]
    return parts, []


@prop("Chain", pivot="centre", material="Metal", collide=False, texture=256)
def chain():
    """A length of heavy iron chain, nine links: the Crimson Revenant drags them."""
    iron = mk.noisy("Ch_Iron", IRON_A, IRON_B, roughness=0.55, metallic=0.9)
    parts = []
    for k in range(9):
        z = (k - 4) * 0.42
        link = mk.torus("Link", 0.2, 0.055, (0, 0, z), rot=(90, 0, 90 * (k % 2)), mat=iron, major_segments=12,
                        minor_segments=5)
        link.scale = (1.0, 1.55, 1.0) if k % 2 == 0 else (1.55, 1.0, 1.0)
        parts.append(link)
    return parts, []


@prop("CrowCloak", pivot="centre", material="Fabric", collide=False, texture=256)
def crow_cloak():
    """A mantle of black crow feathers, layered from the collar down: the Crow Shroud form wears it."""
    feather = mk.noisy("Cc_Feather", srgb(10, 10, 14), srgb(36, 36, 44), roughness=0.55, kind="cloth")
    parts = []
    rows = 5
    for row in range(rows):
        radius = 0.9 + row * 0.32
        z = 1.2 - row * 0.5
        count = 14 + row * 4
        for k in range(count):
            a = 2 * math.pi * (k + 0.5 * (row % 2)) / count
            # Open at the front (-Y): the cloak hangs from the shoulders.
            if math.sin(a) < -0.8 and row > 0:
                continue
            out = Vector((math.cos(a), math.sin(a), 0.0))
            # A feather: a flat blade lying on the layer below, its tip down and out.
            top = out * radius + Vector((0, 0, z))
            tip = out * (radius + 0.3) + Vector((0, 0, z - 0.8))
            along = (tip - top).normalized()
            face = (out - along * out.dot(along)).normalized()
            side = along.cross(face)
            blade = mk.sphere("Feather", 1.0, mat=feather, segments=6, rings=4)
            blade.data.transform(Matrix.Translation((top + tip) / 2) @ Matrix((side, along, face)).transposed().to_4x4()
                                 @ Matrix.Diagonal((0.2, 0.48, 0.035, 1.0)))
            parts.append(blade)
    parts.append(mk.torus("Collar", 0.85, 0.12, (0, 0, 1.25), mat=feather, major_segments=20, minor_segments=5))
    return parts, []


@prop("MarionetteBar", pivot="centre", material="Wood", collide=False, texture=256)
def marionette_bar():
    """A marionette's wooden control: a cross of two bars with a hook at each end (the game hangs the Cut
    Marionette form's strings from them)."""
    wood = mk.noisy("Mb_Wood", srgb(150, 120, 86), srgb(196, 166, 126), roughness=0.6, kind="wood")
    iron = mk.flat("Mb_Iron", srgb(40, 40, 44), 0.5, metallic=0.8)
    parts = [pk.rounded("Long", (2.4, 0.16, 0.12), (0, 0, 0), wood, r=0.03),
             pk.rounded("Cross", (0.16, 1.5, 0.12), (0.55, 0, 0.1), wood, r=0.03)]
    for at in ((-1.15, 0, -0.08), (1.15, 0, -0.08), (0.55, -0.7, 0.02), (0.55, 0.7, 0.02), (0, 0, -0.08)):
        parts.append(mk.torus("Hook", 0.05, 0.012, (at[0], at[1], at[2] - 0.04), rot=(90, 0, 0), mat=iron,
                              major_segments=8, minor_segments=3))
    return parts, []


# Ace's verdict desk (2026-11-16, the user: "check how verdict styles work and make them way more high quality"): the
# pieces of the verdicts' insert shots (client Presentation/Verdicts), on the Core desk under a banker's lamp.
WALNUT_A, WALNUT_B = srgb(34, 20, 12), srgb(78, 48, 30)


@prop("SoundBlock", pivot="bottom", material="Wood", collide=False, texture=512, exact=True)
def sound_block():
    """A judge's sound block: a round of dark polished walnut, a moulded edge, a brass ring set into its top (Final
    Gavel strikes it)."""
    wood = mk.noisy("Sb_Walnut", WALNUT_A, WALNUT_B, roughness=0.3, kind="dark_wood")
    brass = mk.noisy("Sb_Brass", BRASS_B, BRASS_A, roughness=0.25, metallic=1.0)
    felt = mk.flat("Sb_Felt", srgb(22, 40, 28), 0.95)
    profile = [(0.0, 0.0), (0.7, 0.0), (0.74, 0.03), (0.74, 0.08), (0.7, 0.11), (0.72, 0.15), (0.72, 0.24),
               (0.68, 0.28), (0.6, 0.3), (0.0, 0.3)]
    return [mk.lathe("Body", profile, mat=wood, segments=40),
            mk.torus("Inlay", 0.44, 0.012, (0, 0, 0.3), mat=brass, major_segments=40, minor_segments=4),
            mk.torus("InlayIn", 0.3, 0.008, (0, 0, 0.3), mat=brass, major_segments=36, minor_segments=4),
            mk.cylinder("Felt", 0.69, 0.008, (0, 0, 0.004), mat=felt, verts=40)], []


@prop("RubberStamp", pivot="bottom", material="Wood", collide=False, texture=512, exact=True)
def rubber_stamp():
    """An office rubber stamp: a turned walnut handle with a knob, a brass collar, a black block with the red rubber
    die under it (Guilty Stamp; the word is the game's, printed where it lands)."""
    wood = mk.noisy("Rs_Walnut", WALNUT_A, WALNUT_B, roughness=0.35, kind="dark_wood")
    block = mk.noisy("Rs_Block", srgb(16, 16, 18), srgb(40, 38, 40), roughness=0.5)
    brass = mk.noisy("Rs_Brass", BRASS_B, BRASS_A, roughness=0.3, metallic=1.0)
    rubber = mk.flat("Rs_Rubber", srgb(120, 20, 26), 0.8, kind="rubber")
    handle = [(0.0, 0.2), (0.12, 0.2), (0.1, 0.28), (0.08, 0.42), (0.085, 0.56), (0.12, 0.66), (0.17, 0.78),
              (0.17, 0.86), (0.12, 0.93), (0.0, 0.95)]
    return [pk.rounded("Block", (0.9, 0.56, 0.12), (0, 0, 0.1), block, r=0.02),
            mk.box("Die", (0.84, 0.5, 0.04), (0, 0, 0.02), mat=rubber, bevel=0.006),
            mk.cylinder("Collar", 0.15, 0.05, (0, 0, 0.185), mat=brass, verts=24, bevel=0.008),
            mk.lathe("Handle", handle, mat=wood, segments=24)], []


@prop("InkPad", pivot="bottom", material="Metal", collide=False, texture=512, exact=True)
def ink_pad():
    """A tin ink pad open on the desk: the black tin, its lid stood up behind on the hinge, the red-soaked felt in
    it."""
    tin = mk.noisy("Ip_Tin", srgb(18, 18, 20), srgb(52, 52, 56), roughness=0.35, metallic=0.8)
    felt = mk.noisy("Ip_Felt", srgb(70, 8, 14), srgb(130, 18, 26), roughness=0.9, kind="cloth")
    rim = mk.noisy("Ip_Rim", srgb(70, 70, 74), srgb(120, 120, 126), roughness=0.3, metallic=1.0)
    gold = mk.flat("Ip_Print", srgb(176, 150, 96), 0.5)
    parts = [pk.rounded("Tray", (1.0, 0.66, 0.1), (0, 0, 0.05), tin, r=0.02),
             mk.box("Felt", (0.9, 0.56, 0.02), (0, 0, 0.1), mat=felt, bevel=0.004),
             pk.rounded("Lid", (1.02, 0.03, 0.68), (0, 0.36, 0.42), tin, r=0.012),
             mk.cylinder("Hinge", 0.018, 0.96, (0, 0.34, 0.1), rot=(0, 90, 0), mat=rim, verts=8)]
    # (the brand on the lid's inside, facing the camera at the front)
    parts.append(pk.text("Brand", "BUREAU", 0.08, (0, 0.343, 0.55), gold, rot=(90, 0, 0)))
    return parts, []


@prop("CaseFolder", pivot="bottom", material="Fabric", collide=False, texture=1024, exact=True)
def case_folder():
    """A case file lying open: a worn manila folder and its tab, the typed report on the right with a paper clip and a
    photo clipped to it, loose sheets in the left cover (the game prints the name on it)."""
    manila = mk.noisy("Cf_Manila", srgb(176, 148, 96), srgb(214, 188, 132), roughness=0.85, kind="paper")
    paper = mk.noisy("Cf_Paper", srgb(214, 208, 192), srgb(240, 236, 224), roughness=0.85, kind="paper")
    ink = mk.flat("Cf_Type", srgb(36, 34, 36), 0.6)
    photo = mk.noisy("Cf_Photo", srgb(40, 40, 44), srgb(120, 118, 114), roughness=0.3)
    steel = mk.flat("Cf_Clip", srgb(170, 172, 178), 0.25, metallic=1.0)
    red = mk.flat("Cf_Red", srgb(140, 22, 30), 0.7)
    parts = []
    # the two covers, the left one a little raised at its outer edge where it was opened
    for side, lift in ((-1, 0.04), (1, 0.0)):
        grid = []
        for j in range(5):
            y = -0.78 + 1.56 * j / 4
            row = []
            for i in range(5):
                u = i / 4
                row.append((side * (0.02 + 1.14 * u), y, 0.012 + lift * u * u))
            grid.append(row)
        parts.append(mk.sheet("Cover", grid, manila, apart=0.008))
    parts.append(mk.box("Tab", (0.5, 0.18, 0.008), (-0.7, 0.84, 0.012), mat=manila, bevel=0.003))
    parts.append(mk.box("Spine", (0.04, 1.56, 0.014), (0, 0, 0.007), mat=manila))
    # the report: two sheets a little askew, typed lines, a red band at its head
    for k, (dx, rot) in enumerate(((0.58, -2.0), (0.6, 1.0))):
        parts.append(mk.box("Sheet", (1.0, 1.36, 0.004), (dx, -0.02, 0.02 + 0.004 * k), rot=(0, 0, rot), mat=paper))
    rng = __import__("random").Random(1116)
    for r in range(13):
        y = 0.42 - r * 0.075
        x = 0.16
        while x < 0.98:
            w = rng.uniform(0.05, 0.16)
            if x + w > 0.98:
                break
            parts.append(mk.box("Word", (w, 0.018, 0.003), (x + w / 2, y, 0.031), mat=ink))
            x += w + rng.uniform(0.025, 0.05)
    parts.append(mk.box("Band", (0.44, 0.07, 0.003), (0.36, 0.58, 0.031), mat=red))
    # the photo clipped at the top right, a paper clip over its top edge
    parts.append(mk.box("Photo", (0.32, 0.4, 0.006), (0.86, 0.44, 0.036), rot=(0, 0, 6), mat=photo, bevel=0.002))
    parts.append(mk.box("PhotoBorder", (0.36, 0.44, 0.003), (0.86, 0.44, 0.0325), rot=(0, 0, 6), mat=paper))
    for x in (0.8, 0.83, 0.86):
        parts.append(mk.tube("Clip", (x, 0.56, 0.042), (x, 0.72, 0.042), 0.006, mat=steel, verts=4))
    # loose sheets in the left cover
    for k in range(3):
        parts.append(mk.box("Loose", (0.96, 1.3, 0.004), (-0.6 + 0.02 * k, -0.05 + 0.015 * k, 0.03 + 0.005 * k),
                            rot=(0, 0, -3 + 2.5 * k), mat=paper))
    return parts, []


@prop("ChessBoard", pivot="bottom", material="Wood", collide=False, texture=1024, exact=True)
def chess_board():
    """A tournament chess board: a walnut frame round 64 inlaid squares of ebony and maple (Endgame's board)."""
    frame = mk.noisy("Cb_Walnut", WALNUT_A, WALNUT_B, roughness=0.3, kind="dark_wood")
    dark = mk.noisy("Cb_Ebony", srgb(26, 18, 14), srgb(52, 36, 26), roughness=0.3, kind="dark_wood")
    light = mk.noisy("Cb_Maple", srgb(196, 166, 120), srgb(230, 206, 160), roughness=0.3, kind="wood")
    parts = [pk.rounded("Frame", (3.4, 3.4, 0.16), (0, 0, 0.08), frame, r=0.04)]
    sq = 0.38
    for i in range(8):
        for j in range(8):
            parts.append(mk.box("Square", (sq, sq, 0.01), ((i - 3.5) * sq, (j - 3.5) * sq, 0.165),
                                mat=dark if (i + j) % 2 == 0 else light))
    return parts, []


@prop("ChessQueen", pivot="bottom", material="SmoothPlastic", collide=False, texture=256)
def chess_queen():
    """An ivory chess queen, a crown of points on her head: the piece that gives mate in Endgame."""
    ivory = mk.noisy("Cq_Ivory", IVORY_A, IVORY_B, roughness=0.25, kind="plastic")
    felt = mk.flat("Cq_Felt", srgb(30, 50, 34), 0.95)
    profile = [(0.0, 0.0), (0.4, 0.0), (0.42, 0.06), (0.38, 0.13), (0.28, 0.19), (0.3, 0.25), (0.2, 0.33), (0.14, 0.72),
               (0.12, 1.0), (0.24, 1.05), (0.25, 1.1), (0.14, 1.14), (0.2, 1.36), (0.24, 1.44), (0.0, 1.42)]
    parts = [mk.lathe("Body", profile, mat=ivory, segments=20),
             mk.cylinder("Felt", 0.39, 0.01, (0, 0, 0.004), mat=felt, verts=20),
             mk.sphere("Top", 0.07, (0, 0, 1.5), mat=ivory, segments=10, rings=6)]
    for k in range(8):
        a = 2 * math.pi * k / 8
        parts.append(mk.sphere("Point", 0.035, (0.22 * math.cos(a), 0.22 * math.sin(a), 1.47), mat=ivory, segments=8,
                               rings=5))
    return parts, []
