---
name: photo-mode-and-moving-titles
description: Two features added overnight 2026-11-14 without the user's verdict yet: lobby photo mode (World/PhotoMode, P) and five moving shop titles (Shared/TitleMotion, World/TitleAnimator)
metadata:
  type: project
---

The user said "keep working till I wake up ... just innovate" (2026-11-14). Built, tested in Studio, pushed, saved
(place v579), NOT yet judged by the user: treat both as removable if they say so (their removal is final).

- Photo mode: World/PhotoMode.luau; key P (Bindings "photoMode", "The camera" section) and "Photo mode" in the lobby
  menu. Body anchored locally; camera within 36 studs, raycast so it never passes through walls; six film looks, no
  blur; refuses while LobbyIntro.isPlaying(), a cutscene's Cinematic frame or CameraDirector.busy(); the lobby's eye
  button hides meanwhile (PhotoMode.Changed).
- Moving titles: five coin titles (title_a_candle, _coldcase, _chalk, _borrowed, _afterglow) with motions flicker,
  shiver, chalk, heartbeat, afterglow; labels tagged DGTitleMotion + attribute TitleId; reduced motion stills them;
  each title needs a TitleFonts look no other title shares (Rarity.spec checks font/weight/italic/case).
- Same night: the Camera shake setting now reaches every shake (Motion.shakeOff), Jackpot Shuffle's suits are drawn
  (typed suits draw as emoji).
