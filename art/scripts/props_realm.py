"""The Grey Realm's rock kit as props (set "Lobby"): every shape of realmrock.py, made once here and stood about the
realm by the lobby's venue, turned and scaled. They are tiled props (props.prop's tiled): the realm's rock scan and
its ash laid straight onto them, shared with the map's own ground, with no texture of their own. Each is solid by its
own mesh (2026-11-07, the user: no walking into anything): until then the venue stood boxes round each one's foot
(realmrock.footprint), and their bulges, overhangs and creases were walked into or stopped at by nothing drawn."""

import bpy

import realmrock
from maps import matlib
from props import prop

_IMAGES = {}


def _surfaces(key):
    names = realmrock.surfaces(key)
    if any(name not in _IMAGES for name in names):
        _IMAGES.update(matlib.make_textures(names=list(names)))
    return [matlib.material(name, _IMAGES) for name in names]


def surface(name):
    """A map surface for a tiled prop's part (its textures made or loaded once)."""
    if name not in _IMAGES:
        _IMAGES.update(matlib.make_textures(names=[name]))
    return matlib.material(name, _IMAGES)


def tile_uvs(obj):
    """Lays every face of obj in its surface's repeats, projected from the side it faces most (as the map's own faces
    are, mesher.planar_uvs): studs over the studs one repeat covers."""
    mesh = obj.data
    layer = mesh.uv_layers.get("UVMap") or mesh.uv_layers.new(name="UVMap")
    tiles = [matlib.tile_size(m.name[2:] if m.name.startswith("M_") else m.name) for m in mesh.materials]
    for poly in mesh.polygons:
        n = poly.normal
        tile = tiles[poly.material_index] if tiles else 4.0
        ax, ay, az = abs(n.x), abs(n.y), abs(n.z)
        for li in poly.loop_indices:
            co = mesh.vertices[mesh.loops[li].vertex_index].co
            if az >= ax and az >= ay:
                uv = (co.x, co.y if n.z > 0 else -co.y)
            elif ax >= ay:
                uv = (co.y if n.x > 0 else -co.y, co.z)
            else:
                uv = (-co.x if n.y > 0 else co.x, co.z)
            layer.data[li].uv = (uv[0] / tile, uv[1] / tile)
    return obj


def _kit(key):
    verts, faces, uvs, _ = realmrock.shape(key)
    mesh = bpy.data.meshes.new(key)
    mesh.from_pydata(verts, [], faces)
    layer = mesh.uv_layers.new(name="UVMap")
    # (the kit lays its UVs in repeats of the rock scan's tile; a shape of another surface, which wears no ash, is
    # scaled to that surface's own)
    main = realmrock.surfaces(key)[0]
    k = 1.0 if main == realmrock.ROCK else realmrock.TILE / matlib.tile_size(main)
    layer.data.foreach_set("uv", [c * k for face in uvs for uv in face for c in uv])
    for mat in _surfaces(key):
        mesh.materials.append(mat)
    mesh.polygons.foreach_set("material_index", realmrock.materials(key))
    mesh.validate(clean_customdata=False)
    mesh.update()
    obj = bpy.data.objects.new(key, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return [obj], []


def _register(key):
    @prop(key, pivot="bottom", material="Rock", collide=True, texture=256, set="Lobby", tiled=True)
    def build():
        return _kit(key)

    build.__name__ = "build_" + key
    build.__doc__ = f"The realm's rock kit: {key} (realmrock.KIT)."
    return build


for _key in realmrock.KIT:
    if not realmrock.KIT[_key].get("only_far"):
        _register(_key)
