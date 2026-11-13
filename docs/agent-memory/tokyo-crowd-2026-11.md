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

**C2 (trips).** `layout.crowd.ends` (written by `crowd.ends(w)`): 20 nodes, each `edge` or `door` with a weight: the
station's two hall doors (4), the avenue and the north street's far ends (3), the map-edge barricades (1.5), a door node
for the konbini, the ramen bar and the game centre (1.5; the last two are new nodes laid by `crowd.shops`, from the
opening nearest each clerk's post), the arcade's far end (2) and every other dead end (0.6). `posts()` now runs before
`walks()` because `shops` reads them. In `CrowdSim`: every end has a next-hop table built once in `CrowdSim.graph`
(`routesTo`, reverse Dijkstra over states "node, arrived by walk or crossing"; a crossing costs +15 studs and
stepping straight from one crossing onto another +60, so the old "no crossing onto a crossing" rule lives on as a cost);
a walker has `origin`/`dest` (indexes into `graph.ends`), `_enter` takes the next link from the table, at the trip's end
`_arrive` hides it for `AWAY` 2 to 8 s (`walker.away`; `shown = false`; `setShown` keeps `visible` apart so a meeting
does not bring it back early) and `_return` puts it on another end with a new destination. `seed` places walkers part-way
along random trips, never on a crossing. A graph with no `ends` gets every dead end (or every node of a ring), so small
test graphs work. The placeless 12% pause stays until C5. Also fixed: a walker whose step carried it past the kerb in
the same step that first tripped the wait check walked onto the crossing on the cars' light (found because trips send
everybody to a kerb); it now looks at the lamp again before it steps on. After C2 (seed 1, 300 s): U-turns 302 to 0,
revisits of a node 1179 to 7, dead-end lingering 306 stops to 0, 1.2 trips per walker a minute, 9% of walker time out of the
world. Overlap went UP (pairs closer than 1.2 studs 0.45% to 1.1% of samples) because trips share the same shortest
corridors: that is C3's job.

**C3 (walkers mind each other).** All in `CrowdSim`: `_grid` snapshots everyone at the start of a step (6 stud cells),
`_social` answers three things for each walker: a speed cap (it keeps `GAP` 1.8 studs behind anyone ahead within 1.5 of
its line and moving its way, and behind anyone standing for the lamp or a pause whatever their heading), a sideways
target (it steers to 1.8 studs from anyone alongside, round a slower or standing walker when the walk is wide enough, to
the right only when nobody is coming the other way within 14 studs) and who holds it back. Near a corner it looks both
along its walk and towards where the path goes on (`_lookAhead`): at the kerb the look-ahead swings to the crossing and
a walker standing just behind the node would otherwise fall out of view. `side` is at least 0.65 so two coming from
opposite ends are never closer than 1.3. Single-file walks form corridors (consecutive `single` links, built in
`CrowdSim.graph`): one direction at a time, entering waits (`yielding`) for anyone in the corridor going the other way,
and a trip starting or seeded at an end checks too (`_comingThrough(walker, link, node)`). Arrivals and seeds check the
spot is free (`_crowded`), and a pause is not begun where someone already stands. A walker held back for 3 s by people
who are not themselves waiting for something squeezes by for 1.5 s (`_queued` tells a kerb queue, which waits as long
as the lamp does, from a knot). Traps found: (1) holding back for ANY stationary walker at any heading gridlocked the
crowd slowly (trips fell from 260 to 160 a run): the "ahead" relation must be asymmetric, so only walkers within 53 degrees
of my heading count, plus those standing for reasons that depend on nobody (lamp, pause timer; not a yielder, or two
yielding at both ends of a narrow walk wait for each other for ever); (2) two single-file links meeting end to end made
both walkers yield at the node between them until corridors were modelled; (3) a first version with no deadlock fallback
looked fine for 60 s and froze by 300. After C3 (seed 1, 300 s): pairs closer than 1.2 studs 0.033% of samples
(1.09% after C2, 0.45% before the rework), 250 trips, 0 U-turns, kerb groups of two abreast in rows, a faster walker passes a
slower one on a wide walk and queues behind it on a narrow one. What is left are shoulder brushes of a few frames at corners
and at kerb nodes 2 studs apart (nodes 2 and 35). Specs: seven new ones, including a five-minute run on Tokyo's real layout.

**C4 (how they move).** `CrowdSim.KINDS`: a quarter of the walkers stroll (7 to 9 studs a second), half walk (10 to 12),
a quarter are in a hurry (13 to 15; a player walks at 16); `HURRY` on the crossing stays. Speed eases (`ACCEL` 20 up,
`DECEL` 30 down) and a walker brakes in time: for the gap behind someone (`sqrt(2 * BRAKING * room)` plus the leader's
own stopping distance, `BRAKING` 20) and for a stop it knows is coming (the lamp at a kerb, a narrow way taken by
someone else). The heading is its own thing (`_face`): it turns at most `TURN` (a full turn a second), aims at the
point it will be at one stud on (`TURN_AHEAD`, with its sideways offset so a walker on the inside of a corner does not
swing out first) and, standing within 8 studs of a kerb whose crossing it waits for, faces the crossing. The client
needs nothing for the feet: `LocomotionController` advances the stride by the ground the body covered (`setSpeed` gets
the displacement between two snapshots), so any pace from 7 to 15 follows. Routes: they are now over directed walks
(`routesTo`, `_first`, `_next`) and never go straight back along the walk just taken: the node-based version found that
after a crossing, going up a 7-stud dead-end spur and back "reset" the crossing-after-crossing cost and was cheaper
than paying it, so walkers made pointless U-turns (18 a five-minute run; found by the watcher, 0 after). Other fixes
that came with it: a gap rule that allows for a leader who then brakes at its full 30 (follower braking 20 closed the
gap to 1.1 studs), sideways steering that always honours whoever is alongside before whoever is ahead (two walkers side
by side in a packed queue each held still for the other for ever), and a walker may stand up to 3 studs before the start
of the walk it is about to enter so leaving a kerb does not clamp its place forward (`BEFORE`). After C4 (seed 1, 300 s,
the C2 layout): 231 trips, pairs closer than 1.2 studs 0.040% of samples, kerb waiters facing away from the crossing
0% (85 to 95% before), steps where a walker's speed changed by more than 60 studs/s^2: 171 (6180 before). Known: walkers
released together from side-by-side places at a kerb pass through the single point where the walk turns onto the
crossing and can brush for a frame or two; fixing it means changing how a turn maps sideways offsets.

**Graph clean-up after C4 (`crowd.merge_short`).** Nine walks were under 3 studs long (nodes laid almost on top of each
other: a 2.3-stud link joined two kerb nodes and three approaches met there, so a queue for the lamp stood in a heap
for the whole red). `merge_short` contracts each such walk (a kerb node never moves; two plain ones meet halfway when
the ground allows), re-links the neighbours, measures their widths again and closes the numbers up; 8 of 9 merged
(255 nodes, 261 links now), never a station door's node. On the spec's lamp cycle pairs closer than 1.2 studs fell from
0.16% to 0.07 to 0.1%. Not solved: two queues that meet at a corner hub from different links (headings more than 53
degrees apart) do not see each other and can stand 1 stud apart for a whole red phase (longest overlaps 40 s at the
kerbs near (-5,-46), (-77,-82) and (-7,-48)). The rule that would see them (any stationary walker, from any heading)
gridlocked the crowd when tried, see the C3 notes; a hub that holds them properly needs slots at the kerb.

**C5 (pauses with a reason).** `layout.crowd.spots` (`crowd.spots(w)`): 55 places a walker may stop, each with a facing
(`rot`, like a post's) and the walk it hangs off (`link` 1-based, `s` along it, within 4.5 studs, open ground between,
never a crossing or a single-file walk): 36 under low hanging shop signs (the 1F signs at about 6 studs: looking up at
them), 14 under awnings (facing the nearest street), 2 in front of vending machines, 3 at the river's rail. The station's
route map is 38 studs past the hall doors where nothing walks, so it is left out; the scramble itself has none (its
shops have no sign or awning at that height). The old placeless pause (`PAUSE`, `linger`) is gone. In `CrowdSim`, when a
walker enters a walk with spots it takes the nearest free one ahead with its kind's chance (`STOP_CHANCE`: strollers
0.2, walkers 0.1, people in a hurry never), steps off to it at 4.5 studs a second, turns to its facing, stands 3 to 10 s
(`STAND`), steps back to where it left the walk and goes on; a spot holds one walker (`spot.taken`), so the next one
passes by; a visitor counts as standing for a reason of its own to everyone else (`fixed`). Five minutes (seed 1): 68
visits (13.6 a minute among 50 walkers), 3% of walker time standing at one, 256 trips. Clerks (`_clerk`): within 8
studs of a player a clerk turns its body up to 40 degrees towards them for 1.5 to 4 s, goes back, and does not notice
anybody for 4 to 9 s more. The Life layer has no look target and the sign of a head yaw could not be checked without a
play test, so it is the body that turns, in the sim. Client (`World/Crowd`): a body that has stood still for half a
second within 45 studs of the camera gets `DGLife` = 1 (breath, weight, glances: Anim/Life) and, every few seconds, a
small upper-body idle picked by its number (`idleWatch`, `idleLook`, `idleGlance`, `idleHand`, `idleSleeve`, existing
clips: no animation work needed); all of it is under `pcall` so a missing clip can never stop the crowd being drawn.
Trap: a non-looping clip that is not given a `duration` is never stopped by `PoseController` (it holds its last pose
until told), so idles piled up four deep on one body in the first play test; each idle now passes its own length.
Checked in a play test with the OLD server sim (the place's scripts are older than main): a copy of the new
`World/Crowd` (it is in the bundle, `Client/World/Crowd`; parent a clone beside the game's own and `init()` it) drew 40
bodies, gave the standing ones life, never more than one idle at a time, and logged no error.

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
