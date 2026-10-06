"""A small TrueType reader and rasterizer (numpy only), for turning fonts into glyph atlases.

Reads the tables needed to draw glyphs (head, hhea, maxp, cmap, hmtx, loca, glyf), glyph names
(post, format 2.0) and pair kerning (GPOS 'kern' PairPos), and fills outlines with the non-zero
winding rule on a supersampled grid.
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
        self._names = None
        self._kern_subtables = None

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

    # Glyph names (post table, format 2.0) --------------------------------------------------------

    def glyph_names(self):
        """{glyph index: name} for glyphs with a custom name (like "one.case"). The first 258 names
        of the Macintosh standard order are not stored in the font, so those glyphs are absent."""
        if self._names is None:
            self._names = {}
            if "post" in self.tables:
                table = self._table("post")
                if struct.unpack(">I", table[:4])[0] == 0x00020000:
                    count = struct.unpack(">H", table[32:34])[0]
                    index = struct.unpack(f">{count}H", table[34 : 34 + 2 * count])
                    at = 34 + 2 * count
                    strings = []
                    while at < len(table):
                        length = table[at]
                        strings.append(table[at + 1 : at + 1 + length].decode("latin-1"))
                        at += 1 + length
                    for glyph, i in enumerate(index):
                        if i >= 258 and i - 258 < len(strings):
                            self._names[glyph] = strings[i - 258]
        return self._names

    def glyph_by_name(self, name):
        """The glyph index with this custom name, or 0."""
        for glyph, glyph_name in self.glyph_names().items():
            if glyph_name == name:
                return glyph
        return 0

    # Pair kerning (GPOS 'kern', PairPos formats 1 and 2) ------------------------------------------

    def _u16(self, table, at):
        return struct.unpack(">H", table[at : at + 2])[0]

    def _kern_subs(self):
        if self._kern_subtables is None:
            self._kern_subtables = []
            if "GPOS" not in self.tables:
                return self._kern_subtables
            g = self._table("GPOS")
            feature_list, lookup_list = self._u16(g, 6), self._u16(g, 8)
            wanted = set()
            for i in range(self._u16(g, feature_list)):
                tag = g[feature_list + 2 + 6 * i : feature_list + 6 + 6 * i]
                if tag != b"kern":
                    continue
                feature = feature_list + self._u16(g, feature_list + 6 + 6 * i)
                for j in range(self._u16(g, feature + 2)):
                    wanted.add(self._u16(g, feature + 4 + 2 * j))
            for index in sorted(wanted):
                lookup = lookup_list + self._u16(g, lookup_list + 2 + 2 * index)
                kind = self._u16(g, lookup)
                for k in range(self._u16(g, lookup + 4)):
                    sub = lookup + self._u16(g, lookup + 6 + 2 * k)
                    sub_kind = kind
                    if kind == 9:  # extension lookup: the real subtable is elsewhere
                        sub_kind = self._u16(g, sub + 2)
                        sub += struct.unpack(">I", g[sub + 4 : sub + 8])[0]
                    if sub_kind == 2:
                        self._kern_subtables.append(sub)
        return self._kern_subtables

    def _coverage_index(self, g, at, glyph):
        fmt, count = self._u16(g, at), self._u16(g, at + 2)
        if fmt == 1:
            for i in range(count):
                if self._u16(g, at + 4 + 2 * i) == glyph:
                    return i
            return None
        for i in range(count):
            start, end, first = struct.unpack(">HHH", g[at + 4 + 6 * i : at + 10 + 6 * i])
            if start <= glyph <= end:
                return first + glyph - start
        return None

    def _class_of(self, g, at, glyph):
        fmt = self._u16(g, at)
        if fmt == 1:
            start, count = self._u16(g, at + 2), self._u16(g, at + 4)
            if start <= glyph < start + count:
                return self._u16(g, at + 6 + 2 * (glyph - start))
            return 0
        for i in range(self._u16(g, at + 2)):
            start, end, cls = struct.unpack(">HHH", g[at + 4 + 6 * i : at + 10 + 6 * i])
            if start <= glyph <= end:
                return cls
        return 0

    def kern(self, left, right):
        """The extra advance (font units, usually negative) between two glyph indices."""
        subs = self._kern_subs()
        if not subs:
            return 0
        g = self._table("GPOS")
        for sub in subs:
            fmt = self._u16(g, sub)
            index = self._coverage_index(g, sub + self._u16(g, sub + 2), left)
            if index is None:
                continue
            fmt1, fmt2 = self._u16(g, sub + 4), self._u16(g, sub + 6)
            size1, size2 = 2 * bin(fmt1).count("1"), 2 * bin(fmt2).count("1")
            advance_at = 2 * bin(fmt1 & 0x3).count("1") if fmt1 & 0x4 else None
            if fmt == 1:
                pair_set = sub + self._u16(g, sub + 10 + 2 * index)
                record = 2 + size1 + size2
                for r in range(self._u16(g, pair_set)):
                    at = pair_set + 2 + r * record
                    if self._u16(g, at) == right:
                        if advance_at is None:
                            return 0
                        return struct.unpack(">h", g[at + 2 + advance_at : at + 4 + advance_at])[0]
                continue
            class1 = self._class_of(g, sub + self._u16(g, sub + 8), left)
            class2 = self._class_of(g, sub + self._u16(g, sub + 10), right)
            per_row = self._u16(g, sub + 14)
            at = sub + 16 + (class1 * per_row + class2) * (size1 + size2)
            if advance_at is None:
                return 0
            return struct.unpack(">h", g[at + advance_at : at + advance_at + 2])[0]
        return 0

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
