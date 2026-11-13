---
name: surface-roughness-live-test-2026-11
description: "Measured roughness of every map material, what swapping roughness / EnvironmentSpecularScale does live (2026-11-14), and how to try a roughness map in a play test with EditableImage"
metadata:
  type: reference
---

Graphics plan phase 10 (2026-11-14). Mean roughness of the maps in art/export/textures/maps: Terrazzo 0.21, MarbleBlack
0.14, MarbleWhite 0.15, TileWhite 0.12, TileChecker 0.15, VinylLab/VinylClinic 0.30, Linoleum 0.34, WoodFloor 0.34,
WoodFloorDark 0.41, Parquet 0.30, AsphaltWet 0.23, painted walls (PlasterLight/Grey/Dark) 0.62, Ceiling 0.48, WoodPanel
0.36, Concrete 0.74, carpets 0.95. Floors are already glossy: they look matt for lack of bright narrow lights and pale colour.

Live results: EnvironmentSpecularScale 0.3 -> 0.9 changes nothing indoors; a plaster wall at roughness 0.5 or 0.35 turns
lilac-grey (the dark blue sky reflects in it): a grade change, not a sheen; a red 1.2 / range 16 point light tints the walls,
ceiling and floor near it and fades within ~25 studs (the corridor picture's red sign works); no streaks, Roblox has no real
reflections.

**How to try a roughness map with no upload:** on the Client datamodel, `AssetService:CreateEditableImage({Size = Vector2.new(4, 4)})`,
fill a `buffer.create(64)` with RGBA bytes, `img:WritePixelsBuffer(Vector2.zero, Vector2.new(4, 4), buf)` (`WritePixels` does not
exist in this Studio), then `surfaceAppearance.RoughnessMapContent = Content.fromObject(img)`. Put the original back with
`surfaceAppearance.RoughnessMap = "rbxassetid://..."`. The map's big meshes are one per material (Map_Campus_Terrazzo_1 is
the whole campus's terrazzo), so a swap shows everywhere that material is. `Lighting.Technology` cannot be read from a script.
**How to apply:** do not retune floors' roughness for gloss; light placement and floor colour decide how glossy a floor looks.
Related: [[vertex-colours-ignored-under-surfaceappearance]], [[graphics-references-2026-11]].
