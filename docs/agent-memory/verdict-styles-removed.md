---
name: verdict-styles-removed
description: Ace's verdict styles and the Ace shop tab were removed completely on 2026-11-16 (owner's word); what went, what stayed, what the arrest does now
metadata:
  type: feedback
---

The owner (2026-11-16): "remove ace shop and verdict styles completely". Gone: the six items verdict_gavel, verdict_cuffs,
verdict_checkmate, verdict_sugar, verdict_stamp, verdict_lamp; the kind "verdict" (Cosmetics.KINDS, names, slot); the
Ace suit (shop tab); Presentation/Verdicts.luau and Shared/Presentation/VerdictTiming.luau; the verdict stills in
Presentation/Styles.luau; the card/inventory/preview code for them; the verdict look in LightingPresets.scenes; Ace's
level 7 mastery unlock (Sweet Justice); the Ledger's two verdict tiers (21 and 18 now pay coins). Profiles: migration
v10 -> v11 drops owned/worn verdict items and their wishlist/new-card marks, no refund (like v5, v6, v8).

**Why:** the owner wanted Ace's shop and verdict styles out, no replacement ("Removal is final").

**How to apply:**
- Ace's arrest is the plain one: `Cues.fire("arrest", ..., { hold = 4 })`, the Arrest presenter's 2.6 s shot (SHOT), no
  insert after it, and the match waits `Cues.waitHolds(6)` as before. The ending has no verdict beat. Do not re-add a
  verdict slot to the cues (`data.verdict`, `timing.verdict`).
- The Phase "Verdict" (the vote's cutscene, Presenters/Verdict.luau, Terms.PHASE.Verdict, the "verdict" cue) is a different
  thing and stays.
- Film Noir (Sets) lost its Interrogation Lamp: its second piece is now the Case File cover (book_case).
- Art that is now unused but was left alone (the owner decides): Core props Gavel, SoundBlock, RubberStamp, InkPad,
  CaseFolder, ChessBoard, ChessQueen (their previews and textures under art/export), and art/scripts/props_shop.py builds
  them. BureauBadge, BankerLamp, Handcuffs, ChessKing, SugarCube and Teacup are used elsewhere and stay.
