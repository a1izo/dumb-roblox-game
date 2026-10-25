--!strict
-- The flames burning on the scenes' props (candle clusters, the Academy's altars, braziers, lanterns): the server
-- marks each wick with an unseen part tagged LMapFlame (Maps/SceneBuilder: attributes Height, the flame's, and Kind,
-- "candle" or "fire"), and this client stands a living flame on each (Presentation/Vfx Recipes.flame), without a
-- light of its own: the prop carries its lamp. Gone with its mark.

local CollectionService = game:GetService("CollectionService")

local Vfx = require(script.Parent.Parent.Presentation.Vfx)

local Flames = {}

local TAG = "LMapFlame"
local PALE_FIRE = Color3.fromRGB(205, 222, 245)

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
end

return Flames
