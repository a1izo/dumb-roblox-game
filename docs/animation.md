# Movement animation

How every body in Death's Gambit stands, walks, runs, jumps, falls, lands, sits and flies: the style, the clips,
the controller that plays them, and the tools that build and check them. Rebuilt from scratch on 2026-10-14.

## The style: noir restraint, sharpened

A serious investigator, not a cartoon. Grounded weight, little bounce, compact arms, a steady head, and clean
silhouettes that read from the game's camera (behind the player, up to 18 studs away in a case). The anime flair
is kept for the air and the landings. Nothing about how a body moves depends on its secret role.

- **Weight** shows in the body sinking just after a foot lands, not in a bounce.
- **The head** is held steady: the neck works against the torso's lean and turn.
- **Arms** swing close to the body, a little outward at the ends of the swing, so the swing still reads from
  behind (where a plain forward and back swing hides behind the torso).
- **Different rhythms for different moments**: breathing eases in and out, a take-off snaps, a landing compresses
  fast and recovers slowly, a fall drifts on springs.

## What the game plays

| State | Clips | Notes |
| --- | --- | --- |
| Standing | `idle` (at ease, lobby), `idleGuarded` (in a case) | 24 s loops of slow rhythms that do not line up: breaths of different depths, the weight moving from foot to foot and back, the head drifting and glancing. The mood crossfades over 1.5 s. |
| Fidgets | lobby: `idleLook`, `idleWatch`, `idleTie`, `idleNeck`, `idleSleeve`, `idleHandsBack`; case: `idleLook`, `idleWatch`, `idleGlance`, `idleArmsCross`, `idleHand`, `idleRoom` | Every 8 to 20 s while standing with nothing else playing, from a shuffled bag, never the same twice running. Upper body only. |
| Moving | `walk`, `walkBack`, `walkLeft`, `walkRight`, `run`, `runBack`, `runLeft`, `runRight` | Blended by direction (in the body's own frame) and by speed. The run is 16 studs/s, the game's only full speed. |
| Setting off | `startStep` (additive) | The body tips into its first step. |
| Stopping | `stopRight`, `stopLeft` | From a run, on whichever foot is down: the weight catches, the other foot steps up beside it. |
| In the air | `jump`, `jumpApex`, `fall`, `fallLong` | The take-off when it jumped (stepping off a ledge goes straight to the hang), the top, the fall, a long drop's wider shape. |
| Landing | `landLight`, `landNormal`, `landHeavy` (additive) | By the height the impact is like falling from: under 0.6 studs nothing, then light, normal (from 4) and heavy (from 14). Never slows the body. |
| Seated | `sit` | Seats in the world; the throne's stone champion holds a moment of it. |
| Flying | `flyHover`, `flyGlide`, `flyRise`, `flyDive` | Deathsingers and spectators: a hover easing into a glide with speed, a rise and a dive with vertical speed, a bank into sideways drift. |

Timing chart (seconds):

| Clip | Length | Shape |
| --- | --- | --- |
| run (each way) | 0.64 a cycle | right foot lands at 0, left at 0.32; each foot down 0.15 (heel, flat, toe), a long flight between steps |
| walk (each way) | 1.05 a cycle | each foot down 0.63 (both down at the hand-over) |
| idle / idleGuarded | 24 loop | breaths of 4.0 / 3.43 |
| jump | 0.5 | push-off at once (snap), tucked by 0.12 |
| landLight / Normal / Heavy | 0.3 / 0.45 / 0.8 | down in 0.06, held, up slowly |
| stopRight / Left | 0.62 | catch by 0.12, the foot steps up 0.1 to 0.32 |
| startStep | 0.36 | tipped in by 0.09 |

## How a rigid R6 leg walks

An R6 leg is one 2-stud box hanging from the outer edge of the hip, so the clips (art/scripts/locomotion.py)
fake a foot and a knee:

- **A planted leg rolls over its sole** like a foot: it lands on the trailing edge (the heel going forward), rolls
  flat and pushes off from the leading edge (the toe), and the edge on the ground never moves. When the body runs
  a little across (sideways cycles) the leg rolls over corners instead of edges.
- **The knee is a slide**: the leg slides along its own length only, up into the hip as it bends. When reaching
  the ground would pull it out of the hip (a gap under the torso), the body sinks instead, which is also where a
  body is lowest in life: just after a foot lands. The sinking is smoothed so the body eases into it.
- **A swinging foot travels in the world** from where it left the ground to where it lands next, starting and
  ending at rest: it lifts before it moves (no scuffed toe) and comes down at ground speed (no skating heel).
- **Every cycle moves the body the same 2.4 studs over each planted foot** (`TRAVEL`), and every cycle lands its
  right foot at phase 0 and its left at 0.5. That is what lets the controller blend walk with run, and the four
  directions with each other, on one phase without sliding feet.
- **Sideways**, the whole body turns into the run (60 degrees running, 40 walking) with the legs under the torso
  and the head kept to the front: a leg turned far from its torso would swing half out of the torso's silhouette.

## The controller

`src/client/Anim/LocomotionController.luau` poses every body on every client (nothing replicates; the inputs are
the body's velocity, position, the ground under it and a few attributes). It feeds `PoseController` the base pose,
and `PoseController` plays action and emote clips over it. Helpers: `Locomotion/Pose.luau` (pose buffers,
sampling, mixing, additive layers), `Locomotion/Feet.luau` (the after-pass), `Shared/Anim/Gait.luau` (the
arithmetic, checked by `Gait.spec`).

- **One phase** advances by the ground the body actually covered divided by the blended stride, so the legs stop
  when the body stops. Each leg samples its clip at a warped phase (`Gait.warp`) that stretches the clip's stance
  to the blend's, so feet come down together in a walk and run blended mid-way.
- **Direction**: the velocity in the body's own frame splits between the two neighbouring directional cycles
  (squared cosines, summing to one), smoothed over about 0.1 s.
- **Layers over the base**: the first step and the landing (additive, the legs left to the cycle or the planted
  feet), a bank into curves (up to 8 degrees) and a tip against changes of speed.
- **The after-pass** (`Feet.plant`): once every layer has moved a standing body, each leg is set upright on its
  sole's mark, so idles, fidgets, landings and stances never slide the feet. Clips that move the legs themselves
  (dances, actions) keep them.
- **Turning on the spot**: the body lags its root by up to 25 degrees, the head leads, then the body comes round
  and the feet step after it one at a time.
- **Air**: the ground is checked every frame within 80 studs of the camera (every 0.1 s beyond), ignoring water.
  The landing strength comes from the fastest the body fell.
- **Cost**: bodies beyond 110 studs are posed every second frame (holding their last pose between, since an
  Animator would put them back to rest). In the play test, forty bodies cost about 0.7 ms a frame.
- **Strolls and stances** (emotes from the shop) keep working: a stroll replaces the idle and the forward cycles;
  backwards and sideways during a stroll use the movement set.

Transitions:

| From → to | How |
| --- | --- |
| idle → walk/run | the cycle blends in over 0 to 1.5 studs/s; the first step tips in (`startStep`) |
| walk ↔ run | blended by speed (5 to 13 studs/s) on the shared, warped phase |
| run → idle | the stop on the foot that is down, then the idle with the feet planted |
| direction changes | the cycles' weights turn with the velocity (about 0.1 s) |
| ground → air | the take-off (or the hang, stepping off) in about 0.07 s |
| jump → fall | by vertical speed: the take-off rising, the hang at the top, the fall, the long fall after 1.2 s or past 40 studs/s down |
| air → ground | the air poses fade in about 0.08 s while the landing plays over what comes next |
| respawn | a new body starts in the idle at a random point of its loop |

## Building, checking and reviewing

```
blender -b --factory-startup --python art/scripts/run_anims.py      # build every clip, export, check
python art/scripts/check_anims.py [clip ...] [--all]                # the checks alone (Blender's Python works)
blender -b --factory-startup --python art/scripts/check_export.py   # the Blender rig against the game's maths
blender -b --factory-startup --python art/scripts/video_anims.py -- name.mp4 run idle ...
```

`check_anims.py` holds the movement set to: soles that do not slide while down (0.03 studs), nothing below the
floor (0.03), no gap at the hip (0.12), no leg deeper than 0.6 in the torso, clean loop seams, no joint faster
than 900 degrees a second. `run_anims.py` fails when any of them fails.

## References (principles only)

Studied from gameplay footage, frame by frame, on 2026-10-14. Nothing was copied: no poses, timings or sequences.

- **Deepwoken** (R6): speed is sold by the lean and a calm, simple upper body; the air gets its own clear shape.
  Here: a moderate lean, compact arms at speed, a distinct airborne silhouette.
- **Flicker** (the same genre): a crowd of identically dressed people standing close to the camera looks dead
  unless the idles differ in phase and break up now and then. Here: long idles started at random points,
  shuffled fidgets.
- **Jujutsu Shenanigans** (R6): a cycle of about 0.65 s at full speed, the arms arcing out and the torso
  twisting so it reads from behind. Here: a 0.64 s run, a small outward arc, the shoulders turning against the
  legs.
- **DOORS**: a clear lift of the swinging leg and a steady head read as purposeful movement up close. Here: the
  foot lifts before it travels; the head is stabilised.
