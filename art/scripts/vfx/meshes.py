"""The VFX kit's meshes and its props file, DeathsGambitModels_Fx.fbx (set "Fx"): plain white shapes with their own
UVs laid for the effect textures (a ring's u runs round it and v across it, a tube's v up it...), every face drawn on
both sides, plus a carrier quad for each VFX texture so importing the file uploads them, the calibration cubes and
the version marker. Not baked like the other props (the bake would lay new UVs): the game puts a texture on them.

    blender -b --factory-startup --python art/scripts/vfx/meshes.py [-- --preview]

Sizes (Blender units = studs, Z up, so Roblox's Y): radius 1 round the Z axis, from z 0 up where they have a height.
Presentation/Vfx/Shape.luau knows each one's size and pivot.

UVs follow the kit's one rule for laid-along textures (the lab of 2026-10-24: a Beam lays an image's rows along its
length): the image's rows run ALONG the shape (its top row where the shape starts), its columns ACROSS it. Blender's
v counts up from the image's bottom, so a point `along` the shape (0 at its start) gets v = 1 - along.
"""

import math
import os
import random
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import common  # noqa: E402
from maps import export as maps_export  # noqa: E402

SET = "Fx"
FBX = os.path.join(common.EXPORT, "DeathsGambitModels_Fx.fbx")

# Every texture the kit carries (art/scripts/vfx/textures.py writes them), in the order of the carrier quads.
TEXTURES = [
    "VfxFlame", "VfxCandleFlame", "VfxGlow", "VfxFlare", "VfxEmber", "VfxStreak", "VfxSpike", "VfxBurst", "VfxRing",
    "VfxRingBand", "VfxColumn", "VfxSlash", "VfxSlashBand", "VfxWisp", "VfxDust", "VfxSmoke", "VfxCrack", "VfxCircle",
    "VfxPage", "VfxFeather", "VfxMoth", "VfxChunk",
]


def _white():
    mat = bpy.data.materials.get("Vfx_White") or bpy.data.materials.new("Vfx_White")
    mat.use_nodes = True
    mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (1, 1, 1, 1)
    return mat


def _mesh(name, verts, faces, uvs, double=True):
    """A mesh from vertices, faces (index lists) and a UV per face corner (lists matching the faces); with `double`
    each face is drawn again turned the other way, with the same UVs."""
    old = bpy.data.objects.get(name)
    if old:
        bpy.data.objects.remove(old, do_unlink=True)
    all_faces, all_uvs = list(faces), list(uvs)
    if double:
        for f, u in zip(faces, uvs):
            all_faces.append(list(reversed(f)))
            all_uvs.append(list(reversed(u)))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], all_faces)
    layer = mesh.uv_layers.new(name="UVMap")
    k = 0
    for poly, corner_uvs in zip(mesh.polygons, all_uvs):
        for li, uv in zip(poly.loop_indices, corner_uvs):
            layer.data[li].uv = uv
            k += 1
    mesh.materials.append(_white())
    for poly in mesh.polygons:
        poly.use_smooth = True
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    common.collection("VfxMeshes").objects.link(obj)
    obj["dg_vfx"] = True
    return obj


def _grid(name, rows, cols, point, uv, wrap=True, double=True):
    """A surface from a (rows+1) x (cols+1) lattice: point(i, j) and uv(i, j) for row i, column j; with `wrap` the
    last column joins the first (its own UVs kept, so a texture wraps round whole)."""
    verts, index = [], {}
    for i in range(rows + 1):
        for j in range(cols + 1):
            index[(i, j)] = len(verts)
            verts.append(point(i, j))
    faces, uvs = [], []
    for i in range(rows):
        for j in range(cols):
            a, b, c, d = (i, j), (i, j + 1), (i + 1, j + 1), (i + 1, j)
            faces.append([index[a], index[b], index[c], index[d]])
            uvs.append([uv(*a), uv(*b), uv(*c), uv(*d)])
    return _mesh(name, verts, faces, uvs, double)


def ring():
    """VfxRing: a flat ring, radius 1 out, 0.55 in, lying in the ground's plane; along it round (the texture twice),
    across it from its outer edge (a shockwave's front) to its inner."""
    n = 96
    return _grid("VfxRing", 1, n,
                 lambda i, j: (math.cos(2 * math.pi * j / n) * (1.0 - 0.45 * i), math.sin(2 * math.pi * j / n) * (1.0 - 0.45 * i), 0.0),
                 lambda i, j: (float(i), 1.0 - 2.0 * j / n))


def dome():
    """VfxDome: a half sphere of radius 1 over z 0; along it round (twice), across it from its rim to its top."""
    n, m = 64, 16
    def point(i, j):
        a = 2 * math.pi * j / n
        e = math.pi / 2 * min(i / m, 0.985)
        return (math.cos(a) * math.cos(e), math.sin(a) * math.cos(e), math.sin(e))
    return _grid("VfxDome", m, n, point, lambda i, j: (i / m, 1.0 - 2.0 * j / n))


def tube():
    """VfxTube: an open tube of radius 1 from z 0 to 2; along it up (its foot the texture's top row), across it round
    (twice)."""
    n, m = 48, 8
    return _grid("VfxTube", m, n,
                 lambda i, j: (math.cos(2 * math.pi * j / n), math.sin(2 * math.pi * j / n), 2.0 * i / m),
                 lambda i, j: (2.0 * j / n, 1.0 - i / m))


def cone():
    """VfxCone: an open cone, radius 1 at z 0 narrowing to 0.06 at z 2 (a burst flung up, a funnel turned over); u
    round it (twice), v 0 at its wide end to 1 at its point."""
    n, m = 48, 10
    def point(i, j):
        r = 1.0 - 0.94 * (i / m) ** 0.85
        return (math.cos(2 * math.pi * j / n) * r, math.sin(2 * math.pi * j / n) * r, 2.0 * i / m)
    return _grid("VfxCone", m, n, point, lambda i, j: (2.0 * j / n, 1.0 - i / m))


def swirl():
    """VfxSwirl: a ribbon wound one and a half times up round the Z axis, radius 1 at its foot to 0.65 at z 2, its
    band 0.5 tall; along it (the texture three times, from its foot), across its band."""
    n = 120
    turns = 1.5
    def point(i, j):
        s = j / n
        a = 2 * math.pi * turns * s
        r = 1.0 - 0.35 * s
        z = 2.0 * s * 0.8 + (i - 0.5) * 0.5 * (0.6 + 0.4 * math.sin(math.pi * s))
        return (math.cos(a) * r, math.sin(a) * r, max(z, 0.0) + 0.25)
    return _grid("VfxSwirl", 1, n, point, lambda i, j: (float(i), 1.0 - 3.0 * j / n), wrap=False)


def crescent():
    """VfxCrescent: a flat crescent blade in the ground's plane, a 200-degree arc of radius 1 round its middle, wide
    in the middle and sharp at both ends; along it from its tail to its head, across it from its outer (cutting) edge
    to its inner."""
    n = 64
    span = math.radians(200)
    def point(i, j):
        s = j / n
        a = -span / 2 + span * s
        width = 0.34 * math.sin(math.pi * s) ** 0.8
        r = 1.0 - width * i
        return (math.cos(a) * r, math.sin(a) * r, 0.0)
    return _grid("VfxCrescent", 1, n, point, lambda i, j: (float(i), 1.0 - j / n), wrap=False)


def sphere():
    """VfxSphere: a sphere of radius 1 round its middle; u round it (twice), v pole to pole."""
    n, m = 48, 24
    def point(i, j):
        a = 2 * math.pi * j / n
        e = -math.pi / 2 + math.pi * min(max(i / m, 0.004), 0.996)
        return (math.cos(a) * math.cos(e), math.sin(a) * math.cos(e), math.sin(e))
    return _grid("VfxSphere", m, n, point, lambda i, j: (2.0 * j / n, 1.0 - i / m), double=False)


def spike_ball(seed=3):
    """VfxSpikes: fourteen sharp spikes thrown out from a point in every direction, 0.6 to 1 long; each spike's v runs
    0 at its root to 1 at its point, u round it."""
    rng = random.Random(seed)
    verts, faces, uvs = [], [], []
    for k in range(14):
        z = rng.uniform(-0.6, 1.0)
        a = rng.uniform(0, 2 * math.pi)
        d = (math.cos(a) * math.sqrt(1 - z * z), math.sin(a) * math.sqrt(1 - z * z), z)
        length = rng.uniform(0.6, 1.0)
        # two vectors across the spike
        up = (0, 0, 1) if abs(d[2]) < 0.9 else (1, 0, 0)
        ax = (d[1] * up[2] - d[2] * up[1], d[2] * up[0] - d[0] * up[2], d[0] * up[1] - d[1] * up[0])
        n = math.sqrt(sum(c * c for c in ax))
        ax = tuple(c / n for c in ax)
        ay = (d[1] * ax[2] - d[2] * ax[1], d[2] * ax[0] - d[0] * ax[2], d[0] * ax[1] - d[1] * ax[0])
        base = len(verts)
        sides = 5
        r0 = 0.07
        for s in range(sides):
            t = 2 * math.pi * s / sides
            verts.append(tuple(math.cos(t) * r0 * ax[c] + math.sin(t) * r0 * ay[c] for c in range(3)))
        tip = len(verts)
        verts.append(tuple(d[c] * length for c in range(3)))
        for s in range(sides):
            faces.append([base + s, base + (s + 1) % sides, tip])
            uvs.append([(s / sides, 0.0), ((s + 1) / sides, 0.0), ((s + 0.5) / sides, 1.0)])
    return _mesh("VfxSpikes", verts, faces, uvs, double=False)


def shard(seed=5):
    """VfxShard: a long six-sided crystal pointed at both ends, 1 long (z -0.5 .. 0.5), for glass and stone thrown
    off; v along it."""
    rng = random.Random(seed)
    sides = 6
    verts = [(0, 0, -0.5)]
    for s in range(sides):
        t = 2 * math.pi * s / sides
        r = 0.16 * rng.uniform(0.8, 1.15)
        verts.append((math.cos(t) * r, math.sin(t) * r * 0.7, rng.uniform(-0.12, 0.08)))
    verts.append((0, 0, 0.5))
    faces, uvs = [], []
    for s in range(sides):
        a, b = 1 + s, 1 + (s + 1) % sides
        faces.append([0, b, a])
        uvs.append([(s / sides, 0.0), ((s + 1) / sides, 0.45), (s / sides, 0.45)])
        faces.append([a, b, sides + 1])
        uvs.append([(s / sides, 0.45), ((s + 1) / sides, 0.45), ((s + 0.5) / sides, 1.0)])
    return _mesh("VfxShard", verts, faces, uvs, double=False)


def rock(seed=8):
    """VfxRock: a broken lump of stone, about 1 across, flat-faced (debris thrown up by a landing)."""
    rng = random.Random(seed)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.5)
    obj = bpy.context.active_object
    for v in obj.data.vertices:
        v.co *= rng.uniform(0.75, 1.15)
        v.co.z *= 0.75
    verts = [tuple(v.co) for v in obj.data.vertices]
    faces = [list(p.vertices) for p in obj.data.polygons]
    bpy.data.objects.remove(obj, do_unlink=True)
    uvs = [[((verts[i][0] + 0.6) / 1.2, (verts[i][1] + 0.6) / 1.2) for i in f] for f in faces]
    made = _mesh("VfxRock", verts, faces, uvs, double=False)
    for poly in made.data.polygons:
        poly.use_smooth = False
    return made


def page():
    """VfxPage: a sheet of paper 1 wide and 1.4 tall, bowed a little, standing in the XZ plane; u across, v down (the
    Manual's ruled page texture reads the right way up)."""
    cols, rows = 6, 8
    return _grid("VfxPage", rows, cols,
                 lambda i, j: (-0.5 + j / cols, 0.06 * math.sin(math.pi * j / cols) - 0.03, 1.4 * (1 - i / rows)),
                 lambda i, j: (j / cols, 1.0 - i / rows), wrap=False)


BUILDERS = [ring, dome, tube, cone, swirl, crescent, sphere, spike_ball, shard, rock, page]


def carriers():
    """A small quad per VFX texture, its material showing the texture, so the import uploads each."""
    made = []
    for i, name in enumerate(TEXTURES):
        path = os.path.join(common.TEXTURES, name + ".png")
        if not os.path.exists(path):
            print("[vfx meshes] missing texture", name)
            continue
        obj_name = "Tex_" + name
        old = bpy.data.objects.get(obj_name)
        if old:
            bpy.data.objects.remove(old, do_unlink=True)
        image = bpy.data.images.load(path, check_existing=True)
        mat = bpy.data.materials.get(obj_name) or bpy.data.materials.new(obj_name)
        mat.use_nodes = True
        nodes, links = mat.node_tree.nodes, mat.node_tree.links
        bsdf = nodes["Principled BSDF"]
        tex = nodes.get("Image") or nodes.new("ShaderNodeTexImage")
        tex.name = "Image"
        tex.image = image
        links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
        mesh = bpy.data.meshes.new(obj_name)
        mesh.from_pydata([(-1, 0, -1), (1, 0, -1), (1, 0, 1), (-1, 0, 1)], [], [(0, 1, 2, 3)])
        uv = mesh.uv_layers.new(name="UVMap")
        for loop, co in zip(uv.data, ((0, 0), (1, 0), (1, 1), (0, 1))):
            loop.uv = co
        mesh.materials.append(mat)
        obj = bpy.data.objects.new(obj_name, mesh)
        common.collection("VfxTextures").objects.link(obj)
        obj.location = (40 + (i % 6) * 3, 0, (i // 6) * 3)
        made.append(obj)
    return made


def build_and_export():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    common.ensure_dirs()
    objects = []
    for k, build in enumerate(BUILDERS):
        obj = build()
        obj.location = (k * 3.0, 20.0, 0.0)  # (apart, for previews; the game uses each mesh alone)
        objects.append(obj)
        print("[vfx meshes]", obj.name, len(obj.data.polygons), "faces")
    objects += carriers()
    objects += maps_export.calibration_cubes(common.collection("CalibrationFx"), "Calib_Props" + SET, "Models" + SET)
    bpy.context.view_layer.update()
    for obj in bpy.data.objects:
        obj.select_set(obj in objects)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.export_scene.fbx(
        filepath=FBX,
        use_selection=True,
        object_types={"MESH"},
        apply_unit_scale=True,
        apply_scale_options="FBX_SCALE_ALL",
        axis_forward="Z",
        axis_up="Y",
        bake_space_transform=True,
        use_mesh_modifiers=True,
        mesh_smooth_type="FACE",
        path_mode="COPY",
        embed_textures=True,
        add_leaf_bones=False,
    )
    maps_export.write_versions()
    print("[vfx meshes] export", FBX)
    return FBX


if __name__ == "__main__":
    build_and_export()
