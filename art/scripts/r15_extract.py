"""Reads the R15 rig that ships with Roblox Studio (morpherEditorR15.rbxmx) and writes the
part sizes, part CFrames and Motor6D joints to art/data/r15_rig.json. verify_ingame.py uses
it to pose a real R15 body exactly the way the game does.

    python art/scripts/r15_extract.py
"""

import glob
import json
import os
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "data", "r15_rig.json")


def find_rig():
    root = os.path.join(os.environ["LOCALAPPDATA"], "Roblox", "Versions")
    files = glob.glob(os.path.join(root, "*", "content", "avatar", "morpherEditorR15.rbxmx"))
    if not files:
        raise SystemExit("Roblox Studio's morpherEditorR15.rbxmx was not found.")
    return max(files, key=os.path.getmtime)


def cframe(node):
    get = lambda tag: float(node.find(tag).text)
    pos = [get("X"), get("Y"), get("Z")]
    rot = [[get("R00"), get("R01"), get("R02")], [get("R10"), get("R11"), get("R12")], [get("R20"), get("R21"), get("R22")]]
    return {"p": pos, "r": rot}


def props(item):
    return item.find("Properties")


def prop(item, kind, name):
    for node in props(item).findall(kind):
        if node.get("name") == name:
            return node
    return None


def main():
    tree = ET.parse(find_rig())
    parts, names, motors = {}, {}, []
    for item in tree.iter("Item"):
        cls = item.get("class")
        if cls in ("Part", "MeshPart"):
            name = prop(item, "string", "Name").text
            size = prop(item, "Vector3", "size") or prop(item, "Vector3", "Size")
            if size is None:
                continue
            names[item.get("referent")] = name
            parts[name] = {
                "cframe": cframe(prop(item, "CoordinateFrame", "CFrame")),
                "size": [float(size.find(t).text) for t in ("X", "Y", "Z")],
            }
    for item in tree.iter("Item"):
        if item.get("class") == "Motor6D":
            motors.append(
                {
                    "name": prop(item, "string", "Name").text,
                    "part0": names.get(prop(item, "Ref", "Part0").text),
                    "part1": names.get(prop(item, "Ref", "Part1").text),
                    "c0": cframe(prop(item, "CoordinateFrame", "C0")),
                    "c1": cframe(prop(item, "CoordinateFrame", "C1")),
                }
            )
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w") as f:
        json.dump({"parts": parts, "motors": motors}, f, indent=1)
    print("parts", sorted(parts), "motors", [m["name"] for m in motors])


if __name__ == "__main__":
    main()
