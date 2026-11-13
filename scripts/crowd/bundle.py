"""Builds dg_specs.rbxm: the Tokyo crowd's modules, specs and map data straight from the repo, into the content folder of
the newest Roblox Studio on this machine, so that a running Studio can load them with

    game:GetObjects("rbxasset://dg_specs.rbxm")[1]

from execute_luau in the Edit datamodel (run.luau runs the specs, watch.luau measures the crowd). Nothing is written
into the shared Team Create place: the objects are never parented to the game, and the file lives outside the repo.

    python scripts/crowd/bundle.py            (writes the bundle, prints where)

The place's own scripts are older than the repo's (Rojo syncs are the owner's), so this is the way to run the repo's
CrowdSim and MapContract specs and to watch the repo's sim without a play test. See
docs/agent-memory/spec-bundle-via-rbxasset.md."""

import json
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))


def path(*parts):
    return os.path.join(REPO, *parts).replace("\\", "/")


def stub(layout):
    """A map module whose layout() is the venue's generated layout (what SceneMap.layout returns)."""
    return {"$className": "ModuleScript",
            "$properties": {"Source": f"local L = require(script.Parent.{layout})\nreturn {{ layout = function() return L end }}\n"}}


def project():
    maps = {"$className": "Folder"}
    maps["MapContract"] = {"$path": path("src/server/Maps/MapContract.luau")}
    for venue in ("Agency", "Campus", "Tokyo"):
        maps[f"{venue}Layout"] = {"$path": path("src/server/Maps/Scenes", venue, "Layout")}
    maps["TaskForceHQ"] = stub("AgencyLayout")
    maps["UniversityCampus"] = stub("CampusLayout")
    maps["TokyoDistrict"] = stub("TokyoLayout")
    # (the specs reach the sim as Maps.Mechanics.TokyoDistrict.CrowdSim; add a module here when the sim grows one)
    district = {"$className": "Folder"}
    folder = path("src/server/Maps/Mechanics/TokyoDistrict")
    for name in sorted(os.listdir(folder)):
        if name in ("CrowdSim.luau", "CrowdRoutes.luau", "CrowdFlow.luau"):
            district[name[:-len(".luau")]] = {"$path": path("src/server/Maps/Mechanics/TokyoDistrict", name)}
    maps["Mechanics"] = {"$className": "Folder", "TokyoDistrict": district}
    tests = {"$className": "Folder", "TestRunner": {"$path": path("src/server/Tests/TestRunner.luau")}}
    for name in ("CrowdSim.spec", "MapContract.spec"):
        tests[name] = {"$path": path("src/server/Tests", name + ".luau")}
    shared = {"$className": "Folder", "ScrambleCycle": {"$path": path("src/shared/ScrambleCycle.luau")}}
    tools = {"$className": "Folder"}
    for name in ("run", "watch"):
        tools[name] = {"$path": path("scripts/crowd", name + ".luau")}
    # (the client's crowd drawer, for a play test through a copy parented beside the game's own: see
    # docs/agent-memory/tokyo-crowd-2026-11.md)
    client = {"$className": "Folder", "World": {"$className": "Folder", "Crowd": {"$path": path("src/client/World/Crowd.luau")}}}
    return {"name": "DGSpecs", "tree": {"$className": "Folder", "Shared": shared, "Tools": tools, "Client": client,
                                        "Server": {"$className": "Folder", "Maps": maps, "Tests": tests}}}


def studio_content():
    base = os.path.join(os.environ["LOCALAPPDATA"], "Roblox", "Versions")
    found = [os.path.join(base, d) for d in os.listdir(base)
             if os.path.isfile(os.path.join(base, d, "RobloxStudioBeta.exe"))]
    if not found:
        sys.exit("no Roblox Studio under " + base)
    newest = max(found, key=lambda d: os.path.getmtime(os.path.join(d, "RobloxStudioBeta.exe")))
    return os.path.join(newest, "content")


def main():
    out = os.path.join(studio_content(), "dg_specs.rbxm")
    with tempfile.TemporaryDirectory() as tmp:
        spec = os.path.join(tmp, "specs.project.json")
        with open(spec, "w", encoding="utf-8", newline="\n") as f:
            json.dump(project(), f, indent=1)
        subprocess.run(["rojo", "build", spec, "-o", out], check=True)
    print("wrote", out)


if __name__ == "__main__":
    main()
