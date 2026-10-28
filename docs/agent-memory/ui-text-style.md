---
name: ui-text-style
description: "Player-facing text must be short and plain: no em dashes, ellipses, middle-dot separators or colon-joined run-on sentences"
metadata:
  type: feedback
---

On 2026-10-28 the owner asked for every piece of player-facing text (UI, shop, hints, toasts, role cards, signs) to be
rewritten because it was wordy and full of AI writing tells. They named em dashes and "dots" (ellipses `…`/`...` and
the `·` separators) specifically.

**Why:** long explanatory lines and the dash/dot/colon habit read as AI-written and make the game feel cluttered.

**How to apply:**
- One short sentence, or a label. Cut anything the button, icon or screen already says (no "Press to buy. You wear it at once.").
- No `—`, `–`, `…`, `...` or ` · ` in strings a player sees. Use a plain space gap, a comma, a period, `/` on signs, or
  `(key)` after a button name. Loading states are a bare word ("Connecting").
- Don't chain clauses with `:` or `;` ("The deal is made: names come fast now"). Split into short sentences.
- Contractions are fine ("don't", "can't").
- Exceptions kept on purpose: cutscene subtitles (`art/scripts/cinema` uses `...` to time pauses), the font
  truncation ellipsis in `UI/Core/FontMirror.luau`, and the rarity marks around titles (`Shared/Rarity`): ◇ for
  Penned, ◆ from Sealed up. Penned's mark was a `·` until the dots went; it needs a mark of its own, or a Penned
  title looks exactly like a Scrawl one (Rarity.spec checks every tier differs).
- Run `python scripts/check_terms.py` after text edits: words like "Hands", "agent", "Zero" are banned outside Terms placeholders.
