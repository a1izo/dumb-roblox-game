---
name: death-loadout-2026-11
description: Diavolo's four death slots (2026-11-15): where a custom death is owned, equipped and chosen, what changed, the choices made without asking (per name, plain causes stay), where it is saved, and what was not seen in the game
metadata:
  type: project
---

The owner's words: "the custom deaths should be available to use by diavolo in match like he can equip 4 of different death".

**Before.** A custom death (Cosmetics kind `reason`, 15 of them, each a scene death) was bought in the shop and worn in ONE
slot, `profile.equipped.reason`. The Manual (`UI/PrivateScreen`) listed that one death plus the three plain causes and sent
the pick with the name; `DeathNoteService.onWrite` accepted a plain cause or the worn one.

**Now.**
- `Shared/DeathLoadout.luau` (pure): four slots, `slots / slotOf / set / remove / place / usable / resolve`. A death takes one
  slot at most; an id that is not a `reason` item is dropped; `set` moves a death between slots.
- Saved as `profile.deathLoadout` (four item ids, "" for empty), sent in the profile payload. Migration v9 to v10
  (`Data/Migrations`, `CURRENT = 10`) moves a worn `equipped.reason` into slot 1 and clears it; `equipped.reason` is no
  longer used.
- Server: `ShopService` buys put a death in the first empty slot (toast "Added to death slot N"); `equip` does the same,
  `unequip` takes it out, a new action `deathSlot` `{ itemId, slot | clear }` puts it in a chosen slot. All are refused in a
  match ("Change cosmetics in the lobby", the shop's existing check) and need ownership. `CosmeticsService.deathLoadout(player)`
  is the deaths in a slot that the player owns. `DeathNoteService.onWrite` asks `DeathLoadout.resolve`: a plain cause, or the
  cause of an equipped and owned death, anything else is a heart attack (as before for an unknown cause).
- The Manual's list is what the server says: `DeathNoteService.onMatchStart` stores `ps.deaths` ({cause, name} per usable
  death) and `Match.privateState` sends it to the Kira (`private.deaths`); `PrivateScreen` lists them first, in slot order,
  then the three plain causes. A bot Diavolo has none (bots have no profile).
- UI: `UI/Shop/DeathSlots.luau` is a row of four numbered buttons (the lit one holds this death; a click on it takes it out),
  used under an owned custom death in the shop's Your look and in the inventory's Custom deaths page; cards show a "Slot N" chip.

**Choices made without asking the owner (write down, change if they disagree).** (1) The choice is per name, in the Manual,
not rotation or random: the Manual already asked for a cause with every name, and a rotation or a dice would make the death
the owner paid for unpredictable. (2) The three plain causes stay beside the four. (3) Not a Diavolo-only lock: anyone can
fill the slots (they only matter to the Kira side), so nothing about a role shows in the lobby. (4) No change for anyone who
is not Diavolo: the death cue, the cutscene and the cause card are untouched.

**Checked:** 40 pure specs (`DeathLoadout.spec`, `Migrations.spec`, run in Studio from a bundle, negative control: a copy
that ignores ownership fails two). **Not seen:** the shop and inventory slot rows, the Manual's seven-cause grid and a whole
match with a loadout, because the place's scripts predate the repo (owner's Rojo sync needed). Look at the Inventory's Custom
deaths page, a buy, then Diavolo's Manual first.

Related: [[deaths-current-state-2026-11-14]], [[death-cutscene-bot-victim]], [[ui-text-style]].
