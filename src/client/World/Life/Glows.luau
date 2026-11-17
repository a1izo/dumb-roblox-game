--!strict
-- Lights and screens that are alive (graphics plan, phase 13). A prop's glowing parts are separate Neon meshes in the
-- map (ModelLibrary: one per colour in the catalog's glow list), so a desk's monitor, a server rack's three rows of
-- lights, a coffee machine's standby light, a vending machine's display and an arcade cabinet's screen can each be
-- moved on their own. A rule says which prop and which glow colour, and what it does:
--   blink   its colour dips to dark for part of every period (a standby light, a server's rows)
--   cycle   it eases through a short list of colours, holding each for a few seconds (a monitor's picture, a display)
--   warm    it breathes unevenly, like embers
-- Only the colour changes (never the material, the size or the light), only parts near the camera are touched, and each
-- is put back the moment it is out of reach, the building's power is cut (World/Blackout darkens them itself) or the map
-- goes. Under Reduce motion every glow holds its own colour: a cycle shows its first, a blink stays lit.

local Util = require(script.Parent.Util)
local LifePatterns = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("LifePatterns"))

local Glows = {}

type Colour = { number }
type Rule = {
	key: string,
	color: Colour, -- the catalog glow colour that picks the part
	mode: string, -- "blink", "cycle" or "warm"
	period: number?, -- blink: seconds a blink takes
	duty: number?, -- blink: the share of the period it is lit
	low: number?, -- blink: how bright it is when "off" (0 dark, 1 no change)
	palette: { Colour }?, -- cycle
	hold: number?, -- cycle: seconds each colour is held
	fade: number?, -- cycle: seconds the change takes
}

local NEAR = 55 -- studs from the camera within which a glow is alive
local TOLERANCE = 14

local DESK_SCREEN: { Colour } = { { 58, 90, 120 }, { 96, 134, 150 }, { 70, 114, 96 }, { 132, 128, 112 } }
local DISPLAY: { Colour } = { { 120, 230, 255 }, { 255, 200, 120 }, { 255, 140, 170 }, { 150, 255, 180 } }
local ATTRACT: { Colour } = { { 120, 200, 255 }, { 255, 90, 200 }, { 150, 255, 130 }, { 255, 200, 70 } }
local CLAW: { Colour } = { { 255, 150, 210 }, { 150, 210, 255 }, { 255, 230, 130 }, { 190, 255, 170 } }

local RULES: { [string]: { Rule } } = {
	TaskForceHQ = {
		{ key = "BureauDesk", color = { 58, 90, 120 }, mode = "cycle", palette = DESK_SCREEN, hold = 6, fade = 1 },
		{ key = "CoffeeMachine", color = { 255, 60, 40 }, mode = "blink", period = 2.6, duty = 0.3, low = 0.1 },
		{ key = "FaxMachine", color = { 120, 220, 140 }, mode = "blink", period = 3.4, duty = 0.5, low = 0.15 },
		{ key = "SnackVendor", color = { 90, 255, 140 }, mode = "blink", period = 3, duty = 0.55, low = 0.15 },
		{ key = "ServerRack", color = { 255, 170, 60 }, mode = "blink", period = 0.8, duty = 0.5, low = 0.2 },
		{ key = "ServerRack", color = { 80, 170, 255 }, mode = "blink", period = 1.3, duty = 0.6, low = 0.2 },
		{ key = "ServerRack", color = { 60, 255, 120 }, mode = "blink", period = 2.1, duty = 0.55, low = 0.2 },
	},
	TokyoDistrict = {
		{ key = "VendingBlue", color = { 120, 230, 255 }, mode = "cycle", palette = DISPLAY, hold = 3.5, fade = 0.7 },
		{ key = "VendingWhite", color = { 120, 230, 255 }, mode = "cycle", palette = DISPLAY, hold = 3.5, fade = 0.7 },
		{ key = "ArcadeCabinet", color = { 120, 200, 255 }, mode = "cycle", palette = ATTRACT, hold = 1.8, fade = 0.4 },
		{ key = "ArcadeCabinet", color = { 255, 60, 60 }, mode = "blink", period = 1.2, duty = 0.5, low = 0.2 },
		{ key = "ClawMachine", color = { 255, 150, 210 }, mode = "cycle", palette = CLAW, hold = 2.4, fade = 0.6 },
		{ key = "TicketMachine", color = { 255, 60, 50 }, mode = "blink", period = 2.2, duty = 0.4, low = 0.15 },
		{ key = "YakitoriGrill", color = { 255, 110, 40 }, mode = "warm" },
	},
	UniversityCampus = {
		{ key = "KeroseneHeater", color = { 255, 120, 40 }, mode = "warm" },
		{
			key = "CupVendor",
			color = { 255, 190, 110 },
			mode = "cycle",
			palette = {
				{ 255, 190, 110 },
				{ 255, 226, 160 },
				{ 240, 160, 96 },
			},
			hold = 5,
			fade = 1,
		},
	},
}

type Item = { part: BasePart, rule: Rule, base: Color3, phase: number, live: boolean }

local function rgb(c: Colour): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function colourAt(item: Item, now: number): Color3
	local rule = item.rule
	local t = now + item.phase
	if rule.mode == "blink" then
		local on = LifePatterns.blink(t, rule.period or 2, rule.duty or 0.5, 0)
		local level = (rule.low or 0.15) + (1 - (rule.low or 0.15)) * on
		return item.base:Lerp(Color3.new(0, 0, 0), 1 - level)
	elseif rule.mode == "cycle" then
		local palette = rule.palette :: { Colour }
		local index, nextIndex, k = LifePatterns.cycle(t, rule.hold or 4, rule.fade or 0.8, 0, #palette)
		return rgb(palette[index]):Lerp(rgb(palette[nextIndex]), k)
	end
	-- warm: uneven breathing between three quarters and full
	local wobble = 0.6 * math.sin(t * 2.9) + 0.4 * math.sin(t * 6.7 + 1.1)
	return item.base:Lerp(Color3.new(0, 0, 0), 0.14 - 0.12 * wobble)
end

function Glows.build(index: Util.Index, mapId: string): Util.Built?
	local rules = RULES[mapId]
	if not rules then
		return nil
	end
	local items: { Item } = {}
	for _, rule in ipairs(rules) do
		for _, model in ipairs(index.props[rule.key] or {}) do
			for _, part in ipairs(Util.glowsOf(model)) do
				if Util.near(part.Color, rule.color, TOLERANCE) then
					local p = part.Position
					table.insert(items, {
						part = part,
						rule = rule,
						base = part.Color,
						phase = LifePatterns.phaseOf(p.X, p.Z, 12),
						live = false,
					})
				end
			end
		end
	end
	if #items == 0 then
		return nil
	end
	-- (a part is put back only if it is still glowing: World/Blackout turns the lights of a dead building to plastic)
	local function rest(item: Item)
		if item.live then
			item.live = false
			if item.part.Parent and item.part.Material == Enum.Material.Neon then
				item.part.Color = item.base
			end
		end
	end
	return {
		step = function(env: Util.Env)
			for _, item in ipairs(items) do
				local part = item.part
				if not part.Parent then
					continue
				end
				if env.blackout then
					item.live = false
				elseif env.reduced or (part.Position - env.eye).Magnitude > NEAR then
					rest(item)
				else
					item.live = true
					part.Color = colourAt(item, env.now)
				end
			end
		end,
		destroy = function()
			for _, item in ipairs(items) do
				rest(item)
			end
		end,
	}
end

local kind: Util.Kind = {
	name = "glows",
	maps = { "TaskForceHQ", "TokyoDistrict", "UniversityCampus" },
	build = Glows.build,
}
return kind
