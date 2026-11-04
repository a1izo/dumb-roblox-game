"""Night facades for the city beyond the maps: one repeat is two window bays (6 studs each) by one floor (12 studs),
drawn over a photographed scan (scanlib) so the wall keeps its real grain. The windows are cut into it: glass set
back in its reveal, frames, mullions, sills and lintels, balcony slabs, the rain streaks under a sill, and in the
normal map the depth of every opening. Unlit, a window is dark glass with a little of the sky in it, some with
blinds or a curtain behind; the lit ones are the game's own glow, laid over the same openings
(skyline.WINDOWS gives where each style's glass is).

Arrays are [v, u] with v = 0 at the bottom (scanlib's convention). One repeat: u over 12 studs, v over 12 studs;
a floor's slab line is at v = 0.
"""

import numpy as np

TILE = 12.0  # studs one repeat covers, both ways
BAY = 6.0  # studs a window bay takes in the repeat (the walls stretch it to fit their own length)

# style -> how its wall is made and where its openings are, in studs within a 6-stud bay and a 12-stud floor.
# glass: (u0, u1, y0, y1) of the glass; frame: the frame's width round it; bars: [("v"|"h", at)] glazing bars;
# reveal: how deep the glass sits.
STYLES = {
    # A post-war office slab: long windows nearly bay to bay, thin aluminium, dark spandrel panels.
    "NightOffice": dict(scan=("concrete_tile_facade", (78, 82, 90), 2), glass=(0.3, 5.7, 2.4, 9.8), frame=0.1,
                        frame_rgb=(46, 48, 54), bars=[("h", 8.6)], reveal=0.25, spandrel=(30, 33, 38)),
    # Flats: punched windows with a pale frame, a balcony slab and railing along every floor.
    "NightFlats": dict(scan=("beige_wall_001", (116, 112, 104), 1), glass=(1.0, 5.0, 3.6, 9.0), frame=0.16,
                       frame_rgb=(150, 150, 144), bars=[("v", 3.0)], reveal=0.35, balcony=True),
    # Old brick: tall windows with stone sills and lintels, a cross of glazing bars.
    "NightBrick": dict(scan=("red_brick_03", (78, 52, 46), 4), glass=(1.5, 4.5, 3.6, 9.2), frame=0.14,
                       frame_rgb=(40, 36, 34), bars=[("v", 3.0), ("h", 7.0)], reveal=0.45, sill=(150, 144, 132)),
    # Tiled cladding: square windows, dark frames, one mullion.
    "NightTile": dict(scan=("exterior_wall_cladding_02", (132, 124, 112), 2), glass=(1.2, 4.8, 3.6, 8.8), frame=0.12,
                      frame_rgb=(44, 44, 46), bars=[("v", 3.0)], reveal=0.35),
}


def _lin(rgb):
    c = np.asarray(rgb, dtype=np.float32) / 255.0
    return np.where(c <= 0.04045, c / 12.92, np.power((c + 0.055) / 1.055, 2.4))


def _rect(uu, vv, u0, u1, y0, y1):
    return (uu >= u0) & (uu < u1) & (vv >= y0) & (vv < y1)


def _blur(arr, r):
    """A box blur r pixels each way that wraps at the edges (the repeat tiles)."""
    out = arr.copy()
    for axis in (0, 1):
        acc = np.zeros_like(out)
        for k in range(-r, r + 1):
            acc += np.roll(out, k, axis=axis)
        out = acc / (2 * r + 1)
    return out


def make(name, scale=1):
    """The colour (sRGB), normal and roughness maps of a style, in scanlib's form."""
    from maps import scanlib

    style = STYLES[name]
    scan, colour, n = style["scan"]
    seed = sum(map(ord, name))
    base = scanlib.surface(scan, colour, TILE, "ground", n, organic=(n == 1), keep=0.5, seed=seed)[0](scale)
    color = base["color"].astype(np.float32)
    size = color.shape[0]
    normal = base["normal"].astype(np.float32)
    if normal.shape[0] != size:
        normal = normal.repeat(size // normal.shape[0], 0).repeat(size // normal.shape[1], 1)
    normal = normal * 2 - 1
    rough = base["rough"].astype(np.float32)
    rough = rough.repeat(size // rough.shape[0], 0).repeat(size // rough.shape[1], 1)
    px = size / TILE
    vv, uu = np.mgrid[0:size, 0:size].astype(np.float32) / px
    bu = uu % BAY  # the place in its bay
    bay_b = uu >= BAY  # the second bay of the repeat
    rng = np.random.default_rng(seed)
    lin = scanlib.to_linear(color)
    height = np.zeros((size, size), dtype=np.float32)
    flat = np.zeros((size, size), dtype=bool)  # where the scan's own relief is replaced

    g0, g1, y0, y1 = style["glass"]
    fw = style["frame"]
    if style.get("spandrel"):
        # The office's panels between its bands of glass: smooth dark enamel over the scan's grain.
        band = ~_rect(bu, vv, g0 - fw - 0.05, g1 + fw + 0.05, y0 - fw - 0.05, y1 + fw + 0.05)
        lin = np.where(band[..., None], lin * 0.35 + _lin(style["spandrel"]) * 0.65, lin)
        rough = np.where(band, rough * 0.5 + 0.18, rough)
        # Thin joints between the panels: at every floor line and between bays.
        joint = (np.abs(vv - 0.0) < 0.05) | (np.abs(vv - TILE) < 0.05) | (np.abs(bu) < 0.04) | (np.abs(bu - BAY) < 0.04)
        height = np.where(band & joint, -0.04, height)
    if style.get("balcony"):
        # A slab along the floor, its edge lit a little lighter, and a railing over it (bars and a top rail).
        slab = (vv < 0.7)
        lin = np.where(slab[..., None], lin * 0.5 + _lin((120, 118, 112)) * 0.5, lin)
        height = np.where(slab, 0.2, height)
        rail = (vv >= 0.7) & (vv < 3.2)
        bars = rail & ((uu % 0.5) < 0.06)
        top = (vv >= 3.0) & (vv < 3.2)
        metal = bars | top
        lin = np.where(metal[..., None], _lin((36, 38, 42)), lin)
        height = np.where(metal, 0.3, height)
        flat |= metal
        # The shadow the slab casts down the wall below it (the top of the floor under).
        shade = scanlib.smoothstep(TILE - 1.4, TILE, vv)
        lin = lin * (1 - 0.35 * shade[..., None])

    opening = _rect(bu, vv, g0 - fw, g1 + fw, y0 - fw, y1 + fw)
    glass = _rect(bu, vv, g0, g1, y0, y1)
    frame = opening & ~glass
    bar = np.zeros_like(glass)
    for kind, at in style["bars"]:
        bar |= glass & ((np.abs(bu - at) < 0.06) if kind == "v" else (np.abs(vv - at) < 0.06))
    reveal = style["reveal"]
    height = np.where(opening, -reveal * 0.4, height)
    height = np.where(glass, -reveal, height)
    height = np.where(bar, -reveal * 0.7, height)
    flat |= opening

    # Glass at night: near black, a breath of sky toward the top; behind it blinds (the first bay of the
    # repeat, half down), a curtain or nothing (seen as dark room).
    t = np.clip((vv - y0) / max(0.01, y1 - y0), 0, 1)
    pane = _lin((14, 16, 22)) * (1 - t[..., None]) + _lin((34, 40, 52)) * t[..., None]
    blinds = glass & ~bay_b & (vv > (y0 + y1) / 2) & ((vv * 4.0) % 1.0 < 0.55)
    pane = np.where(blinds[..., None], _lin((54, 54, 56)), pane)
    if style.get("balcony") or name == "NightBrick":
        curtain = glass & bay_b & ((bu < g0 + 0.9) | (bu > g1 - 0.9))
        fold = 0.85 + 0.15 * np.sin(uu * 9.0)
        pane = np.where(curtain[..., None], _lin((66, 56, 50)) * fold[..., None], pane)
    # The reveal's shade: dark under the head and down one side of the opening.
    head = scanlib.smoothstep(y1 - 0.9, y1, vv) * glass
    side = scanlib.smoothstep(g0 + 0.6, g0, bu) * glass
    pane = pane * (1 - 0.5 * np.maximum(head, side)[..., None])
    lin = np.where(glass[..., None], pane, lin)
    lin = np.where((frame | bar)[..., None], _lin(style["frame_rgb"]), lin)
    rough = np.where(glass, 0.06, rough)
    rough = np.where(frame | bar, 0.32, rough)

    if style.get("sill"):
        sill = _rect(bu, vv, g0 - fw - 0.25, g1 + fw + 0.25, y0 - fw - 0.45, y0 - fw)
        lintel = _rect(bu, vv, g0 - fw - 0.15, g1 + fw + 0.15, y1 + fw, y1 + fw + 0.6)
        stone = sill | lintel
        grain = color @ scanlib.LUMA
        lin = np.where(stone[..., None], _lin(style["sill"]) * (0.8 + 0.4 * grain[..., None]), lin)
        height = np.where(sill, 0.2, np.where(lintel, 0.08, height))
        rough = np.where(stone, 0.7, rough)
        flat |= stone

    # Rain streaks down from each sill's ends: a darker run on the wall below, fading out.
    for bay in (0.0, BAY):
        for end in (g0 - fw, g1 + fw):
            x = bay + end + rng.uniform(-0.2, 0.2)
            reach = rng.uniform(1.6, 3.2)
            width = rng.uniform(0.15, 0.35)
            streak = (np.abs(uu - x) < width) & (vv < y0 - fw) & (vv > y0 - fw - reach)
            fade = np.clip((vv - (y0 - fw - reach)) / reach, 0, 1)
            lin = np.where((streak & ~flat)[..., None], lin * (1 - 0.25 * fade[..., None]), lin)

    # The relief of the openings, from the height drawn above, over the scan's own (kept on the wall).
    h = _blur(height, max(1, int(px * 0.04)))
    du = (np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)) * 0.5 * px
    dv = (np.roll(h, -1, axis=0) - np.roll(h, 1, axis=0)) * 0.5 * px
    tilt = np.stack([-du, -dv, np.ones_like(du)], axis=-1)
    tilt = tilt / np.linalg.norm(tilt, axis=-1, keepdims=True)
    keep = np.where(flat[..., None], 0.15, 1.0)
    nrm = normal * keep + np.stack([tilt[..., 0], tilt[..., 1], np.zeros_like(du)], axis=-1)
    nrm[..., 2] = np.where(flat, tilt[..., 2], normal[..., 2])
    nrm = nrm / np.linalg.norm(nrm, axis=-1, keepdims=True)

    return {
        "color": np.clip(scanlib.to_srgb(lin), 0, 1),
        "normal": np.clip(nrm * 0.5 + 0.5, 0, 1),
        "rough": np.clip(scanlib.half(rough), 0.03, 1),
    }


def surface(name):
    """A scanlib.LIBRARY entry for a style."""
    return (lambda scale=1: make(name, scale)), TILE
