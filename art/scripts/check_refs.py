"""Every emote's reference notes (art/refs/emotes/<clip>.toml) against its clip (plain Python):

    python art/scripts/check_refs.py [--strict]

For each emote (the nine free ones and every emote item in src/shared/Cosmetics.luau):
  - is there a notes file, and how far along is it (researched, authored, checked, approved, vetoed)?
  - once authored: the clip's length is the notes' length, and that is a whole number of beats of the tempo;
  - the free emotes keep the lengths cutscenes and endings were timed to.
With --strict, any authored emote that breaks a rule fails the run.
"""

import os
import re
import sys
import tomllib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import rbxsim  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
REFS = os.path.join(ROOT, "art", "refs", "emotes")
COSMETICS = os.path.join(ROOT, "src", "shared", "Cosmetics.luau")
FRAME = 1 / 60

# Cutscenes, endings, reactions and the lobby's tableaux play these clips at fixed times.
FROZEN = {"wave": 2.4, "point": 1.6, "cheer": 2.2, "laugh": 1.2, "dance": 1.6, "salute": 2.0, "bow": 2.6,
          "shrug": 2.0, "facepalm": 2.4}
STATUSES = ("researched", "authored", "checked", "approved", "vetoed")


def emote_clips():
    text = open(COSMETICS, encoding="utf-8").read()
    items = re.findall(r'\bemote\s*=\s*"([a-z]\w*)"', text)  # clip ids (suit labels are capitalised)
    seen, out = set(), []
    for clip in list(FROZEN) + items:
        if clip not in seen:
            seen.add(clip)
            out.append(clip)
    return out


def load(clip):
    path = os.path.join(REFS, clip + ".toml")
    if not os.path.exists(path):
        return None
    with open(path, "rb") as f:
        return tomllib.load(f)


def run(strict=False):
    clips = rbxsim.load_clips()
    counts = {s: 0 for s in ("missing",) + STATUSES}
    problems = []
    for clip in emote_clips():
        notes = load(clip)
        if notes is None:
            counts["missing"] += 1
            continue
        status = notes.get("status", "researched")
        counts[status] = counts.get(status, 0) + 1
        if status in ("researched", "vetoed"):
            continue
        data = clips.get(clip)
        if data is None:
            problems.append(f"{clip}: no clip")
            continue
        timing = notes.get("timing", {})
        length = timing.get("length")
        if length is not None and abs(data["length"] - length) > FRAME:
            problems.append(f"{clip}: the clip is {data['length']:.3f} s, the notes say {length:.3f} s")
        bpm, beats = timing.get("bpm"), timing.get("beats")
        if bpm and beats and abs(beats * 60.0 / bpm - data["length"]) > FRAME:
            problems.append(f"{clip}: {beats} beats at {bpm} bpm is {beats * 60.0 / bpm:.3f} s, the clip {data['length']:.3f} s")
        if clip in FROZEN and abs(data["length"] - FROZEN[clip]) > 1e-3:
            problems.append(f"{clip}: free emotes keep their length ({FROZEN[clip]} s), it is {data['length']:.3f} s")
        if not notes.get("source", {}).get("url"):
            problems.append(f"{clip}: no source url")
    print("[refs] " + ", ".join(f"{k} {v}" for k, v in counts.items()))
    for p in problems:
        print("[refs] !!", p)
    return len(problems) if strict else 0


if __name__ == "__main__":
    sys.exit(1 if run("--strict" in sys.argv) else 0)
