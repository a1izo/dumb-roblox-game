---
name: stuck-texture-packs
description: "Everything grey in Studio (2026-11-06): not our files: Roblox's texture packs baked at save stuck at 406 AcrBeingGenerated, and Studio 0.746 no longer falls back to the original maps; how to check it from the logs"
metadata:
  type: reference
---

2026-11-06 the user saw the lobby (Trial steles, altars, bone throne, candles, the giant skull's eyes) and then the maps
go plain grey. The game's files were fine: every SurfaceAppearance had its maps, the images were Approved and Active,
the FBX UVs read right, lighting and the grade were ruled out live.

What it was: when a place is saved, the engine bakes each SurfaceAppearance's maps into one **TexturePack** asset
(SurfaceAppearance.TexturePackContent, engine-only) and draws from that at runtime. Studio 0.746 (installed
2026-11-05 ~21:12Z) asks for a ktx2 representation with `doNotFallbackToBaselineRepresentation=true`; until Roblox has
built it, AssetDelivery answers 406 `AcrBeingGenerated` and the surface draws as a blank grey stand-in. UI ImageLabels
of the same images load fine (baseline), which hides it. A part's own Color does not show through either.

Measured: 2,089 texture ids in the place; in the user's 21:04 session 201 were waiting: 17 ordinary map textures (Maps
Agency 7, Campus 5, Tokyo 5) and 184 TexturePacks, some baked 2026-11-05 16:03Z by the owner account (waiting 29 h),
some baked 2026-11-06 16:10Z at our save. Packs do complete over hours (155 of one day's 172 had), but not all.

How to check (no screen):
- Studio logs (`%LOCALAPPDATA%\Roblox\logs\*_Studio_*_last.log`, open with FileShare ReadWrite):
  `ContentId: rbxassetid://<id> failed due to: Asset content representation is being generated`; the
  `AssetResolutionWorkflow ... failed!! adIndividualItemFailureReason: AssetDelivery406AcrBeingGenerated` lines.
  Compare the set between sessions to see progress.
- Open Cloud (MCP `open_cloud_invoke`, scope asset:read): `GET /assets/v1/assets/<id>?readMask=assetType,
  creationContext,moderationResult,revisionCreateTime` tells a TexturePack from an Image and who baked it when.
- An anonymous curl to assetdelivery with the ktx2 list answers 406 for every id, ready or not: useless as a check.

Which surface uses which pack: `SerializationService:SerializeInstancesAsync({sa})` and read the `rbxassetid://`
ids in the buffer: the one that is not ColorMap/NormalMap/RoughnessMap/MetalnessMap is its pack (TexturePackContent
itself needs RobloxScript to read). 2026-11-06: 1,215 SurfaceAppearances on 576 packs; 641 on the 192 stuck ones
(Maps Tokyo 230, Campus 122, Models Lobby 110, Maps Lobby 91, Agency 70, Models Tokyo 18).

A "re-bake" with the same textures is impossible (tried 2026-11-06, then undone): a fresh SurfaceAppearance with the
same maps gets the SAME pack back the moment it is parented under a MeshPart in the place (a loose one has none), so
the place keeps one pack per map combination. Copying the *Content properties carries the pack along too. Only a
changed map (a re-uploaded image, new id) would bake a new pack, and that new pack and image join the same queue.
ChangeHistoryService:TryBeginRecording returned nil from the MCP: keep your own references to undo by hand.

Do not: re-import or re-save just to "fix" it (each save bakes new packs into the same queue); blame the grade or the
lights (ruled out by turning each off live). Game scripts cannot set SurfaceAppearance maps (PluginSecurity).

Related: [[studio-no-screen]], [[place-script-check]].
