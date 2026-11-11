--!strict
-- The scene deaths' sets, modelled in Blender like the game's other sets (art/scripts/maps/venues/scenes, imported as
-- DeathsGambitMaps_Scenes.fbx; asked 2026-11-08: "why are the scenarios so low quality?", when they were code-built
-- blocks in a box). No server builds them: a scene clones its own set's meshes here, on this screen, wherever it
-- plays (a case, the lobby's shop, the debug gallery). Each set stands in its own cell 1000 studs along X in the
-- import (art/scripts/maps/venues/scenes/plan.py) and is drawn in its scene's own space, so a mesh's place in its
-- cell is its place from the scene's origin. Its lamps, props and signs come from the generated data
-- (Shared.Scenes, run_maps.py --export Scenes). Without the import a scene builds its old stand-in set instead.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ModelLibrary = require(Shared:WaitForChild("ModelLibrary"))
local SceneMaterials = require(Shared:WaitForChild("SceneMaterials"))
local Data = require(Shared:WaitForChild("Scenes")) :: any

local Sets = {}

-- The scene -> its cell in the import (plan.ORDER).
Sets.CELLS = {
	patriot = 0,
	blackwall = 1,
	walrider = 2,
	sam = 3,
	ironMan = 4,
	selection = 5,
	heart = 6,
	frost = 7,
	lightning = 8,
	chip = 9,
	clock = 10,
	dark = 11,
}
local CELL = 1000

local warned = false

-- Whether the sets' import is there (any version: the cells never move, so an older import still beats the stand-ins).
function Sets.available(): boolean
	local ok = ModelLibrary.calibration(Data.calibration) ~= nil
		and #ModelLibrary.sourcesWithPrefix(Data.meshPrefix) > 0
	if RunService:IsStudio() and not warned and not ModelLibrary.source(Data.marker) then
		warned = true
		warn(
			string.format(
				"[DeathsGambit] The scene deaths' sets are %s: import art/export/%s with Studio's 3D importer (v%d).",
				if ok then "an older import" else "not imported (the scenes build stand-ins)",
				Data.fbx,
				Data.version
			)
		)
	end
	return ok
end

local function dress(part: BasePart, material: string)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	local look = (SceneMaterials :: any)[material]
	if look and look.alpha then
		part.Transparency = 1
		return
	end
	local textured = part:FindFirstChildWhichIsA("SurfaceAppearance") ~= nil
		or (part:IsA("MeshPart") and (part :: MeshPart).TextureID ~= "")
	if look and look.textured and look.fallback and not textured then
		look = look.fallback
	elseif not look or look.textured then
		part.CastShadow = true
		return
	end
	local enum = (Enum.Material :: any)[look.material] or Enum.Material.SmoothPlastic
	part.Material = enum
	part.Color = Color3.fromRGB(look.color[1], look.color[2], look.color[3])
	part.Transparency = look.transparency or 0
	part.Reflectance = look.reflectance or 0
	part.CastShadow = enum ~= Enum.Material.Neon and enum ~= Enum.Material.Glass and part.Transparency < 0.5
	local appearance = part:FindFirstChildWhichIsA("SurfaceAppearance")
	if appearance then
		appearance:Destroy()
	end
	if part:IsA("MeshPart") then
		pcall(function()
			(part :: MeshPart).TextureID = ""
		end)
	end
end

local function rgb(values: { number }?): Color3
	return if values then Color3.fromRGB(values[1], values[2], values[3]) else Color3.new(1, 1, 1)
end

local function inCell(x: number, cell: number): boolean
	return math.floor(x / CELL + 0.5) == cell
end

-- Builds the set of `scene` at `origin` (its scene space) under `parent`. Returns the folder, or nil without the import
-- (or for a scene with no set).
function Sets.build(scene: string, origin: CFrame, parent: Instance): Folder?
	local cell = Sets.CELLS[scene]
	if cell == nil or not Sets.available() then
		return nil
	end
	local cal = ModelLibrary.calibration(Data.calibration) :: ModelLibrary.Calibration
	local base = Vector3.new(cell * CELL, 0, 0)
	local folder = Instance.new("Folder")
	folder.Name = "Set"
	local prefix = Data.meshPrefix
	for _, source in ipairs(ModelLibrary.sourcesWithPrefix(prefix)) do
		if not source:IsA("MeshPart") then
			continue
		end
		local local_ = cal.toLocal * source.CFrame
		local at = local_.Position / cal.scale
		if not inCell(at.X, cell) then
			continue
		end
		local part = source:Clone()
		part.Size = source.Size / cal.scale
		part.CFrame = origin * CFrame.new(at - base) * local_.Rotation
		local rest = string.sub(source.Name, #prefix + 1)
		dress(part, (string.gsub(rest, "_%d+$", "")))
		part.Parent = folder
	end
	local dressing = Data.dressing
	for _, p in ipairs(dressing.props) do
		if not inCell(p[2], cell) then
			continue
		end
		local model = ModelLibrary.get(p[1])
		if model then
			if p[6] and math.abs(p[6] - 1) > 1e-3 then
				model:ScaleTo(model:GetScale() * p[6])
			end
			model:PivotTo(origin * CFrame.new(p[2] - base.X, p[3], p[4]) * CFrame.Angles(0, math.rad(p[5] or 0), 0))
			for _, item in ipairs(model:GetDescendants()) do
				if item:IsA("BasePart") then
					item.Anchored = true
					item.CanCollide = false
					item.CanQuery = false
					item.CanTouch = false
				end
			end
			model.Parent = folder
		end
	end
	for _, spec in ipairs(dressing.lights) do
		local at = spec.at
		if not inCell(at[1], cell) then
			continue
		end
		local anchor = Instance.new("Part")
		anchor.Name = "Lamp"
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.CastShadow = false
		anchor.Transparency = 1
		anchor.Size = Vector3.new(0.2, 0.2, 0.2)
		anchor.CFrame = origin * CFrame.new(at[1] - base.X, at[2], at[3]) * CFrame.Angles(0, math.rad(spec.rot or 0), 0)
		local light: Light
		if spec.kind == "spot" then
			local spot = Instance.new("SpotLight")
			spot.Face = (Enum.NormalId :: any)[spec.face] or Enum.NormalId.Bottom
			spot.Angle = spec.angle or 90
			light = spot
		else
			light = Instance.new("PointLight")
		end
		light.Color = rgb(spec.color)
		light.Range = spec.range
		light.Brightness = spec.brightness
		light.Shadows = spec.shadows == true
		light.Parent = anchor
		anchor.Parent = folder
	end
	for _, spec in ipairs(dressing.signs) do
		local at = spec.at
		if not inCell(at[1], cell) then
			continue
		end
		local board = Instance.new("Part")
		board.Name = "Sign"
		board.Anchored = true
		board.CanCollide = false
		board.CanQuery = false
		board.CanTouch = false
		board.CastShadow = false
		board.Transparency = 1
		board.Size = Vector3.new(spec.w, spec.h, 0.05)
		board.CFrame = origin * CFrame.new(at[1] - base.X, at[2], at[3]) * CFrame.Angles(0, math.rad(spec.rot or 0), 0)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.LightInfluence = 0
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 60
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.TextScaled = true
		label.Font = (Enum.Font :: any)[spec.font] or Enum.Font.GothamBlack
		label.TextColor3 = rgb(spec.color)
		label.Text = spec.text
		label.Parent = gui
		board.Parent = folder
	end
	folder.Parent = parent
	return folder
end

return Sets
