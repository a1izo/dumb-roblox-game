---
name: cutscene-walks-and-endings
description: Why the RoleAce Butler's walk and the scene's ending read as "off" and "awkward" (measured in the game, 2026-11-15), what fixed them (eased travel, a curved arrival, an exit, a released stare), and the [end] lint
metadata:
  type: feedback
---

The owner on RoleAce (2026-11-14): the Butler's walk is "kinda off", the cutscene "isn't exiting", the final camera pan gives
"second hand embarrassment". The real briefing in the game ended on time and put everything back
([[studio-real-briefing-play-test]]), so "not exiting" was the ending, not a hang: the last 5.8 s held Ace's stare at the lens
while the lens crept in, then 2.3 s of wide with the servant left standing and nothing to close the scene.

**The walk, in numbers sampled every frame in the game:** a constant 4.0 studs a second that began at once and stopped dead on
arrival; 1.33 s cycles of 2.7 stud steps; a 50 degree pivot on the spot 0.3 s after the stop to face Ace; the torso rigid (lean
3 degrees, roll 0.7) and both arms and the tray dead still (a level tray is right, a rigid body is not); in the pantry he stood
dead still for 5.8 s. The motion report passed all of it.
**What fixed it** (`role_ace.py: travel()`): a slower walk for a man with tea (3 studs a second), eased up over 0.6 s and
down over 0.8 s, the heading turned into the person he serves over the last 1.3 s of the walk along a curved approach (never a
pivot after a stop), small moves while waiting, and a way out (he leaves by the door).

**The ending:** a held look into the lens is cringe when it runs on (the lens creeping in for 5.8 s) and a scene that stops
without anything leaving or resolving feels like it never exits. Release the look (Ace turns back to his screens), let someone
leave, keep the last cut short and still, cut to black for the card (`fx black` at the end, 0.35 s). `run_cinema.py --lint` now
prints `[end]` notes (`cinema/shot.py: end_lint`): a last cut over 4.5 s, events, camera keys or a spoken line past the shot's end,
and an actor still moving at 0.6 studs a second or more as the shot ends.
**How to apply:** after any scene with a walker or a held look, sample the walk in the game, read the `[end]` lines, and watch
the real briefing from the first frame to the role card. Related: [[cutscene-quality-bar]], [[animation-bar]], [[cutscene-footwork]].
