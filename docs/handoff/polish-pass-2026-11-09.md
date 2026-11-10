# Task: human-made polish pass, then a whole-game bug sweep (2026-11-09)

Written from the user's words via prompt-master. The user's words: "the animations are still ugly, the extra characters
look like they have random things on their head, and overall everything is low quality. Polish it way more and pay
attention to accuracy and after that look everywhere for bugs and fix them ... don't take what I said literally, just
make sure they look made by a human and not choppy and stiff ... look at popular games on Roblox with unique animation
for inspiration (A Bizarre Run, newly released)."

## Context (carry forward)
- Death's Gambit, R6 only. Clips are authored in Blender from Python (`art/scripts/*.py`, `cinema/acting.py`,
  `kit.reach/body_reach`), built by `run_anims.py -- --add A,B,C` into `src/shared/Anim/Clips`; played by
  `Anim/PoseController`; `Anim/Life` adds breathing/weight shifts at runtime.
- The nine scene deaths (`src/client/Presentation/SceneDeaths/*.luau`, actors from `art/scripts/scene_actors.py`, sheets
  in `art/refs/deaths/*.md`) are what the user looked at last. Their extras wear part-built costumes: balls and
  slabs welded on heads (Walrider soldiers, Sam's helmet, the Iron Man warlord's crown/crest). That is the "random
  things on their head".
- Locked decisions: scenes copy their references 1 for 1 (POV, set, extras, UI, length); no drawn faces on own
  avatars except the scene faces already approved; no hats/berets (removal is final); no ink effects; moderation-safe
  meshes (every piece reads alone); R6 heads up in close shots; never stylua Acting/Shots files.

## Goal
Every animation the player sees reads as hand-keyed by an animator: weight, anticipation, arcs, overlap, settle,
varied timing; no linear in-betweens, no mechanical shakes, no frozen limbs, no popping. Extras look like designed
characters, not primitives glued to a head. Then no known bug is left in the game.

## Bar (study before changing anything)
Watch fight/emote/cutscene clips from popular Roblox games known for animation (A Bizarre Run, Jujutsu Shenanigans,
The Strongest Battlegrounds, Ink Game, and similar). Write down concrete, measurable traits (frames of anticipation,
hit-stop length, smear/arc use, camera kick, ease curves, how idles breathe, how secondary limbs lag) in
`docs/agent-memory/animation-bar.md`. Copy the qualities, never their assets.

## Order of work
1. Scene deaths: for each of the nine, list stiff/choppy moments (from the clip data: linear segments, identical
   timings, still limbs, root sliding, poses held without breathing) and fix them in `scene_actors.py` with real
   keys: anticipation before every big move, overshoot and settle after, offset timing between limbs, curved paths.
2. Extras' costumes: replace welded primitive helmets/visors/crests with proper shapes (mesh in the Scenes/Models
   pipeline, or remove the piece if the silhouette reads without it). Nothing may float off or clip through a head.
3. Any other clip family the user sees often that fails the bar (deaths, emotes, locomotion, cutscenes), worst first.
4. Bug sweep: run the existing checks (specs, `check_anims`, `run_cinema --clear/--lint`, selene, the harness
   probes) and read the Studio output for errors/warnings in a play test; fix every real bug found; list anything
   that cannot be fixed without the user.

## Rules
- Only change what serves the goal; no refactors beyond it. Match existing code style.
- Verify each change with tool evidence (a check run, a Blender render, a Studio frame); never claim a look you did
  not see.
- Keep the user's PC free: Studio work through the MCP or a minimised harness; warn before launching anything beside
  their running Roblox/Studio.
- Never stage `src/shared/Assets.luau`; check for MERGE_HEAD and conflict markers before committing.
- Stop at 97% weekly usage after committing and updating this file's progress log.

## Done when
- Every scene-death clip passes the bar on a frame review, and no extra has a primitive stuck on its head.
- All checks are clean; the play test shows no new errors.
- Changes are committed and pushed to main, the place's scripts are synced (hash-checked), and the progress log below
  says what was done, what was checked, and what is left.

## Progress log

- 2026-11-09: the bar written down (docs/agent-memory/animation-bar.md, from JJS frames at 0.1 s steps).
- Game-wide cause of choppiness found and fixed: ClipPlayer drew straight lines between keys the export had thinned
  for straight lines (velocity kinks at every key, moves under 0.6 degrees flattened). Now a monotone cubic
  (art/scripts/cubic.py mirrors it; export_anims thins against it; rbxsim and check_anims play it). Every clip
  re-exported from Animations.blend (--keep): 15 parts -> 11, acting files smaller (IntroTokyo 172k -> 136k);
  check_anims 0 failed; check_export worst 0.12 studs (one snap frame of deathClock), most under 0.02.
- Scene actors reworked (art/scripts/scene_actors.py): no steady 7-14 Hz shakes, no metronome staggers; requiem's
  rewound row holds a growing dread (no stutter), its turn hidden in the 3.25 cut; Blackwall's idle has weight and
  glances, its burning staggers are uneven; Sam's victim heaves on the blade in his own time; four Walrider soldier
  clips (soldier 3 alone raises and fires first, as the reference; each recoils on its own volley shots); sans' sleep
  nods irregularly; Iron Man's line acted with beats; the army's stance loops and each soldier starts elsewhere in it.
  Anim/Life now runs on scene actors (0.8; the rewound copies 0.35) and treats a placed body as a cut.
- Extras' costumes modelled (art/scripts/props_scenes.py, Core v35): helmet, plate carrier, carbine, the blade's hair
  and visor, Murasama, the red sword, the warlord's helm and plate, the gauntlet (stones set in its sockets), spear,
  wheelchair. Placement generated by art/scripts/scene_costumes.py into SceneDeaths/Costumes.luau (held pieces solved
  on their poses with kit.hold); SceneDeaths Ctx:wear/place/pointOf. Before the Core v35 import: worn pieces show
  nothing, held ones a plain stand-in.
- Bugs fixed: the lobby title (world layer) and the daily streak pop-up (panels layer) showed over cutscenes, the shop's
  scene-death Preview included; both now wait while a cutscene's frame is up. The first build's nine dead clips
  (death<Requiem..Patriot>, graveSalute) removed from Animations.blend.
- TESTED (harness -Min -Probe Scenes, throwaway place, no imports): all 9 scenes start and finish on time with 0 script
  errors (the one counted line is the "sets not imported" notice the harness place always gives); specs 456 passed,
  0 failed. PUSHED origin/main e871749f + e2fd9bfa.
- PLACE SYNCED (one-shot DGPass plugin in a minimised second Studio, from 7ce5a55b): 34 updated, 1 created (Costumes),
  0 skipped, 0 failed. The place's ReplicatedStorage.Shared.Anim.Clips.Part12-Part15 are left in it, unused (Clips'
  init now lists Part1-Part11): delete them when convenient. Not published.
- NOT SEEN in Roblox: the costumes (they need the Core v35 import) and the new acting in the real place's lighting.
- LEFT for the user: import art/export/DeathsGambitModels_Core.fbx (v35) in Studio, then delete the v34 model and
  File > Save; a look at the scenes in Roblox (F2 > Show > the 9 scene deaths).
- 2026-11-10, "keep polishing the maps": all three case maps rendered (run_maps --preview); weakest found in Tokyo.
  PUSHED e2b4d1c2: yokocho bar fronts (buildings.tin_front: plinth, framed sliding door, lit upright sign, counter,
  stools, bottles, menus), smooth Chochin lanterns, real site hoardings (ribs, kick plate, SiteFenceBoard with the
  plan board, apology and amber lamp; the see-through slit between panels was the weights standing out to 8.7 and the
  fit squeezing the sheet). Maps Tokyo v47, Models Tokyo v24; check_v2 Tokyo ok; budget ok (385,582 / 403,233).
  Agency's "white tile" rooms are a preview artefact (CarpetTile's texture is dark slate, mean 69/73/82).
  NOT synced into the place: ImportVersions and the Tokyo scene data wait for the imports (a marker newer than the
  import builds the map as a greybox). LEFT for the user: import Maps Tokyo v47, Models Tokyo v24, Core v35, then
  sync (make_sync from 229744e1) and save.
- 2026-11-10 (the user: "import and upload everything yourself"): IMPORTED by screen control in Studio: Core v35, Models
  Tokyo v24, Maps Tokyo v47 (every MeshPart has its mesh id); the old Core v34, Models Tokyo v23, Maps Tokyo v46 and
  the unused Clips.Part12-15 removed by MCP; File > Save to Roblox (saved, not published). Then the four scripts
  changed since 229744e1 (Tokyo scene data + Dressing, ImportVersions, ModelCatalog) synced by the DGPass plugin in a
  minimised Studio: 4 updated, 0 skipped. The place matches main 34f3ad53. Not checked in a play test.
