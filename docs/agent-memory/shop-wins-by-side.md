---
name: shop-wins-by-side
description: The shop's Win cutscenes tab is split into a Bureau group and a Coven group (2026-11-16, owner's ask), how it is built and what `cross` means for the card text
metadata:
  type: feedback
---

The owner (2026-11-16): "separate win cutscenes in shop meaning to make it understandable which are for L and which are
for Kira". Done as two groups inside the one "Win cutscenes" suit (not two tabs: the suit/kind map stays one suit per
kind, and the Monetization spec checks that):

- ShopPanel.rebuild lays the kind "win" in two sections, in this order: The Bureau, then The Coven (Terms {Agency} /
  {Circle}), each with a short line under its heading ("Plays when the Bureau wins."). The top note says "Use one scene
  for each side." The grouping reads `item.side` ("bureau" / "coven"); WinCuts.spec checks every win item has one.
- A card's tier line names the side: "SEALED BUREAU WIN", "GODHOOD COVEN WIN" (Card.KIND_WORD winBureau / winCoven, keyed
  by the item's slot; the words come from Terms.side(id, "short"), new: "Bureau" / "Coven" with no article).
- Picked, Your look adds the lines under the buttons (ShopPanel.winNote): when it plays, and for a paid one with a
  `cross`: "When the Coven wins, a Coven version of it plays, unless you use a Coven scene." That is what
  CosmeticsService.winCut does: with no paid scene worn for the side that won, the scene worn for the other side is told
  for it (its `cross` cutscene).
- Equip slots (winBureau / winCoven), pricing and WinCuts are untouched. The inventory's Win cutscenes tab still lists
  both sides together (its cards do show the side in their tier line).

**Why:** the six scenes were mixed in one grid and a player could not tell which side each belonged to.

**How to apply:** never write the source material's names for the sides in the game (check_terms); use the Terms module.
A new win item needs `side`, `slot` and (paid) `cross`; the shop picks it up with no UI change. Not seen in the game
(no Studio): the layout was read by eye only.
