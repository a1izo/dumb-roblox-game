# Inkbound

A Roblox social-deduction game for 6 to 12 players, in a dark anime-noir style. One player is
secretly **the Hand**, who kills by writing a player's **real name** in **the Grimoire**. Everyone
else works for **the Agency**, led by a secret **Zero**. Every case-file task leaks three letters
of the worker's real name to anyone watching, so names become the resource both sides fight over.
Players who are killed, voted out or arrested stay in the match as invisible **Specters**.

## Running it

1. Install the tools once: `aftman install` (Rojo, StyLua and Selene, pinned in `aftman.toml`).
2. Start Rojo (`rojo serve`) and connect the Rojo plugin in Studio. The whole game syncs in; the
   lobby and all maps are built by code.
3. Press **Play**, then **READY** in the lobby. In Studio a match starts with just you
   (`Config.STUDIO_MIN_PLAYERS = 1`); live servers need 6. Press **F2** for the debug panel
   (test bots, phase and role controls, previews; see below).
4. For a real test, use **Test > Clients and Servers** with 6 or more players.

The server runs the unit tests on every Studio Play and prints `[Inkbound tests] N passed, 0 failed`
to Output.

### Testing alone: the debug panel (F2)

In a Studio play test, press **F2**. Everything below works with just you in the server:

| Tab | What it does |
| --- | --- |
| Match | Start a match now, pick the next map, skip to any phase or round, pause or extend the timer, speed phases up (x0.1 to x2), skip cutscene phases, force a win, end the match at once |
| People | Everyone with their role and real name. Change anyone's role mid-match (unique roles swap), force roles for the next match, kill (any cause), vote out, arrest, revive, give the Specter's Eyes, a hood or paper, force a letter flash, add suspicion, teleport, freeze |
| Bots | Add test bots (Studio only). They join the next match, walk on pathfinding, work and fake case files, vote, and the Hand writes names. Toggle autoplay and kills, choose how bots vote, or order one bot to come, work, vote, write a name, serve a warrant or take the Eyes deal |
| World | Teleport to the lobby, map, meeting room, any station or area; preview any map between matches; switch Blender scenes and part-built rooms (greybox maps); check the map contract; fly, noclip, free camera; show colliders, roles over heads and performance stats; force lighting presets, phase moods, rain and snow |
| Show | Play any cutscene for yourself during a match (intro, the four deaths, verdict, arrest, Eyes deal, both outros), announcements, every role's briefing card, the results screen, any music slot, every sound |
| Anim | Play any animation clip on yourself or on the person picked, from x0.1 to x2, looped |
| Profile | Coins, XP, every cosmetic, passes for the session, next day / week (streaks, quests, shop), resets (hints, Academy, streak, quests, achievements, cosmetics, everything), test purchases |

Bots use the same server code as players (every rule, range check and rate limit applies), so a
bug a bot hits is a real bug. To give testers the panel in a published place, add their user
ids to `Config.DEBUG_USER_IDS` (bots stay Studio-only).

### Place settings to check in Studio

- **Game Settings > Avatar > Avatar type: R15.** Poses, the movement set and the noir outfit are
  built for R15.
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
| Case opening (8 s) | Cutscene: the camera sweeps the map, the case card, the Grimoire falls. Hold to skip. |
| Briefing (15 s) | Your role card, your secret real name and your first move. |
| Investigation | Work case files (they flash 3 letters of your name), read notes, drop tips. |
| Grimoire phase | Everyone writes. The Hand writes a full real name; the others file a report. |
| Agency meeting | Free chat. A name written in the Grimoire dies during the meeting (cutscene). |
| Vote, then Verdict | The tally animates; the player voted out is spotlit and fades. Zero can serve a warrant. |
| The end (10 s) | Everyone gathers; the lights find the Hand; each side hears its own music. |
| Case closed | Every role and real name, the timeline, rewards, quests, unlocks. |

## Controls

| Key | Action |
| --- | --- |
| E / F / T | Use world prompts (work a station, fake a task on the Hand's side, rig a flash) |
| Hold C | Role card: your role, real name and allies |
| V | Scratchpad (private notes, never sent anywhere) |
| H | How to Play |
| B | Evidence board |
| Q | Quick-chat and emotes (the only chat outside meetings) |
| N / G | Write or read your note / drop it |
| R | Specter's Eyes read (the Cultist who accepted the deal) |
| Z | Zero's desk: suspicion meter, tips and reports |
| As a Specter or spectator | WASD to fly, Space up, Ctrl down (gamepad: A up, LT down; touch: on-screen buttons) |
| F2 | Debug panel (Studio play tests only) |

Every action also has an on-screen button for touch devices, and gamepads are supported.

## What is in the game

- **UI**: the Grimoire design system (`UI/Kit`): a black notebook in candlelight, with inked
  Gothic titles, handwritten names, parchment for the Agency's paperwork and red ink only for
  what matters. Every screen is built from its tokens, pages, cards, tabs and controls (the
  debug panel's UI tab shows them all), with a router for windows, device scaling, reduced
  motion and full gamepad support.
- **Teaching**: the role card, objectives for your role and phase, one-time tips (the X on a tip
  turns the whole guide off; Settings brings it back), How to Play, and the **Academy** wing of
  the lobby with practice desks for every skill.
- **Cutscenes** (`client/Presentation`): the server sends timed cues that every client plays at the
  same moment. Case opening, deaths, the verdict, arrests, the Specter's Eyes deal and the ending.
- **Characters** (`client/Anim`, `shared/Anim`): procedural poses played on every character from
  public events only (writing, a raised hand when a vote is cast, a collapse per cause of death,
  cuffs, victory and defeat). Deaths ragdoll and leave a body until the next round, then a card
  with the alias. In matches everyone wears a noir suit and red tie, and one movement set replaces
  owned animation packs.
- **World** (`client/World`, `shared/LightingPresets.luau`, `server/Maps/Style.luau`): "noir night"
  lighting per venue (cold moonlight, warm lamps with hard shadows, haze, a washed-out grade,
  bloom only on real lights) with a strong mood per phase, blended slowly: the Grimoire phase
  falls near-black and red, the meeting gets a harsh cold key light, red creeps into the vote,
  the verdict and the ending black out around the cutscene's spotlight. Settings has Low
  graphics for slower devices. Also rain and snow that stop under roofs (footprints in the
  snow), lightning, flickering lamps, steam and neon.
- **Specters**: ghosts fly through walls (but never out of the map: a box follows each map's
  outer walls and ceiling), move between the map and the meeting-room gallery, follow a living
  player's view, chat only with each other, gather lost souls for a few coins, and see real
  names only when no party member or Roblox friend of theirs is still alive. The living never
  see or hear them.
- **Spectating**: while a case runs, players in the lobby can press SPECTATE and fly through
  it the same way. Nobody sees them, not even the Specters; they get public information only,
  read the meeting without typing, watch the cutscenes, and go back to the lobby when they
  leave or the case closes. You cannot be queued and watching at once; a party member readying
  up brings you back.
- **Shop and Robux**: hats, trails, ties, notebook covers, victory poses, Specter forms and titles,
  a daily featured rotation, coin packs, and passes (VIP, Double Coins, Custom Alias, Emote Pack,
  Director). Titles and VIP tags show only in the lobby and on the results screen.
- **Retention**: a daily streak, 3 daily and 3 weekly quests, 31 achievements (with optional
  badges), 10 mastery levels per role, rank titles, global and weekly leaderboards.

## Anonymity rules (never break these)

- The server is the only source of truth. Roles, real names, the tip box, the Grimoire target and
  who voted for whom never leave the server except to the one client allowed to see them.
- Cutscene cues and poses carry only public information. Everyone writes in the Grimoire phase;
  nothing is tied to who really writes.
- No cosmetic may reveal or hide a role, and no in-match display may reveal who is behind an
  alias (titles and VIP tags are lobby-only).
- Specters are invisible to the living and cannot touch the world; their chat only reaches
  Specters.

## Art made in Blender

All animations, props, map scenes and textures are built by scripts in `art/` (see
`art/README.md`).

- **Animations** (28 clips: movement, actions, deaths, endings, emotes) are made on Roblox's own
  R15 rig and exported to `src/shared/Anim/Clips.luau`; the game plays them itself on every
  character, so there is nothing to upload. Walking and running are generated with leg IK and
  advance by distance, so feet do not slide. The default Animate script is replaced by an
  empty one, and R6 avatars are rebuilt as R15.
- **Props and maps** are imported in Studio with **Import 3D**: `art/export/InkboundModels.fbx`
  (props and effect textures), `art/export/InkboundMaps.fbx` (the venues not rebuilt yet), and for
  each rebuilt map its props and its scene, `art/export/InkboundModels_<Venue>.fbx` and
  `art/export/InkboundMaps_<Venue>.fbx` (Tokyo and Agency HQ). Leave them where the
  importer puts them; the server moves them into `ReplicatedStorage > InkboundAssets` when it
  starts and prints what it found. A rebuilt map without its import (or with an older one) loads
  as a **greybox**: the same map, fully playable, in plain colours, and the Output says which file
  to import.

## Your own assets and ids

| Where | What to paste |
| --- | --- |
| `src/shared/Assets.luau` | Music and sound effect ids, uploaded animation ids that replace clips, outfit clothing, textures and icons. Empty slots fall back to silence, the Blender clips or the imported textures. |
| `ReplicatedStorage > InkboundAssets` | The imported Blender props (see above), or your own models with the same names. |
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
  Maps/         Builder, Style (meeting-room dressing), MapContract, SceneBuilder (places the Blender
                scenes), Scenes/ (generated colliders, props, lights and signs per venue), the
                lobby, the meeting room and three maps: Agency HQ, University Campus, Tokyo
  Debug/        test bots for the debug panel (DebugService runs the panel's commands)
  Tests/        specs and the runner
src/client/     init.client.luau boots everything
  UI/           every screen and panel, Core/ (router, motion, settings, clock, scaling)
  Presentation/ cue router, camera director, cinema helpers, ink effects, cutscene presenters
  Anim/         PoseController, LocomotionController and ActingController (Blender clips)
  Audio/        mixer, music and sound effects
  World/        lighting, rain and snow, footprints, flicker, Specter visibility
  Specter/      flight, lost souls and real-name tags for ghosts
  Controllers/  prompts, chat rules, emotes, Specter's Eyes, the Academy
  Input/        actions and bindings
  Debug/        the debug panel (F2) and its local tools (fly, free camera, colliders, tags)
assets/         your own models, synced to ReplicatedStorage/ServerStorage.InkboundAssets
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
