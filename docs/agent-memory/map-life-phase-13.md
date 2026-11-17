---
name: map-life-phase-13
description: Phase 13 of the graphics plan (things that move): World/MapLife + World/Life/* kinds, what was found animatable in the baked maps and what was skipped, and how to add a kind
---

Written 2026-11-17 (written without Studio; nothing here has been seen in the game yet, see the plan's Phase 13 status).

**How it works.** `World/MapLife` waits until the camera is in a map (`LightingController.venue() == "map"`) and not in
Low quality, lets the map settle 1.5 s, sorts it out once (`World/Life/Util.index`: props by catalog name through the
`DeathsGambitProp` model attribute, signs by their writing, lamps = parts named "Light", rain covers, lighting boxes),
then stands up every kind in `World/Life` whose `maps` has the map id and steps it ~30 times a second. A kind returns
`{ step(env), destroy() }`; `destroy` puts back what it moved. A kind that errors is dropped with one warning. Pure
patterns (neon stutter, blink, cycle, sway, gust) are in `src/shared/LifePatterns.luau` with a spec. To add a kind:
a module returning a `Util.Kind` and one line in `KINDS` in MapLife.

**What in a baked map can move** (the lesson): the map's walls, floors, ceilings and fixtures are baked Blender
meshes and cannot move; what can is (1) a **prop** (a Model of its own: `Noren`, `Chochin`, `LanternString`, `MirrorBall`
can be tilted or turned with PivotTo), (2) a prop's **glow parts** (every colour in a catalog `glow` list is its own Neon
MeshPart with attribute `DeathsGambitGlow`: a desk's monitor, a server rack's LED rows, a vending display; change
`Color` only), (3) parts the map **builds itself** (the signs: a board with a SurfaceLight), (4) its **lamps** (existing
lights; touch only `Brightness` and restore at once), (5) **tagged markers** (LRainCover boxes, LLookZone building boxes
= footprint and height), (6) plain parts the client makes (a fan, a status lamp). Roller blinds, wall clocks (hands are
in the mesh, a red second hand included), vents and gratings are baked and were skipped; a wall clock's hand and the
HQ blinds need a re-export with those parts split off.

**Traps.** The Studio-less build guessed some spots (the fume hood's lamp, the ramen counter's steam, the open side of
an awning): each is found by a ray or from the prop's drawing and needs a look. `Blackout` turns glows to plastic and
saves their colour: kinds must not write glows while `env.blackout`. Sounds: no tube buzz exists, Tubes plays
`Assets.sfx.mapTubeBuzz` if someone adds it (never edit Assets.luau from here). A model's `GetScale()` is the placed
scale (props are scaled with ScaleTo); the catalog size is at scale 1.

**Why:** the owner's plan: "a room where nothing moves reads as a model".
**How to apply:** keep to the budgets in the VFX plan part 9 (world loop: 12 particles, 4 emitters, 0 lights), go
through `Emit.share()`, never add a light or a mesh, restore on destroy.
