"""Many stills of one shot in one Blender run (the venue is built once, about three minutes; run_cinema's --stills builds
it again for every call):

    blender -b --factory-startup --python art/scripts/review_stills.py -- <Shot> <outdir> "<t>@cam" "<t>@px,py,pz,tx,ty,tz,fov" ...

Each view is written as <outdir>/<Shot>_<index>.png: `@cam` through the shot's own camera (with the game's letterbox), or from
anywhere (like `--eye` of run_cinema --preview). 960x540 unless DG_SIZE=WxH; DG_LETTERBOX=L puts the letterbox on the free views.
Like the previews it plays the clips saved in Animations.blend, so run run_anims.py -- --add first.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402
from mathutils import Matrix  # noqa: E402

import run_cinema as rc  # noqa: E402
from cinema import shot as shotlib  # noqa: E402


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    name, outdir, views = argv[0], argv[1], argv[2:]
    os.makedirs(outdir, exist_ok=True)
    shots = rc.load_shots()
    shot = shots[name]
    library = rc.build_set(shot.venue)
    clips = {a.clip for a in shot.actors if a.clip}
    rig, actions = rc.load_rig(clips)
    for i, actor in enumerate(shot.actors):
        root, arm, parts = rc.place_actor(shot, actor, rig, actions, i)
        rc.add_held(actor, arm, parts, library)
    rc.add_props(shot, library)
    rc.add_shot_lights(shot)
    cam = rc.add_camera(shot)
    scene = bpy.context.scene
    w, h = (int(v) for v in os.environ.get("DG_SIZE", "960x540").split("x"))
    scene.render.resolution_x, scene.render.resolution_y = w, h
    scene.render.image_settings.media_type = "IMAGE"
    scene.render.image_settings.file_format = "PNG"
    for n, spec in enumerate(views):
        t, what = spec.split("@", 1)
        t = float(t)
        if what == "cam":
            scene.camera = cam
            rc.letterbox(scene, shot.letterbox)
        else:
            eye = [float(v) for v in what.split(",")]
            data = bpy.data.cameras.new(f"EyeCam{n}")
            data.sensor_fit = "VERTICAL"
            data.clip_start = 0.1
            data.clip_end = 3000
            data.angle_y = math.radians(eye[6] if len(eye) > 6 else 60.0)
            look = bpy.data.objects.new(f"EyeCam{n}", data)
            scene.collection.objects.link(look)
            look.matrix_world = Matrix.Translation(rc.b_pos(eye[:3])) @ rc.b_rot(
                shotlib.look_rotation(eye[:3], eye[3:6]), True).to_4x4()
            scene.camera = look
            rc.letterbox(scene, "L" in os.environ.get("DG_LETTERBOX", ""))
        scene.frame_set(int(round(t * rc.FPS)))
        path = os.path.join(outdir, f"{name}_{n:02d}.png")
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        print("[views]", path)


main()
