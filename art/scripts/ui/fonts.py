"""Death's Gambit's lettering: glyph atlases drawn from the two Fontshare fonts the game uses, because
Roblox cannot load custom fonts. Run with Blender's Python (numpy only; plain `python` is not installed):

    "C:\\Program Files\\Blender Foundation\\Blender 5.2\\5.2\\python\\bin\\python.exe" art/scripts/ui/fonts.py

It writes the atlases (art/export/textures/Ui<Face><n>.png), src/shared/UI/GlyphFonts.luau and a
preview (art/export/previews/ui_fonts.png).

The font files are not in the repository (download Aktura and Melodrama from fontshare.com and unzip
them into art/fonts/fontshare/, see art/fonts/CREDITS.md). Faces:

  Title     Aktura Regular: blackletter display face. Game title, CASE CLOSED, big slams. Mixed case only;
            its numerals are the lining set (zero.case ... nine.case), not the default oldstyle ones.
  Head      Melodrama Bold: headings, buttons, names, clocks and numbers at 18 px and up.
  Semi      Melodrama Semibold: the lighter heading weight.
  RnLight   Melodrama Light, letters only: ransom-note letters.
  RnMedium  Melodrama Medium, letters only: ransom-note letters.

Every face is plain white with alpha (the game tints it), one version per character, with the font's own
pair kerning and one fixed slot for the digits (Melodrama's are proportional, and clocks must not wobble
as the numbers change): `digit` in GlyphFonts.luau is that slot's width, and each digit is centred in it
by the middle of its image (pen offset = digit / 2 - (ox + w / 2)).
Note: Melodrama's zero is slashed and wide; it is the font's design and has no plain alternate.
"""

import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import png  # noqa: E402
import ttf  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
FONTSHARE = os.path.join(ROOT, "art", "fonts", "fontshare")
TEXTURES = os.path.join(ROOT, "art", "export", "textures")
PREVIEWS = os.path.join(ROOT, "art", "export", "previews")
LUAU = os.path.join(ROOT, "src", "shared", "UI", "GlyphFonts.luau")

ATLAS = 1024
SUPERSAMPLE = 6
CHARS = [chr(c) for c in range(32, 127)] + list("·—…‘’“”")
LETTERS = [chr(c) for c in range(65, 91)] + [chr(c) for c in range(97, 123)] + list("'’ ")
KERN_MIN = 6  # font units (per 1000): smaller pair adjustments are not worth storing
DIGIT_WORDS = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"]

AKTURA = "Aktura_Complete/Fonts/WEB/fonts/Aktura-Regular.ttf"


def melodrama(weight):
    return f"Melodrama_Complete/Fonts/WEB/fonts/Melodrama-{weight}.ttf"


FACES = {
    "Title": {"source": AKTURA, "em": 128, "pad": 4, "digits": "case", "chars": CHARS},
    "Head": {"source": melodrama("Bold"), "em": 96, "pad": 4, "chars": CHARS},
    "Semi": {"source": melodrama("Semibold"), "em": 96, "pad": 4, "chars": CHARS},
    "RnLight": {"source": melodrama("Light"), "em": 96, "pad": 4, "chars": LETTERS},
    "RnMedium": {"source": melodrama("Medium"), "em": 96, "pad": 4, "chars": LETTERS},
}


def font_path(source):
    path = os.path.join(FONTSHARE, *source.split("/"))
    if not os.path.exists(path):
        raise FileNotFoundError(
            f"{path} not found. Download Aktura and Melodrama from https://www.fontshare.com and unzip "
            "them into art/fonts/fontshare/ (the folder is not in git)."
        )
    return path


def glyph_for(font, char, spec):
    """The glyph index to draw a character from (0 when the font has none)."""
    if spec.get("digits") and char.isdigit() and char.isascii():
        found = font.glyph_by_name(f"{DIGIT_WORDS[int(char)]}.{spec['digits']}")
        if found:
            return found
    return font.glyph_index(char)


# Glyphs -----------------------------------------------------------------------------------------


def render_glyph(font, gid, em, pad):
    """White glyph with its coverage as alpha. Returns (rgba or None, advance px, info)."""
    scale = em / font.units_per_em
    advance = font.advance(gid) * scale
    lines = [ttf.flatten(c) for c in font.contours(gid)] if gid else []
    lines = [line for line in lines if len(line) > 2]
    if not lines:
        return None, advance, None
    # Font units (y up) -> pixels (y down, baseline at 0).
    placed = [[(x * scale, -y * scale) for x, y in line] for line in lines]
    points = np.concatenate([np.array(line) for line in placed])
    minx, miny = np.floor(points.min(axis=0)) - pad
    maxx, maxy = np.ceil(points.max(axis=0)) + pad
    w, h = int(maxx - minx), int(maxy - miny)
    shifted = [[(x - minx, y - miny) for x, y in line] for line in placed]
    cov = ttf.fill(shifted, w, h, ss=SUPERSAMPLE)
    rgba = np.stack([np.ones_like(cov), np.ones_like(cov), np.ones_like(cov), cov], axis=2)
    return rgba, advance, {"ox": float(minx), "top": float(-miny), "w": w, "h": h}


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
            page[..., :3] = 1.0
            pages.append(page)
            x = y = shelf = 0
        page[y : y + h, x : x + w] = img
        where[key] = (len(pages), x, y)
        x += w + 1
        shelf = max(shelf, h + 1)
    return pages, where


def build_face(name, spec):
    font = ttf.Font(font_path(spec["source"]))
    em, pad = spec["em"], spec["pad"]
    scale = em / font.units_per_em
    images, glyphs, gids = [], {}, {}
    for char in spec["chars"]:
        gid = glyph_for(font, char, spec)
        if char != " " and not gid:
            continue
        gids[char] = gid
        rgba, advance, info = render_glyph(font, gid, em, pad)
        if rgba is None:
            glyphs[char] = {"adv": advance}
            continue
        info["adv"] = advance
        info["key"] = char
        images.append((char, rgba))
        glyphs[char] = info
    pages, where = pack(images)
    atlas_names = []
    for i, page in enumerate(pages):
        atlas = f"Ui{name}{i + 1}"
        png.write(os.path.join(TEXTURES, atlas + ".png"), page)
        atlas_names.append(atlas)
    for info in glyphs.values():
        if "key" in info:
            p, x, y = where[info.pop("key")]
            info["page"], info["x"], info["y"] = p, x, y
    # Pair kerning in pixels, for the characters this face has (spaces carry none).
    kern = {}
    drawn = [c for c in gids if c != " "]
    for a in drawn:
        for b in drawn:
            value = font.kern(gids[a], gids[b])
            if abs(value) >= KERN_MIN:
                kern.setdefault(a, {})[b] = value * scale
    # One slot for every digit: the widest digit's ink plus a hair of space, each digit centred in it.
    inks = [glyphs[c]["w"] - 2 * pad for c in "0123456789" if c in glyphs and "w" in glyphs[c]]
    digit = (max(inks) + 0.04 * em) if inks else 0.0
    return {
        "em": em,
        "ascent": font.ascender * scale,
        "descent": -font.descender * scale,
        "lineGap": font.line_gap * scale,
        "digit": digit,
        "atlases": atlas_names,
        "glyphs": glyphs,
        "kern": kern,
        "pages": pages,
    }


# Luau -------------------------------------------------------------------------------------------


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
        "-- Glyph atlases for Death's Gambit's lettering (Aktura and Melodrama from Fontshare). Per face: em size (px),",
        "-- line metrics, the width of one digit slot, atlas texture names (carried in DeathsGambitModels_Core.fbx),",
        "-- pair kerning kern[left][right] in px, and per character { page, x, y, w, h, ox, top, advance } in",
        "-- atlas pixels (a space has only an advance).",
        "",
        "return {",
    ]
    for name, face in faces.items():
        lines.append(f"\t{name} = {{")
        lines.append(
            f"\t\tem = {face['em']}, ascent = {num(face['ascent'])}, descent = {num(face['descent'])}, "
            f"lineGap = {num(face['lineGap'])}, digit = {num(face['digit'])},"
        )
        lines.append("\t\tatlases = { " + ", ".join(f'"{a}"' for a in face["atlases"]) + " },")
        lines.append('\t\tfallback = "Montserrat",')
        lines.append("\t\tkern = {")
        for left, rights in face["kern"].items():
            pairs = ", ".join(f"[{lua_string(r)}] = {num(v)}" for r, v in rights.items() if num(v) != "0")
            if pairs:
                lines.append(f"\t\t\t[{lua_string(left)}] = {{ {pairs} }},")
        lines.append("\t\t},")
        lines.append("\t\tglyphs = {")
        for char, e in face["glyphs"].items():
            if "page" in e:
                values = (e["page"], e["x"], e["y"], e["w"], e["h"], e["ox"], e["top"], e["adv"])
                lines.append(f"\t\t\t[{lua_string(char)}] = {{ " + ", ".join(num(v) for v in values) + " },")
            else:
                lines.append(f"\t\t\t[{lua_string(char)}] = {{ {num(e['adv'])} }},")
        lines.append("\t\t},")
        lines.append("\t},")
    lines.append("}")
    os.makedirs(os.path.dirname(LUAU), exist_ok=True)
    with open(LUAU, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    return LUAU


# Preview ----------------------------------------------------------------------------------------


def draw_text(img, face, text, x, baseline, color, tabular=False):
    """Sets text with kerning (and fixed-width digits when tabular), as the game will."""
    previous = None
    for char in text:
        info = face["glyphs"].get(char) or face["glyphs"].get("?")
        if info is None:
            continue
        if previous is not None:
            x += face["kern"].get(previous, {}).get(char, 0.0)
        if "page" in info:
            page = face["pages"][info["page"] - 1]
            glyph = page[info["y"] : info["y"] + info["h"], info["x"] : info["x"] + info["w"]]
            offset = face["digit"] / 2 - (info["ox"] + info["w"] / 2) if tabular and char.isdigit() else 0.0
            gx, gy = int(round(x + offset + info["ox"])), int(round(baseline - info["top"]))
            region = img[gy : gy + info["h"], gx : gx + info["w"]]
            gh, gw = region.shape[:2]
            a = glyph[:gh, :gw, 3:4]
            region[..., :3] = region[..., :3] * (1 - a) + np.array(color) / 255 * a
        x += face["digit"] if tabular and char.isdigit() else info["adv"]
        previous = char
    return x


def preview(faces, samples):
    """Sample lines in each face on a dark page, for checking by eye."""
    height = 40 + sum(int(faces[f]["em"] * 1.3) for f, _, _ in samples)
    img = np.zeros((height, 1500, 4), np.float32)
    img[..., :3] = np.array([15, 17, 21]) / 255
    img[..., 3] = 1
    y = 20
    for face_name, text, tabular in samples:
        face = faces[face_name]
        draw_text(img, face, text, 24.0, y + face["ascent"], (244, 245, 247), tabular)
        y += int(face["em"] * 1.3)
    os.makedirs(PREVIEWS, exist_ok=True)
    return png.write(os.path.join(PREVIEWS, "ui_fonts.png"), img)


def main():
    os.makedirs(TEXTURES, exist_ok=True)
    faces = {}
    for name, spec in FACES.items():
        faces[name] = build_face(name, spec)
        count = len(faces[name]["glyphs"])
        pairs = sum(len(v) for v in faces[name]["kern"].values())
        print(f"[fonts] {name}: {count} glyphs on {len(faces[name]['atlases'])} atlas(es), {pairs} kerning pairs")
    print("[fonts]", write_luau(faces))
    print(
        "[fonts]",
        preview(
            faces,
            [
                ("Title", "Death's Gambit   Diavolo Wins   Falcon", False),
                ("Title", "The Bureau Wins   Voted Out   0123456789", False),
                ("Head", "INVESTIGATION   READY   Operative   AVATAR To Wa", False),
                ("Head", "01:24   00:08   +340 XP   2,360   4 / 6   0123456789", True),
                ("Semi", "Name pending   Death's Manual   Quests Shop Party", False),
                ("RnLight", "CaSe ClOsEd   Death's Gambit", False),
                ("RnMedium", "CaSe ClOsEd   Death's Gambit", False),
            ],
        ),
    )


if __name__ == "__main__":
    main()
