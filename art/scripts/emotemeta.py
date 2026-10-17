"""The emotes' plain-data description (src/shared/Anim/EmoteMeta.luau), read without Roblox: what each clip
holds, where and when. The prop checks (check_props.py) and the preview renders (review_emote.py) use it, so
the props they test and show are the ones the game puts on the hands.

The Luau file is a little more than a table: it names a few shared pieces (`local GRIP = {...}`) and copies
one with changes (`with(NOTEBOOK, { hide = 4.4 })`). This reader understands exactly that much.
"""

import math
import os
import re

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
META = os.path.join(ROOT, "src", "shared", "Anim", "EmoteMeta.luau")
CATALOG = os.path.join(ROOT, "src", "shared", "ModelCatalog.luau")

_TOKEN = re.compile(r"-?\d+\.?\d*(?:[eE][-+]?\d+)?|[A-Za-z_]\w*|\"(?:[^\"\\]|\\.)*\"|[{}=,()\[\]]")


def _strip(text):
    text = re.sub(r"--\[\[.*?\]\]", "", text, flags=re.S)
    text = re.sub(r"--[^\n]*", "", text)
    # helper functions are Luau the game runs; the data never needs them
    return re.sub(r"local function \w+\(.*?\n\bend\b", "", text, flags=re.S)


def _merge(base, extra):
    out = dict(base)
    out.update(extra)
    return out


def read(path):
    """The table a Luau data module returns, with its locals and `with` copies resolved."""
    tokens = _TOKEN.findall(_strip(open(path, encoding="utf-8").read()))
    pos = 0
    names = {}

    def value():
        nonlocal pos
        tok = tokens[pos]
        if tok == "{":
            return table()
        pos += 1
        if tok in ("true", "false"):
            return tok == "true"
        if tok == "nil":
            return None
        if tok.startswith('"'):
            return tok[1:-1]
        if re.match(r"[A-Za-z_]", tok):
            if pos < len(tokens) and tokens[pos] == "(":
                pos += 1
                args = [value()]
                while tokens[pos] == ",":
                    pos += 1
                    args.append(value())
                pos += 1  # )
                if tok != "with":
                    raise ValueError(f"{path}: unknown call {tok}")
                return _merge(*args)
            if tok not in names:
                raise ValueError(f"{path}: unknown name {tok}")
            return names[tok]
        return float(tok)

    def table():
        nonlocal pos
        pos += 1
        keyed, listed = {}, []
        while tokens[pos] != "}":
            if tokens[pos] == "[":  # ["key"] = value
                key = tokens[pos + 1][1:-1]
                pos += 4
                keyed[key] = value()
            elif tokens[pos + 1] == "=" and re.match(r"[A-Za-z_]", tokens[pos]):
                key = tokens[pos]
                pos += 2
                keyed[key] = value()
            else:
                listed.append(value())
            if tokens[pos] == ",":
                pos += 1
        pos += 1
        return keyed if keyed else listed

    while pos < len(tokens):
        tok = tokens[pos]
        if tok == "local" and tokens[pos + 2] == "=":
            name = tokens[pos + 1]
            pos += 3
            names[name] = value()
        elif tok == "return":
            pos += 1
            return value()
        else:
            pos += 1
    raise ValueError(f"{path}: no return")


def load():
    """clip id -> its meta (dict)."""
    return read(META)


def catalog():
    """ModelCatalog: model key -> {size, pivot, ...}."""
    return read(CATALOG)


# CFrame maths (Roblox conventions: x right, y up, z backwards; CFrame.Angles = Rx * Ry * Rz) ---------


def rx(deg):
    a = math.radians(deg)
    return np.array([[1, 0, 0], [0, math.cos(a), -math.sin(a)], [0, math.sin(a), math.cos(a)]])


def ry(deg):
    a = math.radians(deg)
    return np.array([[math.cos(a), 0, math.sin(a)], [0, 1, 0], [-math.sin(a), 0, math.cos(a)]])


def rz(deg):
    a = math.radians(deg)
    return np.array([[math.cos(a), -math.sin(a), 0], [math.sin(a), math.cos(a), 0], [0, 0, 1]])


def angles(x, y, z):
    m = np.identity(4)
    m[:3, :3] = rx(x) @ ry(y) @ rz(z)
    return m


def move(x, y, z):
    m = np.identity(4)
    m[:3, 3] = (x, y, z)
    return m


def steps(seq):
    """The 4x4 CFrame of a list of steps ({p = ...} moves, {r = ...} turns), applied in order."""
    m = np.identity(4)
    for step in seq or []:
        if "p" in step:
            m = m @ move(*step["p"])
        if "r" in step:
            m = m @ angles(*step["r"])
    return m


def prop_scale(prop, cat):
    """How much the game scales the Core model (its biggest side becomes prop.size)."""
    entry = cat.get(prop["model"])
    if not entry:
        return None
    biggest = max(entry["size"])
    return prop["size"] / biggest if biggest > 0 else 1.0


# Props whose bounding box is a poor stand-in for their shape: boxes (centre, half sizes) in the model's own
# frame from its pivot, before scaling (Roblox axes: the chair's back is at +z, behind someone sitting on it).
SHAPES = {
    "Chair": [
        ((0.0, 1.62, 0.0), (0.9, 0.125, 0.9)),  # the seat
        ((0.0, 3.0, 0.75), (0.75, 0.725, 0.05)),  # the rails of the back
        ((0.75, 1.95, 0.75), (0.08, 1.95, 0.08)),  # back legs, up into the back
        ((-0.75, 1.95, 0.75), (0.08, 1.95, 0.08)),
        ((0.75, 0.75, -0.75), (0.08, 0.75, 0.08)),  # front legs
        ((-0.75, 0.75, -0.75), (0.08, 0.75, 0.08)),
    ],
}
# Props worn round a part (a band round the wrist, a blindfold round the head): they enclose the part they
# are on, so only the other parts count against them.
WRAPS = {"Wristwatch", "Blindfold", "Cuff"}


def prop_boxes(prop, cat):
    """Every box of a prop in its own frame once scaled: [(centre from the pivot, half sizes)]."""
    shape = SHAPES.get(prop["model"])
    if shape and cat.get(prop["model"]):
        s = prop_scale(prop, cat)
        return [(np.array(c, float) * s, np.array(h, float) * s) for c, h in shape]
    return [prop_box(prop, cat)]


def prop_box(prop, cat):
    """The prop's box in its own frame once scaled: (centre from the pivot, half sizes). From the catalog
    model when there is one, else from its stand-in part."""
    entry = cat.get(prop["model"])
    if entry:
        s = prop_scale(prop, cat)
        size = np.array(entry["size"], float) * s
        centre = np.array([0.0, size[1] / 2 if entry.get("pivot") == "bottom" else 0.0, 0.0])
        return centre, size / 2
    size = np.array(prop["stand"]["size"], float)
    if prop["stand"].get("shape") == "Cylinder":
        size = np.array([size[1], size[0], size[2]])  # turned to run along Y (EmoteController.build)
    centre = np.array([0.0, size[1] / 2 if prop["mount"] == "floor" else 0.0, 0.0])
    return centre, size / 2


__all__ = ["load", "catalog", "steps", "prop_box", "prop_scale", "read"]
