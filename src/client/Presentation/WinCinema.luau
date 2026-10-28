-- The paid win cutscenes (shop overhaul, 2026-10-21; Shared/Cinema/WinCuts): a small set built on this screen far
-- from everything, a copy of the winner acting the cutscene's clip on it (Presentation/Stage) holding what the clip
-- holds (EmoteMeta, through EmoteController.dress), the camera through the cutscene's shots, its screen beats, and the
-- set's own events (candles going out, a city dying, strings snapping, a king falling). The same build plays as the
-- ending's centrepiece for everyone (Presenters/Outro), privately for another winner on the results screen
-- (Presenters/WinPrivate), and as the shop's preview in the lobby.
--
--   local stop = WinCinema.play("checkmate", { userId = 123, at = serverTime, wait = false })
--
-- Everything it made goes when it ends, is stopped, or errors (each step under pcall), and the camera and the screen
-- come back; a lead with no body on this screen (gone from the server) is played by Stage's faceless figure.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))
local ManualBook = require(Shared:WaitForChild("ManualBook"))
local ModelLibrary = require(Shared:WaitForChild("ModelLibrary"))
local Models = require(Shared:WaitForChild("Models"))
local Venues = require(Shared:WaitForChild("Venues"))
local WinCuts = require(Shared:WaitForChild("Cinema"):WaitForChild("WinCuts")) :: any

local PoseController = require(script.Parent.Parent.Anim.PoseController)
local Sfx = require(script.Parent.Parent.Audio.Sfx)
local EmoteController = require(script.Parent.Parent.Controllers.EmoteController)
local CameraDirector = require(script.Parent.CameraDirector)
local Cinema = require(script.Parent.Cinema)
local Stage = require(script.Parent.Stage)
local FxKit = require(script.Parent.FxKit)
local Vfx = require(script.Parent.Vfx)

local WinCinema = {}

-- Far off and high: no map, lobby or set reaches here (where a cut plays when its room is not built).
WinCinema.ORIGIN = CFrame.new(6000, 600, -6000)
-- A win cutscene this player sees before their results (another winner's own: Presenters/Outro sets it, the results
-- screen plays it).
WinCinema.pendingPrivate = nil :: string?
-- The cutscene playing on this screen now (nil when none is), and the last one's set (for the harness's checks).
WinCinema.current = nil :: string?
WinCinema.lastRefs = nil :: any
local TAIL = 0.35 -- seconds the last frame holds before everything goes

type Refs = {
	parts: { [string]: BasePart },
	props: { [string]: Model },
	lights: { [string]: { light: PointLight, brightness: number } },
	emitters: { [string]: any },
	strings: { { beam: Beam, far: Attachment } },
	buildings: { { gui: SurfaceGui, order: number } },
	rows: { [number]: { Instance } },
	folder: Instance,
	origin: CFrame,
	star: Model?,
	cleanups: { () -> () },
}

local function vec(v: any): Vector3
	return Vector3.new(v[1] or 0, v[2] or 0, v[3] or 0)
end

local function rgb(c: any, fallback: Color3?): Color3
	if type(c) ~= "table" then
		return fallback or Color3.new(0.5, 0.5, 0.5)
	end
	return Color3.fromRGB(c[1] or 0, c[2] or 0, c[3] or 0)
end

local function angles(r: any): CFrame
	if type(r) ~= "table" then
		return CFrame.identity
	end
	return CFrame.Angles(math.rad(r[1] or 0), math.rad(r[2] or 0), math.rad(r[3] or 0))
end

-- The same small hash as art/scripts/review_win.py (the city is the same buildings in both).
local function hash3(a: number, b: number, c: number): number
	local x = math.sin(a * 12.9898 + b * 78.233 + c * 37.719) * 43758.5453
	return x - math.floor(x)
end

-- Cut data --------------------------------------------------------------------------------------------------

function WinCinema.get(name: string?): any
	return if name then WinCuts[name] else nil
end

function WinCinema.length(name: string?): number
	local cut = WinCinema.get(name)
	return if cut then cut.length else 0
end

-- Building --------------------------------------------------------------------------------------------------

-- What a set's part gives off (the VFX kit: Presentation/Vfx): a candle's living flame (its own part is hidden; `out`
-- snuffs it with a curl of smoke), a fire (out until an "ignite" event lights it, the part's height its flames'),
-- rain, low fog.
local EMIT = {
	flame = function(part: BasePart)
		part.Transparency = 1
		local flame =
			Vfx.Recipes.flame(part, { kind = "candle", scale = math.max(part.Size.Y, 0.3) * 0.9, light = false })
		return {
			out = function()
				flame.out()
			end,
		}
	end,
	fire = function(part: BasePart)
		part.Transparency = 1
		local height = math.max(part.Size.Y, 0.3)
		local flame = Vfx.Recipes.flame(part, {
			kind = "fire",
			scale = height,
			color = Color3.fromRGB(255, 128, 52),
			lit = false,
			lightRange = math.max(height * 7, 8),
			lightBrightness = 1.5,
		})
		return {
			out = function()
				flame.out()
			end,
			ignite = function(scale: number?)
				flame.set(scale or 1, 0.35)
			end,
			flare = function(on: boolean)
				flame.flare(on)
			end,
		}
	end,
	rain = function(parent: Instance)
		return Vfx.Emit.make(parent, {
			tex = "VfxStreak",
			color = Color3.fromRGB(170, 184, 210),
			size = 0.07,
			squash = -3,
			face = "along",
			alpha = { { 0, 0.45 }, { 1, 0.85 } },
			light = 0,
			lit = 0.4,
			life = { 0.6, 0.8 },
			rate = 70,
			speed = { 10, 13 },
			dir = Enum.NormalId.Bottom,
			shape = Enum.ParticleEmitterShape.Box,
		})
	end,
	fog = function(parent: Instance)
		return Vfx.Emit.make(parent, {
			tex = "VfxSmoke",
			grid = 8,
			mode = "OneShot",
			color = Color3.fromRGB(214, 218, 226),
			size = { { 0, 8 }, { 1, 14 } },
			alpha = { { 0, 1 }, { 0.4, 0.84 }, { 1, 1 } },
			light = 0,
			lit = 0.6,
			life = { 6, 9 },
			rate = 3,
			speed = { 0.3, 0.8 },
			spread = { 180, 10 },
			rot = { 0, 360 },
			spin = { -6, 6 },
			shape = Enum.ParticleEmitterShape.Box,
		})
	end,
}

-- Smoke rising from a point (a candle put out: its curl of smoke; anything else, a puff that billows and thins).
local function smoke(at: Vector3, folder: Instance, count: number, color: Color3?)
	if count <= 8 and not color then
		Vfx.Emit.burst(at + Vector3.new(0, 0.6, 0), {
			tex = "VfxWisp",
			grid = 4,
			mode = "OneShot",
			color = Color3.fromRGB(200, 200, 204),
			light = 0,
			lit = 0.35,
			size = 1.6,
			alpha = { { 0, 0.15 }, { 0.7, 0.45 }, { 1, 1 } },
			life = 2.4,
			face = "up",
		}, 1)
		return
	end
	Vfx.Emit.burst(at, {
		tex = "VfxSmoke",
		grid = 8,
		mode = "OneShot",
		color = color or Color3.fromRGB(150, 150, 156),
		light = 0,
		lit = 0.6,
		size = { { 0, 0.4 }, { 1, 1.8 } },
		alpha = { { 0, 0.35 }, { 0.6, 0.5 }, { 1, 1 } },
		life = { 0.9, 1.4 },
		speed = { 0.6, 1.4 },
		spread = 25,
		rot = { 0, 360 },
		spin = { -30, 30 },
	}, count)
	local _ = folder
end

local function makePart(spec: any, origin: CFrame, folder: Instance, refs: Refs): BasePart
	local shape = spec.shape or "Block"
	local material = Enum.Material.SmoothPlastic
	if spec.glow then
		material = Enum.Material.Neon
	elseif type(spec.material) == "string" then
		local ok, found = pcall(function()
			return (Enum.Material :: any)[spec.material]
		end)
		if ok and found then
			material = found
		end
	end
	local part = Create("Part", {
		Name = spec.name or "Piece",
		Shape = (Enum.PartType :: any)[shape] or Enum.PartType.Block,
		Size = vec(spec.size),
		CFrame = origin * CFrame.new(vec(spec.at)) * angles(spec.rot),
		Color = rgb(spec.color),
		Material = material,
		Transparency = if spec.hidden then 1 else spec.alpha or 0,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = not spec.glow and (spec.alpha or 0) < 1,
		Parent = folder,
	}) :: BasePart
	part:SetAttribute("Alpha", spec.alpha or 0)
	if spec.light then
		local light = Create("PointLight", {
			Color = rgb(spec.light.color, Color3.new(1, 1, 1)),
			Range = spec.light.range or 8,
			Brightness = spec.light.brightness or 1,
			Shadows = true,
			Parent = part,
		}) :: PointLight
		if spec.name then
			refs.lights[spec.name] = { light = light, brightness = light.Brightness }
		end
	end
	if spec.emit and EMIT[spec.emit] then
		local emitter = EMIT[spec.emit](part)
		if spec.name then
			refs.emitters[spec.name] = emitter
		end
	end
	if spec.text then
		local gui = Create("SurfaceGui", {
			Name = "Mark",
			Face = (Enum.NormalId :: any)[spec.text.face or "Top"] or Enum.NormalId.Top,
			SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
			PixelsPerStud = 60,
			LightInfluence = 0.6,
			Enabled = not spec.text.hidden,
			Parent = part,
		})
		Create("TextLabel", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.95, 0.5),
			Rotation = spec.text.tilt or -8,
			Text = spec.text.text,
			TextScaled = true,
			TextColor3 = rgb(spec.text.color),
			FontFace = Font.new("rbxasset://fonts/families/" .. (spec.text.font or "Bangers") .. ".json"),
			Parent = gui,
		})
	end
	if spec.name then
		refs.parts[spec.name] = part
	end
	return part
end

local function makeProp(spec: any, origin: CFrame, folder: Instance, refs: Refs)
	local model: Model?
	if spec.key == ManualBook.KEY then
		model = Models.grimoire()
	else
		model = ModelLibrary.get(spec.key)
	end
	if model then
		local extents = model:GetExtentsSize()
		local biggest = math.max(extents.X, extents.Y, extents.Z)
		if spec.size and biggest > 0 and math.abs(spec.size / biggest - 1) > 0.02 and spec.key ~= ManualBook.KEY then
			model:ScaleTo(model:GetScale() * spec.size / biggest)
		end
	else
		-- (not imported yet: a plain block of its size)
		local info = ModelLibrary.info(spec.key) :: any
		local size = if info and info.size then Vector3.new(info.size[1], info.size[2], info.size[3]) else Vector3.one
		local biggest = math.max(size.X, size.Y, size.Z)
		size *= (spec.size or biggest) / biggest
		model = Instance.new("Model")
		local block = Create("Part", {
			Size = size,
			CFrame = CFrame.new(0, size.Y / 2, 0),
			Color = rgb(spec.color),
			Material = Enum.Material.SmoothPlastic,
			Parent = model,
		})
		model.PrimaryPart = block
		model.WorldPivot = CFrame.new()
	end
	local m = model :: Model
	m.Name = spec.name or spec.key
	for _, item in ipairs(m:GetDescendants()) do
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
			item:SetAttribute("Alpha", item.Transparency)
			if spec.hidden then
				item.Transparency = 1
			end
		end
	end
	m:PivotTo(origin * CFrame.new(vec(spec.at)) * CFrame.Angles(0, math.rad(spec.turn or 0), 0))
	m.Parent = folder
	if spec.open and spec.key == ManualBook.KEY then
		ManualBook.pose(m, 1, 1)
	end
	if spec.name then
		refs.props[spec.name] = m
	end
end

-- The skyline below a roof (WinCuts `city`): rows of dark buildings, the face towards the roof lit with windows.
local function makeCity(spec: any, origin: CFrame, folder: Instance, refs: Refs)
	local row, z = 0, -spec.near
	while -z < spec.far do
		local x = -spec.width / 2
		local k = 0
		while x < spec.width / 2 do
			local w = 14 + 12 * hash3(row, k, spec.seed)
			local h = spec.low + (spec.high - spec.low) * hash3(row + 17, k, spec.seed)
			local d = 18 + 8 * hash3(row, k + 31, spec.seed)
			local building = Create("Part", {
				Name = "Building",
				Size = Vector3.new(w, h, d),
				CFrame = origin * CFrame.new(x + w / 2, spec.ground + h / 2, z - d / 2),
				Color = Color3.fromRGB(20 + math.floor(10 * hash3(row, k, 3)), 20, 26),
				Material = Enum.Material.Concrete,
				Anchored = true,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				CastShadow = false,
				Parent = folder,
			}) :: BasePart
			-- its windows: a few lit rows near the top (where the camera sees them), most of them lit
			local gui = Create("SurfaceGui", {
				Name = "Windows",
				Face = Enum.NormalId.Back,
				SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
				PixelsPerStud = 4,
				LightInfluence = 0,
				Brightness = 1.6,
				Parent = building,
			}) :: SurfaceGui
			local cols = math.max(2, math.floor(w / 3.2))
			local rows = math.min(12, math.floor(h / 4.5))
			for r = 0, rows - 1 do
				for c = 0, cols - 1 do
					if hash3(row * 31 + r, k * 17 + c, spec.seed) < 0.55 then
						local warm = hash3(r, c, k + row) < 0.7
						Create("Frame", {
							BorderSizePixel = 0,
							BackgroundColor3 = if warm
								then Color3.fromRGB(255, 212, 150)
								else Color3.fromRGB(196, 210, 255),
							Position = UDim2.fromScale((c + 0.25) / cols, (r * 4.5 + 1.2) / h),
							Size = UDim2.fromScale(0.5 / cols, 2.2 / h),
							Parent = gui,
						})
					end
				end
			end
			table.insert(refs.buildings, { gui = gui, order = -(z - d / 2) + 0.01 * k })
			x += w + 4 + 6 * hash3(row + 5, k, spec.seed)
			k += 1
		end
		z -= 34
		row += 1
	end
end

local function makeBoard(spec: any, origin: CFrame, folder: Instance)
	local n, s = spec.squares, spec.square
	local at = vec(spec.at)
	for i = 0, n - 1 do
		for j = 0, n - 1 do
			Create("Part", {
				Name = "Square",
				Size = Vector3.new(s, 0.5, s),
				CFrame = origin * CFrame.new(at.X - n * s / 2 + s / 2 + i * s, at.Y, at.Z - n * s / 2 + s / 2 + j * s),
				Color = rgb(if (i + j) % 2 == 0 then spec.light else spec.dark),
				Material = Enum.Material.Marble,
				Reflectance = 0.08,
				Anchored = true,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				Parent = folder,
			})
		end
	end
end

-- A chess piece of plain parts (as review_win.py draws them), with the ring that lights it up for a "glow" event.
local function makePiece(
	kind: string,
	color: string,
	x: number,
	z: number,
	origin: CFrame,
	folder: Instance
): { Instance }
	local tone = if color == "white" then Color3.fromRGB(226, 224, 218) else Color3.fromRGB(22, 22, 24)
	local shapes = if kind == "pawn"
		then {
			{ Vector3.new(0.8, 3.2, 3.2), 0.4, "Cylinder" },
			{ Vector3.new(2.6, 1.8, 1.8), 2.1, "Cylinder" },
			{ Vector3.new(1.9, 1.9, 1.9), 3.9, "Ball" },
		}
		else {
			{ Vector3.new(0.9, 3.4, 3.4), 0.45, "Cylinder" },
			{ Vector3.new(3.6, 2.4, 2.4), 2.7, "Cylinder" },
			{ Vector3.new(0.9, 2.9, 2.9), 4.9, "Cylinder" },
		}
	local made: { Instance } = {}
	for _, s in ipairs(shapes) do
		local cylinder = s[3] == "Cylinder"
		table.insert(
			made,
			Create("Part", {
				Shape = if cylinder then Enum.PartType.Cylinder else Enum.PartType.Ball,
				Size = s[1],
				CFrame = origin * CFrame.new(x, s[2], z) * (if cylinder
					then CFrame.Angles(0, 0, math.rad(90))
					else CFrame.identity),
				Color = tone,
				Material = Enum.Material.Marble,
				Anchored = true,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				Parent = folder,
			})
		)
	end
	if color == "white" then
		local ring = Create("Part", {
			Name = "Glow",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.12, 3.6, 3.6),
			CFrame = origin * CFrame.new(x, 0.06, z) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(236, 240, 255),
			Material = Enum.Material.Neon,
			Transparency = 1,
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Parent = folder,
		})
		Create("PointLight", { Color = Color3.fromRGB(220, 230, 255), Range = 9, Brightness = 0, Parent = ring })
		table.insert(made, ring)
	end
	return made
end

local function makeStrings(list: any, origin: CFrame, folder: Instance, refs: Refs)
	local holder = Create("Part", {
		Name = "Strings",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Transparency = 1,
		Size = Vector3.new(0.1, 0.1, 0.1),
		CFrame = origin,
		Parent = folder,
	})
	for _, s in ipairs(list) do
		local a = Create("Attachment", { WorldPosition = (origin * CFrame.new(vec(s.from))).Position, Parent = holder })
		local b =
			Create("Attachment", { WorldPosition = (origin * CFrame.new(vec(s.to))).Position, Parent = holder }) :: Attachment
		local beam = Create("Beam", {
			Attachment0 = a,
			Attachment1 = b,
			Color = ColorSequence.new(Color3.fromRGB(178, 20, 32)),
			Width0 = 0.07,
			Width1 = 0.07,
			FaceCamera = true,
			LightEmission = 0.15,
			LightInfluence = 0.8,
			Segments = 1,
			Parent = holder,
		}) :: Beam
		table.insert(refs.strings, { beam = beam, far = b })
	end
end

-- Where the cut's room stands in the cutscene sets (WinCuts `room`), when it is built there: the sets come with a case's
-- map, and an import older than the rooms has none (the floor under the mark is how the room is known). Nil
-- elsewhere (the lobby's shop): the cut then plays far off on its own stand-in parts.
local function roomMark(cut: any): CFrame?
	local room = cut.room
	if not room then
		return nil
	end
	local mark = CFrame.new(Venues.SETS + Vector3.new(room.at[1], 0, room.at[2]))
	local hit = workspace:Raycast(mark.Position + Vector3.new(0, 6, 0), Vector3.new(0, -8, 0))
	if hit and math.abs(hit.Position.Y - mark.Position.Y) < 1.2 then
		return mark
	end
	return nil
end

local function build(cut: any, origin: CFrame, folder: Instance, inRoom: boolean): Refs
	local refs: Refs = {
		parts = {},
		props = {},
		lights = {},
		emitters = {},
		strings = {},
		buildings = {},
		rows = {},
		folder = folder,
		origin = origin,
		star = nil,
		cleanups = {},
	}
	for _, spec in ipairs(cut.parts or {}) do
		if not (inRoom and spec.stand) then
			makePart(spec, origin, folder, refs)
		end
	end
	for _, spec in ipairs(cut.props or {}) do
		if not (inRoom and spec.stand) then
			makeProp(spec, origin, folder, refs)
		end
	end
	if cut.city then
		makeCity(cut.city, origin, folder, refs)
	end
	if cut.board then
		makeBoard(cut.board, origin, folder)
	end
	for _, group in ipairs(cut.pieces or {}) do
		for _, x in ipairs(group.xs) do
			local made = makePiece(group.kind, group.color, x, group.z, origin, folder)
			if group.row then
				refs.rows[group.row] = refs.rows[group.row] or {}
				for _, item in ipairs(made) do
					if item.Name == "Glow" then
						table.insert(refs.rows[group.row], item)
					end
				end
			end
		end
	end
	if cut.strings then
		makeStrings(cut.strings, origin, folder, refs)
	end
	return refs
end

-- Events ----------------------------------------------------------------------------------------------------

local function tween(
	instance: Instance,
	seconds: number,
	props: { [string]: any },
	style: Enum.EasingStyle?,
	dir: Enum.EasingDirection?
)
	local t = TweenService:Create(
		instance,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Sine, dir or Enum.EasingDirection.Out),
		props
	)
	t:Play()
	return t
end

-- Runs `fn(u)` from 0 to 1 over `seconds` (on RenderStepped), then `done`.
local function over(refs: Refs, seconds: number, fn: (number) -> (), done: (() -> ())?)
	local began = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local u = math.clamp((os.clock() - began) / math.max(seconds, 1e-3), 0, 1)
		fn(u)
		if u >= 1 then
			connection:Disconnect()
			if done then
				done()
			end
		end
	end)
	table.insert(refs.cleanups, function()
		connection:Disconnect()
	end)
end

local function each(event: any): { string }
	if type(event.targets) == "table" then
		return event.targets
	end
	return if event.target then { event.target } else {}
end

local function setShown(item: Instance, shown: boolean)
	local list = if item:IsA("BasePart") then { item } else item:GetDescendants()
	for _, part in ipairs(list) do
		if part:IsA("BasePart") then
			part.Transparency = if shown then (part:GetAttribute("Alpha") :: number? or 0) else 1
		end
	end
end

-- What each event `act` does (WinCuts `events`).
local ACTS: { [string]: (refs: Refs, event: any, cut: any) -> () } = {}

ACTS.show = function(refs, event)
	for _, name in ipairs(each(event)) do
		local item = refs.parts[name] or refs.props[name]
		if item then
			setShown(item, true)
		end
	end
end

ACTS.close = function(refs, event)
	local book = refs.props[event.target]
	if book then
		over(refs, event.seconds or 0.15, function(u)
			ManualBook.pose(book, 1 - u, 1 - u)
		end)
	end
end

ACTS.dim = function(refs, event)
	local entry = refs.lights[event.target]
	if entry then
		tween(entry.light, event.seconds or 0.4, { Brightness = entry.brightness * (event.to or 0) })
	end
end

-- Flames bend towards the star (the copy on the mark).
ACTS.lean = function(refs, event)
	local toward = refs.origin.Position + Vector3.new(0, 3, 0)
	for _, name in ipairs(each(event)) do
		local flame = refs.parts[name]
		if flame then
			local from = flame.CFrame
			local flat = Vector3.new(toward.X - from.X, 0, toward.Z - from.Z)
			local axis = if flat.Magnitude > 0.01 then flat.Unit:Cross(Vector3.yAxis) else Vector3.xAxis
			local bent = CFrame.new(from.Position) * CFrame.fromAxisAngle(axis, math.rad(-28)) * from.Rotation
			tween(flame, event.seconds or 0.8, { CFrame = bent })
			local emitter = refs.emitters[name]
			if emitter and flat.Magnitude > 0.01 then
				emitter.Acceleration = flat.Unit * 2.5
			end
		end
	end
end

ACTS.out = function(refs, event)
	for _, name in ipairs(each(event)) do
		local flame = refs.parts[name]
		local entry = refs.lights[name]
		local emitter = refs.emitters[name]
		if entry then
			tween(entry.light, 0.25, { Brightness = 0 })
		end
		if type(emitter) == "table" then
			-- (a living flame: it goes out with its own curl of smoke)
			emitter.out()
		elseif emitter then
			emitter.Enabled = false
		end
		if flame and type(emitter) ~= "table" then
			tween(flame, 0.15, { Transparency = 1 })
			smoke(flame.Position + Vector3.new(0, 0.2, 0), refs.folder, 8)
		end
	end
end

ACTS.flash = function(refs, event)
	local seconds = event.seconds or 0.3
	for _, name in ipairs(each(event)) do
		local entry = refs.lights[name]
		if entry then
			entry.light.Brightness = event.brightness or 5
			tween(entry.light, seconds, { Brightness = entry.brightness }, Enum.EasingStyle.Exponential)
		end
		local part = refs.parts[name]
		if part and part.Material == Enum.Material.Neon then
			local base = part.Color
			part.Color = rgb(event.color, Color3.new(1, 1, 1))
			tween(part, seconds, { Color = base }, Enum.EasingStyle.Exponential)
		end
	end
end

-- The Manual's pages torn loose: sheets spiralling up round a point, wider and higher, fading at the end.
ACTS.pages = function(refs, event)
	local centre = refs.origin * CFrame.new(vec(event.around))
	local count = event.count or 20
	local seconds = event.seconds or 4
	local sheets: { { part: BasePart, phase: number, speed: number, lift: number, tilt: number } } = {}
	local random = Random.new(41)
	for k = 1, count do
		local sheet = Create("Part", {
			Name = "Page",
			Size = Vector3.new(1.0, 0.03, 1.35),
			Color = Color3.fromRGB(232, 222, 196),
			Material = Enum.Material.SmoothPlastic,
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			CFrame = centre,
			Parent = refs.folder,
		}) :: BasePart
		table.insert(sheets, {
			part = sheet,
			phase = (k / count) * math.pi * 2,
			speed = random:NextNumber(1.6, 2.6),
			lift = random:NextNumber(7, 14),
			tilt = random:NextNumber(-1, 1),
		})
	end
	over(refs, seconds, function(u)
		for _, s in ipairs(sheets) do
			local a = s.phase + u * s.speed * math.pi * 2
			local radius = 1.2 + 4.8 * u
			local at = centre.Position + Vector3.new(math.cos(a) * radius, -1 + s.lift * u, math.sin(a) * radius)
			s.part.CFrame = CFrame.new(at) * CFrame.Angles(a * 1.3, a, s.tilt + u * 4)
			s.part.Transparency = math.clamp((u - 0.75) / 0.25, 0, 1)
		end
	end)
end

-- The city's lights die building by building, the farthest first, over `seconds`.
ACTS.cityOut = function(refs, event)
	local list = table.clone(refs.buildings)
	table.sort(list, function(a, b)
		return a.order > b.order
	end)
	local seconds = event.seconds or 2
	local n = #list
	over(refs, seconds, function(u)
		local upTo = math.floor(u * n + 0.5)
		for k = 1, upTo do
			list[k].gui.Enabled = false
		end
	end)
end

-- A string's far end whips to a part (the photo), then the string fades.
ACTS.snap = function(refs, event)
	local s = refs.strings[event.index]
	local target = refs.parts[event.toward]
	if not s or not target then
		return
	end
	local from = s.far.WorldPosition
	local to = target.Position
	over(refs, 0.14, function(u)
		s.far.WorldPosition = from:Lerp(to, u * u)
	end, function()
		s.beam.Color = ColorSequence.new(Color3.fromRGB(230, 40, 50))
		over(refs, 0.6, function(u)
			s.beam.Width0 = 0.07 * (1 - u)
			s.beam.Width1 = 0.07 * (1 - u)
		end)
	end)
end

-- Parts taken into the star's hand (welded to a body part at `grip`, keeping their arrangement).
ACTS.hold = function(refs, event)
	local star = refs.star
	local hand = star and star:FindFirstChild(event.part or "Right Arm")
	if not hand or not hand:IsA("BasePart") then
		return
	end
	local first = refs.parts[each(event)[1]]
	if not first then
		return
	end
	local anchor = hand.CFrame * CFrame.new(vec(event.grip))
	local offset = first.CFrame
	for _, name in ipairs(each(event)) do
		local part = refs.parts[name]
		if part then
			local relative = offset:ToObjectSpace(part.CFrame)
			part.Anchored = false
			part.Massless = true
			part.CFrame = anchor * relative
			Create("WeldConstraint", { Name = "Held", Part0 = hand, Part1 = part, Parent = part })
		end
	end
end

-- Parts put down again, at `place` (the first of them there, the rest kept round it).
ACTS.drop = function(refs, event)
	local first = refs.parts[each(event)[1]]
	if not first then
		return
	end
	local base = first.CFrame
	local goal = refs.origin * CFrame.new(vec(event.place))
	for _, name in ipairs(each(event)) do
		local part = refs.parts[name]
		if part then
			local relative = base:ToObjectSpace(part.CFrame)
			for _, weld in ipairs(part:GetChildren()) do
				if weld.Name == "Held" then
					weld:Destroy()
				end
			end
			part.Anchored = true
			part.CFrame = goal * CFrame.Angles(0, math.rad(-6), 0) * relative
		end
	end
end

-- The stamp's blow: CLOSED on the case file, a puff of dust.
ACTS.stamp = function(refs, event)
	local file = refs.parts[event.target]
	if file then
		local mark = file:FindFirstChild("Mark")
		if mark and mark:IsA("SurfaceGui") then
			mark.Enabled = true
		end
		smoke(file.Position + Vector3.new(0, 0.1, 0), refs.folder, 12, Color3.fromRGB(196, 190, 176))
		FxKit.shape("ring", CFrame.new(file.Position + Vector3.new(0, 0.12, 0)), {
			size = 4.5,
			seconds = 0.3,
			color = Color3.fromRGB(196, 190, 176),
			material = Enum.Material.ForceField,
			transparency = 0.15,
		})
	end
end

-- A model tipped over: turned about the bottom of its far side (away from the star), slowly, then fast.
ACTS.tip = function(refs, event)
	local model = refs.props[event.target]
	if not model then
		return
	end
	local pivot = model:GetPivot()
	local _, size = model:GetBoundingBox()
	local edge = pivot * CFrame.new(0, 0, -size.Z / 2) -- (the far side: -z, away from the star)
	local relative = edge:ToObjectSpace(pivot)
	over(refs, event.seconds or 1.8, function(u)
		local eased = u * u * u
		model:PivotTo(edge * CFrame.Angles(-math.rad(88) * eased, 0, 0) * relative)
	end)
end

-- A model shattered into shards (crimson) that fly out, fall and fade.
ACTS.shatter = function(refs, event)
	local model = refs.props[event.target]
	if not model then
		return
	end
	local cf, size = model:GetBoundingBox()
	setShown(model, false)
	local random = Random.new(7)
	local color = rgb(event.color, Color3.fromRGB(163, 25, 47))
	-- (the FX kit) the king bursts: a spike burst and a dome of crimson light where it stood
	FxKit.shape(
		"spikes",
		cf,
		{ size = size.Magnitude * 1.1, seconds = 0.25, color = color, transparency = 0.15, spin = 30 }
	)
	FxKit.shape(
		"dome",
		cf - Vector3.new(0, size.Y / 2, 0),
		{ size = size.Magnitude * 1.4, seconds = 0.45, color = color, transparency = 0.5 }
	)
	FxKit.light(cf.Position, color, 24, 6, 0.6)
	-- (and the blow itself: a star, a burst, sparks and spikes flung off it)
	Vfx.Recipes.impact(cf, { color = color, scale = math.clamp(size.Magnitude / 4, 0.6, 1.4), shake = false })
	local shards: { BasePart } = {}
	for _ = 1, event.count or 40 do
		local local_ = Vector3.new(
			random:NextNumber(-0.5, 0.5) * size.X,
			random:NextNumber(-0.5, 0.5) * size.Y,
			random:NextNumber(-0.5, 0.5) * size.Z
		)
		local at = cf * local_
		local shard = Create("WedgePart", {
			Name = "Shard",
			Size = Vector3.new(random:NextNumber(0.3, 1.1), random:NextNumber(0.2, 0.8), random:NextNumber(0.4, 1.4)),
			CFrame = CFrame.new(at)
				* CFrame.Angles(random:NextNumber(0, 6.28), random:NextNumber(0, 6.28), random:NextNumber(0, 6.28)),
			Color = if random:NextNumber() < 0.6 then color else Color3.fromRGB(20, 20, 22),
			Material = if random:NextNumber() < 0.5 then Enum.Material.Neon else Enum.Material.Glass,
			Anchored = false,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Parent = refs.folder,
		}) :: BasePart
		shard.AssemblyLinearVelocity = (at - cf.Position).Unit * random:NextNumber(14, 30) + Vector3.new(0, 10, 0)
		shard.AssemblyAngularVelocity = Vector3.new(random:NextNumber(-8, 8), random:NextNumber(-8, 8), 0)
		table.insert(shards, shard)
	end
	over(refs, 1.8, function(u)
		for _, shard in ipairs(shards) do
			shard.Transparency = math.clamp((u - 0.4) / 0.6, 0, 1)
		end
	end)
end

-- Fires lit (a part made with emit = "fire"): they catch and grow to `scale` of their size; `flare` burns them
-- taller (a file thrown on them).
ACTS.ignite = function(refs, event)
	for _, name in ipairs(each(event)) do
		local fire = refs.emitters[name]
		if type(fire) == "table" and fire.ignite then
			fire.ignite(event.scale)
			if event.flare then
				fire.flare(true)
				task.delay(event.seconds or 1.2, function()
					fire.flare(false)
				end)
			end
		end
		local part = refs.parts[name]
		if part then
			smoke(part.Position, refs.folder, 10, Color3.fromRGB(255, 150, 70))
		end
	end
end

-- Parts burned away (a page, a photo): blackened from their own colour, then gone in a breath of smoke and sparks.
ACTS.char = function(refs, event)
	local seconds = event.seconds or 1.5
	for _, name in ipairs(each(event)) do
		local part = refs.parts[name]
		if part then
			local base = part.Color
			local alpha = part.Transparency
			over(refs, seconds, function(u)
				part.Color = base:Lerp(Color3.fromRGB(26, 20, 16), math.clamp(u / 0.6, 0, 1))
				part.Transparency = alpha + (1 - alpha) * math.clamp((u - 0.55) / 0.45, 0, 1)
			end, function()
				smoke(part.Position, refs.folder, 12, Color3.fromRGB(60, 56, 54))
			end)
		end
	end
end

-- Parts (or a prop) thrown: off whatever held them, along an arc to `to` over `seconds` (`fall`: dropping faster
-- as they go, as a thing falls), turning `spin` turns about x, y and z; hidden where they land with `hide`.
ACTS.fling = function(refs, event)
	local names = each(event)
	local items: { { part: BasePart?, model: Model?, relative: CFrame } } = {}
	local base: CFrame? = nil
	for _, name in ipairs(names) do
		local part = refs.parts[name]
		local model = if part then nil else refs.props[name]
		local cf = if part then part.CFrame elseif model then model:GetPivot() else nil
		if cf then
			base = base or cf
			if part then
				for _, weld in ipairs(part:GetChildren()) do
					if weld.Name == "Held" then
						weld:Destroy()
					end
				end
				part.Anchored = true
			end
			table.insert(items, { part = part, model = model, relative = (base :: CFrame):ToObjectSpace(cf) })
		end
	end
	if not base then
		return
	end
	local from = (base :: CFrame).Position
	local goal = (refs.origin * CFrame.new(vec(event.to))).Position
	local turn = (base :: CFrame).Rotation
	local spin = if type(event.spin) == "table" then vec(event.spin) else Vector3.new(event.spin or 1, 0, 0)
	local arc = event.arc or 1
	over(refs, event.seconds or 1, function(u)
		local down = if event.fall then u * u else u
		local at = Vector3.new(
			from.X + (goal.X - from.X) * u,
			from.Y + (goal.Y - from.Y) * down,
			from.Z + (goal.Z - from.Z) * u
		) + Vector3.new(0, arc * 4 * u * (1 - u), 0)
		local cf = CFrame.new(at)
			* CFrame.Angles(spin.X * u * math.pi * 2, spin.Y * u * math.pi * 2, spin.Z * u * math.pi * 2)
			* turn
		for _, item in ipairs(items) do
			if item.part then
				item.part.CFrame = cf * item.relative
			elseif item.model then
				item.model:PivotTo(cf * item.relative)
			end
		end
	end, function()
		if event.hide then
			for _, item in ipairs(items) do
				setShown((item.part or item.model) :: Instance, false)
			end
		end
	end)
end

-- Words on a part (its `text`, made hidden) shown: a screen's headline, a label.
ACTS.text = function(refs, event)
	for _, name in ipairs(each(event)) do
		local part = refs.parts[name]
		local mark = part and part:FindFirstChild("Mark")
		if mark and mark:IsA("SurfaceGui") then
			mark.Enabled = true
		end
	end
end

-- A string of the board burning: it glows ember-orange along its length, then blackens and thins away.
ACTS.scorch = function(refs, event)
	local s = refs.strings[event.index]
	if not s then
		return
	end
	s.beam.LightEmission = 1
	s.beam.Color = ColorSequence.new(Color3.fromRGB(255, 150, 60))
	local a0 = s.beam.Attachment0
	if a0 then
		smoke(a0.WorldPosition:Lerp(s.far.WorldPosition, 0.5), refs.folder, 6, Color3.fromRGB(255, 120, 50))
	end
	over(refs, event.seconds or 0.9, function(u)
		s.beam.Color = ColorSequence.new(Color3.fromRGB(255, 150, 60):Lerp(Color3.fromRGB(20, 14, 12), u))
		s.beam.LightEmission = 1 - u
		s.beam.Width0 = 0.07 * (1 - u)
		s.beam.Width1 = 0.07 * (1 - u)
	end)
end

-- A row of the white pieces lights up.
ACTS.glow = function(refs, event)
	for _, ring in ipairs(refs.rows[event.row] or {}) do
		if ring:IsA("BasePart") then
			tween(ring, 0.4, { Transparency = 0.15 })
			local light = ring:FindFirstChildOfClass("PointLight")
			if light then
				tween(light, 0.4, { Brightness = 1.6 })
			end
		end
	end
end

WinCinema.ACTS = ACTS

-- Playing ---------------------------------------------------------------------------------------------------

export type Options = {
	userId: number?, -- the star (nil: the faceless figure)
	at: number?, -- the server time its first frame stands at (now when nil)
	wait: boolean?, -- block until it is over (the default); false returns at once with the stopper
	glideBack: boolean?, -- give the camera back with a glide (the shop's preview) instead of a cut
	onEnd: (() -> ())?,
}

-- Plays a win cutscene on this screen. Returns the function that stops it (and puts everything back).
function WinCinema.play(name: string, options: Options?): () -> ()
	local cut = WinCinema.get(name)
	local opts = options or {}
	if not cut then
		return function() end
	end
	local length = cut.length or 8
	local zero = opts.at or workspace:GetServerTimeNow()
	local camera = workspace.CurrentCamera
	local home, homeFov = if camera then camera.CFrame else CFrame.identity, if camera then camera.FieldOfView else 70
	local stage = Stage.new()
	local room = roomMark(cut)
	local origin = room or WinCinema.ORIGIN
	local refs: Refs? = nil
	local token = CameraDirector.take(length + TAIL + 2)
	local done = false
	local screen: { () -> () } = {}
	local sounds: { Sound } = {}
	local undress: (() -> ())? = nil

	local function finish()
		if done then
			return
		end
		done = true
		if WinCinema.current == name then
			WinCinema.current = nil
		end
		for _, cleanup in ipairs(screen) do
			pcall(cleanup)
		end
		if refs then
			for _, cleanup in ipairs(refs.cleanups) do
				pcall(cleanup)
			end
		end
		if undress then
			pcall(undress)
		end
		for _, sound in ipairs(sounds) do
			pcall(function()
				sound:Destroy()
			end)
		end
		pcall(function()
			stage:destroy()
		end)
		if opts.glideBack then
			CameraDirector.move(token, home, 0.6, homeFov, Enum.EasingStyle.Quint)
			task.delay(0.6, function()
				CameraDirector.release(token)
			end)
		else
			CameraDirector.release(token)
		end
		if opts.onEnd then
			task.spawn(opts.onEnd)
		end
	end

	local function step(fn: () -> ())
		if done then
			return
		end
		local ok, err = pcall(fn)
		if not ok then
			warn("[DeathsGambit] win cutscene " .. name .. ": " .. tostring(err))
			finish()
		end
	end

	WinCinema.current = name
	step(function()
		refs = build(cut, origin, stage.folder, room ~= nil)
		WinCinema.lastRefs = refs
		-- the star: a copy of the winner (their match look), or the faceless figure
		local source = if opts.userId then opts.userId else Stage.figure()
		local star = stage:cast(source :: any, origin, nil)
		if not star and opts.userId then
			star = stage:cast(Stage.figure() :: any, origin, nil)
		end
		if star then
			(refs :: Refs).star = star
			local elapsed = math.max(0, workspace:GetServerTimeNow() - zero)
			PoseController.bindWhenReady(star, 2)
			PoseController.play(star, cut.clip, { fadeIn = 0, startAt = os.clock() - elapsed })
			undress = EmoteController.dress(star, cut.clip, function()
				return not done
			end)
		end
		Cinema.letterbox(true)
		table.insert(screen, function()
			Cinema.letterbox(false)
		end)
		local grade = cut.grade
		if grade then
			table.insert(
				screen,
				Cinema.tint({
					Saturation = grade.saturation or 0,
					Contrast = grade.contrast or 0,
					Brightness = grade.brightness or 0,
					TintColor = rgb(grade.tint, Color3.new(1, 1, 1)),
				}, 0.3)
			)
		end
		if cut.vignette then
			table.insert(screen, Cinema.vignette(rgb(cut.vignette.color, Color3.new()), cut.vignette.strength))
		end
	end)
	if done then
		return finish
	end

	-- everything timed, in the cutscene's seconds
	local events: { { t: number, fn: () -> (), order: number? } } = {}
	local shots = cut.shots or {}
	for index, shot in ipairs(shots) do
		local nextAt = if shots[index + 1] then shots[index + 1].at else length
		local view =
			CFrame.lookAt((origin * CFrame.new(vec(shot.eye))).Position, (origin * CFrame.new(vec(shot.look))).Position)
		table.insert(events, {
			t = shot.at,
			fn = function()
				if (shot.glide or 0) > 0 then
					CameraDirector.move(token, view, shot.glide, shot.fov, Enum.EasingStyle.Sine)
				else
					CameraDirector.cut(token, view, shot.fov)
				end
			end,
		})
		local to = shot.to
		if to then
			local eye = (origin * CFrame.new(vec(to.eye or shot.eye))).Position
			local look = (origin * CFrame.new(vec(to.look or shot.look))).Position
			table.insert(events, {
				t = shot.at + (shot.glide or 0),
				fn = function()
					local seconds = math.max(0.1, nextAt - shot.at - (shot.glide or 0))
					CameraDirector.move(
						token,
						CFrame.lookAt(eye, look),
						seconds,
						to.fov or shot.fov,
						Enum.EasingStyle.Sine
					)
				end,
			})
		end
	end
	for _, beat in ipairs(cut.beats or {}) do
		table.insert(events, {
			t = beat.at,
			fn = function()
				if beat.kind == "flash" then
					Cinema.flash(rgb(beat.color, Color3.new(1, 1, 1)), beat.strength, beat.seconds)
				elseif beat.kind == "still" then
					Cinema.still(rgb(beat.color, Color3.new(1, 0.16, 0.2)), beat.seconds)
				elseif beat.kind == "shake" then
					CameraDirector.shake(token, beat.strength or 0.1, beat.seconds or 0.3)
				end
			end,
		})
	end
	for _, event in ipairs(cut.events or {}) do
		local act = ACTS[event.act]
		if act then
			table.insert(events, {
				t = event.at,
				fn = function()
					act(refs :: Refs, event, cut)
				end,
			})
		end
	end
	for _, cue in ipairs(cut.sounds or {}) do
		table.insert(events, {
			t = cue.at,
			fn = function()
				local sound = Sfx.play(cue.slot)
				if sound then
					table.insert(sounds, sound)
				end
			end,
		})
	end
	for index, event in ipairs(events) do
		event.order = index
	end
	table.sort(events, function(a, b)
		if a.t ~= b.t then
			return a.t < b.t
		end
		return (a.order :: number) < (b.order :: number)
	end)

	local runner = task.spawn(function()
		for _, event in ipairs(events) do
			Cinema.waitUntil(zero + event.t)
			if done then
				return
			end
			step(event.fn)
		end
		Cinema.waitUntil(zero + length + TAIL)
		finish()
	end)
	-- (a watchdog, whatever happens)
	task.delay(length + TAIL + 3 + math.max(0, zero - workspace:GetServerTimeNow()), finish)
	local function stop()
		if coroutine.status(runner) ~= "dead" and runner ~= coroutine.running() then
			pcall(task.cancel, runner)
		end
		finish()
	end
	if opts.wait ~= false then
		while not done do
			task.wait(0.05)
		end
	end
	return stop
end

-- Plays the cutscene for the local player as the shop's preview (in the lobby, starring them), unless one plays;
-- `onEnd` when it is over.
local previewing: (() -> ())? = nil
function WinCinema.preview(name: string, onEnd: (() -> ())?)
	if previewing or CameraDirector.busy() then
		return
	end
	previewing = WinCinema.play(name, {
		userId = Players.LocalPlayer.UserId,
		wait = false,
		glideBack = true,
		onEnd = function()
			previewing = nil
			if onEnd then
				onEnd()
			end
		end,
	})
end

function WinCinema.previewing(): boolean
	return previewing ~= nil
end

return WinCinema
