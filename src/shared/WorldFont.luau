--!strict
-- The font for text the server builds into the world (signs, boards, cards): Montserrat, which Roblox ships.
-- The glyph atlases of the UI (Aktura, Melodrama) are client-only images, so world text uses the stand-in.
-- Callers still pass the Enum.Font they used to ask for; it only decides the weight.

local WorldFont = {}

local MONTSERRAT = "rbxasset://fonts/families/Montserrat.json"

local HEAVY = {
	[Enum.Font.GothamBlack] = Enum.FontWeight.ExtraBold,
	[Enum.Font.GrenzeGotisch] = Enum.FontWeight.ExtraBold,
	[Enum.Font.Oswald] = Enum.FontWeight.Bold,
	[Enum.Font.GothamBold] = Enum.FontWeight.Bold,
	[Enum.Font.AmaticSC] = Enum.FontWeight.Bold,
}

function WorldFont.face(font: Enum.Font?): Font
	local weight = if font then HEAVY[font] else nil
	return Font.new(MONTSERRAT, weight or Enum.FontWeight.Medium)
end

return WorldFont
