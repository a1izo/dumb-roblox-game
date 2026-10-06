"""Command-line entry for building props in a background Blender:

    blender -b --factory-startup --python art/scripts/run_props.py -- [keys...] [--export] [--preview] [--set Tokyo]
    blender -b --factory-startup --python art/scripts/run_props.py -- --sheet street [--no-build]

With no keys every prop is built; with --set only that set's props (--export alone rebuilds
nothing). --export writes the set's FBX, DeathsGambitModels_<Set>.fbx (--set is needed: Core, Tokyo,
Agency, Campus, Lobby, Meeting), and the catalog of every prop. Opens art/blend/Props.blend when it exists (so props can be
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
import sheets  # noqa: E402


def main():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    do_export = "--export" in argv
    do_preview = "--preview" in argv
    set_name = argv[argv.index("--set") + 1] if "--set" in argv else ""
    sheet = argv[argv.index("--sheet") + 1] if "--sheet" in argv else ""
    keys = [a for a in argv if not a.startswith("--") and a not in (set_name, sheet)]
    if sheet and not keys:
        keys = [k for k in sheets.GROUPS[sheet] if k in props.BUILDERS]
        if "--no-build" in argv:
            keys = []
    if set_name and not keys and not do_export:
        keys = [k for k, spec in props.BUILDERS.items() if spec.get("set") == set_name]
    blend = os.path.join(common.BLEND, "Props.blend")
    if os.path.exists(blend):
        bpy.ops.wm.open_mainfile(filepath=blend)
    else:
        common.clear_scene()
    no_build = sheet and "--no-build" in argv
    if (keys or not do_export) and not no_build:
        started = time.time()
        results = build_props.build(keys or None)
        for key, info in results.items():
            print(f"[props] {key}: size {info['size']} tris {info['tris']}")
        print(f"[props] built in {time.time() - started:.1f}s")
        if do_preview:
            for key in keys or list(props.BUILDERS):
                print("[props] preview", build_props.preview(key))
    if not no_build:
        common.save_blend("Props.blend")
    if sheet:
        print("[props] sheet", sheets.render(sheet, sheets.GROUPS[sheet]))
    if do_export:
        print("[props] export", build_props.export(set_name))


main()
