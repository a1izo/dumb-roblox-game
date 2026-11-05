---
name: lobby-remake-v2
description: The lobby remade from nothing 2026-11-04 (layout, assets, logic) to the user's two reference videos; what is where, the glow lighting, the two new games, the dive's new way in, what was removed and how
metadata:
  type: project
---

Asked 2026-11-04: an ENTIRE remake of the lobby (it was "really ugly"); the 11-03 remake ([[lobby-remake-2026-11]]) had
kept the old layout. The user chose: Grey Realm, large like before; keep the Trial, the mini-games, the throne with Most
Wins, the rift dive; remove the grey apples and the stone toss and invent two games; remake the dive's jump
transition; remove the title obelisk. References: youtube x7Lgseqn71I and 8pf3PnNtLrw (the death gods' realm).

- Layout: `art/scripts/maps/venues/lobby/plan.py` (rewritten; run it for its overlap check). South spawn ledge, the
  bowl (sunk stone basin, floor at -1.8: candle stones round the SkullDish, tableaux and bell round the rim), the
  throne on RealmThroneRock on the spawn's line, the rift NE, the carcass E (duel under its ribs), the grotto SW (the
  Academy in a cave: billows round, `_vault` roof, HangingCage lanterns), the Reaper's Sweep SE, chess and the tusks
  NW, junk heaps, the arch; plateaus as before (the Chain Heap: GreatChain + GearPlatform checkpoints; runes among
  shards). Border: billows S/W, shards and crags N/E (terrain.edge).
- Look: `LightingPresets.lobby` has `sunAim` (north, 8 degrees up): LightingController searches the clock and latitude
  that put Roblox's sun there (aimSun) and shows it 24 degrees wide; glare 1.5, haze 2.1, a light atmosphere colour and
  a dark decay, so everything toward the glow is a silhouette. Look renders: session scratch look2.py (sky pass fog).
- New games: Lantern Run (`Shared/LobbyGames/Lanterns`, in LobbyGameService like the parkour; tags LLanternStart,
  LLantern; the runner's own client lights the lanterns; profile lanternBest; the first full run grants Realm Walker +
  Apple Toss, the apples' old rewards). Reaper's Sweep (`Shared/LobbyGames/Sweep`, server `LobbySweep`, client
  `SweepController`; the scythe's angle depends on time alone, the client judges its own body, the server catches the
  plainly grounded with ping allowance; profile sweepBest; props SweepScythe).
- Dive: DiveController eases the body's own height and speed at the rim into the rules' fall over 0.9 s (it stopped
  dead and popped up 3 studs), the run's way drifts away, the tumble fades in over 0.8 s, a white flash through the
  cloud deck, and the way back through a white curtain (`Curtain.close(seconds, color)`, `Curtain.flash`).
- Removed for good: TitleMonolith and the title/tagline world signs, the apples (and GreyApple, WitheredAppleTree),
  the stone toss (Toss.luau; its rift-depth helper is `LastBreath.depth` now), BoneBrazier, LanternPost, the dead
  trees, ChessKingFallen, and kit shapes nothing stands. (CandleCluster stays: the sets' shrine and study use it.)
  Removing a prop: its builder, its objects in `art/blend/Props.blend` (the export writes whatever the blend holds),
  the catalog, then `git rm` its `art/export/textures/<Key>_*` and `previews/prop_<Key>.png` and its name in
  `sheets.py` and check_v2's FEET.
- Reach: `CHECKS["reach"]` lists every anchor a game is played at; check_v2 fails any nobody can walk to (see
  [[check-v2-reach]]). It found the grotto shut by its mouth's rocks and the plateaus' tops lying over their
  causeways' steps (each plateau now has a cove where its steps climb: `islets.plateau(arrive=...)`).
- Dressing (`dressing.py`) keeps off every collider standing on the ground and every prop placed before it
  (`solids`), not only off the plan's footprints.

**Why:** the user's verdict on the 11-03 lobby; the references are high-contrast, open and backlit.
**How to apply:** new lobby work starts from plan.py and these modules; keep the anchor names the scripts read (see
Scenes.spec); a props census (placed vs used vs built) is in the session notes. Related: [[realm-rock-kit]],
[[tiled-props]], [[lobby-ground-relief]].

**2026-11-05, the user:** "remove every minigame other than the falling pit, the tower parkour and letter typing
showdown". Kept: the rift dive (LobbyRift, DiveController, LastBreath), the Spire Ascent (Parkour) and the name duel
(LobbyDuel, Duel, DuelPanel). Gone for good, code, map pieces and props: the Lantern Run (RunLantern), the Reaper's
Sweep (dais, SweepScythe), Death's mark (the bell at the bowl's rim), the rune courtyard (tiles, slab, RuneTile; its
plateau is now the "shard garden", ISLET_SHARDS / bridgeShards) and the spirit trial (HauntBar button, board, quest).
Profile bests (lanternBest, sweepBest, markBest, runesBest, spiritBest) stay, written by nothing; Realm Walker and
Apple Toss can no longer be earned. The rift's glowing cracks and the two pale shard clusters on its rim are gone too
(they read as white shards round the vortex). Dive fixes: LobbyRift accepts a leaping diver (ENTER_ABOVE 16,
ENTER_REACH 1.45), LobbyGamesController's pit curtain skips while DiveController.busy(), and lobbyBelow/lobbyCity
haze is thinner (it hid the city 620 studs down). Models_Lobby v21, Maps_Lobby v38.
