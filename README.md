# L game

A Roblox social-deduction game for 6 to 12 players, themed on the Kira case. One player is secretly
Kira, who kills by typing a player's **real name** into the Death Note. The rest form the
investigation team led by a secret L. Every case-file task leaks three letters of the worker's
real name to anyone watching, so names become the resource both sides fight over.

## Running it

1. Start Rojo (`rojo serve`) and connect the Rojo plugin in Studio. The whole game syncs in:
   no models or assets to import, the lobby and all maps are built by code.
2. Press **Play**. Press **READY** in the lobby. In Studio a match starts with just you
   (`Config.STUDIO_MIN_PLAYERS = 1`); live servers need 6.
3. For a real test, use **Test > Clients and Servers** with 6 or more players.

The server runs the unit tests on every Studio Play and prints `[L game tests] N passed, 0 failed`
to Output.

### Place settings to check in Studio

- **Game Settings > Security > Enable Studio Access to API Services**: needed to save coins, ranks
  and cosmetics in Studio. Without it the game uses temporary data and says so in the lobby.
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
| R | Shinigami eyes read (follower with the deal) |
| L | L's desk: suspicion meter, tips and reports |

Every action also has an on-screen button for touch devices.

## Tuning

All numbers live in `src/shared/Config.luau`: phase lengths, ranges, suspicion weights, rewards,
map rotation and the Studio helpers:

- `STUDIO_FORCE_ROLE = "Kira"` (or `"L"`, `"Follower"`, `"Watari"`, `"TaskForce"`) forces the
  first player's role when testing alone.
- `STUDIO_TIME_SCALE = 0.3` speeds every phase up in Studio.
- `CROSS_SERVER_MATCHMAKING` pools queued players across live servers with MemoryStoreService and
  TeleportService. It never runs in Studio. Live servers also start a match locally as soon as
  enough players are ready.

## Code map

```
src/shared/   Config, name pools, rules shared by server and client (name matching,
              letter reveal, vote counting, role assignment, win conditions), remotes (Net)
src/server/   init.server.luau boots every service
  Services/   Match (state), RoundService (match loop), RoleService, NameService,
              CaseFileService, EvidenceService, DeathNoteService, WarrantService, VoteService,
              MeetingService, ChatService, NoteService, EyesService, HoodService,
              SuspicionService, TipBoxService, MatchmakingService, PartyService,
              DataService, ShopService, CosmeticsService, RewardService, CharacterService
  Maps/       Builder plus the lobby, the meeting room and three maps:
              Task Force HQ, University Campus, Tokyo District
  Tests/      TestEZ-style specs and the runner
src/client/   init.client.luau boots the UI and controllers
  UI/         every screen: lobby, shop, party, briefing, HUD, tasks, Death Note, meeting,
              vote, L's desk, notes, tip box, quick-chat, spectate, reveal
  Controllers/ prompts, keybinds, chat rules, emotes, shinigami eyes
```

The server is the only source of truth. Roles, real names, the tip box and the Death Note never
leave the server except to the one client allowed to see them. Letter flashes and eye reads go
only to players in range, for 3 seconds, and are never stored.

## Notes on the tech stack

- **No third-party packages.** UI is plain Roblox instances (no React-lua), data uses a built-in
  session-locked DataStore wrapper (no ProfileStore) and the tests use a small TestEZ-style
  runner. Nothing needs Wally, so the game works right after a Rojo sync.
- **Selene and StyLua** configs are included and CI runs both. Format the code once with
  `stylua src` before your first push, or the StyLua check will flag formatting differences.
- **Licensing:** the in-game text uses the Death Note terms from the design doc (Death Note, Kira,
  L, Watari, shinigami). Rename them before a public release, as the design doc says.
