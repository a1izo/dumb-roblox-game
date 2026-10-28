---
name: cutscene-pipeline
description: "How a Blender-authored cutscene is made end to end (ref → acting → cameras → checks → export → push), the tools and commands, and the owner's standing taste; read before any cutscene work"
metadata:
  node_type: memory
  type: reference
  originSessionId: 77501874-126d-4d88-adac-442fa1338f87
  modified: 2026-10-28T12:46:32.523Z
---

**The loop that works (Tokyo intro, Diavolo, Muerto; 2026-10-28):**
1. Watch the source scene: YouTube in the built-in browser; skip ads by playing muted until `.ad-showing` clears; draw a contact sheet in-page (a fixed canvas, seek `video.currentTime`, `drawImage` each frame, label times) and `zoom` a screenshot of it. Write `art/refs/cinema/<Shot>.toml` (origin, source url, beats with src times, timing/fit, r6 notes, check).
2. Map the set first: read `art/scripts/maps/venues/sets/<set>.py` and the prop functions (props*.py) for where desk items (screens, lamps) stand; Blender prop x maps straight to the world, prop y → world -z on a rot-180 desk (check against a still). Props that stand at head height block every side angle.
3. Acting in `art/scripts/cinema/shots/<file>.py`: a `body(lean, turn, roll)` → (joints, offset) helper and a `key()` wrapper; hands placed with `cinema.acting.body_reach(side, joints, offset, target_char, direction)` (kit.reach inside a leaning body; char frame = floor under the root, facing -z, +x his right); `local_of`/`to_torso` for conversions; props in hand via `kit.hold` solved at a key pose (pen grip: nib 0.54 down the pen's -y). Verify a pen nib numerically against the page (scratchpad nib.py pattern: sample motion, fk, nib = arm @ grip, compare to PAGE).
4. Cameras: `shot.pan(t0,t1,slot,pos, aim, dy, fov, operator=True, shake=, fov_to=, ease_move=, drift=, roll=)` for people; `framing.dolly(...)` for inserts (handheld, eased, zooming). Every non-CCTV camera moves AND breathes (owner: "the camera feels very stale" when locked). Cam groups must be in time order (sort `shot.cam_groups` if added out of order). Locked cameras only for in-world cameras (the `cctv` fx).
5. Checks (all must be clean): `run_cinema.py -- <Shot> --clear` → 0 problems; `--lint` (only intended close-up `[frame]` notes); `run_anims.py -- --add <Clip>,<Clip>,...` (COMMA-separated: space-separated names silently build only the first). Never stylua `src/shared/Cinema/Acting/` or `Shots/` (they are in .styluaignore, and Roblox keeps a script under about 200 000 characters: formatting a big acting file pushes it over; keep many-actor scenes' clips lean) BEFORE `--preview <Shot> --stills=t,...` with `DG_EXPOSURE=3` for dark sets; contact sheet via scratchpad `sheet.py` with hmvenv python (stills save as `Shot_14.png`, not `14.0`). Review EVERY cut's stills; fix, re-render.
6. Export `run_cinema.py -- --export <Shot>`; stylua + selene on changed Luau only; commit `git add -A -- . ':!src/shared/Assets.luau' ':!art/rig'`; pull; on an Animations.blend conflict take theirs and re-run run_anims --add for your clips; push.

**R6 lessons:** bowed heads show only hair (keep heads up in close shots; total head pitch ≥ about -20); arms crossing in front of the face kill frontal shots (follow-throughs low/out, last pose on the near side); big root turns (>11°) swing knees into desks; seated thighs level with hip = legs - lean; clearance treats desks as their top slab only.

**Game-side fx (ShotPlayer events):** focus, pulse, still, black, freeze, flash, shake, burst(pos), inkslash, slash(p0,p1,bend: curved crescent along a stroke, layered CanvasGroups), cctv(dur,label), drain, materialize. A Manual lying on a set opens over the shot with Shot.prop("Grimoire", open=[(t, 0..1)]) (game-side correct; the Blender preview still shows it open: a known preview gap). Shots.spec: voiced role scenes voiceAt 0.8–8.5, ≤8 s after the line ends.

**Owner's taste:** no drawn faces (own avatars), light focus only, no glowing eye blocks, effects replaced not removed when "uninspired", long readable cuts (~1.5–3 s), cause→effect, anime-faithful staging, motion with anticipation/overshoot/settle, never jittery loops. Related: [[cutscene-quality-bar]], [[studio-cutscene-testing]], [[r6-cutscene-redo]].
