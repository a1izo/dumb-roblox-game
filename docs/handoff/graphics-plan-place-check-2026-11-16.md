# Is the first graphics plan in the owner's place? (check of 2026-11-16)

Question: are phases 1 to 7 of `docs/handoff/graphics-plan-2026-11-12.md` (shadows, wet street, coloured light from
signs, contact darkness, visible air, rim light, low-quality notice) in the owner's Roblox place?

## What could and could not be read

- **The place itself could NOT be read.** `list_roblox_studios` showed the owner's one Studio (Death's Gambit, place
  130650608236392) in **Play** mode. The rule for this check is that a Studio in a Play session is not touched, so no
  other Studio tool was called: no script hashes, no `*_Version_*` markers, no state read. Nothing was changed.
- Everything below is from the repo at `origin/main` (c0af985f, fetched 2026-11-16) and from what earlier agents
  recorded about the place (`docs/handoff/list-2026-11-15.md`, `docs/handoff/big-list-2026-11-14.md`, the agent
  memory `list-nov16`). So the answer is "the place should hold it, by the records", not "seen".
- To confirm, run this again with the Studio in Edit mode (the hashes in the last section are ready to compare).

## What the place is recorded to hold

- Scripts: v598 (2026-11-15) was synced to main with fingerprints matching; v608 (2026-11-16) was synced "as of commit
  1dcb59dc". Every file of phases 1 to 7 was last changed at or before 1dcb59dc (list at the end), so a place at
  1dcb59dc holds their final text.
- Imports at v608 (2026-11-16): Core 41, Lobby 56 (Models_Lobby 24), Agency 37, plus the v598 set: Campus 35,
  Tokyo 50 (parts A and B), Sets 20, Meeting 9, Scenes 14. These equal `src/shared/ImportVersions.luau` at
  origin/main for every venue (MapsAgency 37, MapsCampus 35, MapsTokyo 50, MapsMeeting 9, MapsSets 20,
  MapsScenes 14, MapsLobby 56, ModelsCore 41, ModelsLobby 24; ModelsAgency 18, ModelsCampus 16, ModelsMeeting 6,
  ModelsTokyo 24, ModelsFx 3 were not named in the notes and are the one thing to confirm).

## Table

| Phase | Verdict (by the records) | Evidence | What the owner must do |
|---|---|---|---|
| 1 shadows | in the place | Code: 3e6e1f52 (2026-11-13) = `SceneBuilder`, `LightingController`, the three `Scenes/<venue>/Dressing` data modules (the plan's own status: 20 HQ, 12 Campus and a few Tokyo lamps built to cast). Latest edits to those files are 380353fe (11-14) and 04788328 (11-15), both before the v598/v608 syncs. Lights only: no version bump, so no import. | Nothing, if the place is at 1dcb59dc. |
| 2 wet street | in the place | Road retexture 86f597cb (11-13 08:52) rewrote `AsphaltWet_color/rough.jpg` inside `DeathsGambitMaps_Tokyo.fbx`, same version. Tokyo has been re-exported and re-imported since (v48 at 11-13 20:15, then v49, v50); the place holds Tokyo 50 (A+B) from 11-15. So the road is in. | Nothing. (If the place's Tokyo import were older than v48 the road would still be near black.) |
| 3 coloured light from signs | in the place | 79 sign spots + 39 Campus window spills live in the Tokyo/Campus Dressing data (3e6e1f52; Campus/Dressing last 380353fe). Same script sync as phase 1. | Nothing. |
| 4 contact darkness | in the place, if Agency 37 is imported | `CONTACT_DARKNESS = True` in `art/scripts/maps/venues/agency/__init__.py` (2fb7ddf3, Agency v33). Agency now 37; recorded as imported in v608. HQ only (Campus and Tokyo have none, by the plan). | Nothing if "Agency 37" is what the `MapsAgency` marker says. |
| 5 visible air | in the place | `World/AirFx` and `World/LampHaze` (2ab69378, unchanged since), wired in `src/client/init.client.luau` (`AirFx.init()` line 224). | Nothing. |
| 6 rim light | in the place | `World/RimLight` (2ab69378, unchanged since); goes out in a blackout and in Low quality mode; `RimLight.init()` at line 223 of the client init. | Nothing. |
| 7 low-quality notice | in the place | `World/QualityNotice` (2ab69378, unchanged since); `QualityNotice.init()` line 222; `HintController` carries the "tip is on screen" hook. | Nothing. |

Not part of "in the place": the graphics-plan notes themselves say a frame rate on the owner's machine was never read,
the Campus window spill was never seen in a play test, and the interview pendants as shadow lamps were not done.

## Stale compared with origin/main (by the records)

Only two scripts: `Client/Presentation/Verdicts` and `Server/Tests/FateLedger.spec`. Both are commit 5593151f (verdict
fixes), which the v608 note says is NOT in the place yet. No graphics script is affected. The later commits
3624eb53 and c0af985f are docs only. Any script in the place that matches none of the repo's history would be someone
else's live work: not checked.

## Fingerprints at origin/main c0af985f (Adler sum from `place-script-check.md`, over the repo file's bytes)

Compare with the place's `.Source` hash. A mismatch only means a CRLF or Rojo difference if the length is close; the
file's history in git then names the commit.

| Script (repo file) | bytes | hash |
|---|---|---|
| src/client/World/AirFx.luau | 7865 | 2168906254 |
| src/client/World/RimLight.luau | 5342 | 4045272674 |
| src/client/World/QualityNotice.luau | 3484 | 3162862324 |
| src/client/World/LampHaze.luau | 8469 | 3991623235 |
| src/client/World/LightingController.luau | 29353 | 375393631 |
| src/server/Maps/SceneBuilder.luau | 55519 | 1287666237 |
| src/shared/LightingPresets.luau | 32067 | 2267635501 |
| src/server/Maps/Scenes/Agency/Dressing/init.luau | 67151 | 1479387035 |
| src/server/Maps/Scenes/Campus/Dressing/init.luau | 72363 | 1574708514 |
| src/server/Maps/Scenes/Tokyo/Dressing/init.luau | 190979 | 985473708 |
| src/shared/SceneMaterials.luau | 21092 | 3478274010 |
| src/client/init.client.luau | 12215 | 1521728462 |

Last commit that changed each, all at or before 1dcb59dc: AirFx, RimLight, QualityNotice, LampHaze 2ab69378;
LightingController 04788328; SceneBuilder and Campus Dressing 380353fe; Tokyo Dressing 3e6e1f52;
LightingPresets, Agency Dressing, SceneMaterials 8e06742f (the HQ view commit, older than 1dcb59dc);
init.client ecbf94f6.

To confirm in the place (Studio in Edit mode): read the `MapsAgency`, `MapsTokyo`, `MapsCampus` version markers under
workspace (expect 37, 50, 35), check `World.AirFx`, `World.RimLight`, `World.QualityNotice` exist under the client
scripts, and hash the scripts above with a read-only `execute_luau`.
