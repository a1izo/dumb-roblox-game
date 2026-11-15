# Ryuk (the "Specter" model): what he is, how the two scenes move him, what is possible

Written 2026-11-14 for the owner's decision. It answers their words: "rolediavolo, mm i think its mostly how stale the
camera is when its not camera pov, and also how ryuk appears and how stiff he is but thats because im guessing he is
not rigged, that goes for the eyes deal animation too". Nothing in this file has been built: no rig, no model change,
no change to the Oculus deal. The one thing that was changed is the camera work and Ryuk's whole-body motion in
RoleDiavolo (section 6), because that needs no model change and no Luau.

In the code and the catalog he is called `Specter` (the model), "the Deathsinger" in the scene comments and on the
screen. Do not confuse him with the player "Specters" (the dead): `Models.specter()` is only this figure.

## 1. The answer, in plain words

**The owner's guess is right.** Ryuk has no rig. He is one finished sculpt that was exported as eight solid pieces
glued in place: no bones, no joints, no way to bend an arm or turn his head. The game can only move him the way you
move a statue: slide it, turn it, tip it, all of him at once. That is also true in both scenes where he appears (the
Diavolo role card, the Oculus deal). He is used nowhere else.

But "stiff" has three causes, and only one of them is the missing rig:

1. **No rig** (cannot be fixed without a model change, sections 4 and 5).
2. **How the scenes moved the block.** RoleDiavolo rocked him between two poses every 0.24 seconds, tipping him about
   his *toes* (so his hips and head swung like a plank on a hinge) at one steady rate. The Oculus deal stands him still
   for 1.9 seconds, then tips him forward 10 degrees about his toes once, and that is all he does. A statue that is
   moved like a statue reads as a statue.
3. **He is never seen forming.** In RoleDiavolo the whole drawing-in of him happened while the camera was tight on
   Diavolo's face, so the viewer saw nothing of it, and at the next cut a finished, motionless Ryuk was simply there.

Two and three are fixed (or fixable) with no model change, so the owner can already judge how far the cheap route
goes. What is left after that is the part only a rig can fix: his arms never move, his head never turns on its own.

## 2. How he is built

Source: `art/scripts/props_specter.py` (the body), `art/scripts/specter_head.py` (the head and the hair), one
`@prop("Specter", ...)` in the `Core` set; exported in `art/export/DeathsGambitModels_Core.fbx` (15 MB, with every
other Core prop; Open Cloud uploads stop at 20 MB), catalog entry `Specter` in `src/shared/ModelCatalog.luau`
(`size = 5.443 x 9.15 x 3.15`, 78,738 triangles, `pivot = "bottom"`, `collide = false`, `parts = { "Face", "Hair",
"Collar", "Gear" }`, `hinge`, `turn` and `page` all empty).

Read in the live place (Studio MCP, read only, 2026-11-14), `ReplicatedStorage.DeathsGambitAssets.DeathsGambitModels_Core`
holds exactly these eight MeshParts for him, all `Anchored`, no `Weld`, no `Motor6D`, no `Bone`:

| Piece | What is in it | Notes |
|---|---|---|
| `Specter` | the body: torso, shoulders, both arms to the claws and rings, both legs, the stapled neck and its flap, the chest sculpt | one mesh, 3.4 x 6.7 x 1.4 studs; the model's primary part |
| `Specter_Face` | the head shell, eye sockets, teeth, gums, lips, the steel in the face | 1.45 x 1.46 x 1.37; sits on the neck top, overlapping it about 0.5 stud |
| `Specter_Hair` | the cap and the spiky blue locks, nothing below the skull | |
| `Specter_Collar` | the mane of about 90 long black quills off the shoulders and back | roots at the shoulders |
| `Specter_Gear` | the belt, the skirt, the chain with its skulls, the holster and the Manual in it, the wrist bracelets | |
| `Specter_Glow`, `_Glow2`, `_Glow3` | the eyes, the red irises, the pale ring stones on a finger | the first two are in the head, the third is on a hand |

His pose is baked: hunched forward, the neck thrust out, the elbows bowed out wide, the clawed hands hanging by the
knees, the feet drawn out to points (he floats). It is one pose, about 9.15 studs tall to the top of his hair
(`ModelLibrary` scales him to the catalog size). Textures: body 512, face 512, hair 512, collar 128, gear 256
(`props_specter.py`: the Core set loads in every scene and has a pixel budget).

The body is built in code from a skeleton of joint points (`Skeleton` in `props_specter.py`: a spine chain, two
shoulder chains, two leg chains, finger chains) and skinned into **one** surface, so the joint positions exist, but
nothing about them survives the export. The pieces other than the body exist so each could carry its own texture, not
so they could move (the same mechanism lets the Manual's board and leaves turn, which is why `hinge`, `turn` and
`page` exist in the catalog; they are empty for him).

If the import is missing, `Models.specter()` builds a stand-in from ordinary Parts (a cloak, a hood, a skull, wings).
The imported model is what the game uses today.

## 3. How the two scenes move him

### RoleDiavolo (`art/scripts/cinema/shots/role_kira.py`), before

- `shot.prop("Specter", show=(11.2, 15.6))`: the model is added to the stage when the window opens.
- Eight path keys, each a position and three angles (Euler, about his pivot at his toes): at 11.2 stood at the back wall
  (-2.6, 0.2, -9.6); at 13.8 a pitch of 10 degrees, yaw 174; then six keys 0.24 seconds apart, 13.9 to 15.1, flipping
  between pitch 12 and pitch 7 with a lift of 0 and 0.25 stud. The game lerps between the keys (`CFrame:Lerp`).
- So he stood almost still for 2.6 seconds, then rocked back and forth six times, 0.24 seconds apart, the same size
  each time (a metronome), about his toes, which swings his head more than his hips. Nothing about him ever turned, rose, swayed or leaned toward the lens.
- The effect events: `materialize` at 11.2, 1.4 seconds, red (200, 30, 45); a red spot from below behind him, on at
  11.2; a red point light at 13.1; sounds `wisp` at 11.5 and `hauntWhisper` at 13.3.

### The Oculus deal (`src/client/Presentation/Presenters/EyesDeal.luau`, 7.2 seconds, nothing changed)

- `summon`: `Models.specter()` placed 2.6 studs behind the player and 0.6 to the right, facing where the player faces,
  scaled to 8.5 studs tall (`ScaleTo`), feet on the floor.
- 1 (2.2 s): a camera in front of the player at 9 studs, 2 to the right, 0.6 up, aimed past the player to where his head
  will be, easing in to 7 studs over 2.2 seconds; `Materialize.appear(1.9 s, red)`; after 0.35 s two red flares at his
  eyes. Then 1.85 s of him standing still.
- 2 (1.5 s): a locked camera low over his shoulder, 55 degree lens. The only motion he ever makes: one `Clock.tween`
  (1.4 s, in out sine) forward 0.9 stud, down 0.2, and a pitch of -10 degrees about his toes.
- 3 (1.75 s): close on the player's face, locked, 40 degree lens: he is not in it.
- 4 (1.75 s): a locked wide, the player's side, 52 degree lens; `Materialize.vanish(1.1 s)` and 24 feathers.
- So he moves once, the same way every time, for 1.4 of 7.2 seconds, and three of the four cameras do not move at all.

### How his entrance works (both scenes use the same code)

`Presentation/Materialize.appear(model, {seconds, color})`: it sets every part of the model fully transparent; red smoke
and sparks are pulled in toward him in a box; the edges are lit red (`Vfx.Rim.glow`); then over `seconds` (in out
sine) a front climbs from below his feet to above his head, and each part becomes visible by where the part's **centre**
stands on the model (0 feet, 1 top), through a band of 0.35 of his height; at the end a flare and a light flash.

What makes it read badly:

1. **It is a dissolve of eight parts, not a wipe up the body.** The wipe works per *part* (`item.Position.Y`), and he has
   eight parts. The body (feet to shoulders, one mesh, centre at 0.37 of his height) fades in as one slab; the belt and
   skirt (0.4) with it; the mane (0.7); then the head, hair and eyes (0.76 to 0.8) last. The "from his feet up" is
   really "the body, then the head". There is nothing to subdivide without a model change.
2. **The old RoleDiavolo timing hid it.** The materialize started on the bite (11.2, as the owner asked on 2026-10-28)
   and ran 1.4 seconds, to 12.6. The bite shot (cut E, 11.2 to 12.8) was a tight low crop of Diavolo's face, so almost none
   of it was on screen (the renders of 11.1 to 12.7 show only a few black quills at the left edge), and the cut to F at
   12.8 found him whole, standing, with the flare already spent. To the viewer he popped in at the cut.
3. **He is lit and drawn all at once.** The red spot came on at full at 11.2, the red point light at 13.1, and a red
   still frame (the crunch) at 11.4: three reds at once on the bite, then nothing else changes about him.
4. **The Oculus deal's version is on camera** (cut 1 sees the forming) but with the same per-part dissolve, and then he
   stands motionless for 1.85 seconds before the one lean.

## 4. What is possible

### Option 1: move him as a whole, no model change

What a statue can do: rise and fall (float), tip and sway, turn, lean toward the lens, drift forward. Done well it
reads as a creature (a slow breath of height, a lean in on the laugh, the lag between two beats), done badly it reads
as a plank (the old scene). The one rule: **turn him about his hips, not his toes** (the pivot is at his feet, so the
position has to be corrected with the rotation: `ryuk()` in `role_kira.py` does it).

- Cost: Python only, no import, no Luau, no version bump. It is what section 6 did in RoleDiavolo.
- The same Luau-free route is **not** available in the Oculus deal: its motion is hand-written in `EyesDeal.luau`.
  Changing it is a small Luau change (a few lines), which the owner has not cleared yet.
- Limit: arms and head never move on their own. Nothing here makes his arms do anything.

### Option 1b: move the pieces that already exist as separate parts

Because he is eight separate MeshParts, four things can move relative to the body **with Luau only, no model change,
no import, no version bump**:

- **the head** (`Specter_Face` + `Specter_Hair` + `Specter_Glow` + `Specter_Glow2`, turned together about the neck
  top): a slow turn toward Diavolo then toward the lens, a tilt, a nod on the laugh;
- **the mane** (`Specter_Collar`): a few degrees of sway, a beat after the body (hair and cloth follow-through);
- **the gear** (`Specter_Gear`: skirt, belt, chain): a swing about the hips, another beat late;
- the body itself, as option 1.

The neck is known in the model's own coordinates (the FBX origin is kept as each part's pivot: `Specter_Face` reports a
`PivotOffset` of about 7 studs below its middle, i.e. the model's feet; the neck top is at 6.7 studs, 0.9 studs
forward of it, from `props_specter.py`), so no new marker is needed.

- What it takes: a per-frame `CFrame` write on those parts (a sub-pose for a prop: the data in the exported shot
  (`subs` next to the path in `Cinema/Shots/<Shot>.luau`), a small change to `ShotPlayer.luau`, and a few lines in
  `EyesDeal.luau`; a module for both so the two scenes share it). About a day with its tests. No asset work.
- Cost to check before relying on it: the head shell overlaps the neck by about 0.5 stud; a yaw of about 25 degrees and
  a nod of about 15 degrees should keep the neck inside the shell, but I have not looked at it live. Beyond that the
  neck stub shows. That decides how big the head's moves may be.
- Limit: arms, hands, legs and the jaw stay as modelled. He is the same pose, with a head that turns and cloth that
  follows.

### Option 2: rig him

Two ways, neither small. Both need the owner's yes first (the plan's "stop and ask": a new model import).

**2a: cut him into jointed parts** and animate them with the machinery the players use. Every cutscene body is an R6:
`Joints.R6` names six Motor6Ds (the root, the neck, two shoulders, two hips) and `ClipPlayer` writes a CFrame to each
every frame; the acting kit (`animlib.J`, `body_reach`, `check_motion.py`, `review_strip.py`) is built around those six
joints. If Ryuk were built as a Torso, a Head, two Arms and two Legs welded by Motor6Ds named like R6's, **the whole
existing machinery would drive him unchanged**, scaled to nine studs: the same clips, the same reaches, the same
checks.

- Modelling: in `props_specter.py` the body is already built from joint points, so the arms, legs and the upper body can be
  built as separate meshes from the same joints (about eight pieces: upper body with the stapled flap, two arms with the
  claws and bracelets, two legs, head with hair, mane, belt and skirt). Their normal maps are baked from the high-detail
  copies today; each new piece needs its own bake, and the Core set's texture budget is fixed (about 1.6 megapixels in
  all: whether new pieces can share the body's texture is **not known**; check `props.piece` before starting).
- Export and import: re-export Core (`run_props.py -- --export --set Core`; beware `props-blend-can-be-stale.md` and
  `export-restores-binaries.md`), upload by Open Cloud (`imports-by-open-cloud.md`; the file stays under 20 MB only if
  the new pieces are about as heavy as the old body) or the owner's Studio importer, share with the universe, bump
  `ImportVersions.ModelsCore` (39 now), regenerate `ModelCatalog` with the new `parts` list.
- Luau: a builder that welds the pieces with Motor6Ds at the joint points, and a Specter actor in `ShotPlayer` (actors
  are Humanoid characters today); in `EyesDeal.luau` the single tween is replaced by a clip played on the rig.
- Then acting for two scenes (a laugh, a lean, a reach, a turn), checked with `check_motion.py`.
- Cost: several days (modelling and baking, one import cycle, Luau, acting in two scenes) and it risks the texture and
  triangle budgets and the calibration of a new import. R6 limbs have no elbows or knees; his arms are long and bowed, so
  as rigid segments they swing like boomerangs; the machinery's tricks for fake length (a sliding joint) cover that.

**2b: one skinned mesh with bones** (Roblox supports a `MeshPart` carrying `Bone` instances, with `Bone.Transform`
written like a Motor6D's). It keeps one mesh and gives smooth bends, elbows included. **Nothing in this project uses it
yet and I have not tested it.** Unknowns: whether the Open Cloud upload route (the one `imports-by-open-cloud.md`
describes) keeps the bones, how a 78,000-triangle skinned mesh costs on the phones the game supports, how the
`Materialize` transparency pass behaves on it. A one-cube test (a skinned cube through the same upload and a Studio look)
would answer the first in an hour and should come before any commitment.

### Option 3: other ways

- **Hide it.** What helps a stiff model most is to never show him whole, lit evenly and still: a moving camera, parallax
  (something in front of him), a dark key with a red rim, smoke at his feet since he floats (`Vfx.Emit`), the mane
  dissolving into the dark. This is mostly what the new RoleDiavolo cameras do (section 6).
- **Pose variants.** The body is generated from joint points in code, so a second or third *pose* of the same
  Ryuk (arms flung wide for the laugh, a hand raised) is only different numbers and a re-export, with the same textures
  and no rig. A cut between two poses hides the swap. Each is a new model in Core, so it is a model import (the owner's
  yes), and it gives "he moves" only across cuts, never within one.
- **Draw the entrance better in Luau** (a change to `Materialize`): a clipped wipe up the body would need his body mesh in
  slices; with one mesh the honest options are a longer fade, a mask (a shader-free trick: a growing "cloth" of smoke
  parts that hides the lower body, uncovered upward) or a fade from the head down. Any of them is Luau only, nothing to
  import.

## 5. What I recommend

1. **Do option 1 in both scenes now** (RoleDiavolo is done; the Oculus deal needs the owner's yes to touch its Luau).
2. **Then option 1b** (a head that turns, a mane and skirt that follow). It is Luau only (about a day), needs no
   import or version bump, and it adds the one thing the viewer feels missing in a face that grins and never looks at
   anything.
3. **Look again.** If the owner still calls him stiff after 1 and 1b, the next step is the one-cube skinned-mesh test (2b),
   because a rig by pieces (2a) costs more than a full skeleton and bends worse. If the owner says he is fine, stop at
   1b: he is on screen for about 4 seconds in one scene and about 3.5 in another, and a rig is days of work for that.

Do **not** build option 2 for the sake of these two scenes without the owner's choice: it is the biggest piece of work
in this file, it needs a model import, and it changes how Ryuk is made for good.

## 6. What changed in RoleDiavolo (option 1 and the cameras)

**Checked:** `run_cinema.py -- RoleDiavolo --clear` 0 problems; `--lint` only close-up `[frame]` notes that are meant (the
insert B, the close C, the side camera's cut, the two stacked faces of F); `check_motion.py` unchanged (the acting was not
touched); stills of every non-POV cut at three moments each; spacing strips of E and F. **Not seen: the scene in the game.**
No Studio was connected during this work, and the new shot data is not in the place (only the owner's Rojo puts it there).
The Blender previews do not show the materialize, the effects or the lamps' flicker, so the entrance's look in the
game is judged from the code, not from a picture.

Only `art/scripts/cinema/shots/role_kira.py` and the exported `src/shared/Cinema/Shots/RoleDiavolo.luau`. The story, the
cuts (3.2, 5.4, 7.0, 8.2, 11.2, 12.8, 15.6), their lengths, the voice timing, the three hidden-camera shots and every
effect that was there are unchanged; Diavolo's acting (the clip) is untouched.

- **Which shots are camera-POV:** A (0 to 3.2, CAM 01), the side camera S (7.0 to 8.2, CAM 03) and G (15.6 to the end,
  CAM 02): the hidden cameras, locked off on purpose with the REC and the time (the `cctv` effect). Not touched. The five
  others (B, C, D, E, F) are the owner's "stale" ones.
- **The old five** were all one move: a slow creep or push from the front at a head-and-shoulders size (C 3.9 studs and
  D 6.8 studs straight in front of him, E 3.5, F 7.6), B a low insert that was almost all arm. There was nothing in
  front of the lens, no change of side or size between them, and the lens never found Ryuk.
- **The new five** (each a held camera on its own path: `held()` in the file, the spring and breathing of
  `framing.pan(operator=True)` on a path that may bend, aimed at the real head at that time):
  B from above and in front of him, dropping toward the nib as the name is written; C from his left, a long lens (33 to
  28) easing in on the eyes coming up; D low from his right and further back, with the lamp's glow across the foreground,
  trucking in across it as the crisp is raised; E tight and low from straight in front on the bite, then pulled out, round
  to his right and down while the look slides from his face to the space between them, to find Ryuk forming behind the
  chair (from his right Ryuk stands clear of Diavolo's head; from his left he hides behind it); F low and close from in
  front, a little to his right, rising, both faces in the frame.
- **Ryuk's entrance:** he forms on the bite as before, but now the materialize lasts 2.4 seconds, so the body is drawn
  in during E's pull-out, and the head and eyes (the last parts in) arrive in the first half second of F, with sparks at
  his eyes and a pulse of the lens as the head fills; he rises from the floor and steps forward out of the wall as he forms
  (about 0.9 stud back to the spot); the red comes up in three steps and wavers (three lamps on a beat apart) instead of
  switching on whole with the crunch.
- **His laugh:** turned about his hips, not his toes; heaves in uneven runs (four, then three) with a held breath
  between them and each a different size (the gaps between turns of his lean run 0.22 to 0.53 seconds; the old scene's
  were all 0.24), the lean creeping in over his shoulder from 7 to 13 degrees, a slow sway and a slow float under it,
  the laugh dying away as the shot ends.

## 7. The Oculus deal: what I would change once the owner says yes (not changed)

Four cameras, three locked, none shows a reason to move; he moves once. The list, in order of value:

1. Give each of the three locked cameras a move and a breath (the `CameraDirector.move` calls and a slight hand drift),
   as RoleDiavolo's. Cut 2 (the lean) is the shot that most needs it: a slow rise as he comes down.
2. Replace the one 1.4 second plank-tip about his toes with the same motion as RoleDiavolo's Ryuk: a lean about his hips
   (a few lines in `summon`'s tween: the `CFrame` to rotate about a point), a sway, a float.
3. Have the eyes light first as the code comment says (`eyesOf` fires 0.35 s into the appear; with the per-part fade
   the head is not visible until about 65 percent of the way through, so the flares fire before there is a head: move
   them to 0.65 of `seconds`).
4. If the owner chooses option 1b: the head turns to the player on cut 2.

Nothing in this list is hard (an hour or two), but it is Luau in a scene the owner has not cleared, so it waits.

## 8. For the owner to choose

1. Is the new RoleDiavolo (cameras and Ryuk's entrance and laugh) better? If yes, may the Oculus deal's cameras and his
   lean get the same treatment (section 7)?
2. May I do option 1b (a head that turns, a mane and skirt that follow), a Luau change, no import?
3. Is a full rig wanted at all, given how little he is on screen? If yes, 2b's one-cube test first, with the owner's yes
   for the Studio import.
