"""Inkbound's own lettering: glyph atlases drawn from open fonts that ship with Roblox Studio,
then inked by hand-made effects. Run with plain Python (numpy only):

    python art/scripts/ui/fonts.py            atlases + src/shared/UI/GlyphFonts.luau + preview

Two faces:
  Inkbound Gothic  from Grenze Gotisch Bold: ink-bled, slightly rough blackletter for titles,
                   phase banners, role names and big moments.
  Specter Scrawl   from Amatic SC Bold: tall, scratchy pen capitals with three versions of every letter
                   (tilted, stretched, thicker or thinner, scratched, sometimes blotted), so a
                   written name never looks stamped. For names written in the Grimoire, captions,
                   rules pages and objectives.

The atlases are white (the game tints them) and go to art/export/textures/Ui<Face><n>.png, which
build_props.py carries into InkboundModels_Core.fbx like the other effect textures. Both source fonts
are under the SIL Open Font License 1.1 (see art/fonts/CREDITS.md); the faces made here use
their own names, as the license asks.
"""

import glob
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import png  # noqa: E402
import ttf  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
TEXTURES = os.path.join(ROOT, "art", "export", "textures")
PREVIEWS = os.path.join(ROOT, "art", "export", "previews")
LUAU = os.path.join(ROOT, "src", "shared", "UI", "GlyphFonts.luau")

ATLAS = 1024
CHARS = [chr(c) for c in range(32, 127)] + list("·—…‘’“”")

FACES = {
    "Gothic": {
        "source": "GrenzeGotisch-Bold.ttf",
        "em": 88,
        "pad": 6,
        "variants": 1,
        "fallback": "GrenzeGotisch",
        "seed": 11,
        # Blackletter's capital I reads as a J: a dotless i stretched to capital height instead.
        "substitute": {"I": ("ı", 1.12, 1.33)},
    },
    "Scrawl": {
        "source": "AmaticSC-Bold.ttf",
        "em": 104,
        "pad": 7,
        "variants": 3,
        "fallback": "AmaticSC",
        "seed": 23,
    },
}


def roblox_font(name):
    """The newest copy of a font in a Roblox Studio install."""
    base = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Roblox", "Versions")
    found = sorted(glob.glob(os.path.join(base, "*", "content", "fonts", name)), key=os.path.getmtime)
    if not found:
        raise FileNotFoundError(f"{name} not found under {base} (open Roblox Studio once)")
    return found[-1]


# Image helpers ----------------------------------------------------------------------------------


def blur(img, sigma):
    if sigma <= 0:
        return img
    radius = max(1, int(math.ceil(sigma * 3)))
    x = np.arange(-radius, radius + 1)
    k = np.exp(-(x * x) / (2 * sigma * sigma))
    k /= k.sum()
    padded = np.pad(img, radius, mode="constant")
    rows = np.apply_along_axis(lambda r: np.convolve(r, k, mode="valid"), 1, padded)
    return np.apply_along_axis(lambda c: np.convolve(c, k, mode="valid"), 0, rows)


def value_noise(shape, cell, rng):
    """Smooth noise in -1..1 with features about `cell` pixels across."""
    h, w = shape
    gh, gw = int(h / cell) + 3, int(w / cell) + 3
    grid = rng.uniform(-1, 1, (gh, gw))
    ys = np.arange(h) / cell
    xs = np.arange(w) / cell
    y0, x0 = np.floor(ys).astype(int), np.floor(xs).astype(int)
    fy, fx = ys - y0, xs - x0
    fy = fy * fy * (3 - 2 * fy)
    fx = fx * fx * (3 - 2 * fx)
    a = grid[y0][:, x0]
    b = grid[y0][:, x0 + 1]
    c = grid[y0 + 1][:, x0]
    d = grid[y0 + 1][:, x0 + 1]
    top = a + (b - a) * fx[None, :]
    bottom = c + (d - c) * fx[None, :]
    return top + (bottom - top) * fy[:, None]


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


# Inking -----------------------------------------------------------------------------------------


def ink_gothic(cov, rng):
    """Printed-ink blackletter: soft bleed, irregular edges, a few worn pits, light sheen."""
    h, w = cov.shape
    soft = blur(cov, 1.0)
    # Rough, bitten edges: fine noise only matters where the ink is half there.
    edge = value_noise((h, w), 6, rng) * 0.08 + value_noise((h, w), 1.8, rng) * 0.10
    alpha = smoothstep(0.45, 0.55, soft + edge)
    # Ink that ran: short drips below some strokes.
    yy, xx = np.mgrid[0:h, 0:w]
    for _ in range(1 if rng.random() < 0.3 else 0):
        cols = np.nonzero(cov[int(h * 0.55) :, :].max(axis=0) > 0.8)[0]
        if len(cols) == 0:
            break
        cx = cols[rng.integers(len(cols))]
        rows = np.nonzero(cov[:, cx] > 0.8)[0]
        bottom = rows.max()
        length = rng.uniform(5, 12)
        width = rng.uniform(0.9, 1.6)
        drip = np.exp(-((xx - cx) ** 2) / (2 * width * width)) * ((yy >= bottom) & (yy <= bottom + length))
        drip *= 1 - (yy - bottom) / (length + 1)
        tip = np.exp(-((xx - cx) ** 2 + (yy - bottom - length) ** 2) / (2 * (width * 1.3) ** 2))
        alpha = np.maximum(alpha, smoothstep(0.3, 0.6, np.maximum(drip, tip)))
    grain = value_noise((h, w), 1.4, rng)
    alpha *= 1 - 0.3 * smoothstep(0.8, 0.95, grain) * smoothstep(0.8, 1.0, soft)
    grad = np.linspace(1.0, 0.82, h)[:, None]
    lum = np.clip(grad + value_noise((h, w), 5, rng) * 0.05, 0, 1)
    return alpha, lum


def ink_scrawl(cov, rng, weight):
    """Pen handwriting: uneven stroke weight, scratches along the stroke, sometimes a blot."""
    h, w = cov.shape
    soft = blur(cov, 0.9 + 0.5 * weight)
    edge = value_noise((h, w), 4, rng) * 0.08
    threshold = 0.5 - 0.12 * weight
    alpha = smoothstep(threshold - 0.08, threshold + 0.08, soft + edge)
    # Scratches: noise stretched along a slant, cutting thin gaps into the ink.
    angle = rng.uniform(0.3, 0.9)
    yy, xx = np.mgrid[0:h, 0:w]
    u = (xx * math.cos(angle) + yy * math.sin(angle)) / 1.4
    streak = np.sin(u + value_noise((h, w), 9, rng) * 3.0)
    alpha *= 1 - 0.35 * smoothstep(0.86, 0.99, streak)
    # A blot where the pen rested (one letter in six or so).
    if rng.random() < 0.18:
        ys, xs = np.nonzero(cov > 0.6)
        if len(ys):
            i = rng.integers(len(ys))
            r = rng.uniform(2.2, 4.0)
            blot = np.exp(-((yy - ys[i]) ** 2 + (xx - xs[i]) ** 2) / (2 * r * r))
            alpha = np.maximum(alpha, smoothstep(0.35, 0.6, blot + edge))
    lum = np.clip(0.92 + value_noise((h, w), 6, rng) * 0.08, 0, 1)
    return alpha, lum


# Glyphs -----------------------------------------------------------------------------------------


def jitter(rng, variant, em):
    """A small affine bend (2x2 plus offset, in pixels) for handwriting alternates."""
    if variant == 0:
        rot, shear, sx, sy, dy = 0.0, 0.1, 1.0, 1.0, 0.0
    else:
        rot = math.radians(rng.uniform(-8, 8))
        shear = rng.uniform(-0.05, 0.22)
        sx = rng.uniform(0.9, 1.06)
        sy = rng.uniform(0.9, 1.1)
        dy = rng.uniform(-0.05, 0.05) * em
    c, s = math.cos(rot), math.sin(rot)
    m = np.array([[c * sx, -s * sy + shear * sy], [s * sx, c * sy]])
    return m, dy


def render_glyph(font, char, em, pad, rng, variant, face, substitute=None):
    """substitute: (source character, x stretch, y stretch) to draw this character from."""
    source, sx, sy = substitute or (char, 1.0, 1.0)
    gid = font.glyph_index(source)
    scale = em / font.units_per_em
    advance = font.advance(gid) * scale * sx
    contours = font.contours(gid) if gid else []
    if sx != 1.0 or sy != 1.0:
        contours = [[(x * sx, y * sy, on) for x, y, on in c] for c in contours]
    lines = [ttf.flatten(c) for c in contours]
    lines = [line for line in lines if len(line) > 2]
    if not lines:
        return None, advance
    # Font units (y up) -> pixels (y down, baseline at 0), bent about the glyph's middle.
    pts = np.concatenate([np.array(line) for line in lines]) * scale
    centre = np.array([advance / 2, font.ascender * scale * 0.35])
    m, dy = (np.eye(2), 0.0) if face == "Gothic" else jitter(rng, variant, em)

    def place(p):
        q = (np.asarray(p) * scale - centre) @ m.T + centre
        return np.stack([q[:, 0], -q[:, 1] + dy], axis=1)

    placed = [place(line) for line in lines]
    allpts = np.concatenate(placed)
    minx, miny = np.floor(allpts.min(axis=0)) - pad
    maxx, maxy = np.ceil(allpts.max(axis=0)) + pad
    w, h = int(maxx - minx), int(maxy - miny)
    shifted = [[(x - minx, y - miny) for x, y in line] for line in placed]
    cov = ttf.fill(shifted, w, h)
    if face == "Gothic":
        alpha, lum = ink_gothic(cov, rng)
    else:
        weight = [0.2, 1.0, -0.5][variant % 3] + rng.uniform(-0.25, 0.25)
        alpha, lum = ink_scrawl(cov, rng, weight)
    rgba = np.stack([lum, lum, lum, alpha], axis=2)
    info = {"ox": float(minx), "top": float(-miny), "w": w, "h": h}
    del pts
    return (rgba, info), advance


def pack(images):
    """Shelf-packs (key, rgba) images into as many ATLAS x ATLAS pages as needed.
    Returns pages and key -> (page, x, y)."""
    order = sorted(images, key=lambda kv: -kv[1].shape[0])
    pages, where = [], {}
    page = None
    x = y = shelf = 0
    for key, img in order:
        h, w = img.shape[:2]
        if page is None or x + w > ATLAS:
            x, y, shelf = 0, y + shelf, 0
        if page is None or y + h > ATLAS:
            page = np.zeros((ATLAS, ATLAS, 4), np.float32)
            pages.append(page)
            x = y = shelf = 0
        page[y : y + h, x : x + w] = img
        where[key] = (len(pages), x, y)
        x += w + 1
        shelf = max(shelf, h + 1)
    return pages, where


def build_face(name, spec):
    font = ttf.Font(roblox_font(spec["source"]))
    rng = np.random.default_rng(spec["seed"])
    em, pad = spec["em"], spec["pad"]
    scale = em / font.units_per_em
    images, glyphs = [], {}
    for char in CHARS:
        if char != " " and not font.glyph_index(char):
            continue
        variants = spec["variants"] if char.isalnum() else 1
        entries = []
        for v in range(variants):
            substitute = spec.get("substitute", {}).get(char)
            result, advance = render_glyph(font, char, em, pad, rng, v, name, substitute)
            if result is None:
                entries.append({"adv": advance})
                continue
            rgba, info = result
            key = (char, v)
            images.append((key, rgba))
            info["adv"] = advance
            info["key"] = key
            entries.append(info)
        glyphs[char] = entries
    pages, where = pack(images)
    atlas_names = []
    for i, page in enumerate(pages):
        atlas = f"Ui{name}{i + 1}"
        png.write(os.path.join(TEXTURES, atlas + ".png"), page)
        atlas_names.append(atlas)
    for entries in glyphs.values():
        for info in entries:
            if "key" in info:
                p, x, y = where[info.pop("key")]
                info["page"], info["x"], info["y"] = p, x, y
    return {
        "em": em,
        "ascent": font.ascender * scale,
        "descent": -font.descender * scale,
        "lineGap": font.line_gap * scale,
        "atlases": atlas_names,
        "fallback": spec["fallback"],
        "glyphs": glyphs,
        "pages": pages,
    }


def num(v):
    text = f"{v:.1f}".rstrip("0").rstrip(".")
    return "0" if text in ("-0", "") else text


def lua_string(char):
    if char in ('"', "\\"):
        return '"\\' + char + '"'
    return '"' + char + '"'


def write_luau(faces):
    lines = [
        "--!strict",
        "-- GENERATED by art/scripts/ui/fonts.py. Do not edit by hand.",
        "-- Glyph atlases for Inkbound's own lettering. Per face: em size (px), line metrics, atlas",
        "-- texture names (carried in InkboundModels_Core.fbx) and, per character, one or more versions:",
        "-- { page, x, y, w, h, ox, top, advance } in atlas pixels (a space has only an advance).",
        "",
        "return {",
    ]
    for name, face in faces.items():
        lines.append(f"\t{name} = {{")
        lines.append(
            f"\t\tem = {face['em']}, ascent = {num(face['ascent'])}, descent = {num(face['descent'])}, "
            f"lineGap = {num(face['lineGap'])},"
        )
        lines.append("\t\tatlases = { " + ", ".join(f'"{a}"' for a in face["atlases"]) + " },")
        lines.append(f'\t\tfallback = "{face["fallback"]}",')
        lines.append("\t\tglyphs = {")
        for char, entries in face["glyphs"].items():
            versions = []
            for e in entries:
                if "page" in e:
                    versions.append(
                        "{ "
                        + ", ".join(num(v) for v in (e["page"], e["x"], e["y"], e["w"], e["h"], e["ox"], e["top"], e["adv"]))
                        + " }"
                    )
                else:
                    versions.append("{ " + num(e["adv"]) + " }")
            lines.append(f"\t\t\t[{lua_string(char)}] = {{ " + ", ".join(versions) + " },")
        lines.append("\t\t},")
        lines.append("\t},")
    lines.append("}")
    os.makedirs(os.path.dirname(LUAU), exist_ok=True)
    with open(LUAU, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    return LUAU


def preview(faces, samples):
    """Sets sample lines in each face (as the game will) on a dark page, for checking by eye."""
    height = 40 + sum(int(faces[f]["em"] * 1.35) for f, _ in samples)
    img = np.zeros((height, 1400, 4), np.float32)
    img[..., :3] = np.array([18, 16, 21]) / 255
    img[..., 3] = 1
    y = 20
    counters = {}
    for face_name, text in samples:
        face = faces[face_name]
        baseline = y + face["ascent"]
        x = 20.0
        for char in text:
            entries = face["glyphs"].get(char) or face["glyphs"]["?"]
            n = counters.get((face_name, char), 0)
            counters[(face_name, char)] = n + 1
            e = entries[n % len(entries)]
            if "page" in e:
                page = face["pages"][e["page"] - 1]
                glyph = page[e["y"] : e["y"] + e["h"], e["x"] : e["x"] + e["w"]]
                gx, gy = int(round(x + e["ox"])), int(round(baseline - e["top"]))
                region = img[gy : gy + e["h"], gx : gx + e["w"]]
                gh, gw = region.shape[:2]
                a = glyph[:gh, :gw, 3:4]
                ink = np.array([236, 230, 218]) / 255 * glyph[:gh, :gw, :3]
                region[..., :3] = region[..., :3] * (1 - a) + ink * a
            x += e["adv"]
        y += int(face["em"] * 1.35)
    os.makedirs(PREVIEWS, exist_ok=True)
    return png.write(os.path.join(PREVIEWS, "ui_fonts.png"), img)


def main():
    os.makedirs(TEXTURES, exist_ok=True)
    faces = {}
    for name, spec in FACES.items():
        faces[name] = build_face(name, spec)
        count = sum(len(v) for v in faces[name]["glyphs"].values())
        print(f"[fonts] {name}: {count} glyphs on {len(faces[name]['atlases'])} atlas(es)")
    print("[fonts]", write_luau(faces))
    print(
        "[fonts]",
        preview(
            faces,
            [
                ("Gothic", "INKBOUND  The Grimoire"),
                ("Gothic", "Investigation  0:41"),
                ("Scrawl", "Raven wrote: Kenji Mori, heart attack."),
                ("Scrawl", "letters letters letters 0123456789"),
                ("Scrawl", "Rules of the Grimoire - I. The human"),
            ],
        ),
    )


if __name__ == "__main__":
    main()
