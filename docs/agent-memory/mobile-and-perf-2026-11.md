---
name: mobile-and-perf-2026-11
description: "Phones are most players: every touch check goes through UI/Core/Device; Studio tests play as a phone with DGForceDevice; what the 2026-11-11 pass measured and fixed"
metadata:
  type: project
---

The user, 2026-11-11: "make sure the game is properly optimized for every hardware - and make sure the mobile port
works too since a lot of players come from mobile".

**Testing as a phone:** `src/client/UI/Core/Device.luau` answers every "is this a touch screen / what was touched
last" question (Responsive, Actions, Keys, Trial, HoverGlitch, Controls, Duo, Eyes go through it). In Studio the
Workspace attribute `DGForceDevice = "phone"` (or "tablet") makes the game take itself for one: the harness passes it
with `run.ps1 -Attr "DGForceDevice=phone"`. The minimised harness viewport (1096x507 at UI scale 1) is close to a
landscape phone's layout space (844x390 at scale 0.78). Roblox's own thumbstick and jump button do not appear (the
code falls back to Shared/UI/TouchSafe's default place). Probes kept in the harness folder: Perf (frames, scene counts,
UI loop costs per map and scene death), Phone (lobby + windows: text off screen, buttons under 28 px), PhoneCase (a
whole case with bots as a phone: debug remote fillBots/startMatch/skipTo).

**Measured, then fixed (2026-11-11):**
- The text boil redrew every text in one frame: 3-5 ms with the shop open. Now spread over 4 steps (Kit/Boil SLICES),
  and on phones / Low quality small text only drifts (no rich-text rewrite): 0.6-0.9 ms a step on a phone. Kit/Pencil
  the same, and skips lines not on screen: 2.5 ms -> 0.1-0.2 ms.
- Every particle emitter's rate and bursts pass through Vfx/Emit.share(): 60% on touch, 40% in Low quality or once
  the governor cuts effects (the scene deaths had no cut before).
- Maps' meshes keep Roblox's own level of detail on phones (World/MapDetail), Precise stays for computers.
- Phone layout: the lobby menu ran off the bottom (COLUMN_TOP 0.13, rows 37), the streak card sat on the Trial's card
  (bottom middle on phones), windows' titles sat under Roblox's menu/chat buttons (Kit/Window starts phone windows
  below GuiService.TopbarInset; re-arranges when it changes), notification lines cut their wrapped second line
  (Kit/Slip measures and wraps down).

**Not changed, on purpose:** 300-800 local lights on the case maps (shadows already budgeted to the nearest 34;
the engine culls the rest, and the HQ blackout toggles lights itself); StreamingEnabled stays off (the client code
expects whole maps). The harness place has no map imports (4 meshes), so real map memory on a phone is unmeasured:
the honest check is a real phone or Studio's device emulator in the real place.
