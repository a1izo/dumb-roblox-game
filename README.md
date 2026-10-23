# Death's Gambit

A Roblox social-deduction game for 6 to 12 players, in a dark anime-noir style. One player is
secretly **Diavolo**, who kills by writing a player's **real name** in **Death's Manual**, at any
moment of free roam, but never unseen: the book burns red while he writes. He and his **Muertos**
learn real names by **staring** at people up close (their eyes glow). Everyone else works for
**the Bureau**, led by a secret **Ace**, and wins by voting out or arresting Diavolo or by filling a
shared task bar. Players who are killed, voted out or arrested stay in the match as invisible
**Deathsingers**.

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
| Match | Start a match now, pick the next map, skip to any phase, call a meeting, fill the task bar, make the Butler pick, pause or extend the timer, speed phases up (x0.1 to x2), skip cutscene phases, force a win, end the match at once |
| People | Everyone with their role and real name. Change anyone's role mid-match (unique roles swap), force roles for the next match, kill (any cause), vote out, arrest, revive, give the Oculus of the Dead, paper or every real name, reset the Manual and sabotage cooldowns, run any sabotage, finish a case file, teleport, freeze |
| Bots | Add test bots (Studio only). They join the next match, walk on pathfinding and vote; Bureau bots work case files, Coven bots stare, Diavolo writes learned names, Muertos sabotage, a Butler bot names the next Ace. Toggle autoplay and kills, choose how bots vote, or order one bot to come, work, stare, vote, write a name, arrest, ring the bell or take the Oculus deal |
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
| Case opening (15 s) | Cutscene: the camera sweeps the map, the case card, Death's Manual falls. Hold to skip. |
| Briefing (15 s) | Your role card, your secret real name and your first move. |
| Investigation (free roam) | Work case files to fill the Bureau's task bar, pass notes, talk in proximity chat. Diavolo and Muertos stare to learn names; Diavolo writes in the Manual (4 s, glowing, visible) and the victim dies 20 s later; Muertos sabotage. |
| Bureau meeting (60 s) | Called by any death (its cutscene plays first), the emergency bell (one ring each per match) or 3 quiet minutes. Everyone sits in their war chair; free chat at the table; Ace may arrest one player. |
| Vote, then Verdict | Pick a suspect or skip; a tie or a skip majority removes nobody. Then back to free roam. |
| The end (10 s, a few more for a bought cutscene) | The winning side's lead plays their win cutscene for everyone (the default: everyone gathers and the lights find Diavolo, or Ace's spotlight); each side hears its own music. |
| Case closed | Every role and real name, the timeline, rewards, quests, unlocks. |

There is no round limit. **The Bureau wins** when Diavolo is voted out, arrested or leaves, or when
the task bar fills (4 case files per Bureau player). **The Coven wins** when living Diavolo and
Muertos equal or outnumber the living Bureau.

### The roles

- **Diavolo**: stares to learn names and writes them in the Manual (60 s cooldown). He does not know
  the Muertos, so writing a Muerto's name kills the Muerto. Cannot use stations or sabotage.
- **Muerto** (1 at 6 to 9 players, 2 at 10 to 12): knows Diavolo; nobody knows them (not even the
  other Muerto). Stares, passes names on paper notes, sabotages (blackout, jam the stations near
  them, a barricade across the way; one shared 45 s cooldown). May take the **Oculus of the Dead**
  at any time: a 3 s visible ritual, then 1 s reads from 30 studs, and death after 3 minutes of
  free roam.
- **Ace**: secret; only the Butler knows. One arrest per match during a meeting: a Coven player is
  removed, an innocent walks free and Ace dies. The arrest reveals Ace.
- **The Butler**: knows Ace. When Ace dies he has 30 s to name the next Ace (anyone but himself, once
  per match), who gets a fresh arrest. Naming a Coven player gives them a worthless title.
- **Operative**: works case files, watches, votes.

Real names are blocked in every chat; only paper notes carry them. Bureau Deathsingers can keep
working case files.

## Controls

| Key | Action |
| --- | --- |
| E / F | Use world prompts (work a station, ring the bell, take a sheet or a note) |
| Hold C | Role card: your role, real name and allies |
| V | Scratchpad (private notes, never sent anywhere) |
| H | How to Play |
| Q | Quick chat and the emote wheel; 1 to 8 play its emotes. In the lobby, the emote wheel alone |
| N / G | Write or read your note / drop it |
| R | Stare (Diavolo and Muertos): learn the real name of the player you look at |
| P | Death's Manual (Diavolo) |
| Z / B / T | Sabotage (Muertos): blackout, jam stations, barricade |
| K | Ace's arrest, during a meeting |
| As a Deathsinger or spectator | WASD to fly, Space up, Ctrl down (gamepad: A up, LT down; touch: on-screen buttons) |
| F2 | Debug panel (Studio play tests only) |

Every action also has an on-screen button for touch devices, and gamepads are supported.

## What is in the game

- **UI**: the interface kit (`UI/Kit`), being rebuilt in the Death's Gambit style. For now: a black notebook in candlelight, with inked
  Gothic titles, handwritten names, parchment for the Bureau's paperwork and red ink only for
  what matters. Every screen is built from its tokens, pages, cards, tabs and controls (the
  debug panel's UI tab shows them all), with a router for windows, device scaling, reduced
  motion and full gamepad support.
- **Teaching**: nothing in the lobby is explained on a wall. **The Trial** teaches by doing: a new
  player is offered it once (a wisp at the foot of the terrace's steps, never forced), anyone can begin
  it under the Academy's gate, and it walks five steps through the Academy's own drills (role card, a
  case file, a name in the Manual, an arrest, READY) for a one-time reward. (The Trial's case-file
  and Manual steps still show the old letter leak; they are due a rework to staring.)
  Round the plaza five **tableaux** of stone figures act out how a case goes, with one line on the
  screen of whoever stands near. In a case: the role card, objectives for your role and phase, and
  one-time tips that name what to press for the player's own input (longer on a first case; the X
  closes a tip, "Stop tips" turns the guide off, Settings brings it back). How to Play stays in
  Settings and on H; the **Academy** keeps a practice altar for every skill.
- **The lobby** is the Grey Realm: a never-ending wasteland of cracked ash under slow, layered cloud,
  the world Death's Manual comes from. Players appear on a ruined terrace over an old flagstone plaza,
  the colossal blade far to the north between two twisted columns; the title is carved on a monolith
  beyond the plaza, whose open middle holds a ring of twelve candles (one burns for each player who is
  ready). A ridge of rock borders the walkable basin and the wasteland runs on to the horizon beyond it.
  The Academy lies south-west; to the east a rift in the ground looks down on Kagegaoka at night; dead
  trees, bones and a colossal carcass stand about, and behind the title, up on its mesa, the bone
  throne: whoever has the most wins sits on it in stone, over the one board left in the world (Most
  Wins; every other board is in the Leaderboards window). **More to do while waiting** (no rewards but
  bests, a board and a title): *Last breath*, the dive into the rift: step over the rim and tumble,
  helpless, down a throat of rock, through the cloud the realm floats on and over Kagegaoka at night,
  about eleven seconds towards a lit roof; one press and a string from the cloud catches you. The
  smallest gap left wins; too late and you slam onto the roof, limp. Divers who jump together are
  ranked together. *Death's mark*, tag from the bell by the plaza:
  whoever carries the mark when the bell tolls goes down, and the score is the tolls survived in a row.
  The *name duel*, at the two stones under the carcass's ribs: each of two players is given an invented
  name that leaks to the other three letters at a time, and the first to write the other's whole name
  wins (a wrong name costs three seconds; a minute without a winner is a draw).
  And seven grey apples lie in the realm's far corners, for a title. **Mini-games for the wait**
  (solo-capable, no rewards, global top-10 boards for the first two): the *Spire Ascent*, a parkour up
  floating stones on a plateau over the west causeway; the *rune courtyard*, a memory game on the
  north-east plateau; and the *stone-toss* at the rift's rim. Wind, drones
  and far-off knocks make a quiet soundscape (upload `art/audio/*.wav`, see its README).
- **The meeting room** is the Bureau's war room high in the Central Tower: a round table under one
  hard light, a screen between two speaker columns that says why the meeting was called, a wall of
  pinned photographs and red string, the Deathsingers' mezzanine round the walls, and the city at
  night through half-open blinds.
- **The emergency bell** stands on every map (where the old tip box stood). Each living player can
  ring it once per match to call a meeting at once.
- **Each map has a mechanic of its own** (`server/Maps/Mechanics`, one module per map; a bug in one
  warns and never ends a match):
  - *Tokyo, the Scramble.* The lamps really cycle (50 s: walk 11, blink 4, cars 32, amber 3; worked
    out on every machine from one number, `shared/ScrambleCycle`). A crowd of about 35 walkers and a
    few clerks crosses with the walk lamp, four in five of them in the players' own suit: a player's
    name tag hides inside the crowd, and a walker's body blocks a stare and the Oculus. A few cars drive on their lamp, brake and honk for anyone in their lane and never touch
    them. Crossing on the cars' lamp is jaywalking: a camera may report it, and it accuses nobody.
    Nothing of the crowd or the cars exists on the server: they are numbers, sent five times a
    second in one small unreliable snapshot (`shared/MapSync`) and drawn by each client
    (`client/World/Crowd`, `client/World/Scramble`).
  - *University Campus, tracks in the snow.* Every living player leaves prints on untrodden snow
    (never on the swept paths) for a minute, and everyone sees them. They are anonymous.
  - *Bureau HQ.* Its old breaker is gone: the Muerto's blackout sabotage now darkens every map, and
    on this one both floors go dark under red emergency lamps.
- **Cutscenes** (`client/Presentation`): the server sends timed cues that every client plays at the
  same moment. Case opening, deaths, the verdict, arrests, the Oculus of the Dead deal and the ending.
- **Characters** (`client/Anim`, `shared/Anim`): procedural poses played on every character from
  public events only (writing, a raised hand when a vote is cast, a collapse per cause of death,
  cuffs, victory and defeat). Deaths ragdoll and leave a body until the next round, then a card
  with the alias. In matches everyone wears a noir suit and red tie, and one movement set replaces
  owned animation packs.
- **World** (`client/World`, `shared/LightingPresets.luau`): "noir night"
  lighting per venue (the lobby's Grey Realm is a sunless grey day) (cold moonlight, warm lamps with hard shadows, haze, a washed-out grade,
  bloom only on real lights) with a strong mood per phase, blended slowly: a blackout falls
  near-black and red, the meeting gets a harsh cold key light, red creeps into the vote,
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
- **Shop and Robux** ("Death's hand"): hats, notebook covers, writing, verdict and death styles,
  Deathsinger forms, emotes, titles, win cutscenes (one for each side, played by the winning side's
  lead for everyone at the ending), seats and chairs for the war table, matching sets, a daily hand of
  six plus a deal at a quarter off, Fate's weekly draw (odds shown, coins only), the Season ledger
  (free line), collection milestones, coin packs, and passes (VIP, Double Coins, Custom Alias, Emote Pack,
  Director). Search, filters, "New" ribbons and a wishlist; a mannequin by the lobby spawn shows the
  day's emote. Titles and VIP tags show only in the lobby and on the results screen.
- **Emotes**: Q (or Emotes in the lobby menu) opens the emote wheel, a revolver's cylinder of eight
  emotes you choose in the shop's Your look, played with a click, a tap or 1 to 8; More lists all of
  yours. 70 in all (11 everyone's, 59 from the shop in five tiers, Scrawl to Godhood): dances in step,
  poses with a press-to-do moment, prop emotes, strolls that walk by themselves, duos (a real Match Point rally, a
  high five) and group dances. The four Godhood ones play a private cutscene for their owner in the
  lobby. In a case they play from the waist up at the meeting, stop for every scene everyone sees, and
  the few that look like a death, an arrest or the Eyes are lobby-only. Sounds and faces for them go in
  `src/shared/EmoteMedia.luau` (empty until the owner uploads them). How they work and how to make one:
  `docs/emotes.md`.
- **Retention**: a daily streak, 3 daily and 3 weekly quests, 31 achievements (with optional
  badges), 10 mastery levels per role, rank titles, global and weekly leaderboards.

## Anonymity rules (never break these)

- The server is the only source of truth. Roles, real names, the target in Death's Manual and who
  voted for whom never leave the server except to the one client allowed to see them.
- Cutscene cues and poses carry only public information. Writing in the Manual and staring are seen
  on purpose (the glowing book, the glowing eyes); no pop-up tells anyone what they saw, and the name
  written is never shown to anyone but the writer until it kills.
- No cosmetic may reveal or hide a role, and no in-match display may reveal who is behind an
  alias (titles and VIP tags are lobby-only).
- Deathsingers are invisible to the living and cannot touch the world; their chat only reaches
  Deathsingers.

## Art made in Blender

All animations, props, map scenes and textures are built by scripts in `art/` (see
`art/README.md`).

- **Animations** (movement, actions, deaths, reactions and emotes) are made on the R6 rig (see
  `art/README.md`) and exported to `src/shared/Anim/Clips/`; the game plays them itself on every
  character, so there is nothing to upload. The movement set (two idles, a walk and a run each way,
  jumps, falls, three landings, stops, flight) is described in `docs/animation.md`: planted legs roll
  heel to toe, every cycle advances by distance, and standing feet stay on their marks, so feet do not
  slide. The default Animate script is replaced by an empty one, and R15 avatars are rebuilt as R6.
  Every R6 body's accessories are rebuilt as MeshParts as it spawns (`Services/CrispAccessories`): with
  the old kind (a part and a SpecialMesh) Roblox draws the whole body from one small packed texture, and
  avatars came out blocky. The emotes, their props and their checks are described in `docs/emotes.md`.
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
  Services/     Match, RoundService (the match loop: free roam and meetings), Cues (cutscene
                timing), the gameplay services (DeathNoteService the Manual, EyesService staring
                and the Oculus, SabotageService, ArrestService and the Butler's succession,
                MeetingService and the bell, TaskBarService, CaseFileService), CharacterService, RagdollService, GhostService, CollisionGroups,
                DataService, ProfileService, Cosmetics/Shop, Pass/Monetization/Alias/Director,
                Progress/Achievement/Leaderboard, Analytics, DebugService (Studio only)
  Maps/         Builder, MapContract, SceneBuilder (places the Blender scenes), Scenes/ (generated
                layouts, anchors, colliders, props, lights and signs per venue), the
                lobby (the Grey Realm), the meeting room (the war room) and three maps: Bureau HQ,
                University Campus, Tokyo; Mechanics/ (each map's own: the scramble's crowd and
                cars, the tracks in the snow)
  Debug/        test bots for the debug panel (DebugService runs the panel's commands)
  Tests/        specs and the runner
src/client/     init.client.luau boots everything
  UI/           every screen and panel, Core/ (router, motion, settings, clock, scaling)
  Presentation/ cue router, camera director, cinema helpers, the effect styles (Styles) and the
                effects kit (FxKit), cutscene presenters, the win cutscenes (WinCinema), the
                emotes' showpiece cameras and private cutscenes (EmoteCamera, EmoteCinema)
  Anim/         PoseController, LocomotionController and ActingController (Blender clips)
  Audio/        mixer, music and sound effects
  World/        lighting, rain and snow, footprints, flicker, Deathsinger visibility, and what
                each map's mechanic shows (the Tokyo crowd, its lamps and cars, the blackout)
  Deathsinger/      flight, lost souls and real-name tags for ghosts
  Controllers/  prompts, chat rules, emotes (EmoteController, EmoteFx, DuoController), the Oculus of
                the Dead, the Academy
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
