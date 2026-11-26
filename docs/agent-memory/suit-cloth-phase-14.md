---
name: suit-cloth-phase-14
description: Graphics plan phase 14 (2026-11-26): the suit's wool was flat under a key (roughness 0.85, flat normal); suitwool scan look + roughness 0.62, Core 43; how a suited body was put under the HQ key; local textures cannot be tried live on a SurfaceAppearance
metadata:
  type: project
---

**The look test.** A real match started from the Client (`Debug` remote: `nextMap {mapId="TaskForceHQ"}`, `forceRole`, `fillBots
{total=6}`, `startMatch`), `pause` sent once the phase reads Investigation, then the Server anchors the bots and pivots
them into the sergeant's office (floor y 0, root at y 3.05): Bot1 at (-86, 3062) is under the one shadow downlight
(-88, 11.5, 3064), Bot2 at (-78.5, 3068) in the dark east against the wood dado. Camera pinned at 6 studs, fov 55. Pictures
`docs/handoff/refs/p14-suit-under-key.jpg` and `p14-suit-dark-east.jpg`. A match runs on by itself (Meeting after the
Investigation timer): pause, or the bots are in the meeting room by the next call. The camera must not stand inside a
body: Bot1 filled a frame when the camera sat 4 studs behind it.

**What read cheap:** under the key the jacket was flat charcoal (wool roughness 0.85 = no sheen, the weave's normal map nearly
flat, the two wool colours 16 apart); the cut itself (lapels, pockets, tie clip, cuffs) read fine; in the dark east the body
separated from the wood and blinds well. **Change:** `modelkit.SCANS["suitwool"]` (the herringbone scan, 0.22 m a repeat, relief
0.03, tone and sheen following the weave), `Suit_Wool` roughness 0.62, colours 40..62; the maps stay 256 px so the budget is
unchanged. Measured on the jacket panel: normal spread 0.016 to 0.039, roughness mean 0.85 to 0.62. Core exported as 43.

**Trap: a local texture does not load on a SurfaceAppearance.** `rbxasset://textures/<folder>/x.jpg` (a file in Studio's
content folder) shows as `AssetFetchStatus.Success` yet a SurfaceAppearance set to it (property or `ColorMapContent`, client or
server) renders as plain white, and `AssetService:CreateEditableImageAsync` of it gives the checker placeholder (the log says
"Invalid TexturePack source textures"). So suit or prop maps cannot be tried live without an upload; judge them from the
Blender preview and the map numbers, then import. (Skies and Decals do take `rbxasset://textures/...`.)

Never re-add suit fists. Related: [[owner-rejected-changes]], [[low-quality-variant-phase-15]].
