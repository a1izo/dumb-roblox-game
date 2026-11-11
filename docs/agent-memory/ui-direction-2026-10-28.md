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
- **Boil.luau**: OMORI's line boil, 3 states at 8 fps, on drawn lines and frames. Text boils letter by letter (the
  owner wants "letter independent not word independent"), but only big headers (32 px up, not in a button) and a
  button's text while hovered: on small text it "makes small text unreadable" (2026-11-01). Boil.watch(PlayerGui)
  gives each such label a rich-text copy (each letter its own size per state) and hides the label's own letters with
  a see-through UIGradient. Traps hit: the copy must carry NoBoil (else copies of copies, re-entrancy error); hiding
  with MaxVisibleGraphemes = 0 sizes AutomaticSize labels as if empty; a full-size copy grows an auto-sized padded
  label every frame (so it has no height and is 1 px narrower); a Folder around it crashed Studio.
  NoBoil (attribute) keeps a subtree still: the game title and its quote, the case summary, the emote wheel.
- **All text boils since 2026-11-11** (the user: "make all of the text ... more omori styled"): headers and a hovered
  button's text letter by letter as before; smaller text gently (a quarter of its letters +-1 px, the line drifting
  1 px), which keeps it readable. **Kit/Pencil.luau** redraws every UIStroke box outline and every thin rule frame as
  a pencil line: three drawings (UiPencilBox1..3 9-slice 40..216, UiPencilLine1..3, art/scripts/ui/textures.py, Core
  carriers) swapped at 8 fps, each line on its own beat. The stroke stays (its maker keeps using it) but is drawn 0
  thick; rounder-than-8-px corners, text strokes and NoBoil/NoPencil subtrees are left alone. A box that lays out
  its children gets its pencil as a sibling. Test without the import: Kit.Textures.override with rbxasset://
  files copied into Studio's content/textures (the harness Pencil probe does this).
- **Pointer.luau**: the one red pointing hand; buttons and name lines call point/release on hover and selection.
- **Buttons** (Controls.button): solid box plus a boiling inner frame; chosen = the hand comes, never a colour change.
- **Windows** (Window.new): paper sheet over the blurred world, big lowercase title with a full stop (whole, never
  cropped: the owner said the cropped titles were "too high up"), ink rule, Back button.
- **Notifications** (Slip): log lines (mono time, thin rule, capitals; red strip for danger). Tips and pop-ups
  (Notice) are OMORI dialogue boxes.
- Fonts (the owner's pick 2026-10-29 from a 12-font sheet, "05"): **Indie Flower for everything**, titles and text;
  Roboto Mono only for data (clocks, counts); Aktura kept for the announcer and the title. Melodrama is off
  (GlyphText.MIN_ATLAS = math.huge). Indie Flower draws small, so text in it is scaled by Tokens.handScale (1.22)
  in Base and GlyphText. Gotham was "pmo"; Arimo "boring".
- Never rotate a container: Roblox stops clipping inside a rotated frame (the tilted sheets let scrolled lists run
  over the window titles).
- The owner wants real layout changes per screen, not a theme swap: shop (suits as a big-word list on the left),
  quests (a checklist: drawn boxes, 7 streak day boxes), leaderboards (top three big) were rebuilt 2026-10-29;
  party (headshot line-up), settings (sections down the left), how to play, profile, the role poster, vote, results
  and the floating meeting card on 2026-10-31. Still old: shop item cards, Butler, hack/task screens, the Manual,
  notes, ghost HUD, duel, wager.
- Full-screen overlays start their top block about 48 px down: Roblox's own buttons sit over the top left.

Traps hit: change events are deferred, so Boil and Paper compare against the value they last wrote (a flag around
the write is gone by the time the event fires); rotation reads back at lower precision (compare with a tolerance).
Without these, frames walked off-screen and the paper swap looped until Roblox stopped it.

**Rejected, don't bring back:** skewed slabs/tilted cards/stamps ("Marvel Rivals AI slop"), grey glass panels,
"bolder font + grey boxes" as an overhaul, tape-strip and boxed notifications, sparkles anywhere but tips and the
phase line, Arimo as the display face ("boring"), a dark gothic concept B ("horrible"), cropped window titles.
Role card text: three short rules, no "how you win" ("just keep it simple"). The emote wheel is off limits.

**How to apply:** build new UI from these Kit pieces; check every change in a Studio playtest before reporting it.
