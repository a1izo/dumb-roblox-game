--!strict
-- The maps and their props at full detail (the owner, 2026-10-25: "improve the lobby terrain ... and render
-- everything"). Roblox draws a mesh in coarser versions the further it is from the camera (RenderFidelity
-- Automatic), so the realm's far spires, islands and ridges, and every map's distant buildings, went blocky and lost
-- their edges. Every mesh of the world here (not the bodies: World/CharacterDetail sees to their accessories) is
-- drawn Precise on this screen (the property is not replicated, so each client sets its own). Low quality mode
-- (Settings lowGraphics) gives them back to Roblox's own choice, for machines that need it.

local Settings = require(script.Parent.Parent.UI.Core.Settings)

local MapDetail = {}

-- A body (anything with a Humanoid round it) is not the map's.
local function onBody(item: Instance): boolean
	local model = item:FindFirstAncestorWhichIsA("Model")
	while model do
		if model:FindFirstChildOfClass("Humanoid") then
			return true
		end
		model = model:FindFirstAncestorWhichIsA("Model")
	end
	return false
end

local function fidelity(): Enum.RenderFidelity
	return if Settings.get("lowGraphics") == true then Enum.RenderFidelity.Automatic else Enum.RenderFidelity.Precise
end

local function sharpen(item: Instance, wanted: Enum.RenderFidelity)
	if item:IsA("MeshPart") and item.RenderFidelity ~= wanted and not onBody(item) then
		pcall(function()
			item.RenderFidelity = wanted
		end)
	end
end

local function applyAll()
	local wanted = fidelity()
	for _, item in ipairs(workspace:GetDescendants()) do
		sharpen(item, wanted)
	end
end

function MapDetail.init()
	applyAll()
	-- Maps are built and swapped all through a session (the lobby, each round's venue, their props).
	workspace.DescendantAdded:Connect(function(item: Instance)
		if item:IsA("MeshPart") then
			sharpen(item, fidelity())
		end
	end)
	Settings.Changed:Connect(function(key: string)
		if key == "lowGraphics" then
			applyAll()
		end
	end)
end

return MapDetail
