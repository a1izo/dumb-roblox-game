"""Fails when a scene has become heavier than the recorded baseline.

A scene is what a player's device holds while they stand in it: the venue's map import, the
venue's own prop set and the Core prop set. Three things are measured, all from the files that
get imported (art/export):

    pixels     every texture the scene's FBX files embed, counted once, in megapixels
    megabytes  the size of those FBX files
    triangles  the map's own (stats in src/server/Maps/Scenes/<Venue>/init.luau)

Pixels and megabytes may not grow at all. Triangles may grow by the venue's allowance (ALLOW):
edges and trims cost a few, and Tokyo, the heaviest map, gets none.

Growth the owner said yes to is written in art/budget.json's "exceptions" (what, when, how many
megapixels and megabytes, in every scene) and allowed on top of the baseline. An exception that names a
"venue" is for that scene alone, and may also allow its triangles to grow by a further share ("triangles").
Recording a new baseline takes them in: they stay in the file, marked absorbed, as the record of the yes.

Run: python scripts/budget.py            compare with art/budget.json, exit 1 when over
     python scripts/budget.py record     write art/budget.json from what is exported now
"""
import json
import pathlib
import re
import struct
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
EXPORT = ROOT / "art" / "export"
TEXTURES = (EXPORT / "textures", EXPORT / "textures" / "maps")
SCENES = ROOT / "src" / "server" / "Maps" / "Scenes"
BASELINE = ROOT / "art" / "budget.json"

VENUES = ("Lobby", "Meeting", "Agency", "Campus", "Tokyo")
# How much a venue's triangle count may grow over the baseline.
ALLOW = {"Lobby": 0.10, "Meeting": 0.10, "Agency": 0.10, "Campus": 0.10, "Tokyo": 0.0}

IMAGE_NAME = re.compile(rb"([A-Za-z0-9_]+)\.(png|jpg)")
TRIANGLES = re.compile(r"triangles = (\d+)")
SOF = set(range(0xC0, 0xD0)) - {0xC4, 0xC8, 0xCC}


def image_size(path):
    """(width, height) of a PNG or JPEG, read from its header."""
    data = path.read_bytes()
    if data[:8] == b"\x89PNG\r\n\x1a\n":
        return struct.unpack(">II", data[16:24])
    at = 2
    while at + 9 < len(data):
        if data[at] != 0xFF:
            at += 1
            continue
        marker = data[at + 1]
        if marker in SOF:
            height, width = struct.unpack(">HH", data[at + 5 : at + 9])
            return width, height
        if marker == 0xFF or 0xD0 <= marker <= 0xD9:
            at += 2
            continue
        at += 2 + struct.unpack(">H", data[at + 2 : at + 4])[0]
    raise ValueError(f"cannot read the size of {path}")


def texture_path(name):
    for folder in TEXTURES:
        path = folder / name
        if path.exists():
            return path
    return None


def embedded(fbx):
    """Names of the texture files an FBX embeds (the ones that still exist in art/export/textures)."""
    names = {f"{m.group(1).decode()}.{m.group(2).decode()}" for m in IMAGE_NAME.finditer(fbx.read_bytes())}
    return {name for name in names if texture_path(name)}


def measure():
    out = {}
    for venue in VENUES:
        files = [EXPORT / f"DeathsGambitMaps_{venue}.fbx", EXPORT / f"DeathsGambitModels_{venue}.fbx",
                 EXPORT / "DeathsGambitModels_Core.fbx"]
        textures = set()
        for fbx in files:
            textures |= embedded(fbx)
        pixels = 0
        for name in textures:
            width, height = image_size(texture_path(name))
            pixels += width * height
        stats = (SCENES / venue / "init.luau").read_text(encoding="utf-8")
        out[venue] = {
            "megapixels": round(pixels / 1e6, 2),
            "megabytes": round(sum(f.stat().st_size for f in files) / 2**20, 2),
            "triangles": int(TRIANGLES.search(stats).group(1)),
            "textures": len(textures),
        }
    return out


def main():
    now = measure()
    if sys.argv[1:] == ["record"]:
        old = json.loads(BASELINE.read_text(encoding="utf-8")) if BASELINE.exists() else {}
        record = dict(now)
        exceptions = [dict(e, absorbed=True) for e in old.get("exceptions", [])]
        if exceptions:
            record["exceptions"] = exceptions
        BASELINE.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8", newline="\n")
        print(f"Recorded {BASELINE.relative_to(ROOT).as_posix()}")
    base = json.loads(BASELINE.read_text(encoding="utf-8"))
    allowed = [e for e in base.get("exceptions", []) if not e.get("absorbed")]
    over = []
    print(f"{'':8}{'megapixels':>20}{'megabytes':>20}{'triangles':>22}{'textures':>12}")
    for venue in VENUES:
        was, cur = base[venue], now[venue]
        mine = [e for e in allowed if e.get("venue") in (None, venue)]
        limits = {
            "megapixels": round(was["megapixels"] + sum(e["megapixels"] for e in mine), 2),
            "megabytes": round(was["megabytes"] + sum(e["megabytes"] for e in mine), 2),
            "triangles": int(was["triangles"] * (1 + ALLOW[venue] + sum(e.get("triangles", 0) for e in mine))),
        }
        cells = []
        for key, width in (("megapixels", 20), ("megabytes", 20), ("triangles", 22)):
            mark = ""
            if cur[key] > limits[key]:
                mark = " OVER"
                over.append(f"{venue}: {key} {cur[key]} is over {limits[key]}")
            cells.append(f"{cur[key]} / {limits[key]}{mark}".rjust(width))
        print(f"{venue:8}{''.join(cells)}{cur['textures']:>12}")
    for e in allowed:
        where = f"in the {e['venue']} scene" if e.get("venue") else "in every scene"
        extra = f", triangles +{round(e['triangles'] * 100)}%" if e.get("triangles") else ""
        print(f"\nAllowed on top (the owner's yes, {e['approved']}): {e['what']}, "
              f"+{e['megapixels']} megapixels and +{e['megabytes']} megabytes{extra} {where}")
    if over:
        print("\nOver budget:\n  " + "\n  ".join(over))
        return 1
    print("\nEvery scene is within its budget (now / allowed).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
