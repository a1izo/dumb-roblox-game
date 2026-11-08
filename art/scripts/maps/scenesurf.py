"""Surfaces of the scene deaths' sets (maps/venues/scenes): a meadow's grass drawn blade by blade over a scan of
dry ground, and scans graded for the cemetery's headstones, the desert ridge, the battlefield, the car park and the
asylum's lab. Registered into scanlib.LIBRARY like the rugs and facades.
"""

import numpy as np

import lookbook
from maps import scanlib


def _grass(scale=1):
    """A wintry meadow seen from a man's height: soil under a dense mat of blades lying every way, olive and straw,
    darker at their roots. Tiles both ways (every blade wraps)."""
    size = min(lookbook.LARGEST, lookbook.pixels(12.0, "ground") * scale)
    r = np.random.default_rng(401)
    soil = scanlib.load("dry_mud_field_001", size)["color"]
    soil = scanlib.grade(np.clip(soil, 0, 1), (58, 52, 40), keep=0.4, contrast=0.8)
    color = soil.copy()
    height = np.zeros((size, size), dtype=np.float32)
    palette = np.array([
        (92, 108, 58), (80, 98, 52), (106, 120, 66), (118, 124, 72), (140, 134, 86), (70, 88, 48), (100, 114, 70),
        (98, 112, 60),
    ], dtype=np.float32) / 255.0
    count = int(52000 * (size / 1024) ** 2)
    steps = 26
    x0 = r.uniform(0, size, count)
    y0 = r.uniform(0, size, count)
    lean = r.normal(0.6, 0.9, count)  # (mostly lying one way, as a breeze left them)
    length = r.uniform(18, 44, count) * size / 1024
    pick = palette[r.integers(0, len(palette), count)] * r.uniform(0.82, 1.12, (count, 1))
    dx, dy = np.cos(lean) * length, np.sin(lean) * length
    bend = r.normal(0, 0.25, count)
    for k in range(steps):
        t = k / (steps - 1)
        # (a slight curve along the blade; the root sits in shade, the tip catches the light)
        cx = x0 + dx * t - dy * bend * t * t
        cy = y0 + dy * t + dx * bend * t * t
        shade = 0.55 + 0.5 * t
        for ox, oy in ((0, 0), (1, 0), (0, 1)) if t < 0.4 else (((0, 0), (1, 0)) if t < 0.75 else ((0, 0),)):
            ix = (cx.astype(np.int64) + ox) % size
            iy = (cy.astype(np.int64) + oy) % size
            color[iy, ix] = pick * shade
            height[iy, ix] = 0.3 + 0.7 * t
    color = np.clip(color, 0, 1)
    sx, sy = scanlib._slopes(height, 2.2)
    normal = scanlib._unit(np.stack([sx, sy, np.ones_like(sx)], axis=-1)) * 0.5 + 0.5
    rough = np.clip(0.88 - 0.1 * height, 0.5, 1).astype(np.float32)
    return {"color": color.astype(np.float32), "normal": normal.astype(np.float32), "rough": scanlib.half(rough)}


S = scanlib.surface
SURFACES = {
    "MeadowGrass": ((lambda scale=1: _grass(scale)), 12.0),
    # The cemetery's headstones: pale marble (the hero's and every third) and a weathered grey-brown.
    "HeadstonePale": S("concrete_wall_008", (204, 198, 184), 4, "wall", 1, True, keep=0.3, contrast=0.6, rough=0.7,
                       seed=305),
    "HeadstoneDark": S("concrete_wall_008", (86, 80, 72), 4, "wall", 1, True, keep=0.6, seed=306),
    # The desert ridge at dusk (Sam's): sun-baked hardpan, the boulders and the ridge's rock.
    "DesertGround": S("dry_mud_field_001", (150, 116, 80), 18, "ground", 2, True, keep=0.4, seed=302),
    "DesertRock": S("rock_face_03", (128, 98, 72), 12, "wall", 2, True, keep=0.45, seed=303),
    # The battlefield: churned mud, broken concrete and its rubble.
    "WarMud": S("dry_mud_field_001", (70, 58, 48), 16, "ground", 2, True, keep=0.45, contrast=1.2, seed=301),
    "WarRubble": S("rock_face_03", (96, 90, 84), 8, "wall", 2, True, keep=0.4, seed=304),
    # The car park: worn floor slab, the pillars' and ceiling's board-marked concrete.
    "ParkFloor": S("concrete_floor_worn_001", (92, 90, 86), 16, "floor", 2, True, keep=0.6, seed=309),
    "ParkConcrete": S("concrete_wall_008", (142, 136, 124), 10, "wall", 1, True, keep=0.6, seed=310),
    # The asylum's lab: a pale blue-grey floor and walls.
    "LabFloor": S("concrete_floor_worn_001", (140, 152, 160), 16, "floor", 2, True, keep=0.6, seed=307),
    "LabWall": S("concrete_wall_008", (112, 122, 128), 12, "wall", 2, True, keep=0.6, seed=308),
}
