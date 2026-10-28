---
name: ui-notice-component
description: "Every small card over the world (toasts, tips, Trial step, streak, objectives, offers) is a Kit.notice; never hand-build one"
metadata:
  type: feedback
---

On 2026-10-28 the owner said the in-game notifications (cooldowns etc.), the guide and other panels "look horrible" and
asked for one unified style. The windows (Kit.window) were already consistent; the problem was every small HUD card
being hand-built with its own width (300/340/360/380/400), padding, accent mark, glass or solid fill, and an off-palette
amber dot on the Trial.

**Why:** cards built one by one drift apart; on bright maps the see-through "glass" fill made toasts unreadable.

**How to apply:**
- Use `Kit.notice({ kind, eyebrow, icon, title, body, close, actions, Parent })` (src/client/UI/Kit/Notice.luau) for
  any card over the world. Extras go in `notice.slot`; buttons come back in `notice.buttons`.
- Sizes and surface come from `Tokens.notice` (width 340 / phone 280, padding 16, 3 px accent edge, near-solid fill).
  Accent is white or grey; red only for `bad`/`warn`. No new colours.
- First action is the white primary button, the rest ghost.
- A card that cannot be a notice (the lobby profile card, the HUD identity card, the case feed) passes
  `alpha/edgeColor/edgeWidth/padding` from `Tokens.notice` to `Kit.page` so it matches.
- Right-column cards share the zone margin (`Tokens.space.l`); do not add extra offsets.
- The lobby menu's zigzag is deliberate (LobbyPanel comments); leave it unless the owner asks.
