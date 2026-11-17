--!strict
-- Neon that stutters on a fixed pattern (graphics plan, phase 13): three of Tokyo's signs near the arcade and the
-- crossing. The map draws each sign itself, as a lit board with its writing and a SurfaceLight in its colour, so a
-- stutter dims the board and its light together and gives them back. Which signs, and how often each stutters, is
-- fixed below: a sign never stutters at random, and no two stutter together. Nothing flickers under Reduce motion or
-- when the player has flashes off.

local Util = require(script.Parent.Util)
local LifePatterns = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("LifePatterns"))

local Neon = {}

-- What is written on the sign (a part of it is enough) and the seconds between its stutters.
local SIGNS: { [string]: { { text: string, period: number } } } = {
	TokyoDistrict = {
		{ text = "CENTER-GAI", period = 11.3 },
		{ text = "文具", period = 8.4 },
		{ text = "眼鏡", period = 14.6 },
	},
}

local NEAR = 150
local DARK = Color3.new(0.08, 0.08, 0.1)
local DEPTH = 0.8 -- how far toward dark a stutter takes the board at its dimmest

type Item = {
	board: BasePart,
	light: SurfaceLight?,
	color: Color3,
	brightness: number,
	period: number,
	phase: number,
	level: number,
}

local function set(item: Item, level: number)
	if item.level == level then
		return
	end
	item.level = level
	if item.board.Parent then
		item.board.Color = item.color:Lerp(DARK, (1 - level) * DEPTH)
	end
	local light = item.light
	if light and light.Parent then
		light.Brightness = item.brightness * level
	end
end

function Neon.build(index: Util.Index, mapId: string): Util.Built?
	local wanted = SIGNS[mapId]
	if not wanted then
		return nil
	end
	local items: { Item } = {}
	for _, board in ipairs(index.boards) do
		for _, sign in ipairs(wanted) do
			if string.find(board.text, sign.text, 1, true) then
				local light = board.part:FindFirstChildOfClass("SurfaceLight")
				local p = board.part.Position
				table.insert(items, {
					board = board.part,
					light = light,
					color = board.part.Color,
					brightness = if light then light.Brightness else 0,
					period = sign.period,
					phase = LifePatterns.phaseOf(p.X, p.Z, sign.period),
					level = 1,
				})
			end
		end
	end
	if #items == 0 then
		return nil
	end
	return {
		step = function(env: Util.Env)
			for _, item in ipairs(items) do
				if not env.flashes or env.blackout or (item.board.Position - env.eye).Magnitude > NEAR then
					set(item, 1)
				else
					set(item, LifePatterns.neon(env.now, item.period, item.phase))
				end
			end
		end,
		destroy = function()
			for _, item in ipairs(items) do
				set(item, 1)
			end
		end,
	}
end

local kind: Util.Kind = { name = "neon", maps = { "TokyoDistrict" }, build = Neon.build }
return kind
