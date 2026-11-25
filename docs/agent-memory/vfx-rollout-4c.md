---
name: vfx-rollout-4c
description: Stage 4c (2026-11-25), cosmetics on the new VFX kit: Manual covers, writing styles, Deathsinger forms, the win cuts' fx kinds; which Pilot flags are ON or OFF and why, report numbers, and the booth tricks that finally gave pictures of short and soft effects
---
**Flags in `Vfx/Pilot.luau` (old code kept behind each, read at call time).**
ON (seen in a booth or UI picture): `coverOxblood`, `coverGilded`, `coverBurnt`, `coverIron` (+ the pilot's `cover` = Black Mirror),
`writeQuill`, `writeTypewriter`, `writeFire`, `writeKnife`, `writeChalk`, `writeFrost`, `winFxImpact`, `winFxGlint`, `winFxPillar`.
OFF, built but not seen or not better: `coverCasefile`, `coverScale` (the report says PASS for scale and 1 reason for casefile, but neither
showed in a single picture, before or after), `formEmbers/Veil/Chains/Crows/Moths` (retired from sale; the booth showed only the shoulder
flames, identical in both builds; the marionette has no particles so it has no flag), `winFxWave/Bolt/Sparks/Bloom/Ring/Dust/Embers/Motes/Ash/Drizzle`
(rings of two dummies overlapped, sparks and arcs had left the frame, the held kinds are rate emitters; `light` is a plain lamp flash, nothing to move).
**Where the code is.** Covers: `World/CoverTells.luau` (`FRESH_TELLS`, `COVER_FLAG`; `STYLES.__index` reads the flag per call). Writing:
`Presentation/Styles.luau` (`kit(flag, new, old)` picks a new mark when the flag is on AND the new texture is in the place; `mark` got `once`
(a one-shot sheet runs its frames once over the mark's life) and `variants` (one random cell held)). Forms: same file, `freshEmbers/Veil/Chains/
Crows/Moths` + `ignite` (a glint when the form is put on) + `chestGlow`. Win cuts: new `Vfx/Fresh/Win.luau` (`Fresh.Win.wave/sparks/bloom/ring/dust`
and `HELD`), called from `WinCinema.FX` behind `winFx<Kind>`; the held kinds read their flag by name (`winFxEmbers`...). `Catalog` has 13 new
`winfx_<kind>` entries (family `moment`: the `win` family must be `whole`) that call `WinCinema.ACTS.fx` with stand-in refs; `WIN_FX_LATE` is the
recipe's own lead.
**Report, booth, before to after.** cover_oxblood FAIL (1 layer, 100% dots, 3 lights) to PASS (5 emitters, 1 light); gilded FAIL to PASS; burnt
FAIL to PASS (5 emitters); iron FAIL to PASS (4 emitters, 2 lights); casefile 3 reasons to 2 (one layer, no core: paper does not glow); scale
FAIL to PASS (unseen); winfx_impact 4 reasons/14 emitters/27% dots to 1 reason/8 emitters/0%; glint FAIL to PASS; pillar 4 reasons to 1 ("no gather":
an act fires ON the beat, no lead). Cancel halfway: `fx.leftovers` 0 for every entry, old and new. `fx.verify` 0 problems, 93 entries, no duplicate ids.
**Pictures** (`art/export/previews/vfx/rollout/<name>_compare.png`, untracked; left = before, right = after, except the winFx ones: swapped
back by `save.ps1 -Swap` so left = before): coverOxblood, coverGilded, coverBurnt, coverIron, writeQuill, writeTypewriter, writeFire, writeKnife,
writeChalk, writeFrost, winFxImpact, winFxGlint, winFxPillar. Covers and the three wins are a BURST of 8 emitted on both dummies (a handful at
once, so they stand in for the written-in rate, not the real number alive); the old effect is invisible or tiny in most.
**Full colour.** Shop effects wear their colour: covers use `Palette.shop(colour)` for stars and sparks, but a GLOW (mist) must use
`{ colour, colour, deeper }`: a ramp that starts white-hot makes a soft mist read as a grey haze (seen on the iron cover).
**How to photograph short and soft effects in the booth (new).** (1) A private copy of the client in a Play client as in the third-batch note
(rojo build `src/client` to a NEW `dgx_*.rbxm` in Studio's `content` each time; GetObjects; delete old ones). (2) The private
LightingController is never init()ed, so the booth stays navy-dark: hold your own Ambient/Brightness on `RenderStepped` for the shot (about
55 to 105 ambient) and turn DGIntro off. (3) A capture comes about 1 s after the call returns, so any emitter with a life under 1.5 s is dead
by then: set the emitters' `TimeScale` to 0.25 to 0.5 BEFORE emitting (`e.TimeScale = ts; e:Emit(8)`), in its own call, then capture. Never set
`TimeScale` to 0 or 0.001, or `Clock.hold(true)`: the frozen particles are drawn at age 0 and are invisible; and `Clock.hold(false)` before the next
shot. (4) A second dummy: `body:Clone()` PivotTo +6 studs X, `entry.play({ body, root, floor, at, props, preview = false, done })`; a flag flipped
between the two plays gives old and new in one picture; the camera looks along -Z from z above 6000 (right = +X = the new one) or from below (swapped).
Delete the clone before the next pair or the pictures fill with dummies. (5) NEVER print whole `GetDescendants()` of the camera or workspace:
hundreds of Rain/Splash emitters. (6) Writing styles are UI: build a ScreenGui with `Styles.page`, a clip Frame and a TextLabel and call
`Styles.write(clip, label, shown, pace, style)` on the private Styles; the flag is read while it writes, so run the old then the new, one
capture each (whole `writing_*` catalogue entries need the real LightingController and fail on a private copy with "TweenService:Create ... null").
**Traps.** `VfxFire`, `VfxFireBurst`, `VfxCandle`, `VfxAuraFlame` (V1.2) are NOT in ModelsFx 4: `Tex.real` is false and `Tex.id` falls to a
sparkle (no FALLBACK entry), so never use them unguarded: `freshEmbers` falls back to `VfxFlame`, and the writing marks go through `kit()` which
checks `Tex.real`. A mark that cuts a sheet needs `grid`: the old writing dust (`VfxDust` with no grid) drew the whole 4x4 sheet as a dotted
grid in chalk and typewriter (the new marks do not). Stylua rewrote `x:Emit(...)(expr).Destroying` on a line starting with `(`: keep a local
for such a line (a line starting with a parenthesis is a call on the line above in Luau).
**Unseen / weak.** Low graphics, the phone share and Reduce motion were not looked at (the marks and tells are unchanged in rate logic; the writing
marks are skipped when quiet as before). The real written-in rate of the covers was not photographed. The frost crystals were retinted bluer after the
picture; the knife stars and the quill smoke are big on the page (a taste call). The forms' loops and the wins' held kinds are untried by eye.
**Watching the eight win cuts in a play session (2026-11-25): NOT done, and why.** (1) In the Studio MCP play session the place's own client had not
run `Cinema.init()` (`DeathsGambitWorld` held only `DeviceScale`; the real `WinCinema.preview` returned true and died at once with
"win cutscene finalPage: Motion:70: table index is nil", from `Cinema.letterbox` using a nil `topBar`); that is the place's client boot in Studio
(an old-script place, the owner's sync still owed), not a repo bug: `Cinema.init()` is called at `src/client/init.client.luau:210`. (2) A private copy of
the worktree client (as above) plays the cuts after `CameraDirector.init()` and `Cinema.init()` are called on it by hand (`WC.preview("finalPage")`
then returns true, `WC.current` is set, the camera moves round ORIGIN 6000,600,-6000), but the private LightingController has no scene look, so every
picture was black or a dark lobby and says nothing about key/rim light or the actor; the numeric sampler (head projected to the viewport every 0.2 s)
read `WC.lastRefs` before it was rebuilt for the new cut, so its figures were lagging by a cut and are not reported. No plain bug in the cuts was seen.
To do it properly: the owner syncs scripts, then plays each cut from the Debug cutscene gallery (Show tab, F2) in a real Studio play session, or a
harness probe (`docs/handoff/harness/Gallery.server.luau`) steps them with screenshots at fixed times.
