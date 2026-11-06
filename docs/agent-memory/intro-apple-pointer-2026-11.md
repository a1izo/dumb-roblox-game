---
name: intro-apple-pointer-2026-11
description: "2026-11-03 list from the user: smoother eye intro with brown hair, smoother apple loading and a real hand, sharper nib, one-finger pointer hand that never covers anything, tips key, wheel name once, wisp, New World arms"
metadata:
  type: project
---

What the user asked on 2026-11-03 (with three screenshots) and how it was done:

- **Eye intro** (art/scripts/ui/eye_intro.py, UI/EyeIntro): 24 opening frames instead of 8, evenly apart in openness,
  two to a sheet (IntroEyeSheet1..12, 705 x 481 each, one over the other); EyeIntro blends each frame into the next
  on a second ImageLabel (OPEN_TIME 0.85 s, eased slow-fast-slow), so the lid slides. The pupil tightens and the red
  comes up as it opens. Hair is Light's brown "as in the opening" (HAIR_* colours), the lit locks smeared longer so
  they read as anime locks rather than wood grain, inked at their edges, fine dark strands. Skin stays the user's
  grey colour frame.
- **Apple loading** (art/scripts/ui/intro_frames.py + ui/apple_hand.py, UI/AppleLoading): the apple turns on four
  sheets, 64 cells a turn (it stepped at about 15 a second). The hand was a flat grey mitten with two prongs; it is
  now built of parts on the sketch's silhouette (the old measured polygons), each shaded as a rounded form, inked,
  with nails, creases, knuckles, tendons. Three layers: AppleHandBack (the cupped palm and the thumb's web, behind
  the apple), AppleHandFront (over it), AppleThumb (a square round the thumb's hinge at the hand's edge; the game
  turns it: open -38 degrees while waiting, closing over 0.26 s at the catch). Pivot and fades are what keep the open
  thumb joined to the hand: hinge where it leaves the hand's edge, a disc of skin round it in the front layer, the web
  behind the apple.
- **Pen nib pointer** (cursors.py nib): longer nib with shoulders, lit and shaded halves, clean slit and hole, steel
  ring, black grip, 1 px outline, soft drop shadow (shifted, not np.roll: a roll wrapped the shadow to the top edge).
- **"The little pointing hand"** was NOT the mouse: it is Kit/Pointer, the red OMORI hand beside the chosen button.
  Beside SKIP it sat over BEGIN. Now a drawn sheet (PointerHand: right, left, down, up cells) with the index finger
  alone, and Pointer picks the first clear side (left, above, right, below) by testing the hand's box against shown
  buttons, text and pictures on the same screen (not the target or what holds it; backdrops over a quarter of the
  screen ignored). Roblox's own hover hand over buttons cannot be turned off (the docs: MouseIcon is overridden over
  buttons); that was not the complaint.
- **Tips**: a binding closeTip (G / D-Down, Settings > The case) closes the guide's tip; "Got it" wears the keycap.
- **Emote wheel**: the name shows only under its chamber (the caption gives tier and flags); the emotes come in once
  the cylinder has stopped (SPIN_SECONDS - 0.06).
- **Trial wisp**: it hung at the plaque's height (desk + 5) right over the station's name, and its pillar was a hard
  neon rod on the desk going up through the tablet. Now it circles over the top of whatever stands there (rays down),
  the rod is invisible, the soft column stands on your side of the place and goes when you arrive, smaller glow, no
  smoke.
- **New World emote** (art/scripts/emotes/poses.py): both arms spread out to the sides as in the anime (it was the
  right arm to the sky with a fist, the user's 2026-10-20 answer, now replaced); shot at 3.42 reframed for it.

Pictures were uploaded through the Studio MCP ([[pictures-by-mcp]]).

**2026-11-05 follow-up** (the user's word: the emote wheel's caption out, "make this hand match the style of the
game", "make it ryuks hand", "more frames for the intro of light and make his hair darker"):

- The emote wheel's "EMOTES 1-4" caption is gone (UI/QuickChatPanel); nothing replaces it, the wheel sits at the top.
- PointerHand is a paper manicule now (cursors.py pointer_hand): paper white, cel shaded (a crisp grey crescent where
  the piece moved toward the light no longer covers it), graphite outline round each piece, nails and creases in
  line, a pale grey shirt cuff with a button. Same cells, tip and box, so Kit/Pointer is unchanged. No red in it.
- The apple hand is a death god's hand in Ryuk's spirit (apple_hand.py, rewritten): its own outline (ARM) instead of
  the sketch's silhouette, a shorter palm and long bony fingers fanned round the apple's right side (round_apple),
  joints swollen and creased, black claws, a studded black band at the wrist, dark blue-grey skin. The contract with
  the game is HELD, HAND_BOX, THUMB_PIVOT, OPEN_THUMB and the thumb's square (its reach is the tip of THUMB_AXIS, so
  the axis's first point can move: it starts at the hinge now so nothing shows behind the hand when it stands up).
  `intro_frames.py --hand` redraws only the hand, reading the apple's sheets back; LoadingArt.luau came out the same.
- The eye opens in 48 frames (24 sheets, still two to a sheet: 705 px wide leaves one column), OPEN_TIME unchanged.
  The base halves do not change with the frame count or hair colour (hair is its own layer), so they need no upload.
  Hair: near-black brown base, dark chestnut lit locks, dull warm shine (HAIR_*).

**2026-11-06 follow-up** (the user: "i didnt mean to change the pointer colour, I meant to make it look better, more
omori like style. Make it red again. the black outlines are ugly. Also make ryuks hand more detailed and high quality
textured and rendered"):

- PointerHand is red again, drawn like OMORI's (cursors.py pointer_hand): the game's red (210, 30, 30), flat cel
  shading, and NO black anywhere: the line round each piece is a maroon (80, 6, 12), a little wobbly (smooth one-octave
  noise; a 3-octave warp made the edges fuzzy) and heavier on the side away from the light; faint crayon grain, a few
  hatched strokes in the shade, white highlight strokes along the finger, thumb and knuckles, a white cuff. Same
  cells, fingertip and box. Lesson: "match the style" meant the drawing, not the palette; the red is the pointer's
  identity (ui-direction: red = danger, the pointer, a chosen target).
- The apple hand is a 3D render now (art/scripts/ui/apple_hand_3d.py, run with Blender -b; Cycles on the RTX 4060 Ti
  via OptiX, about 4 min quick, longer full). Metaballs (BALL 0.575 / CHAIN 0.7: where a lone ball's and a close
  chain's surface lies, as a share of the radius) for forearm, palm (a negative ellipsoid cups it round the apple),
  ball of the thumb, bone ridges, fingers laid over the apple's front by depth_at; knuckle creases pressed into the
  mesh; skin shader with mottle, blotches, veins, pores, wrinkles, AO-darkened hollows, a little subsurface; lacquered
  claws; a stitched leather band with steel studs. Three renders: Back (no apple), Front (an invisible red apple
  throws its light and shade, a shadow-catcher apple holds the drawn apple's place out of the picture and catches the
  fingers' shadows), Thumb (the hand as holdout, its shadow caught on the apple, faded at its root, laid on its
  square). The hand keeps a slightly thinner stump of the thumb so the turning thumb sits over skin (a separate
  thumb's root showed as a knot). apple_hand.py now holds only the shape and the contract; intro_frames reads the
  three PNGs back for its preview (--hand remakes only the preview).
