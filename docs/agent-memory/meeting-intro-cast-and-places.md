---
name: meeting-intro-cast-and-places
description: How the meeting intro is cast and where its actors must end (2026-11-17): seat:k = place k, the cast is seats 0..n-1, uncast seats get faceless stand-ins, the real bodies stand at radius 17 during the shot and are sat after it, and the server's MEETING_INTRO must equal the shot's length
metadata:
  type: reference
---

Found rebuilding MeetingIntro (list-2026-11-16 item 6):

- `RoundService.meetingCast()` casts only the **living** players, in order: `seat:(i-1)%12` for the i-th living player, so a
  match of n players (6 to 12 in a real case) fills seats **0..n-1**, whoever walked where. ShotPlayer gives every actor
  nobody is cast in a faceless `Stage.figure()` stand-in (uncast `seat:k` too, so an empty or dead place shows a stand-in
  in the montage). The close cuts must therefore live on seats 0 to 5 (always real) and treat 6 to 11 as maybe-stand-ins.
- `MeetingService.gather()` has already put the real bodies **standing at their places, radius 17 facing the middle** (the
  plan's `SEAT_R`) when the intro plays; `gather(true)` seats them in the chairs (root at 19.92) at the start of the Meeting
  phase, after the shot. So the shot's last frame is every actor at `(sin a * 17, cos a * 17)`, a = 30 degrees x k,
  facing the middle; the old shot ended at 16.1.
- The shot's actors are clones (the real bodies are hidden), so nothing in the shot moves a real player.
- `RoundService.MEETING_INTRO` (seconds the match loop waits, +0.25 lead) is a hand-synced constant: it must equal the
  shot's length (7.8 in the 2026-11-17 rebuild) or `gather(true)` fires under the cutscene.

**How to apply:** change the shot's length and that constant together; cast-dependent beats (a face seen, a line of dialogue)
belong to seats 0 to 5.
