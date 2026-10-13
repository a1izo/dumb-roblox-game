"""Quality sheets for heightmap.py (python art/scripts/heightmap.py <scan> --qc DIR).

What is measured, and printed with a verdict:
  round trip   normals made from the height against the scan's own normal map (degrees)
  seams        the jump across each wrapping edge against the steps just beside it
  levels       distinct 16-bit values used, and empty steps inside the range (banding)
  light        how far the face relief follows the photograph's brightness (should be little)
Sheets: the joints and blocks over the photograph, the height, the height lit from four sides next to
the scan's normal map lit the same way (and as the game read it until now), the height tiled 2 x 2,
and where the round trip disagrees.
"""

import os

import numpy as np
from PIL import Image, ImageDraw

import heightmap as hm

LIGHTS = {"from the left": (-1, 0), "from above": (0, -1), "from the right": (1, 0), "from below": (0, 1)}


def _grey(a, lo=None, hi=None):
    lo = np.percentile(a, 0.5) if lo is None else lo
    hi = np.percentile(a, 99.5) if hi is None else hi
    return Image.fromarray((np.clip((a - lo) / max(1e-12, hi - lo), 0, 1) * 255 + 0.5).astype(np.uint8))


def _normals_from(p, q):
    """Unit normals (x right, y up the image, z out) from dh/dcol, dh/drow."""
    n = np.stack([-p, q, np.ones_like(p)], axis=-1)
    return n / np.linalg.norm(n, axis=-1, keepdims=True)


def _lit(n, light, elevation=25.0):
    """Lambert shading of normals (x right, y up) by a raking light; light (dx, drow) on the image."""
    e = np.radians(elevation)
    d = np.array([light[0] * np.cos(e), -light[1] * np.cos(e), np.sin(e)])
    return np.clip(n @ d, 0, 1)


def _label(img, text):
    draw = ImageDraw.Draw(img)
    draw.rectangle([0, 0, 8 + 7 * len(text), 16], fill=(0, 0, 0) if img.mode == "RGB" else 0)
    draw.text((4, 3), text, fill=(255, 255, 255) if img.mode == "RGB" else 255)
    return img


def _decode(rgb):
    n = rgb * 2 - 1
    return n / np.linalg.norm(n, axis=-1, keepdims=True)


def relief_report(scan, made, info, out, verdict):
    """The relief tile: how close its triangles come to the depth field, whether its normal map put
    back on its facets (as 8-bit, as the game gets it) gives the look it was made for, and sheets."""
    size = made["depth"].shape[0]
    tile = hm.REPEAT[scan]
    spp = tile / size
    err = np.abs(made["approx"] - made["depth"])
    print(f"[qc] relief: {len(made['tris'])} triangles per repeat; depth error mean {err.mean():.4f} studs "
          f"({err.mean() * hm.STUD * 1000:.1f} mm), p99 {np.percentile(err, 99):.4f}")
    tangent, bitangent, facet = hm.facet_frames(made["sc"], made["sr"], spp)
    r = _decode(np.round(made["relief_normal"] * 255) / 255)
    shown = r[..., :1] * tangent + r[..., 1:2] * bitangent + r[..., 2:] * facet
    target = (made["macro"] * made["scale"] + made["micro"]) / hm.STUD
    gx, gy = hm.gradient(target)
    want = _normals_from(gx / spp, gy / spp)
    miss = np.degrees(np.arccos(np.clip((shown * want).sum(-1), -1, 1)))
    print(f"[qc] relief normal (8-bit) on its facets vs the look it is for: mean {miss.mean():.2f} deg, "
          f"p99 {np.percentile(miss, 99):.2f}")
    verdict.append(("relief normal recomposes (mean < 1 deg)", miss.mean() < 1.0))
    small = 1024
    wire = _grey(-made["depth"]).convert("RGB").resize((small, small), Image.LANCZOS)
    draw = ImageDraw.Draw(wire)
    for t in made["uv"]:
        for dy in (-1, 0, 1):
            pts = [(u * small, (1 - v - dy) * small) for u, v in t]
            draw.line(pts + [pts[0]], fill=(255, 80, 40), width=1)
    wire.save(os.path.join(out, f"{scan}_qc_relief_mesh.png"))
    crop = (slice(0, size // 2), slice(0, size // 2))
    cells = []
    for label, n in (("relief triangles alone", facet), ("triangles + relief normal map", shown),
                     ("the look it is made for", want)):
        img = _grey(_lit(n[crop], (-1, -1)), 0, 1).resize((512, 512), Image.LANCZOS).convert("RGB")
        cells.append(_label(img, label + " - lit from top left"))
    sheet = Image.new("RGB", (512 * len(cells), 512))
    for i, cell in enumerate(cells):
        sheet.paste(cell, (i * 512, 0))
    sheet.save(os.path.join(out, f"{scan}_qc_relief_lit.png"))


def report(scan, h, joint_mask, labels, inner, info, slopes_used, out, made=None):
    os.makedirs(out, exist_ok=True)
    size = h.shape[0]
    px = info["metres_per_pixel"]
    scan_n = hm.read_normal(scan)
    p_scan, q_scan = slopes_used  # the scan's slopes, read the right way (in pixel units)
    n_scan = _normals_from(p_scan, q_scan)
    gx, gy = hm.gradient(h / px)
    n_height = _normals_from(gx, gy)
    angle = np.degrees(np.arccos(np.clip((n_scan * n_height).sum(-1), -1, 1)))
    # The floor: no height at all can match the part of the scan's slopes that is curl, so the best any
    # height can do is the plain least-squares surface with every wave kept.
    fx, fy = hm.gradient(hm.integrate(p_scan, q_scan, low=(0.0, 1e-6)))
    floor = np.degrees(np.arccos(np.clip((n_scan * _normals_from(fx, fy)).sum(-1), -1, 1)))
    faces = inner & ~joint_mask
    verdict = []
    print("[qc] round trip (height normals vs scan normals), degrees  [floor: the best any height can do]:")
    for name, sel in (("all", np.ones_like(faces)), ("faces", faces), ("joints", joint_mask)):
        a, b = angle[sel], floor[sel]
        print(f"  {name:7s} mean {a.mean():5.2f} [{b.mean():5.2f}]  median {np.median(a):5.2f} [{np.median(b):5.2f}]"
              f"  p95 {np.percentile(a, 95):5.2f} [{np.percentile(b, 95):5.2f}]")
    verdict.append(("round trip within 1 deg of the floor", angle.mean() < floor.mean() + 1.0))

    # Seams: the step across each wrapping edge against the steps just beside it (a joint may lie on
    # the edge, so the steps across the rest of the image are no measure), in the 16-bit counts.
    counts, _ = hm.encode(h)

    def seam(a, axis):
        a = np.roll(a.astype(np.float64), a.shape[axis] // 2, axis=axis)  # the edge now in the middle
        d = np.abs(np.diff(a, axis=axis)).mean(axis=1 - axis)
        m = a.shape[axis] // 2 - 1  # the step across the old edge
        return d[m] / np.mean([d[m - 2], d[m - 1], d[m + 1], d[m + 2]])

    seam_lr, seam_tb = seam(counts, 1), seam(counts, 0)
    src_lr = np.mean([seam(scan_n[..., k], 1) for k in range(2)])
    src_tb = np.mean([seam(scan_n[..., k], 0) for k in range(2)])
    print(f"[qc] seams: left-right {seam_lr:.3f}, top-bottom {seam_tb:.3f} (1 = like the steps beside it; "
          f"the scan's own normal map: {src_lr:.3f}, {src_tb:.3f})")
    verdict.append(("seams within 0.75..1.33", 0.75 < seam_lr < 1.33 and 0.75 < seam_tb < 1.33))

    used = np.unique(counts)
    span = int(used.max()) - int(used.min()) + 1
    hist = np.bincount(counts.ravel() - used.min())
    # Banding shows as runs of empty steps between filled ones in the busy middle of the range.
    lo_c, hi_c = np.percentile(counts, 2), np.percentile(counts, 98)
    mid = hist[int(lo_c - used.min()):int(hi_c - used.min())]
    print(f"[qc] levels: {len(used)} distinct of a {span}-step range; empty steps in the middle 96%: "
          f"{int((mid == 0).sum())} of {len(mid)}")
    verdict.append(("no empty steps mid-range", (mid == 0).sum() == 0))

    photo = hm._rgb(hm._file(scan, "_diff_", "_diffuse_", "_Color."))
    lum = photo @ np.array([0.2126, 0.7152, 0.0722])
    hl = h - hm.blur(h, 30)
    ll = lum - hm.blur(lum, 30)
    corr = float(np.corrcoef(hl[faces], ll[faces])[0, 1])
    print(f"[qc] light: correlation of face relief with the photograph's brightness {corr:+.3f}")
    verdict.append(("photo brightness not used as height (|corr| < 0.35)", abs(corr) < 0.35))

    jd, jf, fr = info["joint_depth_mm"], info["joint_floor_mm"], info["face_roughness_mm"]
    print(f"[qc] sanity: joints {jd} mm deep (floor {jf} mm), faces {fr} mm rough, {info['blocks']} blocks")
    verdict.append(("joint depth 8..35 mm", 8 <= jd <= 35))

    # Sheets ----------------------------------------------------------------------------------------
    small = 1024
    seg = (photo * 255).astype(np.uint8).copy()
    rng = np.random.default_rng(3)
    tint = rng.integers(60, 255, (labels.max() + 1, 3))
    seg = (seg * 0.55 + tint[labels] * 0.45 * (labels > 0)[..., None]).astype(np.uint8)
    seg[joint_mask] = (255, 40, 40)
    Image.fromarray(seg).resize((small, small), Image.LANCZOS).save(os.path.join(out, f"{scan}_qc_segments.png"))

    grey = _grey(h)
    grey.resize((small, small), Image.LANCZOS).save(os.path.join(out, f"{scan}_qc_height.png"))
    tiled = np.tile(h, (2, 2))
    _grey(tiled).resize((small, small), Image.LANCZOS).save(os.path.join(out, f"{scan}_qc_tiled.png"))
    _grey(angle, 0, 20).resize((small, small), Image.LANCZOS).save(os.path.join(out, f"{scan}_qc_roundtrip.png"))

    # The game's reading until now: the file's channels as named (OpenGL), red across, green up.
    n_old = np.stack([scan_n[..., 0], scan_n[..., 1], scan_n[..., 2]], axis=-1)
    tile = 512
    crop = (slice(0, size // 2), slice(0, size // 2))  # a quarter, so the relief reads
    rows = []
    for name, light in LIGHTS.items():
        cells = []
        for label, n in (("height (new)", n_height), ("scan normal, read right", n_scan),
                         ("scan normal as the game read it", n_old)):
            img = _grey(_lit(n[crop], light), 0, 1).resize((tile, tile), Image.LANCZOS).convert("RGB")
            cells.append(_label(img, f"{label} - lit {name}"))
        row = Image.new("RGB", (tile * len(cells), tile))
        for i, cell in enumerate(cells):
            row.paste(cell, (i * tile, 0))
        rows.append(row)
    sheet = Image.new("RGB", (rows[0].width, tile * len(rows)))
    for i, row in enumerate(rows):
        sheet.paste(row, (0, i * tile))
    sheet.save(os.path.join(out, f"{scan}_qc_relit.png"))

    if made is not None:
        relief_report(scan, made, info, out, verdict)

    print("[qc] verdict:")
    for text, ok in verdict:
        print(f"  {'PASS' if ok else 'FAIL'}  {text}")
    return all(ok for _, ok in verdict)
