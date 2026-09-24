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
   (`Config.STUDIO_MIN_PLAYERS = 1`); live servers need 6.
4. For a real test, use **Test > Clients and Servers** with 6 or more players.

The server runs the unit tests on every Studio Play and prints `[Inkbound tests] N passed, 0 failed`
to Output.

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
| As a Specter | WASD to fly, Space up, Ctrl down (gamepad: A up, LT down; touch: on-screen buttons) |
| F2 | Debug panel (Studio play tests only) |

Every action also has an on-screen button for touch devices, and gamepads are supported.

## What is in the game

- **UI**: an angular manga look (black, paper white, one red) built from `UI/Widgets.luau`, with
  a router for windows, device scaling, reduced motion and full gamepad support.
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
- **World** (`client/World`, `server/Maps/Style.luau`): night lighting per venue, rain that stops
  under roofs, lightning, flickering lamps, hard-shadow lamp posts, window blinds, steam and neon.
- **Specters**: ghosts fly through walls, move between the map and the meeting-room gallery,
  chat only with each other, gather lost souls for a few coins, and see real names only when no
  party member or Roblox friend of theirs is still alive. The living never see or hear them.
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

## Your own assets and ids

| Where | What to paste |
| --- | --- |
| `src/shared/Assets.luau` | Music and sound effect ids, animation ids that replace poses, the movement set, outfit clothing, textures and icons. Empty slots fall back to silence, procedural poses or part-built models. |
| `assets/shared/Models/*.rbxm` | Your own models (Grimoire, Handcuffs, Specter); Rojo syncs them to `ReplicatedStorage.InkboundAssets`. |
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
src/shared/     Config, Terms, Assets, Venues, LightingPresets, Models, Cosmetics, CosmeticBuild,
                ShopRotation, Products, AliasRules, SettingsSchema, Net, Copy/ (role cards, How
                to Play), Anim/ (joints and poses), Progression/ (time, streak, quests,
                achievements, mastery, ProgressRules), and the game rules shared by both sides
src/server/     init.server.luau boots every service
  Data/         Migrations (profile schema), ReceiptLedger (purchases granted exactly once)
  Services/     Match, RoundService (the match loop), Cues (cutscene timing), the gameplay
                services, CharacterService, RagdollService, GhostService, CollisionGroups,
                DataService, ProfileService, Cosmetics/Shop, Pass/Monetization/Alias/Director,
                Progress/Achievement/Leaderboard, Analytics, DebugService (Studio only)
  Maps/         Builder, Style (noir dressing), MapContract, the lobby, the meeting room and
                three maps: Agency HQ, University Campus, Tokyo District
  Tests/        specs and the runner
src/client/     init.client.luau boots everything
  UI/           every screen and panel, Core/ (router, motion, settings, clock, scaling)
  Presentation/ cue router, camera director, cinema helpers, cutscene presenters
  Anim/         PoseController and ActingController
  Audio/        mixer, music and sound effects
  World/        lighting, rain, flicker, Specter visibility
  Specter/      flight, lost souls and real-name tags for ghosts
  Controllers/  prompts, chat rules, emotes, Specter's Eyes, the Academy
  Input/        actions and bindings
assets/         your own models, synced to ReplicatedStorage/ServerStorage.InkboundAssets
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
