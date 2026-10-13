"""A scan's height map made from its normal map, for the scans whose own height map is missing or
blank (medieval_blocks_03: every pixel of its disp file is white), and the relief tile that
maps/relief.py turns into geometry.

    python art/scripts/heightmap.py medieval_blocks_03             # height map + relief tile
    python art/scripts/heightmap.py medieval_blocks_03 --qc DIR    # and the quality sheets in DIR

Not Blender's Python: it needs numpy, scipy and Pillow (python -m venv <dir>, then
<dir>/Scripts/pip install numpy scipy pillow). Writes into art/source/prepared:

    <scan>_height16.png         2048 x 2048, 16-bit grey, lossless. White is raised, black is deep;
                                the blocks' face plane is mid-grey (32768). Same size, turn and UVs as
                                the scan.
    <scan>_height16.json        metres per step, the face plane, joint depth, face roughness, how it
                                was made
    <scan>_height8.png          the same map in 8 bits
    <scan>_normal.png           the height's own normal map (OpenGL, green up)
    <scan>_relief.npz           the relief tile, and <scan>_relief_normal.png the normal map for its
                                facets (see relief)

How the height is made:
1. The normal map is read the way that makes it a gradient field. A height map's normals have no
   curl, so of the four ways to read the red and green channels the right one leaves the least
   curl (medieval_blocks_03 has them swapped; the game drew it lit from the side until now).
2. Frankot-Chellappa: the least-squares surface for those slopes, solved in the Fourier domain, so
   it repeats without a seam. One pixel is the scan's size in the game / its width, so heights are
   metres. The broadest waves (fewer than two across the scan) are almost all curl: they are left
   out, and the next band is eased in.
3. The mortar joints are found in the height itself (narrow valleys that join up into one network),
   the blocks between them are numbered, and each block's face is levelled (what the integration
   leaves as a tilt across a block is drift, not stone). Joints, arrises and the split-face grain are
   kept exactly as measured. The colour photograph is never used as height.
4. The relief tile is the wall as a mason laid it (class Wall), built from what was measured: its
   courses, joints and groove shape. The normal map that goes with it puts back on its flat-shaded
   facets everything they leave out, so the wall reads as the height says.
"""

import argparse
import json
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SOURCE = os.path.join(ROOT, "art", "source", "textures")
PREPARED = os.path.join(ROOT, "art", "source", "prepared")
STUD = 1 / 3.5  # metres

# Studs one repeat of the scan covers in the game (scanlib.LIBRARY), which sets the pixel size.
REPEAT = {"medieval_blocks_03": 8.0}
# Joints: wider than this (metres) is not a joint but a dip in a block's face.
JOINT_WIDTH = 0.045
# The relief tile's vertices across a block's face, as a share of the repeat (maps/relief.py keeps the
# walls it is laid on under its triangle cap).
RELIEF_FACE_STEP = 0.2


# Reading ---------------------------------------------------------------------------------------------


def _file(scan, *marks):
    folder = os.path.join(SOURCE, scan)
    for name in sorted(os.listdir(folder)):
        if any(mark in name[len(scan):] for mark in marks):
            return os.path.join(folder, name)
    raise FileNotFoundError(f"{scan}: no file with {marks}")


def _rgb(path):
    return np.asarray(Image.open(path).convert("RGB"), dtype=np.float64) / 255.0


def read_normal(scan):
    """Unit normals [row, col, xyz], rows from the top of the image."""
    n = _rgb(_file(scan, "_nor_gl_", "_NormalGL.")) * 2 - 1
    return n / np.maximum(1e-6, np.linalg.norm(n, axis=-1, keepdims=True))


# Fourier tools ---------------------------------------------------------------------------------------


def _freqs(size):
    """Angular frequencies along columns and rows, and cycles per image."""
    wx = 2 * np.pi * np.fft.fftfreq(size)[None, :]
    wy = 2 * np.pi * np.fft.fftfreq(size)[:, None]
    return wx, wy, np.hypot(wx, wy) * size / (2 * np.pi)


def blur(a, sigma):
    """Gaussian blur that wraps at the edges (sigma in pixels)."""
    _, _, f = _freqs(a.shape[0])
    return np.real(np.fft.ifft2(np.fft.fft2(a) * np.exp(-2 * (np.pi * sigma * f / a.shape[0]) ** 2)))


def gradient(h):
    """Spectral d/dcol, d/drow (wraps)."""
    wx, wy, _ = _freqs(h.shape[0])
    spec = np.fft.fft2(h)
    return np.real(np.fft.ifft2(1j * wx * spec)), np.real(np.fft.ifft2(1j * wy * spec))


def _curl_share(p, q, lo=2, hi=128):
    """How much of the slope field (p, q) in the band [lo, hi) cycles is not the gradient of anything."""
    wx, wy, f = _freqs(p.shape[0])
    band = (f >= lo) & (f < hi)
    P, Q = np.fft.fft2(p) * band, np.fft.fft2(q) * band
    den = np.where(band, wx * wx + wy * wy, 1.0)
    H = (-1j * wx * P - 1j * wy * Q) / den
    rest = np.abs(1j * wx * H - P) ** 2 + np.abs(1j * wy * H - Q) ** 2
    return float(np.sqrt(rest.sum() / max(1e-12, (np.abs(P) ** 2 + np.abs(Q) ** 2).sum())))


READINGS = {
    # name: (dh/dcol, dh/drow) from the slopes sx = -nx/nz, sy = -ny/nz
    "GL": lambda sx, sy: (sx, -sy),  # green up the image (OpenGL), as the files are named
    "DX": lambda sx, sy: (sx, sy),  # green down the image (DirectX)
    "swapped": lambda sx, sy: (sy, sx),  # red and green swapped
    "swapped2": lambda sx, sy: (sy, -sx),
}


def slopes(n):
    """(dh/dcol, dh/drow, reading, curl shares): the slopes read the way the map is a gradient field."""
    nz = np.maximum(n[..., 2], 0.25)
    sx, sy = -n[..., 0] / nz, -n[..., 1] / nz
    shares = {name: _curl_share(*read(sx, sy)) for name, read in READINGS.items()}
    best = min(shares, key=shares.get)
    p, q = READINGS[best](sx, sy)
    return p, q, best, shares


def integrate(p, q, low=(1.5, 6.0)):
    """Frankot-Chellappa height (in pixels of slope x pixels) that wraps. Waves broader than low[0]
    cycles per image are dropped, and eased back in by low[1] (they are mostly curl, see the docstring)."""
    wx, wy, f = _freqs(p.shape[0])
    den = wx * wx + wy * wy
    den[0, 0] = 1.0
    H = (-1j * wx * np.fft.fft2(p) - 1j * wy * np.fft.fft2(q)) / den
    t = np.clip((f - low[0]) / (low[1] - low[0]), 0, 1)
    H *= t * t * (3 - 2 * t)
    H[0, 0] = 0
    return np.real(np.fft.ifft2(H))


# The stone: joints and blocks -----------------------------------------------------------------------


def _label_torus(mask):
    """Connected regions of mask on a torus (what leaves one edge comes back at the other)."""
    labels, count = ndi.label(mask)
    parent = list(range(count + 1))

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    for a_edge, b_edge in ((labels[:, 0], labels[:, -1]), (labels[0, :], labels[-1, :])):
        for a, b in zip(a_edge, b_edge):
            if a and b:
                ra, rb = find(a), find(b)
                if ra != rb:
                    parent[max(ra, rb)] = min(ra, rb)
    roots = np.array([find(i) for i in range(count + 1)])
    _, packed = np.unique(roots, return_inverse=True)
    return packed[labels], int(packed.max())


def joints(h, px):
    """The mortar network: narrow valleys (black top-hat) that join into one net across the scan."""
    size = max(3, int(round(JOINT_WIDTH / px)) | 1)
    padded = np.pad(h, size, mode="wrap")
    valley = (ndi.grey_closing(padded, size=(size, size)) - padded)[size:-size, size:-size]
    level = np.percentile(valley, 82)
    net = valley > level
    net = ndi.binary_opening(np.pad(net, 4, mode="wrap"), iterations=1)[4:-4, 4:-4]
    labels, count = _label_torus(net)
    sizes = np.bincount(labels.ravel())
    sizes[0] = 0
    net = (sizes >= 0.01 * h.size)[labels]  # the net, not the pits in the faces
    # A joint the threshold broke for a few pixels (a chipped arris, mortar filled to the face) is
    # bridged along its own direction, so the blocks either side of it are not taken for one.
    reach = 2 * size
    pad = reach + 2
    grown = np.pad(net, pad, mode="wrap")
    for shape in ((1, reach), (reach, 1)):
        grown |= ndi.binary_closing(grown, structure=np.ones(shape, dtype=bool))
    return grown[pad:-pad, pad:-pad], valley


def blocks(joint_mask, smallest=0.004):
    """Block labels (0 = joint, and the slivers smaller than `smallest` of the scan) and how many."""
    labels, count = _label_torus(~joint_mask)
    sizes = np.bincount(labels.ravel(), minlength=count + 1)
    keep = sizes >= smallest * labels.size
    keep[0] = False
    remap = np.zeros(count + 1, dtype=np.int64)
    remap[keep] = np.arange(1, int(keep.sum()) + 1)
    return remap[labels], int(keep.sum())


def _nearest_block(labels, pad):
    """Every pixel's nearest block (joints take the block beside them), on the torus."""
    padded = np.pad(labels, pad, mode="wrap")
    _, (ri, ci) = ndi.distance_transform_edt(padded == 0, return_indices=True)
    return padded[ri, ci][pad:-pad, pad:-pad]


def levelled(h, labels, count, px):
    """h with each block's tilt taken out (its face plane made parallel to the wall). Returns the new
    height and each block's (level, tilt in mm across 0.5 m)."""
    rows, cols = np.mgrid[0:h.shape[0], 0:h.shape[1]].astype(np.float64)
    inner = ndi.binary_erosion(np.pad(labels > 0, 12, mode="wrap"), iterations=12)[12:-12, 12:-12]
    near = _nearest_block(labels, 96)
    correction = np.zeros_like(h)
    stats = {}
    for k in range(1, count + 1):
        sel = inner & (labels == k)
        if sel.sum() < 200:
            continue
        # A block that leaves one edge carries on at the other: unwrap its pixels around its centre.
        r, c = rows[sel], cols[sel]
        r0, c0 = r[0], c[0]
        r = (r - r0 + h.shape[0] / 2) % h.shape[0] - h.shape[0] / 2
        c = (c - c0 + h.shape[1] / 2) % h.shape[1] - h.shape[1] / 2
        rc, cc = r.mean(), c.mean()
        A = np.stack([np.ones_like(r), c - cc, r - rc], axis=1)
        coef, *_ = np.linalg.lstsq(A, h[sel], rcond=None)
        allk = near == k
        R = (rows[allk] - r0 + h.shape[0] / 2) % h.shape[0] - h.shape[0] / 2 - rc
        C = (cols[allk] - c0 + h.shape[1] / 2) % h.shape[1] - h.shape[1] / 2 - cc
        correction[allk] = coef[1] * C + coef[2] * R
        tilt = np.hypot(coef[1], coef[2]) * (0.5 / px) * 1000
        stats[k] = (float(coef[0]) * 1000, float(tilt))
    # (Soften the seams of the correction in the joints, where two blocks' planes meet.)
    correction = blur(correction, 3.0)
    return h - correction, stats, inner


# Making it -------------------------------------------------------------------------------------------


def make(scan):
    n = read_normal(scan)
    size = n.shape[0]
    px = REPEAT[scan] * STUD / size  # metres per pixel in the game
    p, q, reading, shares = slopes(n)
    h = integrate(p, q) * px
    # Narrow valleys, broad tops: a wall of blocks leans to the deep side. Upside down otherwise.
    local = h - blur(h, 40)
    if ((local - local.mean()) ** 3).mean() > 0:
        h = -h
        p, q = -p, -q
    joint_mask, _ = joints(h, px)
    labels, count = blocks(joint_mask)
    h, stats, inner = levelled(h, labels, count, px)
    face = float(np.median(h[inner]))
    h = h - face
    skeleton = joint_mask & (ndi.grey_erosion(h, size=(5, 5), mode="wrap") >= h - 1e-9)
    info = {
        "scan": scan,
        "size": size,
        "metres_per_pixel": px,
        "reading": reading,
        "curl_share": {k: round(v, 3) for k, v in shares.items()},
        "blocks": count,
        "joint_depth_mm": round(-float(np.median(h[joint_mask])) * 1000, 2),
        "joint_floor_mm": round(-float(np.median(h[skeleton])) * 1000, 2) if skeleton.any() else None,
        "face_roughness_mm": round(float(h[inner].std()) * 1000, 2),
        "range_mm": [round(float(h.min()) * 1000, 2), round(float(h.max()) * 1000, 2)],
        "block_levels_mm": [round(v[0], 2) for v in stats.values()],
        "block_tilts_removed_mm_per_half_metre": [round(v[1], 2) for v in stats.values()],
    }
    return h, joint_mask, labels, inner, info, (p, q)


# Normal maps and the relief tile ---------------------------------------------------------------------


def normal_map(z, stud_per_px):
    """An OpenGL normal map (rgb 0..1, green up the image) of a height z in studs."""
    gx, gy = gradient(z)
    n = np.stack([-gx / stud_per_px, gy / stud_per_px, np.ones_like(z)], axis=-1)  # rows go down: dz/dy = -dz/drow
    return n / np.linalg.norm(n, axis=-1, keepdims=True) * 0.5 + 0.5


def split(h, joint_mask, px, reach=0.0135):
    """(macro, micro): the laid wall (joints, arrises, each block's level and its broad swells) and the
    split-face grain on top of it. The grain is what is left after smoothing each block's face with only
    its own face (so a joint never pulls its edges down) and it fades out towards the joints."""
    sigma = reach / px
    face = (~ndi.binary_dilation(np.pad(joint_mask, 6, mode="wrap"), iterations=4)[6:-6, 6:-6]).astype(np.float64)
    smooth = blur(h * face, sigma) / np.maximum(1e-6, blur(face, sigma))
    away = ndi.distance_transform_edt(np.pad(~joint_mask, 64, mode="wrap"))[64:-64, 64:-64]
    t = np.clip(away / (1.5 * sigma), 0, 1)
    micro = (h - smooth) * face * t * t * (3 - 2 * t)
    return h - micro, micro


def _depth_field(macro, joint_mask, scale):
    """Studs into the wall (0 on the blocks' faces): the laid wall `scale` times its measured depth.
    Only into the wall, so nothing stands proud of the faces the colliders and props were placed on."""
    faces = ~ndi.binary_dilation(np.pad(joint_mask, 6, mode="wrap"), iterations=4)[6:-6, 6:-6]
    top = float(np.percentile(macro[faces], 98))
    return np.maximum(0.0, (top - macro) * scale / STUD), top


def _runs(on):
    """(start, end) of each run of True on a circular array, end inclusive and unwrapped (a run
    across the end of the array ends past it)."""
    n = len(on)
    if on.all():
        return [(0, n - 1)]
    shift = int(np.argmin(on))
    rolled = np.roll(on, -shift)
    out, i = [], 0
    while i < n:
        if rolled[i]:
            start = i
            while i < n and rolled[i]:
                i += 1
            out.append((start + shift, i - 1 + shift))
        else:
            i += 1
    return out


def _deepest(run, line):
    idx = np.arange(run[0], run[1] + 1)
    return int(idx[np.argmax(line[idx % len(line)])])


def _bilinear(a, r, c):
    n = a.shape[0]
    r0, c0 = int(np.floor(r)), int(np.floor(c))
    fr, fc = r - r0, c - c0
    top = a[r0 % n, c0 % n] * (1 - fc) + a[r0 % n, (c0 + 1) % n] * fc
    bottom = a[(r0 + 1) % n, c0 % n] * (1 - fc) + a[(r0 + 1) % n, (c0 + 1) % n] * fc
    return float(top * (1 - fr) + bottom * fr)


class Wall:
    """The laid wall in one repeat, as a modeller would build it: courses of blocks between straight
    bed joints, straight head joints in each course, every joint a groove of the measured shape and
    its own measured depth, each block's face following its measured broad swell. Positions are
    pixels of the depth field (rows go down); depths are studs into the wall."""

    REACH = 48  # pixels either side of a joint the groove shape is measured over

    def __init__(self, depth, joint_mask):
        n = self.n = depth.shape[0]
        self.beds = sorted(_deepest(run, depth.mean(axis=1)) % n for run in _runs(joint_mask.mean(axis=1) > 0.5))
        self.heads = []  # per course k (below bed k): its head joints' columns
        for k in range(len(self.beds)):
            band = self._band(k)
            on = joint_mask[band].mean(axis=0) > 0.5
            self.heads.append(sorted(_deepest(run, depth[band].mean(axis=0)) % n for run in _runs(on)))
        # The faces' own level, smoothed, carried on under the joints (only face pixels count).
        face = ~ndi.binary_dilation(np.pad(joint_mask, 8, mode="wrap"), iterations=6)[8:-8, 8:-8]
        face = face.astype(np.float64)
        self.face = blur(depth * face, 20) / np.maximum(1e-6, blur(face, 20))
        # Each joint's mean profile across it, made relative to the faces beside it; their mean is the
        # groove's shape, and each joint keeps its own floor depth.
        offs = np.arange(-self.REACH, self.REACH + 1)
        profiles, self.bed_floor, self.head_floor = [], [], []
        for k, b in enumerate(self.beds):
            away = np.ones(n, dtype=bool)
            for c in self.heads[k] + self.heads[k - 1]:
                away[np.arange(c - 40, c + 41) % n] = False
            prof = np.array([depth[(b + o) % n][away].mean() for o in offs])
            profiles.append(prof)
            self.bed_floor.append(float(prof[self.REACH]))
        for k in range(len(self.beds)):
            band = self._band(k)
            floors = []
            for c in self.heads[k]:
                prof = np.array([depth[band, (c + o) % n].mean() for o in offs])
                profiles.append(prof)
                floors.append(float(prof[self.REACH]))
            self.head_floor.append(floors)
        shapes = []
        for prof in profiles:
            side = np.concatenate([prof[:8], prof[-8:]]).mean()
            shapes.append((prof - side) / max(1e-6, prof[self.REACH] - side))
        shape = np.mean(shapes, axis=0)
        shape = np.clip((shape + shape[::-1]) / 2, 0, 1)[self.REACH:]
        self.shape = shape  # depth share at 0, 1, 2 ... pixels from a joint's middle
        self.arris = int(next(o for o in range(len(shape)) if shape[o] <= 0.1))

    def _band(self, k):
        """The rows of course k well clear of its bed joints."""
        n = self.n
        top = self.beds[k]
        bottom = self.beds[(k + 1) % len(self.beds)] + (n if k + 1 == len(self.beds) else 0)
        return np.arange(top + 40, bottom - 40) % n

    def _groove(self, offset, floor, face):
        s = np.interp(abs(offset), np.arange(len(self.shape)), self.shape, right=0.0)
        return face + max(0.0, floor - face) * s

    def at(self, row, col, course):
        """Depth at (row, col) (pixels, may be past the repeat), with the head joints of `course`."""
        n = self.n
        r, c = row % n, col % n
        face = _bilinear(self.face, r, c)
        d = face
        for b, floor in zip(self.beds, self.bed_floor):
            d = max(d, self._groove((r - b + n / 2) % n - n / 2, floor, face))
        for c0, floor in zip(self.heads[course], self.head_floor[course]):
            d = max(d, self._groove((c - c0 + n / 2) % n - n / 2, floor, face))
        return d

    def course_cuts(self, k, step):
        """Columns of course k's vertices: the repeat's edges, each head joint's arrises and middle,
        and the faces between them about `step` apart."""
        n, a = self.n, self.arris
        cuts = {0.0, float(n)}
        joints = self.heads[k]
        for c in joints:
            cuts.update(float((c + o) % n) for o in (-a, 0, a))
        if not joints:
            cuts.update(_spaced(0.0, float(n), step))
        for i, c in enumerate(joints):
            nxt = joints[(i + 1) % len(joints)] + (n if i + 1 == len(joints) else 0)
            cuts.update(x % n for x in _spaced(c + a, nxt - a, step))
        return sorted(cuts)

    def floor_cuts(self, k, step):
        """Columns along bed joint k's floor: the head joints that meet it from both sides."""
        n = self.n
        cuts = {0.0, float(n)}
        cuts.update(float(c) for c in self.heads[k] + self.heads[k - 1])
        cuts.update(_spaced(0.0, float(n), step))
        return sorted(cuts)


def _spaced(lo, hi, step):
    """Points strictly between lo and hi, about step apart."""
    count = int(np.floor((hi - lo) / step))
    return [lo + (hi - lo) * (i + 1) / (count + 1) for i in range(max(0, count))]


def _ladder(top, bottom):
    """Triangles between two rows of vertices (sorted along the row, sharing their first and last
    column), taking the shorter step each time."""
    tris, i, j = [], 0, 0
    while i < len(top) - 1 or j < len(bottom) - 1:
        if j == len(bottom) - 1 or (i < len(top) - 1 and top[i + 1][0] <= bottom[j + 1][0]):
            tris.append((top[i], top[i + 1], bottom[j]))
            i += 1
        else:
            tris.append((top[i], bottom[j + 1], bottom[j]))
            j += 1
    return tris


def build_wall(wall, face_step):
    """The relief tile: triangles [(col, row, depth) x 3] from the first bed joint's floor to the same
    floor one repeat down, over columns 0..n. The edges of one tile meet the next tile's vertex for
    vertex, so tiles laid side by side have no cracks."""
    n, a = wall.n, wall.arris
    step = face_step * n
    beds = wall.beds + [wall.beds[0] + n]
    kcount = len(wall.beds)

    def row(cols, r, course):
        return [(c, r, wall.at(r, c, course)) for c in cols]

    floors = [row(wall.floor_cuts(k % kcount, step), beds[k], k % kcount) for k in range(kcount + 1)]
    tris = []
    for k in range(kcount):
        top, bottom = beds[k] + a, beds[k + 1] - a
        inner = int(np.floor((bottom - top) / step))
        cuts = wall.course_cuts(k, step)
        grid = [row(cuts, top + (bottom - top) * i / (inner + 1), k) for i in range(inner + 2)]
        tris += _ladder(floors[k], grid[0])
        for upper, lower in zip(grid, grid[1:]):
            tris += _ladder(upper, lower)
        tris += _ladder(grid[-1], floors[k + 1])
    return tris


def rasterize(tris, n):
    """Per pixel of the repeat: the depth of the triangles and each one's slope (d depth / d col,
    d depth / d row, per pixel). Triangles in (col, row, depth), may reach past the repeat."""
    depth = np.full((n, n), np.nan)
    sc = np.zeros((n, n))
    sr = np.zeros((n, n))
    for (c0, r0, d0), (c1, r1, d1), (c2, r2, d2) in tris:
        det = (c1 - c0) * (r2 - r0) - (c2 - c0) * (r1 - r0)
        if abs(det) < 1e-12:
            continue
        # depth = d0 + gc (col - c0) + gr (row - r0)
        gc = ((d1 - d0) * (r2 - r0) - (d2 - d0) * (r1 - r0)) / det
        gr = ((c1 - c0) * (d2 - d0) - (c2 - c0) * (d1 - d0)) / det
        lo_c, hi_c = int(np.floor(min(c0, c1, c2))), int(np.ceil(max(c0, c1, c2)))
        lo_r, hi_r = int(np.floor(min(r0, r1, r2))), int(np.ceil(max(r0, r1, r2)))
        cc, rr = np.meshgrid(np.arange(lo_c, hi_c + 1) + 0.5, np.arange(lo_r, hi_r + 1) + 0.5)
        w1 = ((cc - c0) * (r2 - r0) - (c2 - c0) * (rr - r0)) / det
        w2 = ((c1 - c0) * (rr - r0) - (cc - c0) * (r1 - r0)) / det
        inside = (w1 >= -1e-9) & (w2 >= -1e-9) & (w1 + w2 <= 1 + 1e-9)
        if not inside.any():
            continue
        pc = (cc[inside] - 0.5).astype(int) % n
        pr = (rr[inside] - 0.5).astype(int) % n
        depth[pr, pc] = d0 + gc * (cc[inside] - c0) + gr * (rr[inside] - r0)
        sc[pr, pc] = gc
        sr[pr, pc] = gr
    if np.isnan(depth).any():
        raise RuntimeError(f"relief tile leaves {int(np.isnan(depth).sum())} pixels uncovered")
    return depth, sc, sr


def facet_frames(sc, sr, stud_per_px):
    """Per pixel, the (tangent, bitangent, normal) of the flat-shaded facet over it: x along +u (right),
    y along +v (up the image), z out of the wall. A facet's tangent is the surface's own direction of
    +u, as the importer's tangents are."""
    fx = -sc / stud_per_px  # out of the wall is -depth; per stud along +u
    fy = sr / stud_per_px  # +v is up the image: d/dv = -d/drow
    normal = np.stack([-fx, -fy, np.ones_like(fx)], axis=-1)
    normal /= np.linalg.norm(normal, axis=-1, keepdims=True)
    tangent = np.stack([np.ones_like(fx), np.zeros_like(fx), fx], axis=-1)
    tangent -= (tangent * normal).sum(-1, keepdims=True) * normal
    tangent /= np.linalg.norm(tangent, axis=-1, keepdims=True)
    return tangent, np.cross(normal, tangent), normal


def residual_normal(target, sc, sr, stud_per_px):
    """The relief's normal map: per pixel, the normal of `target` (studs out of the wall) in the frame
    of the facet it falls on."""
    gx, gy = gradient(target)
    t = np.stack([-gx / stud_per_px, gy / stud_per_px, np.ones_like(target)], axis=-1)
    t /= np.linalg.norm(t, axis=-1, keepdims=True)
    tangent, bitangent, normal = facet_frames(sc, sr, stud_per_px)
    out = np.stack([(t * tangent).sum(-1), (t * bitangent).sum(-1), (t * normal).sum(-1)], axis=-1)
    return out / np.linalg.norm(out, axis=-1, keepdims=True) * 0.5 + 0.5


def relief(scan, h, joint_mask, info, face_step=RELIEF_FACE_STEP, scale=2.0):
    """The relief tile and the normal maps that go with it, written to art/source/prepared:
    <scan>_normal.png         the height's own normal map (for the flat walls, in place of the scan's)
    <scan>_relief.npz         triangles of one repeat: u, v in repeats (v up), depth in studs into the wall
    <scan>_relief_normal.png  the grain, and whatever the triangles leave out, on their facets"""
    px = info["metres_per_pixel"]
    n = h.shape[0]
    tile_studs = REPEAT[scan]
    stud_per_px = tile_studs / n
    base = os.path.join(PREPARED, scan)
    flat = normal_map(h / STUD, stud_per_px)
    Image.fromarray((np.clip(flat, 0, 1) * 255 + 0.5).astype(np.uint8)).save(base + "_normal.png")
    macro, micro = split(h, joint_mask, px)
    depth, top = _depth_field(macro, joint_mask, scale)
    wall = Wall(depth, joint_mask)
    tris = build_wall(wall, face_step)
    approx, sc, sr = rasterize(tris, n)
    # The look the relief must give: the laid wall at `scale`, the grain as measured (as on the flat walls).
    target = (macro * scale + micro) / STUD
    rn = residual_normal(target - target.mean(), sc, sr, stud_per_px)
    Image.fromarray((np.clip(rn, 0, 1) * 255 + 0.5).astype(np.uint8)).save(base + "_relief_normal.png")
    arr = np.array(tris, dtype=np.float64)  # [T, 3, (col, row, depth)]
    uv = np.stack([arr[..., 0] / n, 1 - arr[..., 1] / n], axis=-1)
    # Counter-clockwise in u, v (v up), as faces are seen from the front.
    e1, e2 = uv[:, 1] - uv[:, 0], uv[:, 2] - uv[:, 0]
    flip = e1[:, 0] * e2[:, 1] - e1[:, 1] * e2[:, 0] < 0
    uv[flip] = uv[flip][:, [0, 2, 1]]
    d = arr[..., 2].copy()
    d[flip] = d[flip][:, [0, 2, 1]]
    # Bed joints (their middles, v up) and the arris either side, so a band of relief can end on a joint.
    beds_v = np.array([1 - b / n for b in wall.beds])
    np.savez_compressed(base + "_relief.npz", uv=uv, depth=d, tile_studs=tile_studs, scale=scale, top_m=top,
                        beds_v=beds_v, arris_v=wall.arris / n)
    err = np.abs(approx - depth)
    print(f"[relief] {len(tris)} triangles per repeat; {len(wall.beds)} courses, "
          f"{sum(len(h_) for h_ in wall.heads)} head joints; arris {wall.arris} px; joint floors "
          f"{min(wall.bed_floor + sum(wall.head_floor, [])):.3f}..{max(wall.bed_floor + sum(wall.head_floor, [])):.3f} "
          f"studs; depth error mean {err.mean():.4f} studs ({err.mean() * STUD * 1000:.1f} mm)")
    return {"macro": macro, "micro": micro, "depth": depth, "approx": approx, "sc": sc, "sr": sr, "tris": tris,
            "uv": uv, "normal": flat, "relief_normal": rn, "scale": scale, "wall": wall}


def encode(h):
    """16-bit counts: the face plane at 32768, the furthest point from it 32000 steps away."""
    step = float(np.abs(h).max()) / 32000.0
    counts = np.clip(np.round(32768 + h / step), 0, 65535).astype(np.uint16)
    return counts, step


def write(scan, h, info):
    os.makedirs(PREPARED, exist_ok=True)
    counts, step = encode(h)
    info = dict(info, metres_per_step=step, face_plane=32768, white="raised", black="deep",
                method="normal map integrated (Frankot-Chellappa), blocks levelled; see art/scripts/heightmap.py")
    base = os.path.join(PREPARED, scan)
    Image.fromarray(counts).save(base + "_height16.png", optimize=True)
    # The same map in 8 bits (the face plane at 128), for tools that take no more.
    Image.fromarray(np.clip(np.round(counts / 257.0), 0, 255).astype(np.uint8)).save(base + "_height8.png")
    with open(base + "_height16.json", "w", encoding="utf-8", newline="\n") as f:
        json.dump(info, f, indent=2)
        f.write("\n")
    return base + "_height16.png", info


def main(argv):
    parser = argparse.ArgumentParser()
    parser.add_argument("scan")
    parser.add_argument("--qc", help="folder for the quality sheets")
    parser.add_argument("--face-step", type=float, default=RELIEF_FACE_STEP,
                        help="the relief tile's vertex spacing across block faces, in repeats (0: no tile)")
    args = parser.parse_args(argv)
    h, joint_mask, labels, inner, info, slopes_used = make(args.scan)
    path, info = write(args.scan, h, info)
    print(f"[height] {path}")
    for key in ("reading", "curl_share", "blocks", "joint_depth_mm", "joint_floor_mm", "face_roughness_mm", "range_mm",
                "metres_per_step"):
        print(f"  {key}: {info[key]}")
    made = relief(args.scan, h, joint_mask, info, args.face_step) if args.face_step else None
    ok = True
    if args.qc:
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        import heightmap_qc

        ok = heightmap_qc.report(args.scan, h, joint_mask, labels, inner, info, slopes_used, args.qc, made)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
