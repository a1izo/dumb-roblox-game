---
name: vfx-rollout-4f
description: Stage 4f (2026-11-26), scenes: a partial pass only, NO Pilot flag changed and no code changed. The place's own client plays the Debug gallery fine (that is the route for watching cutscenes), a private client copy cannot judge a cut (black), what the eight win cuts and a few scene deaths looked like, and what is left
---
**Result.** Nothing shipped: no Pilot flag flipped, no code changed. The 4c win kinds (wave, bolt, sparks, bloom, ring, dust, embers, motes, ash, drizzle)
stay OFF; no scene-death effect was replaced. The budget went on finding a route that works, and on watching.

**The route that works for watching cutscenes (new, 2026-11-26).** The place's scripts are now recent (WinCuts with RimBack, Pilot with diveCrash, `Cinema.init` at
`Client` line 210: the 4c "Motion:70" error is gone), so the place's OWN client plays every cut with the real lighting, no private copy needed:
1. `start_stop_play true`, run `front.ps1` (Studio must be the foreground window; captures and mouse calls time out for minutes otherwise, and it may need
   running again after other tool calls), skip the intro (`PlayerGui.DGIntro:Destroy()`).
2. The F2 key sent by `user_keyboard_input` did NOT open the panel. Instead, in the Client: `PlayerGui.DeathsGambitOverlay.DebugPanel.Visible = true`, then
   `ReplicatedStorage.LGameRemotes.Debug:FireServer("watch", true)` (the panel waits for the server's first snapshot; without it the tabs stay empty).
3. `user_mouse_input` with x,y: the screen_capture picture is 1096 wide and the GUI y is the picture's y MINUS 58 (the Studio top bar): the Show tab is at
   (894, 63), the cut buttons below it (picture y 235 to 335 for the scene deaths, 372 and 397 for the four wins, 434 and 459 for the four Coven/Bureau wins).
   `instance_path` clicks hit the first button of the same name, so use coordinates.
4. Click a cut, `wait` 1 to 1.5 s in the same call, then `screen_capture` calls ONE AT A TIME (parallel captures time out). A capture lands about 1 s after the
   previous one finished, so an 8 s cut gives 3 stills at roughly 1.5, 4.5, 7.5 s. Which second a still is cannot be told exactly (the label's clock is the
   wall clock, not the cut's).

A PRIVATE client copy (`game:GetObjects` of a built rbxm, `CameraDirector.init` + `Cinema.init` by hand) plays a cut but renders it almost black (seen again
2026-11-26 on finalPage with `winFxSparks` on): useless for judging effects. To test NEW code in a cut the owner must sync scripts first (Rojo), then flip the
flag in the place's own Pilot and use the route above. Also: after a private `Cinema.init` the Debug panel vanished from the place's client (restart the play).

**Watched: the eight win cuts, in the place's real client** (stills in `art/export/previews/vfx/rollout/watch4f/`, main checkout, untracked). The camera frames
the actor in every still taken except the two near-empty mid-shots named below; key and rim lights read (cold white for the Bureau, red for the Coven, warm
gold for newWorldBureau's flash); endings hold framed (newWorldBureau: the black skull Manual held up beside the head; checkmateCoven: the figure on the roof;
caseClosedCoven: chin on a fist). Per cut:
- finalPage (stills near 1.5 s and 4.5 s): head-on bust with the cold key and a lit shaft, framed. The ending was not caught.
- newWorld: from behind early (red night city), then the face with flying pages and a warm key, framed.
- caseClosed: a dark first frame (opens from black), then the working arm over the desk and the actor behind it; the forearm covers most of the face in one still.
- checkmate: from behind between two pillars, then a three-quarter bust at the board's edge; a later still has the actor small at the left edge with the player's
  own name tag ("Kingsley" and its letters) floating above: that is the lobby preview's overhead tag, a preview only, not in a match.
- caseClosedCoven: bust holding the file, the end held; ONE mid still is a near-empty dark wall with the actor a sliver in the top-left corner (probably the
  throw insert; not confirmed, no run without the first capture was made).
- finalPageBureau: bowed head, face with a pen, then a tilted top-down on the Evidence stamp with a glint star on the hand (the ON `winFxGlint` reads well).
  In one still the pen is a long plain white rod poking out at the frame's left (may read as a plank).
- newWorldBureau: low bust behind the table, a gold flash with the star and a big thin ring (the OFF `ring` kind's old build, a flat disc outline), then the held
  book ending: good.
- checkmateCoven: fade in, one mid still a pale slab with a speck (actor not in frame; its cameras were left alone in the 2026-11-24 redo), then the held roof ending.
No light part was seen as a cube. The side (left/right of the actor) was not checked. No plain bug was found, so nothing was fixed. Open: the two near-empty
mid-shots (caseClosedCoven, checkmateCoven) should be seen in a run with no capture before them, and the endings of finalPage, caseClosed and checkmate were not caught.

**Scene deaths, seen in the real client:** Struck by Lightning (a dark rising face, the strike as a blown-out white-blue body with specks, then the body on the
ground: the flash reads), Frozen Where They Stood (night blue, white frost lines on the ground, snow specks: reads), A Broken Heart (two macro stills of a cup and
the hand's own mesh: acting and camera, no effect caught). The other twelve were not played in this pass. Nothing was compared with a source frame (the repo
holds `art/refs/deaths/<style>.md` tables for nine deaths, no frames; frames exist only for the kit's families in `art/refs/vfx`).

**Left for the next try:** the twelve other scene deaths and the Blender shots' `fx` events (ShotPlayer, needs a match with the Debug `shot` cue); the 4c kinds
once scripts are synced, tried in the place's own Pilot; the two near-empty mid-shots.
