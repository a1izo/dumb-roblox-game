---
name: studio-shared-place-write-blocked
description: "execute_luau writes into the shared Team Create place (script Source) are refused by the permission classifier; test the repo's scripts by emulating on the play-test copy instead"
metadata:
  type: feedback
---

2026-11-13: an Edit-datamodel execute_luau that patched three scripts of the place (UpdateSourceAsync, hash-checked
against the repo's history) was DENIED as "Modify Shared Resources", whatever the user's "full perms". Do not look for
another tool to do the same write (multi_edit is the same thing). The owner's Rojo sync is how scripts reach the place.

What works, all thrown away when play stops: after `MapService.build(<id>)` on the Server datamodel, change the built
lights and parts (the client receives them): this is how the repo's newer SceneBuilder (SOFT pools: spot x0.55, angle
100, a "Bounce" PointLight low under each) and the newest exported light data were emulated on a place whose scripts
and Scenes were older. On the Client: pin the camera, set `Lighting.Ambient` etc. to the repo's newer presets by hand
(LightingController only re-applies on a change of look), and read `require(RS.Shared.Assets).texture("AuraGlow")` for
the glow image (the Client VM's own Textures copy has none loaded). The place's scripts at 2026-11-13 were older than
HEAD (no SOFT_POOLS): compare before judging a look.
Related: [[studio-mcp]], [[studio-no-screen]], [[imports-by-open-cloud]].
