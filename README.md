# Inkbound

A Roblox social-deduction game for 6 to 12 players. One player is secretly **the Hand**, who
kills by writing a player's **real name** in **the Grimoire**. Everyone else works for **the
Agency**, led by a secret **Zero**. Every case-file task leaks three letters of the worker's real
name to anyone watching, so names become the resource both sides fight over.

## Running it

1. Install the tools once: `aftman install` (Rojo, StyLua and Selene, pinned in `aftman.toml`).
2. Start Rojo (`rojo serve`) and connect the Rojo plugin in Studio. The whole game syncs in; the
   lobby and all maps are built by code.
3. Press **Play**. Press **READY** in the lobby. In Studio a match starts with just you
   (`Config.STUDIO_MIN_PLAYERS = 1`); live servers need 6.
4. For a real test, use **Test > Clients and Servers** with 6 or more players.

The server runs the unit tests on every Studio Play and prints `[Inkbound tests] N passed, 0 failed`
to Output.

### Place settings to check in Studio

- **Game Settings > Security > Enable Studio Access to API Services**: needed to save coins, ranks
  and cosmetics in Studio. Without it the game uses temporary data and says so in the lobby.
  Studio saves go to a separate store (`Config.STUDIO_DATASTORE_SUFFIX`), never to live data.
- **Chat**: `TextChatService.ChatVersion` must be `TextChatService` (the default for new places).
- **Voice chat**: the game mutes match players through the audio API. To guarantee that voice is
  off, turn voice chat off in **Game Settings > Communication** too.
- `default.project.json` sets `Workspace.StreamingEnabled = false` and
  `Players.CharacterAutoLoads = false`. If you edited the project file while `rojo serve` was
  running, restart the server so those two properties sync.

## Controls

| Key | Action |
| --- | --- |
| E / F / T | Use world prompts (work a station, read or pick up notes, rig a flash) |
| B | Evidence board |
| Q | Quick-chat and emotes (the only chat outside meetings) |
| N / G | Write or read your note / drop it |
| R | Specter's Eyes read (the Cultist who accepted the deal) |
| Z | Zero's desk: suspicion meter, tips and reports |
| F2 | Debug panel (Studio play tests only) |

Every action also has an on-screen button for touch devices.

## Names

Every name a player reads (game, roles, sides, items, phases) lives in `src/shared/Terms.luau`.
Code writes sentences like `Terms.f("{Hand} wins.")`, so renaming anything is a one-file change.
The internal ids stay as they were and must not change, because saved data and matchmaking use
them: role ids `Kira`, `Follower`, `L`, `Watari`, `TaskForce`; the phase id `DeathNote`; remote
names; tags; DataStore and MemoryStore names. CI fails when a player-facing string uses an old
name (`python scripts/check_terms.py`).

## Your own assets

`src/shared/Assets.luau` lists every slot for music, sound effects, animations, the movement set,
outfit clothing and icons. Empty slots use the built-in fallback (silence, procedural poses,
part-built models). Paste uploaded ids into the slots. Models go in `assets/shared/Models` as
`.rbxm` files; Rojo syncs them to `ReplicatedStorage.InkboundAssets`.

## Tuning

All numbers live in `src/shared/Config.luau`: phase lengths, ranges, suspicion weights, rewards,
map rotation and the Studio helpers:

- `STUDIO_FORCE_ROLE = "Kira"` (or `"L"`, `"Follower"`, `"Watari"`, `"TaskForce"`) forces the
  first player's role when testing alone.
- `STUDIO_TIME_SCALE = 0.3` speeds every phase up in Studio.
- `STUDIO_DEBUG` turns the F2 debug panel on (next phase, force a win, kill or vote out a player,
  print every role, add coins or XP).
- `CROSS_SERVER_MATCHMAKING` pools queued players across live servers with MemoryStoreService and
  TeleportService. It never runs in Studio. Live servers also start a match locally as soon as
  enough players are ready.

## Code map

```
src/shared/   Config, Terms (every display name), Assets (swap-in slots), Copy (role cards and
              the How to Play book), name pools, rules shared by server and client (name
              matching, letter reveal, vote counting, role assignment, win conditions), Net
src/server/   init.server.luau boots every service
  Data/       Migrations: the player profile schema and its upgrades
  Services/   Match (state), RoundService (match loop), RoleService, NameService,
              CaseFileService, EvidenceService, DeathNoteService (the Grimoire), WarrantService,
              VoteService, MeetingService, ChatService, NoteService, EyesService, HoodService,
              SuspicionService, TipBoxService, MatchmakingService, PartyService,
              DataService, ShopService, CosmeticsService, RewardService, CharacterService,
              DebugService (Studio only)
  Maps/       Builder plus the lobby, the meeting room and three maps:
              Agency HQ, University Campus, Tokyo District
  Tests/      TestEZ-style specs and the runner
src/client/   init.client.luau boots the UI and controllers
  UI/         every screen: lobby, shop, party, briefing, HUD, tasks, the Grimoire, meeting,
              vote, Zero's desk, notes, tip box, quick-chat, spectate, reveal, debug panel
  Controllers/ prompts, keybinds, chat rules, emotes, Specter's Eyes
assets/       your own models (.rbxm), synced to ReplicatedStorage/ServerStorage.InkboundAssets
scripts/      check_terms.py (run by CI)
```

The server is the only source of truth. Roles, real names, the tip box and the Grimoire never
leave the server except to the one client allowed to see them. Letter flashes and eye reads go
only to players in range, for 3 seconds, and are never stored.

## Notes on the tech stack

- **No third-party packages.** UI is plain Roblox instances (no React-lua), data uses a built-in
  session-locked DataStore wrapper (no ProfileStore) and the tests use a small TestEZ-style
  runner. Nothing needs Wally, so the game works right after a Rojo sync.
- **Saving:** profiles carry a schema version (`src/server/Data/Migrations.luau`). A server never
  takes a profile another live server still holds; it asks that server to save and let go.
  Match rewards and shop purchases are saved within a few seconds.
- **Selene and StyLua** configs are included and CI runs both, plus the terms check. Run
  `stylua src` and `selene src` before pushing.
