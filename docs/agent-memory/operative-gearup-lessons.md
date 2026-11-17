---
name: operative-gearup-lessons
description: What the RoleOperative rebuild (2026-11-17, gearing up in the locker room) taught about shooting a small prop (the badge case) and an actor facing a wall of lockers on R6; the numbers and the traps
metadata:
  type: reference
---

RoleOperative was rebuilt from an empty file (`art/scripts/cinema/shots/role_operative.py`; the old `role_taskforce.py` is kept
unimported; reference `art/refs/cinema/RoleOperative.toml`). The captions (the `card` events: role, win, move, names) and the
length 19 s are fixed by `Shots.spec` and the briefing screen, and the captions sit low left, so the subject lives right and high.

- **The badge case (`BureauBadge`) is 0.86 studs wide, 0.6 tall.** A head with avatar hair is about 2.4 wide. An insert that reads
  needs the lens 2 to 3 studs away at fov 18 to 24 (a frame about 1.4 to 2 studs wide); at 3.2 studs and fov 25 it was a speck
  beside a head. Aim it at where the case really is (print `framing.part(shot, slot, t, "lhand")` and add the carry offset), not
  at the pose's target: the first aims were 0.4 off and the case sat behind the chin.
- **Near arm in front of the prop.** A fist at the end of an arm that points at the lens shows its 1x1 end face and hides the
  case's lower half. What worked: the case floats 0.7 above the fist (resting on the knuckles), the lens a little above the arm's
  line and out to the holder's other side, so the dark suit and tie are the backdrop. A raking spot over about 1.3 brightness
  blows the leather and the enamel out to grey (2.8 did).
- **A held prop that must tilt toward the lens:** `Prop.at` takes CFrame.Angles(x, y, z) = Rx*Ry*Rz, so a pitch about the
  prop's own width after a yaw is `posekit.euler(ry(theta) @ rx(phi))`, not (phi, theta, 0).
- **An actor facing the lockers is hair and back from every room camera.** The lint's `[frame]` notes there are the story, not a
  fault; shoot those beats wide (fov 42 to 46 at 7 studs) from the far-arm side and put every face beat after the turn to the room
  (take the items first, then turn with the last one in hand).
- **The open locker's door plate** (a thin plate from (360.79, -4.87) to (360.44, -3.58)) leaves 1.4 studs of mouth; a 2 wide body
  stands east of it (P0 x 362.9, z -3.6) and uses the LEFT hand for the shelf. The shelf is 6.0 up: the arm needs `max_slide=1.0`
  (a stretch, shoulder-to-target 2.6) with the body leaned 24 to 26 degrees.
- **Hand to ear, collar and chin do not exist on R6** (the fist is under 1.3 studs from the shoulder): the earpiece is a hand at the
  lapel and a head tilt (neck roll 12, yaw -14).
- **`run_anims.py -- --add RoleOperative_self` takes about 7 minutes** and rewrites `src/shared/Anim/Clips` with other agents' emote
  drift: `git checkout -- src/shared/Anim/Clips` after it (the Operative's clip lives in `Cinema/Acting/RoleOperative.luau`).
  Stills read the clip from `Animations.blend`, but cameras, lights and prop paths come from the module, so those edits need no
  re-bake.
Related: [[r6-reach-limits]], [[r6-near-arm-occlusion]], [[fast-run-launcher]], [[cutscene-quality-bar]].
