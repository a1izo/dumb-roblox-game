"""Drawing for the VFX textures: coordinates, signed distances with anti-aliased edges, glows, sheets of frames, colour
bleed (so a texture's see-through pixels carry the colour of their neighbours and filtering draws no dark fringe) and
writing PNGs without Blender."""

import os
import struct
import zlib

import numpy as np


def grid(h, w=None, span=1.0):
    """(y, x) coordinates over an h x w image from -span to span across its width (y down the image, square pixels)."""
    w = w or h
    ys = (np.arange(h) + 0.5 - h / 2) / (w / 2) * span
    xs = (np.arange(w) + 0.5 - w / 2) / (w / 2) * span
    return np.meshgrid(ys, xs, indexing="ij")


def px(h_or_w, span=1.0):
    """The size of a pixel in grid() units for an image this wide."""
    return 2.0 * span / h_or_w


def aa(d, pixel):
    """Coverage (0..1) of the inside of a signed distance d (negative inside), anti-aliased over a pixel."""
    return np.clip(0.5 - d / pixel, 0.0, 1.0)


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def segment(py, pxx, ay, ax, by, bx):
    """Distance from each point to the segment a-b, and how far along it (0..1) the nearest point lies."""
    dy, dx = by - ay, bx - ax
    length2 = dy * dy + dx * dx + 1e-12
    t = np.clip(((py - ay) * dy + (pxx - ax) * dx) / length2, 0.0, 1.0)
    cy, cx = ay + t * dy, ax + t * dx
    return np.hypot(py - cy, pxx - cx), t


def polygon_sdf(py, pxx, points):
    """Signed distance to a closed polygon [(y, x), ...] (negative inside)."""
    d = np.full(py.shape, np.inf)
    inside = np.zeros(py.shape, dtype=bool)
    n = len(points)
    for k in range(n):
        ay, ax = points[k]
        by, bx = points[(k + 1) % n]
        dist, _ = segment(py, pxx, ay, ax, by, bx)
        d = np.minimum(d, dist)
        crosses = ((ay > py) != (by > py)) & (pxx < (bx - ax) * (py - ay) / (by - ay + 1e-12) + ax)
        inside ^= crosses
    return np.where(inside, -d, d)


def glow(r, core=0.05, falloff=0.35):
    """A light's glow by distance: a bright core and a long soft tail (a gaussian plus an inverse-square-ish wing)."""
    return np.exp(-(r / max(core, 1e-6)) ** 2) * 0.65 + 1.0 / (1.0 + (r / max(falloff, 1e-6)) ** 2) ** 2 * 0.35


def over(dst, src):
    """src over dst, straight alpha, both (h, w, 4)."""
    a = src[..., 3:4] + dst[..., 3:4] * (1 - src[..., 3:4])
    rgb = (src[..., :3] * src[..., 3:4] + dst[..., :3] * dst[..., 3:4] * (1 - src[..., 3:4])) / np.maximum(a, 1e-6)
    return np.concatenate([rgb, a], axis=-1)


def rgba(value, alpha):
    """A white-to-grey image: value (0..1) as the colour, alpha as the coverage."""
    out = np.empty(alpha.shape + (4,), dtype=np.float32)
    v = np.clip(value, 0, 1) if np.ndim(value) else np.full(alpha.shape, float(value))
    out[..., 0] = out[..., 1] = out[..., 2] = v
    out[..., 3] = np.clip(alpha, 0, 1)
    return out


def sheet(frames, cols):
    """Frames (each (h, w, 4)) laid out left to right, top to bottom."""
    h, w, _ = frames[0].shape
    rows = (len(frames) + cols - 1) // cols
    out = np.zeros((rows * h, cols * w, 4), dtype=np.float32)
    for k, f in enumerate(frames):
        r, c = divmod(k, cols)
        out[r * h:(r + 1) * h, c * w:(c + 1) * w] = f
    return out


def bleed(img, passes=24):
    """Fills the colour of see-through pixels from their visible neighbours (alpha untouched), so bilinear filtering
    and mipmaps never pull black into an edge."""
    out = img.copy()
    known = img[..., 3] > 1.0 / 255
    rgb = np.where(known[..., None], img[..., :3], 0.0)
    weight = known.astype(np.float32)
    for _ in range(passes):
        if known.all():
            break
        acc = np.zeros_like(rgb)
        cnt = np.zeros_like(weight)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            acc += np.roll(np.roll(rgb * weight[..., None], dy, 0), dx, 1)
            cnt += np.roll(np.roll(weight, dy, 0), dx, 1)
        fill = (~known) & (cnt > 0)
        rgb[fill] = acc[fill] / cnt[fill][:, None]
        weight = np.where(fill, 1.0, weight)
        known = known | fill
    if not known.all():
        mean = rgb[known].mean(axis=0) if known.any() else np.ones(3)
        rgb[~known] = mean
    out[..., :3] = rgb
    return out


def write_png(path, img):
    """Writes an (h, w, 4) float image (top row first, straight alpha) as an 8-bit RGBA PNG."""
    data = (np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8)
    h, w, _ = data.shape
    raw = b"".join(b"\x00" + data[r].tobytes() for r in range(h))

    def chunk(kind, body):
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)

    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)))
        f.write(chunk(b"IDAT", zlib.compress(raw, 9)))
        f.write(chunk(b"IEND", b""))
    return path


def read_png(path):
    """Reads an 8-bit RGBA or RGB PNG written by write_png or Blender into an (h, w, 4) float image."""
    with open(path, "rb") as f:
        blob = f.read()
    pos, chunks = 8, {}
    idat = b""
    while pos < len(blob):
        length, kind = struct.unpack(">I4s", blob[pos:pos + 8])
        body = blob[pos + 8:pos + 8 + length]
        if kind == b"IHDR":
            chunks["ihdr"] = struct.unpack(">IIBBBBB", body)
        elif kind == b"IDAT":
            idat += body
        pos += 12 + length
    w, h, depth, ctype = chunks["ihdr"][:4]
    assert depth == 8 and ctype in (2, 6), "only 8-bit RGB/RGBA"
    chans = 4 if ctype == 6 else 3
    raw = zlib.decompress(idat)
    stride = w * chans
    out = np.zeros((h, stride), dtype=np.int32)
    prev = np.zeros(stride, dtype=np.int32)
    for r in range(h):
        line = np.frombuffer(raw, dtype=np.uint8, count=stride, offset=r * (stride + 1) + 1).astype(np.int32)
        ftype = raw[r * (stride + 1)]
        cur = line.copy()
        if ftype == 1:
            for i in range(chans, stride):
                cur[i] = (cur[i] + cur[i - chans]) & 255
        elif ftype == 2:
            cur = (cur + prev) & 255
        elif ftype == 3:
            for i in range(stride):
                left = cur[i - chans] if i >= chans else 0
                cur[i] = (cur[i] + ((left + prev[i]) >> 1)) & 255
        elif ftype == 4:
            for i in range(stride):
                a = cur[i - chans] if i >= chans else 0
                b = prev[i]
                c = prev[i - chans] if i >= chans else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                cur[i] = (cur[i] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        out[r] = cur
        prev = cur
    img = out.reshape(h, w, chans).astype(np.float32) / 255
    if chans == 3:
        img = np.concatenate([img, np.ones((h, w, 1), dtype=np.float32)], axis=-1)
    return img


def resize(img, h, w):
    """Box-filter downscale by a whole factor (or nearest when not whole)."""
    H, W, C = img.shape
    if H % h == 0 and W % w == 0:
        fy, fx = H // h, W // w
        a = img[..., 3:4]
        rgb = (img[..., :3] * a).reshape(h, fy, w, fx, 3).mean(axis=(1, 3))
        alpha = a.reshape(h, fy, w, fx, 1).mean(axis=(1, 3))
        rgb = rgb / np.maximum(alpha, 1e-6)
        return np.concatenate([rgb, alpha], axis=-1)
    ys = (np.arange(h) * H / h).astype(int)
    xs = (np.arange(w) * W / w).astype(int)
    return img[ys][:, xs]
