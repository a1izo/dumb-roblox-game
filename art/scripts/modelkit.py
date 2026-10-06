"""A small modelling kit for Death's Gambit props: primitives with bevels, procedural materials,
merging into one mesh per prop, UV unwrapping and baking colour + ambient occlusion into a
single texture per prop (Roblox shows one texture per MeshPart).

Units: 1 Blender unit = 1 stud. Props stand on z = 0 and face -Y (the rig's facing), so the
FBX export (axis_forward="Z", axis_up="Y") turns them to face -Z in Roblox.
"""

import math
import os

import bmesh
import bpy
import numpy as np
from mathutils import Euler, Matrix, Vector

import common


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
    return result


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


@_reusable
def flat(name, color, roughness=0.6, metallic=0.0):
    mat, nodes, links, bsdf = _new_material(name)
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    mat["dg_roughness"] = roughness
    mat["dg_metallic"] = metallic
    return mat


@_reusable
def noisy(name, color_a, color_b, scale=6.0, detail=8.0, roughness=0.6, metallic=0.0, stretch=(1, 1, 1)):
    """Two colours mixed by noise (grime, leather, concrete, cast iron)."""
    mat, nodes, links, bsdf = _new_material(name)
    coord = _coord(nodes, links)
    mapping = nodes.new("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = stretch
    links.new(coord, mapping.inputs["Vector"])
    noise = nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = scale
    noise.inputs["Detail"].default_value = detail
    links.new(mapping.outputs["Vector"], noise.inputs["Vector"])
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (*color_a, 1)
    ramp.color_ramp.elements[1].color = (*color_b, 1)
    ramp.color_ramp.elements[0].position = 0.35
    ramp.color_ramp.elements[1].position = 0.7
    links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    mat["dg_roughness"] = roughness
    mat["dg_metallic"] = metallic
    return mat


@_reusable
def wood(name, light, dark, scale=3.0, rings=18.0, roughness=0.55):
    """Wood grain running along X: stretched noise bands between two browns."""
    mat, nodes, links, bsdf = _new_material(name)
    coord = _coord(nodes, links)
    mapping = nodes.new("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = (0.25, 4.0, 4.0)
    links.new(coord, mapping.inputs["Vector"])
    noise = nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = scale
    noise.inputs["Detail"].default_value = 6
    noise.inputs["Distortion"].default_value = 1.5
    links.new(mapping.outputs["Vector"], noise.inputs["Vector"])
    wave = nodes.new("ShaderNodeTexWave")
    wave.inputs["Scale"].default_value = rings
    wave.inputs["Distortion"].default_value = 6
    wave.bands_direction = "Y"
    links.new(mapping.outputs["Vector"], wave.inputs["Vector"])
    mix = nodes.new("ShaderNodeMix")
    mix.data_type = "FLOAT"
    mix.inputs["Factor"].default_value = 0.5
    links.new(noise.outputs["Fac"], mix.inputs["A"])
    links.new(wave.outputs["Fac"], mix.inputs["B"])
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (*dark, 1)
    ramp.color_ramp.elements[1].color = (*light, 1)
    links.new(mix.outputs["Result"], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = roughness
    mat["dg_roughness"] = roughness
    mat["dg_metallic"] = 0.0
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


def unwrap(obj, margin=0.02, angle=60):
    _select_only(obj)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(angle), island_margin=margin, area_weight=0.0)
    bpy.ops.object.mode_set(mode="OBJECT")


def bake(obj, size=1024, ao_strength=0.6, samples=24):
    """Bakes the object's materials (colour) and ambient occlusion into one texture, then gives
    the object a single material using it. Returns the image path."""
    scene = bpy.context.scene
    previous_engine = scene.render.engine
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    common.ensure_dirs()
    color_img = bpy.data.images.new(obj.name + "_color", size, size, alpha=False)
    ao_img = bpy.data.images.new(obj.name + "_ao", size, size, alpha=False)

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

    _select_only(obj)
    for _, node in targets:
        node.image = color_img
    scene.render.bake.margin = 8
    scene.render.bake.use_pass_direct = False
    scene.render.bake.use_pass_indirect = False
    scene.render.bake.use_pass_color = True
    bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"}, margin=8)
    for _, node in targets:
        node.image = ao_img
    bpy.ops.object.bake(type="AO", margin=8)

    color = np.array(color_img.pixels[:], dtype=np.float32).reshape(size, size, 4)
    ao = np.array(ao_img.pixels[:], dtype=np.float32).reshape(size, size, 4)
    shade = 1.0 - ao_strength * (1.0 - ao[..., :3])
    final = color.copy()
    final[..., :3] = color[..., :3] * shade
    final[..., 3] = 1.0
    out = bpy.data.images.new(obj.name + "_Texture", size, size, alpha=False)
    out.pixels = final.ravel()
    path = os.path.join(common.TEXTURES, obj.name + ".png")
    out.filepath_raw = path
    out.file_format = "PNG"
    out.save()

    for mat, node in targets:
        mat.node_tree.nodes.remove(node)
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        if bsdf and mat.name in saved_metal:
            bsdf.inputs["Metallic"].default_value = saved_metal[mat.name]
    bpy.data.images.remove(color_img)
    bpy.data.images.remove(ao_img)

    # One material with the baked texture.
    baked, nodes, links, bsdf = _new_material("M_" + obj.name)
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = out
    links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    # Roughness and metalness weighted by how much surface each material covers.
    areas = [0.0] * len(obj.data.materials)
    for poly in obj.data.polygons:
        areas[poly.material_index] += poly.area
    total = sum(areas) or 1.0
    rough = sum(common.flag(m, "roughness", 0.6) * a for m, a in zip(obj.data.materials, areas)) / total
    metal = sum(common.flag(m, "metallic", 0.0) * a for m, a in zip(obj.data.materials, areas)) / total
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    obj["metalness"] = round(metal, 2)
    obj.data.materials.clear()
    obj.data.materials.append(baked)
    scene.render.engine = previous_engine
    return path
