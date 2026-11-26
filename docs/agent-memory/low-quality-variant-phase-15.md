---
name: low-quality-variant-phase-15
description: Graphics plan phase 15 (2026-11-26): what the three finished rooms look like at graphics level 1, 3, 5, 10 and 21 in Studio, what is lost where (bloom between 10 and 5), and the maps-only low-quality variant (LightingPresets.lowness, LightingController reads Rendering.QualityLevel)
metadata:
  type: project
---

**What breaks where** (Studio play test, real camera pinned, quality set from the Client with
`settings().Rendering.QualityLevel = Enum.QualityLevel.Level03`; pictures `docs/handoff/refs/p15-*.jpg`): lamps, their
pools, the grade, the haze, the materials and the sky hold at every level down to 1; HQ's office and the University's
hall look nearly the same at 3 as at 21 (never black, never evenly grey). What goes is the **bloom**: a window's halo and
a neon strip's glow are there at level 10 and gone at level 5 (and the BloomEffect still reads `Enabled = true`, so a
script cannot tell), and the wet-street sheen is gone from 10 down. Tokyo is the room that loses most (its signs and
window glow carry it). The Tokyo billboard cycles its ads, so two captures can show a different sign: not a quality effect.

**What was built.** `LightingPresets.LOW_UNDER = 7` (the same 7 as `World/QualityNotice`), `LightingPresets.lowness(level)`
(0 from level 7 up, 1 at level 1, 0.25 on Automatic = 0, 0 when unreadable) and a `lowness` option of `resolve`: up to
+0.1 saturation, +0.06 contrast, +8% air (density), +12% fill under a cap of 55/255 (never lowers a preset above it: Campus
and Tokyo are at 56 already, HQ goes 52 to 55); the bloom values are untouched. `LightingController` reads
`settings().Rendering.QualityLevel` (pcall, EnumItem.Value) every 0.5 s, re-applies the look when it changes, and passes it
for **maps only** (the Grey Realm is grey on purpose, the meeting room has its own key).

**Not verified:** the controller itself was not run in the place (its scripts are older than main until a Rojo sync); the
Tokyo q3 picture with the variant was made by writing the same deltas onto the grade by hand. Whether Roblox returns the
resolved level or Automatic (0) for `Rendering.QualityLevel` on a phone on Automatic was not seen: Automatic gets a quarter
of the variant by design. `DGForceDevice` changes layout only, it does not change the quality level, so a phone test in
Studio needs the quality set by hand.

**Spec trap fixed on the way:** `LightingPresets.spec` "keeps the rebuilt maps readable" failed in every Studio run on a float
rounding (a Color3 of 56 reads back a hair over `56 / 255`); it allows 1e-6 now. Related: [[graphics-references-2026-11]].
