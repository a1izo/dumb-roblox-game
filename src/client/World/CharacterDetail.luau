--!strict
-- Avatars at full detail. Roblox draws a mesh in coarser versions the further it is from the camera
-- (RenderFidelity Automatic), and finely made hair and accessories then turn blocky and jagged, even
-- at the distance a cutscene shoots from. Every accessory on every body here (players, bots and the
-- cutscenes' copies of them) is drawn Precise instead, on this screen only (the property is not
-- replicated, so each client sets its own). Accessories are a handful of meshes per body: cheap.

local CharacterDetail = {}

local function sharpen(item: Instance)
	if item:IsA("MeshPart") and item:FindFirstAncestorWhichIsA("Accessory") then
		pcall(function()
			item.RenderFidelity = Enum.RenderFidelity.Precise
		end)
	end
end

-- Every accessory mesh under `root` (a body, or a copy of one).
function CharacterDetail.apply(root: Instance)
	for _, item in ipairs(root:GetDescendants()) do
		sharpen(item)
	end
end

function CharacterDetail.init()
	CharacterDetail.apply(workspace)
	-- Bodies and accessories arrive all through a match (spawns, respawns, outfits, cutscene copies).
	workspace.DescendantAdded:Connect(function(item: Instance)
		if item:IsA("MeshPart") then
			sharpen(item)
		elseif item:IsA("Accessory") then
			CharacterDetail.apply(item)
		end
	end)
end

return CharacterDetail
