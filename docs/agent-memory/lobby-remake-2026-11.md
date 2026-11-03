---
name: lobby-remake-2026-11
description: The lobby (Grey Realm) remake of 2026-11-03 - what was remade, what was kept, what is left, the budget, and how its look was judged
metadata:
  type: project
---

Asked 2026-11-03: "start a new entire lobby redesign/refurbish/remake to a way more high quality one". Kept every decision
and gameplay piece (layout, rift and dive, throne with Most Wins, the Trial and its stations, tableaux, mini-games, darker
look, no symmetry rule); every anchor name kept.

Remade:
- All rock: the realm rock kit ([[realm-rock-kit]]); the ground: one relief surface ([[lobby-ground-relief]]).
- The title monolith as a tiled prop (`props_monolith.py` TitleMonolith: ashlar plinth, basalt slab, moulded title frame,
  chamfered spire, grooved cracks with red cores, chains); new lobby surface Basalt.
- The Academy's stations (`props_academy.py`): PracticeAltar remade and a new PracticeTablet stele that the drill slab is
  dressed with (Lobby.luau drillDesk; the name is written on its slate at STELE_BACK + STELE_SLATE).
- WinsStele, TableauBase (tableaux and the bell's base), CandleStone (the ready circle) and DuelStone (the name duel's
  two lecterns, same slope as LobbyGames' DUEL_SLATE_*) replace map geometry.
- BoneBrazier and LanternPost remade (`props_realmfire.py`), the black pines' pads and limbs, the apple tree's limbs, the
  giant skull's horns, the stone notebook's emblem, weathered bakes.
- The game's plain parts are dressed: SpireMarker (checkpoints), RuneTile, StartPad (their outline now on the pad), ShopPlinth.
- Clouds, bones, the rift's throat, chasms and plateau sides shade smooth.

Left as they were (candidates next time): ChessGame / ChessKingFallen, SkullPile, BoneScatter, Cairn, the giant skull's
cartoonish head shape, RobedStatue, Puppet and PuppeteerHand (designs asked for in October), the terrace and the Academy's pillars
(map masonry that already reads), the causeways' parapets, LightingPresets.lobby (not retuned).

Budget after: Lobby 64.29 / 66.09 MP, 38.79 / 40.83 MB, 114478 / 117218 map triangles. Look judged in Blender with a
scratch renderer that adds the lobby preset's haze from a distance pass (EEVEE world volumes black out the sky).
