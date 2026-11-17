# Animation and cutscene plan: from stiff to cinematic

Written 2026-11-13 for another agent to carry out. The owner's words: "everything besides the muerto intro cutscene
and maybe the diavolo one feels very low quality blocky stiff not cinematic and generally sloppy". The order the
owner set:

1. The base scenes every match shows: map intros, role intros, the meeting intro.
2. Deaths: their animations, their cutscenes and their effects.
3. Winning cutscenes.
4. Emotes, then base movement.

Do the stages in that order. Inside a stage, do one scene at a time, each as one commit, each shown to the owner
before the next is started.

This file is long because fourteen rounds of rework on these scenes already happened and most were rejected. The
reasons are known. Read all of it once before touching a clip.

## Status (2026-11-14, written when the first batch landed on main)

Read this before picking up work. Stage order and the owner's gates are unchanged.

- **Stage 0 is done and on main.** Tool 1 `art/scripts/check_motion.py`, Tool 2 `art/scripts/review_strip.py`,
  Tool 3 the `[shape]` notes in `run_cinema.py --lint`. Their numbers and how to run them are under Part 2.
- **Stage 1a, the RoleAce pilot, is rebuilt and on main** (`art/scripts/cinema/shots/role_ace.py`; the old `role_l.py`
  is kept and no longer imported; reference `art/refs/cinema/RoleAce.toml`). Both clips pass the motion report. The owner
  has seen it play in the game and called it "meh": it works, but the Butler's walk animation is off, **the cutscene does
  not exit**, and the final camera pan is awkward ("second hand embarrassment"). That is the first miss at the owner's
  gate (the plan allows two): the pilot is fixed on those three points first, and 1b to 1f wait for the second verdict.
  Known faults listed in the pilot's report: the cup tips a little on its saucer at the sip, one cup stays on the
  Butler's tray after Ace lifts his, Ace's face is mostly hair in cut 2 and during the tea, the near arm is a large dark
  block in some frames, and `--lint` still prints `[frame]` notes on the close cuts.
- **Inventory for stages 2 to 4:** [animation-inventory-stages-2-4-2026-11-14.md](animation-inventory-stages-2-4-2026-11-14.md).
  The plan's death list below is out of date (see its section 0); work from the inventory. Nothing there was watched in
  the game yet.
- **Audit of the Luau-built match scenes (1i):** [animation-audit-match-scenes-2026-11-14.md](animation-audit-match-scenes-2026-11-14.md).
  Its biggest find: the Manual's writing shot is black under the game's normal colour grade. Fix that before the
  Manual's pacing or framing.
- **The owner's answers, 2026-11-14.**
  - **1g IntroCampus:** yes, re-act poses, cameras and light, with the same cuts and the same lengths.
  - **1h RoleDiavolo:** what bothers them is how stale the camera is in every shot that is not a camera-POV shot, how
    Ryuk (the Specter) appears, and how stiff he is (they guess he is not rigged). The same goes for the Oculus deal
    (`EyesDeal.luau`). Nothing else in the scene is complained about, so the story and the cuts stay.
  - **The Manual's black writing shot:** fix it now (a task of its own).
  - **Stage 2:** later. Do not start it.
- After merging the pilot, `art/blend/Animations.blend` was kept from main and `run_anims.py -- --add
  RoleAce_self,RoleAce_butler` was re-run, as the rules below say; the exports came out byte-identical.

## Read these first

- `docs/agent-memory/cutscene-pipeline.md`: the loop, the tools and the commands. The method here builds on it.
- `docs/agent-memory/cutscene-quality-bar.md`: all fourteen rounds of the owner's feedback. Every mistake in it
  was made once already.
- `docs/agent-memory/animation-bar.md`: the measurable traits of animation that looks made by a person.
- `docs/agent-memory/cutscene-footwork.md` and `cutscene-life-layer.md`: feet and breath are already handled at
  run time. Do not bake them again.
- `docs/agent-memory/deaths-2026-11.md`, `deaths-batch2.md`, `scene-death-sets.md`: how deaths are built.
- `docs/agent-memory/studio-cutscene-testing.md` and `debug-cutscene-gallery.md`: how to watch a scene in the game.
- `docs/animation.md` and `docs/emotes.md`: the movement set and the emote system.
- `docs/agent-memory/protect-user-assets-edits.md` and `owner-rejected-changes.md`.

# Part 1: why two scenes work and the rest do not

The owner likes RoleMuerto and, less surely, RoleDiavolo. Counting what each shot module does shows the gap is
method, not talent. (Rough counts of calls in `art/scripts/cinema/shots/*.py` on 2026-11-13.)

| Scene | Module | Length | Reference file | Moving cameras (pan, dolly) | Locked camera keys | Effect events | Hands put on targets |
|---|---|---|---|---|---|---|---|
| RoleMuerto | role_follower.py | 18.0 | yes | 7 | 0 | 12 | 13 |
| RoleDiavolo | role_kira.py | 19.6 | yes | 5 | 5 | 19 | 5 |
| RoleAce | role_l.py | 17.5 | no | 2 | 6 | 3 | 2 |
| RoleOperative | role_taskforce.py | 19.0 | no | 0 | 8 | 5 | 0 |
| RoleButler | role_watari.py | 15.0 | no | 0 | 8 | 3 | 11 |
| MeetingIntro | meeting_intro.py | 6.0 | no | 0 | 8 | 2 | 0 |
| IntroAgency | intro_agency.py | about 25 | yes | 4 | 3 | 19 | 9 |
| IntroCampus | intro_campus.py | about 25 | yes | 9 | 2 | 16 | 3 |
| IntroTokyo | intro_tokyo.py | about 26 | yes | 7 | 8 | 21 | 0 |

What the two good scenes have that the others lack:

1. **A real scene was watched first.** Each has `art/refs/cinema/<Shot>.toml` with the source, the times watched
   and the key poses written down frame by frame. The three weak role scenes and the meeting intro have no
   reference file. They were acted from imagination.
2. **They were rebuilt from nothing**, not patched. Polishing the earlier versions was tried and called "still
   suck" (round 9).
3. **One person does one big physical thing that escalates.** Muerto writes, then slashes, faster and faster, then
   throws himself back. The whole body is in every move. The weak scenes are made of small polite gestures: a sip,
   a bow, a glance.
4. **The camera is an operator.** Every shot moves and breathes (`shot.pan(operator=True)`, `framing.dolly`). The
   weak scenes are pairs of locked `shot.cam` keys: a tripod that slides a little.
5. **Every hand is on a target** (`body_reach`), checked by number. The Operative's scene has none.
6. **Effects land on the acting's beats**: a slash across the screen on each stroke, a red wash, a still. Twelve to
   nineteen events against two to five.
7. **The set was built for the scene** from the same source (the flat with its red desk and glass wall).

So the plan is not "polish everything". It is: give every scene the Muerto treatment, with measurement added so
nobody has to trust their own eye.

## Why "blocky" and "stiff", on an R6 body

R6 is six rigid boxes. It has no elbows, knees, fingers or face. On such a body, quality comes from only five
things. Every scene must use all five.

- **The torso acts, the limbs follow.** Emotion on an R6 body is the root: how far it leans, twists, sinks and
  rises, and how fast. A scene where the torso stays upright and only the arms move will always look like a toy.
  Lean further than feels safe: 15 to 35 degrees is normal in the Muerto scene.
- **Limbs slide as well as turn.** The approved style (2026-10-07) lets joints translate (`animlib.J`) so a
  shoulder can rise, an arm can reach longer, a leg can tuck up into the hip. This is the only way to fake an
  elbow or a knee. Use it on every reach and every crouch.
- **Silhouette.** The pose must read as a black shape from the shot's own camera: arms clear of the torso, the
  head clear of the shoulders, never both arms doing the same thing.
- **Timing.** Snap into a pose in 1 to 2 frames, hold it 0.4 to 1.2 seconds, anticipate the other way for 0.1 to
  0.3 seconds first, overshoot and settle. Even spacing is what "stiff" means.
- **Everything around the body.** Camera movement, lens, light on the actor, effects on the beat, sound. A blocky
  body in a well shot, well lit, well cut frame reads as style. The same body in a flat locked wide reads as cheap.

## What "sloppy" has meant so far

Each of these was seen by the owner in the game after the Blender preview looked fine. Treat the list as a
checklist for every scene, run in the game, not in Blender.

- Bodies or hands inside props, walls or each other. The Blender check sees desks as a top slab and misses lamps,
  monitors and rail glass.
- A hand that stops short of the thing it reaches for, or a held prop that jumps when the hand closes.
- Feet sliding, or a body gliding with standing legs.
- A close-up that is all hair, or a face bowed out of sight, or a head cut by the letterbox.
- A camera aimed at where the actor was meant to be, not where they are.
- A prop that appears from nowhere.
- Background people doing the same clip in step, or looping two poses like a metronome.
- A scene that opens on black for most of a second while the engine lights the place.
- Cuts shorter than 1.5 seconds that nobody can read.
- A pop where one clip hands over to another.

## The owner's taste, in one place

- No drawn faces: players wear their own avatars. No glowing eye blocks.
- No heavy blur. A global depth of field was deleted at the owner's word. Light focus only. A little motion blur
  on fast moves is liked.
- Long readable cuts, 1.5 to 3 seconds and more. Show cause, then effect.
- Mystery and unease: slow steady cameras, creeping zooms onto faces, quiet everyday business, reactions that go
  still and turn slowly. Crash zooms, punch-ins and gag timing were called "too comical".
- Violence: strikes, snaps, impact frames, dutch angles on the villain.
- "Uninspired" means replace the effect with a better one, not remove it.
- "Fine but boring" does not mean restructure. A re-paced Campus intro was called "ruined" and reverted.
- Only the match's players in intros, twelve at most, no crowd extras.
- Scene deaths copy their source one for one.
- Rating ceiling is Moderate. No gore. No depiction of suicide.
- Never re-add what the owner removed (`owner-rejected-changes.md`).

# Part 2: tools to build before any scene (stage 0)

Three small tools. They exist so that "is this stiff" has a number and a picture, and so a cheaper model cannot
talk itself into "looks good". Build them first, in this order, one commit each.

## Tool 1: the motion report

`art/scripts/check_motion.py`, run with Blender's Python like `check_anims.py`. It reads exported clips and prints,
per clip and per actor, the traits in `animation-bar.md` as numbers:

- **Frozen**: the longest span in which no joint of the upper body moves more than 0.6 degrees. Report it and
  which joints. (The life layer covers breath at run time, so only flag spans over 2.5 seconds where the story
  does not freeze the body.)
- **Glides**: spans over 0.4 seconds where a joint or the root turns or travels at a speed that varies by less
  than 15 percent. Constant speed is the stiffness the owner sees.
- **Snap and hold**: for each big move (over 40 degrees or 1.5 studs), the time it takes and the hold after it.
  Flag a big move that takes over 0.35 seconds with no hold after.
- **Anticipation**: whether the 0.3 seconds before a big move goes the opposite way at all.
- **Overshoot**: whether a big move passes its rest pose and comes back.
- **Symmetry**: held poses where the two arms are within 8 degrees of mirror images.
- **Torso share**: of all the motion in the clip, the share that is the torso and root. Under about a fifth
  means only the limbs are acting.
- **Metronome**: repeated moves of the same size at the same interval, three or more times.
- **Overlap**: on a turn or stop of the torso, whether the head and arms arrive 2 to 4 frames later.

**Calibrate it on the good scene.** Run it on RoleMuerto's clips and on RoleAce's. Set each threshold so Muerto
passes and Ace fails. If a trait does not separate them, drop it or fix how it is measured. Write the calibrated
numbers into this file under this section. From then on, a clip that fails the report is not done.

The report is a floor, not a judge. Passing it does not make a clip good. Failing it means it is not.

### Tool 1 as built and calibrated (2026-11-14)

Built: `art/scripts/check_motion.py`. Run it with Blender's Python (it only needs numpy and writes nothing):

```
"C:/Program Files/Blender Foundation/Blender 5.2/5.2/python/bin/python.exe" art/scripts/check_motion.py --shot RoleAce --detail
```

Pick clips by name (`RoleAce_self`), by cutscene (`--shot RoleAce`, or the bare name), `--all` (every cutscene),
`--emotes` (the 70), `--movement` (the 21 clips `check_anims.py` holds). `--lead` leaves out a cutscene's extras
(slots `everyone:N` and `extra:N`, which are only noted as `info`, never failing, unless `--strict-extras`).
`--detail` says where each fault is in seconds, `--worst N` ranks, `--table` prints a Markdown table, `--json PATH`
keeps every number, `--selftest` measures made-up clips with known answers. One line per clip: `PASS`, `FAIL` or
`info`, the nine numbers, the failing traits named after `<-`. Exit code 1 when a clip that counts fails, 2 for an
unknown name. It reads the committed exported keys (`src/shared/Cinema/Acting/<Shot>.luau`, `src/shared/Anim/Clips`)
and never opens `Animations.blend`: rebuild and export a clip first (`run_anims.py -- --add`, `run_cinema.py --
--export`) or it measures the old one. A clip the story keeps still is listed in `FREEZE_OK` in the script (today
only `RoleButler_ace`) or passed as `--frozen-ok`.

**What the calibration changed.** Of the plan's nine traits as first worded, only some tell Muerto from Ace, and
Muerto itself broke two of the plan's numbers. In the order of the plan:

| Trait | Muerto (must pass) | Ace self / butler (must fail) | Limit | Verdict on the trait |
|---|---|---|---|---|
| Frozen: whole upper body still | 0.6 s | 0.9 s / 1.3 s | over 2.5 s fails | Does not separate them (the neck always drifts, so the whole body is never still), kept as the plan's guard. |
| **Dead limb** (new, replaces the above as the test): one upper joint still | 3.7 s (left arm) | **17.5 s (left arm never moves)** / 6.2 s | over 8 s fails | Separates. Ace's left arm is dead the whole scene and its torso is still for 7.7 s. No emote is over 6 s. |
| Glides: constant-speed spans over 0.4 s | 0 | 0 / 0 | over 2.5 s in all fails | Does not separate (the game's cubic eases every move between held keys); kept as a guard, it catches RoleButler (2.7 s). |
| Snap and hold: big moves over 0.35 s with no hold | 2 of 44 | 0 of 4 / none | over 35% of 5 or more | Does not separate (Ace's arm moves are fast; its fault is what comes before and after). Guard. |
| Anticipation: big moves drawn back first | 18 of 44 (41%) | 1 of 4 / none | under 15% of 5 or more fails | Muerto passes; Ace has only 4 big moves, too few to judge. Fails a clip with 5 or more big moves and almost none drawn back (IntroTokyo_victim 1 of 8, the emote diceTower 0 of 12). |
| Overshoot: passes its rest pose and comes back | 1 of 44 | 2 of 4 / none | **not judged** | Dropped from the verdict. Muerto has almost none (its strokes flow into each other, they are not settled one by one), so no limit can make Muerto pass and Ace fail. Still printed. |
| Symmetry: held arms mirrored within 8 degrees | 100% of 0.6 s of holds | 0% of 14.2 s / **100% of 15.5 s** | over 50% of 2 s or more | Separates the butler. Muerto has under a second of held arms, so it is not judged. |
| **Torso share** | 15% | **1%** / 38% | under 4% fails (when the limbs turn over 100 degrees) | Separates. The plan guessed a fifth: Muerto itself is 15% and Diavolo 7%, so a fifth would fail the bar. Legs are left out (footwork plans them) and the body offset counts at 25 degrees a stud. |
| Metronome: same size, same interval, in a row | 4 (the torso, 7.9 to 9.8 s, 20 degrees every 0.45 s) | 0 / 0 | 5 or more fails | The plan said three; Muerto's own torso makes four, so five. By itself it does not separate. |
| **Same timing** (new): moves of one joint that take the same number of frames | 20 of 50 (40%) | **14 of 17 neck moves, all 0.18 s (82%)** / none | 6 or more and 60% fails | Separates. Ace's head turns have different sizes and gaps but one timing: that is the metronome the eye catches. |
| Overlap: head or arms arrive 2 to 12 frames after the torso | 32 of 33 | no torso turn at all / 2 of 2 | under 25% of 3 or more fails | Does not separate (Ace's torso never moves, so there is nothing to follow). Guard. |

Result: RoleMuerto_self **PASS**; RoleAce_self **FAIL** (dead limb, torso share, same timing); RoleAce_butler **FAIL**
(symmetry: both arms mirrored for all 15.5 s of held poses). Sanity on the owner's well-rated emotes: 63 of 70 pass;
the 7 that fail are diceTower (anticipation, metronome), finalBreakdown (metronome, same timing), justAsPlanned
(anticipation), preDawnBonk (anticipation, same timing), theLongClimb (torso), twoWeeksNotice (same timing) and wave
(torso: arms only, and its length is frozen). Movement set: 19 of 21 pass; `idle` (16.5 s) and `idleGuarded`
(23.1 s) fail dead limb, because the exported clip's shoulders never move more than 0.6 degrees.

The units: a move is a joint turning faster than 6 degrees a second, so the life layer's breath and glances never
count. Everything is measured on the played curve at 60 a second. Two measuring bugs the self-test caught while
building (a draw-back that swings the joint back past its start was missed, and the hold after an overshoot was
timed from the peak) are fixed; run `--selftest` after touching a measuring.

**Before numbers (2026-11-14, the clips as they stand).** `PASS`/`FAIL` as the report gives it. A sibling session
compares its after against these.

| Clip | Verdict | Frozen s | Dead limb s | Glides s | Slow/big | Wound up/big | Mirrored | Torso | Metronome / same timing | Overlap |
|---|---|---|---|---|---|---|---|---|---|---|
| RoleMuerto_self (the bar) | PASS | 0.6 | 3.7 left arm | 0.0 | 2/44 | 18/44 | 100% of 0.6 s | 15% | 4 / 20 of 50 | 32/33 |
| RoleAce_self | FAIL: dead limb, torso, same timing | 0.9 | 17.5 left arm | 0.0 | 0/4 | 1/4 | 0% of 14.2 s | 1% | 0 / 14 of 17 | 0/0 |
| RoleAce_butler | FAIL: symmetry | 1.3 | 6.2 left arm | 0.0 | 0/0 | 0/0 | 100% of 15.5 s | 38% | 0 / 0 of 0 | 2/2 |
| RoleDiavolo_self | PASS | 0.5 | 4.3 torso | 0.0 | 0/11 | 3/11 | 34% of 5.7 s | 7% | 0 / 3 of 14 | 2/4 |
| RoleOperative_self | PASS | 1.1 | 4.0 right arm | 0.0 | 0/4 | 2/4 | 30% of 10.8 s | 15% | 0 / 4 of 7 | 1/2 |
| RoleButler_self | FAIL: glides, symmetry | 0.4 | 1.5 right arm | 2.7 | 0/1 | 0/1 | 100% of 5.0 s | 19% | 0 / 3 of 8 | 4/5 |
| RoleButler_ace (still by design, in `FREEZE_OK`) | PASS | 3.4 | 10.0 right arm | 0.0 | 0/0 | 0/0 | 0% of 10.0 s | 24% | 0 / 0 of 0 | 0/0 |
| IntroAgency_watcher | PASS | 1.3 | 2.8 right arm | 0.0 | 0/0 | 0/0 | 9% of 10.7 s | 18% | 4 / 4 of 15 | 7/8 |
| IntroCampus_noticer | FAIL: frozen | 4.4 | 7.5 left arm | 0.0 | 0/0 | 0/0 | 0% of 12.2 s | 12% | 3 / 3 of 5 | 2/2 |
| IntroTokyo_victim | FAIL: frozen, dead limb, anticipation, symmetry | 3.3 | 12.1 right arm | 1.1 | 1/8 | 1/8 | 61% of 13.2 s | 23% | 0 / 3 of 12 | 11/12 |
| IntroTokyo_watcher | FAIL: dead limb | 1.4 | 17.3 left arm | 0.0 | 0/3 | 0/3 | 0% of 18.1 s | 5% | 0 / 2 of 7 | 0/0 |

MeetingIntro (12 clips, one per seat, 6.0 s): **10 of 12 FAIL**. Ten fail symmetry: both arms are mirror images for
the whole of their held poses (6 of the seats hold 6.0 s of it; 1.3 to 4.0 s for the others), and seats 8 and 9 are
also frozen for 2.5 and 2.6 s with the torso itself still. Only seats 4 and 5 pass. No seat has a big move, so
snap, anticipation and overshoot have nothing to judge. Torso share 23 to 39%, glides 0 to 0.5 s.

The extras of the three intros are only noted (`info`). IntroAgency (13 extras): 10 have a fault, mostly a dead arm
(8, up to 11.2 s) and mirrored held arms (7). IntroCampus (11 walkers): the 6 with a fault all have a torso under 4%
(the torso stays upright while they walk). IntroTokyo (12 extras): 8 have a fault, mostly mirrored held arms (7);
the two seated commuters never move an arm for the whole 24.6 s, and two of the waiting figures glide for 4 to 5 s.

How to read the other numbers: RoleOperative passes because the report only sees the clip, not the missing hand
targets and locked cameras that make it weak (Part 1). RoleDiavolo (the owner's "maybe") passes. Neither tells the
sessions to leave a scene alone: the report is a floor.

## Tool 2: the spacing strip

An option for `art/scripts/review_anims.py` (or a small new script): one row of frames at a fixed step of 0.05
seconds over a chosen window, from the shot's own camera, bodies drawn as flat black on white. Even spacing between
frames shows at a glance, and so does a weak silhouette. Use it on every big move.

**Built 2026-11-14** as a small new script, `art/scripts/review_strip.py` (the drawing and the geometry live in
`art/scripts/cinema/silhouette.py`, which Tool 3 shares). How to run it, from the repo root:

```
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python art/scripts/review_strip.py -- RoleMuerto self 5.2 6.8 art/export/previews/cinema/strips/RoleMuerto_self_slashes.png
```

The five arguments are the shot, the actor's slot (`self`, `butler`...), the window's start and end in shot seconds and
the output image. `--step=0.05` (the default), `--height=220` (a frame's height in pixels), `--cols=N` (wrap a long
window into rows of N frames) and `--fixed` (hold the camera as it is at the start, to see the body's spacing
without the camera's own move) are the options. Give several groups of five to make several strips in one run:
every shot module loads at start (about two minutes, the emote kit builds every emote when a role scene imports it).
`art/export/previews/cinema/` is gitignored, so strips written there stay out of commits.

- It reads the shot module's own acting (the keys, springs and extras of each actor's `Motion`, through the rig's
  forward kinematics, the same as `--lint` and `--clear`), not the clips saved in `Animations.blend`. Nothing has to
  be rebuilt first, and a strip never shows a stale clip.
- The body is the six R6 boxes (the head a 1.2 box) as flat black on white, in the shot's own camera at each frame, so
  a camera that moves or cuts inside the window shows in the frames. It has no hair, hat or prop, and no set between
  the lens and the body. Grey is what the lens does not show (past the frame's edge, under the letterbox); a red edge
  on a frame is a cut of the camera.
- Under each frame are its time and a bar for how far the body travelled on the screen since the frame before (the
  head, the torso and both hands; the window's biggest step is full height, but never less than 4 percent of a frame's height, so a hold
  stays flat). Read it like this: a run of bars of
  one height is a glide, the stiffness the owner sees; a tall bar followed by flat ones is a snap and a hold, as
  `animation-bar.md` wants. Frames piled on each other are slow, frames far apart are fast. Run it over every big move
  (from 0.3 s before it to 0.5 s after) before and after the timing step of the scene loop.

## Tool 3: the silhouette check

For each held pose in a shot, from that shot's camera at that time: project each arm and the head onto the screen
and measure how much of each lies inside the torso's outline. An arm more than 70 percent inside the torso is
hidden. Print the holds where both arms are hidden or where the head overlaps a raised arm. Add it to
`run_cinema.py --lint` as `[shape]` notes.

**Built 2026-11-14** in `art/scripts/cinema/silhouette.py` (shared with Tool 2), printed by `run_cinema.py --lint` as
`[shape]` lines, one per run of held moments, after the `[lint]` and `[frame]` ones. How to run it, from the repo root:

```
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python art/scripts/run_cinema.py -- --lint RoleAce
```

```
[shape] RoleAce  0.00- 3.10s self: the head is overlapped by the raised right arm (32% of the head) (drawn as a black silhouette)
[shape] RoleAce  8.40- 9.40s self: the head is overlapped by the raised right arm (77% of the head)
```

What it does, and the numbers (constants at the top of `silhouette.py`):

- **A held pose** is a moment at which the body rests: the middle of the head, both hands, both arms' middles and the
  torso's four corners (in the actor's own frame, so a walk across the room does not count as moving) travel less than
  0.25 studs over the 0.15 s either side of it. That is the shot's key poses as the eye sees them, wherever the module
  keyed them (`key()`, `beat()`, `hold()` and the springs all end up as the same sampled pose). The module's own
  `Motion` is sampled every 0.05 s with its springs and extras, through the rig, as `--lint` and `--clear` do; no
  clip in `Animations.blend` is read. The shape is measured at every 0.1 s of a hold, and moments that run together
  become one line with their average.
- **Which actors:** any actor with a `Motion` in the module whose torso is at least 0.2 frame heights tall on the
  screen (a tenth of the frame) with its middle inside the visible frame, from the shot's camera at that moment.
  Bodies too small to read are skipped.
- **The outline** of each part is the convex hull of its box's eight corners through the lens (the head a 1.2 box),
  and the share of a part that lies inside another is the exact overlap of the two hulls.
- **Both arms hidden:** each arm has more than 70 percent of its outline inside the torso's. From the front, arms
  hanging at the sides share 7 percent with the torso; from the side, 83 to 100 percent.
- **Head overlaps a raised arm:** a hand at least 0.5 studs above its own shoulder joint, and that arm covers more than
  40 percent of the head's outline. (An arm level with the shoulder, a tray carried out, is not raised.)
- **A black silhouette** (an actor with `silhouette=` windows, such as Ace's first 3.2 s): the shape is all there is,
  so the lines are 50 percent and 20 percent there, and the note says so.
- **To clear a note:** move the raised arm out from the head (beside it, not in front), or change the camera angle
  at that hold. `run_cinema.py -- --preview <Shot> --stills=t` at the time of the note shows it, and
  Tool 2's strip over the hold shows it in the shot's own frames.

**Calibration, 2026-11-14** (first rule: a hand at shoulder height, 20 percent of the head: RoleMuerto had 7 notes,
the writing poses, the wind-up and the laughing, which is how the scene is meant to look, so the rule was the fault,
not the scene):

| Shot | Notes | What they are |
|---|---|---|
| RoleMuerto (the good scene) | 1 | 5.2 to 5.3 s: the wind-up before the first slash, the fist up in front of the face (73 percent) |
| RoleDiavolo | 0 | |
| RoleAce (the weak scene) | 2 | 0 to 3.1 s: the hand at the lip against the head as a black silhouette; 8.4 to 9.4 s: the hand to the cup covers the head from the two-shot |
| RoleButler | 1 | the silhouetted Ace actor, borderline at 20 percent |
| RoleOperative | 0 | |
| MeetingIntro | 2 | two seated players with both arms in the lap hidden from the front |
| IntroAgency | 5 | hands at faces in the crowd |
| IntroTokyo, IntroCampus | 0 | |

Like Tool 1, it is a floor and not a judge: the weak scenes' faults are mostly timing and cameras, which the notes do
not see. It says whether the held shape of the body reads. A clip with a `[shape]` note it did not mean is not done.

## One experiment to offer the owner: smears

Fast moves on rigid boxes strobe. The games the owner named (Jujutsu Shenanigans, A Bizarre Run) cover 1 to 2
frame moves with a smear: a stretched ghost of the limb along its path for two frames. `DeathScreen` already has
afterimage ghosts. Try a generic version in `ShotPlayer` as an event (`smear`, a part, a duration) on one strike
in the pilot scene and show the owner with and without. Keep it only on the owner's yes, and only for violence.

# Part 3: the scene loop

Every scene in every stage goes through these steps in order. Do not skip one. Each step has a gate: a thing that
must be true before the next step starts.

**1. Watch the scene as it is, in the game.** Play it through the debug cue at full speed, then at
`ShotRate` 0.25. Write down every item from the "sloppy" checklist you see, with its time. Run the motion report
on its clips. Save both lists: they are the "before".
*Gate: a written list of faults with times, and the report's numbers.*

**2. Decide what the scene is about, in one sentence.** Who wants what, and what changes by the end. Then name the
one big physical action that carries it. If you cannot name one, the scene has none and that is its real fault.
*Gate: the sentence and the action, written at the top of the reference file.*

**3. Find and watch a reference.** A real filmed or animated scene that does this action well. Watch it in the
built-in browser frame by frame (the contact sheet method in `cutscene-pipeline.md`). Write
`art/refs/cinema/<Shot>.toml`: source, times watched, eight or more beats each with the source time and the pose in
words (where the torso is, where each hand is, where the head looks), the cuts and their lengths, the lens feel
(close, wide, low, high, moving how). For a death, the reference notes go in `art/refs/deaths/`.
*Gate: the file exists with at least eight beats. No acting is written before this.*

**4. Block the key poses only.** Four to eight poses for the lead, each held, nothing in between. For each pose:
torso first (lean, turn, roll, sink), then the head, then each hand on a target with `body_reach`, then slide the
joints for length. Render each pose from its shot's camera and from a wide side view. Run the silhouette check.
*Gate: every key pose reads as a black shape, both arms differ, and the pose matches its reference beat.*

**5. Shoot it.** Before timing the motion, place the cameras on the key poses.

- One idea per shot. Decide what the viewer must look at, and put it on a third, not in the centre, with the
  letterbox in mind (11 percent top and bottom).
- Vary the lens on purpose: wide and low (fov 50 to 60) for place and power, long (fov 25 to 35) from further
  back for faces. A close-up at a wide fov distorts and shows only hair.
- Give depth: something in the foreground (a desk edge, a shoulder, a door frame), the actor in the middle, light
  or a window behind.
- Every camera moves for a reason: a creep in as tension rises, a pull back on a reveal, a follow on a walk, a
  hand-held drift on a person. Use `shot.pan(operator=True)` and `framing.dolly`. Locked frames only for in-world
  cameras.
- Keep to one side of the line between two people so they do not swap sides of the screen across a cut.
- Cut on an action, not between actions: start the move in one shot and finish it in the next.
- No two shots in a row from the same angle and size. No shot under 1.5 seconds unless it is an impact.
- Aim at the real head at that time (`framing.part`), after `footwork.apply`.
*Gate: a still from every shot, each with the subject readable and nothing blocking the lens.*

**6. Time it.** Now the in-betweens, following `animation-bar.md`: short opposite anticipation, fast out, slow in,
1 to 2 frame impacts, holds with a small settle, the head and arms arriving after the torso. Vary repeated beats in
size and timing. Leave breath and glances to the life layer.
*Gate: the motion report passes, and a spacing strip of each big move shows uneven spacing.*

**7. Light the actor.** Every shot of a person gets a key from one side and a rim from behind so the body
separates from the set (`StageLight`, the shot's lights in `run_cinema.py`). A face in a close shot is never the
darkest thing in frame. Follow the owner's bloom rule: skin never glows.
*Gate: in each still the actor's outline is clear against the background.*

**8. Effects and sound on the beats.** List the scene's three to six strongest beats. Each gets one effect from
the ShotPlayer set (focus, pulse, still, black, freeze, flash, shake, burst, slash, drain, materialize, cctv) or a
new one built for it, timed to the frame of the impact. Write a sound list for the same beats (a footstep, a chair
creak, a pen scratch, a sting). Sound ids live in `src/shared/Assets.luau`, which you must never stage or format:
give the list to the owner in your report.
*Gate: an event on each named beat, and the sound list written.*

**9. The checks.** `run_cinema.py -- <Shot> --clear` reads 0. `--lint` shows only intended notes. `check_sets.py`
is clean if the set changed. The acting file is under 200,000 characters. `run_anims.py -- --add` with the clips
comma-separated. Render `--preview` and look at a still from every cut.
*Gate: all clean.*

**10. Watch it in the game.** Export, sync, play it in a Studio play test at full speed and at 0.25. Go through
the "sloppy" checklist again. Blender has lied every time this step was skipped.
*Gate: none of the checklist's items seen. Anything seen goes back to the step that owns it.*

**11. Show the owner.** Before and after, the preview video's path, what the scene is now about, the reference
used, the report's numbers before and after, the sound list, what was not seen. Then stop and wait for the
owner's word on that scene before starting the next.

**Added 2026-11-15, after the pilot's first turn-down** ("meh": the Butler's walk off, the cutscene "not exiting", the final pan
awkward). The loop was missing three checks, so a scene could pass every gate and still read badly:

- **A walk check (steps 6 and 10).** Any actor who walks: sample the real walk in the game (recipe in
  `docs/agent-memory/studio-real-briefing-play-test.md`: root speed, the leg cycle, the torso, the tray) and compare with a
  reference. The motion report cannot see a walk that starts and stops dead or pivots after it; build walks with
  `role_ace.py: travel()` (eased up and down, the heading turned into the arrival) and a speed that fits the person.
- **An exit check (steps 9 and 10).** `run_cinema.py --lint` prints `[end]` notes (a last cut over 4.5 s, anything past the end,
  a line that overruns, someone still walking as the shot ends). And watch the REAL flow from the first frame to the role card
  (a forced role, a started match), not only the debug cue: camera, letterbox, effects and the HUD must all come back.
- **A closing-shot check (step 5).** The last cut needs a release, not a hold: let the look go, let someone leave, keep it short
  and still, cut to black for the card. A stare into the lens with the lens creeping in for seconds reads as embarrassment.
  Say in words what the closing shot does before shooting it.

**Rules for the loop.**

- **Rebuild or re-act, never polish.** For each scene the stage lists say which. "Rebuild" means a new module from
  an empty file with the old one kept until the owner approves. "Re-act" means the story, the cuts and the set stay
  and every pose and camera is redone through steps 4 to 10.
- **Do not touch RoleMuerto.** It is the bar. Open it, read it, copy its methods.
- **Never restructure a scene the owner liked** without asking. See each stage's list.
- **One scene, one commit, one report.** If a scene takes more than two attempts at the owner's gate, stop and ask
  what is wrong instead of trying a third guess.
- **A scene that is not better does not ship.** If the after is not clearly better than the before in the game,
  keep the old one and say so.

# Part 4: the stages

## Stage 1: the base scenes

Do them in this order. The first is a pilot.

**1a. RoleAce (the pilot). Rebuild.** It is the weakest by the numbers: three body keys in 17.5 seconds, six
locked camera keys, three effects, no reference. Its idea is good and should stay: the detective crouched in an
armchair before a wall of screens, eating sweets without looking, the tea brought in, and the spoken line. Study
how the source character sits, picks things up between finger and thumb, stacks and eats, and how those scenes are
shot (extreme low angles, the screens' glow as the only light, slow push-ins on a still figure). The physical
action to build on is the stillness broken by small precise, odd movements, then one sharp turn of the head to
the lens on the line's last words. This is a mystery scene: slow cameras, no strikes. Run the whole loop. Offer the
smear experiment on a different scene, not this one.

**Stop after the pilot.** Show the owner. If the owner does not call it clearly better, the method is wrong
somewhere: ask what still reads as stiff or cheap, fix the method in this file, and redo the pilot before going on.

**1b. RoleOperative. Rebuild.** No hand is placed on anything and all eight cameras are locked. Find the scene's
one action first (step 2). A locker room and a field agent suggest gearing up: each item taken, checked and put on
with weight, ending on the door. Find a reference for a gearing-up sequence and its cutting rhythm.

**1c. RoleButler. Rebuild.** The hands are placed (eleven reaches) but all eight cameras are locked and the acting
is polite. Study a real butler or tea service scene for the exactness of the hands and the stillness of the body,
and shoot it with inserts on the hands.

**1d. MeetingIntro. Rebuild, short.** Six seconds, eight locked keys, two effects. It is seen more often than any
other scene, so it must be the cleanest. People arriving at a war room: study a team-assembles sequence. It must
end with each player standing at their own seat (`seat:k` parts), so the meeting starts where the montage ends.
Keep it short enough to watch thirty times.

**1e. IntroAgency. Re-act.** Many rounds already. The owner's last words: good but stiff (round 12), the
cinematography needs work (round 13), then too comical instead of deep and mysterious (round 14). Keep the story.
Redo every pose and camera for unease: slow, steady, creeping, quiet business, reactions that go still.

**1f. IntroTokyo. Re-act.** Keep the story (the platform, the watcher with the Manual, the victim). It has no
placed hands at all and eight locked keys. Watch it in the game with a full cast before changing anything.

**1g. IntroCampus. Ask first.** The owner liked its structure and reverted a restructure. The verdict then was
"fine but a bit bland". Ask the owner: keep the cuts and re-act the poses, cameras and light, or leave it alone.
Default if no answer: re-act only, same cuts, same lengths.

**1h. RoleDiavolo. Ask first.** The owner said "maybe". Ask what, if anything, bothers them in it. Default: run
only steps 1, 9 and 10 (find sloppiness in the game and fix exactly that), and change nothing else.

**1i. The other match scenes, audit only.** The case opening (`Presenters/Intro.luau`), the verdict, the arrest,
the outro, the Oculus deal and the Manual's writing shot are built in Luau, not Blender. The owner did not name
them. Watch each once in the game, write a short list of what reads as cheap, and give the owner the list. Change
nothing in them without the owner's word.

## Stage 2: deaths

The inventory is written: [animation-inventory-stages-2-4-2026-11-14.md](animation-inventory-stages-2-4-2026-11-14.md)
(read its section 1.0 first: the 14 custom deaths, `deaths_scenes.py` and the five styles no longer exist; the three
collapses, the table cutscene and 15 scene deaths are what is left). For each item there: watch it in the game through
the debug gallery (Show tab), run the motion report, and confirm or change its mark (good, re-act or rebuild).

Then, worst first:

1. **The three cause collapses** (`collapseAccident`, `collapseDisease`, `collapseHeart`). Every player sees these
   most. A collapse goes lean, torso drops, legs give, fall, as one move with gravity (`deathkit.rod_fall`), the
   leading arm going down first, a hard stop on the floor in 1 to 2 frames, one small bounce or settle, then dead
   still (the life layer already stops for a body lying down). Find film reference for each cause: they must look
   different from each other in the first half second.
2. **The death at the table.** It is a cutscene: the Manual, the name, the cut to the victim on the first beat,
   the others' reactions. Check the cut lands on the death's first frame, the camera follows the fall to where the
   body will lie (`DeathTiming`), and the reactions are not all the same clip.
3. **The 14 custom deaths**, worst first by the report.
4. **The scene re-enactments and scene deaths.** The owner's rule: one for one with the source. Put the source's
   frame sheet beside ours, beat by beat, and list every difference in pose, timing, framing and effect. Fix the
   differences. Do not invent.
5. **The five styles** (ash, strings, crows, stone, glass), each in both lying poses.
6. **Effects** (`Presentation/DeathVfx`, `CustomDeaths`, `DeathFx`, `DeathScreen`, `docs/vfx.md`). For each death,
   check the effect starts on the clip's `fx` beat to the frame, has a beginning, a peak and a decay (not a
   constant emitter switched on and off), lights the body and the floor near it, and leaves something behind for a
   moment (a mark, drifting ash, a last ember). Replace any effect that is one emitter and a flash.

Known traps: root angles lean in the mark's frame (`deathkit.turned`), dressing must be behind the star not behind
the cameras, a scene played from its start opens on black for about 0.75 seconds while the engine lights the place
(open from black on purpose, or pre-warm the place before the first frame).

## Stage 3: winning cutscenes

Eight in `src/shared/Cinema/WinCuts.luau`, written by `art/scripts/emotes/wins.py`: finalPage, newWorld,
caseClosed, checkmate, and their Bureau and Coven versions. They are sold in the shop and shown to the whole
server at the end, so each must feel like a prize.

For each: the loop, with these differences. A win scene is about one person's triumph, so it is built like the
Muerto scene: one actor, one escalating action, an ending pose that holds for at least 1.5 seconds as the winning
side's name is written in. The ending pose must work as a still picture. The versions that share a base (Bureau,
Coven) may share staging but each needs at least its own ending pose, its own grade and its own effect. Use
`art/scripts/review_win.py` for sheets and the debug gallery to watch them anywhere.

## Stage 4: emotes, then base movement

**Emotes.** There are 70 (`docs/emotes.md`, `art/refs/emotes/*.toml`). On 2026-10-27 the owner rated these far
above the cutscene acting, and their method (a reference video per clip, poses copied off frames, hands on
targets) is where the cutscene method came from. So do not redo them. Run the motion report over all 70, render a
sheet of each, and watch the worst fifteen by the report in the game. Re-act only those that fail the report and
look wrong in the game. The first five (Wave, Point, Cheer, Laugh, Dance) copy Roblox's classic emotes and their
lengths are frozen because other scenes reuse them: do not change their lengths.

**Base movement.** `docs/animation.md` describes the set and its controller (`LocomotionController`, rebuilt
2026-10-14). The style the owner approved is "fluid R6 where limbs slide as well as turn", serious, slouched walk,
driven run. Do not change the style. Look for stiffness in this order, in the game, from the game's own camera
(behind the player, up to 18 studs back), at full speed and slowed:

1. The handovers: idle to walk, walk to run, run to stop, direction changes, take-off, landing. Pops and slides
   live in the handovers, not in the cycles.
2. The run and walk from behind: does the torso twist and the shoulders counter the hips enough to read at 18
   studs. Does the head stay steady.
3. The idles and fidgets: twelve people standing in a meeting must not move in step, and no idle may read as a
   loop.
4. Strafes and backward cycles, which are seen less and were likely checked least.
5. Turning on the spot.

Fix what is seen. `check_anims.py` must keep passing (no sliding soles, nothing through the floor, clean seams).
Then run the motion report over the set for anything the eye missed.

# Part 5: working rules

- **Commands.** As in `cutscene-pipeline.md` and `docs/animation.md`. Clip names to `run_anims.py -- --add` are
  comma-separated: space-separated names build only the first, silently.
- **The 200,000 character limit.** Roblox refuses a bigger script. Check each acting file's size after every
  rebuild. Delete a rebuilt scene's old actions from `art/blend/Animations.blend` or they stay in the file.
- **Never stylua** `src/shared/Cinema/Acting/` or `Shots/`, or any generated data.
- **Never stage** `src/shared/Assets.luau` or `art/rig`. Commit with
  `git add -A -- . ':!src/shared/Assets.luau' ':!art/rig'` only when the whole working tree is yours. On
  2026-11-13 other agents had uncommitted work in the tree (map shading files): in that case add your own files by
  name.
- **`Animations.blend` conflicts.** Take theirs and re-run `run_anims.py -- --add` for your clips.
- **Other agents push to main all day.** Fetch and merge before every push. Check for `MERGE_HEAD` first.
- **The owner's screen.** Ask before taking it over. Use the Studio MCP and the no-screen methods
  (`studio-mcp.md`, `studio-no-screen.md`). Never edit the live Team Create place by hand.
- **Blender previews play the saved actions**, not the module. Rebuild clips before rendering.
- **Stop and ask** when: a scene needs a new set or a set change that bumps a version, a liked scene would have
  to be restructured, a new sound or voice line is needed, a scene's meaning would change, or two attempts at one
  scene have been turned down.

## The report after each scene

In plain words, for the owner:

- The scene, and the one sentence it is now about.
- The reference used, with its link.
- Before and after: the faults seen in the game before, and which are gone.
- The motion report's numbers before and after.
- Where the preview video is, and the debug cue to play it in the game.
- The sound list for the owner to fill.
- What is needed to see it (script sync only, or an import with file name and version).
- What was checked, and what was not seen.

Then add what you learned to `docs/agent-memory/cutscene-quality-bar.md` as the next round, and log the scene at
the bottom of this file.

# Log

(Each finished scene: date, scene, rebuild or re-act, the owner's verdict.)

- 2026-11-14, RoleAce (pilot, rebuild), branch claude/pilot-ace-101c0e: new module art/scripts/cinema/shots/role_ace.py (the old role_l.py is kept, no longer imported), reference art/refs/cinema/RoleAce.toml. Motion report: RoleAce_self FAIL (dead limb 17.5 s, torso 1 percent, same timing 14 of 17) before, PASS after; RoleAce_butler FAIL (symmetry, mirrored tray arms) before, PASS after (frozen 2.3 s, dead limb 5.8 s). `--clear` 0, `--lint` no `[shape]` notes, acting file 35,876 characters. Not done: the game watch (the new Acting and Shots files must be synced into the place first, which only the owner's Rojo can do), the owner's verdict.

- 2026-11-15, IntroCampus (1g, re-act: same nine cuts, same lengths, same story and set), branch claude/campus-react-84a4e7: one sentence and the one big action written in `art/refs/cinema/IntroCampus.toml` (the reference re-watched, 14 beats now, one new finding: Light never turns his head, only his eyes move); the noticer acted through (writing fast, the page turned, the clock, the last stop, sat back tapping, sinking with his head on the arm laid along the desk, the wind-up and the snap, the lean to the door), the candidates write with the shoulders too, six of nine cameras changed (every close shot of him a long lens from the door's side or from straight in front, the last shot rises and pulls right out), key and rim lights added, the book lit as it turns. Motion report: IntroCampus_noticer FAIL (frozen 4.4 s) before, PASS after (frozen 1.4 s, torso 14 percent, anticipation 2 of 2). `--clear` 0, `--lint` no notes (three `[frame]` notes before), acting file 151,327 characters. Not done: the game watch (Studio was in another session's Play, then not connected), the owner's verdict.
- 2026-11-14, RoleDiavolo (1h, cameras and Ryuk only, re-act), branch claude/diavolo-ryuk-bc9da4: the owner's complaint (stale cameras when not camera POV, how Ryuk appears, how stiff he is) answered in [ryuk-specter-findings-2026-11-14.md](ryuk-specter-findings-2026-11-14.md): Ryuk is eight rigid parts, no joints (their guess is right), used in two scenes only; options and costs there. Changed in role_kira.py only: B, C, D, E, F are new held cameras, Ryuk is tipped about his hips and drawn in over 2.4 s so his head lands in the cut to F; story, cuts, lengths, voice, hidden cameras and effects unchanged. `--clear` 0, `--lint` only intended `[frame]` notes, motion report unchanged (PASS). Not done: the game watch (no Studio was connected), the Oculus deal (Luau, waits for the owner's choice), the owner's verdict.
- 2026-11-15, RoleAce fix round (first turn-down at the owner's gate): measured the Butler's walk in the game, rebuilt it (eased
  travel, a curved arrival, small moves while waiting, an exit through the door), rebuilt the ending (the stare released at 14.2, a
  wide with the Butler leaving, a cut to black; length 17.5 to 16.6), added the `[end]` lint, a tray reference in `RoleAce.toml`
  and the method checks above. The real briefing in the game ended on time and restored everything: "not exiting" was read as the
  ending. Verdict pending.

- 2026-11-17, RoleButler (item 4 of the 2026-11-16 list, step 1c, rebuild), branch worktree-agent-a54c29b52d540c8ac: new module art/scripts/cinema/shots/role_butler.py (the old role_watari.py kept as role_watari_old.py, unimported), reference art/refs/cinema/RoleButler.toml (Watari, episode 6; 11 beats). The line is unchanged. Motion report RoleButler_self FAIL (glides 2.7 s, symmetry 100 percent) before, PASS after (symmetry 21 percent, frozen 0.7 s); RoleButler_ace PASS both. `--clear` 0, `--lint` no [shape] or [end] notes (1 shape and 3 end notes before), only the intended [frame] notes of the hands insert, acting file 24,712 characters. Not done: the game watch (no Studio was free), the real briefing, the owner verdict.
