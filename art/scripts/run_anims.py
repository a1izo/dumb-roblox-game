"""Command-line entry to rebuild the animations and export them (background Blender):

    blender -b --factory-startup --python art/scripts/run_anims.py [-- --keep | --add name,name]

Rebuilds the rig and every action from anims.py, writes src/shared/Anim/Clips/ and saves
art/blend/Animations.blend. With --keep, the actions in the saved .blend are exported as they
are (use this after editing curves by hand in Blender). With --add, only the named clips are
built from anims.py, onto the rig the saved .blend already holds, and every other action stays
as saved (hand-edited curves included): the way to add a clip without the downloaded rig file.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402

import common  # noqa: E402


def main():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    blend = os.path.join(common.BLEND, "Animations.blend")
    if "--add" in argv and os.path.exists(blend):
        names = [name for name in argv[argv.index("--add") + 1].split(",") if name]
        bpy.ops.wm.open_mainfile(filepath=blend)
        import animlib
        import anims  # noqa: F401  (defines every clip)
        import export_anims

        arm = bpy.data.objects["R6"]
        bpy.context.scene.render.fps = animlib.FPS
        for name in names:
            if name not in animlib.CLIPS:
                raise SystemExit(f"anims.py has no clip named {name}")
            animlib.build_action(arm, animlib.CLIPS[name])
            print("[anims] built", name)
    elif "--keep" in argv and os.path.exists(blend):
        bpy.ops.wm.open_mainfile(filepath=blend)
        import export_anims

        arm = bpy.data.objects["R6"]
    else:
        import anims
        import export_anims
        import rig

        arm = rig.build_rig()
        anims.build(arm)
    print("[anims]", export_anims.export(arm))
    common.save_blend("Animations.blend")


main()
