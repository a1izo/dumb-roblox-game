--!strict
-- The flames burning on the scenes' props (candle clusters, the Academy's altars, braziers, lanterns): the server
-- marks each wick with an unseen part tagged LMapFlame (Maps/SceneBuilder: attributes Height, the flame's, and Kind,
-- "candle" or "fire"), and this client stands a living flame on each (Presentation/Vfx Recipes.flame), without a
-- light of its own: the prop carries its lamp. Gone with its mark.
-- Burning notes too (Services/NoteService: a part tagged LNoteBurn, attributes Burn and Smoke, seconds): the paper
-- flares up in a warm fire with its own light, curls into glowing ash that lifts away, goes out, and smokes.

local CollectionService = game:GetService("CollectionService")

local Vfx = require(script.Parent.Parent.Presentation.Vfx)

local Flames = {}

local TAG = "LMapFlame"
local BURN_TAG = "LNoteBurn"
local PALE_FIRE = Color3.fromRGB(205, 222, 245)
local PAPER_FIRE = Color3.fromRGB(255, 150, 60)

local burning: { [Instance]: any } = {}

local function add(mark: Instance)
	if burning[mark] or not mark:IsA("BasePart") then
		return
	end
	local height = mark:GetAttribute("Height")
	local kind = mark:GetAttribute("Kind")
	burning[mark] = Vfx.Recipes.flame(mark, {
		kind = if kind == "fire" then "fire" else "candle",
		scale = if type(height) == "number" then height else nil,
		color = if kind == "fire" then PALE_FIRE else nil,
		light = false,
	})
end

local function remove(mark: Instance)
	local flame = burning[mark]
	if flame then
		flame.destroy()
		burning[mark] = nil
	end
end

local function burn(mark: Instance)
	if burning[mark] or not mark:IsA("BasePart") then
		return
	end
	local seconds = mark:GetAttribute("Burn")
	local flame = Vfx.Recipes.flame(mark, {
		kind = "fire",
		scale = 1.5,
		color = PAPER_FIRE,
		lightRange = 12,
		lightBrightness = 1.4,
		lit = false,
	})
	flame.set(1, 0.25)
	burning[mark] = flame
	-- the paper curling into ash: dark flakes with glowing edges lifting off it, and a thin grey smoke rising for as
	-- long as the mark stays
	Vfx.Emit.burst(mark.Position, {
		{
			{
				tex = "VfxChunk",
				grid = 2,
				fps = 0,
				startRandom = true,
				color = {
					{ 0, Color3.fromRGB(255, 170, 90) },
					{ 0.3, Color3.fromRGB(60, 40, 32) },
					{ 1, Color3.fromRGB(40, 38, 38) },
				},
				light = 0.2,
				lit = 0.6,
				size = { { 0, 0.22 }, { 1, 0.14 } },
				alpha = { { 0, 0 }, { 0.8, 0.2 }, { 1, 1 } },
				life = { 1.6, 2.6 },
				speed = { 1, 2.5 },
				spread = 50,
				accel = Vector3.new(0.4, 2.2, 0),
				drag = 1,
				rot = { 0, 360 },
				spin = { -150, 150 },
			},
			14,
		},
	}, nil, Vector3.new(0.8, 0.2, 0.8))
	Vfx.Emit.make(mark, {
		tex = "VfxSmoke",
		grid = 8,
		mode = "OneShot",
		color = Color3.fromRGB(96, 94, 98),
		light = 0,
		lit = 0.5,
		size = { { 0, 0.8 }, { 1, 3.2 } },
		alpha = { { 0, 0.55 }, { 0.5, 0.65 }, { 1, 1 } },
		life = { 2.4, 3.4 },
		speed = { 2, 3.5 },
		spread = 12,
		accel = Vector3.new(0.3, 0.4, 0),
		rot = { 0, 360 },
		spin = { -20, 20 },
		rate = 3,
	})
	Vfx.Clock.after(if type(seconds) == "number" then seconds else 2, function()
		if burning[mark] == flame then
			flame.out()
		end
	end)
end

-- (for checks: how many flames burn)
function Flames.count(): number
	local n = 0
	for _ in pairs(burning) do
		n += 1
	end
	return n
end

function Flames.init()
	CollectionService:GetInstanceAddedSignal(TAG):Connect(add)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(remove)
	for _, mark in ipairs(CollectionService:GetTagged(TAG)) do
		add(mark)
	end
	CollectionService:GetInstanceAddedSignal(BURN_TAG):Connect(burn)
	CollectionService:GetInstanceRemovedSignal(BURN_TAG):Connect(remove)
	for _, mark in ipairs(CollectionService:GetTagged(BURN_TAG)) do
		burn(mark)
	end
end

return Flames
