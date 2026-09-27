"""Reads src/shared/ModelCatalog.luau (written by build_props.py) outside the game: each prop's
size, pivot, whether it collides, the lights it carries, its anchor (the point a map places
on the spot it asks for, such as a pole's foot) and, for a station's look, its screen slot."""

import os
import re

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
PATH = os.path.join(ROOT, "src", "shared", "ModelCatalog.luau")

_CACHE = {}


def _entries(text):
    """(key, body) for every top-level entry, whatever its line breaks."""
    for m in re.finditer(r"^\t(\w+) = \{", text, re.M):
        depth, i = 1, m.end()
        while depth and i < len(text):
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
            i += 1
        yield m.group(1), text[m.end():i - 1]


def _entries_in(block):
    """The top-level { ... } entries of a list body."""
    depth, begin = 0, 0
    for i, ch in enumerate(block):
        if ch == "{":
            if depth == 0:
                begin = i + 1
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                yield begin, block[begin:i]


def _numbers(s):
    return [float(v) for v in re.findall(r"-?[\d.]+", s)]


def load():
    if _CACHE:
        return _CACHE
    text = open(PATH, encoding="utf-8").read()
    for key, body in _entries(text):
        size = re.search(r"size = \{([^}]*)\}", body)
        pivot = re.search(r'pivot = "(\w+)"', body)
        collide = re.search(r"collide = (true|false)", body)
        anchor = re.search(r"anchor = \{([^}]*)\}", body)
        screen = re.search(r"screen = \{ at = \{([^}]*)\}, size = \{([^}]*)\}", body)
        lights = []
        start = body.find("lights = {")
        if start >= 0:
            depth, i = 1, start + len("lights = {")
            while depth and i < len(body):
                depth += {"{": 1, "}": -1}.get(body[i], 0)
                i += 1
            block = body[start + len("lights = {"):i - 1]
            for _, entry in _entries_in(block):
                at = re.search(r"at = \{([^}]*)\}", entry)
                rng = re.search(r"range = ([-\d.]+)", entry)
                bright = re.search(r"brightness = ([-\d.]+)", entry)
                lights.append({"at": _numbers(at.group(1)) if at else [0.0, 0.0, 0.0],
                               "range": float(rng.group(1)) if rng else 10.0,
                               "brightness": float(bright.group(1)) if bright else 1.0})
        if size:
            _CACHE[key] = {
                "size": _numbers(size.group(1)),
                "pivot": pivot.group(1) if pivot else "bottom",
                "collide": bool(collide and collide.group(1) == "true"),
                "anchor": _numbers(anchor.group(1)) if anchor else [0.0, 0.0],
                "lights": lights,
                "screen": {"at": _numbers(screen.group(1)), "size": _numbers(screen.group(2))} if screen else None,
            }
    return _CACHE
