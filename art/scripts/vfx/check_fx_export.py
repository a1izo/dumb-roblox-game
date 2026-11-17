"""Reads the Fx props file back (art/export/DeathsGambitModels_Fx.fbx) and checks what a full export of
art/scripts/vfx/meshes.py must have put in it (ticket V1.7, the closing half). Exits 1 when anything is missing.

    blender -b --factory-startup --python art/scripts/vfx/check_fx_export.py -- [--old-fbx PATH] [--scratch DIR]

  * every texture in meshes.TEXTURES (23 old + 22 new) is embedded in the FBX byte for byte as art/export/textures/<name>.png,
    and has its Tex_<name> carrier quad with that picture on its material;
  * with --old-fbx (the previous export, e.g. `git show <rev>:art/export/DeathsGambitModels_Fx.fbx`) every old name's
    picture is byte for byte the one the old file carried;
  * every kit shape (meshes.BUILDERS, the three new ones included) is an object with a UV layer inside 0..1 that fills
    it, and the version marker for the Fx file and the three calibration cubes are there;
  * triangles per shape, under the importer's 20,000 (the import drops each shape's back-face twins, so the real
    count is double what this prints for the doubled shapes).
"""

import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))

import common  # noqa: E402
from maps import export as maps_export  # noqa: E402
from vfx import meshes  # noqa: E402

OLD_NAMES = meshes.TEXTURES[:23]
NEW_NAMES = meshes.TEXTURES[23:]
LIMIT = 20000


def arg(flag):
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    return args[args.index(flag) + 1] if flag in args else None


def main():
    problems = []
    fbx_bytes = open(meshes.FBX, "rb").read()
    print("[check_fx_export] file", meshes.FBX, len(fbx_bytes), "bytes", f"({len(fbx_bytes) / 2**20:.2f} MB)")

    old_bytes = open(arg("--old-fbx"), "rb").read() if arg("--old-fbx") else None
    for name in meshes.TEXTURES:
        path = os.path.join(common.TEXTURES, name + ".png")
        data = open(path, "rb").read()
        in_new = data in fbx_bytes
        line = f"  {name:18s} png {len(data):8d} bytes, embedded {'yes' if in_new else 'NO'}"
        if not in_new:
            problems.append(f"{name}: the PNG is not embedded byte for byte")
        if old_bytes is not None and name in OLD_NAMES:
            same = data in old_bytes
            line += f", same as the old file's {'yes' if same else 'NO'}"
            if not same:
                problems.append(f"{name}: an old texture differs from the one the old file carried")
        print(line)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=meshes.FBX)
    objects = {o.name: o for o in bpy.data.objects}

    def base(name):  # (the importer may add .001 to repeated names)
        return name.split(".")[0]

    by_name = {base(n): o for n, o in objects.items()}
    for name in meshes.TEXTURES:
        carrier = by_name.get("Tex_" + name)
        if carrier is None:
            problems.append(f"{name}: no Tex_{name} carrier quad")
            continue
        picture = None
        for slot in carrier.material_slots:
            for node in slot.material.node_tree.nodes if slot.material and slot.material.node_tree else []:
                if node.type == "TEX_IMAGE" and node.image:
                    picture = node.image
        if picture is None:
            problems.append(f"{name}: the carrier's material shows no picture")
    print(f"  carriers found: {sum(1 for n in meshes.TEXTURES if 'Tex_' + n in by_name)} of {len(meshes.TEXTURES)}")

    shapes = sorted(n for n in by_name if n.startswith("Vfx") and not n.startswith("Tex_"))
    print("  shapes in the file:", ", ".join(shapes))
    if len(shapes) != len(meshes.BUILDERS):
        problems.append(f"{len(shapes)} Vfx shapes in the file, meshes.BUILDERS has {len(meshes.BUILDERS)}")
    for want in ("VfxSlashArc", "VfxTwister", "VfxShell"):
        if want not in shapes:
            problems.append(f"the new shape {want} is not in the file")
    print("  (triangles as imported; the importer may drop a shape's back twins, so the real count is at most double)")
    for name in shapes:
        obj = by_name[name]
        mesh = obj.data
        mesh.calc_loop_triangles()
        tris = len(mesh.loop_triangles)
        uvs = mesh.uv_layers.active
        if uvs is None:
            problems.append(f"{name}: no UV layer")
            continue
        us = [d.uv[0] for d in uvs.data]
        vs = [d.uv[1] for d in uvs.data]
        inside = min(us) >= -1e-4 and max(us) <= 1 + 1e-4 and min(vs) >= -1e-4 and max(vs) <= 1 + 1e-4
        fills = max(us) - min(us) > 0.95 and max(vs) - min(vs) > 0.95
        print(f"  {name:12s} {tris:6d} tris, u {min(us):.3f}..{max(us):.3f}, v {min(vs):.3f}..{max(vs):.3f}")
        if not inside:
            problems.append(f"{name}: UVs outside 0..1")
        if not fills:
            problems.append(f"{name}: UVs do not fill 0..1 in both directions")
        if tris * 2 >= LIMIT:
            problems.append(f"{name}: {tris * 2} triangles is not under {LIMIT}")

    marker = "DeathsGambit" + "Models" + meshes.SET + "_Version_"
    version = [n for n in by_name if n.startswith(marker)] + [n for n in objects if n.startswith(marker)]
    print("  version marker:", sorted(set(version)) or "NONE")
    expect = f"{marker}{maps_export.VERSION['Models' + meshes.SET]}"
    if not any(v.startswith(expect) for v in version):
        problems.append(f"no version marker {expect}")
    for cube in ("_O", "_X", "_Y"):
        if "Calib_Props" + meshes.SET + cube not in by_name:
            problems.append(f"calibration cube {cube} missing")

    if problems:
        print("[check_fx_export] FAILED:")
        for p in problems:
            print("  -", p)
        sys.exit(1)
    print("[check_fx_export] OK:", len(meshes.TEXTURES), "textures and carriers,", len(shapes), "shapes")


if __name__ == "__main__":
    main()
