# Audit: the match scenes built in Luau (plan item 1i)

Written 2026-11-14 for the owner. The plan (`animation-cutscene-plan-2026-11-13.md`, item 1i) asks for a short list of
what reads as cheap or stiff in the six match scenes that are built in Luau and not in Blender. Nothing in them was
changed.

**The first version of this file came from the code alone. A second session then watched five of the six scenes in a
Studio play test (2026-11-14, Studio in front, the owner's "yes, screen ok"; see "The watch that was done" at the
end).** Each fault line now carries a mark: **Seen** (with the time, in seconds from the cue's start), **Wrong** or
**Not seen** (with what was actually there) or **Not checked** (and why). The marks are in the "In game" block at the
end of each scene, so the code-based text above it stays as it was written. The case opening is the exception: no
live map plays it, so it was not watched. Times in the "In game" blocks were measured (the camera logged every
0.1 s from a `RenderStepped` listener, and stills taken with a clock on the screen), the others still come from the code.
Verdicts stay as they were unless a block says otherwise.

## What the watch changed, in short

- **Confirmed as predicted:** the Verdict's cut at 4.1 s with a creep onto a body that is dissolving; the Arrest's two
  operatives popping in on the cut and never moving, and no cuff on screen; the Oculus deal's player not being frozen;
  the Outro's Ace turn and Hand turn being one shot twice; the Manual shot's small name.
- **Worse than predicted:** the Outro's Manual page shows about 4 to 5 of its 18 lines at the end, not 6.7; **every
  Manual shot (the Outro's book and the writing shot) is a black frame under the game's normal colour grade, whatever the
  number of names**, because the page is lit by almost nothing and the grade crushes it (run down at the end); the
  Arrest's operatives are huge black T-posed blocks that stand in front of the suspect.
- **Wrong or not seen:** the Arrest's suspect head is not lost at the end of the creep; the Outro's sweep camera has no
  head within 3 studs and nothing in the lens (it is 19 studs from the nearest face); the Oculus deal's close-up is not
  "all hair"; no visible wall or prop blocked any Oculus camera in open air (only invisible colliders did).
- **New:** the Verdict shows a seated person from behind and never their face; the Oculus deal's first 2 s are close to
  black and the over-shoulder frame shows a black silhouette with the player a few dozen pixels big; in a debug run the
  Outro's Ace turn only plays if the cue is sent by hand (the debug outro cue carries no timing).

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

In game: **Not checked, all of it** (2026-11-14). All three live maps have a Blender intro, and the debug panel's intro
plays that one, so the Luau version cannot be reached without a fourth map. Every line above is still from the code.

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

**In game (2026-11-14).** Watched in the Campus meeting room (everyone seated, the voted-out player in a chair),
Bureau HQ and Campus free roam, with the debug `verdict` cue on a bot; the camera was logged at 0.1 s steps in runs
without a screenshot, then stills taken at 3.4, 4.4 and 5.7 s.

- **Seen, 4.1 s: the cut and creep as predicted.** The camera is the player's until 4.1 s, cuts to the shot (fov 55, 8.2
  studs from the head), creeps to fov 42 and 5.1 studs by 5.9 s, and the player's own camera is back at about 6.05 s.
  The gavel and the red name are at 3.2 s (still at 3.38 s: "Marten" struck in red with three strokes, "Skip" with one,
  on a dark card about 540 px wide in the middle of the live room), so the cut lands 0.9 s after the gavel.
- **Seen, 4.1 to 6.05 s: the camera pushes in on someone who is vanishing.** The target's mean
  `LocalTransparencyModifier` (83 parts) is 0.06 at 4.1 s, 0.19 at 4.3, 0.31 at 4.5, 0.56 at 4.9, 0.69 at 5.1, 0.94 at
  5.5 and 1.00 at 5.7 s. Half-way through the creep (5.0 s) the person is about 62 percent gone (predicted 60); the body
  is gone from 5.65 s, so the last **0.4 s** of the shot (the audit said 0.3) has nobody in it.
- **Seen, 5.74 s: the close frame is an empty chair with the outline still drawn.** The white outline keeps tracing the
  vanished body's shape, static particles drift across, the chair back and armrests show, and the stamp "Their role
  stays secret" sits over the armrests. Nobody is in it; it is not empty of marks.
- **New, seen, 4.39 s and 5.74 s: the camera sees a seated person from behind.** In the meeting room the table is in
  front of the chair, `ShotSolver.frame` takes the first clear angle, and that is the chair back: the back of the head at
  4.39 s (static across it), the chair back at 5.74 s. The face never shows. (This is for this seat on the Campus;
  other seats may differ. A standing target in free roam was framed from the side, face hidden by the static.)
- **Wrong:** the head does not leave the frame. It stays at 754 to 776 px across and 310 to 325 px down of a 1507 x 619
  view for the whole creep.
- **Seen: the others' reactions are never shown.** One seated player's head touches the right edge of the 4.39 s frame
  and nothing else.
- **Seen, 3.38 s: the tally is a small text card**, the "part that works"; the stock stamp and lamps are the same as in
  the other scenes.
- **Not checked:** the tally's sound pile-up (no audio in the stills). The debug cue plays while the match is in the
  Meeting phase, so the phase's HUD text ("bureau meeting", bottom right) stayed on screen over the shot; in the real
  Verdict phase it may differ.
- **Verdict unchanged: small fix.** Add: frame the face (a seat-aware angle) and start the dissolve after the push-in.

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

**In game (2026-11-14).** Watched in the Campus meeting room (the suspect, a bot, seated), debug `arrest` cue, a
24-sample camera and actor log plus stills at 0.49 and 1.47 s. The suspect was not the Hand, so the stamp read "Innocent".

- **Seen, 0.35 s: the two operatives pop in on the cut.** No actor on the stage at 0.3 s, two at 0.4 s, at 2.6 studs
  either side and 1.4 studs in front of the suspect.
- **Seen, 0.4 to 2.9 s: they never move.** Their offsets are the same to 0.1 stud for the whole shot.
- **Seen, 0.49 s: they are huge, black and in the way.** The still at 0.49 s (under the glyph and the white flash) has
  two faceless black figures that together cover about half the frame, arms held straight out sideways (the `point`
  clip reads as a T pose at this size), standing between the camera and the suspect and hiding much of them. At
  1.47 s they are black masses on a dark room (the meeting room is dark); the suspect, outlined, is dim.
- **Seen, 0.49 and 1.47 s: no cuff on screen.** No cuff, no hand on a wrist, no operative reaching; the suspect is in
  the cuffed pose with the stamp over the chest. That is the scene's real fault, as predicted.
- **Seen: both operatives play the same clip** (the same arms-out pose, from the code's single `point` clip).
- **Wrong: the head is not lost at the end of the creep.** From 0.4 to 2.9 s the head stays at 729 to 753 px across and
  316 to 331 px down of a 1507 x 619 view; the camera goes from 9.2 to 5.1 studs (fov 55 to 44) and is given back at
  about 2.95 s.
- **Seen: an innocent is treated like the guilty** (same pose, lights and stamp, text "Innocent").
- **Not seen: any operative inside the table or a chair.** In the seated arrangement they stand in the aisle beside
  and in front of the suspect.
- **Not checked:** the handcuff and gavel sounds, and the four flashes' look (the stills were taken between flashes).
- **Verdict unchanged: rebuild.** The watch makes it plainer: what is on screen is two black T-posed blocks in front of
  the lens and a click.

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

**In game (2026-11-14).** Watched in the Campus meeting room (five bots seated) with a full `outro` cue sent by hand
from the Server DM (`winner = "Team"`, timing 5 / 3 / 2.5 / 5 s, four names written, 15.5 s in all); a camera log at
0.1 s steps, a nearest-head and lens check each step, stills at 2.52 s (sweep) and in the Manual at 5.4 to 7.5 s. The
debug panel's own `outro` cue carries no `timing` or Ace, so it plays only the sweep and the Hand's turn (see "How to
watch them").

- **Seen, 0.3 to 5.0 s: the sweep.** The camera stands at (0, 5.2, -3000), the meeting center the server sends, turns
  150 degrees and goes from fov 70 to 58. The nearest head is 19.4 studs away the whole time, nothing is within 1.2
  studs of the lens and nothing within 6 studs ahead of it. **Wrong: no head within 3 studs and nothing in the lens.**
  New: because the ring of seats is 10 to 20 studs from that spot, the faces are small (about 70 px wide in a 1884 px
  frame at 2.52 s), the room is dark and the sitters were still, so the sweep reads as a dim wide shot with a card
  ("The Bureau wins") over the floor, not a turn "across their faces".
- **Seen, 5.0 to 8.0 s: the Manual, and it is worse than predicted.** The page is 1.89 x 2.58 studs; at the end the camera
  is 1.65 studs from it at fov 36 and the page is about three times the frame's height, so only about **4 to 5 of the 18
  ruled lines** are in frame (the audit said 6.7; counted from the page corners projected to the screen and the height of the letterbox
  bars, not from the stills). With 10 names written the camera is aimed at the middle of rows 1 to 10, so about
  half of the names are out of frame. And **the whole Manual segment is a black frame under the game's normal
  lighting, with 10 names or with 2** (first run: four stills at 5.4, 5.5, 7.3 and 7.5 s with 10 names, only film grain
  inside the bars; a fresh Play session on Bureau HQ later: black at 6.9 s with 10 names and with 2), although the set
  was there (the Grimoire, the page with 8 labels at 7.0 s, the lamp enabled at brightness 4.3, the camera 1.7 studs over
  the page, the page corners on screen). **This replaces the first version of this line, which blamed the number of
  names: that comparison was confounded, because I had switched the grade, bloom, depth of field and atmosphere off
  between the 10 name and the 2 name runs** (the 2 name still at 7.1 s, "Aiko Tanaka, and Ren Sato struck through",
  dim but readable, was taken with them off). The cause is in "The black Manual, run down" at the end: the colour grade
  crushes a page that is lit by almost nothing.
- **Seen, 8.0 to 10.65 s and 10.7 to 15.2 s: Ace's turn and the Hand's turn are one shot twice.** Ace: cut at 8.2 studs
  from the head at fov 50, creep to 5.1 studs at fov 42. Hand: cut at 9.2 studs at fov 55, creep to 5.1 studs at
  fov 40. The two cuts stand 1.4 studs apart ((11.9, 6.1, -2996.0) and (10.9, 6.2, -2996.8)): the same tripod, panned 55
  degrees between two neighbouring seats. The camera is given back at about 15.2 s.
- **Seen: four sections, four timers.** Cuts at 5.0, 8.0 and 10.65 s, on the server's marks, not on a movement.
- **Not seen:** the Hand's card (the logger ran, no still was taken in the Hand's turn); the winners' and losers'
  cheer, dance and slump clips (the sitters in the stills were not acting; whether the cue starts them was not checked,
  they are in `ActingController`).
- **Verdict unchanged: small fix**, with the Manual's fit and its rendering as the first thing to fix or check.

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

**In game (2026-11-14).** Watched in Campus free roam (open air, no ceiling), the player at (120, 3, 3028) and at two
spots next to invisible colliders, debug `eyesDeal` cue; the camera, a line to the player's head, a part-in-the-lens
check and the Deathsinger's box logged at 0.1 s steps, stills at 1.10, 2.87, 4.10, 4.19 and 6.20 s. Not tested indoors.

- **Seen: the timeline.** Cut at 0.0 s (fov 52, 9.2 studs from the head), creep to fov 48 and 7.1 studs by 2.1 s; the
  over-shoulder cut at 2.2 s (fov 55, locked); the face cut at about 3.8 s (fov 40, 2.4 studs, locked); the wide cut at
  about 5.6 s (fov 52, 9.3 studs); the camera is given back at about 7.3 s. The three cuts land 0.1 to 0.15 s later than
  the code's 2.2, 3.7 and 5.45 s; the face shot lasts 1.8 s and the wide with the card 1.7 s.
- **Seen: three locked frames after one move**, as written (1.5, 1.75 and 1.75 s; measured 1.6, 1.8 and 1.7).
- **Not seen, hand-placed cameras (open air and next to invisible colliders):** in all three tests every camera had a
  clear line to the player's head and none was inside a part. The one blocked line was the over-shoulder camera behind
  an invisible `Collider` (5.5 of 9.7 studs, standing 3 studs from it), which cannot be seen. No visible wall or prop
  blocked a camera, and the one prop tested (a display case) does not collide at all. **The fault stays "possible,
  unconfirmed"**: it needs an indoor spot (a meeting room or office) to be seen.
- **Not seen, the Deathsinger through a wall or ceiling:** 8.5 studs at the start, 8.2 after the lean; its box
  overlapped only invisible colliders. The Campus is open air, so the ceiling case was not tested.
- **Seen: the player is not frozen.** `WalkSpeed` stayed 16 and the root was not anchored the whole cue. With a held
  forward input (camera-relative, as a held key is) the player was 16 studs from where they started by 1.8 s, and 48
  studs by 4.1 s in a second run. **At the eye ignition (3.95 s, the close-up is locked from 3.8 s) the 4.19 s still
  of that run shows the player's head at the left edge, its right side behind a stone pillar, walking out of frame**;
  the burst is on a body that is leaving. (Without a key the player stays put and the frame is as designed.)
- **Wrong: the face close-up is not "all hair" (still at 4.10 s, no key).** The head fills about a sixth of the frame
  width; the bangs hide the face, but the two red star flares sit where the eyes are, a red ring is round the head and the
  Deathsinger's grin looms behind at the upper left, its head cropped by the top bar. It reads as "eyes on fire". It is
  still level, locked and from straight ahead.
- **New, seen, 1.10 s: the opening is close to black.** The red tint, the vignette and the dimmed lamps leave a nearly
  black frame; the player is a dark mass in the middle, two small red sparks (the Deathsinger's eyes) are the only
  thing that reads. Your face is not readable in the first 2 s.
- **New, seen, 2.87 s: the over-shoulder frame is a black silhouette.** The Deathsinger's collar fills the left half as a
  black shape with a thin red outline and snow specks; the player is a few dozen pixels, behind a fence. It reads as
  "a shape", not as "it leans over you". (The lean itself was not looked at: a 0.9 stud, 10 degree tilt would not show
  at this size.)
- **Seen, 6.20 s: the card reads** ("The Oculus Of The Dead", "You can read names from afar. 2 minutes left to live."),
  on screen about 1.7 s; the kicker "Deal made" is tiny (about 10 px high). It sits over the player's lower body in a
  frame where the player is already a dark shape.
- **Not checked:** the sounds (`eyesOpen`, `hauntWhisper`), the bolts' look (the 4.10 s still shows the flares and the
  ring), the 0.5 s start.
- **Verdict unchanged: small fix.** The first fix is to freeze the player (cheap and it saves the key shot); then the
  dark opening and the silhouette frame; the camera clearance check can wait for an indoor test.

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

**In game (2026-11-14).** Watched in the Campus meeting room with a `manualWrite` cue sent by hand from the Server DM
(`name = "Kenji Mori"`, no writing style, so plain ink); stills at 0.48 and 1.53 s. **These stills were taken with the
game's colour grade (and bloom, depth of field, atmosphere) switched off on my client, so they show the best case.**
Under the normal grade the same shot is a black frame (see "The black Manual, run down" at the end), so the numbers
below are rough and the page is darker in the game than in them.

- **Seen, 0.48 s (grade off): the first frame is near black.** The page's outline is barely there, no name has
  appeared. (The set exists from the cut; it is the exposure, not an empty frame.)
- **Seen, 1.53 s (grade off): the name is finished and the page is dim.** "Kenji Mori" is fully written, in dark grey
  ink on dark brown paper, about 160 px wide and 30 px high in a 1884 x 774 frame, **about 4 to 5 percent of the frame
  height** (the audit said 5 to 10): readable, low contrast, small. The writing is done between 0.48 s and 1.53 s,
  consistent with the code's 0.7 s; the camera keeps creeping for the rest of the 2.6 s. **With the normal grade the
  1.43 s frame is black** (fresh Play session, Bureau HQ, grade contrast 0.46 and saturation -0.60).
- **Not checked:** any sound with the plain ink (no audio in the stills), and the exact second the name ends. Nothing
  else was on the page at 1.53 s, so **no mark, bleed or last-stroke beat was seen** with the plain ink, as predicted.
- **Not seen as a fault:** the set built at y 1500 loads at once (no empty first frame).
- **Verdict unchanged: small fix**, but the first thing to fix is the light: the page must be lit enough to survive the
  grade (the lamp does not seem to reach it at all, see the end), or the shot needs its own grade.

## Summary and order

| Scene | Verdict | Why in one line |
|---|---|---|
| Case opening | leave alone | not played by any live map (not watched) |
| Verdict | small fix | the cut lands late, the camera pushes in on a person who is dissolving, from behind, ending on an empty chair |
| Arrest | rebuild | nothing physical happens on screen: two black T-posed blocks in front of the lens, no cuffs seen |
| Outro | small fix (the rest is Stage 3) | one recipe twice from one spot, the Manual segment is a black frame under the normal grade and shows only 4 to 5 lines, the sweep is a dim wide shot |
| Oculus deal | small fix | the beats are good; three locked frames, the player is not frozen (a held key walks them out of the key shot), a near-black opening |
| Manual writing shot | small fix (light first) | black under the normal grade, the page is not lit by its lamp; the writing is done in the first second, the name small, the plain ink has no pen |

If the owner wants them done after the Stage 1 list: the Oculus deal and the Verdict first (smallest, most seen by one
player each), then the Manual's pace, then the Outro with Stage 3; the Arrest is a Blender scene of its own. The watch
adds two things to do before any of that: the Manual set's lighting (the shot is black under the normal grade, with any
number of names) and the Oculus deal's freeze, both small.

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

**Second try, same day, with the owner's yes to the screen** (Studio in front, 54 fps, `screen_capture` then showed the
3D and the game's screens; the Debug cues worked after a match with bots was started and `skipTo` Investigation was
sent): one measurement only before the usage limit ended the session. The Verdict cue for a bot, logged from the
client at 0.25 s steps, cut to the 3D shot at about 4.1 s, crept from fov 55 to fov 42 and gave the camera back at
about 6.0 s. That matches the code's timeline above (the cut, the creep and the end). Not yet measured or seen: the
dissolve against the push-in, the frames of any scene, the Arrest, the Outro, the Oculus deal, the Manual shot. A
caution for the next try: the match's own intro and briefing cutscenes hold the camera for a while after `startMatch`,
so wait until the camera type is Custom for 4 s before a cue (**corrected by the third try below: the camera type reads
Custom during the intro, wait on the cue's clock instead**), and read the bot's model from `workspace` by its
`BotUserId` attribute.

## The watch that was done (2026-11-14, third try: five scenes seen)

A session with the owner's "yes, screen ok" (asked once in chat) brought Studio to the front
(`WScript.Shell.AppActivate(<pid of RobloxStudioBeta.exe>)` returned True this time; 60 fps, checked with a 2 s
`RenderStepped` count), started Play through the MCP, ran the cues described in "How to watch them", and stopped Play
again (`get_studio_state` says Edit; nothing in the place was edited, and nothing in the scenes' files was touched).
It saw the Verdict, the Arrest, the Outro (sweep, Manual, Ace's turn and the Hand's turn), the Oculus deal and the
Manual's writing shot. It did not see the case opening (not reachable), the sounds (no audio in the stills), the Hand's
card in the Outro, the Oculus deal indoors, or any Outro Manual with 3 to 9 names. The stills were not kept (a few
hundred KB each, not committed); the "In game" blocks describe them. What got in the way, in the order it was found:

- The match's own intro and briefing hold the camera for about 20 s after `startMatch`, but `CameraType` reads `Custom`
  while they do (the cutscene sets the camera's CFrame itself): wait on the cue's own clock, not on the camera type.
- Bots wander in free roam and the phase timer runs, so a target walks away, a phase changes under the cue (everyone is
  teleported to the meeting room) and bots die on their own ("Name the next Ace" covered a whole run). Fix: skip to the
  `Meeting` phase straight after `startMatch`, send `pause` once (it toggles, and it survives `skipTo`), and anchor the
  bots' `HumanoidRootPart` from the Server DM if they must stay still in free roam.
- **A `screen_capture` seems to disturb the camera it is taken in.** In all four runs that had a still, the camera log
  showed the camera pulled back toward the player's own camera from the moment of the capture (the fov creep went on,
  the position did not); the runs without a still (Verdict twice, Oculus, Arrest, Outro) were clean. So: log the numbers
  in runs with no capture, and take
  the stills in separate runs; a still is true at the instant it was taken.
- The debug panel's `outro` cue sends no `timing`, `aceUserId` or `lead`, so the Ace turn never plays from it.

## How to watch them

The Studio MCP (`mcp__Roblox_Studio__*`) is allowed by the owner (2026-11-14, and the screen too, asked again each new
session); a session that watches should first run `list_roblox_studios` and `get_studio_state` and leave it alone while
another session is in Play. The recipe that worked, from the Client DM's `execute_luau` unless it says Server:

- Bring Studio to the front, `start_stop_play true`. Fill and start a match:
  `f = game.ReplicatedStorage.LGameRemotes; f.Debug:FireServer("fillBots", {total = 6}); task.wait(2);
  f.Debug:FireServer("startMatch")`, then `FireServer("skipTo", {phase = "Meeting"})` and one `"pause"`. Bots are models in
  `workspace` with a `BotUserId` attribute (-1001 to -1005). `f.GetSnapshot:InvokeServer()` gives the real state.
  Wait about 20 s for the intro and briefing cutscenes before a cue.
- A clock and a logger in `PlayerGui`: a ScreenGui (DisplayOrder 10000) whose label reads
  "kind t=3.82" from the last `Cue` remote's `at`, and a `BindToRenderStep` at `Last + 1` that logs the camera's
  position, look, fov, type and the thing you are checking every 0.1 s into `_G`.
- A still at a chosen second: one `execute_luau` that fires the cue, waits until the cue's clock is 0.2 s short of the
  second you want and returns, then `screen_capture` in the same message (the capture follows within about 0.1 s).
- Debug cues from the Client: `f.Debug:FireServer("cue", {kind = "verdict", userId = -1002})`, `{kind = "arrest",
  userId = -1003}`, `{kind = "eyesDeal"}`, `{kind = "outro", extra = "Kira"}` (sweep and Hand's turn only, no names).
  `intro` plays the Blender shot.
- Cues with their full data (the Ace turn, names in the Manual, `manualWrite`) are sent by hand from the **Server** DM:
  `f.Cue:FireClient(game.Players:GetPlayers()[1], {id = 0, matchId = 0, kind = "outro", at = workspace:GetServerTimeNow()
  + 0.3, data = {winner = "Team", center = Vector3.new(0, 0, -3000), written = {{name = "Aiko Tanaka"}, {name = "Ren
  Sato", struck = true}}, duration = 15.5, timing = {opening = 5, book = 3, ace = 2.5, hand = 5}, handUserId = -1003,
  aceUserId = -1002, lead = -1002, leadAlias = "Marten", winners = {...}}})`. `id = 0` always passes the router; the
  centre of the meeting room was (0, 0, -3000) on both maps tried. `manualWrite` takes `data = {name = "Kenji Mori"}`.
- To test the Oculus deal's walking, bind `hum:Move(Vector3.new(0, 0, -1), true)` on `RenderStepped` before the cue.
- `docs/handoff/harness` is for pictures of Blender shots and deaths and needs its paths fixed on this machine (see
  `docs/agent-memory/harness-paths-stale.md`).
- Still to look at: the Oculus deal indoors (a meeting room, an office: walls and a low ceiling near the player), the
  Outro's Hand card, any sound, and why the Manual's lamp does not light its page (see the next section).

## The black Manual, run down (2026-11-14, later the same day, at the owner's yes)

Question: why was the Outro's Manual segment black with 10 names? Answer: **it is black with any number of names, under
the game's normal lighting; the first note (10 names black, 2 names dim) was a confounded comparison.** A fresh Play
session on Bureau HQ (Meeting phase, paused, stills at 6.9 s of a hand-sent `outro` cue and at 1.4 s of a `manualWrite`
cue, grade state set only through the Client DM's `Lighting` children):

| Run | Grade | Lamp | Result |
|---|---|---|---|
| Outro, 10 names, 6.91 s | on (contrast 0.46, saturation -0.60) | 4.3 | black |
| Outro, 2 names, 6.90 s | on | 4.3 | black |
| `manualWrite`, 1.45 s | on | 17.2 (4 times) | black |
| `manualWrite`, 1.43 s | **off** | 4.3 | page visible, dim brown, grey ink, "Kenji Mori" readable |
| `manualWrite`, 1.38 s | **off** | 17.2 (4 times) | the same dim page, no brighter |

**Corrected 2026-11-15, when the owner said "manual yes" and the cause was run down properly (the table above is still
true, its reading was not).** The grade is only an amplifier. The real causes, all seen in a Play session:

- **Cause 1: the shot is lit by the wrong look.** The Manual's set stands at (0, 1500, 300). `Venues.at` classes that as
  the lobby, so on the cut the lighting controller does nothing for about 1.8 s (the meeting's look stays on: ambient
  0.03, exposure -0.5, contrast 0.53), then blends over 3.5 s (`BLEND`) into the lobby's look (Lighting.Brightness 1.3,
  ambient 0.22, the Grey Realm's sky and afternoon clock, haze 2.1). Logged every 0.5 s through a 12 s shot. A 2.6 s
  writing shot or a 3 s Outro book lives entirely inside the dark part; the page only reads from about 5 s, by the lobby's
  sky light.
- **Cause 2: the set's lamp lights nothing, at any brightness.** BookStage's PointLight (range 9, 3.2 studs over the page,
  enabled) left the page black at brightness 4.3, 17.2 and 40 (range 20); a visible Neon bulb with its own PointLight 1.2
  studs over the page did too, while the same kind of light lit the stone floor in the lobby at ground level. Why it does
  not light the page is not found (suspects: the altitude, the 60 x 60 lid and floor, the page's PBR surface). The sun
  does not reach the page either (Brightness 1.3 with a dark ambient: black). The page is lit by ambient and sky light
  only, which the grade (contrast 0.46 or 0.53) then crushes when it is low.
- **The fix (src, 2026-11-15):** a scene look of the set's own, the way the death scenes light their far-off sets.
  `LightingPresets.scenes.manual` (ambient and outdoor ambient rgb(176, 170, 164), env diffuse 0.5, saturation -0.4,
  contrast 0.12, a warm tint, bloom 0.4; the floor and lid are near-black parts, so only the book reads); `BookStage.play`
  calls `LightingController.scene("manual")` before it builds the set (the look is applied at once, no blend) and its stop
  function puts it back with `task.defer`, once the caller has moved the camera on and only if the look is still
  "manual" (new `LightingController.currentScene()`), so a scene death that follows the book keeps its own look. The
  lamp is kept but no longer scaled by the exposure read at build time (the shot's exposure is 0 now).
- **Seen with the look forced (stills, the page lit as the new look lights it):** the writing shot at 0.28 s (the name
  being written, the ruled page already readable) and at 1.5 s ("Kenji Mori" legible, black around the book); the Outro's
  Manual with 10 names at 2.3 s (every name readable, the struck ones crossed out, black around). Before the fix the same
  shots were black at 0.35, 1.0, 3.0 and 7.0 s. No veil from black is needed at the start: the page shows from the first
  frames once the look is its own.
- **Not verified, needs the owner's Rojo sync:** the new code itself ran nowhere. The place's scripts are older than the
  repo and cannot be written from here, so the look's values were forced onto `Lighting` and the grade every frame from
  the cut (the real controller tweens the same properties), on a BookStage copy. To check after the sync: the first frame
  and the end of the writing shot and of the Outro's book (the world's look must come back at once, with no flash up or
  3.5 s blend), the Ace turn right after the Outro's book, a death by the Manual into a scene death (it must keep its
  look), and the Hand-won red wash (`Cinema.tint`, its own effect on the camera) over the page.
- **Verdict for the Manual shots:** the black frame is fixed at its cause in the set's own lighting, nothing global
  changed. What is left of the audit's list for them is the fit (about half the names out of frame at 10 names behind the
  letterbox) and the pace, as written above.
