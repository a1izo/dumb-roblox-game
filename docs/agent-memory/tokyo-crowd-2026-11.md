---
name: tokyo-crowd-2026-11
description: The Tokyo crowd rework (plan Part B, phases C1 to C6, started 2026-11-13): what the crowd did before, what each phase changed, where the pieces are and how to measure it
metadata:
  type: project
---

The owner (2026-11-13): "fix the logic of the npcs on the tokyo map" and did not say which behaviour looks wrong. The
plan is `docs/handoff/graphics-and-crowd-plan-2026-11-13.md`, Part B. If the owner names something not on its list, that
comes first.

**Where it lives.** Walk graph: `art/scripts/maps/venues/tokyo/crowd.py` (exported to
`src/server/Maps/Scenes/Tokyo/Layout/init.luau`). Sim (plain maths, deterministic for a `Random`):
`src/server/Maps/Mechanics/TokyoDistrict/CrowdSim.luau`; its server wrapper and sight lines: `Crowd.luau`; stepping and
snapshots: `init.luau`. Client bodies: `src/client/World/Crowd.luau`. Specs: `Tests/CrowdSim.spec.luau`, the contract
rules in `Maps/MapContract.luau` (`validateCrowd`) and `check_v2.py` (`crowd_and_traffic`).

**The crowd as watched on 2026-11-13 (before C1; seed 1, 300 s, 50 walkers, `scripts/crowd/watch.luau`).** Walkers
double back all the time (straightness 0.06: net distance from the start is 6% of the path walked; 31% of walker time is
spent lingering, 306 stops a run at the 14 dead ends); 0.45% of walker pairs are closer than 1.2 studs at any moment
(about 5 pairs overlapping, some at 0.00: on the same spot); speed jumps by up to 478 studs/s^2 and the heading by
5400 deg/s (starts, stops and turns snap); 85% of the walkers waiting at a kerb face away from the crossing; two or more
walkers are within 5 studs of the scramble's centre only 2.5% of the time (11% during WALK, never in CARS). The graph
had 2 doubled links and 27 links 1 stud wide or less. Seen in a play test as well: the crowd is thin round the scramble.

**C1 (graph).** `Walks.link` skips a pair already linked (the doubles came from `_tie` and `join`). `widen(w)` moves the
nodes of each link under 1.5 wide (never a kerb, a crossing's end or a station door) up to 2.5 studs, three passes,
to wherever every walk at the node is open and wide; 21 of the 27 narrow links were widened, the 6 left (yokocho and
alley pavement that really is that narrow) carry `single = true`. The sim reads it (`link.single`); phase C3 uses it.
Rules: `check_v2` (laid twice, narrow without single) and `MapContract.validateCrowd` (the same, run on the real layout
by `MapContract.spec`). Tokyo export: only `Layout/init.luau` changed, Maps v47 and its mesh digest kept.

**How to iterate.** The Tokyo scene builds in 7 s in Blender with no export: a scratch script that does
`module.build(mesher.Scene("Tokyo", prefix="Map", chunk=128.0))` and prints `scene.crowd` shows a change to
`crowd.py` at once (the full `run_maps.py -- Tokyo --export` takes 100 s). Everything Luau goes through the bundle in
[[spec-bundle-via-rbxasset]]: `python scripts/crowd/bundle.py`, then `run.luau` for the specs and `watch.luau` for the
numbers above, no play test needed. After an export, `git checkout --` the Tokyo blend and FBX, `ImportVersions.luau`
and `art/export/previews/light_Tokyo.png` ([[export-restores-binaries]]).

**Play-test traps (2026-11-13).** The place's scripts are older than main and writes into the shared place are blocked
([[studio-shared-place-write-blocked]]), so a play test shows the OLD sim. `MapService.build("TokyoDistrict")` does not
start the mechanic: call `Mechanics.adopt("TokyoDistrict", TokyoDistrictModule, { map = info, rng = Random.new(5),
matchId = 0 })` after it, then the crowd runs and snapshots flow (`TD.debug("cars")` / `"walk"` turn the lamps). In
my parked off-screen Studio the game's own client `World/Crowd` drew no bodies although the snapshots arrived (a copy of
its source made as an unparented sibling module and `init()`ed drew 40, so the code is fine; cause not found, perhaps the
15 fps governor or a late client init): to see the crowd, run such a copy. Another agent's Studio may be closed under you
(the lighting agent closes theirs when it finishes); launch your own, parked off screen, per [[studio-no-screen]].

Related: [[graphics-references-2026-11]], [[mobile-and-perf-2026-11]].
