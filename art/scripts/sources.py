"""The photographed source material the game's surfaces are made from, and where it came from.

Everything here is free to use: material scans and sky panoramas are CC0 (ambientCG, Poly Haven),
typefaces are under the SIL Open Font License (Google Fonts), old prints carry the Public Domain Mark
(Wellcome Collection). Nothing is made by an image generator.
The raw files are large and stay out of git (art/source/); art/sources.json records every file with
its address, size and checksum, so the same set can be fetched again.

Run (plain Python, no Blender needed):
    python art/scripts/sources.py list     write art/sources.json from the catalogues (downloads nothing)
    python art/scripts/sources.py fetch    download what the manifest lists into art/source/, and verify it
Either takes one group's name after it (textures, skies, fonts, engravings) to do only that group.
"""
import hashlib
import json
import os
import sys
import urllib.parse
import urllib.request

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
MANIFEST = os.path.join(ROOT, "art", "sources.json")
AGENT = {"User-Agent": "DeathsGambit-art-pipeline"}


def _source():
    """art/source: here, or in the main checkout when this is a git worktree below it (as common.source)."""
    folder, probe = os.path.join(ROOT, "art", "source"), ROOT
    while not os.path.isdir(folder) and os.path.dirname(probe) != probe:
        probe = os.path.dirname(probe)
        folder = os.path.join(probe, "art", "source")
    return folder if os.path.isdir(folder) else os.path.join(ROOT, "art", "source")


SOURCE = _source()

# Poly Haven texture id -> what the game uses it for.
POLYHAVEN = {
    "moon_01": "Ash (the Grey Realm's ground)",
    "dry_mud_field_001": "AshCracked",
    "rock_face_03": "RockGrey (cliffs, spires)",
    "monastery_stone_floor": "RuinFlag",
    "medieval_blocks_03": "RuinStone, Stone",
    "concrete_floor_worn_001": "ConcreteDark, concrete floors",
    "concrete_wall_008": "Concrete (weathered walls)",
    "metal_plate": "MetalFloor",
    "wood_floor": "WoodFloor",
    "dark_wooden_planks": "WoodFloorDark",
    "rectangular_parquet": "Parquet",
    "herringbone_parquet": "WoodHerringbone",
    "walnut_veneer_02": "WoodPanel, dark furniture",
    "oak_veneer_01": "Wood, CeilingSlats, light furniture",
    "wood_table_001": "varnished desk and table tops",
    "beige_wall_001": "PlasterLight, PlasterGrey, PlasterDark, PlasterCream, PlasterGreen, CeilingPlaster",
    "white_plaster_02": "aged plaster (back rooms, old halls)",
    "plaster_grey_04": "outside render",
    "linoleum_brown": "Linoleum, VinylLab, VinylClinic",
    "rubber_tiles": "Rubber, gym floor",
    "marble_01": "MarbleWhite",
    "granite_tile": "MarbleBlack",
    "floor_tiles_06": "TileChecker",
    "long_white_tiles": "TileMetroGrey (station walls)",
    "interior_tiles": "TileMetroFloor",
    "clean_asphalt": "AsphaltWet (Tokyo's roads)",
    "asphalt_02": "Asphalt (Campus)",
    "asphalt_snow": "SnowThin",
    "red_brick_03": "BrickDark",
    "brick_wall_001": "BrickRed",
    "exterior_wall_cladding_02": "FacadeTile",
    "concrete_tile_facade": "FacadeTileGrey",
    "painted_metal_shutter": "Shutter",
    "roof_slates_03": "Slate",
    "snow_02": "Snow, Snow2",
    "snow_03": "slush at doorways",
    "tatami_mat": "Tatami",
    "brick_pavement_02": "PaversWarm",
    "blue_metal_plate": "painted metal (props, trims)",
    "metal_plate_02": "BlackMetal, DarkMetal, Steel",
    "brown_planks_05": "painted wood trims",
    "sakura_bark": "Bark (Tokyo's cherries)",
    "pine_bark": "Bark (Campus)",
    "poly_wool_herringbone": "suits, Fabric",
    "rough_linen": "shirts, canvas, TarpBlue",
    "floral_jacquard": "Damask, Wallpaper",
    "book_pattern": "notebook and manual covers",
    "velour_velvet": "FabricRed, karaoke seats",
    "brown_leather": "Leather",
    "bamboo_wall": "Bamboo",
    "polystyrene": "Ceiling, CeilingDark (board tiles)",
}
# ambientCG asset id -> use. Only photographed assets (no procedural ones).
AMBIENTCG = {
    "Rock050": "the Grey Realm's dark basalt",
    "Carpet015": "CarpetRed, CarpetGrey, CarpetNavy, CarpetPurple, CarpetGreen",
    "Carpet016": "CarpetTile, CarpetTileBlue",
    "Concrete048": "clean concrete (Bureau HQ)",
    "Terrazzo019L": "Terrazzo, TerrazzoDark",
    "Tiles002": "TileWhite",
    "Snow006": "SnowPath (trodden snow)",
    "Snow014": "Ice",
    "PavingStones136": "PaversWet, PaversWarmWet",
    "Paper001": "Paper",
    "Paper003": "creased paper (posters, notices)",
    "Paper005": "cardboard",
    "Plastic001": "plastics on props",
}
# Poly Haven sky panorama id -> the map it is for (4k .hdr).
SKIES = {
    "kloppenheim_07_puresky": "Tokyo (overcast night)",
    "kloofendal_overcast_puresky": "Campus (snow sky)",
    "overcast_soil_puresky": "Bureau HQ (storm cloud)",
}
# Google Fonts folder -> (files, use).
FONTS = {
    "notosansjp": (["NotoSansJP[wght].ttf"], "plain signs, notices"),
    "notoserifjp": (["NotoSerifJP[wght].ttf"], "formal notices, older shops"),
    "delagothicone": (["DelaGothicOne-Regular.ttf"], "loud shopfronts"),
    "yujisyuku": (["YujiSyuku-Regular.ttf"], "traditional shops"),
    "zenmarugothic": (["ZenMaruGothic-Bold.ttf"], "friendly shops, clinics"),
    "rocknrollone": (["RocknRollOne-Regular.ttf"], "karaoke, arcade"),
    "oswald": (["Oswald[wght].ttf"], "Latin condensed headings"),
    "bebasneue": (["BebasNeue-Regular.ttf"], "Latin poster capitals"),
}
# Old prints, key -> (the whole picture's address, the page that describes it, use). From the Wellcome
# Collection, under the Public Domain Mark. Its image server makes each file on request, so there is
# no catalogue size or checksum to check a download against: both are recorded at the first fetch.
ENGRAVINGS = {
    "skull_anterior": (
        "https://iiif.wellcomecollection.org/image/V0007916/full/max/0/default.jpg",
        "https://wellcomecollection.org/works/zs6gser7",
        "Skull: anterior view. Line engraving. (the skull on the cover of Death's Manual)",
    ),
    "gamelin_skull": (
        "https://iiif.wellcomecollection.org/image/b20265396_epb_g_os_f_2270_0059.JP2/full/max/0/default.jpg",
        "https://wellcomecollection.org/works/u9ecexq2/items?canvas=59",
        "J. Gamelin, Nouveau recueil d'osteologie et de myologie, 1779: skull with its jaw dropped"
        " (second study for the cover of Death's Manual)",
    ),
}
MAPS = ("Diffuse", "nor_gl", "Rough", "Displacement", "AO", "Metal")


def get_json(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers=AGENT), timeout=120) as reply:
        return json.load(reply)


def polyhaven_files(key):
    data = get_json(f"https://api.polyhaven.com/files/{key}")
    files = []
    for name, by_res in data.items():
        wanted = name in MAPS or name.lower().startswith(("col", "diff"))
        entry = by_res.get("2k", {}).get("jpg") if wanted and isinstance(by_res, dict) else None
        if entry:
            files.append({"name": os.path.basename(urllib.parse.urlparse(entry["url"]).path), "url": entry["url"],
                          "bytes": entry["size"], "md5": entry["md5"]})
    return sorted(files, key=lambda f: f["name"])


def ambientcg_file(key):
    data = get_json(f"https://ambientcg.com/api/v2/full_json?id={key}&include=downloadData")
    asset = data["foundAssets"][0]
    if asset["creationMethod"] == "PBRProcedural":
        raise SystemExit(f"{key} is procedural, not photographed")
    for d in asset["downloadFolders"]["default"]["downloadFiletypeCategories"]["zip"]["downloads"]:
        if d["attribute"] == "2K-JPG":
            return [{"name": d["fileName"], "url": d["fullDownloadPath"], "bytes": d["size"]}]
    raise SystemExit(f"{key} has no 2K-JPG download")


def sky_file(key):
    entry = get_json(f"https://api.polyhaven.com/files/{key}")["hdri"]["4k"]["hdr"]
    return [{"name": os.path.basename(urllib.parse.urlparse(entry["url"]).path), "url": entry["url"],
             "bytes": entry["size"], "md5": entry["md5"]}]


def font_files(folder, names):
    listing = get_json(f"https://api.github.com/repos/google/fonts/contents/ofl/{folder}")
    files = []
    for item in listing:
        if item["name"] in names or item["name"] == "OFL.txt":
            files.append({"name": item["name"], "url": item["download_url"], "bytes": item["size"]})
    return files


def _textures():
    out = {}
    for key, use in POLYHAVEN.items():
        out[key] = {"source": "Poly Haven", "page": f"https://polyhaven.com/a/{key}",
                    "licence": "CC0-1.0", "use": use, "files": polyhaven_files(key)}
    for key, use in AMBIENTCG.items():
        out[key] = {"source": "ambientCG", "page": f"https://ambientcg.com/a/{key}",
                    "licence": "CC0-1.0", "use": use, "files": ambientcg_file(key)}
    return out


def _skies():
    return {key: {"source": "Poly Haven", "page": f"https://polyhaven.com/a/{key}",
                  "licence": "CC0-1.0", "use": use, "files": sky_file(key)} for key, use in SKIES.items()}


def _fonts():
    return {folder: {"source": "Google Fonts", "page": f"https://github.com/google/fonts/tree/main/ofl/{folder}",
                     "licence": "OFL-1.1", "use": use, "files": font_files(folder, names)}
            for folder, (names, use) in FONTS.items()}


def _engravings(recorded):
    out = {}
    for key, (url, page, use) in ENGRAVINGS.items():
        entry = {"name": key + ".jpg", "url": url}
        # (What the first fetch recorded stays: there is no catalogue to read it from again.)
        for old in recorded.get(key, {}).get("files", []):
            if old.get("url") == url:
                entry.update({k: old[k] for k in ("bytes", "sha256") if k in old})
        out[key] = {"source": "Wellcome Collection", "page": page, "licence": "Public Domain Mark 1.0",
                    "credit": "Wellcome Collection", "use": use, "files": [entry]}
    return out


GROUPS = ("textures", "skies", "fonts", "engravings")


def build(recorded=None, only=None):
    """The manifest from the catalogues: all of it, or `recorded` with the group `only` made again."""
    recorded = recorded or {}
    makers = {"textures": _textures, "skies": _skies, "fonts": _fonts,
              "engravings": lambda: _engravings(recorded.get("engravings", {}))}
    return {group: makers[group]() if only in (None, group) else recorded.get(group, {}) for group in GROUPS}


def summary(manifest):
    total = 0
    for group, items in manifest.items():
        size = sum(f.get("bytes", 0) for item in items.values() for f in item["files"])
        count = sum(len(item["files"]) for item in items.values())
        total += size
        print(f"{group:9} {len(items):3} sets {count:4} files {size / 2**20:8.1f} MB")
    print(f"{'total':9} {'':22} {total / 2**20:8.1f} MB")


def fetch(manifest, only=None):
    for group, items in manifest.items():
        if only not in (None, group):
            continue
        for key, item in items.items():
            folder = os.path.join(SOURCE, group, key)
            os.makedirs(folder, exist_ok=True)
            for f in item["files"]:
                path = os.path.join(folder, f["name"])
                if not (os.path.exists(path) and os.path.getsize(path) == f.get("bytes", os.path.getsize(path))):
                    print("fetch", group, key, f["name"])
                    with urllib.request.urlopen(urllib.request.Request(f["url"], headers=AGENT), timeout=600) as reply:
                        data = reply.read()
                    if "bytes" not in f:
                        # A file its server makes on request (an old print): this fetch is the record.
                        f["bytes"] = len(data)
                    elif len(data) != f["bytes"] and group == "engravings":
                        # Made again by its server, a little differently: say so and keep the new record.
                        print(f"{f['name']}: {len(data)} bytes now, {f['bytes']} at the first fetch")
                        f["bytes"] = len(data)
                        f.pop("sha256", None)
                    if len(data) != f["bytes"]:
                        raise SystemExit(f"{f['name']}: got {len(data)} bytes, the manifest says {f['bytes']}")
                    if f.get("md5") and hashlib.md5(data).hexdigest() != f["md5"]:
                        raise SystemExit(f"{f['name']}: checksum differs from the catalogue's")
                    with open(path, "wb") as out:
                        out.write(data)
                f.setdefault("bytes", os.path.getsize(path))
                if not f.get("sha256"):
                    with open(path, "rb") as src:
                        f["sha256"] = hashlib.sha256(src.read()).hexdigest()
    return manifest


def save(manifest):
    with open(MANIFEST, "w", encoding="utf-8", newline="\n") as f:
        json.dump(manifest, f, indent=1)
        f.write("\n")


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    only = sys.argv[2] if len(sys.argv) > 2 else None
    if only not in (None, *GROUPS):
        print(__doc__)
        return 2
    recorded = {}
    if os.path.exists(MANIFEST):
        with open(MANIFEST, encoding="utf-8") as f:
            recorded = json.load(f)
    if mode == "list":
        manifest = build(recorded, only)
        save(manifest)
        summary(manifest)
    elif mode == "fetch":
        manifest = recorded
        save(fetch(manifest, only))
        summary(manifest)
    else:
        print(__doc__)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
