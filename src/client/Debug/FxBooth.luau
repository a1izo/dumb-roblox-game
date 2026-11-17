--!strict
-- The effects booth (the VFX rework, ticket V0.1): any one effect in the game (Presentation/Vfx/Catalog) played alone, by
-- name, on a dummy in a cell of its own far from the map, and held at a chosen moment, to look at or to take pictures
-- of. The debug panel's Effects tab drives it; a harness probe drives it through the same functions.
--
-- The cell stands 6000 studs out (the camera that far from the body counts as away: World/Away parks the crowd and the
-- rain), a mid-grey floor and walls, a dummy, two soft lamps. Three switches:
--   backdrop  "dark" (the grey under a dim light, as a night map) or "lit" (a bright room: light walls, full ambient)
--   camera    "follow" (18 studs back, as a player sees their own emote) or "close" (8 studs)
--   hold      play, and freeze the kit's clock at the effect's main beat (then step() or release())
--
-- Harness hooks: FxBooth.list(), FxBooth.play(id, opts), FxBooth.stop(), FxBooth.at(id, seconds) (plays the effect and
-- holds the kit's clock `seconds` after its hit), step(seconds), release(), leftovers() (what Stop must leave at 0),
-- verify() (the catalogue against the game's own lists). play() and at() yield while a stopped effect settles.
--
-- A whole scene (a win cutscene, a scene death, a writing style: Catalog entries marked `whole`) plays on the player's
-- own camera as the cutscene gallery's does, so the booth hands the camera over; the kit's clock does not hold it.
-- Only what the kit made is held: an emote's body clip and the older emitters made outside the kit run on.

local RunService = game:GetService("RunService")

local Catalog = require(script.Parent.Parent.Presentation.Vfx.Catalog)
local CameraDirector = require(script.Parent.Parent.Presentation.CameraDirector)
local LightingController = require(script.Parent.Parent.World.LightingController)
local Stage = require(script.Parent.Parent.Presentation.Stage)
local Vfx = require(script.Parent.Parent.Presentation.Vfx)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LightingPresets = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LightingPresets"))

local Clock = Vfx.Clock

local FxBooth = {}

-- Where the dummy stands (the floor's top).
FxBooth.ORIGIN = Vector3.new(6000, 650, 6000)
local ORIGIN = FxBooth.ORIGIN

export type Options = {
	backdrop: string?, -- "dark" or "lit"
	camera: string?, -- "follow" or "close"
	hold: boolean?, -- freeze the kit's clock at the effect's hit
	preview: boolean?, -- an emote plays as the shop's preview does (no aura, no lights or billboards)
	yaw: number?, -- degrees the camera turns round the dummy (0: behind it)
	onEnd: (() -> ())?, -- a whole scene or a stop ends it: called once
}

local state = { backdrop = "dark", camera = "follow", hold = false, preview = false, yaw = 0 }

type Run = {
	entry: Catalog.Entry,
	stop: () -> (),
	startedAt: number,
	whole: boolean,
	onEnd: (() -> ())?,
	finished: boolean,
}

local current: Run? = nil
local runId = 0
local settleUntil = 0
local SETTLE = 1.5 -- seconds a stopped effect's late callbacks are swept for

local cell: Folder? = nil
local props: Folder? = nil
local floorPart: Part? = nil
local walls: { Part } = {}
local lamps: { PointLight } = {}
local set: any = nil
local token: number? = nil
local sweeper: RBXScriptConnection? = nil

local LOOKS = { dark = "FxBoothDark", lit = "FxBoothLit" }

-- The scene looks the booth lights itself with, made from the Manual's (a plain, ambient-lit one) the first time: dark
-- is a night's grey, lit a bright room. (Registered here on this client only; LightingPresets.scenes is read by key.)
local function registerLooks()
	local scenes = LightingPresets.scenes :: any
	local base = scenes.manual
	if not base then
		return
	end
	local dark = table.clone(base)
	dark.clockTime = 0
	dark.brightness = 0
	dark.exposure = 0
	dark.ambient = Color3.fromRGB(46, 46, 52)
	dark.outdoorAmbient = Color3.fromRGB(46, 46, 52)
	dark.envDiffuse = 0.3
	dark.envSpecular = 0.3
	dark.saturation = 0
	dark.contrast = 0.08
	dark.tint = Color3.new(1, 1, 1)
	dark.bloom = 0.45
	dark.bloomThreshold = 1.8
	dark.density = 0
	dark.haze = 0
	scenes[LOOKS.dark] = dark
	local lit = table.clone(base)
	lit.clockTime = 14
	lit.brightness = 2
	lit.exposure = 0
	lit.ambient = Color3.fromRGB(205, 205, 208)
	lit.outdoorAmbient = Color3.fromRGB(205, 205, 208)
	lit.envDiffuse = 0.6
	lit.envSpecular = 0.4
	lit.saturation = 0
	lit.contrast = 0.04
	lit.tint = Color3.new(1, 1, 1)
	lit.bloom = 0.3
	lit.bloomThreshold = 1.8
	lit.density = 0
	lit.haze = 0
	scenes[LOOKS.lit] = lit
end

-- What the booth leaves in the camera, cleared: the kit's folder and the screen effects it hangs there.
local function purge()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local folder = camera:FindFirstChild("DGVfx")
	if folder then
		folder:ClearAllChildren()
	end
	for _, child in ipairs(camera:GetChildren()) do
		if child ~= folder and string.sub(child.Name, 1, 5) == "DGVfx" then
			child:Destroy()
		end
	end
end

-- How much the kit has in the camera now (Stop must leave 0).
function FxBooth.leftovers(): number
	local camera = workspace.CurrentCamera
	if not camera then
		return 0
	end
	local count = 0
	local folder = camera:FindFirstChild("DGVfx")
	if folder then
		count += #folder:GetChildren()
	end
	for _, child in ipairs(camera:GetChildren()) do
		if child ~= folder and string.sub(child.Name, 1, 5) == "DGVfx" then
			count += 1
		end
	end
	return count
end

-- Keeps sweeping the camera for the settle time after a stop: a stopped effect's last delayed pieces land in it.
local function sweep()
	if sweeper then
		return
	end
	sweeper = RunService.Heartbeat:Connect(function()
		purge()
		if os.clock() >= settleUntil and sweeper then
			sweeper:Disconnect()
			sweeper = nil
		end
	end)
end

-- The cell ------------------------------------------------------------------------------------------------------------

local function slab(name: string, size: Vector3, centre: Vector3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = true
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Size = size
	part.Position = centre
	part.Parent = parent
	return part
end

local function paint()
	local lit = state.backdrop == "lit"
	if floorPart then
		floorPart.Color = if lit then Color3.fromRGB(196, 196, 200) else Color3.fromRGB(122, 122, 126)
	end
	for _, wall in ipairs(walls) do
		wall.Color = if lit then Color3.fromRGB(226, 226, 229) else Color3.fromRGB(118, 118, 122)
	end
	for _, lamp in ipairs(lamps) do
		lamp.Brightness = if lit then 0.7 else 0.55
	end
end

local function applyLook()
	-- (a copy of LightingController that was never init()ed, as a command-bar require makes, has no effects to blend:
	-- it would fail on a nil Instance in TweenService:Create and then think the look was set)
	if cell and (LightingController.atmosphere() :: Atmosphere?) then
		LightingController.scene(LOOKS[state.backdrop] or LOOKS.dark)
	end
end

local function ensureCell()
	if cell and cell.Parent then
		return
	end
	registerLooks()
	local folder = Instance.new("Folder")
	folder.Name = "DGFxBooth"
	folder.Parent = workspace
	cell = folder
	floorPart = slab("Floor", Vector3.new(100, 1, 100), ORIGIN - Vector3.new(0, 0.5, 0), folder)
	walls = {
		slab("Back", Vector3.new(100, 40, 1), ORIGIN + Vector3.new(0, 20, -26), folder),
		slab("Front", Vector3.new(100, 40, 1), ORIGIN + Vector3.new(0, 20, 34), folder),
		slab("Left", Vector3.new(1, 40, 100), ORIGIN + Vector3.new(-34, 20, 4), folder),
		slab("Right", Vector3.new(1, 40, 100), ORIGIN + Vector3.new(34, 20, 4), folder),
	}
	local holder = slab("Lamps", Vector3.new(0.2, 0.2, 0.2), ORIGIN + Vector3.new(0, 18, 6), folder)
	holder.Transparency = 1
	holder.CanCollide = false
	holder.CanQuery = false
	lamps = {}
	for _, x in ipairs({ -9, 9 }) do
		local attachment = Instance.new("Attachment")
		attachment.Position = Vector3.new(x, 0, 0)
		attachment.Parent = holder
		local lamp = Instance.new("PointLight")
		lamp.Range = 70
		lamp.Shadows = false
		lamp.Color = Color3.fromRGB(255, 246, 232)
		lamp.Parent = attachment
		table.insert(lamps, lamp)
	end
	local stuff = Instance.new("Folder")
	stuff.Name = "Props"
	stuff.Parent = folder
	props = stuff
	set = Stage.new()
	paint()
end

-- A fresh dummy on the floor (an effect may have dissolved or dressed the last one).
local function newBody(): Model
	ensureCell()
	set:clear()
	if props then
		props:ClearAllChildren()
	end
	local made = set:cast(Stage.figure(), CFrame.new(ORIGIN), nil)
	if not made then
		error("the booth could not stand its dummy")
	end
	return made
end

-- The camera ----------------------------------------------------------------------------------------------------------

local function cameraPose(): (CFrame, number)
	local turn = CFrame.Angles(0, math.rad(state.yaw), 0)
	local look = ORIGIN + Vector3.new(0, 3.2, 0)
	if state.camera == "close" then
		return CFrame.lookAt(ORIGIN + turn:VectorToWorldSpace(Vector3.new(0, 3.9, 8.5)), look), 52
	end
	return CFrame.lookAt(ORIGIN + turn:VectorToWorldSpace(Vector3.new(0, 5.4, 18)), look), 70
end

local function placeCamera()
	if token then
		local at, fov = cameraPose()
		CameraDirector.cut(token, at, fov)
	end
end

local function takeCamera()
	if not (token and CameraDirector.busy()) then
		token = CameraDirector.take(3000)
	end
	placeCamera()
end

local function releaseCamera()
	if token then
		CameraDirector.release(token)
		token = nil
	end
end

-- Switches ------------------------------------------------------------------------------------------------------------

local function adopt(opts: Options?)
	if not opts then
		return
	end
	if opts.backdrop == "dark" or opts.backdrop == "lit" then
		state.backdrop = opts.backdrop
	end
	if opts.camera == "follow" or opts.camera == "close" then
		state.camera = opts.camera
	end
	if opts.hold ~= nil then
		state.hold = opts.hold
	end
	if opts.preview ~= nil then
		state.preview = opts.preview
	end
	if opts.yaw ~= nil then
		state.yaw = opts.yaw
	end
end

-- Sets the switches (backdrop, camera, hold, preview, yaw); what is on the screen follows at once.
function FxBooth.set(opts: Options)
	adopt(opts)
	if cell then
		paint()
		applyLook()
		if token then
			placeCamera()
		end
	end
end

function FxBooth.state()
	return table.clone(state)
end

function FxBooth.isOpen(): boolean
	return cell ~= nil and cell.Parent ~= nil
end

-- The catalogue as plain data (no play functions).
function FxBooth.list(): { { [string]: any } }
	local list = {}
	for _, entry in ipairs(Catalog.get()) do
		table.insert(list, {
			id = entry.id,
			family = entry.family,
			source = entry.source,
			tier = entry.tier,
			hit = entry.hit,
			length = entry.length,
			label = entry.label,
			budget = entry.budget,
			whole = entry.whole == true,
			loop = entry.loop == true,
			estimated = entry.estimated == true,
		})
	end
	return list
end

function FxBooth.find(id: string): Catalog.Entry?
	return Catalog.byId(id)
end

local function finish(run: Run)
	if not run.finished then
		run.finished = true
		if run.onEnd then
			task.spawn(run.onEnd)
		end
	end
end

-- Stopping --------------------------------------------------------------------------------------------------------------

-- Stops what plays and clears it away: the effect's own stop, the clock let go, everything it left in the camera, a fresh
-- dummy. The late pieces of a stopped effect are swept for a moment after (play() waits for that).
function FxBooth.stop()
	runId += 1
	local running = current
	current = nil
	if running then
		local ok, err = pcall(running.stop)
		if not ok then
			warn("[FxBooth] stopping " .. running.entry.id .. ": " .. tostring(err))
		end
		finish(running)
		settleUntil = os.clock() + SETTLE
	end
	Clock.hold(false)
	purge()
	if cell then
		local ok, err = pcall(newBody)
		if not ok then
			warn("[FxBooth] " .. tostring(err))
		end
	end
	sweep()
end

local function settle()
	while os.clock() < settleUntil do
		task.wait()
	end
	purge()
end

-- Playing -------------------------------------------------------------------------------------------------------------

-- Holds the kit's clock `seconds` after the current effect began (kit time). False when nothing plays.
function FxBooth.holdAt(seconds: number): boolean
	local run = current
	if not run or run.whole then
		return false
	end
	local target = run.startedAt + math.max(0, seconds)
	while Clock.now() < target do
		RunService.Heartbeat:Wait()
		if current ~= run then
			return false
		end
	end
	Clock.hold(true)
	return true
end

-- Lets the clock run `seconds` more, then holds it again.
function FxBooth.step(seconds: number)
	Clock.hold(false)
	local target = Clock.now() + math.max(0, seconds)
	while Clock.now() < target do
		RunService.Heartbeat:Wait()
	end
	Clock.hold(true)
end

-- Lets the clock run on.
function FxBooth.release()
	Clock.hold(false)
end

-- Plays the catalogue entry `id` on a fresh dummy. Yields while a stopped effect settles. Returns whether it started
-- (and why not).
function FxBooth.play(id: string, opts: Options?): (boolean, string?)
	local entry = Catalog.byId(id)
	if not entry then
		return false, "no effect called " .. id
	end
	adopt(opts)
	FxBooth.stop()
	settle()
	runId += 1
	local mine = runId
	local ok, made = pcall(newBody)
	if not ok then
		warn("[FxBooth] " .. tostring(made))
		return false, tostring(made)
	end
	local dummy = made :: Model
	local root = dummy:FindFirstChild("HumanoidRootPart") :: BasePart
	local propsFolder: Instance = props or workspace
	local run: Run = {
		entry = entry,
		stop = function() end,
		startedAt = Clock.now(),
		whole = entry.whole == true,
		onEnd = if opts then opts.onEnd else nil,
		finished = false,
	}
	local stage: Catalog.Stage = {
		body = dummy,
		root = root,
		floor = ORIGIN,
		at = CFrame.new(ORIGIN),
		props = propsFolder,
		preview = state.preview,
		done = function()
			finish(run)
			if current == run then
				current = nil
			end
		end,
	}
	if run.whole then
		-- (a whole scene lights and films itself: it takes the camera, and the booth's look and camera go)
		releaseCamera()
		LightingController.scene(nil)
	else
		paint()
		applyLook()
		takeCamera()
		Clock.hold(false)
		run.startedAt = Clock.now()
	end
	current = run
	local started, stopOrError = pcall(entry.play, stage)
	if not started then
		warn("[FxBooth] " .. id .. " failed: " .. tostring(stopOrError))
		if current == run then
			FxBooth.stop()
		end
		return false, tostring(stopOrError)
	end
	run.stop = stopOrError :: () -> ()
	if state.hold and not run.whole then
		task.spawn(function()
			if runId == mine then
				FxBooth.holdAt(entry.hit)
			end
		end)
	end
	return true, nil
end

-- Plays `id` and holds the kit's clock `seconds` after its hit (a negative number is before it). Returns whether it held.
function FxBooth.at(id: string, seconds: number, opts: Options?): (boolean, string?)
	local merged: Options = if opts then table.clone(opts) else {}
	merged.hold = false
	local kept = state.hold
	local ok, why = FxBooth.play(id, merged)
	state.hold = kept -- (the switch is the panel's: at() holds by itself)
	if not ok then
		return false, why
	end
	local run = current
	if not run then
		return false, "the scene ended before it could be held"
	end
	if run.whole then
		return false, "a whole scene cannot be held"
	end
	return FxBooth.holdAt(run.entry.hit + seconds), nil
end

-- Leaves the booth: stops, gives the camera and the lighting back, takes the cell away.
function FxBooth.close()
	FxBooth.stop()
	releaseCamera()
	if LightingController.currentScene() == LOOKS.dark or LightingController.currentScene() == LOOKS.lit then
		LightingController.scene(nil)
	end
	if set then
		set:destroy()
		set = nil
	end
	if cell then
		cell:Destroy()
		cell = nil
	end
	props = nil
	floorPart = nil
	walls = {}
	lamps = {}
	purge()
end

-- The catalogue against the game's own lists: problems found (none when sound). The server's spec cannot load the
-- client's EmoteFx, so the check that every emote clip with an effect has an entry runs here, in a play test.
function FxBooth.verify(): { string }
	local problems = Catalog.check(Catalog.get(), nil)
	local ok, EmoteFx = pcall(function()
		return require(script.Parent.Parent.Controllers.EmoteFx) :: any
	end)
	if not ok then
		table.insert(problems, "EmoteFx could not be loaded: " .. tostring(EmoteFx))
		return problems
	end
	for _, problem in ipairs(Catalog.check(Catalog.get(), EmoteFx.clips())) do
		if not table.find(problems, problem) then
			table.insert(problems, problem)
		end
	end
	return problems
end

return FxBooth
