--!strict
-- Every title's own typeface (the owner, 2026-10-25: "give the titles unique fonts so each one feels special"): a
-- face, a weight, upright or italic, and its case, chosen for what the title says (a typed tag for a trainee, a
-- terminal's lower case for Terminally Online, blackletter for a legend, a ledger's mono for Death's Accountant). No
-- two titles share all four. The words take it wherever a title is drawn (over the head, on its card, in Your look,
-- on the results screen) through Rarity.titleText; its tier's marks stay in the UI's own face round them.
--
--   TitleFonts.look("title_set_online")        --> { font = Enum.Font.Code, case = "lower", ... }
--   TitleFonts.face("title_set_online")        --> a Font for a TextLabel's FontFace (the tag's own when none)
--   TitleFonts.wrap("title_set_online", text)  --> rich text: the (already safe) words in that face

local TitleFonts = {}

export type Case = "upper" | "title" | "lower"
export type Look = { font: Enum.Font, weight: Enum.FontWeight?, italic: boolean?, case: Case? }

local W = Enum.FontWeight
local F = Enum.Font

local LOOKS: { [string]: Look } = {
	title_trainee = { font = F.DenkOne, case = "upper" },
	title_detective = { font = F.Merriweather, weight = W.Bold, case = "title" },
	title_insomniac = { font = F.Jura, weight = W.Light, case = "lower" },
	title_vip = { font = F.Bodoni, italic = true, case = "title" },
	title_set_noir = { font = F.Oswald, weight = W.Bold, case = "upper" },
	title_set_ivory = { font = F.Antique, case = "title" },
	title_set_gilded = { font = F.Bodoni, weight = W.Bold, case = "upper" },
	title_set_red = { font = F.PermanentMarker, case = "title" },
	title_set_ninelives = { font = F.Creepster, case = "title" },
	title_set_desk = { font = F.Kalam, weight = W.Bold, case = "lower" },
	title_set_successors = { font = F.TitilliumWeb, weight = W.Light, case = "upper" },
	title_set_main = { font = F.GothamBlack, weight = W.Heavy, case = "upper" },
	title_set_online = { font = F.Code, case = "lower" },
	title_set_floor = { font = F.Sarpanch, weight = W.Bold, case = "upper" },
	title_s1_bookkeeper = { font = F.Garamond, case = "title" },
	title_s1_accountant = { font = F.RobotoMono, weight = W.Medium, case = "upper" },
	title_c_mover = { font = F.Ubuntu, weight = W.Bold, italic = true, case = "upper" },
	title_c_showstopper = { font = F.Michroma, case = "upper" },
	title_c_living_legend = { font = F.GrenzeGotisch, weight = W.Bold, case = "title" },
	title_nightowl = { font = F.JosefinSans, weight = W.Light, italic = true, case = "title" },
	title_veteran = { font = F.RobotoCondensed, weight = W.Bold, case = "upper" },
	title_lifer = { font = F.AmaticSC, weight = W.Bold, case = "upper" },
	title_unbeaten = { font = F.BuilderSans, weight = W.ExtraBold, italic = true, case = "upper" },
	title_archivist = { font = F.Merriweather, weight = W.Light, italic = true, case = "title" },
	title_papertrail = { font = F.SpecialElite, case = "lower" },
	title_sharpeye = { font = F.Highway, case = "upper" },
	title_unwritten = { font = F.IndieFlower, case = "lower" },
	title_shepherd = { font = F.Fondamento, case = "title" },
	title_inkstained = { font = F.PatrickHand, case = "title" },
	title_handcuffs = { font = F.Oswald, weight = W.Light, case = "upper" },
	title_realmwalker = { font = F.Nunito, weight = W.Light, case = "upper" },
	title_m_hand = { font = F.Fantasy, case = "title" },
	title_m_cultist = { font = F.Fondamento, weight = W.Bold, case = "upper" },
	title_m_zero = { font = F.Roboto, weight = W.Light, case = "upper" },
	title_m_butler = { font = F.Garamond, italic = true, case = "title" },
	title_m_agent = { font = F.SciFi, case = "upper" },
	title_m10_hand = { font = F.GrenzeGotisch, weight = W.Heavy, case = "upper" },
	title_m10_cultist = { font = F.Antique, weight = W.Bold, case = "upper" },
	title_m10_zero = { font = F.JosefinSans, weight = W.Bold, case = "upper" },
	title_m10_butler = { font = F.Garamond, weight = W.Bold, italic = true, case = "title" },
	title_m10_agent = { font = F.SpecialElite, case = "upper" },
	title_rank_2 = { font = F.RobotoCondensed, case = "upper" },
	title_rank_3 = { font = F.Arimo, weight = W.Bold, case = "upper" },
	title_rank_4 = { font = F.Merriweather, case = "upper" },
	title_rank_5 = { font = F.Ubuntu, case = "upper" },
	title_rank_6 = { font = F.TitilliumWeb, weight = W.Bold, case = "upper" },
	title_rank_7 = { font = F.Garamond, weight = W.SemiBold, case = "upper" },
	title_rank_8 = { font = F.BuilderSans, weight = W.Heavy, case = "upper" },
}

-- The face a title tag falls back to (the UI's bold sans).
local DEFAULT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold)

function TitleFonts.look(id: string?): Look?
	return if id then LOOKS[id] else nil
end

function TitleFonts.ids(): { string }
	local ids = {}
	for id in pairs(LOOKS) do
		table.insert(ids, id)
	end
	table.sort(ids)
	return ids
end

-- A title's face for a TextLabel (the tag's own bold sans for one with no look).
function TitleFonts.face(id: string?): Font
	local look = TitleFonts.look(id)
	if not look then
		return DEFAULT
	end
	local base = Font.fromEnum(look.font)
	return Font.new(
		base.Family,
		look.weight or base.Weight,
		if look.italic then Enum.FontStyle.Italic else Enum.FontStyle.Normal
	)
end

-- A title's words in its case (the name as written for "title").
function TitleFonts.cased(id: string?, name: string): string
	local look = TitleFonts.look(id)
	local case = if look then look.case or "upper" else "upper"
	if case == "lower" then
		return string.lower(name)
	elseif case == "title" then
		return name
	end
	return string.upper(name)
end

-- Rich text: `words` (already safe in rich text) set in the title's face; unchanged for one with no look.
function TitleFonts.wrap(id: string?, words: string): string
	local look = TitleFonts.look(id)
	if not look then
		return words
	end
	local face = TitleFonts.face(id)
	local text = string.format('<font family="%s" weight="%s">%s</font>', face.Family, face.Weight.Name, words)
	return if look.italic then "<i>" .. text .. "</i>" else text
end

return TitleFonts
