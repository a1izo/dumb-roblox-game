---
name: scene-death-hits-and-blood
description: 2026-11-14 scene deaths: the drawn blood splats (SceneDeaths/Splat), Sam's hit effects and OPEN shift, why a scene's first 0.75 s is never seen, harness textures folder
metadata:
  type: reference
---

- Every scene death opens on black for about 0.75 s (SceneDeaths.play: the engine lights a new place late). Anything
  staged in that time is not seen. Sam's blade lock was: the scene now runs through a shifted ctx (`OPEN` = 1 s, in
  Sam.luau) that adds a second to every time, so the sheet's times stay as written; its Cosmetics `scene` is 15.
- `SceneDeaths/Splat.luau`: `Splat.screen(layer, {at, size, image, drips, hold, fade})` lands a drawn splat on the lens
  (pictures from `art/scripts/ui/blood_splats.py`: BloodSplatA-D, BloodDrip, uploaded as plain images, ids in the
  module); `Splat.spray(at, dir, amount)` throws dark drops in the world. Walrider's end and Sam's thrust use both.
- Sam's `hitFx(at, power, blood)`: flare, long orange sparks, embers, light, shake, a field-of-view punch, streaks across
  the lens (`lensSparks`), a vignette pulse. The COMBAT LOG is destroyed when the kanji lands.
- Big cloud particles must use the soft round glow (VfxGlow, light 0): the smoke flipbook's cells show as squares at
  80 studs.
- Harness: `-Attr DGVfxLocal` reads VFX and blood pictures from
  `<Studio version>/content/textures/dg_vfx_harness/` (copy art/export/textures/Vfx*.png and Blood*.png there after
  each Studio update; the folder goes with the old version). The harness place has no imports: sets are stand-ins.
- Faces of cast characters are marketplace face accessories (Cast.COSTUMES FaceAccessory), never drawn here.

- 2026-11-15 ("add more blood splatters to the cutscene that have them": only Let's dance! and Walrider have any):
  `Splat.ground(parent, at, normal, size, {image, seed, spread, hold})` lands a drawn splat as a decal on a floor or a
  wall (thrown on, then soaking out); `Splat.drips(ctx, partFn, offset, t0, t1, every, slow)` lets drops fall off a
  hand or a wound. Sam: the cut, the thrust (a pool under him, splats behind him), the hold (the wound runs), the
  pull; Walrider: a splat on every round of the volley, drops thrown past the lens on each hit, the hand dripping in
  the slow motion, twelve splats at the end.
- Cast faces (2026-11-15, "fix Snakes head glitching"): a marketplace face accessory sits ON the classic head's
  surface, so the head broke through it and the plain face showed under it. Cast now drops the head's face decal,
  gives a dressed player the classic head (Head = 0), and grows each face mesh out (`lift`, FACE_LIFT 1.035; Snake's
  eyepatch 1.075 over his face).

Related: [[deaths-batch2]], [[scene-death-sets]], [[studio-scene-preview-check]].
