---
name: butler-scene-rebuild-2026-11-17
description: RoleButler (the Butler's role briefing) rebuilt 2026-11-17 from the anime's Watari (episode 6) as art/scripts/cinema/shots/role_butler.py; what the scene is, the geometry facts and traps found (tray contents, the doorway, mirrored arms, the lift into the counter), what was not seen in the game
metadata:
  type: project
---

The owner (2026-11-16): "redo the butler cutscene entirely but still with those lines, the one from the anime". The line is kept
word for word ("Is something the matter? Hmm? ... What's wrong?", `voiceButler`). The reference is Watari in Death Note,
episode 6 (the scene where he stands by L's armchair, touches his hat, lays a hand flat on his chest, opens the case of badges);
notes in `art/refs/cinema/RoleButler.toml`. The old module is `role_watari_old.py` (unimported).

The scene: he straightens a cup on the tray, takes the tray up by its two ends, carries it on one hand through the pantry door
into Ace's dark room (the faceless shape in the chair), and asks with the left hand flat on his chest; nothing answers; black.

Facts and traps:
- The `TeaTray` prop already carries a teapot, two cups of tea and a cake slice (only a Teacup is not a separate model there).
  Nothing can stand on Ace's low table: the set's sweets cover it (the tray would sit on them), so he never sets it down.
- The doorways are 4 wide and a Butler with his arms is 4 wide: walk him down z = 0 and keep the free arm close (roll 1,
  not 7) or `--clear` reports the arm in the jamb.
- A tray lifted from the counter to a belt-height carry dips 0.8 into the counter on the way: lift it a hand's breadth higher
  first, and let the left hand go with the lift (it also dips through the counter if it simply swings to its side).
- Both hands on the tray all through the carry made the arms mirror images (motion report: symmetry 72 percent); the tray rides on
  the right hand alone and the left hangs.
- Preview stills use the plain mannequin (tan head box, no hair): judge poses and framing from them, not faces.
- Not seen in the game (no Studio was free). Needs only a script sync (Shots and Acting files, no import; Animations.blend was
  rebuilt and is committed with the clips).
Related: [[cutscene-walks-and-endings]], [[r6-camera-distance-visible-height]], [[youtube-reference-hunting]].
