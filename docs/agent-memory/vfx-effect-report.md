---
name: vfx-effect-report
description: The effect report (Presentation/Vfx/Probe, FxBooth.report / reportAll, ticket V0.5, 2026-11-16): what it records, what it cannot see, how each check is read, how to run it
---

The plan's Part 3 as numbers ([vfx-rework-plan-2026-11](vfx-rework-plan-2026-11.md), ticket V0.5). A floor, not a judge:
passing it does not make an effect good.

**Run it** (Studio, a play test, the client; each call yields, so give it its own thread):
`DebugPanel.fx.report("recipe_slam")` plays one effect with the probe on for `max(length, hit + 1.6) + 0.3` seconds and
prints `[FxReport] PASS|FAIL <id> <- reasons | layers n, dots x% | peak ... particles, big, emitters, lights (budget)`.
`DebugPanel.fx.reportAll({ families = {...}, ids = {...}, skip = {...} })` does the whole catalogue (minutes) and prints a
Markdown table (`FxBooth.reportTable`). Nothing else changes in play: the probe is off unless a report runs.

**What records**: one `if Probe.on then` line in `Emit.make` / `Emit.burst`, `Beams.make`, `Shape.grow`, `Light.flash` and
`Light.hold`, `Screen.shake/flash/punch/impact`. On top of that `FxBooth.report` listens to `workspace.DescendantAdded` and
reads every emitter, beam and light made outside the kit (`Probe.raw`), so old effects (SceneDeaths, DeathFx, EmoteFx's own
parts) show too. Rows far from the dummy (250 studs) are another system's and are dropped, except for whole scenes (win cuts,
scene deaths, writing styles), which build elsewhere and are not position-filtered.

**What it cannot see** (say so in any report):
- `emitter:Emit(n)` called by hand on an emitter with no rate: the row is there (a layer) but its count is not; the line
  says `(+N by hand)` and those particles are not in the peak. Anything after `Emit.make` that changes size, colour or alpha
  sequences is not seen either (a row is read once, as made; `Rate` and `Enabled` are followed).
- Parts, meshes, highlights, sounds, and a Neon part's real brightness (a shape counts as bright 1, light 1 if Neon).
- Sizes are the particle's size in studs, not the effect's extent; "over 3 studs" means the biggest layer's size.
- Counts are designed at 100% (the count asked for, the spec's rate), not after `Emit.share()`.

**How each check is read** (`Probe.judge`, pure, spec `VfxProbe.spec`):
- dots: layers (distinct looks; repeats of one look fold into one) whose texture is VfxGlow/Ember/Flare or AuraGlow/Specks/Twinkle.
  Fail over half, or no layer with a shaped texture or mesh. A beam or particle of any other texture counts as shaped
  (VfxStreak, VfxSmoke, VfxDust too: the ticket names only the three).
- moments (not loops): a layer starting before `hit - 0.05` (gather); the layer scoring best on size and brightness together
  (each as a share of the most) starts within 0.05 s of `hit`; a layer alive past `hit + 1.0` (residue). Loops: a burst in the
  first 0.6 s and at least four layers. `hit` for showpiece emotes and whole scenes is a guess (`estimated`), so those lines
  say so in their notes.
- pops: lives over 0.6 s, born under 0.5 transparency at over a third of its size; or dies under 0.9 transparency with a size
  over 5% of its biggest (not shrunk to nothing).
- values: a layer with `light` under 0.5 when the biggest layer is over 3 studs; a layer with `bright` 2 or more.
- light: a light alive at the hit and started by hit + 0.1, for tiers sealed, condemned, godhood.
- cost: the peak at any moment, read every 0.05 s, against `Probe.BUDGETS` (Part 9). A rate's alive count is rate times its
  average life.

**Traps**: Light.hold records its target brightness (it fades in from 0). A server spec reaches Probe through
`StarterPlayer.StarterPlayerScripts.Client` like VfxCatalog.spec; Probe requires nothing so it loads there.
