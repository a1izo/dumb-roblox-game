--!strict
-- Role mastery: experience per role from matches played as it. Ten levels each; levels 5
-- and 10 unlock cosmetics that only masters of that role have, level 7 a style for the two
-- roles that have one (Diavolo's The Knife, Ace's Sugar Cubes), and level 8 an emote.

local Mastery = {}

Mastery.LEVELS = { 0, 60, 150, 280, 450, 680, 960, 1300, 1720, 2200 }
Mastery.MAX = #Mastery.LEVELS

Mastery.PLAY_XP = 20
Mastery.WIN_XP = 30

-- [roleId] = { [level] = cosmetic id }
Mastery.UNLOCKS = {
	Kira = { [5] = "title_m_hand", [7] = "writing_knife", [8] = "emote_just_as_planned", [10] = "tie_m_hand" }, -- terms:ok (internal role id)
	Follower = { [5] = "title_m_cultist", [8] = "emote_reapers_cackle", [10] = "tie_m_cultist" },
	L = { [5] = "title_m_zero", [7] = "verdict_sugar", [8] = "emote_its_you", [10] = "tie_m_zero" },
	Watari = { [5] = "title_m_butler", [8] = "emote_strawberry_on_top", [10] = "tie_m_butler" }, -- terms:ok (internal role id)
	TaskForce = { [5] = "title_m_agent", [8] = "emote_forty_seconds", [10] = "tie_m_agent" },
} :: { [string]: { [number]: string } }

function Mastery.level(xp: number): number
	local level = 1
	for index, needed in ipairs(Mastery.LEVELS) do
		if xp >= needed then
			level = index
		end
	end
	return level
end

-- Experience still needed for the next level (nil at the top).
function Mastery.toNext(xp: number): number?
	local level = Mastery.level(xp)
	local nextXp = Mastery.LEVELS[level + 1]
	return if nextXp then nextXp - xp else nil
end

function Mastery.xpFor(won: boolean): number
	return Mastery.PLAY_XP + (if won then Mastery.WIN_XP else 0)
end

return Mastery
