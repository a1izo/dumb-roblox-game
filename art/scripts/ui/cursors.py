"""The game's two pointers (UI/Cursor) and the red pointing hand (UI/Kit/Pointer), drawn with numpy:

    CursorLock    64 x 64  the closed-eyes mark the user drew (art/refs/ui/cursor_lashes.png), traced from it, white
                           with a black outline: the pointer locked in the middle of the screen in a case's free roam
                           (World/ShoulderCam)
    CursorFree    64 x 64  a fountain pen's nib on the black of its grip, its point on the middle pixel: the pointer
                           everywhere else. Redrawn 2026-11-03 at the user's word ("sharper and more professional"):
                           a longer nib with its shoulders, a lit and a shaded half, the slit and the breather hole cut
                           clean, a steel ring and the grip behind it, a thin outline and a soft drop shadow
    PointerHand  192 x 192 the hand that points at whatever is chosen (OMORI's, in the game's red, lines in its blood
                           red, never black): a right hand, its
                           index finger alone held out (the user's word of 2026-11-03: "pointing with a single finger"),
                           the thumb laid along it, the other three curled under, a white cuff; four cells, pointing
                           right, left, down and up (the fingertip at 92, 48 of a 96 px cell pointing right)

Roblox centres a custom pointer on the mouse, so each one's hot spot is the middle of its picture (the gap between
the two lashes; the nib's point). Also writes previews, art/export/previews/cursors.png (each pointer on dark and on
light, actual size and four times) and pointer_hand.png.

    "C:/Program Files/Blender Foundation/Blender 5.2/5.2/python/bin/python.exe" art/scripts/ui/cursors.py
"""

import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import flow  # noqa: E402
import paint as pt  # noqa: E402
import png  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
REF = os.path.join(ROOT, "art", "refs", "ui", "cursor_lashes.png")
OUT = os.path.join(ROOT, "art", "export", "textures")
PREVIEW = os.path.join(ROOT, "art", "export", "previews", "cursors.png")
PREVIEW_HAND = os.path.join(ROOT, "art", "export", "previews", "pointer_hand.png")

SIZE = 64
SS = 8  # drawn at eight times the size, then averaged down
LASH_WIDTH = 54  # the mark's width on screen, px
THICKEN = 0.9  # the mark's strokes made this much bolder, px (thin strokes vanished under the outline)
OUTLINE = 1.4  # the black outline, px
OUTLINE_NIB = 1.0  # the nib's outline, px (thin, so it stays sharp)
WHITE = np.array([0.97, 0.97, 0.97], np.float32)
BONE = np.array([0.93, 0.91, 0.86], np.float32)
BLACK = np.array([0.02, 0.02, 0.025], np.float32)


def down(a):
    """Averages a supersampled (SIZE * SS) array down to SIZE."""
    shape = (SIZE, SS, SIZE, SS) + a.shape[2:]
    return a.reshape(shape).mean(axis=(1, 3))


def outlined(fill_ss):
    """A shape (supersampled coverage) as RGBA: white inside a black outline."""
    hard = (fill_ss > 0.5).astype(np.float32)
    ring = flow.grow(hard, int(round(OUTLINE * SS)))
    fill = down(hard)
    alpha = down(ring)
    rgb = WHITE[None, None] * fill[..., None] + BLACK[None, None] * (1 - fill[..., None])
    return np.concatenate([rgb, alpha[..., None]], -1).astype(np.float32)


def lashes():
    """The user's mark, traced: its dark shapes, scaled to LASH_WIDTH and centred on the middle pixel."""
    grey = png.read(REF)[..., 0].astype(np.float32) / 255.0
    ink = grey < 0.5
    ys, xs = np.nonzero(ink)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    crop = (grey[y0:y1, x0:x1] < 0.5).astype(np.float32)
    h, w = crop.shape
    width = LASH_WIDTH * SS
    height = int(round(h * width / w))
    shape = flow.resample(crop, height, width)
    canvas = np.zeros((SIZE * SS, SIZE * SS), np.float32)
    top = (SIZE * SS - height) // 2
    left = (SIZE * SS - width) // 2
    canvas[top:top + height, left:left + width] = shape
    return outlined(flow.grow((canvas > 0.5).astype(np.float32), int(round(THICKEN * SS))))


def _stamp(points, scale):
    """A polygon given in final px, filled on the supersampled canvas."""
    return pt.fill([(x * scale, y * scale) for x, y in points], SIZE * scale, SIZE * scale)


def nib():
    """A fountain pen's nib, its point on the middle pixel, slanting down to the right (as an arrow does), on the black
    grip of the pen: the shoulders, a lit half and a shaded one, the slit down from the point to the breather hole, a
    line engraved across the shoulders, a steel ring where it meets the grip; a thin black outline round it all and a
    soft shadow under it."""
    centre = SIZE / 2
    axis = np.array([math.cos(math.radians(50)), math.sin(math.radians(50))])  # from the point to the back
    side = np.array([-axis[1], axis[0]])

    def at(u, v):
        p = np.array([centre, centre]) + axis * u + side * v
        return (float(p[0]), float(p[1]))

    def body(us, half):
        left = [at(u, -hw) for u, hw in zip(us, half)]
        right = [at(u, hw) for u, hw in zip(us, half)]
        return left + right[::-1]

    # half widths along the nib (px from the point): fine at the point, full at the shoulders, a little in to the ring
    us = np.linspace(0, 24.2, 60)
    half = np.interp(us, [0, 0.7, 2.5, 7, 11, 15, 18.5, 21.5, 24.2], [0.25, 0.65, 1.55, 3.6, 5.2, 6.4, 6.9, 6.7, 6.4])
    nib_shape = _stamp(body(us, half), SS)
    ring = _stamp(body([24.0, 25.6], [6.5, 6.5]), SS)
    # the grip: straight, its end rounded
    grip_pts = [at(25.4, -5.7), at(31.2, -5.7)]
    grip_pts += [at(31.2 + 5.7 * math.sin(a), -5.7 * math.cos(a)) for a in np.linspace(0, math.pi, 13)]
    grip_pts += [at(25.4, 5.7)]
    grip = _stamp(grip_pts, SS)
    solid = np.clip(nib_shape + ring + grip, 0, 1)
    hard = (solid > 0.5).astype(np.float32)
    ring_out = flow.grow(hard, int(round(OUTLINE_NIB * SS)))

    n = SIZE * SS
    ys, xs = np.mgrid[0:n, 0:n].astype(np.float32)
    ys, xs = (ys + 0.5) / SS, (xs + 0.5) / SS
    rel_u = (xs - centre) * axis[0] + (ys - centre) * axis[1]
    rel_v = (xs - centre) * side[0] + (ys - centre) * side[1]
    # the nib: the lit half (toward the light, top right) and the shaded half, a soft turn between them along the slit
    turn = pt.smoothstep(-0.6, 0.9, rel_v)
    lit = BONE[None, None] * (1.0 - 0.06 * pt.smoothstep(4, 22, rel_u))[..., None]
    shade = BONE[None, None] * 0.74
    rgb = lit * (1 - turn[..., None]) + shade * turn[..., None]
    # (a bright edge along the lit side)
    edge = pt.smoothstep(1.6, 0.2, np.abs(rel_v + np.interp(rel_u, us, half) - 0.9)) * (rel_v < 0) * (rel_u > 2)
    rgb = rgb + edge[..., None] * 0.05
    slit = pt.fill([(x * SS, y * SS) for x, y in pt.outline([at(0.9, 0), at(12.4, 0)], [0.8, 0.8])], n, n)
    hole = pt.ellipse(*[c * SS for c in at(13.7, 0)], 1.55 * SS, 1.55 * SS, n, n)
    arc = [at(19.6 - 2.2 * (1 - (v / 5.4) ** 2), v) for v in np.linspace(-5.4, 5.4, 15)]
    engraved = pt.fill([(x * SS, y * SS) for x, y in pt.outline(arc, [0.55] * 15)], n, n)
    marks = np.clip(slit + hole, 0, 1)
    rgb = rgb * (1 - marks[..., None]) + BLACK[None, None] * marks[..., None]
    rgb = rgb * (1 - 0.45 * engraved[..., None])
    # the steel ring and the grip
    in_ring = ring * (1 - nib_shape)
    steel = np.array([0.62, 0.62, 0.64], np.float32)[None, None] * (1.0 - 0.25 * turn)[..., None]
    rgb = rgb * (1 - in_ring[..., None]) + steel * in_ring[..., None]
    in_grip = grip * (1 - np.clip(nib_shape + ring, 0, 1))
    black_grip = np.array([0.07, 0.07, 0.08], np.float32)[None, None] * np.ones((n, n, 1), np.float32)
    shine = pt.smoothstep(1.4, 0.0, np.abs(rel_v + 2.8)) * (rel_u > 26.5) * (rel_u < 32.5)
    black_grip = black_grip + shine[..., None] * 0.28
    rgb = rgb * (1 - in_grip[..., None]) + black_grip * in_grip[..., None]
    rgb = rgb * hard[..., None] + BLACK[None, None] * (1 - hard[..., None])
    alpha = down(ring_out)
    colour = down(rgb * ring_out[..., None]) / np.maximum(alpha, 1e-6)[..., None]
    # the soft shadow under it (down and to the right), where the pen itself is not
    shadow = pt.blur(alpha, 1.1)
    moved = np.zeros_like(shadow)
    moved[2:, 1:] = shadow[:-2, :-1]  # (shifted, not rolled: nothing wraps round to the other edge)
    shadow = moved * 0.38
    out_alpha = alpha + shadow * (1 - alpha)
    out_rgb = colour * (alpha / np.maximum(out_alpha, 1e-6))[..., None]
    return np.concatenate([np.clip(out_rgb, 0, 1), out_alpha[..., None]], -1).astype(np.float32)


HAND_CELL = 96  # one cell of the PointerHand sheet, px
HAND_SS = 6
HAND_OUTLINE = 2.0  # the line round each piece, px at the cell's size (the hand shows at half: about 1.1 px)
HAND_OUTLINE_HEAVY = 2.7  # where the hand-drawn line presses harder
# The game's one red (UI/Kit/Tokens red 210, 30, 30) and its blood (120, 14, 16) for the lines: no black anywhere.
RED = np.array([210, 30, 30], np.float32) / 255
RED_SHADE = np.array([158, 18, 24], np.float32) / 255
RED_DEEP = np.array([128, 12, 18], np.float32) / 255
LINE = np.array([80, 6, 12], np.float32) / 255  # a maroon, the red at its darkest
HIGHLIGHT = np.array([255, 236, 228], np.float32) / 255
CUFF = np.array([236, 232, 224], np.float32) / 255
CUFF_SHADE = np.array([200, 190, 182], np.float32) / 255


def _capsule(a, b, r, n, scale, r_end=None):
    """A capsule from a to b (final px), radius r (tapering to r_end at b), as coverage on the supersampled canvas."""
    ax, ay = a
    bx, by = b
    rb = r if r_end is None else r_end
    ang = math.atan2(by - ay, bx - ax)
    pts = []
    for t in np.linspace(math.pi / 2, 3 * math.pi / 2, 18):
        pts.append((ax + r * math.cos(ang + t), ay + r * math.sin(ang + t)))
    for t in np.linspace(-math.pi / 2, math.pi / 2, 18):
        pts.append((bx + rb * math.cos(ang + t), by + rb * math.sin(ang + t)))
    return pt.fill([(x * scale, y * scale) for x, y in pts], n, n)


def _rounded(x0, y0, x1, y1, r, n, scale):
    """A rounded rectangle (final px) as coverage on the supersampled canvas."""
    pts = []
    for cx, cy, a0 in ((x1 - r, y0 + r, -90), (x1 - r, y1 - r, 0), (x0 + r, y1 - r, 90), (x0 + r, y0 + r, 180)):
        for t in np.linspace(a0, a0 + 90, 8):
            pts.append((cx + r * math.cos(math.radians(t)), cy + r * math.sin(math.radians(t))))
    return pt.fill([(x * scale, y * scale) for x, y in pts], n, n)


def _poly(points, n, scale):
    return pt.fill([(x * scale, y * scale) for x, y in points], n, n)


def _line(points, width, n, scale, tip=None):
    """A line along `points` (final px), `width` wide, thinning to `tip` at both ends if given."""
    if tip is None:
        widths = [width] * len(points)
    else:
        m = len(points)
        widths = [tip + (width - tip) * max(0.0, math.sin(math.pi * k / (m - 1))) ** 0.6 for k in range(m)]
    return pt.fill([(x * scale, y * scale) for x, y in pt.outline(points, widths)], n, n)


def _arc(cx, cy, rx, ry, a0, a1, steps=12):
    """Points along an elliptical arc (final px), angles in degrees."""
    return [(cx + rx * math.cos(math.radians(a)), cy + ry * math.sin(math.radians(a))) for a in np.linspace(a0, a1, steps)]


def _moved(mask, dx, dy):
    """`mask` moved by (dx, dy) supersampled px, nothing wrapping round."""
    out = np.zeros_like(mask)
    h, w = mask.shape
    out[max(dy, 0): h + min(dy, 0), max(dx, 0): w + min(dx, 0)] = mask[max(-dy, 0): h + min(-dy, 0),
                                                                        max(-dx, 0): w + min(-dx, 0)]
    return out


def _warped(mask, amp, cell, seed):
    """`mask` pushed about by smooth noise (`amp` supersampled px, features about `cell` px): a hand-drawn wobble."""
    h, w = mask.shape
    dx = (pt.noise(h, w, cell, seed, octaves=1) - 0.5) * 2 * amp
    dy = (pt.noise(h, w, cell, seed + 1, octaves=1) - 0.5) * 2 * amp
    ys, xs = np.mgrid[0:h, 0:w]
    sy = np.clip(np.round(ys + dy).astype(int), 0, h - 1)
    sx = np.clip(np.round(xs + dx).astype(int), 0, w - 1)
    return mask[sy, sx]


def _cel(hard, lit, shade, depth, k):
    """A piece's flat cel shading: `lit` colour, a crisp `shade` crescent along its lower right (where the piece
    moved `depth` px toward the light from the top left no longer covers it). Returns the colours and the crescent."""
    toward = _moved(hard, int(round(-0.45 * depth * k)), int(round(-depth * k)))
    crescent = np.clip(hard - toward, 0, 1)
    col = np.empty(hard.shape + (3,), np.float32)
    col[:] = lit
    col = col * (1 - crescent[..., None]) + shade[None, None] * crescent[..., None]
    return col, crescent


def pointer_hand():
    """The pointing hand, pointing right, its index finger alone held out (the fingertip at 92, 48 of the cell), drawn
    like OMORI's: the game's red, flat and cel shaded, a hand-drawn line that wobbles and swells round every piece in
    the red's own blood (never black), crayon grain in the fill, a few hatched strokes in the shadows, white
    highlight strokes where the light catches, a white cuff (redrawn 2026-11-06 at the user's word: "make it red
    again, the black outlines are ugly", more OMORI-like). Built back to front: the cuff, the back of the hand, the
    three curled fingers, the index finger, the thumb along it."""
    n = HAND_CELL * HAND_SS
    k = HAND_SS
    pieces = [
        ("cuff", _poly([(8, 38.5), (21, 36.5), (24.5, 38), (24.5, 82), (21, 83.5), (8, 81.5), (6.5, 79), (6.5, 41)],
                       n, k)),
        ("fist", _poly([(22, 42), (32, 37.5), (46, 37.5), (58, 41), (63.5, 50), (64, 64), (61, 76), (52, 82.5),
                        (36, 83), (22, 80.5)], n, k)),
        ("curl3", _capsule((44, 76.5), (57.5, 76), 4.5, n, k, 4.2)),
        ("curl2", _capsule((46, 67.6), (61, 67.2), 4.9, n, k, 4.6)),
        ("curl1", _capsule((48, 58.8), (63.5, 58.6), 5.1, n, k, 4.8)),
        ("index", _capsule((50, 48.6), (86.6, 48), 5.6, n, k, 4.9)),
        ("thumb", _capsule((30, 42.2), (58, 43.4), 4.9, n, k, 4.3)),
    ]
    rgb = np.zeros((n, n, 3), np.float32)
    alpha = np.zeros((n, n), np.float32)
    ys, xs = pt.grid(n, n)
    # crayon grain: fine noise that lifts and sinks the fill a little
    grain = pt.noise(n, n, 1.6 * k, 71, octaves=1)
    # the pen's pressure along the line: where it is high the line swells
    pressure = pt.smoothstep(0.4, 0.7, pt.noise(n, n, 16 * k, 33, octaves=1))
    # hatching: short diagonal strokes, broken up so they read as drawn, not ruled
    period = 3.4 * k
    hatch = pt.smoothstep(0.62, 0.8, 0.5 + 0.5 * np.cos(2 * math.pi * (xs + ys * 0.9) / period))
    hatch *= pt.smoothstep(0.35, 0.5, pt.noise(n, n, 5 * k, 57, octaves=2))
    thin_r = int(round(HAND_OUTLINE * k))
    heavy_r = int(round(HAND_OUTLINE_HEAVY * k))
    for seed, (name, cover) in enumerate(pieces):
        hard = _warped((cover > 0.5).astype(np.float32), 0.25 * k, 16 * k, 100 + 7 * seed)
        # the line swells with the pen's pressure and sits heavier on the side away from the light (lower right)
        ring = flow.grow(hard, thin_r) * (1 - pressure) + flow.grow(hard, heavy_r) * pressure
        ring = np.maximum(ring, _moved(flow.grow(hard, thin_r), int(0.5 * k), int(0.9 * k)))
        pt.layer_over(rgb, alpha, LINE, ring)
        if name == "cuff":
            fill, _ = _cel(hard, CUFF, CUFF_SHADE, 3.0, k)
            pt.layer_over(rgb, alpha, fill, hard)
            seam = _line([(19.8, 40), (19.6, 60), (19.9, 80)], 0.8, n, k, tip=0.3)
            pt.layer_over(rgb, alpha, LINE, seam * hard * 0.8)
            button = pt.ellipse(13.5 * k, 46.5 * k, 1.6 * k, 1.6 * k, n, n) * hard
            pt.layer_over(rgb, alpha, RED, button)
            continue
        curled = name.startswith("curl")
        base = RED_SHADE * 0.3 + RED * 0.7 if curled else RED
        fill, crescent = _cel(hard, base, RED_DEEP if curled else RED_SHADE, 6.0 if name == "fist" else 2.6, k)
        fill = fill * (0.96 + 0.07 * grain[..., None])
        pt.layer_over(rgb, alpha, fill, hard)
        pt.layer_over(rgb, alpha, LINE, hatch * crescent * 0.75)
        if name == "index":
            # a long white catch of light along the finger's top, the nail in line, the two joint creases
            hi = _line([(53, 45.2), (62, 44.6), (72, 44.4), (80, 44.8)], 1.1, n, k, tip=0.25) * hard
            pt.layer_over(rgb, alpha, HIGHLIGHT, hi * 0.95)
            nail = _line(_arc(83.2, 48.1, 3.4, 3.0, -100, 100, 14), 0.8, n, k, tip=0.3) * hard
            pt.layer_over(rgb, alpha, LINE, nail)
            for x in (66.5, 75.5):
                crease = _line([(x - 0.4, 50.8), (x, 52.2), (x + 0.4, 53.2)], 0.8, n, k, tip=0.3) * hard
                pt.layer_over(rgb, alpha, LINE, crease)
        elif name == "thumb":
            hi = _line([(36, 39.8), (44, 39.6), (51, 40.2)], 1.0, n, k, tip=0.25) * hard
            pt.layer_over(rgb, alpha, HIGHLIGHT, hi * 0.95)
            nail = _line(_arc(54.6, 43.2, 3.0, 2.6, -95, 95, 12), 0.75, n, k, tip=0.3) * hard
            pt.layer_over(rgb, alpha, LINE, nail)
            crease = _line([(44.5, 44.8), (45, 46.2), (45.6, 47)], 0.75, n, k, tip=0.3) * hard
            pt.layer_over(rgb, alpha, LINE, crease * 0.9)
        elif curled:
            # each curled finger's knuckle catches a dab of light; a crease near its end
            y = {"curl1": 58.7, "curl2": 67.4, "curl3": 76.2}[name]
            x = {"curl1": 58.5, "curl2": 56.5, "curl3": 53.5}[name]
            dab = _line([(x - 6.5, y - 2.6), (x - 3.0, y - 3.0)], 0.9, n, k, tip=0.3) * hard
            pt.layer_over(rgb, alpha, HIGHLIGHT, dab * 0.8)
            crease = _line([(x, y - 3.2), (x + 0.9, y - 1.0), (x + 1.0, y + 1.0)], 0.75, n, k, tip=0.3) * hard
            pt.layer_over(rgb, alpha, LINE, crease * 0.85)
        elif name == "fist":
            # light along the back of the hand's top edge, the bone of the wrist where the hand turns down
            hi = _line([(27, 42.5), (33, 40.2), (40, 39.8)], 1.0, n, k, tip=0.25) * hard
            pt.layer_over(rgb, alpha, HIGHLIGHT, hi * 0.85)
            pt.layer_over(rgb, alpha, LINE, _line([(29, 70), (31.5, 75), (31.5, 79)], 0.8, n, k, tip=0.3) * hard * 0.7)

    def shrink_down(a):
        return a.reshape(HAND_CELL, k, HAND_CELL, k, *a.shape[2:]).mean(axis=(1, 3))

    a_small = shrink_down(alpha)
    rgb_small = shrink_down(rgb * alpha[..., None]) / np.maximum(a_small, 1e-6)[..., None]
    right = np.concatenate([np.clip(rgb_small, 0, 1), a_small[..., None]], -1).astype(np.float32)
    left = right[:, ::-1]
    down_cell = np.rot90(right, k=-1)
    up_cell = np.rot90(right, k=1)
    top = np.concatenate([right, left], axis=1)
    bottom = np.concatenate([down_cell, up_cell], axis=1)
    return np.ascontiguousarray(np.concatenate([top, bottom], axis=0))


def hand_preview(sheet):
    """The four cells at the size the game shows them (half) and at the drawn size, on dark and on light."""
    cell = HAND_CELL
    rows = []
    for back in (0.08, 0.78):
        tiles = []
        for index in range(4):
            y, x = (index // 2) * cell, (index % 2) * cell
            picture = sheet[y:y + cell, x:x + cell]
            half = picture.reshape(cell // 2, 2, cell // 2, 2, 4).mean(axis=(1, 3))
            for img in (half, picture):
                tile = np.full((cell, cell, 3), back, np.float32)
                h, w = img.shape[:2]
                oy, ox = (cell - h) // 2, (cell - w) // 2
                a = img[..., 3:]
                tile[oy:oy + h, ox:ox + w] = tile[oy:oy + h, ox:ox + w] * (1 - a) + img[..., :3] * a
                tiles.append(tile)
        rows.append(np.concatenate(tiles, axis=1))
    return np.concatenate(rows, axis=0)


def preview(pictures):
    rows = []
    for back in (0.08, 0.78):
        tiles = []
        for picture in pictures:
            for zoom in (1, 4):
                big = np.repeat(np.repeat(picture, zoom, 0), zoom, 1)
                tile = np.full((SIZE * 4, SIZE * 4, 3), back, np.float32)
                h, w = big.shape[:2]
                y, x = (SIZE * 4 - h) // 2, (SIZE * 4 - w) // 2
                a = big[..., 3:]
                tile[y:y + h, x:x + w] = tile[y:y + h, x:x + w] * (1 - a) + big[..., :3] * a
                # the hot spot, a red dot
                tile[SIZE * 2 - 1:SIZE * 2 + 1, SIZE * 2 - 1:SIZE * 2 + 1] = (0.9, 0.1, 0.1)
                tiles.append(tile)
        rows.append(np.concatenate(tiles, axis=1))
    return np.concatenate(rows, axis=0)


def main():
    os.makedirs(OUT, exist_ok=True)
    lock, free, hand = lashes(), nib(), pointer_hand()
    png.write(os.path.join(OUT, "CursorLock.png"), lock)
    png.write(os.path.join(OUT, "CursorFree.png"), free)
    png.write(os.path.join(OUT, "PointerHand.png"), hand)
    png.write(PREVIEW, preview([lock, free]))
    png.write(PREVIEW_HAND, hand_preview(hand))
    print("[cursors] wrote", os.path.join(OUT, "CursorLock.png"), ", CursorFree.png and PointerHand.png")


if __name__ == "__main__":
    main()
