---
name: win-cutscenes-redo-2026-11-24
description: 2026-11-24 the eight win cutscenes put through the animation workflow (item 12 of the 2026-11-16 list): what was weak in the pictures although Tool 1 passed, what changed, where the pieces are, the preview recipe (review_win --room --build --every), and what is still unseen in the game
metadata:
  type: reference
---

The owner: "redo the win cutscenes with the workflow". All eight already passed `check_motion.py` (2026-11-15), so the
numbers could not say what was wrong; the pictures did. Judged from `review_win.py` boards (every 0.5 s through the
active shot, in the real room):

- **Faults found**: the actor out of frame (finalPage's first 3.3 s were from above-behind: a black back; caseClosed had
  no actor in frame for 4.4 s); every ending from behind (a blank R6 head: finalPage, finalPageBureau) or a head-on bust
  hiding the held book (newWorldBureau); a 36-stud top-down where the star was a dot (checkmate); lenses of 32-36 deg at
  5 studs = 2.5 studs of frame, filled with an arm (caseClosed, caseClosedCoven; a whole crouched R6 needs ~5 studs);
  a 0.45 s shot with no impact (newWorldBureau); the burning page held across the face (finalPageBureau); the free
  arm dead for 4-8 s (caseClosed 8.0 s, checkmateCoven 5.2 s, finalPage 4.8 s); no key/rim light on the actor.
- **Where things are**: the star's clip is `art/scripts/emotes/wins.py` (the OLD one is `wins_old.py`, unimported, kept);
  the cameras (`shots`), lights (`parts` with `alpha = 1` and a `light`: KeyCold/RimWarm/RimBack/KeyFront/KeyFace/
  FillPress), events and sounds are data in `src/shared/Cinema/WinCuts.luau` (camera work needs no Blender build).
  The per-win reference notes (sentence, the one big action, beats, what was watched) are
  `art/refs/cinema/Win<Name>.toml`.
- **Preview recipe** (no Studio): `blender -b --factory-startup --python art/scripts/review_win.py -- <cut keys>
  --size=640 --room --build --every=0.5` writes `art/export/previews/wins/<cut>_room/board.png` (16 frames a cut; the folder is gitignored, so the boards are local: regenerate them). The
  cut keys are WinCuts' keys (`finalPage`, not `winFinalPage`). `--room` is the truth (the stand-in parts differ from
  the room); `--build` builds the clip in memory from `emotes/wins.py`, so a pose change shows in 20 s; the events
  (a thrown file, a shattering king, fire, candles) are NOT drawn, so a held prop stays in the hand in the picture.
- **Commit recipe for the clips**: `run_anims.py -- --add winA,winB,...` (3 min for all eight) re-exports every clip in
  the blend, including orphaned actions (paradeMarch, notMyProblem) and a differently split Part10/11, so take only the
  eight `win...` blocks into HEAD's `Part10.luau` (all eight sit in Part 10; lengths are 8 s so Index.luau stays) and
  `git checkout` Part3/4/5/11 and Index.
- **Traps seen**: a right arm reached forward at chest height sends the held Grimoire out sideways like a plank (hold
  the book up beside the head: `J((128, 0, 14))`); a camera at the table's height between two candles looks at a candle's
  flame (check `parts` x/z before placing a low lens); a bowed writer (root + neck pitch -36) is only a top of head from
  the front, keep it near -26.
- **Numbers (check_motion, all eight PASS before and after)**: dead limb finalPage 4.8 s -> 2.6 s, caseClosed 8.0 s ->
  4.2 s, checkmate 3.4 s -> 2.2 s, checkmateCoven 5.2 s -> 2.8 s; end holds (arm joints within 6 degrees of the last
  pose) 1.53 to 2.17 s. Acting changed in six clips, cameras and lights in seven cuts (checkmateCoven's cameras were
  left alone).
- **Not seen**: any of it in the game (Studio was another session's); the preview mannequin has no face texture, no
  hair and none of the events. Owed: a script sync, then play each cut from the Debug cutscene gallery.
