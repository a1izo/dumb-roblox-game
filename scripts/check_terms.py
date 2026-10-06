"""Fails when a player-facing string still uses an old name.

Player-facing text must come from src/shared/Terms.luau. Two kinds of names are banned:
names from the source material (Kira, Death Note...) and the game's own retired names
(Inkbound, the Hand, the Grimoire, Specter, Zero, Cultist, the Agency, Agent).

Internal ids ("Kira", "Watari", "DeathNote", the "Agency" venue...) are allowed as whole string
literals, because code compares against them. {placeholders} are ignored: their keys stay stable
while the words they print change. Add "-- terms:ok" to a line to allow it on purpose.
Test specs are skipped.

Run: python scripts/check_terms.py
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE_NAMES = r"Kira|KIRA|Death Note|DEATH NOTE|[Ss]hinigami|SHINIGAMI|Watari|WATARI|Task Force|TASK FORCE|\bL's\b|\bL'S\b|L game|L GAME"
GAME_NAME = r"[Ii]nkbound|INKBOUND"
OLD_ROLES = (
    r"\b[Tt]he Hand\b|\bTHE HAND\b|\bHand's\b|\bHand wins\b|\bHands\b"
    r"|[Gg]rimoire|GRIMOIRE"
    r"|[Ss]pecter|SPECTER"
    r"|\bZero\b|\bZERO\b"
    r"|[Cc]ultist|CULTIST"
    r"|\b[Aa]gency\b|\bAGENCY\b"
    r"|\b[Aa]gents?\b|\bAGENTS?\b"
)
BANNED = re.compile(SOURCE_NAMES + "|" + GAME_NAME + "|" + OLD_ROLES)
# A string with no spaces and only identifier characters is an id or instance name, never a sentence.
# Ids may keep old role words ("Specter" attributes, "specter_ember" cosmetics, "grimoire" windows);
# only the retired game name and the source material stay banned in them.
IDENTIFIER = re.compile(r"[A-Za-z0-9_.:/#-]+")
BANNED_IN_IDS = re.compile(SOURCE_NAMES + "|" + GAME_NAME)
PLACEHOLDER = re.compile(r"\{[A-Za-z_]+\}")
INTERNAL_IDS = {
    "Kira", "Watari", "KiraRemoved", "LKilled", "DeathNote", "DeathNoteService",
    # Internal ids that are never shown: the venue id, the model and set names in the Blender art.
    "Agency", "Grimoire", "TaskForce",
}
# One string literal, double or single quoted; \\. keeps escaped characters inside it.
STRING = re.compile(r'"((?:[^"\\\n]|\\.)*)"|\'((?:[^\'\\\n]|\\.)*)\'')
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
            visible = PLACEHOLDER.sub("", text)
            if IDENTIFIER.fullmatch(visible):
                banned = BANNED_IN_IDS
            else:
                banned = BANNED
            if banned.search(visible):
                problems.append(f"{rel}:{number}: {text}")

if problems:
    print("Player-facing strings must use Terms (src/shared/Terms.luau):")
    for problem in problems:
        print("  " + problem)
    sys.exit(1)
print("Terms check passed.")
