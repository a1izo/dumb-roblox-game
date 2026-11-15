---
name: photo-mode-and-moving-titles
description: Added overnight 2026-11-14: five moving shop titles (kept, no verdict yet) and a lobby photo mode (REMOVED 2026-11-15 at the user's word) (Shared/TitleMotion, World/TitleAnimator)
metadata:
  type: project
---

The user said "keep working till I wake up ... just innovate" (2026-11-14). Built, tested in Studio, pushed, saved
(place v579), NOT yet judged by the user: treat both as removable if they say so (their removal is final).

- Photo mode was REMOVED for good on 2026-11-15 (the user: "Also remove photomode"): World/PhotoMode, its P key
  (Bindings "photoMode"), its Actions entry and the lobby menu's "Photo mode". Never bring it back.
- Moving titles: five coin titles (title_a_candle, _coldcase, _chalk, _borrowed, _afterglow) with motions flicker,
  shiver, chalk, heartbeat, afterglow; labels tagged DGTitleMotion + attribute TitleId; reduced motion stills them;
  each title needs a TitleFonts look no other title shares (Rarity.spec checks font/weight/italic/case).
- Same night: the Camera shake setting now reaches every shake (Motion.shakeOff), Jackpot Shuffle's suits are drawn
  (typed suits draw as emoji).
