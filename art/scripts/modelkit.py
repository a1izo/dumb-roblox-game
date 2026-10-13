"""A small modelling kit for Death's Gambit props: primitives with bevels, materials made from
photographed scans, merging into one mesh per prop, UV unwrapping and baking each prop's colour,
relief, roughness and metalness into one set of textures (Roblox shows one set per MeshPart).

Units: 1 Blender unit = 1 stud. Props stand on z = 0 and face -Y (the rig's facing), so the
FBX export (axis_forward="Z", axis_up="Y") turns them to face -Z in Roblox.
"""

import math
import os
import time

import bmesh
import bpy
import numpy as np
from mathutils import Euler, Matrix, Vector

import common
import lookbook
from maps import scanlib


# Objects ------------------------------------------------------------------------------------------


def _link(obj, coll_name="Build"):
    common.collection(coll_name).objects.link(obj)
    return obj


def _obj_from_bm(name, bm, mat=None):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    if mat is not None:
        mesh.materials.append(mat)
    return _link(obj)


def box(name, size, loc=(0, 0, 0), rot=(0, 0, 0), mat=None, bevel=0.0, segments=2):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    obj = _obj_from_bm(name, bm, mat)
    obj.location = loc
    obj.rotation_euler = Euler([math.radians(a) for a in rot])
    if bevel > 0:
        add_bevel(obj, bevel, segments)
    return obj


def cylinder(name, radius, depth, loc=(0, 0, 0), rot=(0, 0, 0), mat=None, verts=24, bevel=0.0, radius2=None):
    bm = bmesh.new()
    bmesh.ops.create_cone(
        bm,
        cap_ends=True,
        cap_tris=False,
        segments=verts,
        radius1=radius,
        radius2=radius if radius2 is None else radius2,
        depth=depth,
    )
    obj = _obj_from_bm(name, bm, mat)
    obj.location = loc
    obj.rotation_euler = Euler([math.radians(a) for a in rot])
    if bevel > 0:
        add_bevel(obj, bevel, 2)
    smooth(obj)
    return obj


def sphere(name, radius, loc=(0, 0, 0), scale=(1, 1, 1), mat=None, segments=24, rings=16):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segments, v_segments=rings, radius=radius)
    obj = _obj_from_bm(name, bm, mat)
    obj.location = loc
    obj.scale = scale
    smooth(obj)
    return obj


def torus(name, major, minor, loc=(0, 0, 0), rot=(0, 0, 0), mat=None, major_segments=32, minor_segments=12):
    bm = bmesh.new()
    for i in range(major_segments):
        a = 2 * math.pi * i / major_segments
        center = Vector((math.cos(a) * major, math.sin(a) * major, 0))
        ring = []
        for j in range(minor_segments):
            b = 2 * math.pi * j / minor_segments
            direction = Vector((math.cos(a) * math.cos(b), math.sin(a) * math.cos(b), math.sin(b)))
            ring.append(bm.verts.new(center + direction * minor))
        bm.verts.index_update()
    bm.verts.ensure_lookup_table()
    for i in range(major_segments):
        for j in range(minor_segments):
            a = i * minor_segments + j
            b = i * minor_segments + (j + 1) % minor_segments
            c = ((i + 1) % major_segments) * minor_segments + (j + 1) % minor_segments
            d = ((i + 1) % major_segments) * minor_segments + j
            bm.faces.new((bm.verts[a], bm.verts[b], bm.verts[c], bm.verts[d]))
    obj = _obj_from_bm(name, bm, mat)
    obj.location = loc
    obj.rotation_euler = Euler([math.radians(v) for v in rot])
    smooth(obj)
    return obj


def lathe(name, profile, loc=(0, 0, 0), mat=None, segments=32):
    """Spins a profile [(radius, z), ...] around Z (for vases, bulbs, posts, bottles)."""
    bm = bmesh.new()
    rings = []
    for r, z in profile:
        ring = []
        for i in range(segments):
            a = 2 * math.pi * i / segments
            ring.append(bm.verts.new((math.cos(a) * r, math.sin(a) * r, z)))
        rings.append(ring)
    for k in range(len(rings) - 1):
        for i in range(segments):
            j = (i + 1) % segments
            bm.faces.new((rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]))
    # caps
    if profile[0][0] > 0:
        bm.faces.new(list(reversed(rings[0])))
    if profile[-1][0] > 0:
        bm.faces.new(rings[-1])
    obj = _obj_from_bm(name, bm, mat)
    obj.location = loc
    smooth(obj)
    return obj


def extrude_shape(name, points, depth, loc=(0, 0, 0), rot=(0, 0, 0), mat=None, bevel=0.0):
    """A flat polygon [(x, y), ...] in the XY plane, extruded `depth` along Z (centred)."""
    bm = bmesh.new()
    verts = [bm.verts.new((x, y, -depth / 2)) for x, y in points]
    face = bm.faces.new(verts)
    result = bmesh.ops.extrude_face_region(bm, geom=[face])
    moved = [e for e in result["geom"] if isinstance(e, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, vec=(0, 0, depth), verts=moved)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = _obj_from_bm(name, bm, mat)
    obj.location = loc
    obj.rotation_euler = Euler([math.radians(v) for v in rot])
    if bevel > 0:
        add_bevel(obj, bevel, 2)
    return obj


def sheet(name, grid, mat=None, apart=0.002):
    """A thin sheet (a leaf of paper) through a grid of points [[(x, y, z), ...], ...]: a face on each
    of its sides, `apart` from one another, so it shows from both."""
    bm = bmesh.new()
    for flip, drop in ((False, 0.0), (True, apart)):
        verts = [[bm.verts.new((x, y, z - drop)) for x, y, z in row] for row in grid]
        for j in range(len(grid) - 1):
            for i in range(len(grid[0]) - 1):
                quad = (verts[j][i], verts[j][i + 1], verts[j + 1][i + 1], verts[j + 1][i])
                bm.faces.new(quad[::-1] if flip else quad)
    return _obj_from_bm(name, bm, mat)


def tube(name, start, end, radius, radius_end=None, mat=None, verts=12):
    """A (tapered) cylinder from one point to another."""
    start, end = Vector(start), Vector(end)
    axis = end - start
    obj = cylinder(name, radius, axis.length, mat=mat, verts=verts,
                   radius2=radius if radius_end is None else radius_end)
    # create_cone builds along Z with radius1 at -Z; point -Z at the start.
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = axis.normalized().to_track_quat("Z", "Y")
    obj.location = (start + end) / 2
    return obj


def add_bevel(obj, width, segments=2):
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    mod.harden_normals = False
    return mod


def smooth(obj):
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return obj


def subdivide(obj, levels=1):
    mod = obj.modifiers.new("Subdivision", "SUBSURF")
    mod.levels = levels
    mod.render_levels = levels
    return mod


def displace_noise(obj, strength=0.1, scale=1.0, name="Noise"):
    tex = bpy.data.textures.get(name) or bpy.data.textures.new(name, "CLOUDS")
    tex.noise_scale = scale
    mod = obj.modifiers.new("Displace", "DISPLACE")
    mod.texture = tex
    mod.strength = strength
    return mod


def merge(objects, name, keep=False):
    """Applies modifiers and transforms and joins the objects into one mesh, keeping every
    object's materials. Returns the new object."""
    depsgraph = bpy.context.evaluated_depsgraph_get()
    bm = bmesh.new()
    materials = []
    for obj in objects:
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        mesh.transform(obj.matrix_world)
        if obj.matrix_world.determinant() < 0:
            mesh.flip_normals()
        index_map = {}
        # The original materials, never the evaluated copies (those are temporary).
        for i, slot in enumerate(obj.material_slots):
            mat = slot.material
            if mat not in materials:
                materials.append(mat)
            index_map[i] = materials.index(mat)
        temp = bmesh.new()
        temp.from_mesh(mesh)
        for face in temp.faces:
            face.material_index = index_map.get(face.material_index, 0)
        temp_mesh = bpy.data.meshes.new("_tmp")
        temp.to_mesh(temp_mesh)
        temp.free()
        bm.from_mesh(temp_mesh)
        bpy.data.meshes.remove(temp_mesh)
        evaluated.to_mesh_clear()
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    for mat in materials:
        mesh.materials.append(mat)
    for poly in mesh.polygons:
        poly.use_smooth = True
    result = bpy.data.objects.new(name, mesh)
    _link(result, "Props")
    if not keep:
        for obj in objects:
            bpy.data.objects.remove(obj, do_unlink=True)
    # Sharp edges stay sharp: split normals above 40 degrees.
    auto_smooth(result, 40)
    weighted_normals(result)
    return result


def weighted_normals(obj):
    """Lets big faces keep their own direction where they meet small ones (a table top and its
    chamfer): without it the top's light bends towards the rim across the whole face, and a normal
    map baked against that bend comes out as wild tilts that smear."""
    mod = obj.modifiers.new("WeightedNormals", "WEIGHTED_NORMAL")
    mod.mode = "FACE_AREA"
    mod.weight = 100
    mod.keep_sharp = True
    view_layer = bpy.context.view_layer
    view_layer.update()
    for other in view_layer.objects:
        other.select_set(False)
    obj.select_set(True)
    view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj


def auto_smooth(obj, angle_deg=40):
    """Marks edges sharper than the angle as sharp so smooth shading keeps hard corners."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    limit = math.radians(angle_deg)
    for edge in bm.edges:
        if len(edge.link_faces) == 2:
            if edge.calc_face_angle(0) > limit:
                edge.smooth = False
        else:
            edge.smooth = False
    bm.to_mesh(obj.data)
    bm.free()
    return obj


def ground(obj):
    """Moves the mesh so its bottom centre is the origin (props stand on the floor).
    Returns the shift applied, to move attached meshes the same way."""
    coords = [v.co for v in obj.data.vertices]
    min_z = min(c.z for c in coords)
    cx = (min(c.x for c in coords) + max(c.x for c in coords)) / 2
    cy = (min(c.y for c in coords) + max(c.y for c in coords)) / 2
    shift = Vector((-cx, -cy, -min_z))
    obj.data.transform(Matrix.Translation(shift))
    obj.location = (0, 0, 0)
    return shift


def centre(obj):
    """Moves the object's origin to its bounding-box centre."""
    coords = [v.co for v in obj.data.vertices]
    mid = Vector(
        (
            (min(c.x for c in coords) + max(c.x for c in coords)) / 2,
            (min(c.y for c in coords) + max(c.y for c in coords)) / 2,
            (min(c.z for c in coords) + max(c.z for c in coords)) / 2,
        )
    )
    obj.data.transform(Matrix.Translation(-mid))
    obj.location = (0, 0, 0)
    return -mid


def dimensions(obj):
    coords = [v.co for v in obj.data.vertices]
    return (
        max(c.x for c in coords) - min(c.x for c in coords),
        max(c.y for c in coords) - min(c.y for c in coords),
        max(c.z for c in coords) - min(c.z for c in coords),
    )


def triangles(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


# Materials -----------------------------------------------------------------------------------------


# Materials made during the current build are reused by name; older ones are replaced.
# Build ids are unique per session, so materials saved by an earlier run never match.
BUILD = {"id": "", "count": 0, "session": f"{os.getpid()}-{int(__import__('time').time())}"}


def new_build():
    BUILD["count"] += 1
    BUILD["id"] = f"{BUILD['session']}:{BUILD['count']}"


class _Reuse(Exception):
    def __init__(self, mat):
        self.mat = mat


def _new_material(name):
    mat = bpy.data.materials.get(name)
    if mat and common.flag(mat, "build") == BUILD["id"]:
        raise _Reuse(mat)
    if mat:
        bpy.data.materials.remove(mat)
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat["dg_build"] = BUILD["id"]
    return mat, mat.node_tree.nodes, mat.node_tree.links, mat.node_tree.nodes["Principled BSDF"]


def _reusable(fn):
    def wrapper(name, *args, **kwargs):
        try:
            return fn(name, *args, **kwargs)
        except _Reuse as reuse:
            return reuse.mat

    wrapper.__name__ = fn.__name__
    wrapper.__doc__ = fn.__doc__
    return wrapper


def _coord(nodes, links):
    coord = nodes.new("ShaderNodeTexCoord")
    return coord.outputs["Object"]


# Scanned surfaces ---------------------------------------------------------------------------------------
# A prop's materials are photographed scans (art/source/textures, the ones the maps use too), laid over
# the prop from six sides and graded onto the material's own colours, so a prop's steel is the map's
# steel. The scan's height gives the relief; the prop's own shape says where its edges are worn.

# kind -> (scan, metres it covers, depth of its relief in studs, how much its edges wear, how much its
# brightness follows the scan's light and dark, how far it swings between its two colours). The last
# two are counted in the scan's own spread, so a contrasty scan varies a prop no more than a quiet
# one: paint, plastic and metal stay even (they would look camouflaged), wood, leather and stone vary.
SCANS = {
    "plastic": ("Plastic001", 0.3, 0.003, 0.0, 0.3, 0.3),
    "metal": ("metal_plate_02", 2.0, 0.005, 0.5, 0.4, 0.4),
    "paint": ("blue_metal_plate", 2.5, 0.005, 0.8, 0.4, 0.4),
    "matte": ("beige_wall_001", 3.0, 0.004, 0.2, 0.4, 0.4),
    "rubber": ("rubber_tiles", 2.0, 0.01, 0.0, 0.5, 0.5),
    "wood": ("oak_veneer_01", 1.83, 0.004, 0.2, 1.0, 0.9),
    "dark_wood": ("walnut_veneer_02", 1.0, 0.003, 0.2, 0.8, 0.7),
    "leather": ("brown_leather", 0.4, 0.02, 0.2, 0.9, 0.8),
    "cloth": ("rough_linen", 0.27, 0.012, 0.0, 0.8, 0.6),
    "wool": ("poly_wool_herringbone", 0.27, 0.01, 0.0, 0.7, 0.5),
    "paper": ("Paper001", 0.3, 0.003, 0.0, 0.5, 0.4),
    "card": ("Paper005", 0.4, 0.004, 0.0, 0.7, 0.5),
    "stone": ("concrete_wall_008", 2.71, 0.03, 0.3, 1.0, 0.9),
    "bark": ("sakura_bark", 1.59, 0.1, 0.0, 1.2, 1.0),
}
# The last word of a material's name ("Desk_Steel") names its kind when it is one of these; any
# other name takes the kind of the helper that made it.
WORDS = {
    "leather": ("leather",),
    "cloth": ("cloth", "fabric", "felt", "curtain", "quilt", "cushion", "scarf", "coat", "canvas", "sack", "cloak",
              "velvet", "ribbon", "tent", "rope", "thread", "string", "umbrella", "slipper", "hat", "bag"),
    "paper": ("paper", "pages", "label", "print", "photo", "menu", "lined"),
    "card": ("card", "folder", "cover", "book"),
    "wood": ("wood", "oak", "timber", "ply", "planks", "pencil", "bamboo", "stick"),
    "dark_wood": ("ebony",),
    "stone": ("stone", "concrete", "bone", "horn", "ivory", "ash", "coal"),
    "bark": ("bark",),
    "rubber": ("tyre", "rubber"),
    "metal": ("steel", "iron", "brass", "gold", "alu", "galv", "chrome", "rust", "metal", "rim", "cymbal"),
    "plastic": ("plastic", "resin", "bezel", "button"),
}
_stats = {}


def kind_of(name, fallback):
    word = name.rsplit("_", 1)[-1].lower().rstrip("0123456789")
    for kind, words in WORDS.items():
        if word in words:
            return kind
    return fallback


def _scan_image(scan, what):
    img = bpy.data.images.load(scanlib.prepared(scan)[what], check_existing=True)
    if what != "color":
        img.colorspace_settings.name = "Non-Color"
    return img


def _scan_stats(scan):
    """(mean brightness, its spread as a share of the mean, mean roughness, its spread) of a scan as a
    prop sees it: what its light and dark, and its rough and smooth, are measured against."""
    if scan not in _stats:
        files = scanlib.prepared(scan)
        light = scanlib.to_linear(scanlib._read(files["color"], 256, 256)) @ scanlib.LUMA
        rough = scanlib._read(files["rough"], 256, 256)[..., 0]
        mean = float(light.mean())
        _stats[scan] = (mean, max(0.01, float(light.std()) / max(1e-4, mean)), float(rough.mean()),
                        max(0.01, float(rough.std())))
    return _stats[scan]


def _math(nodes, links, operation, a, b=None, clamp=False):
    node = nodes.new("ShaderNodeMath")
    node.operation = operation
    node.use_clamp = clamp
    for socket, value in zip(node.inputs, (a, b)):
        if value is None:
            continue
        if isinstance(value, (int, float)):
            socket.default_value = value
        else:
            links.new(value, socket)
    return node.outputs["Value"]


def _scanned(mat, nodes, links, bsdf, kind, color_a, color_b, roughness, metallic):
    """Wires `kind`'s scan into the material: the scan's dark parts take color_a and its light parts
    color_b (give the same colour twice for a plain surface), its roughness varies around `roughness`,
    its height is the relief, and on painted and bare metal the prop's edges are worn."""
    scan, metres, depth, wear, tone_share, swing = SCANS[kind]
    mean_light, spread_light, mean_rough, spread_rough = _scan_stats(scan)
    mapping = nodes.new("ShaderNodeMapping")
    scale = 1.0 / (metres * lookbook.STUDS_PER_METRE)
    mapping.inputs["Scale"].default_value = (scale, scale, scale)
    links.new(_coord(nodes, links), mapping.inputs["Vector"])

    def sample(what):
        node = nodes.new("ShaderNodeTexImage")
        node.image = _scan_image(scan, what)
        node.projection = "BOX"
        node.projection_blend = 0.2
        links.new(mapping.outputs["Vector"], node.inputs["Vector"])
        return node.outputs["Color"]

    def value(color_socket):
        split = nodes.new("ShaderNodeSeparateColor")
        links.new(color_socket, split.inputs["Color"])
        return split.outputs["Red"]

    grey = nodes.new("ShaderNodeRGBToBW")
    links.new(sample("color"), grey.inputs["Color"])
    light = _math(nodes, links, "DIVIDE", grey.outputs["Val"], mean_light)  # 1 = the scan's average
    # How far this spot is from the scan's average, in the scan's own spread (kept within three).
    off = _math(nodes, links, "DIVIDE", _math(nodes, links, "SUBTRACT", light, 1.0), spread_light)
    off = _math(nodes, links, "MAXIMUM", _math(nodes, links, "MINIMUM", off, 3.0), -3.0)
    # Its dark parts lean to the first colour, its light parts to the second...
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.25
    ramp.color_ramp.elements[0].color = (*color_a, 1)
    ramp.color_ramp.elements[1].position = 0.75
    ramp.color_ramp.elements[1].color = (*color_b, 1)
    links.new(_math(nodes, links, "ADD", _math(nodes, links, "MULTIPLY", off, 0.125 * swing), 0.5, clamp=True),
              ramp.inputs["Fac"])
    # ...and its brightness follows the scan's own light and dark a little.
    tone = nodes.new("ShaderNodeVectorMath")
    tone.operation = "SCALE"
    links.new(ramp.outputs["Color"], tone.inputs[0])
    links.new(_math(nodes, links, "ADD", _math(nodes, links, "MULTIPLY", off, 0.06 * tone_share), 1.0), tone.inputs["Scale"])
    colour = tone.outputs["Vector"]

    # The scan's relief. (Edges are rounded in the mesh, by the builders' own bevels: a shader bevel
    # takes a thin inlay or a label lying on a surface for an edge and tilts the whole face under it.)
    bump = nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 1.0
    bump.inputs["Distance"].default_value = depth
    links.new(value(sample("height")), bump.inputs["Height"])
    links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])

    # Rougher and smoother than the material's own level by what its kind allows, like the brightness.
    rough = _math(nodes, links, "DIVIDE", _math(nodes, links, "SUBTRACT", value(sample("rough")), mean_rough), spread_rough)
    rough = _math(nodes, links, "MAXIMUM", _math(nodes, links, "MINIMUM", rough, 3.0), -3.0)
    rough = _math(nodes, links, "ADD", _math(nodes, links, "MULTIPLY", rough, 0.04 * tone_share), roughness)
    if wear > 0:
        # Where the shape turns outward (edges, corners), hands and knocks have worn the finish: lighter
        # and smoother. The mesh's own pointiness says where.
        geometry = nodes.new("ShaderNodeNewGeometry")
        edge = _math(nodes, links, "SUBTRACT", geometry.outputs["Pointiness"], 0.5)
        edge = _math(nodes, links, "MULTIPLY", edge, 6.0, clamp=True)
        # (Broken up by the scan, so the wear is not a drawn line.)
        edge = _math(nodes, links, "MULTIPLY", edge, _math(nodes, links, "MULTIPLY", light, wear, clamp=True))
        worn = nodes.new("ShaderNodeVectorMath")
        worn.operation = "SCALE"
        links.new(colour, worn.inputs[0])
        links.new(_math(nodes, links, "ADD", 1.0, _math(nodes, links, "MULTIPLY", edge, 0.7)), worn.inputs["Scale"])
        colour = worn.outputs["Vector"]
        rough = _math(nodes, links, "SUBTRACT", rough, _math(nodes, links, "MULTIPLY", edge, 0.15))
    links.new(colour, bsdf.inputs["Base Color"])
    clamp = nodes.new("ShaderNodeClamp")
    clamp.inputs["Min"].default_value = 0.03
    links.new(rough, clamp.inputs["Value"])
    links.new(clamp.outputs["Result"], bsdf.inputs["Roughness"])
    bsdf.inputs["Metallic"].default_value = metallic
    mat["dg_roughness"] = roughness
    mat["dg_metallic"] = metallic
    mat["dg_kind"] = kind


@_reusable
def flat(name, color, roughness=0.6, metallic=0.0, kind=None):
    """One colour. kind: the surface (SCANS), when the name's last word does not already say."""
    mat, nodes, links, bsdf = _new_material(name)
    kind = kind or kind_of(name, "metal" if metallic > 0.5 else "matte")
    _scanned(mat, nodes, links, bsdf, kind, color, color, roughness, metallic)
    return mat


@_reusable
def noisy(name, color_a, color_b, scale=6.0, detail=8.0, roughness=0.6, metallic=0.0, stretch=(1, 1, 1), kind=None):
    """Two colours: the surface's dark parts take the first, its light parts the second (grime,
    leather, concrete, cast iron). scale, detail and stretch shaped the noise this was once drawn
    with; the scan decides now, and they are accepted so that the builders need not change."""
    mat, nodes, links, bsdf = _new_material(name)
    kind = kind or kind_of(name, "metal" if metallic > 0.5 else "matte")
    _scanned(mat, nodes, links, bsdf, kind, color_a, color_b, roughness, metallic)
    return mat


@_reusable
def wood(name, light, dark, scale=3.0, rings=18.0, roughness=0.55):
    """Wood between two browns, its grain running along X (scale and rings: see noisy)."""
    mat, nodes, links, bsdf = _new_material(name)
    kind = "dark_wood" if sum(light) / 3 < 0.09 else "wood"
    _scanned(mat, nodes, links, bsdf, kind, dark, light, roughness, 0.0)
    return mat


@_reusable
def banded(name, color_a, color_b, frequency=120.0, axis="Z", roughness=0.85):
    """Fine parallel bands (page edges, corrugated metal, blinds)."""
    mat, nodes, links, bsdf = _new_material(name)
    coord = _coord(nodes, links)
    wave = nodes.new("ShaderNodeTexWave")
    wave.wave_type = "BANDS"
    wave.bands_direction = axis
    wave.inputs["Scale"].default_value = frequency
    wave.inputs["Distortion"].default_value = 0.3
    links.new(coord, wave.inputs["Vector"])
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (*color_a, 1)
    ramp.color_ramp.elements[1].color = (*color_b, 1)
    links.new(wave.outputs["Fac"], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = roughness
    mat["dg_roughness"] = roughness
    mat["dg_metallic"] = 0.0
    return mat


@_reusable
def emissive(name, color, strength=4.0):
    mat, nodes, links, bsdf = _new_material(name)
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Emission Color"].default_value = (*color, 1)
    bsdf.inputs["Emission Strength"].default_value = strength
    mat["dg_glow"] = True
    return mat


@_reusable
def glass(name, color, alpha=0.35):
    mat, nodes, links, bsdf = _new_material(name)
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = 0.05
    bsdf.inputs["Alpha"].default_value = alpha
    mat["dg_glass"] = True
    return mat


# UVs and baking ---------------------------------------------------------------------------------------


def _select_only(obj):
    view_layer = bpy.context.view_layer
    view_layer.update()
    for other in view_layer.objects:
        if other is not None:
            other.select_set(False)
    obj.select_set(True)
    view_layer.objects.active = obj


def faces(obj, normal, where=None):
    """The faces of a mesh that look along `normal` (and whose middle `where` accepts), by number."""
    normal = Vector(normal).normalized()
    return [poly.index for poly in obj.data.polygons
            if poly.normal.dot(normal) > 0.95 and (where is None or where(poly.center))]


def lay(obj, picked, rect, u, v, span=None):
    """Flat UVs for the faces `picked`: seen along the axes u and v, their outline fills rect
    (u0, v0, u1, v1) of the texture. For a face that carries a picture, which has to know where it is.
    span: (low u, high u, low v, high v) along those axes to fill the rect with, when it is not the
    faces' own outline (a bevelled board's face is a little smaller than the board)."""
    mesh = obj.data
    layer = mesh.uv_layers.active or mesh.uv_layers.new(name="UVMap")
    u, v = Vector(u), Vector(v)
    spots = {}
    for index in picked:
        for loop in mesh.polygons[index].loop_indices:
            co = mesh.vertices[mesh.loops[loop].vertex_index].co
            spots[loop] = (co.dot(u), co.dot(v))
    if not spots:
        raise ValueError(f"{obj.name}: no face to lay on {rect}")
    if span:
        lo_u, hi_u, lo_v, hi_v = span
    else:
        lo_u, hi_u = min(s[0] for s in spots.values()), max(s[0] for s in spots.values())
        lo_v, hi_v = min(s[1] for s in spots.values()), max(s[1] for s in spots.values())
    for loop, (a, b) in spots.items():
        layer.data[loop].uv = (rect[0] + (a - lo_u) / max(hi_u - lo_u, 1e-9) * (rect[2] - rect[0]),
                               rect[1] + (b - lo_v) / max(hi_v - lo_v, 1e-9) * (rect[3] - rect[1]))
    return set(picked)


def unwrap(obj, margin=0.02, angle=60, laid=None, into=(0.0, 0.0, 1.0, 1.0)):
    """laid: a function (obj) -> the faces it gave UVs by hand (lay); the others are unwrapped into the
    part `into` of the texture."""
    # Faces with a zero-length edge go first (where a lathe's profile touches its axis, a whole ring of
    # points is one point): they have no direction for a normal map to be measured against, and baked
    # as random tilts, which showed as smears on a polished table top.
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.dissolve_degenerate(bm, dist=1e-6, edges=bm.edges)
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    kept = laid(obj) if laid else set()
    if len(kept) == len(obj.data.polygons):
        return
    _select_only(obj)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    if kept:
        bpy.ops.mesh.select_all(action="DESELECT")
        edit = bmesh.from_edit_mesh(obj.data)
        for face in edit.faces:
            face.select_set(face.index not in kept)
        bmesh.update_edit_mesh(obj.data)
    bpy.ops.uv.smart_project(angle_limit=math.radians(angle), island_margin=margin, area_weight=0.0)
    bpy.ops.object.mode_set(mode="OBJECT")
    if kept or tuple(into) != (0.0, 0.0, 1.0, 1.0):
        layer = obj.data.uv_layers.active
        for poly in obj.data.polygons:
            if poly.index not in kept:
                for loop in poly.loop_indices:
                    uv = layer.data[loop].uv
                    layer.data[loop].uv = (into[0] + uv.x * (into[2] - into[0]), into[1] + uv.y * (into[3] - into[1]))


def texture_size(obj, limit=1024, where="prop"):
    """The texture size the look rulebook gives a prop: enough pixels for its surface at the density
    of `where` ("prop", or "held" for what sits in a hand), and never more than `limit`."""
    area = sum(poly.area for poly in obj.data.polygons)
    side = math.sqrt(max(1e-6, area) / 0.55)  # (an unwrap fills a little over half of its square)
    size = 2 ** round(math.log2(side * lookbook.DENSITY[where]))
    return int(min(limit, lookbook.LARGEST, max(lookbook.SMALLEST, size)))


def _save_map(name, pixels, size, non_color, quality):
    img = bpy.data.images.new(name, size, size, alpha=False)
    if non_color:
        img.colorspace_settings.name = "Non-Color"
    img.pixels.foreach_set(np.ascontiguousarray(pixels, dtype=np.float32).ravel())
    path = os.path.join(common.TEXTURES, name + ".jpg")
    img.filepath_raw = path
    img.file_format = "JPEG"
    # (On Windows another program may hold the old file for a moment: a scanner, a file listing.)
    for attempt in range(6):
        try:
            img.save(filepath=path, quality=quality)
            break
        except RuntimeError:
            if attempt == 5:
                raise
            time.sleep(1.0)
    img.filepath = path
    return img


def bake(obj, size=1024, ao_strength=0.6, samples=24, where="prop", exact=False, finish=None):
    """Bakes the object's materials into one set of textures, then gives the object a single material
    using them: <name>_color.jpg (colour with the shade of its own hollows), <name>_normal.jpg (the
    scans' relief, at half the colour's size), <name>_rough.jpg and, when part of
    it is metal, <name>_metal.jpg (a quarter). `size` is the most the colour may take; the look
    rulebook may give it less (exact: it takes `size` as given, for a face that carries a picture).
    The split is what lets a prop carry four maps in the memory its one colour map took before.
    finish: a function (colour, normal, roughness), each a pixel array [v, u, 4], called before they
    are saved, to change them in place (pictures drawn straight onto faces laid by hand).
    Returns the colour map's path."""
    scene = bpy.context.scene
    previous_engine = scene.render.engine
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    common.ensure_dirs()
    size = size if exact else texture_size(obj, size, where)
    half = max(lookbook.SMALLEST // 2, size // 2)
    small = max(lookbook.SMALLEST // 2, size // 4)

    def target(name, side, data=False):
        img = bpy.data.images.new(obj.name + name, side, side, alpha=False, float_buffer=data)
        if data:
            img.colorspace_settings.name = "Non-Color"
        return img

    def read(img, side):
        return np.array(img.pixels[:], dtype=np.float32).reshape(side, side, 4)

    color_img, ao_img = target("_bake_color", size), target("_bake_ao", size)
    normal_img = target("_bake_normal", half, True)
    rough_img, metal_img = target("_bake_rough", small, True), target("_bake_metal", small, True)

    targets = []
    # Metals bake as black diffuse colour; bake their albedo as if they were not metal.
    saved_metal = {}
    for mat in obj.data.materials:
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        if bsdf and not bsdf.inputs["Metallic"].is_linked:
            saved_metal[mat.name] = bsdf.inputs["Metallic"].default_value
            bsdf.inputs["Metallic"].default_value = 0.0
    for mat in obj.data.materials:
        node = mat.node_tree.nodes.new("ShaderNodeTexImage")
        node.name = "DeathsGambitBake"
        mat.node_tree.nodes.active = node
        targets.append((mat, node))

    def aim(img):
        for _, node in targets:
            node.image = img

    # Alone in the scene while it bakes: every prop in Props.blend stands on the same spot, and its
    # neighbours would shade it (and round its edges against theirs).
    others = [o for o in scene.objects if o is not obj and o.type == "MESH" and not o.hide_render]
    for other in others:
        other.hide_render = True
    _select_only(obj)
    scene.render.bake.margin = 8
    scene.render.bake.use_pass_direct = False
    scene.render.bake.use_pass_indirect = False
    scene.render.bake.use_pass_color = True
    aim(color_img)
    bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"}, margin=8)
    aim(ao_img)
    bpy.ops.object.bake(type="AO", margin=8)
    aim(normal_img)
    bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT", margin=8)
    aim(rough_img)
    bpy.ops.object.bake(type="ROUGHNESS", margin=8)
    # Metalness has no bake pass of its own: each material glows by how metal it is, and the glow is
    # baked.
    glows = []
    for mat, _ in targets:
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        if not bsdf:
            continue
        socket = bsdf.inputs["Emission Color"]
        sources = [link.from_socket for link in socket.links]
        glows.append((mat, bsdf, tuple(socket.default_value), bsdf.inputs["Emission Strength"].default_value, sources))
        for link in list(socket.links):
            mat.node_tree.links.remove(link)
        value = saved_metal.get(mat.name, 0.0)
        socket.default_value = (value, value, value, 1)
        bsdf.inputs["Emission Strength"].default_value = 1.0
    aim(metal_img)
    bpy.ops.object.bake(type="EMIT", margin=8)
    for mat, bsdf, colour, strength, sources in glows:
        bsdf.inputs["Emission Color"].default_value = colour
        bsdf.inputs["Emission Strength"].default_value = strength
        for source in sources:
            mat.node_tree.links.new(source, bsdf.inputs["Emission Color"])
    for other in others:
        other.hide_render = False

    color = read(color_img, size)
    shade = 1.0 - ao_strength * (1.0 - read(ao_img, size)[..., :3])
    final = color.copy()
    final[..., :3] = color[..., :3] * shade
    final[..., 3] = 1.0
    metal = read(metal_img, small)
    normal, rough = read(normal_img, half), read(rough_img, small)
    if finish:
        finish(final, normal, rough)
    maps = {
        "color": _save_map(obj.name + "_color", final, size, False, 90),
        "normal": _save_map(obj.name + "_normal", normal, half, True, 90),
        "rough": _save_map(obj.name + "_rough", rough, small, True, 88),
    }
    metal_path = os.path.join(common.TEXTURES, obj.name + "_metal.jpg")
    if float(metal[..., 0].max()) > 0.1:
        maps["metal"] = _save_map(obj.name + "_metal", metal, small, True, 88)
    elif os.path.exists(metal_path):
        os.remove(metal_path)
    path = bpy.path.abspath(maps["color"].filepath)

    for mat, node in targets:
        mat.node_tree.nodes.remove(node)
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        if bsdf and mat.name in saved_metal:
            bsdf.inputs["Metallic"].default_value = saved_metal[mat.name]
    for img in (color_img, ao_img, normal_img, rough_img, metal_img):
        bpy.data.images.remove(img)

    # Roughness and metalness weighted by how much surface each material covers (the prop's base
    # Roblox material is chosen from them).
    areas = [0.0] * len(obj.data.materials)
    for poly in obj.data.polygons:
        areas[poly.material_index] += poly.area
    total = sum(areas) or 1.0
    obj["metalness"] = round(sum(common.flag(m, "metallic", 0.0) * a for m, a in zip(obj.data.materials, areas)) / total, 2)

    # One material with the baked textures.
    baked, nodes, links, bsdf = _new_material("M_" + obj.name)

    def use(kind, socket):
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = maps[kind]
        links.new(tex.outputs["Color"], socket)

    use("color", bsdf.inputs["Base Color"])
    use("rough", bsdf.inputs["Roughness"])
    relief = nodes.new("ShaderNodeNormalMap")
    use("normal", relief.inputs["Color"])
    links.new(relief.outputs["Normal"], bsdf.inputs["Normal"])
    if "metal" in maps:
        use("metal", bsdf.inputs["Metallic"])
    else:
        bsdf.inputs["Metallic"].default_value = 0.0
    obj.data.materials.clear()
    obj.data.materials.append(baked)
    scene.render.engine = previous_engine
    return path
