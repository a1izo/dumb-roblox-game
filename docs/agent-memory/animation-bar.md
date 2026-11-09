---
name: animation-bar
description: The animation quality bar (2026-11-09, from JJS / A Bizarre Run frames, the user's "look made by a human, not choppy and stiff"): measurable traits to check every clip against, and the two engine causes of stiffness found
---

The user (2026-11-09): "make sure they look made by a human and not choppy and stiff", inspired by popular Roblox games
with distinctive animation (A Bizarre Run, Jujutsu Shenanigans, TSB). Seen frame by frame (JJS domain showcase, 0.1 s
steps):

- **Impacts snap, then hold**: the body reaches an impact or landing pose in 1-2 frames (0.03-0.07 s), then holds it
  0.4-1.2 s with a small settle (a few degrees sinking), never a slow slide into it. Landings are deep and asymmetric:
  one knee down, a hand on the floor, the head up.
- **Anticipation is short and opposite**: 0.1-0.3 s back the other way before a big move.
- **Spacing is uneven**: fast out of a pose, slow into the next (ease-out heavy); no constant-speed glides.
- **Asymmetry everywhere**: contrapposto stances, one arm working while the other rests, head tilted; never mirrored
  arms on a held pose.
- **Moving holds**: a held pose still breathes (1-3 degrees), the head glances; nothing frozen for over a second unless
  the story freezes it (and then it holds DEAD still, on purpose, not jittering).
- **Overlap**: head and arms trail the torso by 2-4 frames on a turn or stop and settle past it a little.
- **No noise as acting**: tremors are rare, short, and decay; steady 7-14 Hz shakes read as a glitch, not a feeling.
  Repeated beats vary in size and timing (never a metronome of identical staggers).
- **Big transitions are covered**: a flash, a smear or a cut hides the jump between two very different poses.

Engine causes found 2026-11-09 (fixed the same day):
1. `ClipPlayer` interpolated between exported keys in straight lines, and `export_anims.py` thins keys with
   Douglas-Peucker at 0.6 degrees: every slow move became a polyline with velocity kinks at each kept key. It now
   plays them on a monotone cubic (Fritsch-Carlson, like motion.py's "smooth"), so curves stay curves and holds and
   snaps stay exact.
2. Moves under 0.6 degrees are thinned away entirely: a baked `alive(amount=0.35)` breath leaves the arms frozen for
   the whole clip (sceneRequiemKiller's arms had two identical keys over 16.5 s). Small life belongs to the runtime
   `Anim/Life` layer (DGLife), not to baked micro-motion.

Related: [[cutscene-quality-bar]], [[cutscene-life-layer]], [[cutscene-pipeline]].
