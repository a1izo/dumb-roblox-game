---
name: clock-scene-2026-11-15
description: "Their time ran out" remade 2026-11-15 ("make the clock more high quality ... better altogether"): the dial in remade.py clock, hands/pendulum/wristwatch as Core 40 props, the victim on the boss, what holds between ticks
metadata:
  type: project
---

- **Set** (art/scripts/maps/venues/scenes/remade.py `clock`): enamel dial (DialEnamel / DialEnamelDeep flat
  materials; MarbleWhite's tiles ran round a lathe in rings of bricks), a moulded brass bezel (14-point profile, 144
  segments), a railroad minute track, the chapter ring, Roman numerals built stroke by stroke with serifs (`_glyph`,
  `_numeral`: radial, tops to the rim, IIII for four, each stroke at its own height so none share a plane), engraved
  circles, twelve brass lozenges, a rosette, the arbor and the BOSS: flat-topped at y 2.38, radius 3.3 to 4.05.
- **The victim stands on the boss** (Clock.luau `STAND` = (0, 2.38, 1.2)). Before, they stood inside the hub at the
  dial's middle and the hands swept through their legs.
- **Hands** (Core props SceneClockHourHand / Minute / Second, props_scenes.CLOCK_HANDS lengths and tails): placed by
  measuring the model's box at identity (the arbor = the box's tail end back by `tail`), at heights 0.5 / 1.0 / 1.42,
  under the boss. Stand-in boxes before the Core 40 import.
- **SceneClockPendulum** hangs at (0, 64, 56) behind the victim (in the back of the tick shots), swings 13 degrees;
  seven RustGears (Lobby props) 62 to 82 out turn on their axles; the pendulum, gears, sand streams, their splashes
  and the dust all follow `shown(t)` / TimeScale 0 between the ticks.
- **SceneWristwatch** (Costumes `wristwatch`, Left Arm): its face on the arm's FRONT (-Z), which faces the opening
  close-up in the WRIST_L pose (checked with rbxsim); a twinkle on it at 0.7.
- At the stop: a VfxCrack decal 26 across under them, a dust burst, sand pouring off the boss's edge (a Cylinder
  surface emitter), MEMENTO MORI on the dial between the boss and VI (SurfaceGui, Merriweather).
Related: [[deaths-today]], [[scene-death-sets]], [[deaths-batch2]].
