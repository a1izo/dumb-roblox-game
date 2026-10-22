-- Builders for cosmetics, shared by the server (characters) and the shop's 3D preview.

local Create = require(script.Parent.Create)
local ModelLibrary = require(script.Parent.ModelLibrary)

local CosmeticBuild = {}

local VERTICAL = CFrame.Angles(0, 0, math.rad(90))

local function cylinder(cf: CFrame, height: number, diameter: number, color: Color3): Part
	return Create("Part", {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = cf * VERTICAL,
		Color = color,
		Material = Enum.Material.Fabric,
	})
end

local function box(cf: CFrame, size: Vector3, color: Color3): Part
	return Create("Part", {
		Size = size,
		CFrame = cf,
		Color = color,
		Material = Enum.Material.Fabric,
	})
end

-- The hats' Core models (art/scripts/props_hats.py, Core v13): each one's biggest side, and where its middle sits
-- from the head's middle (x right, y up, z behind).
local HAT_FITS: { [string]: { size: number, at: Vector3 } } = {
	HatCap = { size = 1.838, at = Vector3.new(0, 0.6, -0.21) },
	HatTrench = { size = 2.0, at = Vector3.new(0, 0.78, 0) },
	HatDiavolo = { size = 2.154, at = Vector3.new(0, 0.855, 0.077) },
	HatTopper = { size = 1.921, at = Vector3.new(0, 0.74, 0) },
	HatGraveSilk = { size = 1.88, at = Vector3.new(0, 1.09, 0) },
	HatCowl = { size = 2.0, at = Vector3.new(0, -0.06, 0.04) },
	HatCirclet = { size = 1.5, at = Vector3.new(0, 0.6, 0) },
}

-- What a hat does besides sit there (in the world: a 3D view draws no particles or lights): Grave Silk's crown
-- smoulders into smoke and ash; the Thorned Circlet holds a cold white light.
local function hatLife(item, holder: BasePart, top: CFrame)
	if item.id == "hat_tophat_ink" then
		local vent = Create("Attachment", { Name = "Smoulder", Parent = holder }) :: Attachment
		vent.WorldCFrame = top
		Create("ParticleEmitter", {
			Rate = 6,
			Lifetime = NumberRange.new(1.4, 2.2),
			Speed = NumberRange.new(0.4, 0.9),
			SpreadAngle = Vector2.new(25, 25),
			Acceleration = Vector3.new(0, 0.8, 0),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0.9) }),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.55),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Color = ColorSequence.new(Color3.fromRGB(90, 86, 84), Color3.fromRGB(150, 146, 140)),
			LightInfluence = 0.8,
			Texture = "rbxasset://textures/particles/smoke_main.dds",
			Parent = vent,
		})
	elseif item.id == "hat_circlet" then
		Create("PointLight", {
			Color = Color3.fromRGB(220, 236, 255),
			Range = 6,
			Brightness = 1.2,
			Shadows = false,
			Parent = holder,
		})
	end
end

-- The parts of a hat, placed in world space on a head at `anchor`: its Core model, or (before Core v13 is
-- imported) a few plain shapes.
function CosmeticBuild.hat(item, anchor: CFrame, head: BasePart): { BasePart }
	local fit = if type(item.model) == "string" then HAT_FITS[item.model] else nil
	local model = if fit then ModelLibrary.get(item.model) else nil
	if model and fit then
		local _, size = model:GetBoundingBox()
		local biggest = math.max(size.X, size.Y, size.Z)
		if biggest > 0 then
			model:ScaleTo(model:GetScale() * fit.size / biggest)
		end
		model:PivotTo(anchor * CFrame.new(fit.at))
		local parts = {}
		for _, piece in ipairs(model:GetDescendants()) do
			if piece:IsA("BasePart") then
				table.insert(parts, piece)
			end
		end
		if parts[1] then
			local _, box = model:GetBoundingBox()
			hatLife(item, parts[1], anchor * CFrame.new(fit.at + Vector3.new(0, box.Y / 2, 0)))
		end
		return parts
	end
	local top = anchor * CFrame.new(0, head.Size.Y / 2, 0)
	local color = item.color
	local accent = item.accent
	if item.style == "fedora" then
		return {
			cylinder(top * CFrame.new(0, 0.06, 0), 0.12, 2.3, color),
			cylinder(top * CFrame.new(0, 0.5, 0), 0.85, 1.35, color),
			cylinder(top * CFrame.new(0, 0.22, 0), 0.22, 1.4, accent),
		}
	elseif item.style == "tophat" then
		return {
			cylinder(top * CFrame.new(0, 0.06, 0), 0.12, 2, color),
			cylinder(top * CFrame.new(0, 0.85, 0), 1.6, 1.3, color),
			cylinder(top * CFrame.new(0, 0.25, 0), 0.25, 1.35, accent),
		}
	elseif item.style == "cowl" then
		return {
			box(top * CFrame.new(0, -0.35, 0.12), Vector3.new(1.5, 1.7, 1.45), color),
		}
	elseif item.style == "circlet" then
		local pieces = {}
		for k = 0, 7 do
			local a = k * math.pi / 4
			table.insert(
				pieces,
				box(
					top * CFrame.new(0.68 * math.cos(a), -0.05, 0.68 * math.sin(a)),
					Vector3.new(0.12, 0.3, 0.12),
					color
				)
			)
		end
		return pieces
	end
	-- cap
	return {
		cylinder(top * CFrame.new(0, 0.25, 0), 0.5, 1.35, color),
		box(top * CFrame.new(0, 0.05, -0.85), Vector3.new(1.1, 0.1, 0.7), accent),
	}
end

return CosmeticBuild
