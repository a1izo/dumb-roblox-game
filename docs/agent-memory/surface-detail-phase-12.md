---
name: surface-detail-phase-12
description: Graphics plan phase 12 (2026-11-26): wear marks (kit.wear, WearOffice sheet), pipe runs (kit.pipe_run), small notices (AgencyNotes sheet, fit.notice) on HQ's 38F service rooms and the University's labs; budget traps, what was left, the imports owed
metadata:
  type: project
---

Built 2026-11-26 as Maps Agency 38 and Maps Campus 37 (imports owed; nothing seen in Roblox, only in Blender previews).

**What exists, all reusable**

- `maps/wear.py` makes `art/export/textures/WearOffice.png` (512 x 512 RGBA alpha sheet, four 2 x 2 stud cells at 128 px
  a stud: 0 chair-height scuffs, 1 a damp stain that runs down from the top centre, 2 finger grime round a switch plate,
  3 the pale tape residue of a notice that came down). Flat 8 x 8 normal and roughness maps are written with it (the
  importer only makes a SurfaceAppearance, the only kind whose alpha the game can switch to transparency, when it has
  them). It is in `matlib.SHEETS` and `matlib.ALPHA`, so SceneMaterials gets `alpha = true` for it.
- `kit.wear` (called from `kit.wall` when a trim spec has `"wear": True`): 0 to 3 marks per wall face from a hash of where
  the wall stands, three different kinds in a row, 2 studs apart, never on glass, a door or a casing. Scuffs sit at
  0.65..2.65 up (on a dado face 0.13 out, clear of the stiles), tape marks at 4.6..6.6, a switch plate (0.34 x 0.55) at
  4.2 beside a door with its halo. Agency: `fit.partition(..., wear=True)`; Campus: the same flag on its own
  `partition`.
- `kit.pipe_run(s, a, b, y, out, seed=..)`: an 8-sided steel pipe along a wall face with a clamp every 6 studs, a collar at
  every joint and, under the first three collars, a stain quad. About 250 triangles for 25 studs. Used at `C - 1.1`
  (11.9) in the security office, the interview hall, the copy room, the locker room, the break room, the corridor, and the
  University's two labs and hall.
- `prints.py` has a second Agency sheet, `AgencyNotes` (512 px, 3 x 2 notices: 0 fire notice, 1 duty roster, 2 memo, 3
  handwritten note, 4 authorised persons only, 5 cleaning rota), made by `blender -b --factory-startup --python
  art/scripts/maps/prints.py -- AgencyNotes` (`SIZES` lets a sheet be smaller than 1024). `venues/agency/fit.notice(s, x, z,
  out, y, w, index)` hangs one at 0.10 off the face with two scraps of tape. `venues/campus/fit.notice` builds a fire notice
  from boxes (white sheet, dark header, yellow rule, teal arrow, text bars) because the campus has no megapixels.

**Decisions and traps**

- The ceiling tile grid the plan asks for already existed: `Ceiling` and `CeilingDark` are polystyrene with `joint=(4, 4)`
  in scanlib, a normal-mapped grid in every office and lab ceiling (seen in every preview). Nothing added.
- Drawer labels already exist on the Agency's `BureauCabinet` (card frames and typed marks), cork boards are the
  `PinBoard` prop (pinned notes and string in its texture), and the Agency already has a wall clock prop in most rooms.
  New: clocks in the copy room and the locker room, and the University's lab.
- Megapixels: a scene's textures are counted once from its FBX. WearOffice (0.26 MP) and PrintsAgencyNotes (0.26 MP) go
  to Agency only (125.20 of 127.66 after). Campus is 0.07 MP over its line and may not grow, so it takes
  `"wear": "grime"`: the same placement drawn from the existing `GrimeWall` cells (kicks, spots, the rub round a switch),
  no tape marks and no new texture (160.35 before and after).
- Z-fight rule: `finders.zfight` flags parallel faces within 0.02 studs. The grime sits at 0.03, wear at 0.07, notices at
  0.10, a switch plate is 0.12 deep (its back on the wall). A first try with wear at 0.05 gave ten finds.
- Box faces: a box's local -z face is its wall's "n" side, so never copy `skip=("-z",)` onto a prop that may face either way.
- Generated files under `src/server/Maps/Scenes/`, `SceneMaterials.luau` and `MapBounds.luau` are in `.styluaignore`: do not run
  stylua on them (it rewrote 5,000 lines of lights). After an export, `git checkout HEAD --` them and export again if the
  version bumped twice, as `export-restores-binaries.md` says.
- The sergeant's office (HQ 38F, `lower.sergeant`) was not touched: its east and south walls are a wood dado under a
  blinds window with no solid wall above, so a clock or notice has no wall there, and the north/west are glass. Do it only
  with a partition edit.
- Cost: Agency 106,180 to 107,838 triangles (limit 112,761), Campus 160,301 to 161,927 (limit 166,763).
- `art/export/scenes/<Venue>.json` finds after: Agency zfight 28 (all rugs, as before), Campus none from this work;
  `find_ghosts.py` lists nothing of ours; `check_v2` Agency and Campus ok.

**Not done:** the Tokyo map (no budget: 0 triangles allowed), the 39F rooms, the plan's step 4 (things on top of things: boxes
on cupboards, a mug, a coat on a chair: props are placed one by one and each needs its footprint checked), the University's
canteen and library. Look in Roblox after the imports: the stain and scuff alpha are only judged in Blender (the real
surface appearance with Transparency alpha is what ScratchNames and GrimeWall already use).

**Why:** the owner's graphics plan (docs/handoff/graphics-and-crowd-plan-2026-11-13.md, phase 12). **How to apply:** put
`wear=True` on a partition to get marks, call `kit.pipe_run` for a service run, `fit.notice` for paper; check the budget first.
