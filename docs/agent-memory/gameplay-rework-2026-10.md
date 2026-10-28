---
name: gameplay-rework-2026-10
description: "Core loop rework decided 2026-10-18 — free roam + meetings, Manual anytime, stare names, sabotage Muerto, Ace arrest, Butler succession; plan path inside"
metadata:
  node_type: memory
  type: project
  originSessionId: a8efe614-ddc4-46ed-a493-3bbb8f188a29
  modified: 2026-10-18T14:14:26.153Z
---

On 2026-10-18 the user and I decided, in a grilling session, to rewrite the core gameplay. The full spec is the plan file `C:\Users\user\.claude\plans\i-need-help-reworking-wobbly-fern.md`. Key points:

- **Cut:** hoods, letter flashes, the evidence board, the suspicion meter and tip box, the Butler's letter, Coven task faking, the frozen DeathNote phase and the round cap.
- **Loop:** free roam, broken up by meetings. A meeting starts on a death, when someone rings the bell, or after a 3-minute timer. It runs 60s of talk then a 20s vote. The Bureau wins by voting out or arresting Diavolo, or by filling a shared task bar. The Coven wins at parity.
- **Diavolo:** writes in the Manual any time, visibly. 60s cooldown, victim dies after 20s. Writing a Muerto's name kills the Muerto.
- **Names:** learned by "stare" (4s, eyes glow). Visual tells only, no witness pop-ups.
- **Muerto:** a saboteur (blackout, jam stations, barricade). Takes the Oculus deal any time and dies 3 minutes later. Only one-way knowledge: Muertos know Diavolo, and nobody else knows them.
- **Ace:** secret. Points at someone in a meeting to arrest them; a wrong arrest kills Ace.
- **Butler:** names the next Ace when Ace dies, and can't pick himself.
- **Chat:** proximity text chat. Real names are blocked in all chat; only notes carry names.

**Why:** the old loop hid every kill, so nobody could ever catch Diavolo, and most of the clue systems went unused.

**How to apply:** the user chose one big rewrite directly on main. Check [[parallel-agent-merges]] before committing.
