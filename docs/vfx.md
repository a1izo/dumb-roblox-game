# Effects (VFX)

How the game's effects are made: the Roblox tools and what each is for, the house rules every effect follows, timing,
the camera, and keeping it cheap. Written at the start of the shop and cosmetics overhaul (Part B, 2026-10-21) from
the research the brief asked for; `docs/emotes.md` says where each emote's effect lives.

## Sources read (2026-10-21)

- Roblox Creator Hub: Particle emitters (`/docs/effects/particle-emitters`), Beams (`/docs/effects/beams`),
  Highlighting objects (`/docs/effects/highlighting`), Post-processing effects
  (`/docs/environment/post-processing-effects`), Camera (`/docs/workspace/camera`), Using animations
  (`/docs/animation/using`), the AnimationTrack and Highlight class references, and the artist curriculum's
  beam/trail/flipbook definitions.
- DevForum threads on starting VFX (beams for fixed spans, particles for volume, meshes for shaped bursts).
- Jujutsu Shenanigans: the "Aura monster" traversal emote watched frame by frame (youtube WCS02c9lgro), robloxden's
  and bloxodes' emote lists (traversal emotes move the player, slower than a walk, while the animation is active).

## The owner's tutorials (2026-10-22/23)

The owner sent tutorials to learn from (read through their captions; the silent ones from their frames):

- goodgood3d (Blender, "the same 5 nodes for 90% of my 3D work"): stylised effects are plain shapes (a shockwave
  dome, rings, spikes) scaled over time on a curve (Scene Time -> Map Range -> Float Curve -> Transform Geometry),
  their look a noise cut into hard steps. Here: `Presentation/FxKit` grows the Core set's `FxDome`, `FxRing`,
  `FxCrescent` and `FxSpikes` on an eased curve (the Float Curve), tinted and glowing; the stepped noise is baked
  in Blender into the `FxPuff` flipbook (4 x 4, `art/scripts/textures.py`).
- MoldySugar (VFX scripting): effect templates cloned at a CFrame; emit every emitter at once, enable a lingering
  layer under the burst; a crater of rocks (`FxKit.rocks`); a camera shake; an impact light (`FxKit.light`); a
  ColorCorrection flash tinted to the effect (EmoteCinema's `flash` and `impact` beats).
- BlenderBuilder (particles): colour from dark to its hue and a size that swells mid-life; LightEmission with the
  colours darkened to match; velocity-aligned orientation and Squash for streaks; white textures, so they tint;
  Drag to gather; TimeScale for a frozen beat.
- Ludius, Disobeyedcrab (cutscenes): a camera animated with the body (our Blender shot lists), the player locked
  and kept safe while it plays, an easing chosen for each move, a roll, a lower FOV, easing back into the player's
  camera at the end. Moon Animator (two): never linear keys (quad, quart). Pidgey's showcase: beams in layers (a
  white core inside coloured shells), a swirling vortex, thick smoke, white streaks.

## The aura tutorials (2026-10-24)

The owner: "make the vfx very high quality and not just those simple particles". Three tutorials, read:

- Twist VFX, "How to Learn Roblox Aura VFX in 1 Hour" (captions): every emitter fades in and out by size or
  transparency, never pops; LightEmission 1 takes a texture's black away; LightInfluence 0; a glow held steady by
  two particles half a life apart on a V of transparency; spec textures, sparingly; off-centre textures turned as
  they go for wisps; faint ambient smoke behind; ground effects laid flat (VelocityPerpendicular, Speed 0.001, never
  0), rings growing out, a ground glow, a spiked ring; two beams spiralling up, mirrored by their curve; a lens
  flare small behind; few particles alive per emitter (the rate against the lifetime); enable everything together
  so the layers stay in step; make it in daylight, not only in the dark.
- TerKungTH, the ground aura guide (frames; it has no speech): crescent slashes spinning on the floor, stars and
  flares small with a high rate, smoke very transparent with a long life, a halo ring behind the head, light
  streaks; Top + VelocityPerpendicular for anything on the ground.
- TerKungTH, the body aura guide (frames): smoke, specs, glitter flares and lightning on the limbs (emitters in
  the body's parts, not one big box: his own "mistake" was one cloud swallowing the body).

Here: `Presentation/Aura` builds these layers by level (1: the steady glow, specks, limb flares, a light; 2: and
wisps, smoke and the ground's ripple, glow, spiked ring and spinning slashes; 3: and two spiral beams, a halo,
lightning sparks and an edge of light), from white textures baked in `art/scripts/textures.py` (`AuraGlow`,
`AuraSpecks`, `AuraTwinkle`, `AuraHalo`, `AuraCrescent`, `AuraSpikeRing`, `AuraWisp`, `AuraBolt`; carried in the
Core set). Every emote from Sealed up wears one under its own effect (`Controllers/EmoteFx`: Sealed level 1,
Condemned 2, Godhood 3, a few showpieces a level up), in its tier's colour or its own.

## The tools

| Tool | Use it for | Notes from the docs |
| --- | --- | --- |
| `ParticleEmitter` | dust, sparks, embers, petals, rain streaks, symbols that drift | Rate caps at 400/s (100/s on phones); Lifetime caps at 20 s. `LightEmission` 1 = additive glow, 0 = normal blend. `Squash` stretches a particle into a streak (rain: about 3, with `VelocityParallel`). `ZOffset` layers emitters without changing their size. Fade `Transparency` in and out or particles pop. Flipbooks (2x2, 4x4, 8x8) cap at 30 fps and are dropped on low-memory phones, so the effect must still read without them. Sphere and Cylinder shapes misbehave on Attachments: give them a Part. |
| `:Emit(n)` | bursts on a beat (impacts, a clap, a coin landing) | One emitter reused for every burst; `Rate` stays 0. |
| `Beam` | streaks between two points (a ball's flight, strings, light shafts, speed lines, slashes) | Needs two different Attachments; curve with `CurveSize0/1` along the attachments' X axes; `FaceCamera` or it vanishes edge-on; `TextureMode` Wrap/Static repeat by length, Stretch by count. Streaks that follow a moving hand are Beams between the hand and a lagging attachment, never `Trail` (see the rules). |
| `Highlight` | an outline or fill on a body or prop for a beat (a reveal, a glare) | Up to 255 on screen at once (older pages said 31); a disabled one still takes a slot. Creating or destroying one rebuilds geometry and can hitch, so keep one per effect and change its properties. The first one on screen costs up to about 1 ms on phones. |
| `PointLight` / `SpotLight` / `SurfaceLight` | the light an effect throws on the body and floor | Tween `Brightness` up and down with the beat; never leave one on. |
| Post effects (`ColorCorrectionEffect`, `BloomEffect`, `BlurEffect`, `DepthOfFieldEffect`) | grading a cutscene, a flash | Parented to the **camera** they reach one player only; parented to Lighting, everyone. Ours always go on the camera and are restored when the shot ends (`Cinema`, `EmoteCinema`). |
| `BillboardGui` | manga bubbles, symbols that must face the camera (ゴゴゴ, ドドド), floating text | `MaxDistance` so it never clutters far away; `AlwaysOnTop` off so walls hide it. |
| Parts and meshes (Neon, glass, SmoothPlastic) | shaped one-off pieces: steps forming under a foot, shards, a shockwave ring | Anchored, `CanCollide`/`CanQuery`/`CanTouch` off, `CastShadow` off; tweened in size and transparency. |
| `TweenService` | every fade and grow | `Sine`/`Quad` InOut for camera and light, `Back` Out for a pop-in (a bubble), `Exponential` Out for a flash falling away. |

## House rules

1. **Grey world, colour is earned.** Effects live in the game's greys, bone and soft white. Crimson belongs to Godhood
   only; red elsewhere means danger (the UI rule). One emote has its own colour by the owner's call: The Long Climb
   is green, like the show it copies.
2. **No ink.** No pools, splashes, sinking into ink, dripping or ink-coloured wisps (the owner's rule, 2026-10-21).
   Pick dust, ash, smoke, embers, light, glass or paper instead.
3. **No `Trail` instances.** The owner took trails out of the game; streaks are Beams or particles.
4. **The motion comes first.** An effect lands on a beat the body already makes (a stamp, a clap, a turn, a landing);
   it never stands in for a missing movement.
5. **One idea per emote.** Each emote has a motif of its own (a fedora's tip, a stair of light, a manga panel) rather
   than the same burst in another colour. Bigger tiers get more layers, not more of the same particle.
6. **Readable from the default camera.** Most players see an emote from their own follow camera, often in a match;
   the effect must read there, not only in the showpiece shot.
7. **Never hide another player.** Effects stay near the body (about 6 studs), fade within a few seconds, and keep
   off the faces of people standing nearby. No full-screen flash for anyone but the emoter.

## Timing

- **Anticipation, hit, settle.** A small gather before the beat (dust drawn in, a light dimming), the hit on the frame
  the pose lands, then a slower fall-off (2-4 times the rise).
- **Beats come from the clip.** `EmoteFx` gets the session's phase and the clip's time (`accent`, `onBeats`, `burst`);
  effects are placed at clip seconds, so a late joiner or a slowed clip still lines up.
- **In and out.** Every looping effect fades in over 0.2-0.4 s and out over 0.3-0.6 s; nothing appears or vanishes in
  one frame. A cancelled emote fades its effects out quickly (0.2 s) instead of cutting them.
- **Sound with the picture.** Cue slots (`EmoteMedia.CUES`) sit on the same beats as the effect; the ids are the
  owner's.

## The camera

- Lobby only: no camera moves in a case (the owner's rule); effects still play there in full.
- Each showpiece emote gets one move chosen for it (push-in, low hero, high angle, over the shoulder, side track, orbit
  left or right, hold), eased with Sine InOut, its peak on the emote's key beat. Cuts belong to the Godhood cutscenes
  and the win cutscenes.
- Scriptable camera, updated at `Enum.RenderPriority.Camera`, `Focus` set with the `CFrame`; always handed back to the
  player's camera on end, cancel, death, respawn or error.

## Animation notes

The game plays its own R6 clips (`PoseController`/`ClipPlayer`, `docs/animation.md`), not Roblox `AnimationTrack`s, so
Roblox's priorities don't apply; the same ideas are ours: clips ease in and out, an upper-body mask leaves the legs to
the movement set, and the floor guard keeps soles out of the floor while a leg clip blends. What the brief asks of
every emote (weight shifts, anticipation, follow-through, legs that take part, loops that don't snap, no splayed limbs)
is measured per clip by the checks in `art/scripts` and judged by eye on render sheets.

## Keeping it cheap

- **Reuse.** One emitter per job, fired with `:Emit`; one Highlight per effect; shared textures. Parts that recur (the
  climb's steps) come from a small pool.
- **Short lives.** Particle lifetimes of 0.3-1.5 s for accents; loops keep their rate low (under about 40/s per
  emitter) and their particles small (fill rate and overdraw are what cost).
- **Everything belongs to the session.** An emote's effects are made under its session and destroyed with it
  (`EmoteController`): nothing outlives the emote, piles up, or runs each frame after it ends.
- **Low graphics.** On the lowest quality levels effects drop to their first rung (`EmotePolicy`, `EmoteFx`); a match no
  longer caps them (the owner's call).
- **Test both ends.** Check effects at the lowest and highest quality levels.
