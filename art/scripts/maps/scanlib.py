"""The maps' tiling surfaces, made from photographed material scans (art/source/textures, listed in
art/sources.json and fetched by art/scripts/sources.py). Nothing here is drawn from noise: a scan
supplies the surface, and this module only fits it to the game.

For each surface it: brings the scan to the pixel density the look rulebook gives that kind of
surface; lays it out over one repeat (side by side for bricks, tiles and boards; shuffled into
patches for ash, asphalt, plaster or snow, so no repeat shows); moves its colour onto the surface's
own in the game's palette, keeping the scan's light and dark; and adds what the scene asks for
(joints between panels, rain on a road). Each surface gets a colour map (sRGB), a normal map (OpenGL
style, +V up), a roughness map, and a metalness map when the scan has one.

Arrays are indexed [v, u] with v = 0 at the bottom of the image, like Blender's pixel buffer.
"""

import os
import zipfile

import bpy
import numpy as np

import common
import lookbook

SOURCE = common.source("textures")

# What each map is called in a Poly Haven file name and in an ambientCG one.
KINDS = {
    "color": ("_diff_", "_diffuse_", "_albedo_", "_col1_", "_Color."),
    "normal": ("_nor_gl_", "_NormalGL."),
    "rough": ("_rough_", "_Roughness."),
    "height": ("_disp_", "_displacement_", "_Displacement."),
    "metal": ("_metal_", "_Metalness."),
}
LUMA = np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)
# Raise this when the surfaces change in a way an imported map must follow (new textures for the
# same meshes): every venue's version then goes up at its next export (export.mesh_digest), and the
# game takes the new import over the old one.
REVISION = 1

_cache = {}


# Reading scans ---------------------------------------------------------------------------------------


def _files(scan):
    folder = os.path.join(SOURCE, scan)
    if not os.path.isdir(folder):
        raise FileNotFoundError(f"scan {scan} is not in art/source: run art/scripts/sources.py fetch")
    for name in os.listdir(folder):
        if name.endswith(".zip") and not os.path.exists(os.path.join(folder, name[:-4] + "_Color.jpg")):
            with zipfile.ZipFile(os.path.join(folder, name)) as archive:
                archive.extractall(folder)
    return [os.path.join(folder, name) for name in sorted(os.listdir(folder)) if name.endswith(".jpg")]


def paths(scan):
    """{"color", "normal", "rough", "height"[, "metal"]: file} of a scan (the 2K originals)."""
    out = {}
    for path in _files(scan):
        # (Only what follows the scan's own name: blue_metal_plate is not a metalness map.)
        rest = os.path.basename(path)[len(scan):]
        for kind, marks in KINDS.items():
            if kind not in out and any(mark in rest for mark in marks):
                out[kind] = path
    return out


def _shrink(arr, rows, cols):
    """An array averaged down to rows x cols (each new pixel is the mean of the block it covers)."""
    for axis, count in ((0, rows), (1, cols)):
        have = arr.shape[axis]
        if count >= have:
            continue
        edges = (np.arange(count) * have) // count
        sizes = np.diff(np.append(edges, have)).reshape([-1 if i == axis else 1 for i in range(arr.ndim)])
        arr = np.add.reduceat(arr, edges, axis=axis) / sizes
    return arr


def _read(path, rows, cols):
    """An image as a float array [v, u, 3] in 0..1, averaged down to rows x cols. A scan that is not
    square is fitted to the square all the same (it still repeats without a seam)."""
    img = bpy.data.images.load(path, check_existing=False)
    w, h = img.size
    buf = np.empty(w * h * img.channels, dtype=np.float32)
    img.pixels.foreach_get(buf)
    channels = img.channels
    bpy.data.images.remove(img)
    arr = buf.reshape(h, w, channels)
    arr = arr[..., :3] if channels >= 3 else np.repeat(arr[..., :1], 3, axis=-1)
    return np.ascontiguousarray(_shrink(arr, rows, cols), dtype=np.float32)


def load(scan, size, cols=None):
    """{"color", "normal", "rough", "height"[, "metal"]} of a scan at size x size (or size rows by
    `cols`). Colour is sRGB, the normal is a unit vector per pixel, the rest are single values."""
    key = (scan, size, cols)
    if key in _cache:
        return _cache[key]
    maps = {kind: _read(path, size, cols or size) for kind, path in paths(scan).items()}
    if "color" not in maps or "normal" not in maps:
        raise FileNotFoundError(f"scan {scan} has no colour or normal map")
    maps["normal"] = _unit(maps["normal"] * 2 - 1)
    for kind in ("rough", "height", "metal"):
        if kind in maps:
            maps[kind] = maps[kind][..., 0]
    maps.setdefault("rough", np.full(maps["color"].shape[:2], 0.6, dtype=np.float32))
    maps.setdefault("height", maps["color"] @ LUMA)
    _cache[key] = maps
    return maps


# Small tools -----------------------------------------------------------------------------------------


def _unit(n):
    return n / np.maximum(1e-6, np.sqrt((n * n).sum(axis=-1, keepdims=True)))


def to_linear(c):
    c = np.asarray(c, dtype=np.float32)
    return np.where(c <= 0.04045, c / 12.92, np.power((c + 0.055) / 1.055, 2.4))


def to_srgb(c):
    c = np.clip(c, 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(c, 1 / 2.4) - 0.055)


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def half(arr):
    """An array at half its size (the average of each 2 x 2 block)."""
    h, w = arr.shape[:2]
    return arr.reshape(h // 2, 2, w // 2, 2, *arr.shape[2:]).mean(axis=(1, 3))


def drift(r, size, lo=1.0, hi=4.0, beta=2.6):
    """A slow wandering field in 0..1 that wraps at the edges (a few broad patches per image)."""
    spectrum = np.fft.fft2(r.standard_normal((size, size)))
    fv = np.fft.fftfreq(size)[:, None] * size
    fu = np.fft.fftfreq(size)[None, :] * size
    f = np.sqrt(fu * fu + fv * fv)
    f[0, 0] = 1.0
    amp = 1.0 / np.power(f, beta / 2.0)
    amp[f < lo] = 0.0
    amp *= np.exp(-np.square(np.maximum(0.0, f - hi) / (hi * 0.5 + 1e-6)))
    field = np.real(np.fft.ifft2(spectrum * amp))
    field -= field.min()
    return (field / max(1e-9, field.max())).astype(np.float32)


def _slopes(height, strength):
    du = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) * 0.5
    dv = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) * 0.5
    return -du * strength, -dv * strength


def _tilt(normal, sx, sy):
    """The normal with extra relief on top (slopes added to what the scan already has)."""
    out = normal.copy()
    out[..., 0] += sx * normal[..., 2]
    out[..., 1] += sy * normal[..., 2]
    return _unit(out)


def evened(maps, amount, reach=0.12, normals=False):
    """The scan without the slow light and dark of the place it was photographed in (a brighter
    corner, a broad stain): what is left is the material itself, which can then sit next to any other
    part of itself. `reach` is the size of what counts as slow, as a share of the scan."""
    size = maps["color"].shape[0]
    f = np.fft.fftfreq(size)
    blur = np.exp(-2 * (np.pi * reach * size) ** 2 * (f[:, None] ** 2 + f[None, :] ** 2))

    def slow(a):
        return np.real(np.fft.ifft2(np.fft.fft2(a) * blur)).astype(np.float32)

    out = dict(maps)
    lin = to_linear(maps["color"])
    luma = lin @ LUMA
    gain = np.power(float(luma.mean()) / np.maximum(1e-4, slow(luma)), amount)
    out["color"] = to_srgb(lin * gain[..., None]).astype(np.float32)
    rough = maps["rough"]
    out["rough"] = rough - amount * (slow(rough) - float(rough.mean()))
    if "height" in maps:
        out["height"] = maps["height"] - amount * (slow(maps["height"]) - float(maps["height"].mean()))
    if normals:
        # The broad swells too (a snowdrift, a dip in a floor): the ground's shape is the map's to give.
        normal = maps["normal"].copy()
        normal[..., 0] -= amount * slow(normal[..., 0])
        normal[..., 1] -= amount * slow(normal[..., 1])
        out["normal"] = _unit(normal)
    return out


def prepared(scan, size=1024):
    """The scan made ready for a prop, as files: {"color", "rough", "height"} without the broad
    stains, plates and reflections of the thing that was photographed, so that only the material's
    own grain is left to lie on a prop of any shape. Kept in art/source/prepared."""
    folder = common.source("prepared")
    out = {kind: os.path.join(folder, f"{scan}_{kind}.jpg") for kind in ("color", "rough", "height")}
    if all(os.path.exists(path) for path in out.values()):
        return out
    os.makedirs(folder, exist_ok=True)
    maps = evened(load(scan, size), 1.0, 0.04)
    # Its relief keeps only the grain: a broad swell in the scan would bend the reflections on a
    # polished table top (the prop's own mesh gives it its shape).
    maps["height"] = evened(load(scan, size), 1.0, 0.012)["height"]
    for kind, path in out.items():
        arr = np.clip(maps[kind], 0, 1)
        if arr.ndim == 2:
            arr = np.stack([arr, arr, arr], axis=-1)
        rgba = np.concatenate([arr, np.ones(arr.shape[:2] + (1,), dtype=np.float32)], axis=-1).astype(np.float32)
        img = bpy.data.images.new(f"{scan}_{kind}", size, size, alpha=False)
        if kind != "color":
            img.colorspace_settings.name = "Non-Color"
        img.pixels.foreach_set(rgba.ravel())
        img.filepath_raw = path
        img.file_format = "JPEG"
        img.save(filepath=path, quality=93)
        bpy.data.images.remove(img)
    return out


# Laying a scan out over one repeat -------------------------------------------------------------------


def side_by_side(maps, n):
    """The scan repeated n x n: for surfaces with a pattern of their own (bricks, tiles, boards)."""
    return {kind: np.tile(arr, (n, n) + (1,) * (arr.ndim - 2)) for kind, arr in maps.items()}


def shuffled(maps, n, seed, layers=3, sharp=22.0):
    """The scan over n x n of its own size with no repeat to be seen: a few copies of it, each
    shifted (and mirrored) differently, patched together along soft wandering borders. Where two
    copies meet they are mixed so that the surface keeps its contrast instead of going flat."""
    r = np.random.default_rng(seed)
    p = maps["color"].shape[0]
    size = p * n
    fields = np.stack([drift(r, size, 1.0, 2.2 * n, 3.0) for _ in range(layers)])
    weights = np.exp((fields - fields.max(axis=0)) * sharp)
    weights /= weights.sum(axis=0)
    spread = np.sqrt((weights * weights).sum(axis=0))
    moves = [(int(r.integers(p)), int(r.integers(p)), bool(r.integers(2)), bool(r.integers(2))) for _ in range(layers)]
    out = {}
    for kind, arr in maps.items():
        tiled = np.tile(arr, (n, n) + (1,) * (arr.ndim - 2))
        if kind == "normal":
            mean = np.array([0.0, 0.0, 1.0], dtype=np.float32)
        else:
            mean = arr.mean(axis=(0, 1))
        total = np.zeros_like(tiled)
        for k, (du, dv, flip_u, flip_v) in enumerate(moves):
            layer = np.roll(tiled, (dv, du), axis=(0, 1))
            if flip_u:
                layer = layer[:, ::-1]
                if kind == "normal":
                    layer = layer * np.array([-1.0, 1.0, 1.0], dtype=np.float32)
            if flip_v:
                layer = layer[::-1]
                if kind == "normal":
                    layer = layer * np.array([1.0, -1.0, 1.0], dtype=np.float32)
            w = weights[k] if arr.ndim == 2 else weights[k][..., None]
            total += w * (layer - mean)
        s = spread if arr.ndim == 2 else spread[..., None]
        out[kind] = mean + total / s
    out["normal"] = _unit(out["normal"])
    return out


# Fitting it to the game ------------------------------------------------------------------------------


def grade(color, target, keep=0.5, contrast=1.0, limits=lookbook.ALBEDO):
    """The scan's colour moved onto `target` (sRGB 0..255), in the game's palette. The scan keeps its
    light and dark (raised to `contrast`); `keep` is how much of its own colour variation survives
    (0 = the target's hue everywhere, as for dyed cloth or paint; 1 = all of it, as for old stone)."""
    lin = to_linear(color)
    goal = to_linear(np.array(target, dtype=np.float32) / 255.0)
    luma = lin @ LUMA
    relative = np.power(np.maximum(1e-4, luma / max(1e-4, float(luma.mean()))), contrast)
    flat = goal[None, None, :] * relative[..., None]
    gain = np.minimum(4.0, goal / np.maximum(1e-4, lin.reshape(-1, 3).mean(axis=0)))
    own = lin * gain[None, None, :]
    out = flat * (1 - keep) + own * keep
    grey = (out @ LUMA)[..., None]
    out = grey + (out - grey) * lookbook.SATURATION
    out = np.maximum(0, out * np.array(lookbook.COLD, dtype=np.float32))
    light = np.maximum(1e-5, out @ LUMA)
    out = out * (np.clip(light, *limits) / light)[..., None]
    return to_srgb(out).astype(np.float32)


def despeckled(maps, reach=0.006):
    """The scan without its dark specks (grit and needles on photographed snow or ice), which would
    show as a sprinkle of ticks once the scan repeats."""
    size = maps["color"].shape[0]
    f = np.fft.fftfreq(size)
    blur = np.exp(-2 * (np.pi * reach * size) ** 2 * (f[:, None] ** 2 + f[None, :] ** 2))
    lin = to_linear(maps["color"])
    luma = np.maximum(1e-4, lin @ LUMA)
    around = np.real(np.fft.ifft2(np.fft.fft2(luma) * blur))
    out = dict(maps)
    out["color"] = to_srgb(lin * np.maximum(1.0, around / luma)[..., None]).astype(np.float32)
    return out


def accented(maps, base, accent, seed):
    """A second colour along the pattern the scan itself carries (the figure woven into a jacquard):
    the scan's sheen says where the figure is."""
    figure = maps["metal"] if "metal" in maps else 1 - maps["rough"]
    lo, hi = np.percentile(figure, 35), np.percentile(figure, 80)
    mask = smoothstep(lo, max(lo + 1e-3, hi), figure)[..., None]
    goal = to_linear(np.array(accent, dtype=np.float32) / 255.0) / to_linear(np.array(base, dtype=np.float32) / 255.0)
    lin = to_linear(maps["color"])
    maps["color"] = to_srgb(lin * (1 + mask * (goal[None, None, :] - 1))).astype(np.float32)
    return maps


def joints(maps, cols, rows, width=0.004, dark=0.5, depth=1.6):
    """Seams the builder made, not the material: between wall panels, ceiling boards, carpet tiles.
    cols x rows cells per repeat (0 = no seams that way); `width` is a share of the repeat."""
    size = maps["color"].shape[0]
    v, u = np.mgrid[0:size, 0:size] / size
    edge = np.full((size, size), 1.0)
    if cols:
        cu = (u * cols) % 1.0
        edge = np.minimum(edge, np.minimum(cu, 1 - cu) / cols)
    if rows:
        cv = (v * rows) % 1.0
        edge = np.minimum(edge, np.minimum(cv, 1 - cv) / rows)
    seam = (1 - smoothstep(width * 0.5, width, edge)).astype(np.float32)
    maps["color"] = maps["color"] * (1 - seam[..., None] * dark)
    maps["rough"] = np.clip(maps["rough"] + seam * 0.25, 0, 1)
    sx, sy = _slopes(1 - seam, depth * size / 256)
    maps["normal"] = _tilt(maps["normal"], sx, sy)
    return maps


def wetted(maps, amount, seed):
    """Rain on the surface: darker, glossy, and standing water in the dips, where it lies flat."""
    size = maps["color"].shape[0]
    r = np.random.default_rng(seed + 900)
    height = maps["height"]
    low = 1 - (height - height.min()) / max(1e-6, float(height.max() - height.min()))
    pools = smoothstep(0.52, 0.7, low * 0.35 + drift(r, size, 1.0, 5.0, 3.0) * 0.65) * amount
    maps["color"] = maps["color"] * (1 - 0.3 * amount) * (1 - 0.18 * pools[..., None])
    maps["rough"] = np.clip(maps["rough"] * (1 - 0.5 * amount), 0.04, 1) * (1 - pools) + 0.03 * pools
    flat = np.array([0.0, 0.0, 1.0], dtype=np.float32)
    maps["normal"] = _unit(maps["normal"] * (1 - pools[..., None] * 0.92) + flat * pools[..., None] * 0.92)
    return maps


def _prepared_normal(scan, kind, size):
    """A normal map art/scripts/heightmap.py made for a scan (art/source/prepared): "height" is the one
    of its rebuilt height map, "relief" the one for the facets of its relief tile (maps/relief.py)."""
    name = {"height": "normal", "relief": "relief_normal"}[kind]
    path = os.path.join(common.source("prepared"), f"{scan}_{name}.png")
    if not os.path.exists(path):
        raise FileNotFoundError(f"{path} is missing: run art/scripts/heightmap.py {scan} (see there)")
    return _unit(_read(path, size, size) * 2 - 1)


def build(scan, colour, studs, where, n, organic, keep, contrast, relief, rough, quiet, wet, joint, turn, seed,
          even, accent, metal, reach, clean, normal=None, scale=1):
    size = min(lookbook.LARGEST, lookbook.pixels(studs, where) * scale)
    if isinstance(n, tuple):
        # A scan that is longer one way (a bolt of cloth): across x up, so the figure keeps its shape.
        across, up = n
        piece = load(scan, -(-2 * size // up), -(-2 * size // across))
        maps = {kind: _shrink(np.tile(arr, (up, across) + (1,) * (arr.ndim - 2)), size, size) for kind, arr in piece.items()}
        maps["normal"] = _unit(maps["normal"])
        n = 1
    else:
        maps = load(scan, size // n)
    if normal:
        maps = dict(maps, normal=_prepared_normal(scan, normal, size // n))
    if not metal:
        # (Cloth scans carry a sheen map under that name; only real metal keeps a metalness map.)
        maps = {kind: arr for kind, arr in maps.items() if kind != "metal" or accent}
    if clean:
        maps = despeckled(maps)
    if even:
        # A shuffled surface must match itself everywhere, so it loses broad stains too; a patterned
        # one keeps the difference from one brick or board to the next.
        maps = evened(maps, even, reach or (0.05 if organic else 0.12), normals=organic)
    if turn:
        maps = quarter_turn(maps)
    maps = shuffled(maps, n, seed) if organic else side_by_side(maps, n)
    r = np.random.default_rng(seed)
    maps["color"] = grade(np.clip(maps["color"], 0, 1), colour, keep, contrast)
    if accent:
        maps = accented(maps, colour, accent, seed)
        maps.pop("metal", None)
    # A slow drift in tone across the repeat, so two neighbouring repeats do not look stamped. It stays
    # inside the surface's own variation: on rough concrete it is lost in the grain, and a painted wall,
    # which has almost none, gets almost none (there it would show as clouds).
    tone = maps["color"] @ LUMA
    amount = min(lookbook.MACRO, 2.0 * float(tone.std()) / max(1e-4, float(tone.mean())))
    maps["color"] = maps["color"] * (1 + amount * (drift(r, size)[..., None] * 2 - 1))
    maps["rough"] = np.clip(maps["rough"], 0, 1)
    if rough is not None:
        # The scan's roughness around the surface's own level (a polished floor, a matt wall).
        maps["rough"] = rough + (maps["rough"] - float(maps["rough"].mean())) * 0.7
    maps["rough"] = maps["rough"] + 0.04 * (drift(r, size) * 2 - 1)
    if relief != 1.0:
        maps["normal"] = _unit(maps["normal"] * np.array([relief, relief, 1.0], dtype=np.float32))
    if joint:
        maps = joints(maps, *joint)
    if wet:
        maps = wetted(maps, wet, seed)
    normal = maps["normal"] * 0.5 + 0.5
    out = {
        "color": np.clip(maps["color"], 0, 1),
        "normal": np.clip(half(normal) if quiet else normal, 0, 1),
        "rough": np.clip(half(maps["rough"]), 0.03, 1),
    }
    if "metal" in maps:
        out["metal"] = np.clip(half(maps["metal"]), 0, 1)
    return out


def quarter_turn(maps):
    """The scan turned a quarter (boards that ran across now run up)."""
    out = {}
    for kind, arr in maps.items():
        turned = np.rot90(arr)
        if kind == "normal":
            turned = np.stack([-turned[..., 1], turned[..., 0], turned[..., 2]], axis=-1)
        out[kind] = np.ascontiguousarray(turned)
    return out


def surface(scan, colour, studs, where="wall", n=1, organic=False, keep=0.5, contrast=1.0, relief=1.0, rough=None,
            quiet=False, wet=0.0, joint=None, turn=False, seed=1, even=0.85, accent=None, metal=False, reach=None, clean=False,
            normal=None):
    """A LIBRARY entry: the surface's generator and the studs one repeat covers.

    scan     the photographed material (a folder of art/source/textures)
    colour   the surface's own colour in the game (sRGB), which the scan is graded onto
    studs    what one repeat covers; n = how many times the scan fits across it (1, 2, 4 or 8), or
             (across, up) for a scan that is not square
    where    how close a player gets (lookbook.DENSITY): sets the pixel size
    organic  shuffle the scan into patches (ash, asphalt, plaster, snow); off for patterned surfaces
    quiet    faint relief: the normal map is kept at half size
    even     how much of the scan's own slow light and dark is taken out before it is laid out
    accent   a second colour along the figure the scan carries (a jacquard's woven pattern)
    clean    take the scan's dark specks out (grit on photographed snow)
    normal   a normal map art/scripts/heightmap.py made, in place of the scan's own: "height" (from the
             height it rebuilt) or "relief" (for the facets of the relief tile, maps/relief.py)
    """
    return (lambda scale=1: build(scan, colour, studs, where, n, organic, keep, contrast, relief, rough, quiet, wet,
                                  joint, turn, seed, even, accent, metal, reach, clean, normal, scale)), studs


# name -> (generator, studs covered by one repeat of the image)
LIBRARY = {
    # Stone, concrete, plaster.
    "MarbleBlack": surface("granite_tile", (38, 37, 40), 16, "floor", 2, keep=0.3, contrast=1.5, rough=0.14, quiet=True, seed=11),
    "MarbleWhite": surface("marble_01", (204, 200, 192), 12, "floor", 2, keep=0.6, contrast=0.6, rough=0.16, quiet=True, seed=12),
    "Concrete": surface("concrete_wall_008", (114, 114, 116), 16, "wall", 2, True, keep=0.6, seed=20),
    "ConcreteDark": surface("concrete_floor_worn_001", (64, 64, 68), 16, "floor", 2, True, keep=0.6, seed=21),
    "PlasterDark": surface("beige_wall_001", (46, 50, 56), 10, "wall", 1, True, keep=0.2, contrast=0.6, quiet=True, seed=22),
    "PlasterLight": surface("beige_wall_001", (150, 144, 132), 10, "wall", 1, True, keep=0.2, contrast=0.6, quiet=True, seed=23),
    "PlasterGrey": surface("beige_wall_001", (104, 110, 120), 10, "wall", 1, True, keep=0.2, contrast=0.6, quiet=True, seed=42),
    # The Campus's rooms: a warm cream over the dado, and the 1960s block's painted sage dado.
    "PlasterCream": surface("beige_wall_001", (168, 156, 132), 10, "wall", 1, True, keep=0.2, contrast=0.6, quiet=True, seed=108),
    "PlasterGreen": surface("beige_wall_001", (92, 106, 96), 10, "wall", 1, True, keep=0.2, contrast=0.6, quiet=True, seed=109),
    # (The scan's own normal map has its red and green swapped, and its height map is blank: both come from
    # the height art/scripts/heightmap.py rebuilt. StoneRelief is the same wall where its joints are cut
    # into the mesh, maps/relief.py.)
    "Stone": surface("medieval_blocks_03", (150, 144, 130), 8, "wall", 1, keep=0.7, seed=28, normal="height"),
    "StoneRelief": surface("medieval_blocks_03", (150, 144, 130), 8, "wall", 1, keep=0.7, seed=28, normal="relief"),
    "Slate": surface("roof_slates_03", (46, 48, 54), 10, "far", 1, keep=0.4, seed=33),
    "FacadeTile": surface("exterior_wall_cladding_02", (150, 140, 124), 8, "wall", 1, keep=0.4, seed=34),
    "FacadeTileGrey": surface("concrete_tile_facade", (104, 108, 114), 8, "wall", 1, keep=0.4, seed=35),
    "BrickRed": surface("brick_wall_001", (128, 58, 44), 10, "wall", 1, keep=0.45, contrast=0.8, seed=26),
    "BrickDark": surface("red_brick_03", (70, 48, 44), 7, "wall", 2, keep=0.6, seed=27),
    "Terrazzo": surface("Terrazzo019L", (170, 166, 156), 12, "floor", 4, True, keep=0.8, rough=0.2, quiet=True, seed=60),
    "TerrazzoDark": surface("Terrazzo019L", (86, 88, 92), 12, "floor", 4, True, keep=0.8, rough=0.2, quiet=True, seed=61),
    # Wood.
    "WoodFloor": surface("wood_floor", (118, 80, 52), 12, "floor", 2, keep=0.6, rough=0.34, quiet=True, seed=13),
    "WoodFloorDark": surface("dark_wooden_planks", (70, 46, 32), 12, "floor", 2, keep=0.6, rough=0.42, seed=14),
    "WoodPanel": surface("walnut_veneer_02", (92, 58, 36), 8, "wall", 2, keep=0.6, rough=0.36, quiet=True,
                         joint=(2, 1), turn=True, seed=25),
    "Parquet": surface("rectangular_parquet", (110, 72, 44), 8, "floor", 1, keep=0.6, rough=0.3, quiet=True, seed=55),
    "WoodHerringbone": surface("herringbone_parquet", (126, 88, 56), 12, "floor", 1, keep=0.6, rough=0.3, quiet=True,
                               seed=70),
    "CeilingSlats": surface("oak_veneer_01", (104, 70, 44), 8, "ceiling", 2, keep=0.5, rough=0.5, joint=(0, 12, 0.012, 0.85), seed=59),
    # Cloth and paper on walls and floors.
    "CarpetGrey": surface("Carpet016", (58, 62, 72), 12, "floor", 2, True, keep=0.0, contrast=0.7, rough=0.95, seed=15),
    "CarpetRed": surface("Carpet015", (92, 16, 22), 12, "floor", 8, keep=0.0, rough=0.95, seed=16),
    "CarpetNavy": surface("Carpet016", (34, 40, 56), 12, "floor", 2, True, keep=0.0, contrast=0.7, rough=0.95, seed=46),
    "CarpetPurple": surface("Carpet015", (54, 22, 66), 12, "floor", 8, keep=0.0, rough=0.95, seed=68),
    "CarpetGreen": surface("Carpet015", (30, 58, 42), 12, "floor", 8, keep=0.0, rough=0.95, seed=69),
    "CarpetTile": surface("Carpet016", (70, 74, 82), 7, "floor", 1, keep=0.0, contrast=0.7, rough=0.95, joint=(4, 4), seed=66),
    "CarpetTileBlue": surface("Carpet016", (34, 48, 78), 7, "floor", 1, keep=0.0, contrast=0.7, rough=0.95, joint=(4, 4), seed=67),
    "Wallpaper": surface("floral_jacquard", (54, 18, 24), 8, "wall", (4, 3), keep=0.0, contrast=1.0, accent=(150, 118, 70), rough=0.7, seed=24),
    "Damask": surface("floral_jacquard", (52, 16, 20), 6, "wall", (3, 2), keep=0.0, contrast=1.0, accent=(96, 34, 38), rough=0.6, seed=56),
    "Tatami": surface("tatami_mat", (170, 156, 98), 6, "floor", 1, keep=0.5, seed=65),
    # Tile and sheet floors, ceilings.
    "TileWhite": surface("Tiles002", (214, 216, 216), 4, "wall", 1, keep=0.0, contrast=0.45, rough=0.12, even=1.0, reach=0.03, seed=17),
    "TileChecker": surface("floor_tiles_06", (128, 126, 124), 10, "floor", 1, keep=0.8, rough=0.14, quiet=True, seed=18),
    "TileMetroFloor": surface("interior_tiles", (118, 120, 124), 6, "floor", 1, keep=0.3, rough=0.3, seed=43),
    "TileMetroGrey": surface("long_white_tiles", (150, 154, 156), 4, "wall", 1, keep=0.4, rough=0.16, seed=44),
    "VinylLab": surface("linoleum_brown", (150, 162, 156), 12, "floor", 2, True, keep=0.2, contrast=0.5, rough=0.3, quiet=True, seed=62),
    "VinylClinic": surface("linoleum_brown", (186, 196, 200), 12, "floor", 2, True, keep=0.2, contrast=0.5, rough=0.3, quiet=True,
                           seed=63),
    "Linoleum": surface("linoleum_brown", (122, 92, 66), 12, "floor", 2, True, keep=0.5, contrast=0.6, rough=0.34, quiet=True, seed=64),
    "Ceiling": surface("polystyrene", (176, 176, 172), 8, "ceiling", 2, True, keep=0.2, contrast=0.6, joint=(4, 4), seed=36),
    "CeilingDark": surface("polystyrene", (92, 94, 98), 8, "ceiling", 2, True, keep=0.2, contrast=0.6, joint=(4, 4), seed=45),
    "CeilingPlaster": surface("beige_wall_001", (196, 190, 178), 16, "ceiling", 1, True, keep=0.2, contrast=0.6, quiet=True, seed=57),
    "CeilingPlasterDark": surface("beige_wall_001", (58, 60, 66), 16, "ceiling", 1, True, keep=0.2, contrast=0.6, quiet=True, seed=58),
    # Metal.
    "MetalFloor": surface("metal_plate", (96, 98, 104), 8, "floor", 4, keep=0.3, metal=True, seed=37),
    "Shutter": surface("painted_metal_shutter", (150, 152, 154), 7, "wall", 1, keep=0.4, seed=38),
    # Outside: Tokyo in the rain, the campus in snow.
    "Asphalt": surface("asphalt_02", (46, 46, 50), 20, "ground", 2, True, keep=0.5, seed=29),
    "AsphaltWet": surface("clean_asphalt", (44, 44, 48), 16, "road", 2, True, keep=0.5, wet=1.0, seed=29),
    "PaversWarm": surface("brick_pavement_02", (120, 106, 92), 8, "floor", 1, keep=0.5, seed=31),
    "PaversWet": surface("PavingStones136", (104, 104, 108), 8, "floor", 1, keep=0.4, wet=1.0, seed=30),
    "PaversWarmWet": surface("brick_pavement_02", (120, 106, 92), 8, "floor", 1, keep=0.5, wet=1.0, seed=31),
    "Snow": surface("snow_02", (222, 228, 238), 28, "ground", 4, True, keep=0.5, contrast=0.7, clean=True, seed=47),
    "Snow2": surface("snow_02", (214, 222, 236), 28, "far", 4, True, keep=0.5, contrast=0.7, clean=True, seed=71),
    "SnowPath": surface("Snow006", (150, 152, 158), 16, "ground", 2, True, keep=0.6, seed=48),
    "SnowThin": surface("asphalt_snow", (170, 174, 184), 14, "ground", 2, True, keep=0.8, contrast=1.0, seed=72),
    "Ice": surface("Snow014", (60, 76, 90), 14, "ground", 2, True, keep=0.3, contrast=0.7, rough=0.1, quiet=True, clean=True, seed=49),
    # The lobby, the Grey Realm: dark ash and basalt, old flagstones (the owner asked for it blacker
    # and darker, 2026-10-10; the light went down with them, see LightingPresets.lobby, so these stay
    # light enough to model).
    "Ash": surface("moon_01", (112, 112, 116), 22, "ground", 2, True, keep=0.3, quiet=True, seed=50),
    "AshCracked": surface("dry_mud_field_001", (98, 97, 96), 21, "ground", 2, True, keep=0.2, contrast=1.2, seed=51),
    "RockGrey": surface("Rock050", (70, 70, 74), 14, "wall", 2, True, keep=0.3, seed=52),
    "RuinFlag": surface("monastery_stone_floor", (90, 90, 94), 12, "floor", 2, keep=0.3, seed=53),
    "RuinStone": surface("medieval_blocks_03", (78, 78, 82), 14, "wall", 2, keep=0.3, seed=54),
    "BoneWhite": surface("white_plaster_02", (168, 162, 146), 4, "wall", 1, True, keep=0.3, rough=0.55, seed=81),
    "BoneOld": surface("white_plaster_02", (122, 116, 104), 4, "wall", 1, True, keep=0.4, rough=0.65, seed=82),
    # What used to be one flat colour each: the metals, the painted trims, cloth, leather, paper, wood
    # and bark that frame everything else. Small textures (they are narrow), from the scans the props
    # use, so a door frame and the filing cabinet beside it are the same steel.
    "BlackMetal": surface("metal_plate_02", (30, 30, 34), 4, "wall", 1, True, keep=0.2, rough=0.45, metal=True, seed=83),
    "DarkMetal": surface("metal_plate_02", (60, 62, 68), 4, "wall", 1, True, keep=0.2, rough=0.4, metal=True, seed=84),
    "Steel": surface("metal_plate_02", (150, 152, 158), 4, "wall", 1, True, keep=0.2, rough=0.3, metal=True, seed=85),
    "Brass": surface("metal_plate_02", (176, 140, 72), 4, "wall", 1, True, keep=0.0, rough=0.3, metal=True, seed=86),
    "Gold": surface("metal_plate_02", (214, 176, 96), 4, "wall", 1, True, keep=0.0, rough=0.22, metal=True, seed=87),
    "ChainLink": surface("metal_plate_02", (112, 116, 122), 4, "wall", 1, True, keep=0.2, rough=0.45, metal=True, seed=88),
    "WhiteTrim": surface("beige_wall_001", (218, 214, 204), 4, "wall", 1, True, keep=0.1, rough=0.4, quiet=True, seed=89),
    "CreamTrim": surface("beige_wall_001", (196, 184, 160), 4, "wall", 1, True, keep=0.1, rough=0.4, quiet=True, seed=90),
    "BlackTrim": surface("beige_wall_001", (24, 24, 28), 4, "wall", 1, True, keep=0.1, rough=0.35, quiet=True, seed=91),
    "RedTrim": surface("beige_wall_001", (150, 22, 32), 4, "wall", 1, True, keep=0.0, rough=0.4, quiet=True, seed=92),
    "Vermilion": surface("beige_wall_001", (170, 44, 32), 4, "wall", 1, True, keep=0.0, rough=0.3, quiet=True, seed=93),
    "PaintYellow": surface("beige_wall_001", (222, 190, 60), 4, "wall", 1, True, keep=0.0, rough=0.45, quiet=True, seed=94),
    "BlindSlat": surface("beige_wall_001", (150, 140, 118), 4, "wall", 1, True, keep=0.1, rough=0.5, quiet=True, seed=95),
    "Rubber": surface("rubber_tiles", (30, 30, 32), 4, "wall", 1, True, keep=0.0, rough=0.85, seed=96),
    "Paper": surface("Paper001", (226, 220, 205), 2, "wall", 2, True, keep=0.2, rough=0.8, quiet=True, seed=97),
    "Photo": surface("Paper001", (70, 72, 74), 2, "wall", 2, True, keep=0.0, rough=0.35, quiet=True, seed=98),
    "PhotoPale": surface("Paper001", (178, 176, 168), 2, "wall", 2, True, keep=0.0, rough=0.35, quiet=True, seed=99),
    "Fabric": surface("rough_linen", (40, 40, 46), 2, "wall", 2, keep=0.0, rough=0.9, seed=100),
    "FabricRed": surface("velour_velvet", (120, 24, 30), 2, "wall", 2, keep=0.0, rough=0.85, seed=101),
    "TarpBlue": surface("rough_linen", (36, 78, 150), 2, "wall", 2, keep=0.0, rough=0.55, seed=102),
    "RedString": surface("rough_linen", (170, 24, 32), 2, "wall", 2, keep=0.0, rough=0.9, seed=103),
    "Leather": surface("brown_leather", (40, 26, 22), 2, "wall", 1, True, keep=0.3, rough=0.5, seed=104),
    "Wood": surface("oak_veneer_01", (86, 58, 38), 6, "wall", 1, keep=0.5, rough=0.5, quiet=True, seed=105),
    "Bamboo": surface("bamboo_wall", (156, 138, 88), 7, "wall", 1, keep=0.5, rough=0.5, seed=106),
    "Bark": surface("sakura_bark", (60, 44, 34), 6, "wall", 1, keep=0.5, seed=107),
}

# Surfaces drawn at twice the size the rulebook gives them (the owner, 2026-10-25: "make every texture in the game
# more high quality"): the floors under the players' feet first, then the small trims, as many as fit in 80% of the
# texture memory each scene had free (scripts/budget.py), Tokyo's wet streets among them. None that the Lobby shows:
# its scene has no room left.
SHARPER = frozenset("""
    WoodFloorDark WoodFloor WoodHerringbone Terrazzo VinylClinic CarpetTile CarpetTileBlue Linoleum TerrazzoDark
    TileChecker MarbleWhite CarpetPurple Tatami TileMetroFloor CarpetGreen PaversWarmWet PaversWet PaversWarm
    Paper CreamTrim Vermilion TileWhite Gold Photo TarpBlue Rubber ChainLink
""".split())
