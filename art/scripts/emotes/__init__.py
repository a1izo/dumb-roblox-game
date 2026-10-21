"""The rebuilt emotes (2026-10-17): each copies its reference (art/refs/emotes/). anims.py imports this package
after anims_emotes, so a clip defined here replaces the older one of the same name."""

from emotes import dances, duos, free, older, poses, props, seats, strolls, wins  # noqa: F401

# The audit's fixes, over every emote once all are made (emotes/settle.py).
from emotes import settle  # noqa: E402

print("[emotes] settled:", ", ".join(settle.run()) or "nothing")
