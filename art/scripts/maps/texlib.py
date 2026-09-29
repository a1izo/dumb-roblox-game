"""Seamless tiling textures for the maps, drawn with numpy (no Blender needed to compute them).

Every texture tiles in both directions: noise is made in the frequency domain (so it wraps),
and patterns (bricks, tiles, planks) repeat a whole number of times per image. Each material
gets a colour map (sRGB), a normal map (OpenGL style, +V up) and a roughness map.

Arrays are indexed [v, u] with v = 0 at the bottom of the image, like Blender's pixel buffer.
"""

import math

import numpy as np

N = 1024


def rng(seed):
    return np.random.default_rng(seed)


def fbm(r, beta=2.0, lo=1.0, hi=None, aniso=(1.0, 1.0), n=N):
    """Periodic fractal noise in [0, 1]. beta sets roughness (higher = smoother); lo/hi limit
    the frequencies (cycles per image); aniso stretches it ((u, v) weights: >1 = finer)."""
    white = r.standard_normal((n, n))
    spectrum = np.fft.fft2(white)
    fv = np.fft.fftfreq(n)[:, None] * n * aniso[1]
    fu = np.fft.fftfreq(n)[None, :] * n * aniso[0]
    f = np.sqrt(fu * fu + fv * fv)
    f[0, 0] = 1.0
    amp = 1.0 / np.power(f, beta / 2.0)
    amp[f < lo] = 0.0
    if hi is not None:
        amp *= np.exp(-np.square(np.maximum(0.0, f - hi) / (hi * 0.5 + 1e-6)))
    field = np.real(np.fft.ifft2(spectrum * amp))
    field -= field.min()
    field /= max(1e-9, field.max())
    return field


def grid(cols, rows, offset=0.0, n=N):
    """For a brick/tile layout: per-pixel cell index (col, row) and position inside the cell
    (0..1). offset shifts every other row by that fraction of a cell."""
    v, u = np.mgrid[0:n, 0:n] / n
    fr = v * rows
    row = np.floor(fr).astype(int)
    fc = u * cols + (row % 2) * offset * 1.0
    col = np.floor(fc).astype(int) % cols
    return col, row % rows, fc - np.floor(fc), fr - np.floor(fr)


def edge_distance(cu, cv, aspect=1.0):
    """Distance (in cell-height units) from each pixel to the nearest cell edge."""
    du = np.minimum(cu, 1 - cu) * aspect
    dv = np.minimum(cv, 1 - cv)
    return np.minimum(du, dv)


def cell_random(col, row, seed, cols=64, rows=64):
    table = rng(seed).random((rows + 1, cols + 1))
    return table[row % rows, col % cols]


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def mix(a, b, t):
    t = t[..., None] if np.ndim(t) == 2 else t
    return np.asarray(a) * (1 - t) + np.asarray(b) * t


def tint(base, amount):
    """base colour (3,) scaled by a per-pixel factor (H, W)."""
    return np.asarray(base)[None, None, :] * amount[..., None]


def normal_from_height(h, strength):
    """Tangent-space normal map from a height field (wraps at the edges)."""
    du = (np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)) * 0.5 * N / 256
    dv = (np.roll(h, -1, axis=0) - np.roll(h, 1, axis=0)) * 0.5 * N / 256
    nx, ny = -du * strength, -dv * strength
    nz = np.ones_like(h)
    length = np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.stack([nx / length * 0.5 + 0.5, ny / length * 0.5 + 0.5, nz / length * 0.5 + 0.5], axis=-1)


def result(color, height, rough, strength=2.0):
    return {
        "color": np.clip(color, 0, 1),
        "normal": normal_from_height(height, strength),
        "rough": np.clip(rough, 0.02, 1),
    }


# Materials -----------------------------------------------------------------------------------------


def marble(seed, base, vein, vein2, tiles=2, grout=True):
    """Polished marble in large tiles (tiles x tiles per image) with thin grout lines."""
    r = rng(seed)
    warp = fbm(r, 2.4, 1, 24)
    warp2 = fbm(r, 2.0, 2, 64)
    v, u = np.mgrid[0:N, 0:N] / N
    veins = np.abs(np.sin((u * 2 + v * 1) * math.pi * 2 + warp * 7.0 + warp2 * 2.5))
    thin = (1 - smoothstep(0.0, 0.035, veins)) * (0.55 + 0.45 * fbm(r, 2.0, 2, 30))
    branch = np.abs(np.sin((u * 3 - v * 4) * math.pi * 2 + warp2 * 6.0 + warp * 2.0))
    thin = np.maximum(thin, (1 - smoothstep(0.0, 0.02, branch)) * smoothstep(0.55, 0.75, warp) * 0.8)
    faint = 1 - smoothstep(0.0, 0.3, np.abs(np.sin((u * 4 - v * 3) * math.pi * 2 + warp * 5)))
    cloud = fbm(r, 2.2, 1, 64)
    color = tint(base, 0.85 + cloud * 0.3)
    color = mix(color, vein2, faint * 0.35)
    color = mix(color, vein, np.clip(thin, 0, 1) * 0.95)
    col, row, cu, cv = grid(tiles, tiles)
    joint = (1 - smoothstep(0.004, 0.009, edge_distance(cu, cv) / tiles)) if grout else np.zeros((N, N))
    grout = joint
    color = mix(color, np.asarray(base) * 0.5, grout)
    height = 1 - grout * 0.6 + cloud * 0.02
    rough = 0.1 + cloud * 0.08 + grout * 0.5
    return result(color, height, rough, 1.5)


def planks(seed, light, dark, count=8, joints=3):
    """Wooden floor planks along U: `count` planks across the image, staggered end joints."""
    r = rng(seed)
    v, u = np.mgrid[0:N, 0:N] / N
    row = np.floor(v * count).astype(int)
    cv = v * count - row
    shift = cell_random(row, row * 7, seed, 64, 64)
    along = (u * joints + shift) % 1.0
    plank = np.floor(u * joints + shift).astype(int)
    tone = cell_random(plank + row * 13, row, seed + 1, 64, 64)
    grain = fbm(r, 2.0, 2, 200, aniso=(0.12, 1.6))
    fine = fbm(r, 1.2, 40, 400, aniso=(0.25, 2.0))
    knots = fbm(r, 3.0, 4, 30)
    wood = np.clip(grain * 0.8 + fine * 0.35 + (knots > 0.82) * 0.4, 0, 1)
    color = mix(light, dark, np.clip(wood * 0.9 + tone * 0.35 - 0.15, 0, 1))
    color = color * (0.82 + tone * 0.3)[..., None]
    seam_v = 1 - smoothstep(0.0, 0.035, np.minimum(cv, 1 - cv))
    seam_u = 1 - smoothstep(0.0, 0.004 * joints, np.minimum(along, 1 - along))
    seam = np.maximum(seam_v, seam_u)
    color = mix(color, np.asarray(dark) * 0.35, seam * 0.85)
    height = 1 - seam * 0.8 + fine * 0.05
    rough = 0.42 + fine * 0.18 + seam * 0.3
    return result(color, height, rough, 2.5)


def carpet(seed, base, pattern_color=None, tiles=4, pattern=None):
    """Carpet: fine fibre noise, carpet tiles laid in alternating directions, optional motif."""
    r = rng(seed)
    fibre = fbm(r, 0.8, 120, 500)
    mottle = fbm(r, 2.2, 2, 40)
    col, row, cu, cv = grid(tiles, tiles)
    direction = (col + row) % 2
    stripes = np.where(direction == 1, np.sin(cu * math.pi * 60), np.sin(cv * math.pi * 60)) * 0.5 + 0.5
    shade = 0.8 + fibre * 0.25 + mottle * 0.15 + stripes * 0.05 * (pattern is None)
    color = tint(base, shade)
    if pattern == "diamond":
        v, u = np.mgrid[0:N, 0:N] / N
        k = 8
        d = np.abs(((u * k) % 1) - 0.5) + np.abs(((v * k) % 1) - 0.5)
        line = 1 - smoothstep(0.02, 0.05, np.abs(d - 0.42))
        dot = 1 - smoothstep(0.04, 0.08, d)
        ring = 1 - smoothstep(0.015, 0.035, np.abs(d - 0.2))
        motif = np.clip(line + dot * 0.9 + ring * 0.6, 0, 1)
        color = mix(color, pattern_color, motif * 0.8)
    elif pattern is None:
        seam = 1 - smoothstep(0.0, 0.006, edge_distance(cu, cv) / tiles)
        color = color * (1 - seam * 0.35)[..., None]
    height = fibre * 0.5 + mottle * 0.1
    rough = 0.92 + fibre * 0.08
    return result(color, height, rough, 0.8)


def ceramic(seed, base, grout_color, cols, rows=None, offset=0.0, bevel=0.06, variation=0.08, checker=None):
    """Glazed tiles with grout and a soft bevel. checker = second colour for a checkerboard."""
    r = rng(seed)
    rows = rows or cols
    col, row, cu, cv = grid(cols, rows, offset)
    aspect = (N / cols) / (N / rows)
    d = edge_distance(cu, cv, aspect)
    grout = 1 - smoothstep(0.02, 0.04, d)
    edge = smoothstep(0.02, 0.02 + bevel, d)
    tone = cell_random(col, row, seed, 256, 256)
    speck = fbm(r, 1.0, 60, 400)
    color = tint(base, 1 - variation / 2 + tone * variation + speck * 0.04)
    if checker is not None:
        alt = ((col + row) % 2 == 1)
        color = np.where(alt[..., None], tint(checker, 1 - variation / 2 + tone * variation), color)
    color = mix(color, grout_color, grout)
    height = edge * 0.9 + speck * 0.02
    rough = 0.12 + grout * 0.7 + speck * 0.05
    return result(color, height, rough, 3.0)


def concrete(seed, base, seams=0, stains=True):
    r = rng(seed)
    big = fbm(r, 2.6, 1, 16)
    mid = fbm(r, 2.0, 4, 128)
    pores = fbm(r, 0.6, 200, 512)
    color = tint(base, 0.8 + big * 0.25 + mid * 0.12 - (pores > 0.8) * 0.12)
    if stains:
        v, _ = np.mgrid[0:N, 0:N] / N
        streak = fbm(r, 2.0, 2, 60, aniso=(4.0, 0.15))
        color = color * (1 - np.clip(streak - 0.55, 0, 1) * 0.6)[..., None]
    height = mid * 0.4 + pores * 0.2 - (pores > 0.85) * 0.3
    if seams:
        v, u = np.mgrid[0:N, 0:N] / N
        line = 1 - smoothstep(0.0, 0.004, np.minimum((v * seams) % 1, 1 - (v * seams) % 1) / seams)
        color = color * (1 - line * 0.3)[..., None]
        height = height - line * 0.5
    rough = 0.82 + mid * 0.12
    return result(color, height, rough, 1.6)


def plaster(seed, base, stripes=None, stripe_color=None, stripe_count=24):
    """Painted plaster or wallpaper (stripes = thin vertical pinstripes)."""
    r = rng(seed)
    soft = fbm(r, 2.4, 2, 64)
    fine = fbm(r, 1.2, 60, 400)
    color = tint(base, 0.9 + soft * 0.12 + fine * 0.05)
    height = soft * 0.2 + fine * 0.25
    if stripes:
        v, u = np.mgrid[0:N, 0:N] / N
        phase = (u * stripe_count) % 1
        line = 1 - smoothstep(0.02, 0.05, np.abs(phase - 0.5))
        band = smoothstep(0.3, 0.32, np.abs(phase - 0.5)) * 0.06
        color = mix(color, stripe_color, line * 0.75)
        color = color * (1 - band)[..., None]
        height = height + line * 0.1
    rough = 0.75 + soft * 0.1 - (0 if not stripes else 0.1)
    return result(color, height, np.full((N, N), rough) if np.isscalar(rough) else rough, 0.9)


def panels(seed, light, dark, cols=4, rows=2):
    """Raised wooden wall panels (wainscot): frames and inset panels with grain."""
    r = rng(seed)
    col, row, cu, cv = grid(cols, rows)
    aspect = (N / cols) / (N / rows)
    d = edge_distance(cu, cv, aspect)
    frame = 1 - smoothstep(0.1, 0.13, d)
    bevel = smoothstep(0.1, 0.2, d)
    grain = fbm(r, 2.0, 2, 200, aniso=(1.6, 0.12))
    fine = fbm(r, 1.2, 40, 400, aniso=(2.0, 0.25))
    wood = np.clip(grain * 0.85 + fine * 0.3, 0, 1)
    color = mix(light, dark, wood)
    color = color * (1 - frame * 0.18)[..., None]
    groove = 1 - smoothstep(0.0, 0.012, np.abs(d - 0.1))
    color = color * (1 - groove * 0.5)[..., None]
    height = bevel * 0.7 + frame * 0.3 - groove * 0.4 + fine * 0.04
    rough = 0.35 + fine * 0.2
    return result(color, height, rough, 2.5)


def bricks(seed, base, mortar, cols=6, rows=18, variation=0.25, soot=0.0):
    r = rng(seed)
    col, row, cu, cv = grid(cols, rows, 0.5)
    aspect = (N / cols) / (N / rows)
    d = edge_distance(cu, cv, aspect)
    joint = 1 - smoothstep(0.05, 0.1, d)
    tone = cell_random(col, row, seed, 128, 128)
    tone2 = cell_random(col + 3, row + 5, seed + 9, 128, 128)
    rough_n = fbm(r, 1.2, 30, 400)
    chips = fbm(r, 2.0, 8, 120)
    brick = tint(base, 0.75 + tone * variation * 2 + rough_n * 0.12)
    brick = mix(brick, np.asarray(base) * np.array([0.8, 0.85, 0.95]), (tone2 > 0.8) * 0.5)
    color = mix(brick, tint(mortar, 0.85 + rough_n * 0.3), joint)
    if soot:
        grime = fbm(r, 2.4, 1, 20, aniso=(3.0, 0.4))
        color = color * (1 - np.clip(grime - 0.4, 0, 1) * soot)[..., None]
    height = (1 - joint) * (0.8 + chips * 0.2) + rough_n * 0.06 - (chips > 0.85) * (1 - joint) * 0.3
    rough = 0.8 + rough_n * 0.15
    return result(color, height, rough, 2.8)


def ashlar(seed, base, joint_color, cols=3, rows=4, variation=0.12):
    """Cut stone blocks."""
    r = rng(seed)
    col, row, cu, cv = grid(cols, rows, 0.5)
    aspect = (N / cols) / (N / rows)
    d = edge_distance(cu, cv, aspect)
    joint = 1 - smoothstep(0.015, 0.03, d)
    chisel = smoothstep(0.03, 0.09, d)
    tone = cell_random(col, row, seed, 64, 64)
    grain = fbm(r, 1.6, 8, 300)
    spots = fbm(r, 2.6, 2, 40)
    color = tint(base, 0.85 + tone * variation + grain * 0.12 - np.clip(spots - 0.6, 0, 1) * 0.5)
    color = mix(color, joint_color, joint)
    height = chisel * 0.8 + grain * 0.12
    rough = 0.75 + grain * 0.2
    return result(color, height, rough, 2.0)


def asphalt(seed, base, wet_all=0.0):
    """Road asphalt. wet_all: rain-soaked (Tokyo): darker all over and glossy, the low patches
    holding water (near-mirror, smooth)."""
    r = rng(seed)
    big = fbm(r, 2.8, 1, 12)
    grit = fbm(r, 0.5, 200, 512)
    mid = fbm(r, 2.0, 4, 100)
    speck = (grit > 0.78).astype(float)
    color = tint(base, 0.8 + mid * 0.25 + speck * 0.35 - big * 0.1)
    wet = smoothstep(0.8, 0.86, big) * 0.6  # a few damp patches: a little darker and glossier
    color = color * (1 - wet * 0.15)[..., None]
    cracks = 1 - smoothstep(0.0, 0.01, np.abs(fbm(r, 2.2, 3, 60) - 0.5))
    color = color * (1 - cracks * 0.4)[..., None]
    height = grit * 0.5 + mid * 0.2 - cracks * 0.5 - wet * 0.2
    rough = np.clip(0.8 - wet * 0.5 + grit * 0.08, 0.1, 1)
    if wet_all:
        pool = smoothstep(0.62, 0.74, big) * wet_all
        color = color * (1 - 0.3 * wet_all - pool[..., None] * 0.18)
        height = height * (1 - pool * 0.85)
        rough = np.clip(0.44 - pool * 0.36 + grit * 0.1 - wet * 0.1, 0.05, 1)
    return result(color, height, rough, 1.4)


def pavers(seed, base, joint_color, cols=4, rows=4, offset=0.0, wet_all=0.0):
    """Paving slabs. wet_all: rain-soaked (Tokyo): darker, glossy, water standing in the joints
    and in the odd dip."""
    r = rng(seed)
    col, row, cu, cv = grid(cols, rows, offset)
    aspect = (N / cols) / (N / rows)
    d = edge_distance(cu, cv, aspect)
    joint = 1 - smoothstep(0.01, 0.025, d)
    bevel = smoothstep(0.01, 0.06, d)
    tone = cell_random(col, row, seed, 64, 64)
    grit = fbm(r, 0.8, 100, 512)
    stain = fbm(r, 2.6, 1, 16)
    wet = smoothstep(0.82, 0.88, stain) * 0.5
    color = tint(base, 0.9 + tone * 0.16 + grit * 0.1 - stain * 0.04)
    color = mix(color, joint_color, joint)
    color = color * (1 - wet * 0.12)[..., None]
    height = bevel * 0.8 + grit * 0.1
    rough = np.clip(0.8 - wet * 0.4 + grit * 0.1, 0.1, 1)
    if wet_all:
        dip = smoothstep(0.66, 0.78, stain) * wet_all
        color = color * (1 - 0.26 * wet_all - dip[..., None] * 0.14 - joint[..., None] * 0.1 * wet_all)
        rough = np.clip(0.4 - dip * 0.3 - joint * 0.25 * wet_all + grit * 0.1, 0.05, 1)
    return result(color, height, rough, 2.2)


def grass(seed, base, dry):
    r = rng(seed)
    blades = fbm(r, 0.6, 150, 512, aniso=(1.0, 0.35))
    clumps = fbm(r, 2.2, 3, 64)
    patches = fbm(r, 2.8, 1, 10)
    color = mix(base, dry, np.clip(patches * 0.6 - 0.1, 0, 1))
    color = color * (0.6 + blades * 0.55 + clumps * 0.25)[..., None]
    height = blades * 0.7 + clumps * 0.3
    rough = 0.85 + blades * 0.1
    return result(color, height, rough, 1.2)


def slate(seed, base, rows=10, cols=5):
    r = rng(seed)
    col, row, cu, cv = grid(cols, rows, 0.5)
    tone = cell_random(col, row, seed, 64, 64)
    lap = cv  # each row overlaps the one below: thick at the bottom edge
    gap = 1 - smoothstep(0.0, 0.03, np.minimum(cu, 1 - cu))
    grain = fbm(r, 1.6, 10, 300)
    color = tint(base, 0.8 + tone * 0.3 + grain * 0.1)
    color = color * (1 - gap * 0.6)[..., None] * (0.75 + lap * 0.25)[..., None]
    height = (1 - lap) * 0.6 - gap * 0.4 + grain * 0.05
    rough = 0.55 + grain * 0.2
    return result(color, height, rough, 2.5)


def facade_tiles(seed, base, cols=16, rows=32):
    r = rng(seed)
    col, row, cu, cv = grid(cols, rows, 0.5)
    aspect = (N / cols) / (N / rows)
    d = edge_distance(cu, cv, aspect)
    joint = 1 - smoothstep(0.04, 0.08, d)
    tone = cell_random(col, row, seed, 128, 128)
    grime = fbm(r, 2.2, 1, 30, aniso=(3.0, 0.3))
    color = tint(base, 0.9 + tone * 0.12)
    color = mix(color, np.asarray(base) * 0.6, joint)
    color = color * (1 - np.clip(grime - 0.45, 0, 1) * 0.9)[..., None]
    height = (1 - joint) * 0.8
    rough = 0.3 + joint * 0.5 + grime * 0.2
    return result(color, height, rough, 2.0)


def ceiling(seed, base, cols=4):
    r = rng(seed)
    col, row, cu, cv = grid(cols, cols)
    d = edge_distance(cu, cv)
    frame = 1 - smoothstep(0.012, 0.02, d)
    pits = fbm(r, 0.5, 150, 512)
    color = tint(base, 0.92 + pits * 0.08 - (pits > 0.75) * 0.15)
    color = mix(color, np.asarray(base) * 0.55, frame)
    height = (1 - frame) * 0.6 - (pits > 0.75) * 0.2
    rough = np.full((N, N), 0.9)
    return result(color, height, rough, 1.5)


def metal_plate(seed, base, tiles=4):
    """Raised access-floor plates with perforated centres (server rooms)."""
    r = rng(seed)
    col, row, cu, cv = grid(tiles, tiles)
    d = edge_distance(cu, cv)
    edge = 1 - smoothstep(0.01, 0.025, d)
    v, u = np.mgrid[0:N, 0:N] / N
    holes = (np.sin(u * math.pi * 2 * tiles * 14) * np.sin(v * math.pi * 2 * tiles * 14) > 0.7) * (d > 0.12)
    scratches = fbm(r, 1.5, 20, 400, aniso=(3.0, 0.2))
    color = tint(base, 0.85 + scratches * 0.25 - holes * 0.5)
    color = color * (1 - edge * 0.5)[..., None]
    height = 1 - edge * 0.8 - holes * 0.4
    rough = 0.4 + scratches * 0.3
    return result(color, height, rough, 2.0)


def corrugated(seed, base, ribs=24):
    """Ribbed metal: roller shutters and sheds."""
    r = rng(seed)
    v, u = np.mgrid[0:N, 0:N] / N
    wave = np.sin(v * math.pi * 2 * ribs) * 0.5 + 0.5
    rust = fbm(r, 2.4, 2, 50)
    color = tint(base, 0.75 + wave * 0.3)
    color = mix(color, np.array([0.3, 0.17, 0.1]), np.clip(rust - 0.6, 0, 1) * 1.5)
    height = wave
    rough = 0.5 + rust * 0.3
    return result(color, height, rough, 3.0)


def leaves(seed, base):
    """Hedges: dense leaves."""
    r = rng(seed)
    leaf = fbm(r, 1.0, 40, 200)
    clump = fbm(r, 2.0, 4, 50)
    color = tint(base, 0.45 + leaf * 0.7 + clump * 0.3)
    height = leaf * 0.8 + clump * 0.4
    rough = np.full((N, N), 0.8)
    return result(color, height, rough, 2.5)


def dirt(seed, base):
    r = rng(seed)
    clods = fbm(r, 1.4, 20, 300)
    big = fbm(r, 2.4, 2, 30)
    color = tint(base, 0.7 + clods * 0.4 + big * 0.2)
    height = clods * 0.8
    rough = np.full((N, N), 0.95)
    return result(color, height, rough, 2.0)


def snow(seed, base, shadow):
    """Fresh snow lying on the ground or a roof: soft drifts and ripples, a faint blue in the
    hollows, a sparkle of grains."""
    r = rng(seed)
    drift = fbm(r, 3.0, 1, 12)
    ripple = fbm(r, 1.8, 8, 120)
    grain = fbm(r, 0.4, 200, 512)
    sparkle = (grain > 0.86).astype(float)
    shade = np.clip(drift * 0.6 + ripple * 0.4, 0, 1)
    color = mix(shadow, base, 0.55 + shade * 0.45)
    color = color * (0.95 + grain * 0.05 + sparkle * 0.05)[..., None]
    height = drift * 0.6 + ripple * 0.5 + grain * 0.1
    rough = np.clip(0.8 - sparkle * 0.45, 0.1, 1)
    return result(color, height, rough, 1.2)


def slush(seed, base, joint_color, snow_color, cols=6, rows=6):
    """A shovelled path: wet pavers, trodden slush in the joints, packed snow in patches."""
    r = rng(seed)
    col, row, cu, cv = grid(cols, rows, 0.5)
    aspect = (N / cols) / (N / rows)
    d = edge_distance(cu, cv, aspect)
    joint = 1 - smoothstep(0.01, 0.035, d)
    tone = cell_random(col, row, seed, 64, 64)
    grit = fbm(r, 0.8, 100, 512)
    patches = fbm(r, 2.6, 2, 24)
    packed = smoothstep(0.58, 0.72, patches)
    wet = smoothstep(0.3, 0.1, patches) * 0.8
    color = tint(base, 0.85 + tone * 0.18 + grit * 0.1)
    color = mix(color, joint_color, joint * 0.6)
    color = mix(color, snow_color, np.clip(packed + joint * 0.35, 0, 1) * 0.85)
    color = color * (1 - wet * 0.22)[..., None]
    height = smoothstep(0.01, 0.06, d) * 0.6 + packed * 0.4 + grit * 0.1
    rough = np.clip(0.8 - wet * 0.6 + packed * 0.05, 0.08, 1)
    return result(color, height, rough, 1.8)


def ice(seed, base, frost, snow_color):
    """A frozen pond: dark ice with pale cracks and frost, snow blown into drifts on it."""
    r = rng(seed)
    cracks = 1 - smoothstep(0.0, 0.012, np.abs(fbm(r, 2.0, 2, 40) - 0.5))
    fine = 1 - smoothstep(0.0, 0.01, np.abs(fbm(r, 1.6, 10, 120) - 0.5))
    cloud = fbm(r, 2.6, 1, 16)
    drifts = smoothstep(0.62, 0.78, fbm(r, 2.8, 1, 10))
    color = mix(base, frost, np.clip(cloud * 0.5 + cracks * 0.8 + fine * 0.35, 0, 1))
    color = mix(color, snow_color, drifts)
    height = drifts * 0.6 - cracks * 0.3
    rough = np.clip(0.12 + drifts * 0.7 + cloud * 0.1, 0.05, 1)
    return result(color, height, rough, 1.0)


def srgb(r, g, b):
    return np.array([r, g, b]) / 255.0


# name -> (generator, studs covered by one repeat of the image)
LIBRARY = {
    "MarbleBlack": (lambda: marble(11, srgb(28, 27, 30), srgb(176, 150, 96), srgb(70, 66, 70)), 16),
    "MarbleWhite": (lambda: marble(12, srgb(206, 202, 194), srgb(120, 118, 120), srgb(170, 168, 165)), 12),
    "MarbleColumn": (lambda: marble(41, srgb(200, 196, 188), srgb(110, 106, 104), srgb(165, 162, 158), 1, False), 10),
    "WoodFloor": (lambda: planks(13, srgb(118, 80, 52), srgb(52, 32, 20)), 8),
    "WoodFloorDark": (lambda: planks(14, srgb(70, 46, 32), srgb(26, 16, 12)), 8),
    "CarpetGrey": (lambda: carpet(15, srgb(58, 62, 72)), 12),
    "CarpetRed": (lambda: carpet(16, srgb(92, 16, 22), srgb(150, 112, 60), pattern="diamond"), 16),
    "TileWhite": (lambda: ceramic(17, srgb(214, 216, 216), srgb(120, 122, 124), 8), 4),
    "TileChecker": (lambda: ceramic(18, srgb(220, 218, 212), srgb(60, 60, 62), 8, checker=srgb(34, 34, 38)), 8),
    "TileMetro": (lambda: ceramic(19, srgb(206, 208, 204), srgb(90, 92, 92), 8, 16, 0.5), 4),
    "Concrete": (lambda: concrete(20, srgb(112, 112, 114), seams=4), 16),
    "ConcreteDark": (lambda: concrete(21, srgb(62, 62, 66), seams=4), 16),
    "PlasterDark": (lambda: plaster(22, srgb(46, 50, 56)), 12),
    "PlasterLight": (lambda: plaster(23, srgb(150, 144, 132)), 12),
    "PlasterGrey": (lambda: plaster(42, srgb(104, 110, 120)), 12),
    "Wallpaper": (lambda: plaster(24, srgb(54, 18, 24), True, srgb(150, 118, 70), 16), 8),
    "WoodPanel": (lambda: panels(25, srgb(92, 58, 36), srgb(40, 24, 16)), 8),
    "BrickRed": (lambda: bricks(26, srgb(128, 58, 44), srgb(150, 144, 134), soot=0.5), 6),
    "BrickDark": (lambda: bricks(27, srgb(70, 48, 44), srgb(96, 92, 88), soot=0.6), 6),
    "Stone": (lambda: ashlar(28, srgb(150, 144, 130), srgb(92, 88, 80)), 8),
    "Asphalt": (lambda: asphalt(29, srgb(44, 44, 48)), 16),
    "Pavers": (lambda: pavers(30, srgb(104, 104, 108), srgb(52, 52, 56), 4, 4), 8),
    "PaversWarm": (lambda: pavers(31, srgb(120, 106, 92), srgb(62, 56, 50), 6, 6, 0.5), 8),
    # Tokyo in the rain: the same surfaces soaked (darker, glossy, water in the dips and joints).
    "AsphaltWet": (lambda: asphalt(29, srgb(44, 44, 48), wet_all=1.0), 16),
    "PaversWet": (lambda: pavers(30, srgb(104, 104, 108), srgb(52, 52, 56), 4, 4, wet_all=1.0), 8),
    "PaversWarmWet": (lambda: pavers(31, srgb(120, 106, 92), srgb(62, 56, 50), 6, 6, 0.5, wet_all=1.0), 8),
    "Grass": (lambda: grass(32, srgb(46, 76, 38), srgb(92, 88, 52)), 16),
    "Slate": (lambda: slate(33, srgb(46, 48, 54)), 8),
    "FacadeTile": (lambda: facade_tiles(34, srgb(150, 140, 124)), 8),
    "FacadeTileGrey": (lambda: facade_tiles(35, srgb(104, 108, 114)), 8),
    "Ceiling": (lambda: ceiling(36, srgb(176, 176, 172)), 8),
    "MetalFloor": (lambda: metal_plate(37, srgb(96, 98, 104)), 8),
    "Shutter": (lambda: corrugated(38, srgb(150, 152, 154)), 6),
    "Hedge": (lambda: leaves(39, srgb(40, 70, 36)), 6),
    "Dirt": (lambda: dirt(40, srgb(70, 54, 40)), 8),
    # The metro's own surfaces: grey tile and a darker ceiling, so the platform is not a white box.
    "TileMetroFloor": (lambda: ceramic(43, srgb(118, 120, 124), srgb(66, 68, 72), 8), 4),
    "TileMetroGrey": (lambda: ceramic(44, srgb(150, 154, 156), srgb(76, 78, 80), 8, 16, 0.5), 4),
    "CeilingDark": (lambda: ceiling(45, srgb(92, 94, 98)), 8),
    "CarpetNavy": (lambda: carpet(46, srgb(34, 40, 56), srgb(62, 70, 92), pattern="diamond"), 12),
    # Kagegaoka University in snow: the lawns and roofs, the shovelled paths, the frozen pond.
    "Snow": (lambda: snow(47, srgb(222, 228, 238), srgb(168, 180, 204)), 24),
    "SnowPath": (lambda: slush(48, srgb(88, 86, 84), srgb(40, 40, 42), srgb(196, 200, 208)), 8),
    "Ice": (lambda: ice(49, srgb(34, 48, 60), srgb(140, 166, 186), srgb(210, 218, 230)), 24),
}
