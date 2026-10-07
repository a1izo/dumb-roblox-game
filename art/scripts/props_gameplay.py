"""Gameplay objects (see props.py). These dress existing gameplay parts, which keep their tags,
prompts and collisions: the part turns invisible and the mesh sits exactly where it was."""

import math
import random

import bmesh
import bpy
from mathutils import Vector

import modelkit as mk
from common import srgb
from props import BRASS_A, BRASS_B, PAPER_A, PAPER_B, RED, prop
from props_world import dark_wood


@prop("Station", pivot="bottom", material="Metal", collide=False, texture=1024)
def station():
    """A case-file console: steel desk, CRT housing around the game's screen part, keyboard."""
    steel = mk.noisy("Stat_Steel", srgb(44, 44, 50), srgb(70, 70, 78), scale=16, detail=10, roughness=0.45,
                     metallic=0.6)
    dark = mk.noisy("Stat_Dark", srgb(16, 16, 18), srgb(30, 30, 34), scale=20, roughness=0.5)
    beige = mk.noisy("Stat_Beige", srgb(170, 162, 146), srgb(200, 192, 176), scale=18, roughness=0.6)
    label = mk.noisy("Stat_Label", PAPER_B, PAPER_A, scale=30, roughness=0.9)
    parts = [
        mk.box("Top", (5.2, 2.6, 0.18), (0, 0, 2.91), mat=steel, bevel=0.04),
        mk.box("Body", (4.8, 2.3, 2.8), (0, 0.05, 1.45), mat=steel, bevel=0.05),
        mk.box("Kick", (4.6, 2.1, 0.25), (0, 0.05, 0.12), mat=dark),
        # CRT housing behind and around the screen (the screen itself is the game's part).
        mk.box("Shell", (4.9, 1.0, 3.1), (0, 1.45, 5.4), mat=beige, bevel=0.15),
        mk.box("BezelTop", (4.9, 0.2, 0.25), (0, 0.72, 6.83), mat=beige, bevel=0.05),
        mk.box("BezelBottom", (4.9, 0.2, 0.3), (0, 0.72, 3.95), mat=beige, bevel=0.05),
        mk.box("BezelLeft", (0.25, 0.2, 2.6), (-2.33, 0.72, 5.4), mat=beige, bevel=0.05),
        mk.box("BezelRight", (0.25, 0.2, 2.6), (2.33, 0.72, 5.4), mat=beige, bevel=0.05),
        mk.box("Stand", (0.8, 0.8, 0.9), (0, 1.2, 3.45), mat=dark, bevel=0.05),
        mk.box("Keyboard", (1.6, 0.5, 0.1), (0.2, -0.6, 3.05), rot=(4, 0, 0), mat=beige, bevel=0.03),
        mk.box("Label", (1.2, 0.04, 0.4), (-1.4, -1.12, 2.2), mat=label),
        mk.tube("Cable", (1.9, 1.2, 2.95), (2.2, 1.3, 0.2), 0.05, mat=dark, verts=8),
    ]
    for i in range(6):
        parts.append(mk.box("Vent", (0.5, 0.04, 0.06), (1.6, -1.12, 1.0 + i * 0.25), mat=dark))
    glow = [mk.box("Power", (0.12, 0.04, 0.08), (2.0, 0.6, 4.05), mat=mk.emissive("Stat_Led", srgb(80, 255, 140), 5))]
    return parts, glow


@prop("EvidenceBoard", pivot="centre", material="Wood", collide=False, texture=1024)
def evidence_board():
    """A detective's cork board: frame, cork, a big pinned sheet in the middle (the game writes
    the log onto it), photos around it and red string between the pins."""
    frame = dark_wood("Board_Frame")
    cork = mk.noisy("Board_Cork", srgb(120, 84, 50), srgb(160, 120, 76), scale=40, detail=10, roughness=0.95)
    paper = mk.noisy("Board_Paper", PAPER_B, PAPER_A, scale=30, roughness=0.9)
    photo = mk.noisy("Board_Photo", srgb(60, 60, 60), srgb(150, 150, 146), scale=8, detail=6, roughness=0.6)
    border = mk.flat("Board_PhotoBorder", srgb(236, 232, 222), 0.8)
    pin = mk.flat("Board_Pin", RED, 0.3)
    string = mk.flat("Board_String", srgb(170, 20, 30), 0.8)
    w, h = 12.0, 7.0
    parts = [
        mk.box("Cork", (w, 0.2, h), (0, 0.1, 0), mat=cork),
        mk.box("FrameTop", (w + 0.6, 0.45, 0.3), (0, 0, h / 2 + 0.15), mat=frame, bevel=0.05),
        mk.box("FrameBottom", (w + 0.6, 0.45, 0.3), (0, 0, -h / 2 - 0.15), mat=frame, bevel=0.05),
        mk.box("FrameLeft", (0.3, 0.45, h), (-w / 2 - 0.15, 0, 0), mat=frame, bevel=0.05),
        mk.box("FrameRight", (0.3, 0.45, h), (w / 2 + 0.15, 0, 0), mat=frame, bevel=0.05),
        mk.box("Sheet", (w * 0.66, 0.03, h * 0.74), (0, -0.02, -0.1), mat=paper),
    ]
    rng = random.Random(21)
    photo_spots = [(-5.0, 2.4), (-5.1, 0.3), (-4.9, -2.2), (5.0, 2.3), (5.1, 0.1), (4.9, -2.3), (-2.2, 3.05),
                   (2.4, 3.05)]
    pins = []
    for x, z in photo_spots:
        tilt = rng.uniform(-10, 10)
        parts.append(mk.box("PhotoBorder", (1.3, 0.03, 1.5), (x, -0.03, z), rot=(0, tilt, 0), mat=border))
        parts.append(mk.box("Photo", (1.1, 0.03, 1.1), (x, -0.05, z + 0.12), rot=(0, tilt, 0), mat=photo))
        pins.append(Vector((x, -0.12, z + 0.6)))
        parts.append(mk.sphere("Pin", 0.1, (x, -0.12, z + 0.6), mat=pin, segments=10, rings=6))
    # Red string zig-zagging between the pins.
    order = [0, 6, 3, 4, 1, 5, 2, 7, 0]
    for a, b in zip(order, order[1:]):
        parts.append(mk.tube("String", pins[a] + Vector((0, -0.02, 0)), pins[b] + Vector((0, -0.02, 0)), 0.025,
                             mat=string, verts=6))
    return parts, []


@prop("TipBox", pivot="bottom", material="Metal", collide=False, texture=512)
def tip_box():
    """A red post box on a short post, flat-fronted for the TIP BOX plate."""
    paint = mk.noisy("Tip_Paint", srgb(140, 16, 22), srgb(180, 34, 38), scale=14, detail=10, roughness=0.45,
                     metallic=0.2)
    dark = mk.noisy("Tip_Dark", srgb(20, 20, 22), srgb(40, 40, 44), scale=14, roughness=0.5)
    brass = mk.noisy("Tip_Brass", BRASS_B, BRASS_A, scale=14, roughness=0.3, metallic=1.0)
    parts = [
        mk.box("Body", (2.6, 2.2, 3.0), (0, 0, 2.5), mat=paint, bevel=0.12),
        mk.cylinder("Roof", 1.3, 2.4, (0, 0, 4.0), rot=(90, 0, 0), mat=paint, verts=24, bevel=0.05),
        mk.box("RoofBase", (2.8, 2.4, 0.15), (0, 0, 4.0), mat=paint, bevel=0.04),
        mk.box("Slot", (1.6, 0.1, 0.18), (0, -1.12, 3.25), mat=dark),
        mk.box("SlotLip", (1.8, 0.2, 0.08), (0, -1.15, 3.4), mat=paint, bevel=0.02),
        mk.box("Post", (1.0, 1.0, 1.0), (0, 0, 0.5), mat=dark, bevel=0.05),
        mk.box("Door", (1.9, 0.06, 1.6), (0, -1.11, 1.9), mat=paint, bevel=0.03),
        mk.cylinder("Lock", 0.1, 0.12, (0.7, -1.16, 1.9), rot=(90, 0, 0), mat=brass, verts=12),
    ]
    return parts, []


def _paper_sheet(name, mat, curl=0.08):
    """A sheet of paper with slightly curled corners (1.1 x 1.5 studs, like the game's sheets)."""
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=6, y_segments=8, size=0.5)
    for v in bm.verts:
        v.co.x *= 1.1
        v.co.y *= 1.5
        v.co.z = curl * ((abs(v.co.x) / 0.55) ** 2 + (abs(v.co.y) / 0.75) ** 3) * 0.5
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    mesh.materials.append(mat)
    mk._link(obj)
    solid = obj.modifiers.new("Solidify", "SOLIDIFY")
    solid.thickness = 0.02
    return obj


@prop("PaperSheet", pivot="bottom", material="SmoothPlastic", collide=False, texture=256)
def paper_sheet():
    paper = mk.banded("Paper_Lined", srgb(214, 206, 186), srgb(236, 230, 214), frequency=24, axis="Y")
    return [_paper_sheet("Sheet", paper)], []


@prop("PaperNote", pivot="bottom", material="SmoothPlastic", collide=False, texture=256)
def paper_note():
    """A note with a few lines of ink on it."""
    paper = mk.noisy("Note_Paper", srgb(210, 200, 176), srgb(232, 224, 204), scale=30, roughness=0.9)
    ink = mk.flat("Note_Ink", srgb(20, 18, 24), 0.4)
    parts = [_paper_sheet("Note", paper, curl=0.12)]
    for i in range(5):
        width = 0.45 if i == 4 else 0.7
        parts.append(mk.box("Line", (width, 0.035, 0.008), (-0.05 - (0.7 - width) / 2, 0.45 - i * 0.2, 0.05),
                            mat=ink))
    return parts, []


def _hood_shell(name, mat):
    """A cowl: the back and sides of a sphere, open at the face, falling onto the shoulders."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=28, v_segments=16, radius=1.0)
    faces = [f for f in bm.faces if f.calc_center_median().y < -0.15 and -0.75 < f.calc_center_median().z < 0.7]
    bmesh.ops.delete(bm, geom=faces, context="FACES")
    for v in bm.verts:
        if v.co.z < -0.2:
            spread = -0.2 - v.co.z
            v.co.x *= 1.0 + spread * 0.9
            v.co.y *= 1.0 + spread * 0.5
            v.co.z -= spread * 1.1
        if v.co.z > 0.8:
            v.co.y += (v.co.z - 0.8) * 0.8
            v.co.z += (v.co.z - 0.8) * 0.5
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    mesh.materials.append(mat)
    mk._link(obj)
    mk.smooth(obj)
    solid = obj.modifiers.new("Solidify", "SOLIDIFY")
    solid.thickness = 0.08
    return obj


@prop("Hood", pivot="centre", material="Fabric", collide=False, texture=512)
def hood():
    """The hood worn over the head (the game scales it to each head)."""
    cloth = mk.noisy("Hood_Cloth", srgb(22, 20, 26), srgb(44, 40, 50), scale=10, detail=12, roughness=0.95)
    shell = _hood_shell("Shell", cloth)
    shell.scale = (0.78, 0.8, 0.72)
    return [shell], []


@prop("HoodPickup", pivot="bottom", material="Fabric", collide=False, texture=512)
def hood_pickup():
    """A hood lying on the ground, ready to be picked up."""
    cloth = mk.noisy("Hood_Cloth", srgb(22, 20, 26), srgb(44, 40, 50), scale=10, detail=12, roughness=0.95)
    shell = _hood_shell("Shell", cloth)
    shell.scale = (0.8, 0.8, 0.45)
    shell.rotation_euler = (math.radians(-70), 0, math.radians(20))
    shell.location = (0, 0, 0.45)
    drape = mk.box("Drape", (1.4, 1.2, 0.12), (0.1, 0.4, 0.06), rot=(0, 0, 12), mat=cloth, bevel=0.05)
    return [shell, drape], []
