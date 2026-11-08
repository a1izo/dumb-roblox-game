# Handoff: the scene deaths rework (started 2026-11-08)

## For the next Claude: paste this to start

> Read docs/handoff/scene-deaths-rework.md in full, then docs/agent-memory/INDEX.md and the shot sheets in
> art/refs/deaths/. The scene deaths (src/client/Presentation/SceneDeaths/) work and are synced, but their sets are
> built from code primitives and look low quality. Model every scene's set in Blender like the game's other sets
> (section "The user's next verdict" below says what each needs), light them like the maps, import them, and point
> SceneDeaths at them. Copy the references 1 for 1. Test with the harness probes named below and compare frames
> against the sheets before calling it done.

The whole previous conversation (every message, tool call and picture) is exported at
`C:\Users\negru\Downloads\session-export-1794141328128.zip` (95 MB, too big for git); its raw transcript is
`C:\Users\negru\.claude\projects\C--Users-negru-Documents-Lgame\1006243a-657a-4ece-83f7-f284b1514138.jsonl`.
The harness (run.ps1; probes Scenes, ScenePics, Gallery, Deaths) is in
`C:\Users\negru\AppData\Local\Temp\claude\607a96825a4aa8f9\1006243a-657a-4ece-83f7-f284b1514138\scratchpad\harness`
(tools/ beside it: rojo, stylua, selene). The place sync generator is in
`C:\Users\negru\AppData\Local\Temp\claude\c9df517f12cfcae6\1006243a-657a-4ece-83f7-f284b1514138\scratchpad\sync`
(make_sync.py + pass.ps1; set SINCE_COMMIT to the place's last synced commit, now 31e49b56). Copy these out of Temp
if they matter: Windows may clean it. Copies of the harness scripts and the sync tools are in docs/handoff/harness and docs/handoff/sync (run.ps1 builds the throwaway place from a repo path: set AUDIT_REPO; it expects tools one folder up for rojo).

This file is for whichever Claude picks this task up next (the user may switch accounts when the weekly limit runs
out). Read it all first, then `docs/agent-memory/INDEX.md`, then the shot sheets in `art/refs/deaths/`. The previous
session's transcript export is listed at the bottom.

**Rule from the user:** stop working at once at 97% weekly usage, after saving progress here (commit + push).

## What the user asked, word for word (2026-11-08)

> Ok claude. you didnt listen to me at all. First off - let me begin with this. Make the hypergamy name ''Dead by
> selection'' removing the hypergamy text from the image and only showing this image but redrawn a bit so it doesnt
> look like people - more like lines, but make it understandable still.
>
> Second of all, you didnt listen to me on the cutscenes at all. You made them slop, low quality, used basically the
> same ''shaking'' animation each time and had no diversity or pacing.
>
> here's how its gonna work: you rework each new cutscene from the ground up by MAKING SURE to copy the EXACT povs of
> each video or reference I showed you. For example: the multiple ''you'' characters looking back in the video while
> you try to punch a menacing shadowy figure (the killer), or the quickhack icon animation being displayed above your
> head in a scenario and the blackwall gateway shouldnt be just an aura on the body, rather glichy cyberpunky figures
> showing up on you, overtaking you. The ''A GOD IS NOT AFRAID OF'' you should make a scenario where your character
> is the supposed devourer of gods up in a purple sky and theyre slowly disintegrating while spamming the ''A GOD DOES
> NOT FEAR DEATH'' on the left bottom corner. for the ironman death you legit did nothing, you were supposed to give
> him the ironman glove with all the infinity stones, where he wouldve snapped his fingers. For Sam's death, you didnt
> make the thing cinematic at all, there were supposed to be 2 characters and raidens murasama - you basically didnt
> even do it at all like in the video like I asked you to. You also slacked off on the vfx side and inverted colors a
> lot for no reason. And you also didnt add the sword mechanic blue screen so players would know its a metal gear
> rising reveangance reference. For Walrider, I told you to do ALL deaths exactly like in the POV of the video, extra
> characters and all. Instead you made it from 3rd person, when we were supposed to see ourselves in first person
> getting up and getting shot for a second in slowmotion and then geting shot all over. For sans, you speeded it up
> and nothing could be understood. You didnt add a speech bubble, any of the four FIGHT ACT ITEM SPARE buttons. And
> for the True Patriot scene, you straight up made a character collapsing from nowhere when all we were supposed to
> see was the grave, the sad face and the salute.
>
> Basically what Im telling you is you didnt do it at all like I asked. This time, I want you to copy EXACTLY what you
> see in the video, measured FRAME by FRAME so that you dont miss any important moments. This means EVERYTHING. Pov,
> scenario, scene, VFX, VFX colours, places, assets, extra characters, etc, Im talking 1 for 1. And dont you dare miss
> a single frame. Also, respect the lengths I gave you as a description when I first named the 8 new deaths. You made
> them way too short and nothing or no reference can be understood from the clip.
>
> If you need help considering you cant directly watch something, use other AIs that you consider good to explain you
> what happens in each of these clips in great detail, compare these explanations with your pictures of each frame and
> start building.
>
> Also, as a little extra at the end, please make it so when you see the little cutscene of something being written
> in the notebook, make it so the words arent perfectly aligned in each line, just a bit more scattered like in the
> anime, and the name of the victim who died shows up too. So for example it would be like this: John Doe died (reason
> for death). Also make up funny connectors for each death style. An example would be: John Doe met their fate by
> Walrider, or John Doe was not happy to hear Let's Dance!. And do this in unique ways for each custom death.

(The image they attached is the well-known "dating app" chart: left, five figures each with arrows fanning out to
many on the right; right, five figures whose arrows all converge on the top three on the left.)

Then: "I opened the browser for you. Also, when you hit your 97% weekly usage limit - stop working at once. Do
something to save this whole conversation somewhere on the git ... so that I can redirect another Claude account to
work on this incase you dont manage to finish ... I want ... that you complete this task in the absolute ultra highest
quality possible."

## The original requests (2026-11-07/08), with the time ranges = the lengths to keep

1. "death by hypergamy" -> now **Dead by selection** (see decisions).
2. **This is... requiem**: youtube.com/watch?v=Blr9yG1KihM 2:47-3:03 (16 s).
3. **Blackwall gateway**: youtube.com/watch?v=LD5z3GmQRXQ "in studio" (the whole clip, 23 s).
4. **A GOD.. IS NOT... AFRAID OF...**: Calamity's Devourer of Gods death + the chat line "A GOD DOES NOT FEAR DEATH!"
   (no clip given: the user's description above is the spec).
5. **and I.. am..**: Iron Man's death from Avengers: Endgame (no clip given: the gauntlet, six stones, the snap).
6. **Let's dance!**: Sam's finisher, youtube.com/watch?v=fz70rkwLm2U 1:30-1:45 (15 s).
7. **Walrider**: Outlast 1 ending, youtube.com/watch?v=tSu602yq5ck 4:34-4:53 (19 s), "exactly how it is".
8. **heh, didja really think-**: sans' death "in the exact way" as youtube.com/watch?v=viIakaNTAi0 (the whole clip).
9. **A true patriot**: MGS3 salute, youtube.com/watch?v=pEBSp-fkNog 1:50-2:15 (25 s); the name on the grave = who
   died; the one saluting = their Roblox friend in the server (priority) else a random player in the server.

## Decisions taken (keep them unless the user says otherwise)

- Dead by selection: built WITHOUT showing suicide (Roblox bans it; the user's first version said the character
  "decides to end it"). The victim looks at the chart (redrawn as dots and lines, no human figures, no text), every
  line passes them by, and they are "deselected": greyed out, crumbling. Tell the user plainly.
- Our own assets only (no ripped art or audio). Copy composition, POV, staging, timing, colours, UI layout; draw our
  own versions of HUDs (the quickhack menu, the blade-mode screen, the FIGHT/ACT/ITEM/MERCY bar). Short quotes only.
- In a case, these scenes are full cinematics: everyone watches the cut (after the Manual shot), then the camera
  returns to the body lying in the map. The case is held for the whole length.
- The grave name in a case = the name written in the Manual (the case's real name); in the shop Preview the player's
  display name.

## Where things are

- Shot sheets (frame by frame): `art/refs/deaths/<death>.md` (requiem, blackwall done 2026-11-08).
- First build (rejected): `art/scripts/deaths_scenes.py`, `src/client/Presentation/{CustomDeaths,DeathVfx,DeathScreen}.luau`,
  `art/scripts/cinema/deathcuts.py` (scenes), `src/shared/Cinema/DeathCuts.luau` (generated). The grave + server pick
  of the saluter (`DeathNoteService` saluterFor, `Presenters/Death`) and the debug gallery (F2 > Show) are fine.
- Manual sentence (done, uncommitted at first): `src/shared/Presentation/DeathLines.luau`, Cosmetics `line` on every
  reason item, `BookStage` Line.scatter. Still to do: ManualTiming.BOOK 1.6 -> 2.8 (a sentence needs time),
  Presenters/Death + WinCinema ACTS.book to pass `{ text = DeathLines.sentence(name, cause), scatter = true }`,
  deathcuts.py BOOK and the book event.
- Test harness: previous session's scratchpad `harness/` (run.ps1 -Min -Probe Deaths / Gallery / DeathPics); place sync:
  `docs/agent-memory/studio-no-screen.md` (one-shot plugin, `sync/make_sync.py` in this session's scratchpad).

## Progress log

- 2026-11-08: feedback saved (memory feedback-scene-deaths-1for1). Requiem and Blackwall references read frame by
  frame; sheets written. Manual sentence code written (not yet wired or tested).
- 2026-11-08: ALL references read frame by frame; every death has its sheet in art/refs/deaths/ (requiem, blackwall,
  sam, walrider, sans, patriot) and a spec for the three without a clip (ironman, god, selection). Manual sentence
  wired (Presenters/Death, WinCinema ACTS.book, BOOK 2.8, deathcuts.py book event `cause`), not yet tested.
  User went to sleep: "take as long as you need ... make it perfect". Next: the cinematic engine, then each scene.
- 2026-11-08 (later): WORK IN PROGRESS IS ON BRANCH `wip/scene-deaths` (pushed), not on main yet:
  - `art/scripts/scene_actors.py`: 15 actor clips (scene<Death><Role>), built into Clips (check_anims 0 failed);
    sans dodges to HIS right (screen left).
  - `src/client/Presentation/SceneDeaths/init.luau`: the engine (ctx: part/light/text/actor/dress/attach/face/at/
    during/shot/camera/layer/say/grade/screen/tween/fadeOut; SceneDeaths.box/emit; play(name, {victim, saluter,
    named, at, wait, glideBack, onEnd})). Scenes written: Requiem, Sans, Patriot, Walrider. NOT yet: Blackwall, Sam,
    IronMan, God, Selection.
  - `DeathScreen.face` (drawn faces), Manual sentence wiring (DeathLines, BookStage scatter, BOOK 2.8).
  - NOT wired yet: WinCinema.cutOf/preview for "scene:<style>", Presenters/Death playing the scene in a case, the
    server hold (Cosmetics item `scene = <length>`), Causes clip for scene deaths (collapseHeart), removing the old
    first-build pieces (DeathCuts entries for the 8 + patriot_grave chain, CustomDeaths FX + DeathVfx beats for the
    8, the deaths_scenes.py clips), the "Dead by selection" item. Nothing tested in Roblox yet.
- 2026-11-08 (night, branch `wip/scene-deaths` at 915e90eb): ALL NINE scenes written and wired; lint clean; actor
  clips reviewed in Blender renders. Wired: Cosmetics `scene = <seconds>` on the 8 + new item `reason_selection`
  ("Dead by selection"); Causes.scene/sceneLength (the world body plays collapseHeart); DeathNoteService holds
  BOOK + scene + ManualTiming.SCENE_AFTER (2.4) + 0.4 and picks the patriot's saluter; Presenters/Death plays the scene
  after the book then a shot of the body with the card; WinCinema.cutOf -> "scene:<style>", preview plays it;
  DebugPanel gallery lists them ("The 9 scene deaths"). Removed: the first build (CustomDeaths/DeathVfx batch blocks,
  deathcuts.py batch scenes + grave, deaths_scenes.py). The old death<Requiem..Patriot> + graveSalute clips are still
  inside src/shared/Anim/Clips until a FULL `run_anims.py` rebuild (unused, harmless).
  NEXT: 1) play-test in the throwaway place: probe `Scenes` (scratchpad harness ScenesClient/Scenes.server, run.ps1
  -Min -Probe Scenes) and pictures (adapt DeathPics to "scene:<style>" names); NOT run yet because the user's own
  Studio was open on the place (a harness launch beside it once crashed theirs: ask/warn first). 2) Look at real frames
  of each scene against art/refs/deaths/*.md and fix what differs. 3) Merge to main, push, sync the place
  (sync/make_sync.py one-shot plugin; scripts last synced at 90a60109). 4) A death in a real case (the hold, the
  saluter pick) has never been run.
- 2026-11-08 (day): TESTED + MERGED. Probe `Scenes`: all 9 play to the end, 0 errors, patriot headstone = player name,
  Manual sentence written word by word; specs 456/0. Picture probe `ScenePics` (harness, -Off -CornerSize 1920x1080
  -Attr DGSharp; MOMENTS per sheet) shot 82 frames; fixed from them: sans camera inside its box, Blackwall mirrored,
  requiem nebula + row closeness, god sky/size/close-ups, Iron Man light, Sam blade-mode blue wash + shoulder shots,
  Walrider swarm placement, patriot lone saluter (olive soldier) + stone light. Merged into main 31e49b56 and pushed.
  LEFT: the place sync (the user's Studio is open on the place: a second Studio on it would bump their session; sync
  when it is closed, sync/make_sync.py from 90a60109), Iron Man's gauntlet close-up still tight, a death in a real case.

## The user's next verdict (2026-11-08, after the sync): "why are the scenarios so low quality?"

Their screenshot (the patriot's grave in the gallery): the sets are code-built Roblox primitives (blocks, cylinders,
balls, flat walls of one colour), the box room's corners show in the background, the light is blown out (the face
glows white, the drawn face lost), long glowing "sun shaft" slabs cross the frame as pink lines. The game's own maps
are Blender-modelled FBX imports; these scenes are not, and it shows.

**What the next pass must do (not started):**
1. Model each scene's set in Blender like the other sets (art/scripts kit + run_maps / the Sets FBX the win cutscenes
   use): the cemetery (modelled headstones with bevelled tops and engraving, a real tree with branches, grass
   ground with clumps, rows going into fog, a horizon instead of box walls), the car park (pillars, ramps, ceiling
   beams, cars, lift), the desert ridge, the battlefield ruins, the asylum lab and its doorway, the starfield/void
   skies as proper sky domes, the board room. Export as an FBX set the place imports (a new import for the user),
   referenced by SceneDeaths instead of ctx:part boxes.
2. Light every set like the maps (keys + rims, no blow-out; drop Brightness in the grades, cap PointLights near faces;
   fog via Atmosphere-like layered veils far off, never box walls in view).
3. Remove the crossing sun-shaft slabs; use beams/god-ray textures behind the subject.
4. Check the drawn faces on avatars with mesh heads (the user's head showed none).
5. Re-shoot with ScenePics and compare against art/refs/deaths/*.md.

Also open (not part of this task): the Studio notice about missing lobby imports: Maps_Lobby v39 and Models_Lobby
v22 (from the 2026-11-07 "solid and alive" work) were never imported into the place.
- 2026-11-08 (afternoon), lobby imports: started by screen control in the user's open Studio. DeathsGambitMaps_Lobby.fbx
  (v39) was in the Import Queue (uploading, ~30%); DeathsGambitModels_Lobby.fbx (v22) was submitted to the importer
  but not confirmed (the user started using the PC). At the last check the place still held only Maps v38 and
  Models v21. To finish: let the queue end, check Workspace for DeathsGambitMapsLobby_Version_39 and
  DeathsGambitModelsLobby_Version_22, import whichever is missing (Home > Import 3D, art/export), then delete the old
  DeathsGambitMaps_Lobby (v38 marker) and DeathsGambitModels_Lobby (v21 marker) models, and File > Save.
- 2026-11-08 (later), checked by Studio MCP in the user's play test: Maps_Lobby v39 LANDED (the loader uses it and moves
  v38 to ServerStorage.DeathsGambitSuperseded). Models_Lobby is still v21: v22 never queued, so it is the one import
  left (art/export/DeathsGambitModels_Lobby.fbx), then delete the old v38 maps model and v21 models model and save.
- 2026-11-08 15:56: DONE. Models_Lobby v22 imported, the old Maps v38 / Models v21 removed, place saved (not
  published). All 13 imports in the place now match src/shared/ImportVersions.luau.
- 2026-11-08 (evening): THE MODELLED SETS ARE IN (branch wip/scene-sets merged to main). Venue `Scenes`
  (art/scripts/maps/venues/scenes, DeathsGambitMaps_Scenes.fbx v2, IMPORTED into the place, v1 removed, place saved,
  not published): the patriot's cemetery (rolling meadow + grass tufts, ~950 bevelled arched headstones in rows, the
  big bare oak, bare woods and hills into the mist), Blackwall's car park (pillars painted with the "1", beams, duct,
  pipes, bays, parked cars, the two-level lift with the blue car, shutter, exit doors), Walrider's lab (vault on ribs,
  pipes, chevron door frame, hazard stripe, the white tiled room with blood), Sam's desert ridge (hills, boulders, the
  ridge, mesas), Iron Man's battlefield (craters, rubble, torn walls with rebar, burnt-out shells), the selection
  board room (panelling, blinds, table and chairs, the board's stand). Five drawn skies (Mist, Dusk, Ember, Requiem,
  God). Each scene lit by LightingPresets.scenes (sun aimed finely, mist, grade); the old part sets stay only as
  stand-ins without the import. Drawn faces now on a carrier in front of the head (mesh heads hid them). Every scene
  played from its start opens on black for ~0.75 s (the engine lights a new place a moment late). Actors carry no
  name tags. Details and traps: docs/agent-memory/scene-death-sets.md.
  CHECKED in the real place (play test by MCP + screen): patriot wide/headstone/salute close, Blackwall normal + scan
  + fire, Walrider floor/door/tiled room, Sam desert, Iron Man wide and wall, selection board, requiem void.
  Scripts synced by hash-checked MCP patches (all 20 + follow-ups UPDATED, none skipped).
  NOT CHECKED: god's purple sky in Roblox (same path as requiem's), sans (no set; black), the Iron Man army wide after
  its camera move, a death in a real case (the hold), the Walrider drops/tiled room after v2 (tubes now 2.97).
  LEFT / ideas: Walrider's first-person hands are still part-built blocks; the scene actors' acting is the previous
  session's; the lobby HUD (tagline, daily streak card) showed over scenes in my hook-driven test (the debug gallery
  hides its panel; check what the shop Preview hides).
- 2026-11-08 (evening, last look): god's purple nebula sky CHECKED in the place (serpent + chat spam fine). Two flaws
  seen and NOT fixed: (1) god's disintegration wide (~t 7) has a hard-edged translucent purple plane over the left
  third (an effect part from the first build, not the set); (2) Iron Man's army wide (t 10-13) still reads dark on its
  left third after the camera move: move the eye further right (x ~11) or trim the broken wall's +X end in
  art/scripts/maps/venues/scenes/ironman.py (that one needs a v3 import).
- 2026-11-08 (night): BOTH FLAWS FIXED and checked in the place. (1) God's "purple plane" was a SKY SEAM: Roblox shows
  SkyboxLf toward +X and SkyboxRt toward -X, the opposite of skies.py's face names; LightingController.applySky swaps
  the two for Scene* skies (main 0e6eb21c). Also moved god's and requiem's nebula smoke clouds far from the cameras
  (one sat beside the god wide's lens). The maps' skies (skies.py) use the same naming and probably have the same
  seam: NOT checked, NOT changed. (2) Iron Man's army wide now shot from in front of the broken wall (475e4532): clear.
  Scripts synced by hash-checked MCP patches; place saved (not published).
