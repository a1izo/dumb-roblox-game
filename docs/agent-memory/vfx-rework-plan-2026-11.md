---
name: vfx-rework-plan-2026-11
description: The owner's 2026-11-16 verdict on effects ("horrible and cheap": animations, emotes, cosmetics), what the check behind the plan found, and the plan's order with its hard stop after the pilot
metadata:
  type: project
---

On 2026-11-16 the owner said: "currently anything that uses vfx such as animations, emotes, cosmetics etc look
horrible and cheap", and asked for a plan to rework all of it that cheaper models can carry out.

The plan: `docs/handoff/vfx-rework-plan-2026-11-16.md` (tickets V0.1 to V5.1, a Status block, a Log).

What the check behind it found that day:

- **Not a missing import.** The running place had the real Fx textures (121 `Tex_` carrier quads, every `Vfx*` name
  resolved), so `Vfx/Tex.luau` was not falling back to Roblox's sparkle. Only `Tex_FxPuff` did not resolve.
- **The textures are numpy formulas, small and flat in their cells.** VfxSmoke fills 19% of a 128 px cell with a
  tone spread of 0.044; VfxWisp 6%; VfxCandleFlame 20%; VfxCrack is one tone. Look at them with
  `art/scripts/vfx/preview.py` (over dark, tinted), never in an image viewer: they are white on clear.
- **Six plain sprites are 68% of all `tex = "..."` uses in `src`** (glow, ember, flare, smoke, dust, streak); the
  shaped ones are 5%. In the running place 254 of 476 live emitters and beams wore VfxGlow.
- **Nothing erodes** (every particle leaves by fading), and **no tool shows an effect as pictures** (`Clock.hold`
  exists; nothing uses it).

**Decided 2026-11-16, colour:** asked whether shop effects (emotes, cosmetics) should use full colour instead of
the grey rule, the owner said "Yes, full colour". Shop effects wear their own colour (or their tier's) at full
strength and are never washed toward grey; world and gameplay effects keep `docs/vfx.md` rule 1 (they were not part
of the question).

**Why:** this is the third "make the effects high quality" round (2026-10-24, 2026-11-12/14, now). The earlier
rounds added layers and counts of the same sprites; the look did not change because the textures and the lack of a
picture loop did not change.
**How to apply:** do the plan's stages in order: tools and before sheets, the texture library, the kit, then a
three-effect pilot and a hard stop for the owner's verdict. Do not "add more layers" to an effect as a fix. Nothing
was watched in the game for the plan; its ticket V0.2 does that. Related: [[win-cutscene-fx]],
[[cutscene-lag-2026-11-15]], [[mobile-and-perf-2026-11]], [[animation-plan-2026-11]].
