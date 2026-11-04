---
name: tiny-parts-bake-colour
description: A prop's small separate parts (keys, buttons, labels) can bake in a random colour; fixed in modelkit for new bakes 2026-11-04, older bakes still carry it
metadata:
  type: project
---

A baked prop's colour map holds every part at the prop's texel density, which for a big prop with many parts is low:
the CRT bank's 384 square studs baked at about 9 px a stud, and only 3% of its 1024 map held surface. A keyboard key
came out a fifth of a texel. The bake reaches no texel of an island that small, so the key took whatever colour lay
next to it in the map: about 4 keys in 10 were black, the rest beige, by chance.

`modelkit._snap_slivers` already gave a sliver the colour of the bigger island next to it in the mesh. On 2026-11-04
it learned the case of a small part with nothing bigger next to it: it is laid inside the biggest face of the nearest
island of its own material that is big enough. The CRT bank's keys, deck buttons and CAM labels now wear their own
colours.

**Why:** at preview size the defect is invisible, and a close look at a desk showed a chequered keyboard.

**How to apply:** the fix reaches a prop only when it is rebuilt and baked again. On 2026-11-04, 25 props baked under
16 px a stud, the CRT bank among them; the others not yet rebuilt include the Tree, BoneThrone, TrainHead, TrainMiddle,
ShoeLockers, Bus, BeerCrates and SnowTaxi. When you rebuild one, look at close renders of its small parts, and expect
them to change colour.
