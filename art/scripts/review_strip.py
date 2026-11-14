"""The spacing strip (Tool 2 of docs/handoff/animation-cutscene-plan-2026-11-13.md): one row of an actor's frames, 0.05 s
apart over a window of a shot, each as the shot's own camera sees it, the body flat black on white, saved as one image
(background Blender):

    blender -b --factory-startup --python art/scripts/review_strip.py -- Shot actor t0 t1 out.png [--step=0.05]
        [--height=220] [--cols=0] [--fixed]

    blender -b --factory-startup --python art/scripts/review_strip.py -- RoleMuerto self 5.1 6.6 strip.png

`actor` is the slot the shot's actors go by ("self", "butler"...). Several groups of five (Shot actor t0 t1 out.png)
make several images in one run: the shots take about two minutes to load (the emote kit builds every emote when a
role scene imports it), so ask for all the strips you want at once.

Even spacing between frames is the stiffness the owner sees, and a weak silhouette shows at the same glance: a snap
is a few frames far apart and then frames piled on one another (a hold); a glide is the same gap all along. Under each
frame its time and a bar for how far the body travelled since the frame before (the window's biggest is full height).
Grey is what the lens does not show (past the frame, under the letterbox); a red edge on a frame is a cut.
--cols=N wraps the row after N frames (a long window); --fixed holds the camera as it is at t0 (the body's spacing
without the camera's own move); --height is a frame's height in pixels.

This reads the shot module's own acting (as --lint and --clear do), not the clips saved in Animations.blend, so
nothing needs rebuilding first. The body is the six R6 boxes: no hair, no prop, no set in front of it."""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from cinema import shot as shotlib  # noqa: E402
from cinema import silhouette  # noqa: E402


def main():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    options = [a for a in argv if a.startswith("--")]
    groups = [a for a in argv if not a.startswith("--")]
    step, height, cols, fixed = 0.05, 220, 0, False
    for a in options:
        if a.startswith("--step="):
            step = float(a.split("=")[1])
        elif a.startswith("--height="):
            height = int(a.split("=")[1])
        elif a.startswith("--cols="):
            cols = int(a.split("=")[1])
        elif a == "--fixed":
            fixed = True
        else:
            raise SystemExit(f"[strip] unknown option {a}")
    if not groups or len(groups) % 5:
        raise SystemExit("[strip] usage: -- Shot actor t0 t1 out.png [Shot actor t0 t1 out.png ...] "
                         "[--step=0.05] [--height=220] [--cols=0] [--fixed]")
    import cinema.shots  # noqa: F401  (each module defines its shots)

    shots = shotlib.SHOTS
    for name, slot, t0, t1, out in (groups[i : i + 5] for i in range(0, len(groups), 5)):
        if name not in shots:
            raise SystemExit(f"[strip] no shot {name}; they are: {', '.join(sorted(shots))}")
        shot = shots[name]
        slots = [a.slot for a in shot.actors]
        if slot not in slots:
            raise SystemExit(f"[strip] {name} has no actor {slot}; its actors are: {', '.join(slots)}")
        info = silhouette.strip(shot, slot, float(t0), float(t1), out, step=step, height=height, cols=cols, fixed=fixed)
        w, h = info["image"]
        print(f"[strip] {name} {slot} {float(t0):g}-{float(t1):g}s: {info['frames']} frames of {info['tile'][0]}x{info['tile'][1]}"
              f" -> {out} ({w}x{h})")
        if info["cuts"]:
            print(f"[strip]   the camera cuts at {', '.join(f'{c:g}s' for c in info['cuts'])} (a red edge)")
        print(f"[strip]   biggest step {info['biggest_step_px']} px (at {info['at']:g}s); {info['still_frames']} frames "
              f"nearly still, {info['moving_frames']} moving")


main()
