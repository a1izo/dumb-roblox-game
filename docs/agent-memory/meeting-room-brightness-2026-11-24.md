---
name: meeting-room-brightness-2026-11-24
description: 2026-11-24 the owner said the meeting is "way too dark": the Meeting phase resolved to ambient 10/255 because the preset and the Meeting mood both dim it; what was measured and changed, and how it was looked at
metadata:
  type: reference
---

The war-room meeting's look is the preset `LightingPresets.meeting` TIMES the `moods.Meeting` mood (resolve()). Measured in a
Studio play test (fillBots total 6, startMatch, skipTo Meeting, pause, wait ~35 s for the intro and briefing; read
`game.Lighting` in the Client): ambient 10/255, brightness 0.24, exposure -0.05, grade contrast 0.46, environment diffuse
0.35. The room lamps are fill 0.35x (0.17 to 0.31 brightness). Faces, seats and walls were black.

Changed: preset brightness 1.0, exposure 0.2, ambient (73,71,84), outdoor (69,67,80), envDiffuse 0.7, contrast 0.2; the Meeting
mood now brightness 1.2, ambient 1.1, exposure 0.3, contrast 0 (it used to dim to 0.6 / 0.45). Resolved: brightness 1.2,
ambient (80,78,92), exposure 0.5, contrast 0.2. The key (1.5) and fill (0.35) lamp scales, vignette 0.6 and tint are
unchanged, so it is still dim and cold with lit pools. The first try (ambient up only) barely changed the picture: the
grade's contrast (0.46) was crushing it; contrast 0.32 still read too dark, 0.2 reads clearly.
Side effects: Vote, Verdict and Outro moods multiply the same preset, so they are somewhat brighter in the room (Vote ambient
about 22 instead of 7; Verdict stays near black: exposure -1.2). Not looked at. LightingPresets specs unchanged.

How it was judged without writing into the place: the Client forced Lighting's values and the grade's contrast every frame
(BindToRenderStep after the controller) to the resolved numbers. Pictures: art/export/previews/meeting_light/before_1.png,
after_1.png (main checkout copy too). One camera only (the player's seat, looking at the table); not looked at: the vote, a
phone, Low graphics, the faces in a close-up. Needs the script sync (Rojo).
