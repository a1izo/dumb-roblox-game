"""The VFX kit's art (the owner, 2026-10-24: "redo them and make ALL of them extremely high quality ... right now they
just look like simple particles"): textures drawn and rendered here, meshes built here, both shipped in their own props
file, DeathsGambitModels_Fx.fbx, and played by src/client/Presentation/Vfx.

    noise.py     gradient noise, fractal sums and domain warps (tileable, and looping in time)
    draw.py      shapes as signed distances with anti-aliased edges, compositing, colour bleed, PNG writing
    textures.py  every texture (flipbooks and single images), white or grey so the game tints them
    volumes.py   the smoke flipbooks rendered from Blender volumes (needs bpy)
"""
