"""The things the shop's styles, forms and gestures hold or show (Core set; see props.py): the quill and the
knife of Diavolo's writing styles, Ace's gavel, chess king and sugar cube, the coin and the apple of two
gestures, and what three Deathsinger forms wear (a chain, a cloak of crow feathers, a marionette's
control bar). Each is small and plain enough to be held in a hand or hung on a ghost, and is seen up close
in the shop's "Your look"."""

import math

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
    """A sugar cube, its corners a little crumbled: Ace's Sugar Cubes (L's tower of them)."""
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
    parts = [mk.lathe("Body", profile, mat=skin, segments=20),
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
