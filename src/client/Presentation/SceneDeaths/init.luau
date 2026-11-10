-- The scene deaths (rebuilt 2026-11-08 from the frame-by-frame sheets in art/refs/deaths/, the user's verdict on the
-- first build: copy each reference 1 for 1, its POV, its set, its extra characters, its UI, its length). Each is a
-- full cutscene on this screen alone, built far from everything: its set, its actors (the victim, the killer and the
-- extras, acting clips from art/scripts/scene_actors.py), its cameras (first person where the reference is), its
-- screen overlays and effects, each on its sheet's times. One module per scene beside this one returns
-- { length = seconds, build = function(ctx) }.
--
--   local stop = SceneDeaths.play("requiem", { victim = userId, at = serverTime, wait = false })
--
-- Played by the shop's Preview and the debug gallery (WinCinema.preview of "scene:<style>") and, in a case, by the death
-- cutscene after the Manual's shot (Presenters/Death), on every screen at once. Everything it made goes when it ends.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local PoseController = require(script.Parent.Parent.Anim.PoseController)
local Life = require(script.Parent.Parent.Anim.Life)
local Screens = require(script.Parent.Parent.UI.Screens)
local CameraDirector = require(script.Parent.CameraDirector)
local Cinema = require(script.Parent.Cinema)
local DeathScreen = require(script.Parent.DeathScreen)
local Stage = require(script.Parent.Stage)
local Vfx = require(script.Parent.Vfx)
local LightingController = require(script.Parent.Parent.World.LightingController)
local Sets = require(script.Sets)
local Costumes = require(script.Costumes) :: any
local Cast = require(script.Cast)
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local ModelLibrary = require(Shared:WaitForChild("ModelLibrary"))
local EmoteProps = require(Shared:WaitForChild("Anim"):WaitForChild("EmoteProps"))

local SceneDeaths = {}
SceneDeaths.Cast = Cast

SceneDeaths.ORIGIN = CFrame.new(-6000, 650, 6000) -- far off and high: no map, lobby or other set reaches here
SceneDeaths.current = nil :: string?
SceneDeaths.lastCtx = nil :: any -- (the last scene's context, for the harness's checks)

local NAMES = { "requiem", "blackwall", "god", "ironMan", "sam", "walrider", "sans", "patriot", "selection" }
local MODULES = {
	requiem = "Requiem",
	blackwall = "Blackwall",
	god = "God",
	ironMan = "IronMan",
	sam = "Sam",
	walrider = "Walrider",
	sans = "Sans",
	patriot = "Patriot",
	selection = "Selection",
}
local loaded: { [string]: any } = {}

local function scene(name: string): any
	if loaded[name] then
		return loaded[name]
	end
	local moduleName = MODULES[name]
	local module = moduleName and script:FindFirstChild(moduleName)
	if not module then
		return nil
	end
	local ok, result = pcall(require, module)
	if not ok then
		warn("[DeathsGambit] scene death " .. name .. " failed to load: " .. tostring(result))
		return nil
	end
	loaded[name] = result
	return result
end

function SceneDeaths.has(name: string?): boolean
	return name ~= nil and MODULES[name] ~= nil and scene(name) ~= nil
end

function SceneDeaths.length(name: string?): number
	local s = if name then scene(name) else nil
	return if s then s.length else 0
end

function SceneDeaths.names(): { string }
	return table.clone(NAMES)
end

-- The context ---------------------------------------------------------------------------------------------------------

local Ctx = {}
Ctx.__index = Ctx

-- Seconds into the scene now.
function Ctx:now(): number
	return workspace:GetServerTimeNow() - self.zero
end

-- A point or frame in the scene's own space (y up, origin on its floor) to the world.
function Ctx:world(v: Vector3): Vector3
	return self.origin:PointToWorldSpace(v)
end

function Ctx:frame(cf: CFrame): CFrame
	return self.origin * cf
end

-- A part of the set. spec: size, at (scene space), rot (degrees, x y z), color, material, alpha, glow (neon),
-- shape ("Ball", "Cylinder", "Wedge"), name, cast (shadow; default on unless glowing or see-through).
function Ctx:part(spec: { [string]: any }): BasePart
	local part: BasePart
	if spec.shape == "Wedge" then
		part = Instance.new("WedgePart")
	else
		part = Instance.new("Part")
		if spec.shape then
			(part :: Part).Shape = (Enum.PartType :: any)[spec.shape]
		end
	end
	part.Name = spec.name or "Piece"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Size = spec.size or Vector3.one
	local rot = spec.rot or Vector3.zero
	part.CFrame = self.origin
		* CFrame.new(spec.at or Vector3.zero)
		* CFrame.fromEulerAnglesYXZ(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))
	part.Color = spec.color or Color3.fromRGB(40, 40, 44)
	part.Material = if spec.glow then Enum.Material.Neon else spec.material or Enum.Material.SmoothPlastic
	part.Transparency = spec.alpha or 0
	part.CastShadow = if spec.cast ~= nil then spec.cast else not spec.glow and (spec.alpha or 0) < 0.5
	part.Parent = self.stage.folder
	return part
end

-- A light on an invisible point (scene space).
function Ctx:light(at: Vector3, color: Color3, range: number, brightness: number, shadows: boolean?): PointLight
	local p = self:part({ size = Vector3.new(0.2, 0.2, 0.2), at = at, alpha = 1, cast = false })
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = shadows == true
	light.Parent = p
	return light
end

-- Text on a part's face (a painted number, an engraving).
function Ctx:text(part: BasePart, face: Enum.NormalId, text: string, color: Color3, font: Enum.Font?, scale: number?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 120 -- (crisp in a close-up: the headstone's name fills the frame)
	gui.LightInfluence = 1
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, scale or 1)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.TextScaled = true
	label.Font = font or Enum.Font.GothamBlack
	label.TextColor3 = color
	label.Text = text
	label.Parent = gui
	return label
end

-- The scene's set, modelled in Blender (SceneDeaths/Sets: the Scenes import), cloned into the stage. Returns it, or nil
-- without the import: the scene then builds its stand-in set of parts.
function Ctx:set(): Folder?
	local folder = Sets.build(self.name, self.origin, self.stage.folder)
	self.built = folder ~= nil
	return folder
end

-- Whether the scenes' import is here at all (its skies come with it: a void scene shows its sky instead of a box).
function Ctx:imported(): boolean
	return Sets.available()
end

-- Shafts of sunlight through gaps (the trees, the smoke) while the scene plays: Roblox's sun rays, aimed by the
-- scene's look (LightingPresets.scenes).
function Ctx:sunRays(intensity: number, spread: number)
	local rays = Instance.new("SunRaysEffect")
	rays.Name = "SceneSunRays"
	rays.Intensity = intensity
	rays.Spread = spread
	rays.Parent = Lighting
	table.insert(self.cleanups, function()
		rays:Destroy()
	end)
end

-- A soft focus on whatever stands `distance` studs from the lens (close-ups), from t0 to t1.
function Ctx:focus(t0: number, t1: number, distance: number, radius: number?)
	self:at(t0, function()
		local undo = Cinema.focus(distance, radius)
		table.insert(self.cleanups, undo)
		self:atNow(t1, undo)
	end)
end

-- Starts `clip` on an actor in step with the scene (from scene time `from`, default 0).
function Ctx:act(actor: Model, clip: string, from: number?, speed: number?)
	PoseController.bindWhenReady(actor, 2)
	PoseController.play(actor, clip, { fadeIn = 0, startAt = self.clockZero + (from or 0), speed = speed })
end

-- An actor: `who` a userId (their look; the faceless figure when they have no body here) or "figure"; standing on
-- `at` (scene space: a floor point and the way it faces). Plays `clip` from scene time `from`. `life` (0 to 1,
-- default LIFE) is how much Anim/Life breathes, shifts and glances over the clip (2026-11-09: held poses read as
-- frozen without it; small life is too fine for the exported keys, which drop moves under 0.6 degrees).
local LIFE = 0.8
function Ctx:actor(who: any, at: CFrame, clip: string?, from: number?, scale: number?, life: number?): Model?
	-- who: a userId, a Model (a player dressed in a costume: Cast.dressed), "cast:<costume>" (an extra in its marketplace
	-- costume, Cast), or anything else for the plain figure
	local source: any = if type(who) == "number" or typeof(who) == "Instance" then who else nil
	if type(who) == "string" and string.sub(who, 1, 5) == "cast:" then
		source = Cast.get(string.sub(who, 6))
	end
	source = source or Stage.figure()
	local actor = self.stage:cast(source :: any, self.origin * at, nil)
	if not actor and type(who) == "number" then
		actor = self.stage:cast(Stage.figure() :: any, self.origin * at, nil)
	end
	if not actor then
		return nil
	end
	actor:SetAttribute(Life.ATTRIBUTE, life or LIFE)
	-- (no overhead name tag or role label floating in a cutscene's frame)
	for _, item in ipairs(actor:GetDescendants()) do
		if item:IsA("BillboardGui") then
			item:Destroy()
		end
	end
	if scale and scale ~= 1 then
		-- (scaled about its root: lifted so its feet stay on the floor; an R6 root stands 3 studs up)
		actor:ScaleTo(scale)
		actor:PivotTo(actor:GetPivot() + Vector3.new(0, (scale - 1) * 3, 0))
	end
	if clip then
		self:act(actor, clip, from)
	end
	return actor
end

function Ctx:limb(actor: Model, name: string): BasePart?
	local p = actor:FindFirstChild(name)
	return if p and p:IsA("BasePart") then p else nil
end

-- Recolours an actor (a figure's costume): look = { head, torso, arms, legs = Color3, material, face = false hides
-- the face }.
function Ctx:dress(actor: Model, look: { [string]: any })
	for _, item in ipairs(actor:GetDescendants()) do
		if item:IsA("BasePart") then
			local name = item.Name
			local color = if name == "Head"
				then look.head
				elseif name == "Torso" then look.torso
				elseif name == "Left Arm" or name == "Right Arm" then look.arms
				elseif name == "Left Leg" or name == "Right Leg" then look.legs
				else nil
			if color then
				item.Color = color
				if look.material then
					item.Material = look.material
				end
			end
		elseif item:IsA("Decal") and look.face == false then
			item.Transparency = 1
		end
	end
end

-- A part welded to an actor's limb, `at` in the limb's own frame. Returns it.
function Ctx:attach(actor: Model, limbName: string, spec: { [string]: any }): BasePart?
	local limb = self:limb(actor, limbName)
	if not limb then
		return nil
	end
	local part = self:part(spec)
	part.Anchored = false
	part.Massless = true
	local rot = spec.rot or Vector3.zero
	part.CFrame = limb.CFrame
		* CFrame.new(spec.at or Vector3.zero)
		* CFrame.fromEulerAnglesYXZ(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = limb
	weld.Part1 = part
	weld.Parent = part
	part.Parent = actor
	return part
end

-- A costume piece (Costumes: a helmet, a vest, a blade) worn by an actor: the Core model, scaled to its size, welded to
-- its body part where it sits. Before the import that holds them (Costumes.CORE) a held piece shows its plain stand-in
-- part, a worn one nothing at all (never a block stuck on a head). Returns the model.
function Ctx:wear(actor: Model, key: string): Model?
	local spec = Costumes[key]
	local limb = if spec then self:limb(actor, spec.mount) else nil
	if not spec or not limb then
		return nil
	end
	local model: Model? = nil
	-- (a scaled actor, the towering warlord, wears its pieces scaled with it)
	local k = actor:GetScale()
	if ModelLibrary.version("ModelsCore") >= Costumes.CORE then
		model = ModelLibrary.get(spec.model)
	end
	if model then
		local _, size = model:GetBoundingBox()
		local biggest = math.max(size.X, size.Y, size.Z)
		if biggest > 0 then
			model:ScaleTo(model:GetScale() * spec.size * k / biggest)
		end
	elseif spec.stand then
		local holder = Instance.new("Model")
		local part = Instance.new("Part")
		part.Size = Vector3.new(spec.stand.size[1], spec.stand.size[2], spec.stand.size[3]) * k
		part.Color = Color3.fromRGB(spec.stand.color[1], spec.stand.color[2], spec.stand.color[3])
		part.Material = Enum.Material.SmoothPlastic
		part.Parent = holder
		holder.PrimaryPart = part
		model = holder
	end
	if not model then
		return nil
	end
	model.Name = "Costume_" .. key
	model:SetAttribute("CostumeScale", k)
	local at = EmoteProps.steps(spec.at)
	model:PivotTo(limb.CFrame * CFrame.new(at.Position * k) * at.Rotation)
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") then
			item.Anchored = false
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
			item.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = limb
			weld.Part1 = item
			weld.Parent = item
		end
	end
	model.Parent = actor
	return model
end

-- A Costumes model standing in the scene (the old man's wheelchair): its pivot at `at` (scene space). Nil before the
-- import that holds it, so the scene keeps its stand-in.
function Ctx:place(key: string, at: CFrame): Model?
	local spec = Costumes[key]
	if not spec or ModelLibrary.version("ModelsCore") < Costumes.CORE then
		return nil
	end
	local model = ModelLibrary.get(spec.model)
	if not model then
		return nil
	end
	local _, size = model:GetBoundingBox()
	local biggest = math.max(size.X, size.Y, size.Z)
	if biggest > 0 then
		model:ScaleTo(model:GetScale() * spec.size / biggest)
	end
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
		end
	end
	model:PivotTo(self.origin * at)
	model.Parent = self.stage.folder
	return model
end

-- Where a named point of a worn piece is now (world): Costumes' `muzzle`, `tip`, `base` (from the piece's pivot), or a
-- list entry (`list`, `index`: the gauntlet's sockets).
function Ctx:pointOf(piece: Model, key: string, name: string, index: number?): Vector3
	local spec = Costumes[key]
	local p = if index then Costumes[name][index] else spec and spec[name]
	local k = piece:GetAttribute("CostumeScale") or 1
	if not p then
		return piece:GetPivot().Position
	end
	return piece:GetPivot():PointToWorldSpace(Vector3.new(p[1], p[2], p[3]) * k)
end

-- A face drawn over an actor's head (DeathScreen.face): "shock", "shout", "pain", "sleep", "smug".
function Ctx:face(actor: Model, kind: string)
	local head = self:limb(actor, "Head")
	if head then
		DeathScreen.face(head, kind)
	end
end

-- `fn` at scene time `t` (in order with everything else).
function Ctx:at(t: number, fn: () -> ())
	table.insert(self.events, { t = t, fn = fn, order = #self.events })
end

-- `fn(t, dt)` every frame from t0 to t1 (scene times).
function Ctx:during(t0: number, t1: number, fn: (number, number) -> ())
	table.insert(self.frames, { t0 = t0, t1 = t1, fn = fn })
end

-- A camera shot at `t`: eye and look in scene space (or functions of the scene time returning them), held, or
-- moving to `to` (eye, look, fov) by the next shot.
function Ctx:shot(t: number, eye: any, look: any, fov: number, to: { [string]: any }?)
	table.insert(self.shots, { t = t, eye = eye, look = look, fov = fov, to = to })
end

-- The camera every frame from t0 to t1 from fn(t) -> (CFrame in scene space, fov): first person, a ride.
function Ctx:camera(t0: number, t1: number, fn: (number) -> (CFrame, number))
	table.insert(self.shots, { t = t0, until_ = t1, follow = fn })
end

-- A full-screen layer for this scene's overlays (the HUDs), above the picture and under the letterbox's bars.
function Ctx:layer(z: number?): Frame
	local frame = Instance.new("Frame")
	frame.Name = "SceneLayer"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 1)
	frame.ZIndex = z or 3
	frame.Parent = self.gui
	return frame
end

-- A subtitle at `t` for `seconds`.
function Ctx:say(t: number, text: string, seconds: number)
	self:at(t, function()
		table.insert(self.cleanups, Cinema.subtitle(text, seconds))
	end)
end

-- A colour grade from t0 to t1 (Cinema.tint props).
function Ctx:grade(t0: number, t1: number?, props: { [string]: any }, fade: number?)
	self:at(t0, function()
		local undo = Cinema.tint(props, fade or 0.15)
		table.insert(self.cleanups, undo)
		if t1 then
			self:atNow(t1, undo)
		end
	end)
end

-- (from inside an event: `fn` at scene time `t`, run by the frame loop)
function Ctx:atNow(t: number, fn: () -> ())
	table.insert(self.frames, {
		t0 = t,
		t1 = t + 0.001,
		once = true,
		fn = function()
			fn()
		end,
	})
end

-- Where a world point is on the screen (0..1), and whether it is in front.
function Ctx:screen(world: Vector3): (Vector2, boolean)
	local camera = workspace.CurrentCamera
	local p, onScreen = camera:WorldToViewportPoint(world)
	local size = camera.ViewportSize
	return Vector2.new(p.X / size.X, p.Y / size.Y), onScreen and p.Z > 0
end

-- A tween on any instance (a part fading, a light dimming), from now.
function Ctx:tween(item: Instance, seconds: number, props: { [string]: any }, style: Enum.EasingStyle?)
	local tween = TweenService:Create(item, TweenInfo.new(seconds, style or Enum.EasingStyle.Sine), props)
	tween:Play()
	return tween
end

-- An actor fading to nothing over `seconds` (its parts and decals).
function Ctx:fadeOut(actor: Model, seconds: number)
	for _, item in ipairs(actor:GetDescendants()) do
		local part = item:IsA("BasePart") and item.Transparency < 1 and item.Name ~= "HumanoidRootPart"
		if part or item:IsA("Decal") then
			self:tween(item, seconds, { Transparency = 1 })
		end
	end
end

-- Playing --------------------------------------------------------------------------------------------------------------

export type Options = {
	victim: number?, -- whose death it is (their look); nil: the faceless figure
	saluter: number?, -- the patriot's grave: who salutes
	named: string?, -- the name the scene shows (a headstone, a target tag)
	at: number?, -- the server time its first frame stands at (now when nil)
	wait: boolean?,
	glideBack: boolean?,
	onEnd: (() -> ())?,
}

function SceneDeaths.play(name: string, options: Options?): () -> ()
	local def = scene(name)
	local opts = options or {}
	if not def then
		return function() end
	end
	local length = def.length
	local zero = opts.at or workspace:GetServerTimeNow()
	local camera = workspace.CurrentCamera
	local home, homeFov = camera.CFrame, camera.FieldOfView
	local token = CameraDirector.take(length + 3)
	local gui = Instance.new("Frame")
	gui.Name = "SceneDeath"
	gui.BackgroundTransparency = 1
	gui.Size = UDim2.fromScale(1, 1)
	gui.ZIndex = 2
	gui.Parent = Screens.cinematic
	local victimName = "Unknown"
	if opts.victim then
		local who = Players:GetPlayerByUserId(opts.victim)
		victimName = if who then who.DisplayName else victimName
	end
	local ctx = setmetatable({
		name = name,
		origin = SceneDeaths.ORIGIN,
		stage = Stage.new(),
		zero = zero,
		clockZero = os.clock() - (workspace:GetServerTimeNow() - zero),
		token = token,
		gui = gui,
		events = {},
		frames = {},
		shots = {},
		cleanups = {},
		victim = opts.victim,
		saluter = opts.saluter,
		victimName = opts.named or victimName,
		length = length,
	}, Ctx)
	SceneDeaths.lastCtx = ctx
	SceneDeaths.current = name
	-- (lit by its own look while it plays, not by whatever venue the far-off camera falls in)
	LightingController.scene(name)
	local done = false
	local runner: thread? = nil
	local frameConn: RBXScriptConnection? = nil

	local function finish()
		if done then
			return
		end
		done = true
		if SceneDeaths.current == name then
			SceneDeaths.current = nil
			LightingController.scene(nil)
		end
		if frameConn then
			frameConn:Disconnect()
		end
		for index = #ctx.cleanups, 1, -1 do
			pcall(ctx.cleanups[index])
		end
		pcall(function()
			ctx.stage:destroy()
		end)
		gui:Destroy()
		Cinema.letterbox(false)
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

	local ok, err = pcall(def.build, ctx)
	if not ok then
		warn("[DeathsGambit] scene death " .. name .. ": " .. tostring(err))
		finish()
		return function() end
	end
	Cinema.letterbox(true)
	-- (from black: the engine lights a place the camera has just jumped to over its first few frames, so a scene played
	-- from its start opens on black for a beat and fades up, never on a half-lit frame)
	if workspace:GetServerTimeNow() - zero < 0.2 then
		local veil = Instance.new("Frame")
		veil.Name = "FromBlack"
		veil.BackgroundColor3 = Color3.new(0, 0, 0)
		veil.BorderSizePixel = 0
		veil.Size = UDim2.fromScale(1, 1)
		veil.ZIndex = 50
		veil.Parent = gui
		task.delay(0.3, function()
			if veil.Parent then
				TweenService:Create(veil, TweenInfo.new(0.45, Enum.EasingStyle.Sine), { BackgroundTransparency = 1 })
					:Play()
				task.delay(0.5, function()
					veil:Destroy()
				end)
			end
		end)
	end
	table.sort(ctx.shots, function(a, b)
		return a.t < b.t
	end)
	-- the shots become events: a cut (or a move to `to` until the next shot), or a followed camera
	for index, s in ipairs(ctx.shots) do
		local nextAt = if ctx.shots[index + 1] then ctx.shots[index + 1].t else length
		if s.follow then
			local t1 = s.until_ or nextAt
			ctx:during(s.t, t1, function(t)
				local cf, fov = s.follow(t)
				CameraDirector.cut(token, ctx.origin * cf, fov)
			end)
		else
			ctx:at(s.t, function()
				local function resolve(v: any): Vector3
					return if type(v) == "function" then v(ctx:now()) else v
				end
				local eye, look = resolve(s.eye), resolve(s.look)
				CameraDirector.cut(token, CFrame.lookAt(ctx:world(eye), ctx:world(look)), s.fov)
				if s.to then
					local toEye = if s.to.eye then resolve(s.to.eye) else eye
					local toLook = if s.to.look then resolve(s.to.look) else look
					CameraDirector.move(
						token,
						CFrame.lookAt(ctx:world(toEye), ctx:world(toLook)),
						math.max(0.1, nextAt - s.t),
						s.to.fov or s.fov,
						Enum.EasingStyle.Sine
					)
				end
			end)
		end
	end
	table.sort(ctx.events, function(a, b)
		if a.t ~= b.t then
			return a.t < b.t
		end
		return a.order < b.order
	end)
	local last = os.clock()
	frameConn = RunService.RenderStepped:Connect(function()
		local now = os.clock()
		local dt = now - last
		last = now
		local t = ctx:now()
		for index = #ctx.frames, 1, -1 do
			local f = ctx.frames[index]
			if t >= f.t0 and t <= f.t1 + (if f.once then 10 else 0) then
				local fine, problem = pcall(f.fn, t, dt)
				if not fine then
					warn("[DeathsGambit] scene death " .. name .. " frame: " .. tostring(problem))
				end
				if f.once then
					table.remove(ctx.frames, index)
				end
			elseif t > f.t1 and not f.once then
				table.remove(ctx.frames, index)
			end
		end
	end)
	runner = task.spawn(function()
		for _, event in ipairs(ctx.events) do
			Cinema.waitUntil(zero + event.t)
			if done then
				return
			end
			local fine, problem = pcall(event.fn)
			if not fine then
				warn("[DeathsGambit] scene death " .. name .. " at " .. event.t .. ": " .. tostring(problem))
			end
		end
		Cinema.waitUntil(zero + length)
		finish()
	end)
	task.delay(length + 4 + math.max(0, zero - workspace:GetServerTimeNow()), finish)
	local function stop()
		if runner and coroutine.status(runner) ~= "dead" and runner ~= coroutine.running() then
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

-- Shared bits the scenes use -------------------------------------------------------------------------------------------

-- A room-sized box round the set (a floor, four walls, a ceiling) of one colour, so nothing of the world shows.
function SceneDeaths.box(ctx: any, size: Vector3, centre: Vector3, color: Color3, material: Enum.Material?)
	local t = 2
	local x, y, z = size.X, size.Y, size.Z
	local specs = {
		{ Vector3.new(x, t, z), centre + Vector3.new(0, -t / 2, 0) },
		{ Vector3.new(x, t, z), centre + Vector3.new(0, y + t / 2, 0) },
		{ Vector3.new(t, y, z), centre + Vector3.new(-x / 2 - t / 2, y / 2, 0) },
		{ Vector3.new(t, y, z), centre + Vector3.new(x / 2 + t / 2, y / 2, 0) },
		{ Vector3.new(x, y, t), centre + Vector3.new(0, y / 2, -z / 2 - t / 2) },
		{ Vector3.new(x, y, t), centre + Vector3.new(0, y / 2, z / 2 + t / 2) },
	}
	local parts = {}
	for _, s in ipairs(specs) do
		table.insert(parts, ctx:part({ size = s[1], at = s[2], color = color, material = material, cast = false }))
	end
	return parts
end

-- A held emitter on a still box of air (scene space), let go at scene time t1. Returns it.
function SceneDeaths.emit(ctx: any, at: Vector3, size: Vector3, spec: { [string]: any }, t0: number?, t1: number?)
	local box = ctx:part({ size = size, at = at, alpha = 1, cast = false })
	spec.shape = spec.shape or Enum.ParticleEmitterShape.Box
	local emitter = Vfx.Emit.make(box, spec)
	emitter.Enabled = t0 == nil or t0 <= 0
	if t0 and t0 > 0 then
		ctx:at(t0, function()
			emitter.Enabled = true
		end)
	end
	if t1 then
		ctx:at(t1, function()
			emitter.Enabled = false
		end)
	end
	return emitter
end

return SceneDeaths
