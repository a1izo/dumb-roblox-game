# Handoff: the scene deaths rework (started 2026-11-08)

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
