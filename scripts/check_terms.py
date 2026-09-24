"""Fails when a player-facing string still uses a name from the source material.

Player-facing text must come from src/shared/Terms.luau. Internal ids ("Kira", "Watari",
"KiraRemoved"...) are allowed as whole string literals, because code compares against them.
Add "-- terms:ok" to a line to allow it on purpose. Test specs are skipped.

Run: python scripts/check_terms.py
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
BANNED = re.compile(r"Kira|KIRA|Death Note|DEATH NOTE|[Ss]hinigami|SHINIGAMI|Watari|WATARI|Task Force|TASK FORCE|\bL's\b|\bL'S\b|L game|L GAME")
INTERNAL_IDS = {"Kira", "Watari", "KiraRemoved", "LKilled", "DeathNote", "DeathNoteService"}
STRING = re.compile(r'"((?:[^"\\n]|\.)*)"|\'((?:[^\'\\n]|\.)*)\'')
SKIP = ("src/server/Tests/",)

problems = []
for path in sorted((ROOT / "src").rglob("*.luau")):
    rel = path.relative_to(ROOT).as_posix()
    if rel.startswith(SKIP):
        continue
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if "terms:ok" in line:
            continue
        code = line.split("--", 1)[0] if not line.lstrip().startswith("--") else ""
        for match in STRING.finditer(code):
            text = match.group(1) if match.group(1) is not None else match.group(2)
            if text in INTERNAL_IDS:
                continue
            if BANNED.search(text):
                problems.append(f"{rel}:{number}: {text}")

if problems:
    print("Player-facing strings must use Terms (src/shared/Terms.luau):")
    for problem in problems:
        print("  " + problem)
    sys.exit(1)
print("Terms check passed.")
