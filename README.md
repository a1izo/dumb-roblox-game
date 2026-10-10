# Death's Gambit

A Roblox social-deduction game for 6 to 12 players, in a dark anime-noir style. One player is
secretly **Diavolo**, who kills by writing a player's **real name** in **Death's Manual**. Everyone
else works for **the Bureau**, led by a secret **Ace**. Every case-file task leaks three letters
of the worker's real name to anyone watching, so names become the resource both sides fight over.
Players who are killed, voted out or arrested stay in the match as invisible **Deathsingers**.

## Running it

1. Install the tools once: `aftman install` (Rojo, StyLua and Selene, pinned in `aftman.toml`).
2. Start Rojo (`rojo serve`) and connect the Rojo plugin in Studio. The whole game syncs in; the
   lobby, the meeting room and all maps are built by code from their Blender scene data (as
   greyboxes until their FBX files are imported, see "Art made in Blender").
3. Press **Play**, then **READY** in the lobby. In Studio a match starts with just you
   (`Config.STUDIO_MIN_PLAYERS = 1`); live servers need 6. Press **F2** for the debug panel
   (test bots, phase and role controls, previews; see below).
4. For a real test, use **Test > Clients and Servers** with 6 or more players.

The server runs the unit tests on every Studio Play and prints `[DeathsGambit tests] N passed, 0 failed`
to Output.

### Testing alone: the debug panel (F2)

In a Studio play test, press **F2**. Everything below works with just you in the server:

| Tab | What it does |
| --- | --- |
| Match | Start a match now, pick the next map, skip to any phase or round, pause or extend the timer, speed phases up (x0.1 to x2), skip cutscene phases, force a win, end the match at once |
| People | Everyone with their role and real name. Change anyone's role mid-match (unique roles swap), force roles for the next match, kill (any cause), vote out, arrest, revive, give the Oculus of the Dead, a hood or paper, force a letter flash, add suspicion, teleport, freeze |
| Bots | Add test bots (Studio only). They join the next match, walk on pathfinding, work and fake case files, vote, and Diavolo writes names. Toggle autoplay and kills, choose how bots vote, or order one bot to come, work, vote, write a name, serve a warrant or take the Eyes deal |
| World | Teleport to the lobby, map, meeting room, any station or area; preview any map between matches; switch Blender scenes and greyboxes; check the map contract; fly, noclip, free camera; show colliders, roles over heads and performance stats; force lighting presets, phase moods, rain and snow |
| Show | Play any cutscene for yourself during a match (intro, the four deaths, verdict, arrest, Eyes deal, both outros), announcements, every role's briefing card, the results screen, any music slot, every sound |
| Anim | Play any animation clip on yourself or on the person picked, from x0.1 to x2, looped |
| Profile | Coins, XP, every cosmetic, passes for the session, next day / week (streaks, quests, shop), resets (hints, Academy, streak, quests, achievements, cosmetics, everything), test purchases |

Bots use the same server code as players (every rule, range check and rate limit applies), so a
bug a bot hits is a real bug. To give testers the panel in a published place, add their user
ids to `Config.DEBUG_USER_IDS` (bots stay Studio-only).

### Place settings to check in Studio

- **Game Settings > Avatar > Avatar type: R6.** Every animation and the noir outfit are built for
  R6 (an avatar that loads as R15 is rebuilt as R6 by the server, so this only saves that step).
- **Game Settings > Security > Enable Studio Access to API Services**: needed to save profiles in
  Studio. Without it the game uses temporary data and says so in the lobby. Studio saves go to a
  separate store (`Config.STUDIO_DATASTORE_SUFFIX`), never to live data.
- **Chat**: `TextChatService.ChatVersion` must be `TextChatService` (the default for new places).
- **Voice chat**: the game mutes match players through the audio API. To guarantee that voice is
  off, turn voice chat off in **Game Settings > Communication** too.
- `default.project.json` sets `Lighting.Technology = Future`, `Workspace.StreamingEnabled = false`
  and `Players.CharacterAutoLoads = false`. If you edited the project file while `rojo serve` was
  running, restart the server so those properties sync.
- **Private servers** (optional): enable them in **Game Settings > Permissions** for the Director
  pass.

## A match

| Phase | What happens |
| --- | --- |
| Case opening (8 s) | Cutscene: the camera sweeps the map, the case card, Death's Manual falls. Hold to skip. |
| Briefing (15 s) | Your role card, your secret real name and your first move. |
| Investigation | Work case files (they flash 3 letters of your name), read notes, drop tips. |
| Death's Gambit phase | Everyone writes. Diavolo writes a full real name; the others file a report. |
| Bureau meeting | Free chat. A name written in Death's Manual dies during the meeting (cutscene). |
| Vote, then Verdict | The tally animates; the player voted out is spotlit and fades. Ace can serve a warrant. |
| The end (10 s) | Everyone gathers; the lights find Diavolo; each side hears its own music. |
| Case closed | Every role and real name, the timeline, rewards, quests, unlocks. |

## Controls

| Key | Action |
| --- | --- |
| E / F / T | Use world prompts (work a station, fake a task on Diavolo's side, rig a flash) |
| Hold C | Role card: your role, real name and allies |
| V | Scratchpad (private notes, never sent anywhere) |
| H | How to Play |
| B | Evidence board |
| Q | Quick-chat and emotes (the only chat outside meetings) |
| N / G | Write or read your note / drop it |
| R | Oculus of the Dead read (the Muerto who accepted the deal) |
| Z | Ace's desk: suspicion meter, tips and reports |
| As a Deathsinger or spectator | WASD to fly, Space up, Ctrl down (gamepad: A up, LT down; touch: on-screen buttons) |
| F2 | Debug panel (Studio play tests only) |

Every action also has an on-screen button for touch devices, and gamepads are supported.

## What is in the game

- **UI**: the interface kit (`UI/Kit`), being rebuilt in the Death's Gambit style. For now: a black notebook in candlelight, with inked
  Gothic titles, handwritten names, parchment for the Bureau's paperwork and red ink only for
  what matters. Every screen is built from its tokens, pages, cards, tabs and controls (the
  debug panel's UI tab shows them all), with a router for windows, device scaling, reduced
  motion and full gamepad support.
- **Teaching**: the role card, objectives for your role and phase, one-time tips (the X on a tip
  turns the whole guide off; Settings brings it back), How to Play, and the **Academy** in the
  lobby, a ring of broken pillars with a practice altar for every skill.
- **The lobby** is the Grey Realm: a never-ending wasteland of cracked ash under slow, layered cloud,
  the world Death's Manual comes from. Players appear on a ruined terrace over an old flagstone plaza,
  the colossal blade far to the north between two twisted columns; the title is carved on a monolith
  beyond the plinth of Death's Manual, and steles round the plaza carry How to Play, the next case and the
  boards. A ridge of rock borders the walkable basin and the wasteland runs on to the horizon beyond it.
  The Academy lies south-west; to the east a rift in the ground looks down on Kagegaoka at night; dead
  trees, bones, a colossal carcass and an empty bone throne stand about. **Mini-games for the wait**
  (solo-capable, no rewards, global top-10 boards for the first two): the *Spire Ascent*, a parkour up
  floating stones on a plateau over the west causeway; the *rune courtyard*, a memory game on the
  north-east plateau; *bone dice* at the dice rock; and the *stone-toss* at the rift's rim. Wind, drones
  and far-off knocks make a quiet soundscape (upload `art/audio/*.wav`, see its README).
- **The meeting room** is the Bureau's war room high in the Central Tower: a round table under one
  hard light, Ace's screen between two speaker columns, the evidence board on a wall of pinned
  photographs and red string, the Deathsingers' mezzanine round the walls, and the city at night
  through half-open blinds.
- **Each map has a mechanic of its own** (`server/Maps/Mechanics`, one module per map; a bug in one
  warns and never ends a match):
  - *Tokyo, the Scramble.* The lamps really cycle (50 s: walk 11, blink 4, cars 32, amber 3; worked
    out on every machine from one number, `shared/ScrambleCycle`). A crowd of about 35 walkers and a
    few clerks crosses with the walk lamp, four in five of them in the players' own suit: a player's
    name tag hides inside the crowd, and a walker's body blocks a letter flash, a witness and the
    Oculus. A few cars drive on their lamp, brake and honk for anyone in their lane and never touch
    them. Crossing on the cars' lamp is jaywalking: a camera may report it, and it accuses nobody.
    Nothing of the crowd or the cars exists on the server: they are numbers, sent five times a
    second in one small unreliable snapshot (`shared/MapSync`) and drawn by each client
    (`client/World/Crowd`, `client/World/Scramble`).
  - *University Campus, tracks in the snow.* Every living player leaves prints on untrodden snow
    (never on the swept paths) for a minute, and everyone sees them. They are anonymous.
  - *Bureau HQ, the breaker.* Once a round anyone can pull the main breaker by the fire stair: both
    floors go dark for 15 s under red emergency lamps, name tags hide, a letter flash reaches half as
    far and a faked task is only witnessed from close by. The pull is on camera.
- **Cutscenes** (`client/Presentation`): the server sends timed cues that every client plays at the
  same moment. Case opening, deaths, the verdict, arrests, the Oculus of the Dead deal and the ending.
- **Characters** (`client/Anim`, `shared/Anim`): procedural poses played on every character from
  public events only (writing, a raised hand when a vote is cast, a collapse per cause of death,
  cuffs, victory and defeat). Deaths ragdoll and leave a body until the next round, then a card
  with the alias. In matches everyone wears a noir suit and red tie, and one movement set replaces
  owned animation packs.
- **World** (`client/World`, `shared/LightingPresets.luau`): "noir night"
  lighting per venue (the lobby's Grey Realm is a sunless grey day) (cold moonlight, warm lamps with hard shadows, haze, a washed-out grade,
  bloom only on real lights) with a strong mood per phase, blended slowly: the Death's Gambit phase
  falls near-black and red, the meeting gets a harsh cold key light, red creeps into the vote,
  the verdict and the ending black out around the cutscene's spotlight. Settings has Low
  graphics for slower devices. Also rain and snow that stop under roofs (footprints in the
  snow), lightning, flickering lamps, steam and neon.
- **Deathsingers**: ghosts fly through walls (but never out of the map: a box follows each map's
  outer walls and ceiling), move between the map and the meeting-room gallery, follow a living
  player's view, chat only with each other, gather lost souls for a few coins, and see real
  names only when no party member or Roblox friend of theirs is still alive. The living never
  see or hear them.
- **Spectating**: while a case runs, players in the lobby can press SPECTATE and fly through
  it the same way. Nobody sees them, not even the Deathsingers; they get public information only,
  read the meeting without typing, watch the cutscenes, and go back to the lobby when they
  leave or the case closes. You cannot be queued and watching at once; a party member readying
  up brings you back.
- **Shop and Robux**: hats, trails, ties, notebook covers, victory poses, Deathsinger forms and titles,
  a daily featured rotation, coin packs, and passes (VIP, Double Coins, Custom Alias, Emote Pack,
  Director). Titles and VIP tags show only in the lobby and on the results screen.
- **Retention**: a daily streak, 3 daily and 3 weekly quests, 31 achievements (with optional
  badges), 10 mastery levels per role, rank titles, global and weekly leaderboards.

## Anonymity rules (never break these)

- The server is the only source of truth. Roles, real names, the tip box, the target in Death's Manual and
  who voted for whom never leave the server except to the one client allowed to see them.
- Cutscene cues and poses carry only public information. Everyone writes in the Death's Gambit phase;
  nothing is tied to who really writes.
- No cosmetic may reveal or hide a role, and no in-match display may reveal who is behind an
  alias (titles and VIP tags are lobby-only).
- Deathsingers are invisible to the living and cannot touch the world; their chat only reaches
  Deathsingers.

## Art made in Blender

All animations, props, map scenes and textures are built by scripts in `art/` (see
`art/README.md`).

- **Animations** (movement, actions, deaths, reactions and emotes) are made on the R6 rig (see
  `art/README.md`) and exported to `src/shared/Anim/Clips.luau`; the game plays them itself on every
  character, so there is nothing to upload. Walking and running are generated so a stance leg rolls
  over its sole and advances by distance, so feet do not slide. The default Animate script is
  replaced by an empty one, and R15 avatars are rebuilt as R6.
- **Props and scenes** are imported in Studio with **Import 3D**: the props every venue and the
  game use, with the effect and UI textures, `art/export/DeathsGambitModels_Core.fbx`; and for each
  venue (the lobby, the meeting room, Bureau HQ, University Campus, Tokyo) its props and its scene,
  `art/export/DeathsGambitModels_<Set>.fbx` and `art/export/DeathsGambitMaps_<Venue>.fbx`. Leave them where
  the importer puts them; the server moves them into `ReplicatedStorage > DeathsGambitAssets` when it
  starts and prints what it found. A venue without its import (or with an older one) loads as a
  **greybox**: the same place, fully playable, in plain colours, and the Output says which file
  to import.

## Your own assets and ids

| Where | What to paste |
| --- | --- |
| `src/shared/Assets.luau` | Music and sound effect ids, uploaded animation ids that replace clips, outfit clothing, textures and icons. Empty slots fall back to silence, the Blender clips or the imported textures. |
| `ReplicatedStorage > DeathsGambitAssets` | The imported Blender props (see above), or your own models with the same names. |
| `src/shared/Products.luau` | Developer product ids (coin packs) and game pass ids. An id of 0 hides the button. |
| `src/shared/Progression/Achievements.luau` | Badge ids (0 = no badge). |

Roblox automatically rejects uploads of copyrighted music. Each music slot has a `ref` naming the
track it was chosen for and a `fallbackId` for a licensed Creator Store track.

## Tuning

All numbers live in `src/shared/Config.luau` (phase lengths, ranges, rewards, map rotation) and the
Progression modules (quests, streak rewards, mastery levels). Studio helpers:

- `STUDIO_FORCE_ROLE = "Kira"` (or `"L"`, `"Follower"`, `"Watari"`, `"TaskForce"`) forces the
  first player's role when testing alone.
- `STUDIO_TIME_SCALE` speeds the gameplay phases up in Studio; `STUDIO_SKIP_PRESENTATION` skips
  the cutscene phases.
- `STUDIO_PASSES = { "alias", "director", "vip" }` treats those passes as owned in Studio.
- `STUDIO_DEBUG` turns the F2 debug panel on (next phase, force a win, kill or vote out a player,
  print every role, add coins or XP, jump a day or a week ahead).
- `CROSS_SERVER_MATCHMAKING` pools queued players across live servers. It never runs in Studio or
  in private servers.

## Names

Every name a player reads lives in `src/shared/Terms.luau`; code writes sentences like
`Terms.f("{Hand} wins.")`. The internal ids never change because saved data and matchmaking use
them: role ids `Kira`, `Follower`, `L`, `Watari`, `TaskForce`; the phase id `DeathNote`; remote
names; tags; DataStore and MemoryStore names. CI fails when a player-facing string uses an old name
(`python scripts/check_terms.py`).

## Code map

```
src/shared/     Config, Terms, Assets, Venues, LightingPresets, Models, ModelLibrary and
                ModelCatalog (the Blender props), SceneMaterials, Cosmetics, CosmeticBuild,
                ShopRotation, Products, AliasRules, SettingsSchema, Net, Copy/ (role cards, How
                to Play), Anim/ (joints and poses), Progression/ (time, streak, quests,
                achievements, mastery, ProgressRules), and the game rules shared by both sides
src/server/     init.server.luau boots every service
  Data/         Migrations (profile schema), ReceiptLedger (purchases granted exactly once)
  Services/     Match, RoundService (the match loop), Cues (cutscene timing), the gameplay
                services, CharacterService, RagdollService, GhostService, CollisionGroups,
                DataService, ProfileService, Cosmetics/Shop, Pass/Monetization/Alias/Director,
                Progress/Achievement/Leaderboard, Analytics, DebugService (Studio only)
  Maps/         Builder, MapContract, SceneBuilder (places the Blender scenes), Scenes/ (generated
                layouts, anchors, colliders, props, lights and signs per venue), the
                lobby (the Grey Realm), the meeting room (the war room) and three maps: Bureau HQ,
                University Campus, Tokyo; Mechanics/ (each map's own: the scramble's crowd and
                cars, the tracks in the snow, the breaker's blackout)
  Debug/        test bots for the debug panel (DebugService runs the panel's commands)
  Tests/        specs and the runner
src/client/     init.client.luau boots everything
  UI/           every screen and panel, Core/ (router, motion, settings, clock, scaling)
  Presentation/ cue router, camera director, cinema helpers, ink effects, cutscene presenters
  Anim/         PoseController, LocomotionController and ActingController (Blender clips)
  Audio/        mixer, music and sound effects
  World/        lighting, rain and snow, footprints, flicker, Deathsinger visibility, and what
                each map's mechanic shows (the Tokyo crowd, its lamps and cars, the blackout)
  Deathsinger/      flight, lost souls and real-name tags for ghosts
  Controllers/  prompts, chat rules, emotes, the Oculus of the Dead, the Academy
  Input/        actions and bindings
  Debug/        the debug panel (F2) and its local tools (fly, free camera, colliders, tags)
assets/         your own models, synced to ReplicatedStorage/ServerStorage.DeathsGambitAssets
art/            Blender scripts, .blend sources, the FBX export and previews (art/README.md)
src/character/  the empty Animate script that replaces Roblox's default one
scripts/        check_terms.py (run by CI)
```

## Notes on the tech stack

- **No third-party packages.** UI is plain Roblox instances, data uses a built-in session-locked
  DataStore wrapper and the tests use a small TestEZ-style runner. Nothing needs Wally.
- **Saving:** profiles carry a schema version. A newer profile loads read-only on an older server;
  a server never takes a profile another live server still holds. Robux purchases are reported
  as granted only after the save succeeds.
- **Analytics:** the onboarding funnel and every coin source and sink are logged to the Creator
  Dashboard (Analytics) from live servers.
- **Selene and StyLua** configs are included and CI runs both, plus the terms check. Run
  `stylua src` and `selene src` before pushing.
