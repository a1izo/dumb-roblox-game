"""The game's two pointers (UI/Cursor) and the red pointing hand (UI/Kit/Pointer), drawn with numpy:

    CursorLock    64 x 64  the closed-eyes mark the user drew (art/refs/ui/cursor_lashes.png), traced from it, white
                           with a black outline: the pointer locked in the middle of the screen in a case's free roam
                           (World/ShoulderCam)
    CursorFree    64 x 64  a fountain pen's nib on the black of its grip, its point on the middle pixel: the pointer
                           everywhere else. Redrawn 2026-11-03 at the user's word ("sharper and more professional"):
                           a longer nib with its shoulders, a lit and a shaded half, the slit and the breather hole cut
                           clean, a steel ring and the grip behind it, a thin outline and a soft drop shadow
    PointerHand  192 x 192 the hand that points at whatever is chosen (OMORI's): traced from your picture of it
                           (2026-11-06), a white hand drawn in a red line, its index finger alone held out (2026-11-03:
                           "pointing with a single finger"), the thumb laid over the back of the hand, the other three
                           curled under, filled red; no sleeve, no black; four cells, pointing right, left, down and up
                           (the fingertip at 92, 48 of a 96 px cell pointing right)

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
# Your picture of the hand (2026-11-06, 41 x 40 px), traced in its own px and laid on the cell by _at: its fingertip
# lands on the cell's (92, 48) and the hand stays inside the box Kit/Pointer expects.
REF_SCALE = 2.23
INK = np.array([194, 32, 42], np.float32) / 255  # the red line
WHITE = np.array([253, 247, 244], np.float32) / 255  # the hand
BLUSH = np.array([246, 204, 200], np.float32) / 255  # where the white turns away from the light
CURL = np.array([220, 92, 96], np.float32) / 255  # the curled fingers, filled red
CURL_LIT = np.array([246, 172, 168], np.float32) / 255  # the round top of each curled finger
CURL_DEEP = np.array([176, 30, 40], np.float32) / 255  # deep in the fold

# The hand's outline (your picture's px), clockwise from the middle of the wrist's end: up its back to the knuckle,
# along the top of the index finger to its tip, back under it, round the curled fingers' ends and along the bottom.
HAND_SHAPE = [(1.5, 21.0), (1.8, 18.2), (3.3, 16.6), (6.0, 15.9), (8.6, 14.9), (11.0, 13.5), (13.4, 12.0), (15.5, 10.4),
           (18.0, 9.4), (21.0, 9.6), (22.9, 11.0), (24.6, 12.4), (28.0, 12.9), (33.0, 13.0), (37.2, 13.3), (39.2, 14.3),
           (39.3, 15.7), (37.6, 16.6), (33.5, 17.1), (31.6, 18.0), (31.0, 20.0), (30.6, 22.3), (29.2, 23.4),
           (28.9, 25.3), (27.7, 26.6), (25.0, 27.3), (20.0, 27.4), (15.6, 27.1), (13.4, 26.4), (9.5, 25.8), (5.0, 25.5),
           (2.9, 24.9), (1.8, 23.3)]
# The curled fingers, one filled patch under the index finger, and the folds between them (their ends turn up).
CURLED = [(17.6, 18.0), (22.0, 17.4), (28.0, 17.4), (31.6, 18.0), (31.0, 20.0), (30.6, 22.3), (29.2, 23.4),
          (28.9, 25.3), (27.7, 26.6), (25.0, 27.3), (19.0, 27.4), (17.8, 25.6), (19.6, 23.2), (19.9, 20.6)]
FOLDS = [[(19.9, 21.7), (24.0, 21.8), (28.6, 21.8), (30.6, 21.0)],
         [(20.2, 24.3), (24.0, 24.4), (27.8, 24.3), (29.0, 23.5)]]
# (the light on each curled finger's round top: from, to, the stripe's height)
CURL_TOPS = [((22.8, 19.4), (28.8, 19.4), 1.3), ((22.6, 23.0), (27.0, 23.0), 1.0), ((18.2, 25.6), (21.4, 25.6), 0.8)]
# The underside of the index finger, from its tip back to where it meets the curled fingers.
INDEX_UNDER = [(37.8, 16.5), (33.0, 17.0), (27.0, 17.2), (23.6, 17.6)]
# The thumb, laid over the back of the hand: its edge from the knuckle down to the curled fingers, its tip a small
# round at the left and the line from it back up to them.
THUMB_EDGE = [(18.2, 12.6), (19.0, 14.5), (20.2, 16.4), (21.2, 17.9)]
THUMB_TIP = [(12.3, 21.0), (13.2, 20.0), (15.0, 19.8), (16.5, 20.4), (16.1, 21.6), (14.2, 22.0), (12.8, 21.7)]
THUMB_UNDER = [(16.4, 20.2), (17.0, 19.2), (17.8, 18.4)]


def _at(x, y):
    """Your picture's px to the cell's px."""
    return (5 + REF_SCALE * (x - 1), 48 + REF_SCALE * (y - 15))


def _curve(points, closed=False, n=6):
    """A smooth curve (Catmull-Rom) through `points` (your picture's px), in the cell's px."""
    pts = np.array([_at(*p) for p in points], np.float64)
    if closed:
        pts = np.vstack([pts[-1], pts, pts[0], pts[1]])
    else:
        pts = np.vstack([pts[0] * 2 - pts[1], pts, pts[-1] * 2 - pts[-2]])
    out = []
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[i + 1], pts[i + 2]
        for t in np.linspace(0, 1, n, endpoint=False):
            out.append(0.5 * (2 * p1 + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
                              + (3 * p1 - p0 - 3 * p2 + p3) * t * t * t))
    out.append(pts[-2])
    return [tuple(p) for p in out]


def _poly(points, n, scale):
    return pt.fill([(x * scale, y * scale) for x, y in points], n, n)


def _stroke(points, n, k, width, closed=False, taper=True, heavy=None):
    """A drawn line along `points` (your picture's px): `width` cell px, swelling a little as a pen's pressure does,
    heavier where `heavy` (a function of the cell's x, y, giving 0..1) says, thinning at its ends unless closed."""
    line = _curve(points, closed)
    m = len(line)
    widths = []
    for i, (x, y) in enumerate(line):
        w = width * (1 + 0.14 * math.sin(i * 0.9 + x * 0.21))
        if heavy is not None:
            w *= 1 + 0.45 * heavy(x, y)
        if taper and not closed:
            w *= 0.35 + 0.65 * min(1.0, 4.0 * min(i, m - 1 - i) / max(1, m - 1)) ** 0.7
        widths.append(w)
    return pt.fill([(x * k, y * k) for x, y in pt.outline(line, widths)], n, n)


def _moved(mask, dx, dy):
    """`mask` moved by (dx, dy) supersampled px, nothing wrapping round."""
    out = np.zeros_like(mask)
    h, w = mask.shape
    out[max(dy, 0): h + min(dy, 0), max(dx, 0): w + min(dx, 0)] = mask[max(-dy, 0): h + min(-dy, 0),
                                                                        max(-dx, 0): w + min(-dx, 0)]
    return out


def pointer_hand():
    """The pointing hand, pointing right (the fingertip at 92, 48 of the cell), traced from your picture of it
    (2026-11-06: "remove the sleeve ... make it more accurate to the image"): OMORI's hand, white, drawn in a red line
    that swells and thins as a pen's does, heavier along the hand's lower right where it turns from the light; a pale
    blush where the white turns; the three curled fingers filled red under the index finger, the round top of each
    lit pink, the folds between them in the line's red; the thumb laid over the back of the hand in two lines and a
    round tip. No sleeve, no black."""
    n = HAND_CELL * HAND_SS
    k = HAND_SS
    rgb = np.zeros((n, n, 3), np.float32)
    alpha = np.zeros((n, n), np.float32)

    def heavy(x, y):
        # (the line presses harder toward the hand's lower right, away from the light)
        return max(0.0, min(1.0, ((y - 46) / 24 + (x - 30) / 80)))

    body = _poly(_curve(HAND_SHAPE, closed=True), n, k)
    hard = (body > 0.5).astype(np.float32)
    pt.layer_over(rgb, alpha, WHITE, body)
    # the blush: where the hand, moved toward the light (up and left), no longer covers itself
    toward = _moved(hard, int(-1.2 * k), int(-2.6 * k))
    blush = pt.blur(np.clip(hard - toward, 0, 1), 1.2 * k) * hard
    pt.layer_over(rgb, alpha, BLUSH, blush * 0.75)
    # the curled fingers, filled red, each one's round top lit, deeper in the folds
    curled = _poly(_curve(CURLED, closed=True), n, k) * hard
    pt.layer_over(rgb, alpha, CURL, curled)
    for a, b, h in CURL_TOPS:
        top = _stroke([a, ((a[0] + b[0]) / 2, a[1] - 0.15), b], n, k, h * REF_SCALE)
        pt.layer_over(rgb, alpha, CURL_LIT, top * curled * 0.85)
    for fold in FOLDS:
        shade = _stroke([(x, y - 0.6) for x, y in fold], n, k, 1.1 * REF_SCALE)
        pt.layer_over(rgb, alpha, CURL_DEEP, shade * curled * 0.7)
    # the thumb's tip, a little red round
    tip = _poly(_curve(THUMB_TIP, closed=True), n, k)
    pt.layer_over(rgb, alpha, CURL, tip * 0.85)
    # the lines
    lines = [
        _stroke(HAND_SHAPE, n, k, 2.2, closed=True, heavy=heavy),
        _stroke(INDEX_UNDER, n, k, 2.1, heavy=heavy),
        _stroke(CURLED[:4], n, k, 2.0, heavy=heavy),
        _stroke(CURLED[10:] + CURLED[:1], n, k, 1.8),
        _stroke(THUMB_EDGE, n, k, 2.0, heavy=heavy),
        _stroke(THUMB_TIP, n, k, 1.7, closed=True),
        _stroke(THUMB_UNDER, n, k, 1.6),
    ] + [_stroke(fold, n, k, 2.0, heavy=heavy) for fold in FOLDS]
    for line in lines:
        pt.layer_over(rgb, alpha, INK, line)

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
