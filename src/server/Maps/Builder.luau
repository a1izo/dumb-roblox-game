-- The parts, props and signs every venue's Blender scene is placed with (SceneBuilder), and the
-- gameplay objects the game builds itself: stations, the tip box, the evidence board, drop points.
-- Coordinates passed to the builder are local to its origin; y = 0 is the floor surface.
-- Rotations are degrees around Y: 0 faces -Z, 180 faces +Z, 90 faces -X, -90 faces +X.
-- Gameplay objects wear the Blender props (ModelLibrary) once they are imported, and keep their
-- part-built look otherwise; both have the same footprint.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))
local WorldFont = require(Shared:WaitForChild("WorldFont"))
local ModelLibrary = require(Shared:WaitForChild("ModelLibrary"))
local TaskTypes = require(Shared:WaitForChild("Tasks"):WaitForChild("TaskTypes"))

local Builder = {}
Builder.__index = Builder

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
		FontFace = WorldFont.face(font or Enum.Font.GothamBlack),
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

-- Props --------------------------------------------------------------------------------

-- Places an imported Blender prop standing on the floor at (x, z), facing rot. Returns the
-- model, or nil when the prop has not been imported (the caller then builds a stand-in).
function Builder:placeModel(key: string, x: number, z: number, rot: number?, scale: number?, y: number?): Model?
	local model = ModelLibrary.get(key)
	if not model then
		return nil
	end
	if scale and math.abs(scale - 1) > 1e-3 then
		model:ScaleTo(model:GetScale() * scale)
	end
	model:PivotTo(self:world(self:cf(x, y or 0, z, rot or 0)))
	model.Parent = self.parent
	return model
end

-- Gameplay objects -------------------------------------------------------------------

-- A case-file station: desk, a screen that faces the worker and a type prop.
-- The worker stands on the side the rotation faces.
function Builder:station(def, id: string)
	local model = Create("Model", { Name = "Station_" .. id, Parent = self.parent })
	local base = self:cf(def.x, def.y or 0, def.z, def.rot)
	local typeColor = TaskTypes.get(def.type).color
	local desk = self:part(
		Vector3.new(5, 3, 2.4),
		base * CFrame.new(0, 1.5, 0),
		Color3.fromRGB(58, 56, 62),
		Enum.Material.Metal,
		{ Parent = model }
	)
	local strip = self:part(
		Vector3.new(5.2, 0.12, 2.6),
		base * CFrame.new(0, 3.06, 0),
		typeColor,
		Enum.Material.Neon,
		{ Parent = model, CanQuery = false }
	)
	local pedestal = self:part(
		Vector3.new(0.4, 1.2, 0.3),
		base * CFrame.new(0, 3.6, 0.8),
		Color3.fromRGB(40, 40, 44),
		Enum.Material.Metal,
		{ Parent = model }
	)
	-- With the Blender console only the screen stays: its housing is built around it, and the
	-- screen shows the station type. The part-built extras are for the stand-in only.
	-- The station's own look where the map gives one (a CCTV desk, a phone booth...), else the
	-- standard console. A look placed by its anchor stands on the station's origin, and when it
	-- has a screen slot (a monitor on the desk, a terminal on the counter) the game's screen goes
	-- there instead of the console's spot.
	local look = if def.prop then ModelLibrary.info(def.prop) else nil
	local anchor = look and look.anchor
	local lookOffset = CFrame.new(0, -1.5, 0)
		* (if anchor then CFrame.new(-anchor[1], 0, -(anchor[2] or 0)) else CFrame.identity)
	local ownLook = def.prop ~= nil and ModelLibrary.dress(desk, def.prop, lookOffset) ~= nil
	local dressed = ownLook or ModelLibrary.dress(desk, "Station", CFrame.new(0, -1.5, 0)) ~= nil
	if dressed then
		for _, extra in ipairs({ pedestal, strip }) do
			extra.Transparency = 1
			extra.CanQuery = false
			extra.CastShadow = false
		end
	end
	local slot = if ownLook and look then look.screen else nil
	local screenSize = if slot then Vector3.new(slot.size[1], slot.size[2], 0.2) else Vector3.new(4.4, 2.6, 0.3)
	local screenAt = if slot
		then CFrame.new(slot.at[1], slot.at[2], slot.at[3]) * CFrame.Angles(math.rad(slot.tilt or 0), 0, 0)
		else CFrame.new(0, 5.4, 0.8)
	local screen = self:part(
		screenSize,
		base * screenAt,
		Color3.fromRGB(12, 12, 16),
		Enum.Material.SmoothPlastic,
		{ Parent = model }
	)

	-- Type props for the part-built stand-in (the console mesh is the whole station).
	if not dressed and def.type == "Camera" then
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
	elseif not dressed and def.type == "Fingerprint" then
		self:part(
			Vector3.new(1.4, 0.2, 1),
			base * CFrame.new(-1.5, 3.2, -0.3),
			Color3.fromRGB(80, 230, 170),
			Enum.Material.Neon,
			{ Parent = model, CanQuery = false }
		)
	elseif not dressed and def.type == "Forensics" then
		-- A microscope and an ink flask.
		self:part(
			Vector3.new(0.6, 1.4, 0.6),
			base * CFrame.new(-1.5, 3.8, -0.2),
			Color3.fromRGB(40, 40, 46),
			Enum.Material.Metal,
			{ Parent = model }
		)
		self:part(
			Vector3.new(0.5, 0.7, 0.5),
			base * CFrame.new(1.5, 3.4, -0.3),
			Color3.fromRGB(200, 90, 200),
			Enum.Material.Glass,
			{ Parent = model, CanQuery = false, Transparency = 0.3 }
		)
	elseif not dressed then
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
		FontFace = WorldFont.face(Enum.Font.Code),
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
	local base = self:cf(def.x, def.y or 0, def.z, def.rot)
	local box = self:part(
		Vector3.new(2.6, 4, 2.2),
		base * CFrame.new(0, 2, 0),
		Color3.fromRGB(140, 30, 35),
		Enum.Material.Metal,
		{ Parent = model }
	)
	local slot = self:part(
		Vector3.new(1.6, 0.2, 0.1),
		base * CFrame.new(0, 3.2, -1.12),
		Color3.fromRGB(15, 15, 15),
		Enum.Material.SmoothPlastic,
		{ Parent = model }
	)
	local lid = self:part(
		Vector3.new(2.8, 0.3, 2.4),
		base * CFrame.new(0, 4.15, 0),
		Color3.fromRGB(90, 20, 25),
		Enum.Material.Metal,
		{ Parent = model }
	)
	local dressed = ModelLibrary.dress(box, "TipBox", CFrame.new(0, -2, 0)) ~= nil
	if dressed then
		slot.Transparency = 1
		lid.Transparency = 1
		lid.CanQuery = false
	end
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
		Color3.fromRGB(110, 20, 25),
		-- A typewritten plate, like the rest of the case's paperwork.
		Enum.Font.SpecialElite
	)
	signPart.Parent = model
	if dressed then
		-- Painted on the box instead of a plate in front of it.
		signPart.Transparency = 1
		signPart.CanQuery = false
		signPart.CanCollide = false
	end
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
		Enum.Font.SpecialElite
	)
	label.TextScaled = true
	label.TextWrapped = true
	Create("UITextSizeConstraint", { MaxTextSize = 16, MinTextSize = 6, Parent = label })
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	local boardPart = label:FindFirstAncestorWhichIsA("BasePart")
	local boardScale = math.min((def.w or 12) / 12, (def.h or 7) / 7)
	local dressed = boardPart ~= nil
		and ModelLibrary.dress(boardPart, "EvidenceBoard", CFrame.new(0, 0, 0.05), boardScale) ~= nil
	if dressed then
		-- The log is written in ink on the pinned sheet in the middle of the cork.
		label.TextColor3 = Color3.fromRGB(24, 22, 26)
		local padding = label:FindFirstChildOfClass("UIPadding")
		if padding then
			padding.PaddingLeft = UDim.new(0.19, 0)
			padding.PaddingRight = UDim.new(0.19, 0)
			padding.PaddingTop = UDim.new(0.16, 0)
			padding.PaddingBottom = UDim.new(0.16, 0)
		end
	end
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
	title.FontFace = WorldFont.face(Enum.Font.SpecialElite)
	if dressed then
		-- The cork board is recognisable on its own; no plate floating above it.
		local titlePart = title:FindFirstAncestorWhichIsA("BasePart")
		if titlePart then
			titlePart:Destroy()
		end
	end
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
	ModelLibrary.dress(grate, "Grate", CFrame.new(0, -0.15, 0))
	grate:SetAttribute("DropId", id)
	grate:SetAttribute("DropName", def.name)
	grate:AddTag("LDropPoint")
	return { id = id, name = def.name, part = grate, position = grate.Position }
end

return Builder
