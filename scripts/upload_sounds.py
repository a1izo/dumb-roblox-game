"""Uploads the ready sound files in art/audio to Roblox and writes each one's new id into src/shared/Assets.luau.

It needs an Open Cloud API key of your own (Creator Hub > Open Cloud > API Keys > Create: the Assets API with Read
and Write, made on the account that owns the game, so the sounds play in it). The key is asked for at a hidden
prompt (or read from the ROBLOX_API_KEY variable) and never stored or printed.

Run from the repo:
    python scripts/upload_sounds.py             every ready file whose slot is still empty
    python scripts/upload_sounds.py --dry-run   what it would upload; nothing is sent
    python scripts/upload_sounds.py --creator 123456   the uploading account's user id (default: the game's owner)

A slot that already has an id is left alone, and each id is written as soon as its upload finishes, so a run that
stops halfway can simply be run again. Audio uploads count toward the account's monthly audio upload limit.
"""
import getpass
import json
import os
import pathlib
import re
import sys
import time
import urllib.error
import urllib.request
import uuid

ROOT = pathlib.Path(__file__).resolve().parent.parent
ASSETS = ROOT / "src" / "shared" / "Assets.luau"
AUDIO = ROOT / "art" / "audio"
OWNER = "409214934"  # realALEXTEM, who owns the Death's Gambit universe (10767766818)
API = "https://apis.roblox.com/assets/v1"

# Assets.sfx slot -> its file in art/audio (made by art/scripts/audio/*).
FILES = {
    "realmWind": "realm_wind", "realmDrone": "realm_drone", "realmRumble": "realm_rumble",
    "realmRocks": "realm_rocks", "realmStone1": "realm_stone1", "realmStone2": "realm_stone2",
    "realmMetal1": "realm_metal1", "realmMetal2": "realm_metal2", "realmFar1": "realm_far1",
    "realmFar2": "realm_far2", "gameRune": "game_rune", "gameWrong": "game_wrong",
    "gameCheckpoint": "game_checkpoint", "gameFinish": "game_finish", "gameThrow": "game_throw",
    "gameFall": "game_fall", "gameBellToll": "game_bell_toll", "gameDiveWind": "game_dive_wind",
    "gameDiveCrash": "game_dive_crash", "gameDiveFall": "game_dive_fall", "gameDiveString": "game_dive_string",
    "gameDiveImpact": "game_dive_impact", "trialChime": "trial_chime", "typewriter": "style_typewriter",
    "knifeScrape": "style_knife", "crows": "style_crows", "stoneCrack": "style_stone",
    "stringsSnap": "style_strings",
}


def slot(text, key):
    """(start, end) of the slot's `id = "..."` value in Assets.luau, and the id there now."""
    start = text.index("Assets.sfx = {")
    entry = re.compile(r"\n\t" + key + r" = \{").search(text, start)
    if not entry:
        sys.exit(f"no slot {key} in Assets.sfx")
    found = re.compile(r'\bid = "(\d*)"').search(text, entry.end())
    following = re.compile(r"\n\t[A-Za-z0-9_]+ = \{").search(text, entry.end())
    if not found or (following and found.start() > following.start()):
        sys.exit(f"slot {key} has no id field")
    return found.start(1), found.end(1), found[1]


def ref(text, key):
    start = text.index("Assets.sfx = {")
    entry = re.compile(r"\n\t" + key + r" = \{").search(text, start)
    found = re.compile(r'ref = "([^"]*)"').search(text, entry.end())
    return found[1] if found else key


def request(method, url, key, body=None, content_type=None):
    req = urllib.request.Request(url, data=body, method=method)
    req.add_header("x-api-key", key)
    if content_type:
        req.add_header("Content-Type", content_type)
    try:
        with urllib.request.urlopen(req, timeout=120) as response:
            return json.loads(response.read() or b"{}")
    except urllib.error.HTTPError as err:
        detail = err.read().decode("utf-8", "replace")[:400]
        if err.code in (401, 403):
            sys.exit(f"Roblox refused the key ({err.code}): {detail}\n"
                     "The key needs the Assets API (Read and Write) and must belong to the --creator account.")
        raise RuntimeError(f"{err.code}: {detail}") from None


def upload(path, name, description, creator, key):
    boundary = uuid.uuid4().hex
    meta = {
        "assetType": "Audio",
        "displayName": name[:50],
        "description": description[:1000],
        "creationContext": {"creator": {"userId": creator}},
    }
    parts = [
        f'--{boundary}\r\nContent-Disposition: form-data; name="request"\r\n'
        f"Content-Type: application/json\r\n\r\n{json.dumps(meta)}\r\n".encode(),
        f'--{boundary}\r\nContent-Disposition: form-data; name="fileContent"; filename="{path.name}"\r\n'
        "Content-Type: audio/wav\r\n\r\n".encode(),
        path.read_bytes(),
        f"\r\n--{boundary}--\r\n".encode(),
    ]
    operation = request("POST", f"{API}/assets", key, b"".join(parts), f"multipart/form-data; boundary={boundary}")
    op_id = operation.get("operationId") or operation.get("path", "").split("/")[-1]
    for _ in range(60):
        if operation.get("done"):
            asset = operation.get("response", {})
            asset_id = asset.get("assetId") or asset.get("path", "").split("/")[-1]
            if asset_id:
                return str(asset_id)
            raise RuntimeError(f"finished without an id: {json.dumps(operation)[:300]}")
        time.sleep(1.5)
        operation = request("GET", f"{API}/operations/{op_id}", key)
    raise RuntimeError("still processing after 90 s; run again later")


def main():
    args = sys.argv[1:]
    dry = "--dry-run" in args
    creator = args[args.index("--creator") + 1] if "--creator" in args else OWNER
    text = ASSETS.read_text(encoding="utf-8")
    todo = []
    for key, stem in FILES.items():
        path = AUDIO / f"{stem}.wav"
        if not path.exists():
            sys.exit(f"missing {path}")
        if slot(text, key)[2]:
            print(f"  {key:16} has an id already")
            continue
        todo.append((key, path))
    print(f"{len(todo)} to upload as user {creator}" + (" (dry run)" if dry else ""))
    if dry or not todo:
        for key, path in todo:
            print(f"  {key:16} <- {path.relative_to(ROOT)}")
        return
    key_text = os.environ.get("ROBLOX_API_KEY") or getpass.getpass("Open Cloud API key (hidden): ").strip()
    if not key_text:
        sys.exit("no key given")
    done = 0
    for name, path in todo:
        text = ASSETS.read_text(encoding="utf-8")
        try:
            asset_id = upload(path, f"Death's Gambit {name}", ref(text, name), creator, key_text)
        except RuntimeError as err:
            print(f"  {name:16} FAILED {err}")
            continue
        start, end, _ = slot(text, name)
        ASSETS.write_text(text[:start] + asset_id + text[end:], encoding="utf-8", newline="")
        done += 1
        print(f"  {name:16} {asset_id}")
    print(f"{done} of {len(todo)} uploaded; their ids are in src/shared/Assets.luau")


if __name__ == "__main__":
    main()
