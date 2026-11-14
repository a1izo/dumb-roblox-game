# Audit: the match scenes built in Luau (plan item 1i)

Written 2026-11-14 for the owner. The plan (`animation-cutscene-plan-2026-11-13.md`, item 1i) asks for a short list of
what reads as cheap or stiff in the six match scenes that are built in Luau and not in Blender. Nothing in them was
changed.

**Every line below comes from reading the code and not one was watched in game** ("not watched in game"). When the
audit was written Studio was in Play, started by someone else, so it was left alone. The owner then said yes to a
watch and Studio was free, but the watch through the Studio MCP did not work (see "The watch that was tried" at the
end). Times are worked out from the code (phase lengths, `task.wait`s, tween lengths), not measured on a screen. Where
a fault depends on how a thing looks, it is marked "check in game".

Yardstick: the plan's "what sloppy has meant" list and "the owner's taste", the Part 3 checklist, and the Part 1 table
of counts (RoleMuerto: 7 moving cameras, 0 locked, 12 effect events, 13 hands on targets).

## The six at a glance

| Scene | File | Runs | Camera shots | Moves / locked | Effect beats | Held props | Acting in the file |
|---|---|---|---|---|---|---|---|
| Case opening | `Intro.luau` | 15 s | 6 | 5 / 1 (5.9 s) | 5 | 1 (the book) | none |
| Verdict | `Verdict.luau` | 6.0 s of 7 (4.3 s if nobody is removed) | 1 (3D part) | 1 / 0 | 8 | 0 | none |
| Arrest | `Arrest.luau` | about 2.9 s (the match waits 4) | 1 | 1 / 0 | 15 | 0 | two black copies, standing |
| Outro | `Outro.luau` | 10 to 15.5 s | 3 or 4 | 3 or 4 / 0 | 11 | 1 (the Manual) | none |
| Oculus deal | `EyesDeal.luau` | 7.2 s | 4 | 1 / 3 | 10 | 0 | the Deathsinger, rigid |
| Manual writing shot | `ManualWrite.luau` | 2.6 s | 1 | 1 / 0 | 0 | 1 (the Manual) | none |

"Moves" are camera moves (`CameraDirector.move`, or the Outro's per-frame sweep). Every move is one `Sine` ease in and
out (`CameraDirector.move` defaults to it and no scene passes another), so there is no fast-out, slow-in. "Locked" is a frame that is cut to and
then not moved. While a letterbox is up `Lens` lays a 0.16 degree breathing sway and film grain over every frame, so no
locked frame is truly still, but none of that is an operator's move.

No scene in these six files has a hand placed on a target, a body clip of its own, or an impact frame (no `still`,
`slash`, `freeze` or smear). The only body acting on screen comes from `Anim/ActingController` (the cuffed pose, the
slump, the reactions, the cheers), which this audit does not cover.

## What every one of them shares (the root cause)

1. **One camera recipe.** A hard cut to a framing from `ShotSolver.frame`, then one slow creep to a closer one. The
   Verdict, the Arrest, Ace's turn and the Hand's turn in the Outro are the same shot: 8 to 9 studs, 1.6 to 2 up, 18 to
   25 degrees off axis, fov 50 to 55, then 5 studs, 0.8 to 1 up, 8 to 12 degrees, fov 40 to 44. The plan's rule is "no two
   shots in a row from the same angle and size"; the Outro cuts from Ace's to the Hand's with exactly that pair.
2. **The camera is aimed once.** Each framing is worked out at the cut, at the head's place at that moment, and the move
   goes to a point worked out at the same moment. A body that is still moving (the verdict's slump, a laugh) leaves it.
3. **Close-ups at fov 40 to 44.** The plan wants faces from further back at fov 25 to 35 and says a wide close-up shows
   only hair. Check in game.
4. **Each scene ends by snapping the camera back to the player** (`CameraDirector.release`), mid-creep, not on an
   action. Check in game.
5. **No body acting of their own.** Nothing is acted in these files, so none of the Part 2 tools (motion report,
   silhouette check, spacing strip) can read them.

## 1. Case opening (`Presenters/Intro.luau`)

**No player sees this scene today.** It is the fallback for a map with no Blender intro (`RoundService.INTRO_SHOTS`),
and all three maps (Campus, Tokyo, Agency HQ) have one, including when the debug panel plays the intro. The faults below
would show only on a fourth map without a Blender intro.

How it runs (15 s, the phase length): 0 to 2.4 s the establishing shot (fov 62 to 56, a third of the way in) with the
case card typed in; 2.4 to 8.8 s four vignettes of 1.6 s each (cut at 8 studs / fov 50, creep to 5 studs / fov 42,
alternating 32 degrees to either side, a name and a line in handwriting); 8.8 to 9.7 s the Grimoire falls and lands
(thunder, bone flash, lamps dip, burst, chalk ring, sparks, a 0.35 s shake); 9.7 to 15 s the same frame held.

Faults, against the checklist:
- **8.8 to 15 s: a locked frame for about 5.9 s.** The fall is 0.9 s and the rest is a held frame of a book lying on the
  ground; the vignettes are clamped to 1.6 s so they never use the time left.
- **8.8 to 9.7 s: a prop from nowhere.** The camera looks at the ground from 11 studs and the book falls from up to 40
  studs on a `t * t` slide. Out of doors it enters the frame for about 4 frames (0.07 s) before it lands. Indoors it
  shows for about a third of a second. Check in game.
- **2.4 to 8.8 s: four shots from one recipe**, each 1.6 s (among the shortest cuts of the six; only the Oculus deal's
  1.5 s shot is shorter), with a name and a caption to read in that time.
- The people in them play one of four short idle clips ("checking the time", "lost in thought"): small polite gestures,
  the thing the plan names as the gap against RoleMuerto.

**Verdict: leave alone.** It is never played; if a fourth map ships without a Blender intro, that map needs the Blender
treatment, not this.

Not seen: all of it.

## 2. Verdict (`Presenters/Verdict.luau`)

How it runs (7 s phase, the result lands at 3.2 s): the black page glitches in and the votes are tallied as marks
(one `penScratch` sound per stroke, up to a dozen in about 1.5 s); at 3.2 s the gavel, the name turns red, a bone
flash; 3.8 s the page fades (0.3 s); 4.1 s the 3D shot on the person voted out: cut at 8 studs / fov 55, creep to 5
studs / fov 42 over 1.8 s, a spotlight, an outline, a rim light, the room's lamps dip, the stamp "Their role stays
secret"; the shot ends at 6.0 s. When nobody is removed there is no 3D at all: a stamp on the page, gone by about 4.3 s.

Faults:
- **4.1 to 6.0 s: the camera pushes in on someone who is vanishing.** `ActingController` starts the dissolve at 4.0 s
  (1.6 s long, gone at 5.6 s) and the creep runs to 5.9 s. At the half-way of the creep (5.0 s) the person is about 60
  percent faded; for the last 0.3 s of the shot the spotlight, outline and rim light are on empty air. The close frame
  is the one with nobody in it. Check in game.
- **3.2 s, then 4.1 s: the cut lands 0.9 s after the gavel**, not on it (the 0.6 s hold and the 0.3 s fade come between).
  The plan asks for the cut on the action. The person is already mid-slump when the shot starts, so the camera is
  aimed at a head that keeps sinking (fault 2 above).
- **4.1 to 6.0 s: one 1.9 s shot is the whole 3D beat**, with the reactions of the others (they start at 3.5 to 4.0 s)
  never shown, though the header comment says the camera finds them "while the others react".
- **0 to 3.2 s: the tally is a screen of text**, which is the part that works; the stamp and the lights are the stock
  set of cards and lamps the Arrest and the Outro use too, nothing is built for this scene.

**Verdict: small fix.** The shot is simple and short; re-time the cut onto the gavel, start the dissolve after the
push-in, and add one reaction shot. No rebuild needed.

Not seen: all of it, the tally's sound pile-up above all.

## 3. Arrest (`Presenters/Arrest.luau`)

How it runs (2.6 s of shot, about 2.9 s with the opening, the match waits 4): at 0 s a huge Ø slams on the screen
(2.4 times its size to 1 in 0.22 s, fading from 0.55 s); at 0.3 s the handcuffs sound, four flashes 0.35 s apart
(white, steel, white, steel) and sparks at the suspect's hand; the camera cuts in (8 to 9 studs, fov 55, creep to 5
studs / fov 44 over 2.5 s); about 1.2 s the stamp "Arrested" pops with a gavel sound, and four red and blue rim lights
alternate every 0.42 s for the rest. Ace's verdict style, if worn, shows in a small viewport on the right.

Faults:
- **0.3 s: two operatives pop into existence.** The header says they "close in on the suspect"; the code casts two black
  copies of the suspect at fixed marks (2.6 studs to either side, 1.4 ahead) on the first frame of the cut, under a 45
  percent white flash, and they never move. A prop from nowhere, and nothing that closes in.
- **0.3 to 2.9 s: the cuffs click and nothing is seen.** There is no cuff on screen, no hand to hand, no operative
  reaching; the cuffs are a sound and a flash. The scene has no physical action (plan Part 3, step 2: that is its real
  fault).
- **0.3 to 2.9 s: both operatives play the same `point` clip**, a symmetric pair with a random start up to 0.5 s apart.
  The plan's "never both arms doing the same thing" and "background people in step".
- **0.3 to 2.9 s: one creep for the whole beat**, aimed at the head 0.3 s into the suspect's 0.4 s blend to the cuffed
  pose (check in game that the head is still in frame at the end).
- **An innocent is treated alike**: the cuffed pose, the lights and the stamp; only the stamp colour and the outline
  change (a story point to confirm with the owner, not a fault of craft).
- 4 flashes in 1.35 s plus the slam: strong, but the flash is the only thing carrying the beat.
- The Ø comes up over the live meeting room for 0.3 s before the cut; the slam is the best beat in the scene.

**Verdict: rebuild** (in Blender, when its turn comes). A patch cannot add the physical action the scene lacks (the
operatives walking in, the cuffs shut on the wrists); that is a new scene.

Not seen: all of it; whether the operatives stand in the table or a chair (they are placed with no clearance check).

## 4. Outro (`Presenters/Outro.luau`)

How it runs (10 s phase, +3 s when names were written, +2.5 s when the Bureau won with Ace alive and no win cutscene
of theirs; 10 to 15.5 s in all; the lead's win cutscene replaces the first part and is out of scope here): 0 to 5 s the
sweep (a camera in the middle of the table, turning 150 degrees, fov 70 to 58, over the winners and losers acting in
`ActingController`'s clips) with "X wins" typed over it, a bell, and a red wash when the Hand won; 5 to 8 s the Manual
with every name written, those that killed struck through; 8 to 10.5 s (Bureau win) Ace under a spotlight with a gavel,
outline, lamps dip and a card; then the Hand for the last 5 s (cut at 9 studs / fov 55, creep to 5 studs / fov 40, a red
spotlight, outline and rim light, the card "Hand was ...").

Faults:
- **0 to 5 s, the sweep: the camera stands where the table is and has no clearance check.** Only the ceiling is read
  (`ShotSolver.ceiling`); a centrepiece, a lamp or a seat back can sit in the lens, and the plan's "camera within 3
  studs of a head" is possible. Check in game.
- **5 to 8 s, the Manual: from 8 names up the frame cannot hold them.** The camera ends 1.55 studs from the page at fov
  36, which shows about 6.7 of the page's 18 ruled lines through the letterbox; the first and last names drop out of
  frame from 8 names. They are also written at about 0.3 s a name (the pace shrinks to fit 2.6 s), faster than they can
  be read.
- **The last 5 s, the Hand: one shot with every effect at second 0** (spotlight, outline, rim, lamps, gavel, card), then
  4.5 s of a slow creep on a body that laughs or kneels in `ActingController`'s clip. Nothing happens after the opening
  beat.
- **Ace's turn and the Hand's turn are one shot twice** (fault 1 above), back to back.
- **Four sections, four timers, no cut on an action**: the camera changes at the second marks the server sends, not on a
  movement.
- The sweep, the book and the Hand's turn are all single eased moves; the plan's "one big thing that escalates" is not
  there; the ending's escalation (the winner, the names, the Hand) is carried by cards.
- The win cutscenes (Stage 3) own the better version of the first part; do not spend time on the sweep if those are
  rebuilt.

**Verdict: small fix** for the Manual's fit and pace, the Hand's turn and the variety of the Ace and Hand shots; the
first part belongs to Stage 3.

Not seen: all of it; how the seated or standing winners look in their cheer, dance and slump clips (not in this file).

## 5. Oculus deal (`Presenters/EyesDeal.luau`)

The best built of the six: a story of four beats, each with its own shot and effects. Only the Muerto who took the deal
sees it.

How it runs (7.2 s): 0 to 2.2 s your face from 9 studs in front, the world drains red (tint, red vignette, lamps dip),
the Deathsinger is drawn out of smoke behind you with its eyes lit first (camera creeps 9 to 7 studs, fov 52 to 48);
2.2 to 3.7 s cut low over its shoulder (fov 55, locked) while it leans down 10 degrees; 3.7 to 5.45 s cut to your face
(2.4 studs, fov 40, locked), your eyes take fire at 3.95 s (two flares, embers, a ring, four bolts 0.12 s apart, a red
flash); 5.45 to 7.2 s wide again (locked), the Deathsinger comes apart into smoke and 24 feathers, the card "Deal
made" for 1.75 s.

Faults:
- **2.2 to 7.2 s: three locked frames** (1.5, 1.75 and 1.75 s) after one move. The plan allows locked frames only for
  cameras that exist in the world.
- **The hand-placed cameras have no clearance check.** The first three (`near`, `closer`, `overShoulder`) are plain
  `CFrame.lookAt`; only the face and the wide shot use `ShotSolver`. A player who stands within 9 studs of a wall or a
  prop gets a camera in it. Check in game.
- **The Deathsinger is placed 2.6 studs behind you with only a floor ray**, 8.5 studs tall: a wall behind you or a
  ceiling under 9 studs puts it through the building. Check in game.
- **The player is not frozen.** The server releases the ritual freeze just before it fires the cue, and the framing is
  worked out once at the start; a held key walks the player out of the shot. (`ManualWrite` freezes the writer; this
  one does not.) Check in game.
- **3.7 to 5.45 s: the key close-up is at 2.4 studs, fov 40, level, from straight ahead**, the framing the plan says
  shows only hair, and it is locked. The eyes catch fire in the one frame that does not move.
- **2.2 to 3.6 s: the "lean" is a rigid 10 degree tilt of the whole model** and a slide of 0.9 studs, over 1.4 s on a
  sine. A model with no animation reads as a prop, which is the stiffness the plan names.
- **5.45 to 7.2 s: the card reads for 1.75 s**, two lines, with 0.3 s of that the fade; short.
- The player's own body does nothing (whatever idle it had); the plan's "reactions that go still and turn slowly" are
  not used.

**Verdict: small fix.** Keep the four beats. Put the three hand-placed cameras through `ShotSolver`, freeze the player,
move the two middle shots, pull the close-up back to a longer lens; the rigid Deathsinger is the larger job and can
wait.

Not seen: all of it; the first 0.5 s (whether the red tint covers the start).

## 6. Manual's writing shot (`Presenters/ManualWrite.luau`, via `BookStage`)

How it runs (2.6 s, `ManualTiming.WRITE`): the writing screen steps aside; the book lies alone in the dark, camera from
the book's foot (cut at 2.9 studs / fov 40, creeping to 1.55 studs at the line / fov 36 over 2.5 s); the name is wiped in
from the left. The owner's staging (2026-10-12): no place, no hands, so it never shows who wrote; a point light over the
page and dust in the beam.

Faults:
- **0 to about 1 s: the name is written; 1 to 2.6 s: the page is finished and the camera keeps creeping.** The wipe
  takes 0.07 s a letter, so a 10 letter name is done in 0.7 s and an average one in about 0.9 s.
- **No sound and no mark with the plain ink** (most players; in the code): the wipe is a clipped width tween, no pen noise, no ink
  that bleeds, nothing at the last stroke. The plan's cause and effect ("the pen's last stroke") has no cause: there is
  no pen. The styles (quill, fire, knife, frost, chalk) add their own marks; the default has none.
- **0 effect beats** in the whole shot. The writing screen is closed by the same cut.
- The framing: the name is a small hand on a ruled line, about 5 to 10 percent of the screen height. Check in game that
  it reads.
- A set built far above the world each time (`BookStage`, y 1500): check in game that the first frame is not black.

**Verdict: small fix**, inside the owner's staging (no hands): let the writing last the shot, and give the last stroke a
beat (a sound, an ink bloom). The staging stays.

Not seen: all of it; what the default ink's wipe looks like at the end of the creep.

## Summary and order

| Scene | Verdict | Why in one line |
|---|---|---|
| Case opening | leave alone | not played by any live map |
| Verdict | small fix | the cut lands late and the camera pushes in on a person who is dissolving |
| Arrest | rebuild | nothing physical happens on screen: static pointing copies, no cuffs seen |
| Outro | small fix (the rest is Stage 3) | one recipe twice, the Manual cannot show 8 names, the Hand's turn is all front-loaded |
| Oculus deal | small fix | the beats are good; three locked frames, three unchecked cameras, the player is not frozen |
| Manual writing shot | small fix | the writing is done in the first second and the plain ink has no pen |

If the owner wants them done after the Stage 1 list: the Oculus deal and the Verdict first (smallest, most seen by one
player each), then the Manual's pace, then the Outro with Stage 3; the Arrest is a Blender scene of its own.

## The watch that was tried (2026-11-14, nothing seen)

First the Studio was in Play, started by someone else, so it was left alone. Later it was in Edit and the owner had
said yes, so I started a play test through the Studio MCP and stopped it again (Studio is back in Edit, nothing in the
place was edited). It produced no pictures and no measurements of the scenes:

- `screen_capture` during Play returned only Roblox's own top-left buttons on a dark grey frame, no 3D and none of the
  game's screens. The client drew 14.9 frames a second: Studio was not the window in front. Getting full frames needs
  Studio in front (the owner's screen), which the yes did not cover.
- The `Debug` remote reached the server (a listener of mine saw it) but the real `DebugService` sent no reply, no cue
  and no snapshot within 8 s, so none of the match cues (`verdict`, `arrest`, `eyesDeal`) could be fired this way. A
  match with bots was already running by then (its own intro cutscene was on the camera), so a measuring script of
  mine fought it for the camera and read nonsense; it is not used here.
- `require` in the MCP's `execute_luau` returns its own copy of every game module (a fresh `Match`, a fresh `Bots`),
  not the running one, so game state cannot be read or driven by requiring the services. See
  `docs/agent-memory/studio-mcp-play-test-traps.md`.

So the list above is still from the code. Two ways to see them: the owner plays the cues (the list below) with the
list of "check in game" lines in hand, or a session starts Studio's play test with Studio in front, once the owner
agrees to the screen.

## How to watch them

The Studio MCP (`mcp__Roblox_Studio__*`) and the no-screen methods are allowed by the owner (2026-11-14); a session that
watches should first run `list_roblox_studios` and `get_studio_state` and leave it alone while another session is in
Play.

- A running match with bots is needed for the server cues: `Net.event("Debug"):FireServer("fillBots", {total=6})` then
  `"startMatch"` (`studio-cutscene-testing.md`). Then, one at a time, from the client:
  `FireServer("cue", {kind="verdict"})`, `{kind="arrest"}`, `{kind="eyesDeal"}`, `{kind="outro", extra="Kira"}` and
  `extra="Team"` (the Bureau's Ace turn), `{kind="intro"}` (this plays the Blender shot: the Luau version needs a map
  with no shot).
- `manualWrite` has no debug cue. From the client command bar require
  `Client.Presentation.Presenters.ManualWrite` and call it with `{at = workspace:GetServerTimeNow(), data = {name =
  "Kenji Mori"}}`, or write a name in the Manual in a real match.
- For slow motion: `game.Players.LocalPlayer:SetAttribute("ShotRate", 0.25)` (it affects Blender shots; the Luau
  scenes run on `task.wait` and tweens at real time, so capture them with several `screen_capture` calls).
- The audit's checks to make in game, in order of how much they matter: the Verdict's dissolve against the push-in;
  the Oculus deal's cameras near a wall and the player walking; the Outro's Manual with 8 or more names; the Arrest's
  operatives and the cuffs; the Manual shot's first frame and the name's size.
- The `docs/handoff/harness` scripts are for pictures of Blender shots and deaths; they need paths adjusted on this
  machine (see `docs/agent-memory/harness-paths-stale.md`) and a place with the imports to show a map.
