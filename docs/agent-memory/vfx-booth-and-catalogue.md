---
name: vfx-booth-and-catalogue
description: The effects catalogue (Presentation/Vfx/Catalog) and the debug booth (Debug/FxBooth, the Effects tab), 2026-11-16 ticket V0.1: how to play any one effect alone and hold it, and the traps in how it is built
---

Built for the VFX rework ([vfx-rework-plan-2026-11](vfx-rework-plan-2026-11.md), ticket V0.1). The panel's **Effects**
tab (F2) plays any effect in the game alone, on a dummy, in a grey cell 6000 studs out (`FxBooth.ORIGIN`; `World/Away`
parks the crowd and rain there).

- **Catalogue**: `Presentation/Vfx/Catalog.luau`, entries `{ id, family, source, tier, hit, length, play }` (plus label,
  budget, whole, loop, estimated). `Catalog.get()` is the game's list (emotes from `EmoteFx.clips()`); `Catalog.build(
  {emotes=...})` takes lists, which is what the server spec uses; `Catalog.check` returns the problems.
- **Booth hooks** (also `DebugPanel.fx`): `FxBooth.list()`, `play(id, opts)`, `stop()`, `at(id, seconds)` (plays, holds the
  kit's clock that many seconds after `hit`), `step(s)`, `release()`, `leftovers()` (count in `Camera.DGVfx`, 0 after
  Stop), `verify()`. `opts`: backdrop dark/lit, camera follow/close, hold, preview, yaw. `play` and `at` YIELD while a
  stopped effect settles (1.5 s); call them from their own thread.
- **Emotes play with `preview = false`** (a player's view, so the aura and the lights show). The ticket said `true`, but
  `EmoteFx.play(..., true)` returns nothing for the showpieces that `return nothing if preview` (New World and others)
  and never starts the aura. `FxBooth.play(id, { preview = true })` gives the shop's version.
- **`hit` for emotes** is the first accent beat read from `EmoteFx`'s `accent(...)` calls (table `FIRST_BEAT` in the
  catalogue); hand-made showpieces have `estimated = true` and hit 1.0 until V0.2 watches them. Whole scenes (wins, scene
  deaths, writing styles) have hit at half their length, also estimated.
- **Whole scenes** (`whole = true`: win cuts, scene deaths, writing styles) play on the player's own camera through
  `WinCinema.preview` / `BookStage`, as the cutscene gallery does, so the booth releases its camera first and the panel
  hides while they run (F2 brings it back). The kit's clock does not hold them.
- **Holding only freezes what the kit made** (`Clock.watch`): the emote's body clip (real time) and emitters made outside
  the kit (the old `DeathFx` ones) keep running.
- **A server spec cannot load `EmoteFx`** (its client requires reach `LocalPlayer`), so `VfxCatalog.spec` finds the Catalog
  through `StarterPlayer.StarterPlayerScripts.Client` (it requires shared data only) and builds it from the shop's own
  emote clips; the check against the real `EmoteFx.clips()` is `FxBooth.verify()` in a play test.
- **Looks**: the booth registers `FxBoothDark` / `FxBoothLit` into `LightingPresets.scenes` at runtime (clones of the
  Manual's look), on this client only; `LightingController.scene(key)` reads them by key.
- The debug window had 8 tabs at 62 px (524 px in a 480 px window); with nine, the tab width is now shared out.
- No verdict entries on purpose (the verdict styles were removed 2026-11-16); the family name stays in `Catalog.FAMILIES`.
