---
name: r6-camera-distance-visible-height
description: How far a cutscene camera must stand to frame an R6 body (the visible height is 0.78 x 2 x distance x tan(fov/2)); the numbers that fooled the RoleButler cameras on 2026-11-17 and why the pantry limits what can be shot
metadata:
  type: reference
---

A shot's `fov` is the vertical lens angle, and the letterbox hides 11 percent top and bottom, so the height of world you see
at distance `d` studs is `0.78 x 2 x d x tan(fov/2)`. A standing R6 is 5 studs tall, 6.4 with the hair, and a body bent over a
counter has its head forward and low:

- head and shoulders (2.6 studs): fov 30 from about 6 studs; fov 40 from about 4.5.
- the whole figure (6.4 studs): fov 40 from about 11 studs; fov 46 from about 9.5.
- RoleButler's first cameras were placed by feel at 4 to 5 studs with fov 36 to 44 and every frame was a head filling the
  screen with the letterbox cutting it (stills, 2026-11-17). Work the distance out before placing the camera, or render a free
  camera still (`review_stills.py ... "t@px,py,pz,tx,ty,tz,fov"`) first.
- A camera 2 to 3 studs from a bent figure sees the near arm as a wall of black: put the camera where the lens sees the
  figure, not its arm (see [[r6-near-arm-occlusion]]), and aim a bent figure higher than its torso (`dy` +0.5 to +1.3) or its
  head rides the top letterbox.
- A narrow set (the Butler's pantry is 14 by 12, its counter against the north wall) allows a front view of someone at the
  counter only from above the counter or from the room's far corners; the corners (east end, high west) worked, and a long
  look through the doorway to the room beyond gave the depth.
Related: [[cutscene-pipeline]], [[held-camera-and-sides]].
