-- Procedural building kit for the lobby, the meeting room and the three maps.
-- Coordinates passed to the builder are local to its origin; y = 0 is the floor surface.
-- Rotations are degrees around Y: 0 faces -Z, 180 faces +Z, 90 faces -X, -90 faces +X.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))

local Builder = {}
Builder.__index = Builder

local STATION_COLORS = {
	Camera = Color3.fromRGB(70, 140, 255),
	Fingerprint = Color3.fromRGB(80, 220, 160),
	Phone = Color3.fromRGB(255, 185, 70),
}

function Builder.new(parent: Instance, origin: Vector3)
	local self = setmetatable({}, Builder)
	self.parent = parent
	self.origin = origin
	return self
end

-- Local CFrame helper.
function Builder:cf(x: number, y: number, z: number, rot: number?): CFrame
	return CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(rot or 0), 0)
end

function Builder:world(localCFrame: CFrame): CFrame
	return CFrame.new(self.origin) * localCFrame
end

function Builder:worldPos(x: number, y: number, z: number): Vector3
	return self.origin + Vector3.new(x, y, z)
end

-- Core part factory. `localCFrame` is relative to the origin.
function Builder:part(
	size: Vector3,
	localCFrame: CFrame,
	color: Color3,
	material: Enum.Material?,
	extra: { [string]: any }?
)
	local part = Create("Part", {
		Anchored = true,
		Size = size,
		CFrame = self:world(localCFrame),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
	})
	if extra then
		for key, value in pairs(extra) do
			if key ~= "Parent" then
				part[key] = value
			end
		end
	end
	part.Parent = if extra and extra.Parent then extra.Parent else self.parent
	return part
end

-- Box centred on local (x, y, z).
function Builder:block(
	x: number,
	y: number,
	z: number,
	sx: number,
	sy: number,
	sz: number,
	color: Color3,
	material: Enum.Material?,
	extra: { [string]: any }?
)
	return self:part(Vector3.new(sx, sy, sz), CFrame.new(x, y, z), color, material, extra)
end

-- Rotated box standing on the floor at (x, z).
function Builder:prop(
	x: number,
	z: number,
	rot: number,
	offset: CFrame,
	size: Vector3,
	color: Color3,
	material: Enum.Material?,
	extra: { [string]: any }?
)
	return self:part(size, self:cf(x, 0, z, rot) * offset, color, material, extra)
end

-- Floor slab whose top surface is at height y.
function Builder:floor(
	x1: number,
	z1: number,
	x2: number,
	z2: number,
	color: Color3,
	material: Enum.Material?,
	y: number?
)
	local top = y or 0
	local sx = math.abs(x2 - x1)
	local sz = math.abs(z2 - z1)
	return self:block((x1 + x2) / 2, top - 0.5, (z1 + z2) / 2, sx, 1, sz, color, material)
end

-- Straight wall from (x1, z1) to (x2, z2) standing on the floor.
function Builder:wall(
	x1: number,
	z1: number,
	x2: number,
	z2: number,
	height: number,
	color: Color3,
	material: Enum.Material?,
	thickness: number?,
	base: number?
)
	local a = Vector3.new(x1, 0, z1)
	local b = Vector3.new(x2, 0, z2)
	local length = (b - a).Magnitude
	if length < 0.05 then
		return nil
	end
	local mid = (a + b) / 2
	local bottom = base or 0
	local localCFrame =
		CFrame.lookAt(Vector3.new(mid.X, bottom + height / 2, mid.Z), Vector3.new(b.X, bottom + height / 2, b.Z))
	return self:part(Vector3.new(thickness or 1, height, length), localCFrame, color, material)
end

-- Axis-aligned wall with door gaps. doors = list of { center, width } measured along
-- the wall from its start point. A lintel closes the space above each door.
function Builder:wallDoors(
	x1: number,
	z1: number,
	x2: number,
	z2: number,
	height: number,
	doors: { { number } },
	color: Color3,
	material: Enum.Material?
)
	local a = Vector3.new(x1, 0, z1)
	local b = Vector3.new(x2, 0, z2)
	local length = (b - a).Magnitude
	local dir = (b - a).Unit
	local gaps = {}
	for _, door in ipairs(doors) do
		table.insert(gaps, { door[1] - door[2] / 2, door[1] + door[2] / 2 })
	end
	table.sort(gaps, function(g1, g2)
		return g1[1] < g2[1]
	end)
	local cursor = 0
	local doorHeight = math.min(9, height - 1)
	for _, gap in ipairs(gaps) do
		local from = math.max(cursor, 0)
		local to = math.min(gap[1], length)
		if to - from > 0.05 then
			local p1 = a + dir * from
			local p2 = a + dir * to
			self:wall(p1.X, p1.Z, p2.X, p2.Z, height, color, material)
		end
		local l1 = a + dir * math.max(gap[1], 0)
		local l2 = a + dir * math.min(gap[2], length)
		self:wall(l1.X, l1.Z, l2.X, l2.Z, height - doorHeight, color, material, 1, doorHeight)
		cursor = gap[2]
	end
	if length - cursor > 0.05 then
		local p1 = a + dir * cursor
		self:wall(p1.X, p1.Z, b.X, b.Z, height, color, material)
	end
end

-- Four walls around a rectangle (no doors).
function Builder:enclose(
	x1: number,
	z1: number,
	x2: number,
	z2: number,
	height: number,
	color: Color3,
	material: Enum.Material?
)
	self:wall(x1, z1, x2, z1, height, color, material)
	self:wall(x2, z1, x2, z2, height, color, material)
	self:wall(x2, z2, x1, z2, height, color, material)
	self:wall(x1, z2, x1, z1, height, color, material)
end

function Builder:light(x: number, y: number, z: number, color: Color3, range: number?, brightness: number?)
	local fixture =
		self:block(x, y, z, 2.4, 0.2, 2.4, color, Enum.Material.Neon, { CanQuery = false, CastShadow = false })
	Create("PointLight", {
		Color = color,
		Range = range or 24,
		Brightness = brightness or 1.2,
		Shadows = false,
		Parent = fixture,
	})
	return fixture
end

-- Text panel. The text faces the direction given by rot.
function Builder:sign(
	x: number,
	y: number,
	z: number,
	rot: number,
	w: number,
	h: number,
	text: string,
	textColor: Color3,
	bg: Color3,
	font: Enum.Font?
)
	local board = self:part(Vector3.new(w, h, 0.3), self:cf(x, y, z, rot), bg, Enum.Material.SmoothPlastic)
	local gui = Create("SurfaceGui", {
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 30,
		LightInfluence = 0,
		Parent = board,
	})
	local label = Create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = text,
		TextColor3 = textColor,
		TextScaled = true,
		Font = font or Enum.Font.GothamBlack,
		Parent = gui,
	})
	Create("UIPadding", {
		PaddingLeft = UDim.new(0.04, 0),
		PaddingRight = UDim.new(0.04, 0),
		PaddingTop = UDim.new(0.08, 0),
		PaddingBottom = UDim.new(0.08, 0),
		Parent = label,
	})
	return board, label
end

-- Furniture ---------------------------------------------------------------------------

function Builder:desk(x: number, z: number, rot: number, color: Color3?)
	local wood = color or Color3.fromRGB(96, 74, 56)
	self:prop(x, z, rot, CFrame.new(0, 2.9, 0), Vector3.new(6, 0.3, 3), wood, Enum.Material.Wood)
	for _, lx in ipairs({ -2.7, 2.7 }) do
		self:prop(x, z, rot, CFrame.new(lx, 1.4, 0), Vector3.new(0.3, 2.8, 2.6), wood, Enum.Material.Wood)
	end
	-- Monitor on the desk
	self:prop(
		x,
		z,
		rot,
		CFrame.new(0.8, 3.9, 0.7),
		Vector3.new(1.8, 1.2, 0.15),
		Color3.fromRGB(25, 25, 30),
		Enum.Material.SmoothPlastic
	)
	self:prop(
		x,
		z,
		rot,
		CFrame.new(-1.3, 3.1, 0.2),
		Vector3.new(1.1, 0.12, 0.8),
		Color3.fromRGB(240, 240, 235),
		Enum.Material.SmoothPlastic
	)
end

function Builder:chair(x: number, z: number, rot: number, color: Color3?)
	local c = color or Color3.fromRGB(40, 40, 46)
	self:prop(x, z, rot, CFrame.new(0, 1.6, 0), Vector3.new(1.8, 0.3, 1.8), c, Enum.Material.Fabric)
	self:prop(x, z, rot, CFrame.new(0, 2.8, 0.8), Vector3.new(1.8, 2.2, 0.25), c, Enum.Material.Fabric)
	self:prop(
		x,
		z,
		rot,
		CFrame.new(0, 0.75, 0),
		Vector3.new(0.3, 1.5, 0.3),
		Color3.fromRGB(70, 70, 75),
		Enum.Material.Metal
	)
end

function Builder:shelf(x: number, z: number, rot: number, width: number?, color: Color3?)
	local w = width or 6
	local c = color or Color3.fromRGB(80, 62, 48)
	self:prop(x, z, rot, CFrame.new(0, 4, 0), Vector3.new(w, 8, 1.6), c, Enum.Material.Wood)
	local bookColors = {
		Color3.fromRGB(150, 40, 40),
		Color3.fromRGB(40, 70, 130),
		Color3.fromRGB(200, 170, 90),
		Color3.fromRGB(60, 110, 60),
	}
	for level = 1, 3 do
		self:prop(
			x,
			z,
			rot,
			CFrame.new(0, level * 2.2, -0.85),
			Vector3.new(w - 0.6, 1.4, 0.2),
			bookColors[(level % #bookColors) + 1],
			Enum.Material.SmoothPlastic
		)
	end
end

function Builder:cabinet(x: number, z: number, rot: number)
	self:prop(
		x,
		z,
		rot,
		CFrame.new(0, 2.5, 0),
		Vector3.new(2.4, 5, 2),
		Color3.fromRGB(120, 125, 130),
		Enum.Material.Metal
	)
	for level = 1, 3 do
		self:prop(
			x,
			z,
			rot,
			CFrame.new(0, level * 1.5, -1.02),
			Vector3.new(0.8, 0.15, 0.1),
			Color3.fromRGB(60, 60, 60),
			Enum.Material.Metal
		)
	end
end

function Builder:plant(x: number, z: number)
	self:block(x, 1, z, 1.6, 2, 1.6, Color3.fromRGB(90, 70, 60), Enum.Material.Concrete)
	self:part(
		Vector3.new(3, 3.4, 3),
		CFrame.new(x, 3.4, z),
		Color3.fromRGB(50, 120, 60),
		Enum.Material.Grass,
		{ Shape = Enum.PartType.Ball }
	)
end

function Builder:tree(x: number, z: number, scale: number?)
	local s = scale or 1
	self:part(
		Vector3.new(1.4 * s, 9 * s, 1.4 * s),
		CFrame.new(x, 4.5 * s, z),
		Color3.fromRGB(95, 70, 50),
		Enum.Material.Wood
	)
	self:part(
		Vector3.new(9 * s, 8 * s, 9 * s),
		CFrame.new(x, 10 * s, z),
		Color3.fromRGB(60, 125, 65),
		Enum.Material.Grass,
		{ Shape = Enum.PartType.Ball }
	)
	self:part(
		Vector3.new(6 * s, 6 * s, 6 * s),
		CFrame.new(x + 2 * s, 12.5 * s, z - 1 * s),
		Color3.fromRGB(75, 140, 70),
		Enum.Material.Grass,
		{ Shape = Enum.PartType.Ball }
	)
end

function Builder:bench(x: number, z: number, rot: number)
	local wood = Color3.fromRGB(120, 85, 55)
	self:prop(x, z, rot, CFrame.new(0, 1.5, 0), Vector3.new(6, 0.3, 1.8), wood, Enum.Material.Wood)
	self:prop(x, z, rot, CFrame.new(0, 2.6, 0.8), Vector3.new(6, 1.6, 0.25), wood, Enum.Material.Wood)
	for _, lx in ipairs({ -2.5, 2.5 }) do
		self:prop(
			x,
			z,
			rot,
			CFrame.new(lx, 0.7, 0),
			Vector3.new(0.3, 1.4, 1.6),
			Color3.fromRGB(50, 50, 55),
			Enum.Material.Metal
		)
	end
end

function Builder:sofa(x: number, z: number, rot: number, color: Color3?)
	local c = color or Color3.fromRGB(110, 40, 45)
	self:prop(x, z, rot, CFrame.new(0, 1, 0), Vector3.new(7, 2, 3), c, Enum.Material.Fabric)
	self:prop(x, z, rot, CFrame.new(0, 2.5, 1.2), Vector3.new(7, 2.2, 0.8), c, Enum.Material.Fabric)
	for _, lx in ipairs({ -3.2, 3.2 }) do
		self:prop(x, z, rot, CFrame.new(lx, 1.8, 0), Vector3.new(0.8, 1.8, 3), c, Enum.Material.Fabric)
	end
end

function Builder:table(x: number, z: number, rot: number, w: number?, d: number?, color: Color3?)
	local c = color or Color3.fromRGB(150, 120, 90)
	local width = w or 5
	local depth = d or 3
	self:prop(x, z, rot, CFrame.new(0, 2.6, 0), Vector3.new(width, 0.3, depth), c, Enum.Material.Wood)
	self:prop(
		x,
		z,
		rot,
		CFrame.new(0, 1.25, 0),
		Vector3.new(0.6, 2.5, 0.6),
		Color3.fromRGB(60, 60, 64),
		Enum.Material.Metal
	)
end

function Builder:counter(x: number, z: number, rot: number, w: number, color: Color3?)
	local c = color or Color3.fromRGB(200, 200, 205)
	self:prop(x, z, rot, CFrame.new(0, 1.75, 0), Vector3.new(w, 3.5, 2.4), c, Enum.Material.Marble)
end

function Builder:vending(x: number, z: number, rot: number, color: Color3?)
	local c = color or Color3.fromRGB(200, 40, 50)
	self:prop(x, z, rot, CFrame.new(0, 3.5, 0), Vector3.new(4, 7, 2.6), c, Enum.Material.SmoothPlastic)
	self:prop(
		x,
		z,
		rot,
		CFrame.new(-0.4, 4.3, -1.32),
		Vector3.new(2.6, 4, 0.1),
		Color3.fromRGB(190, 230, 255),
		Enum.Material.Neon,
		{ CanQuery = false }
	)
	self:prop(
		x,
		z,
		rot,
		CFrame.new(1.4, 4.3, -1.32),
		Vector3.new(0.6, 1.5, 0.1),
		Color3.fromRGB(40, 40, 40),
		Enum.Material.SmoothPlastic
	)
end

function Builder:crate(x: number, z: number, size: number?, rot: number?)
	local s = size or 4
	self:prop(
		x,
		z,
		rot or 0,
		CFrame.new(0, s / 2, 0),
		Vector3.new(s, s, s),
		Color3.fromRGB(140, 105, 65),
		Enum.Material.WoodPlanks
	)
end

function Builder:rack(x: number, z: number, rot: number)
	self:prop(x, z, rot, CFrame.new(0, 4, 0), Vector3.new(3, 8, 3), Color3.fromRGB(30, 32, 38), Enum.Material.Metal)
	for level = 1, 6 do
		self:prop(
			x,
			z,
			rot,
			CFrame.new(-0.9, level * 1.15, -1.52),
			Vector3.new(0.25, 0.12, 0.05),
			if level % 2 == 0 then Color3.fromRGB(60, 255, 120) else Color3.fromRGB(80, 170, 255),
			Enum.Material.Neon,
			{ CanQuery = false }
		)
	end
end

function Builder:pillar(x: number, z: number, height: number, color: Color3?, width: number?)
	local w = width or 2.5
	return self:block(x, height / 2, z, w, height, w, color or Color3.fromRGB(200, 200, 200), Enum.Material.Concrete)
end

function Builder:streetLamp(x: number, z: number, color: Color3?)
	local c = color or Color3.fromRGB(255, 220, 160)
	self:block(x, 6, z, 0.5, 12, 0.5, Color3.fromRGB(45, 45, 50), Enum.Material.Metal)
	local bulb = self:block(x, 12.3, z, 1.4, 0.6, 1.4, c, Enum.Material.Neon, { CanQuery = false, CastShadow = false })
	Create("PointLight", { Color = c, Range = 26, Brightness = 1.6, Parent = bulb })
end

-- Block building with lit window strips on all four sides.
function Builder:building(x: number, z: number, w: number, d: number, h: number, color: Color3, windowColor: Color3?)
	self:block(x, h / 2, z, w, h, d, color, Enum.Material.Concrete)
	local glow = windowColor or Color3.fromRGB(255, 225, 150)
	local floors = math.floor((h - 4) / 6)
	for level = 1, floors do
		local y = level * 6
		self:block(
			x,
			y,
			z - d / 2 - 0.06,
			w - 3,
			2,
			0.1,
			glow,
			Enum.Material.Neon,
			{ CanQuery = false, CastShadow = false }
		)
		self:block(
			x,
			y,
			z + d / 2 + 0.06,
			w - 3,
			2,
			0.1,
			glow,
			Enum.Material.Neon,
			{ CanQuery = false, CastShadow = false }
		)
		self:block(
			x - w / 2 - 0.06,
			y,
			z,
			0.1,
			2,
			d - 3,
			glow,
			Enum.Material.Neon,
			{ CanQuery = false, CastShadow = false }
		)
		self:block(
			x + w / 2 + 0.06,
			y,
			z,
			0.1,
			2,
			d - 3,
			glow,
			Enum.Material.Neon,
			{ CanQuery = false, CastShadow = false }
		)
	end
end

function Builder:car(x: number, z: number, rot: number, color: Color3)
	self:prop(x, z, rot, CFrame.new(0, 1.6, 0), Vector3.new(5, 1.8, 10), color, Enum.Material.SmoothPlastic)
	self:prop(
		x,
		z,
		rot,
		CFrame.new(0, 3.1, 0.6),
		Vector3.new(4.4, 1.4, 5.5),
		Color3.fromRGB(30, 35, 45),
		Enum.Material.Glass,
		{ CanQuery = false, Transparency = 0.2 }
	)
	for _, wx in ipairs({ -2.3, 2.3 }) do
		for _, wz in ipairs({ -3.2, 3.2 }) do
			self:part(
				Vector3.new(0.8, 1.8, 1.8),
				self:cf(x, 0, z, rot) * CFrame.new(wx, 0.9, wz),
				Color3.fromRGB(20, 20, 20),
				Enum.Material.SmoothPlastic,
				{ Shape = Enum.PartType.Cylinder }
			)
		end
	end
end

-- Decorative glass pane that does not block sight lines.
function Builder:glass(x1: number, z1: number, x2: number, z2: number, height: number, base: number?)
	local pane = self:wall(x1, z1, x2, z2, height, Color3.fromRGB(170, 200, 220), Enum.Material.Glass, 0.3, base)
	if pane then
		pane.Transparency = 0.6
		pane.CanQuery = false
	end
	return pane
end

-- Gameplay objects -------------------------------------------------------------------

-- A case-file station: desk, a screen that faces the worker and a type prop.
-- The worker stands on the side the rotation faces.
function Builder:station(def, id: string)
	local model = Create("Model", { Name = "Station_" .. id, Parent = self.parent })
	local base = self:cf(def.x, def.y or 0, def.z, def.rot)
	local typeColor = STATION_COLORS[def.type] or Color3.fromRGB(200, 200, 200)
	local desk = self:part(
		Vector3.new(5, 3, 2.4),
		base * CFrame.new(0, 1.5, 0),
		Color3.fromRGB(58, 56, 62),
		Enum.Material.Metal,
		{ Parent = model }
	)
	self:part(
		Vector3.new(5.2, 0.12, 2.6),
		base * CFrame.new(0, 3.06, 0),
		typeColor,
		Enum.Material.Neon,
		{ Parent = model, CanQuery = false }
	)
	self:part(
		Vector3.new(0.4, 1.2, 0.3),
		base * CFrame.new(0, 3.6, 0.8),
		Color3.fromRGB(40, 40, 44),
		Enum.Material.Metal,
		{ Parent = model }
	)
	local screen = self:part(
		Vector3.new(4.4, 2.6, 0.3),
		base * CFrame.new(0, 5.4, 0.8),
		Color3.fromRGB(12, 12, 16),
		Enum.Material.SmoothPlastic,
		{ Parent = model }
	)

	if def.type == "Camera" then
		self:part(
			Vector3.new(0.8, 0.6, 1.2),
			base * CFrame.new(-1.6, 3.5, 0),
			Color3.fromRGB(30, 30, 34),
			Enum.Material.Metal,
			{ Parent = model }
		)
		self:part(
			Vector3.new(0.5, 0.5, 0.2),
			base * CFrame.new(-1.6, 3.5, -0.65),
			Color3.fromRGB(80, 160, 255),
			Enum.Material.Neon,
			{ Parent = model, CanQuery = false }
		)
	elseif def.type == "Fingerprint" then
		self:part(
			Vector3.new(1.4, 0.2, 1),
			base * CFrame.new(-1.5, 3.2, -0.3),
			Color3.fromRGB(80, 230, 170),
			Enum.Material.Neon,
			{ Parent = model, CanQuery = false }
		)
	else
		self:part(
			Vector3.new(0.7, 0.35, 1.3),
			base * CFrame.new(-1.6, 3.25, -0.2),
			Color3.fromRGB(35, 35, 38),
			Enum.Material.SmoothPlastic,
			{ Parent = model }
		)
		self:part(
			Vector3.new(1.6, 0.3, 0.9),
			base * CFrame.new(1.5, 3.2, -0.3),
			Color3.fromRGB(220, 215, 200),
			Enum.Material.SmoothPlastic,
			{ Parent = model }
		)
	end

	local gui = Create("SurfaceGui", {
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 40,
		LightInfluence = 0,
		Parent = screen,
	})
	local label = Create("TextLabel", {
		BackgroundColor3 = Color3.fromRGB(10, 14, 22),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Text = string.upper(def.name) .. "\nREADY",
		TextColor3 = typeColor,
		TextScaled = true,
		Font = Enum.Font.Code,
		Parent = gui,
	})
	Create("UIPadding", {
		PaddingLeft = UDim.new(0.06, 0),
		PaddingRight = UDim.new(0.06, 0),
		PaddingTop = UDim.new(0.1, 0),
		PaddingBottom = UDim.new(0.1, 0),
		Parent = label,
	})

	desk:SetAttribute("StationId", id)
	desk:SetAttribute("StationType", def.type)
	desk:SetAttribute("StationName", def.name)
	desk:SetAttribute("Busy", false)
	desk:AddTag("LStation")
	screen:SetAttribute("StationId", id)
	screen:AddTag("LStationScreen")

	return {
		id = id,
		type = def.type,
		name = def.name,
		model = model,
		desk = desk,
		screen = screen,
		label = label,
		position = desk.Position,
	}
end

-- Anonymous tip box at headquarters. Only L reads the tips.
function Builder:tipBox(def)
	local model = Create("Model", { Name = "TipBox", Parent = self.parent })
	local base = self:cf(def.x, 0, def.z, def.rot)
	local box = self:part(
		Vector3.new(2.6, 4, 2.2),
		base * CFrame.new(0, 2, 0),
		Color3.fromRGB(140, 30, 35),
		Enum.Material.Metal,
		{ Parent = model }
	)
	self:part(
		Vector3.new(1.6, 0.2, 0.1),
		base * CFrame.new(0, 3.2, -1.12),
		Color3.fromRGB(15, 15, 15),
		Enum.Material.SmoothPlastic,
		{ Parent = model }
	)
	self:part(
		Vector3.new(2.8, 0.3, 2.4),
		base * CFrame.new(0, 4.15, 0),
		Color3.fromRGB(90, 20, 25),
		Enum.Material.Metal,
		{ Parent = model }
	)
	local signAt = (base * CFrame.new(0, 2.2, -1.2)).Position
	local signPart = self:sign(
		signAt.X,
		signAt.Y,
		signAt.Z,
		def.rot,
		2.4,
		0.9,
		"TIP BOX",
		Color3.fromRGB(255, 240, 220),
		Color3.fromRGB(110, 20, 25)
	)
	signPart.Parent = model
	box:AddTag("LTipBox")
	return { part = box, position = box.Position, model = model }
end

-- Physical evidence board; the returned label shows the latest entries.
function Builder:board(def)
	local _, label = self:sign(
		def.x,
		def.y or 6,
		def.z,
		def.rot,
		def.w or 12,
		def.h or 7,
		"",
		Color3.fromRGB(235, 235, 225),
		Color3.fromRGB(30, 34, 30),
		Enum.Font.Code
	)
	label.TextScaled = true
	label.TextWrapped = true
	Create("UITextSizeConstraint", { MaxTextSize = 16, MinTextSize = 6, Parent = label })
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	local _, title = self:sign(
		def.x,
		(def.y or 6) + (def.h or 7) / 2 + 0.6,
		def.z,
		def.rot,
		7,
		1.2,
		"EVIDENCE BOARD",
		Color3.fromRGB(255, 255, 255),
		Color3.fromRGB(120, 25, 30)
	)
	title.Font = Enum.Font.GothamBlack
	return label
end

-- Hidden drop point for paper notes: an inconspicuous vent grate.
function Builder:dropPoint(def, id: string)
	local grate = self:part(
		Vector3.new(2, 0.3, 2),
		self:cf(def.x, def.y or 0.15, def.z, def.rot or 0),
		Color3.fromRGB(70, 72, 76),
		Enum.Material.DiamondPlate
	)
	grate.Name = "DropPoint_" .. id
	grate:SetAttribute("DropId", id)
	grate:SetAttribute("DropName", def.name)
	grate:AddTag("LDropPoint")
	return { id = id, name = def.name, part = grate, position = grate.Position }
end

return Builder
