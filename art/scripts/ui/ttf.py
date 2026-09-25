"""A small TrueType reader and rasterizer (numpy only), for turning fonts into glyph atlases.

Reads the tables needed to draw glyphs (head, hhea, maxp, cmap, hmtx, loca, glyf) and fills
outlines with the non-zero winding rule on a supersampled grid. Outlines can be bent by an
affine transform first (the handwriting alternates use that).
"""

import struct

import numpy as np


class Font:
    def __init__(self, path):
        with open(path, "rb") as f:
            self.data = f.read()
        self.tables = {}
        count = struct.unpack(">H", self.data[4:6])[0]
        for i in range(count):
            tag, _, offset, length = struct.unpack(">4sIII", self.data[12 + 16 * i : 28 + 16 * i])
            self.tables[tag.decode("latin-1")] = (offset, length)
        head = self._table("head")
        self.units_per_em = struct.unpack(">H", head[18:20])[0]
        self.loca_long = struct.unpack(">h", head[50:52])[0] == 1
        hhea = self._table("hhea")
        self.ascender, self.descender, self.line_gap = struct.unpack(">hhh", hhea[4:10])
        self.num_hmetrics = struct.unpack(">H", hhea[34:36])[0]
        self.num_glyphs = struct.unpack(">H", self._table("maxp")[4:6])[0]
        self.cmap = self._read_cmap()
        self._hmtx = self._table("hmtx")
        self._loca = self._read_loca()
        self._glyf_offset = self.tables["glyf"][0]

    def _table(self, tag):
        offset, length = self.tables[tag]
        return self.data[offset : offset + length]

    def _read_cmap(self):
        table = self._table("cmap")
        count = struct.unpack(">H", table[2:4])[0]
        best = None
        for i in range(count):
            platform, encoding, offset = struct.unpack(">HHI", table[4 + 8 * i : 12 + 8 * i])
            fmt = struct.unpack(">H", table[offset : offset + 2])[0]
            if platform == 3 and encoding in (1, 10) and fmt in (4, 12):
                best = (offset, fmt)
                if fmt == 12:
                    break
        if best is None:
            raise ValueError("no unicode cmap")
        offset, fmt = best
        mapping = {}
        if fmt == 4:
            seg_x2 = struct.unpack(">H", table[offset + 6 : offset + 8])[0]
            segs = seg_x2 // 2
            ends = struct.unpack(f">{segs}H", table[offset + 14 : offset + 14 + seg_x2])
            base = offset + 16 + seg_x2
            starts = struct.unpack(f">{segs}H", table[base : base + seg_x2])
            deltas = struct.unpack(f">{segs}h", table[base + seg_x2 : base + 2 * seg_x2])
            range_base = base + 2 * seg_x2
            ranges = struct.unpack(f">{segs}H", table[range_base : range_base + seg_x2])
            for s in range(segs):
                for code in range(starts[s], ends[s] + 1):
                    if code == 0xFFFF:
                        continue
                    if ranges[s] == 0:
                        glyph = (code + deltas[s]) & 0xFFFF
                    else:
                        at = range_base + 2 * s + ranges[s] + 2 * (code - starts[s])
                        glyph = struct.unpack(">H", table[at : at + 2])[0]
                        if glyph:
                            glyph = (glyph + deltas[s]) & 0xFFFF
                    if glyph:
                        mapping[code] = glyph
        else:
            groups = struct.unpack(">I", table[offset + 12 : offset + 16])[0]
            for g in range(groups):
                start, end, first = struct.unpack(">III", table[offset + 16 + 12 * g : offset + 28 + 12 * g])
                for code in range(start, end + 1):
                    mapping[code] = first + code - start
        return mapping

    def _read_loca(self):
        table = self._table("loca")
        n = self.num_glyphs + 1
        if self.loca_long:
            return struct.unpack(f">{n}I", table[: 4 * n])
        return [v * 2 for v in struct.unpack(f">{n}H", table[: 2 * n])]

    def advance(self, glyph):
        index = min(glyph, self.num_hmetrics - 1)
        return struct.unpack(">H", self._hmtx[4 * index : 4 * index + 2])[0]

    def glyph_index(self, char):
        return self.cmap.get(ord(char), 0)

    def contours(self, glyph, depth=0):
        """The glyph's outline as a list of contours, each a list of (x, y, on_curve)."""
        start, end = self._loca[glyph], self._loca[glyph + 1]
        if end <= start:
            return []
        d = self.data
        at = self._glyf_offset + start
        n_contours = struct.unpack(">h", d[at : at + 2])[0]
        p = at + 10
        if n_contours >= 0:
            ends = struct.unpack(f">{n_contours}H", d[p : p + 2 * n_contours])
            p += 2 * n_contours
            n_instr = struct.unpack(">H", d[p : p + 2])[0]
            p += 2 + n_instr
            n_points = ends[-1] + 1 if ends else 0
            flags = []
            while len(flags) < n_points:
                flag = d[p]
                p += 1
                flags.append(flag)
                if flag & 8:
                    repeat = d[p]
                    p += 1
                    flags.extend([flag] * repeat)
            flags = flags[:n_points]
            xs, ys = [], []
            value = 0
            for flag in flags:
                if flag & 2:
                    delta = d[p]
                    p += 1
                    value += delta if flag & 16 else -delta
                elif not flag & 16:
                    value += struct.unpack(">h", d[p : p + 2])[0]
                    p += 2
                xs.append(value)
            value = 0
            for flag in flags:
                if flag & 4:
                    delta = d[p]
                    p += 1
                    value += delta if flag & 32 else -delta
                elif not flag & 32:
                    value += struct.unpack(">h", d[p : p + 2])[0]
                    p += 2
                ys.append(value)
            out, first = [], 0
            for last in ends:
                out.append([(xs[i], ys[i], bool(flags[i] & 1)) for i in range(first, last + 1)])
                first = last + 1
            return out
        # Composite glyph: components placed with an offset and an optional 2x2 transform.
        out = []
        while True:
            flags, component = struct.unpack(">HH", d[p : p + 4])
            p += 4
            if flags & 1:
                dx, dy = struct.unpack(">hh", d[p : p + 4])
                p += 4
            else:
                dx, dy = struct.unpack(">bb", d[p : p + 2])
                p += 2
            a, b, c, e = 1.0, 0.0, 0.0, 1.0
            if flags & 8:
                a = e = struct.unpack(">h", d[p : p + 2])[0] / 16384
                p += 2
            elif flags & 0x40:
                a, e = (v / 16384 for v in struct.unpack(">hh", d[p : p + 4]))
                p += 4
            elif flags & 0x80:
                a, b, c, e = (v / 16384 for v in struct.unpack(">hhhh", d[p : p + 8]))
                p += 8
            if depth < 8:
                for contour in self.contours(component, depth + 1):
                    out.append([(a * x + c * y + dx, b * x + e * y + dy, on) for x, y, on in contour])
            if not flags & 0x20:
                break
        return out


def flatten(contour, steps=8):
    """A contour of on/off-curve points as a closed polyline (quadratic curves split into steps)."""
    pts = list(contour)
    if not pts:
        return []
    # Start on an on-curve point (insert an implied one when none exists).
    start = next((i for i, p in enumerate(pts) if p[2]), None)
    if start is None:
        a, b = pts[0], pts[1 % len(pts)]
        pts.insert(0, ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, True))
        start = 0
    pts = pts[start:] + pts[:start]
    pts.append(pts[0])
    out = [(pts[0][0], pts[0][1])]
    i = 1
    while i < len(pts):
        p = pts[i]
        if p[2]:
            out.append((p[0], p[1]))
            i += 1
            continue
        control = p
        nxt = pts[i + 1] if i + 1 < len(pts) else pts[0]
        if nxt[2]:
            end = nxt
            i += 2
        else:
            end = ((control[0] + nxt[0]) / 2, (control[1] + nxt[1]) / 2, True)
            i += 1
        x0, y0 = out[-1]
        for s in range(1, steps + 1):
            t = s / steps
            mt = 1 - t
            out.append(
                (
                    mt * mt * x0 + 2 * mt * t * control[0] + t * t * end[0],
                    mt * mt * y0 + 2 * mt * t * control[1] + t * t * end[1],
                )
            )
    return out


def fill(polylines, width, height, ss=4):
    """Coverage (height x width, 0..1) of polylines given in pixel coordinates (y down), filled
    with the non-zero rule on an ss x ss supersampled grid."""
    edges = []
    for line in polylines:
        for (x0, y0), (x1, y1) in zip(line, line[1:]):
            if y0 != y1:
                edges.append((x0 * ss, y0 * ss, x1 * ss, y1 * ss))
    grid = np.zeros((height * ss, width * ss), dtype=np.float32)
    if not edges:
        return np.zeros((height, width), dtype=np.float32)
    e = np.array(edges, dtype=np.float64)
    x0, y0, x1, y1 = e[:, 0], e[:, 1], e[:, 2], e[:, 3]
    direction = np.where(y1 > y0, 1, -1)
    ylo, yhi = np.minimum(y0, y1), np.maximum(y0, y1)
    cols = np.arange(width * ss) + 0.5
    for row in range(height * ss):
        y = row + 0.5
        hit = (ylo <= y) & (y < yhi)
        if not hit.any():
            continue
        xs = x0[hit] + (y - y0[hit]) * (x1[hit] - x0[hit]) / (y1[hit] - y0[hit])
        dirs = direction[hit]
        order = np.argsort(xs)
        xs, dirs = xs[order], dirs[order]
        winding = np.cumsum(dirs)
        inside = winding[:-1] != 0
        for a, b in zip(xs[:-1][inside], xs[1:][inside]):
            grid[row, (cols >= a) & (cols < b)] = 1.0
    return grid.reshape(height, ss, width, ss).mean(axis=(1, 3))
