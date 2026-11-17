---
name: griddy-one-leg-hop
description: Griddy rebuilt 2026-11-16 as a one-leg hop with both arms thrown up every 2 s (emotes/griddy.py); how a stroll's cycle clip can be a 4-hop bar, what the game does with it, how to iterate in 7 seconds, and the shared-browser trap
metadata:
  type: project
---

The owner (2026-11-16): "rework griddy to be more accurate (bouncing on one leg, hands thrown up every 2 seconds)".
`art/scripts/emotes/griddy.py` builds both clips from one `Motion` (the bar, 2.0 s, four hops of 0.5 s, the throw on the
fourth): `griddy` standing, `griddyWalk` the same bar as a cycle. The first build (mocap of Justin Jefferson, heel taps)
is kept unimported in `emotes/griddy_mocap.py`; strolls.py imports the new module.

**How a stroll cycle can be longer than a step.** The game plays a stroll's walk by the ground covered:
`phase += covered / clip.stride`, so a clip may hold four hops (stride 18 studs at 4.5 a hop; the stroll's pace of 9
makes it two seconds). Its `stance` must be the part of the cycle a foot is down (hop stance / 4), since the game
derives the studs over a planted foot from `stride * stance` and warps leg time with it (identity when the stroll is the
only cycle playing, so the left leg is baked at the same phase as the right). `LocomotionController` fires `Footfall`
(the dust in EmoteFx) at phase 0 and 0.5 only: here that is hops 1 and 3 of 4, not every landing.

**Fast loop** (7 s, not the 2 minutes of run_anims.py): a Blender script that opens Animations.blend, loads
`emotes/griddy.py` BY FILE PATH (importing the `emotes` package would build all 68 emotes), builds the two actions,
exports just those two with `export_anims.sample_action/clip_lua`, writes a scratch .luau and runs
`check_anims.check_clip` on it; `check_motion` can read it by patching `rbxsim.load_clips`; `review_emote.py` can draw it
with `common.BLEND` pointed at a scratch folder holding the saved copy of the blend.

**Splice, do not commit run_anims output**: the whole library is rewritten with drift; take only the two clips' blocks
from the exported part file, `git checkout` the Clips folder and Animations.blend, put the blocks into HEAD's part file
and set their Index.luau lines.

**Trap: the built-in browser pane is shared with other sessions.** Twice a page navigated away in the middle of a
script ("page navigated while this script was running", a lightning video). Open your own tab (`tabs_create`) and pass its
`tabId` to every call.
