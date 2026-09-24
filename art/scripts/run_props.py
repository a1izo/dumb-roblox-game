"""Command-line entry for building props in a background Blender:

    blender -b --factory-startup --python art/scripts/run_props.py -- [keys...] [--export] [--preview]

With no keys every prop is built. Opens art/blend/Props.blend when it exists (so props can be
rebuilt one at a time), and saves it back.
"""

import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402

import build_props  # noqa: E402
import common  # noqa: E402
import props  # noqa: E402


def main():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    do_export = "--export" in argv
    do_preview = "--preview" in argv
    keys = [a for a in argv if not a.startswith("--")]
    blend = os.path.join(common.BLEND, "Props.blend")
    if os.path.exists(blend):
        bpy.ops.wm.open_mainfile(filepath=blend)
    else:
        common.clear_scene()
    if keys or not do_export:
        started = time.time()
        results = build_props.build(keys or None)
        for key, info in results.items():
            print(f"[props] {key}: size {info['size']} tris {info['tris']}")
        print(f"[props] built in {time.time() - started:.1f}s")
        if do_preview:
            for key in keys or list(props.BUILDERS):
                print("[props] preview", build_props.preview(key))
    common.save_blend("Props.blend")
    if do_export:
        print("[props] export", build_props.export())


main()
