"""The shop's death scenes rendered for review (background Blender): each scene's set (art/scripts/cinema/deathcuts.py:
its parts, Core props and lights), its star on the R6 mannequin in its death clip from `clipAt` (and, in a death style's
scene, the style's clip from its `fallen` event, laid over the body where it lies as Presentation/Fallen does), seen
through the scene's own shots (each shot's start, middle and end):

    blender -b --factory-startup --python art/scripts/review_deaths.py -- [scene ...] [--size=480]

Writes art/export/previews/deaths/<scene>/sheet.png. What happens on the set (the chandelier falling, lamps going out)
and the effects are not drawn: it shows the framing and the acting."""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Matrix  # noqa: E402

import common  # noqa: E402
import emotemeta  # noqa: E402
import review_emote as rv  # noqa: E402
import review_win as rw  # noqa: E402

OUT = os.path.join(common.PREVIEWS, "deaths")


def main():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    size = 480
    names = []
    for a in argv:
        if a.startswith("--size="):
            size = int(a.split("=", 1)[1])
        else:
            names.append(a)
    from cinema import deathcuts  # (builds the scenes, and writes DeathCuts.luau as it does)

    cuts = deathcuts.CUTS
    names = names or sorted(cuts)
    cat = emotemeta.catalog()
    bpy.ops.wm.open_mainfile(filepath=os.path.join(common.BLEND, "Animations.blend"))
    for obj in list(bpy.data.objects):
        if obj.type in ("CAMERA", "LIGHT") or obj.name.startswith("label_"):
            bpy.data.objects.remove(obj, do_unlink=True)
    arm = bpy.data.objects["R6"]
    parts = {child.name: child for child in arm.children}
    rv.bind_rest(arm, parts)
    rest = arm.matrix_world.copy()
    rw.FLOOR[0] = rest @ rw.AXES4
    lib = rv.library()
    cam = rv.bench(size)
    scene = bpy.context.scene
    scene.render.resolution_x, scene.render.resolution_y = size, int(size * 9 / 16)
    floor = bpy.data.objects.get("Floor")
    if floor is not None:
        floor.hide_render = True
    for name in ("Key", "Fill", "Rim"):
        light = bpy.data.objects.get(name)
        if light is not None:
            light.data.energy *= 0.35
    axes = rw.AXES4
    axes_inv = axes.inverted()
    for name in names:
        cut = cuts.get(name)
        if cut is None:
            print(f"[deaths] no scene {name}")
            continue
        length = float(cut["length"])
        clip_at = float(cut["clipAt"])
        style = next((e for e in cut["events"] if e["act"] == "fallen"), None)
        tl = deathcuts.Timeline(cut["clip"], clip_at, style["style"] if style else None,
                                style["at"] if style else None)
        base = Matrix([list(row) for row in tl.base])
        moved = rest @ axes @ base @ axes_inv
        arm.animation_data_create()
        for obj in list(common.collection("Props").objects):
            bpy.data.objects.remove(obj, do_unlink=True)
        coll = common.collection("WinSet")
        for obj in list(coll.objects):
            bpy.data.objects.remove(obj, do_unlink=True)
        arm.animation_data.action = bpy.data.actions[cut["clip"]]
        rv.bake_props(arm, parts, rw.as_meta(cut, None), cat, lib, [0], length, False)
        for spec in cut.get("parts") or []:
            if not spec.get("hidden") and (spec.get("alpha") or 0) < 1:
                rw.part(spec, coll)
            light = spec.get("light")
            if light and light.get("brightness", 0) > 0:
                data = bpy.data.lights.new("WL", "POINT")
                data.color = rw.rgb(light["color"])[:3]
                data.energy = 60 * light["brightness"] * light["range"] / 9
                obj = bpy.data.objects.new("WL", data)
                coll.objects.link(obj)
                obj.location = rw.FLOOR[0] @ rw.Vector(spec["at"])
        folder = os.path.join(OUT, name)
        os.makedirs(folder, exist_ok=True)
        stills = []
        shots = cut["shots"]
        for i, shot in enumerate(shots):
            t1 = shots[i + 1]["at"] if i + 1 < len(shots) else length
            for tag, u in (("a", 0.0), ("b", 0.5), ("c", 1.0)):
                t = shot["at"] + (t1 - shot["at"]) * u - (0.05 if tag == "c" else 0.0)
                if style and t >= style["at"]:
                    arm.animation_data.action = bpy.data.actions[tl.style_clip]
                    arm.matrix_world = moved
                    local = t - style["at"]
                else:
                    arm.animation_data.action = bpy.data.actions[cut["clip"]]
                    arm.matrix_world = rest
                    local = max(0.0, t - clip_at)
                scene.frame_set(int(round(local * rv.FPS)))
                rw.camera_at(cam, shot, u)
                path = os.path.join(folder, f"shot{i + 1}_{tag}.png")
                rv.render_still(path)
                stills.append(path)
        arm.matrix_world = rest
        rv.make_sheet(stills, os.path.join(folder, "sheet.png"), cols=3, tile=size // 2, tall=int(size * 9 / 32))
        print(f"[deaths] {name}: {folder}")


main()
