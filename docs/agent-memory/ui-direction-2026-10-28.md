---
name: ui-direction-2026-10-28
description: "Concept A (paper, ink, blood) is the chosen UI, built 2026-10-29: Boil, Pointer, Paper, OMORI buttons; what was rejected"
metadata:
  type: feedback
---

On 2026-10-29 the owner picked concept A ("whatever just implement a") from the Design canvas
https://claude.ai/artifact/EeKtqNWovgnkScrFL924cH, after rejecting several other directions.

What it is, in the code (src/client/UI/Kit):
- **Palette** (Tokens): warm ink ramp g0..g6, paper (232,228,220) as `white`, one red (210,30,30) for danger, the
  pointer and a chosen target. `Tokens.paper` is the same ramp light-to-dark.
- **Paper.luau**: menus are paper sheets; `Paper.apply(root)` swaps every ink-ramp colour under root for its paper
  partner, now and on later changes. `PaperKeep` attribute (or `Paper.keep`) opts something out (buttons do).
- **Boil.luau**: OMORI's line boil, 3 states at 8 fps, only on drawn lines and big titles, never small text.
- **Pointer.luau**: the one red pointing hand; buttons and name lines call point/release on hover and selection.
- **Buttons** (Controls.button): solid box plus a boiling inner frame; chosen = the hand comes, never a colour change.
- **Windows** (Window.new): paper sheet over the blurred world, big lowercase title with a full stop (whole, never
  cropped: the owner said the cropped titles were "too high up"), ink rule, Back button.
- **Notifications** (Slip): log lines (mono time, thin rule, capitals; red strip for danger). Tips and pop-ups
  (Notice) are OMORI dialogue boxes.
- Fonts: Gotham Heavy for big lowercase titles (`font = "title"`, set the `KeepFont` attribute BEFORE parenting or
  FontMirror turns it into Melodrama), Melodrama for names, Arimo for text, Roboto Mono for data.

Traps hit: change events are deferred, so Boil and Paper compare against the value they last wrote (a flag around
the write is gone by the time the event fires); rotation reads back at lower precision (compare with a tolerance).
Without these, frames walked off-screen and the paper swap looped until Roblox stopped it.

**Rejected, don't bring back:** skewed slabs/tilted cards/stamps ("Marvel Rivals AI slop"), grey glass panels,
"bolder font + grey boxes" as an overhaul, tape-strip and boxed notifications, sparkles anywhere but tips and the
phase line, Arimo as the display face ("boring"), a dark gothic concept B ("horrible"), cropped window titles.
Role card text: three short rules, no "how you win" ("just keep it simple"). The emote wheel is off limits.

**How to apply:** build new UI from these Kit pieces; check every change in a Studio playtest before reporting it.
