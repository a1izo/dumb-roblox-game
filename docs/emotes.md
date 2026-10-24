# Emotes

How the emotes work: what there is, how one plays on every screen, where it may play, the data that describes
each one, the camera, the effects, and how an emote is made and checked. Rebuilt in the emote overhaul
(2026-10-17 to 2026-10-21); the movement set they play over is in `docs/animation.md`.

## What there is

70 emotes: 11 that everyone has and 59 from the shop.

| Family | Emotes | Notes |
| --- | --- | --- |
| Everyone's | Wave, Point, Cheer, Laugh, Dance, Salute, Bow, Shrug, Facepalm; High Five, Handshake | The first five copy Roblox's classic `/e` emotes; their lengths are frozen (other scenes reuse them). High Five and Handshake are free duos. |
| Dances (19) | The Classic, Office Party, Bunny Ears, Jackpot Shuffle, Rat Dance, Goal Celebration, ... | Several motion-captured from footage (`art/refs/mocap`); loops play on a shared beat, so everyone doing one is in step. |
| Poses (19) | Just As Planned, New World, Final Breakdown, Reaper's Eyes, Menacing Pose, Low Battery, Chair Perch, ... | Held moments, many with a press-to-do moment. |
| Prop emotes (14) | Pre-Dawn Bonk, Sugar Tower, Dice Tower, Furious Scribbling, Apple Toss, Strawberry on Top, Potato chip, ... | Props from the Core set held, carried, stacked, tossed, opened or set on the floor. |
| Strolls (5) | The Long Climb, Parade March, Griddy, Mushroom Stroll, Not My Problem | Walk styles that walk by themselves. |
| Duos (2 + the 2 free) | Match Point, Cuffed Together | Played by two. |

Every shop emote has a rarity (`src/shared/Rarity.luau`), the same five tiers as every other shop item:

| Tier (id) | Colour | Effects |
| --- | --- | --- |
| Scrawl (`common`) | ash `#A7A29A` | the motion alone, the ink wisp at the start and end |
| Penned (`rare`) | slate blue `#6F93C2` | one accent made for it |
| Sealed (`epic`) | violet `#9C7BEA` | an effect made for it, with light; the showpiece camera |
| Condemned (`legendary`) | amber `#D9963F` | layered, supernatural effects |
| Godhood (`godhood`) | crimson `#A3192F` | a private cutscene: New World, Final Breakdown, Reaper's Eyes, Just As Planned (1500 coins; Fate counts them as Condemned) |

## How an emote plays

1. **The wheel** (`src/client/UI/Wheel`, Q): eight emotes in a revolver's cylinder; point and click, tap, or 1
   to 8. It says what an emote is (walks, press-to-do, for two, a group, a cutscene, lobby only) or why it cannot
   play here.
2. **The server** (`src/server/Services/EmoteService.luau`) checks the player may use it (owned, everyone's, or
   from a pass), a rate of one request every 0.8 s, and the rules below (`src/shared/EmotePolicy.luau`); a refusal
   goes back with its reason. A duo asks someone instead; a stroll sets the body's `Stroll` attribute instead; an
   emote with another ending (its shop item's `alt`) and no press-to-do moment plays it some of the time. Otherwise it sends
   `{ userId, emote, at, mask }` to everyone who can see the player and remembers it (for Join in, press-to-do
   moments and duos).
3. **Every client** (`src/client/Controllers/EmoteController.luau`) starts a session on that body: the clip
   (`PoseController`, eased in and out; a loop joins the shared beat, a one-shot catches up at most 0.25 s), its
   props, sound cues, face, effects (`EmoteFx`), the wisp of dust, and for the player's own emote the camera. The
   session ends when the clip ends, the body moves, another emote replaces it, the body goes, or the server stops
   it, and it takes everything it made with it.

`PoseController` plays an emote over the movement set's base layer. With the mask `upper` only the waist up
plays (the hips stay the base layer's and the soles stay planted). While a clip that moves the legs fades in or
out, the body is lifted wherever the blend of two poses would put a leg through the floor.

## Where an emote may play

`EmotePolicy` decides; the server applies it and the wheel shows it.

| Where | What may play |
| --- | --- |
| The lobby | everything |
| A case: the Briefing, free roam | everything but duos and the lobby-only ones; the effects in full (the owner's Q8 b; low graphics keeps one small accent); no camera moves |
| A case: the meeting and the vote | the waist up only; nothing that is about the legs (`lowBody`), sets props on the floor, or walks |
| A case: the Intro, Verdict, Outro, Reveal, and any scene everyone sees (intro, meeting intro, death, arrest, verdict, outro) | nothing: every emote stops and new ones are refused while the scene holds |
| A scene only one player sees (the Eyes deal) | no effect on emotes (stopping everyone's would give it away) |
| A Deathsinger | seen only by other Deathsingers; no strolls |

Lobby only: the duos, and the emotes that look like a case's signals (Low Battery like a death, Reaper's Eyes
like the Eyes, Cuffed Together like an arrest). **Join in**: anyone within 12 studs of a looping dance can join
it on its beat in the lobby; in a case only someone who owns it.

## The data: `src/shared/Anim/EmoteMeta.luau`

Plain data per clip, read by the game and, without Roblox, by `art/scripts/emotemeta.py` (the prop checks and
the review renders use it, so what they test is what the game does).

- **`props`**: each prop's `model` (`ModelCatalog`), `size`, the part it is on (`mount`) and where (`at`, solved
  from the Blender key poses: `-- hold:` lines written by `art/scripts/solve_holds.py`), when it shows and hides,
  `moves` and `tosses`, a `stack` (copies set down one by one, `carry`-ed from the hand, `topple`-d to the floor),
  `drop`/`sink` onto the floor, `open` (the real Death's Manual opened in the hand), `core` (the Core version that
  has the model; older imports show `fallback` or a stand-in block).
- **`contacts`** and **`allow`**: where a prop is meant to touch the body (an apple at the mouth) and the windows a
  part may pass through a prop; the prop check flags everything else.
- **`lowBody`**, **`loud`**, **`fx`** (a rung other than its rarity's), **`duo`**, **`lobbyOnly`**.
- **`context`**: a press-to-do moment, `{ label, from, to, branch, alt?, altChance? }`.
- **`formation`**: a group dance's places for those who join in.
- **`cinematic`** and **`cinema`**: the private cutscene's shot list (below).

## Press-to-do moments

A button shows from `from` and stays until it is pressed or the emote ends (all along in a loop): not a quick-time
event (the owner, 2026-10-24); `to` is only the end of the beat it was made for. One press plays the branch on
every screen (the server picks an `alt` branch some of the time). A branch with a context of its own can be pressed
again. It has its own keys, Y and R3, which no other action uses, and its own look (`UI/PromptView`): a white diamond
with the key dark on it and a ring breathing out of it, where every other prompt is a dark round keycap.

| Label | Emote | What it does |
| --- | --- | --- |
| EAT | Potato chip | Diavolo's "...and EAT IT." |
| LOOK UP | Excuse Me, Sir | the face tipped back to the sky |
| FLIP | Coin Flip | the flip |
| NEXT POSE | Menacing Pose | round six JoJo poses: DIO's, Giorno's, Jotaro's Star Platinum, DIO's WRYYY, Jotaro's point, Kira's |
| CHARGE | Low Battery | plugged in, jolted back up |
| LIFT | Blindfold Lift | the blindfold up, blue eyes |
| ADD ONE | Sugar Tower, Dice Tower | one more on the tower: it holds, or one time in two it all comes down |
| WRITE IT | Furious Scribbling | the last name written huge and slashed |
| TOSS | Apple Toss | thrown to an unseen death god |

## Strolls, duos and group dances

- **Strolls** are a standing loop (`<clip>`) and a walk cycle (`<clip>Walk`, the game's own `locomotion.Cycle`,
  in `art/scripts/emotes/strolls.py`) that replaces the walk while the `Stroll` attribute is on. The body walks by
  itself (`Controllers/StrollWalker`) at the stroll's `pace` (Cosmetics: 4 to 9 studs a second) along the way it
  faced when it began, sliding along walls and turning back at a ledge or a wall met head-on, with no time limit.
  The player steers it (keys, stick, touch pad, from the camera): it turns that way and keeps on it when let go
  (2026-10-24; steering used to end it). It ends when the player jumps, uses a game action (`InputRouter.Ran`: a
  note, the Eyes, a sabotage, an arrest) or a prompt, plays another emote or picks the stroll again; the emote
  wheel, Help, the scratchpad, the Grimoire, chat, Escape, the camera and shift lock never end it. The Long Climb's
  effect (an escalator of green-edged steps going down as fast as the climber climbs, so they never rise; a
  grinning green image of them over their shoulders, body-sized; green rain; its aura) is in
  `Controllers/EmoteFx`; its grin is the `manicGrin` face slot in `Shared/EmoteMedia`.
- **Duos**: the nearest player within 10 studs is asked and has 15 s to answer. Match Point is a real rally (the
  server keeps the ball; a press as it reaches your racket sends it back, a little quicker each time; the first
  miss ends it). Cuffed Together chains the one asked to the leader (a jump, another emote or 12 studs apart
  breaks it). High Five and Handshake walk the one asked up to face the asker (3.0 and 2.6 studs apart, set right
  on the spot) and both play it from the same moment (`DuoService`).
- **Group dances**: a dance with a `formation` walks each joiner to a free place round the first dancer (Office
  Party: two beside, three in a row behind) and sets them right on it.

## The camera

Only the player's own emote, only in the lobby, never under Reduce motion.

- **The showpiece camera** (`Presentation/EmoteCamera`, Settings "Camera moves round your showpiece emotes"):
  Sealed and up, and duos: the emote's own single move (`EmoteMeta.camera`: push, hero, high, shoulder, track,
  orbitLeft, orbitRight or hold), eased round to where it begins and arriving where it ends on the emote's `at`
  beat; no cuts; a slow orbit to the right without one. Then it glides back.
- **The private cutscenes** (`Presentation/EmoteCinema`, Settings "Godhood emote cutscenes"): the four Godhood
  emotes take the camera through their `cinema` shot list, with the letterbox, a colour grade and a vignette.
  A shot is `{ at, eye, look, fov, glide?, to?, focus? }` in the body's frame as the emote begins (x to its
  right, y up from its middle, z behind it): a cut (or a `glide` in from the shot before), then a drift to `to`
  until the next shot. `beats` add flashes, impact frames, a shake or a vignette at a moment. Every eye is
  checked against the walls (`ShotSolver`): pulled in, or mirrored to the other side, or the shot is left out.
  The camera and the screen come back on the end, walking off, another emote, death, respawn, a case starting,
  a step that errors, and a watchdog. With the setting off the showpiece camera turns round them instead.
  Everyone else sees the emote and its effects only.

## Effects, faces and sound

- **Effects** (`src/client/Controllers/EmoteFx.luau`): one function per clip, given the body, returning its
  clean-up; the rung (0 to 4) comes from the rarity or `fx`, at most 1 in a case or on low graphics. Under Reduce
  motion there are no flashes and no shake. Textures come from the Core set; an older import falls back to
  Roblox's own particles.
- **Faces** (`EmoteMedia.FACES`): six decals (deadpan, smirk, smug, raisedBrow, wideGrin, stare) a shop item can
  name with `face`; the ids are the owner's to upload and fill in.
- **Sound** (`EmoteMedia.SOUNDS`, `EmoteMedia.CUES`): a slot for every emote (the specs require it) and cues fired
  from beats; loops start their sound at the beat's phase; loud ones are kept quiet in a case. The ids are the
  owner's.

## Making and checking an emote

Each emote went through the same loop, and a new one should too:

1. **Reference notes**: `art/refs/emotes/<clip>.toml` (origin, source, timing, face, sound, effects, camera, R6
   notes, how it was checked). `python art/scripts/check_refs.py --strict` checks every emote has them.
2. **Watch the source** frame by frame (frame sheets in the browser); dances with clear footage are motion-captured
   into `art/refs/mocap/<clip>.json` and built with `art/scripts/emotes/mocap.py`.
3. **Author** it in its family's file in `art/scripts/emotes/` with the `Motion` API (`art/scripts/motion.py`:
   `key`, `follow`, `plant`, `floor=True`), `kit.reach` (an arm to a point and direction in the torso frame) and
   `posekit` (`on_floor`, `on_seat`). An R6 crouch or a sit on the floor is the legs out in front along the floor
   (about 80 degrees at the hips), the torso upright on their back ends, never soles planted with tilted legs.
   Props' holds go in the file's `HOLDS` and `solve_holds.py` writes them into EmoteMeta.
4. **Build and check**:

```
blender -b --factory-startup --python art/scripts/run_anims.py -- --add clipA,clipB   # build, export, check
python art/scripts/check_anims.py --quiet          # soles, floor, hips, seams, joint speed (EMOTE tier)
python art/scripts/check_props.py                  # every prop against every body part, all through the clip
python art/scripts/check_refs.py --strict
blender -b --factory-startup --python art/scripts/check_export.py -- clipA   # Blender rig vs the game's maths
blender -b --factory-startup --python art/scripts/review_emote.py -- clipA --sheet [--closeup=Model] [--cinema]
blender -b --factory-startup --python art/scripts/run_props.py -- --export --set Core   # after a prop mesh change
```

   `review_emote.py` renders the clip with its props exactly as the game places them; `--cinema` renders a
   cinematic emote through its own shot list (16:9). A Core mesh change bumps `VERSION` in
   `art/scripts/maps/export.py` and the props' `core =` gates, and needs the owner's re-import.
5. **In Roblox**: the headless play test plays it on a player and a test bot and checks it plays, ends, keeps its
   body above the floor, puts out its props and effects and takes them away again.

The specs (`Emotes.spec`, `EmotePolicy.spec`, `Rarity.spec`, `WheelMath.spec`) check the data: every emote
reachable once, a sound slot each, only known faces, contexts and props in clips that exist, cutscene shots in
order and inside their clip, and the phase rules.
