"""Builds emote.project.json: the audit worktree's default.project.json with absolute paths, the harness
attribute on Workspace and the two probe scripts (whole-game audit session 3e64b245)."""
import json
import os
import sys

here = os.path.dirname(os.path.abspath(__file__))
repo = os.environ.get("AUDIT_REPO") or r"C:\Users\negru\Documents\Lgame\.claude\worktrees\shop-overhaul"
probe = sys.argv[1] if len(sys.argv) > 1 else "Probe"
project = json.load(open(os.path.join(repo, "default.project.json"), encoding="utf-8"))


def fix(node):
    if isinstance(node, dict):
        for key, value in list(node.items()):
            if key == "$path" and isinstance(value, str):
                node[key] = os.path.join(repo, value).replace("\\", "/")
            else:
                fix(value)


fix(project["tree"])
attrs = project["tree"]["Workspace"].setdefault("$attributes", {})
attrs["DGEmoteHarness"] = True
for extra in sys.argv[2:]:
    # (Name=value: a string attribute; Name alone: true)
    if "=" in extra:
        key, value = extra.split("=", 1)
        attrs[key] = value
    else:
        attrs[extra] = True
# (a place made from Roblox's template has its spawn pad at the world's middle: the game must take it away)
project["tree"]["Workspace"]["SpawnLocation"] = {
    "$className": "SpawnLocation",
    "$properties": {"Anchored": {"Bool": True}, "Size": {"Vector3": [12, 1, 12]},
                    "CFrame": {"CFrame": {"position": [0, 0.5, 0],
                                          "orientation": [[1, 0, 0], [0, 1, 0], [0, 0, 1]]}}}}
# (the VFX textures packed by pack_textures.py, for the probes to load as EditableImages)
if os.path.isdir(os.path.join(here, "vfxtex")):
    project["tree"]["ReplicatedStorage"]["DGVfxTex"] = {"$path": os.path.join(here, "vfxtex").replace("\\", "/")}
if os.path.isdir(os.path.join(here, "vfxmesh")):
    project["tree"]["ReplicatedStorage"]["DGVfxMesh"] = {"$path": os.path.join(here, "vfxmesh").replace("\\", "/")}
project["tree"]["ServerScriptService"]["DGEmoteProbe"] = {
    "$path": os.path.join(here, probe + ".server.luau").replace("\\", "/")}
project["tree"]["StarterPlayer"]["StarterPlayerScripts"]["DGEmoteProbeClient"] = {
    "$path": os.path.join(here, probe + "Client.client.luau").replace("\\", "/")}
out = os.path.join(here, "emote.project.json")
with open(out, "w", encoding="utf-8", newline="\n") as f:
    json.dump(project, f, indent=2)
print("ok", out, probe)
