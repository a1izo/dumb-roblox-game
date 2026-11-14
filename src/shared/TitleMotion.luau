--!strict
-- Titles whose letters move (docs/shop-roadmap.md, "Animated titles", agreed as a thing to sell): each of these titles
-- has a motion of its own, played wherever the title is drawn (over the head in the lobby, on its shop card, in Your
-- look) by the client's World/TitleAnimator. Titles show in the lobby and on the results screen only, like every
-- title. No ink anywhere (the owner's rule): the motions are light, breath, chalk, cold and a pulse.
--
--   TitleMotion.of("title_a_candle")  --> "flicker"
--   TitleMotion.TAG                   --> the CollectionService tag a moving title's TextLabel wears
--
-- A label that moves carries the tag and the attribute TitleId (its title's id); the animator reads the motion and
-- the tier's colour from that.

local TitleMotion = {}

TitleMotion.TAG = "DGTitleMotion"

export type Kind = "flicker" | "chalk" | "heartbeat" | "shiver" | "afterglow"

-- What each motion is, for the shop's card band and the docs.
TitleMotion.NAMES = {
	flicker = "Flickers like a candle",
	chalk = "Drawn on in chalk",
	heartbeat = "Beats like a heart",
	shiver = "Shivers with cold",
	afterglow = "Glows and fades",
}

local MOTIONS: { [string]: Kind } = {
	title_a_candle = "flicker",
	title_a_chalk = "chalk",
	title_a_borrowed = "heartbeat",
	title_a_coldcase = "shiver",
	title_a_afterglow = "afterglow",
}

function TitleMotion.of(titleId: string?): Kind?
	return if titleId then MOTIONS[titleId] else nil
end

function TitleMotion.all(): { [string]: Kind }
	return table.clone(MOTIONS)
end

return TitleMotion
