# Dead by selection — from the user's chart (2026-11-08), redone 2026-11-10

The user's picture (the "dating app" chart): left, five figures, each with arrows fanning out to many on the right;
right, five figures whose arrows all converge on the top three on the left. Asked first (2026-11-08): rename to "Dead
by selection", remove the text, redraw it "so it doesn't look like people - more like lines, but make it
understandable still".

The first build drew the chart live on a board in a room, from straight bars. The user, 2026-11-10: "redo the death by
selection cutscene entirely because the way you drew those lines looks completely made by AI - instead make the
character look at the phone at the second image then up to the starry night sky in contempt with dramatic camera
shots."

Now: the chart is a PICTURE drawn by hand (art/scripts/scene_pictures.py, SelectionChart: two columns of five dots on
paper, red arrows fanning evenly from the left, blue arrows from the right all going to the top three; the bottom left
dot ringed in pencil is the victim's, and no blue arrow comes to it), shown on the victim's phone. The place is a
rooftop at night over a city under the Milky Way (maps/venues/scenes/selection.py, sky SkySceneNight).

Not suicide (Roblox bans depicting it): the victim is "deselected": they read it, look up at the stars, let the phone
go, grey, and go to dust that rises into the sky. No words, no face expressions. Length: 14 s.

| t | shot | in frame | motion | VFX / light |
|---|------|----------|--------|-------------|
| 0.0–2.4 | over the right shoulder, slow push | the lit phone in the reading hand, the city beyond, soft | reading, head down; the thumb scrolls | the phone's glow on them, the stair lamp's warm rim behind |
| 2.4–4.6 | the screen itself, filling the frame | the app: the post, the chart on its paper | a held phone's drift, a scroll, then a push in to the ringed dot | the glass's shine |
| 4.6–6.6 | the face from below | lit by the phone | it lands: still, the breath goes out; the phone sinks | the light leaves the face |
| 6.6–8.2 | from low behind, going up | the back of the head, then the Milky Way | the head comes up; the camera goes up past it and opens wide | |
| 8.2–9.7 | from above, the sky's side, closing in | the face turned up to the lens | a slow shake of the head, chin high | |
| 9.7–10.6 | the roof | the phone falls into frame, lands face up, a bounce; the feet beyond | the hand opened | a puff of grit; the screen still lit |
| 10.6–14.0 | the wide, sinking back, then up to the sky | a small figure against the galaxy | standing, chin up | the colour drains (10.6), dust from the feet up, rising (11.7); the phone's screen goes out (12.9) |
