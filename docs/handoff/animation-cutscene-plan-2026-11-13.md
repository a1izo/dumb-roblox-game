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

## Tool 2: the spacing strip

An option for `art/scripts/review_anims.py` (or a small new script): one row of frames at a fixed step of 0.05
seconds over a chosen window, from the shot's own camera, bodies drawn as flat black on white. Even spacing between
frames shows at a glance, and so does a weak silhouette. Use it on every big move.

## Tool 3: the silhouette check

For each held pose in a shot, from that shot's camera at that time: project each arm and the head onto the screen
and measure how much of each lies inside the torso's outline. An arm more than 70 percent inside the torso is
hidden. Print the holds where both arms are hidden or where the head overlaps a raised arm. Add it to
`run_cinema.py --lint` as `[shape]` notes.

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

Start with an inventory, written into this file: every death clip in `art/scripts/deaths.py` (the 14 and the three
cause collapses), the eight scene re-enactments in `art/scripts/deaths_scenes.py`, the scene deaths under
`src/client/Presentation/SceneDeaths/`, the five death styles in `art/scripts/fallen.py`, and the death at the
table (`Presenters/Death.luau`). For each: watch it in the game through the debug gallery (Show tab), run the
motion report, and mark it good, re-act or rebuild.

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
