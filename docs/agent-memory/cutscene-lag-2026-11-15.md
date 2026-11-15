---
name: cutscene-lag-2026-11-15
description: 2026-11-15 "fix the lag esp during cutscenes": the governor never cut effects ("emoteFx" is no cut), Emit's own quick frame watch, World/Away parks the crowd and rain while a cutscene plays far off, scene lamps' shadows follow the shadow cut
metadata:
  type: project
---

- **The governor never thinned an effect.** Emit.share, Vfx.low, FxKit, Aura and EmoteFx all asked
  `Governor.low("emoteFx")`; GovernorRules.CUTS has no such cut, so only the Low graphics setting ever lightened
  them. World/Governor maps it (`ALIAS = { emoteFx = "particles" }`).
- **The governor is too slow for a cutscene** (six slow seconds before a cut; a scene death is over in ten to
  twenty-five). Vfx/Emit keeps its own smoothed frame rate: under 40 fps every new burst and emitter makes 0.7 of its
  particles, under 26 0.45 (`pressure()`), on top of the touch and Low shares.
- **World/Away**: true when the camera is 900+ studs from the body (2x from the map's middle with no body): a scene
  death at SceneDeaths.ORIGIN, the win rooms, the Manual's stage, the shop's previews. While away the Tokyo crowd hides
  its bodies once and skips its whole draw (`parked`), and RainController takes its weather folder off the camera.
- **Shadows**: SceneDeaths Ctx:light and Sets' dressing lamps drop `Shadows` when `Governor.low("shadows")` (Low
  graphics, or the governor's third cut), as the maps' lamps do.
- Not measured in the engine (the user's Roblox and Studio were open: a harness launch beside them crashed their
  Studio once). The harness Perf probe measures frame costs per scene death when it can run.
Related: [[mobile-and-perf-2026-11]], [[studio-frame-rate-measure]].
