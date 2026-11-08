---
name: deaths-batch2
description: The second batch of custom deaths (2026-11-08): eight scene re-enactments the user named, what each reference shows, where each piece lives, and the "A true patriot" grave with a server-picked saluter
---

Asked 2026-11-07/08: eight custom deaths, each re-acting a scene the user named and linked (a ninth, a suicide joke,
was declined: Roblox bans depicting suicide). Built like the first batch ([deaths-2026-11](deaths-2026-11.md)).

What the references show (watched frame by frame in the browser pane) and what we copied:
- **This is... requiem** (JoJo, GER vs Diavolo): a lunge whose blow stops dead and rewinds to zero in a violet and green
  star void, afterimages smeared behind; "What? Why? What is this!?"; the barrage; thrown down; dying again and again.
- **Blackwall gateway** (Cyberpunk 2077): a green scan, the target outlined red, red glitch data eating in, a chain of
  red-orange sparks, the body burning red as it drops.
- **A GOD.. IS NOT... AFRAID OF...** (Calamity, Devourer of Gods): its chat boast "A GOD DOES NOT FEAR DEATH!" shown in
  an old-game chat line (DeathScreen.chat, Arcade font, cyan); the body breaking apart a segment at a time in magenta
  and cyan.
- **and I.. am..** (Endgame): the fist raised with six coloured glints, "And I... am...", the snap (white flash, a
  ring of light), the burnt arm smoking, sat down, slumped back; the chest light goes out last.
- **Let's dance!** (MGR, Sam's finisher): blade mode: the picture drained cold, a red 斬, red cut lines drawn, four
  cuts landing (Cinema.slash), red edges. No gore.
- **Walrider** (Outlast ending): four shots, down on the back, a hand reaching up, the grey static swarm tearing out,
  the screen red.
- **heh, didja really think-** (Undertale, sans): asleep (Z's), dodges the FIRST slash, the smug line typed and cut
  off by the SECOND slash, the health bar emptied in one hit, a few steps aside, down to dust.
- **A true patriot** (MGS3): one shot in a field of white flowers; then the grave (below).

Where things are: `art/scripts/deaths_scenes.py` (the eight clips + `graveSalute`, imported by anims.py after
deaths.py, recorded in deaths.TIMING); effects in `Presentation/CustomDeaths` (signature effect from the `fx` beat) and
`Presentation/DeathVfx` (the beats; `b.state` carries values between beats of one play); screen bits in
`Presentation/DeathScreen` (chat line, big glyph, Z's, health bar, afterimage ghosts); shop scenes in
`art/scripts/cinema/deathcuts.py` (`batch_shots`: shots on each death's own beats, the fall filmed from higher so a body
thrown on its back never comes at the lens).

**The grave** (user's rules): the headstone reads the name of who died; the one saluting is the dead's Roblox friend if
one is in the server, else a random player in it. In a case the server picks (`DeathNoteService` saluterFor:
`IsFriendsWith` checks side by side, a second at most) and sends `saluter` in the death cue; the hold grows by the
grave's length; every screen plays `DeathCuts.patriot_grave` at the same server time after the death
(`Presenters/Death`, `ManualTiming.GRAVE_GAP`). The headstone shows the name written in the Manual (the case's real
name; the Preview uses the player's display name); a set mark reading `$dead` gets `WinCinema` option `named`. The
Preview chains via the cut's `after` field (`WinCinema.preview`), the local player's friend in the server first
(`WinCinema.saluter`), else anyone, else the faceless figure. No beret: hats were removed for good.
