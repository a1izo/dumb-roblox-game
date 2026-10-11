"""The photographed source material the game's surfaces are made from, and where it came from.

Everything here is free to use: material scans and sky panoramas are CC0 (ambientCG, Poly Haven),
typefaces are under the SIL Open Font License (Google Fonts). Nothing is made by an image generator.
The raw files are large and stay out of git (art/source/); art/sources.json records every file with
its address, size and checksum, so the same set can be fetched again.

Run (plain Python, no Blender needed):
    python art/scripts/sources.py list     write art/sources.json from the catalogues (downloads nothing)
    python art/scripts/sources.py fetch    download what the manifest lists into art/source/, and verify it
"""
import hashlib
import json
import os
import sys
import urllib.parse
import urllib.request

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
MANIFEST = os.path.join(ROOT, "art", "sources.json")
SOURCE = os.path.join(ROOT, "art", "source")
AGENT = {"User-Agent": "DeathsGambit-art-pipeline"}

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
    "beige_wall_001": "PlasterLight, PlasterGrey, PlasterDark, CeilingPlaster",
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


def build():
    out = {"textures": {}, "skies": {}, "fonts": {}}
    for key, use in POLYHAVEN.items():
        out["textures"][key] = {"source": "Poly Haven", "page": f"https://polyhaven.com/a/{key}",
                                "licence": "CC0-1.0", "use": use, "files": polyhaven_files(key)}
    for key, use in AMBIENTCG.items():
        out["textures"][key] = {"source": "ambientCG", "page": f"https://ambientcg.com/a/{key}",
                                "licence": "CC0-1.0", "use": use, "files": ambientcg_file(key)}
    for key, use in SKIES.items():
        out["skies"][key] = {"source": "Poly Haven", "page": f"https://polyhaven.com/a/{key}",
                             "licence": "CC0-1.0", "use": use, "files": sky_file(key)}
    for folder, (names, use) in FONTS.items():
        out["fonts"][folder] = {"source": "Google Fonts", "page": f"https://github.com/google/fonts/tree/main/ofl/{folder}",
                                "licence": "OFL-1.1", "use": use, "files": font_files(folder, names)}
    return out


def summary(manifest):
    total = 0
    for group, items in manifest.items():
        size = sum(f["bytes"] for item in items.values() for f in item["files"])
        count = sum(len(item["files"]) for item in items.values())
        total += size
        print(f"{group:9} {len(items):3} sets {count:4} files {size / 2**20:8.1f} MB")
    print(f"{'total':9} {'':22} {total / 2**20:8.1f} MB")


def fetch(manifest):
    for group, items in manifest.items():
        for key, item in items.items():
            folder = os.path.join(SOURCE, group, key)
            os.makedirs(folder, exist_ok=True)
            for f in item["files"]:
                path = os.path.join(folder, f["name"])
                if not (os.path.exists(path) and os.path.getsize(path) == f["bytes"]):
                    print("fetch", group, key, f["name"])
                    with urllib.request.urlopen(urllib.request.Request(f["url"], headers=AGENT), timeout=600) as reply:
                        data = reply.read()
                    if len(data) != f["bytes"]:
                        raise SystemExit(f"{f['name']}: got {len(data)} bytes, the manifest says {f['bytes']}")
                    if f.get("md5") and hashlib.md5(data).hexdigest() != f["md5"]:
                        raise SystemExit(f"{f['name']}: checksum differs from the catalogue's")
                    with open(path, "wb") as out:
                        out.write(data)
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
    if mode == "list":
        manifest = build()
        save(manifest)
        summary(manifest)
    elif mode == "fetch":
        with open(MANIFEST, encoding="utf-8") as f:
            manifest = json.load(f)
        save(fetch(manifest))
        summary(manifest)
    else:
        print(__doc__)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
