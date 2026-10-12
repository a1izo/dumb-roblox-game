"""Builds venues and lists the likely visual defects maps/finders.py finds in them (candidates for a
look by eye, never fixes):

    blender -b --factory-startup --python art/scripts/find_defects.py -- [venues...] [--out DIR]
            [--only zfight,rest,fixture,leak,stretch,buried]

Writes finds_<Venue>.json and finds_<Venue>.txt to DIR (default: art/export/previews), and an
eyes_<Venue>.txt with a camera for each find, ready for run_maps.py --eyes.
"""

import json
import math
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import importlib  # noqa: E402

import common  # noqa: E402
from maps import catalog, finders, mesher  # noqa: E402

# (run_maps.py runs on import, so its venue list is repeated here.)
VENUES = ["Lobby", "Meeting", "Agency", "Campus", "Tokyo"]
MODULES = {"Lobby": "lobby", "Meeting": "meeting", "Agency": "agency", "Campus": "campus", "Tokyo": "tokyo"}


def _caller():
    """Where in the venue's (or the kit's) scripts the piece being made was asked for: the first two
    frames outside mesher.py, innermost first."""
    frame = sys._getframe(2)
    out = []
    while frame and len(out) < 2:
        name = os.path.basename(frame.f_code.co_filename)
        if name not in ("mesher.py", "find_defects.py", "lightbook.py"):
            out.append(f"{name}:{frame.f_lineno}")
        frame = frame.f_back
    return " < ".join(out)


def build(name):
    """The venue's scene data (faces, props, lights, signs), as run_maps.build_venue makes it, without
    building Blender meshes. scene.piece_src maps each piece (by id) to the script line that made it."""
    module = importlib.import_module("maps.venues." + MODULES[name])
    scene = mesher.Scene(name, prefix="Map", chunk=128.0)
    plain = scene._piece
    scene.piece_src = {}

    def traced(mat):
        piece = plain(mat)
        scene.piece_src[id(piece)] = _caller()
        return piece

    scene._piece = traced
    plain_light = scene.light

    def traced_light(*args, **kwargs):
        plain_light(*args, **kwargs)
        scene.lights[-1]["src"] = _caller()

    scene.light = traced_light
    module.build(scene)
    return scene


def eye_for(find):
    """A camera at a player's eye, about 7 studs off the find, looking at it."""
    x, y, z = find["at"]
    n = find.get("normal")
    if n and abs(n[1]) < 0.7:
        ox, oz = n[0], n[2]
    else:
        ox, oz = 0.7, 0.7
    length = math.hypot(ox, oz) or 1.0
    ox, oz = ox / length * 7.0, oz / length * 7.0
    eye_y = y + 2.0 if find["kind"] in ("float", "sunk") else max(y - 2.0, y + 1.5 if n and n[1] > 0.7 else y)
    return f"{x + ox:.1f},{eye_y:.1f},{z + oz:.1f},{x:.1f},{y:.1f},{z:.1f},22"


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out_dir = os.path.join(common.ROOT, "art", "export", "previews")
    only = ("zfight", "rest", "fixture", "leak", "stretch", "buried")
    venues = []
    i = 0
    while i < len(argv):
        if argv[i] == "--out":
            out_dir = argv[i + 1]
            i += 2
        elif argv[i] == "--only":
            only = tuple(argv[i + 1].split(","))
            i += 2
        else:
            venues.append(argv[i])
            i += 1
    os.makedirs(out_dir, exist_ok=True)
    cat = catalog.load()
    common.clear_scene()
    for venue in venues or VENUES:
        scene = build(venue)
        started = time.time()
        finds, stats = finders.run(scene, cat, venue, only)
        finds.sort(key=lambda f: (f["kind"], -(f.get("worst") or f.get("area") or f.get("gap") or f.get("dist") or 0)))
        for n, f in enumerate(finds, 1):
            f["id"] = f"{venue[0]}{n:03d}"
        with open(os.path.join(out_dir, f"finds_{venue}.json"), "w", encoding="utf-8", newline="\n") as fh:
            json.dump(finds, fh, indent=1)
        counts = {}
        for f in finds:
            counts[f["kind"]] = counts.get(f["kind"], 0) + 1
        with open(os.path.join(out_dir, f"finds_{venue}.txt"), "w", encoding="utf-8", newline="\n") as fh:
            fh.write(f"{venue}: {stats['triangles']} triangles, {stats['lamps']} lamps; {counts}; "
                     f"{stats['far']} more outside the playable bounds\n")
            for f in finds:
                extra = {k: v for k, v in f.items() if k not in ("id", "kind", "at", "detail")}
                fh.write(f"{f['id']} {f['kind']:<12} {f['at']} {f['detail']} {extra}\n")
        with open(os.path.join(out_dir, f"eyes_{venue}.txt"), "w", encoding="utf-8", newline="\n") as fh:
            for f in finds:
                fh.write(f"{f['id']} {eye_for(f)}\n")
        print(f"[finds] {venue}: {counts} ({time.time() - started:.1f}s)")


if __name__ == "__main__":
    main()
