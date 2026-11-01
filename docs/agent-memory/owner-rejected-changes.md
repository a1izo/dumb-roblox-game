---
name: owner-rejected-changes
description: Changes the owner explicitly rejected and had removed (never re-add them), and one still unresolved
metadata:
  type: feedback
---

The owner had these taken out; do not bring them back (or anything like them) unless the owner asks:

- **Modelled suit fists** (SuitHandL / SuitHandR, see-through arms, Suit.HAND 0.7; de4b91f and the cuff/pen part of
  8831a50): removed 2026-11-01 at the owner's word ("remove the hand things"). Hands are the classic skin hand at
  the arm's end (Suit.HAND 0.35), the arm solid. The fist meshes may still sit in the Core import; nothing uses them.
- **Unresolved, ask the owner first: the Deathsinger forming on "EAT IT!" in Diavolo's role scene** (394e2a9,
  re-applied as 63e7a2a, live now). The owner told one agent "ignore his commit for the shinigami" and had it
  force-pushed over (2026-10-28); the other agent's code cites the owner asking for it on "EAT IT!". Do not change
  it either way until the owner says which.

**Why:** both were pushed by an agent on its own judgement after the owner had decided otherwise; one came back after
being removed.
**How to apply:** before changing something another agent or the owner settled, check this list and the git log for
a revert; when the owner rejects a change, add it here.
