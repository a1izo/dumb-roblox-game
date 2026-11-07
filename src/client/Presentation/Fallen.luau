--!strict
-- A fallen body under its death style (Shared/Cosmetics kind "death": ash, strings, crows, stone, glass; the user's
-- ask of 2026-11-07, "animations for death purposes"). On every screen a copy of the body that dies stands in for it
-- (Stage.copyOf, the real one hidden on this screen): it plays the collapse as the body would, lies still a moment
-- (ManualTiming.STYLE_AFTER, while the death cutscene shows the witnesses) and then acts its style
-- (fallen<Style><Down|Up>, art/scripts/fallen.py) while Presentation/Styles.death plays the style's effect on it, timed
-- to the acting (Shared/Anim/DeathTiming). What the style leaves (a heap, a statue's rubble, nothing at all) stays
-- where the body fell: the server's frozen copy of the body (RagdollService, which carries the style in its LDeathStyle
-- attribute) is hidden on this screen, and the copy goes when that one does (the bodies are cleared).
--
--   Fallen.stand(userId, character, at, cause, style)     -- a death in a case (ActingController)
--   Fallen.act(copy, style, collapseClip)                 -- any posed body that has collapsed (the shop's scenes)
--   Fallen.bodyOf(userId)                                 -- what to film: the copy while it stands in

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Anim = Shared:WaitForChild("Anim")
local Causes = require(Anim:WaitForChild("Causes"))
local ClipPlayer = require(Anim:WaitForChild("ClipPlayer"))
local Joints = require(Anim:WaitForChild("Joints"))
local ManualTiming = require(Shared:WaitForChild("Presentation"):WaitForChild("ManualTiming"))

local PoseController = require(script.Parent.Parent.Anim.PoseController)
local DeathVfx = require(script.Parent.DeathVfx)
local Stage = require(script.Parent.Stage)
local Styles = require(script.Parent.Styles)

local Fallen = {}

local BLEND = 0.45 -- seconds the limbs take to ease from how the body lies into the style's first pose
local TRACK = "fallenStyle"
local FROZEN_WAIT = 20 -- seconds after the style the server's frozen copy is looked for

type Standing = {
	userId: number,
	alias: string?,
	copy: Model,
	stage: Stage.Stage,
	gone: boolean,
}

local standing: { [number]: Standing } = {}
local watch: RBXScriptConnection? = nil

-- Which way a body lies: "Down" with its chest to the floor, "Up" on its back.
function Fallen.family(body: Model): string
	local torso = body:FindFirstChild("Torso")
	if torso and torso:IsA("BasePart") then
		return if torso.CFrame.LookVector.Y < 0 then "Down" else "Up"
	end
	return "Down"
end

-- Whether a style has an acting of its own for a fallen body.
function Fallen.has(style: string?): boolean
	return Causes.fallenClip(style, "Down") ~= nil
end

-- The copy that stands in for this player's body while it dies on this screen, or their own body.
function Fallen.bodyOf(userId: number?): Model?
	local entry = if userId then standing[userId] else nil
	if entry and not entry.gone and entry.copy.Parent then
		return entry.copy
	end
	if not userId then
		return nil
	end
	local player = Players:GetPlayerByUserId(userId)
	return if player then player.Character else nil
end

-- Fallen.bodyOf, once the stand-in (made on the same beat elsewhere) is there: waits up to `timeout` seconds for it.
function Fallen.waitFor(userId: number, timeout: number): Model?
	local deadline = os.clock() + timeout
	while os.clock() < deadline do
		local entry = standing[userId]
		if entry and not entry.gone and entry.copy.Parent then
			return entry.copy
		end
		task.wait()
	end
	return Fallen.bodyOf(userId)
end

local function smooth(u: number): number
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end

-- The torso's place relative to the root part for a root joint value (a clip's rotation and offset).
local function torsoFrom(motor: Joints.Instance6D, rotation: CFrame, offset: Vector3?): CFrame
	local c0 = Joints.c0(motor)
	local c1 = Joints.c1(motor)
	local basis = c0 - c0.Position
	return c0 * ClipPlayer.transform(basis, rotation, offset) * c1:Inverse()
end

-- Takes a body that has collapsed (posed by PoseController, holding its collapse clip's last frame, its root part
-- anchored) over into its death style's acting: the style clip's first frame is laid over the body where it lies
-- (the root part moved so that frame's torso is where the body's torso is), the limbs eased from where they lie into
-- it, and the style's effect played on it, timed to the clip. Returns how long the acting runs (0: no style clip).
function Fallen.act(body: Model, style: string, collapse: string, options: { quiet: boolean? }?): number
	local family = Fallen.family(body)
	local clipId = Causes.fallenClip(style, family)
	local prepared = if clipId then ClipPlayer.get(clipId) else nil
	local fell = ClipPlayer.get(collapse)
	local root = body:FindFirstChild("HumanoidRootPart")
	local torso = body:FindFirstChild("Torso")
	local motors = Joints.find(body)
	local motor = motors.root
	if not clipId or not prepared or not root or not root:IsA("BasePart") or not torso or not torso:IsA("BasePart") then
		Styles.death(style, body)
		return 0
	end
	-- (where the limbs lie now: the collapse's last frame, as this body is holding it)
	local start: { [string]: CFrame } = {}
	if fell then
		start = ClipPlayer.sample(fell, fell.length)
	end
	local first, firstOffset = ClipPlayer.sample(prepared, 0)
	if motor and first.root then
		root.Anchored = true
		root.CFrame = torso.CFrame * torsoFrom(motor, first.root, firstOffset):Inverse()
	end
	local length = prepared.length
	PoseController.stop(body, collapse, 0, "replaced")
	PoseController.playProcedural(body, TRACK, function(elapsed: number)
		local rotations, offset = ClipPlayer.sample(prepared, elapsed)
		local w = smooth(elapsed / BLEND)
		if w < 1 then
			for joint, rot in pairs(rotations) do
				local was = start[joint]
				if joint ~= "root" and was then
					rotations[joint] = was:Lerp(rot, w)
				end
			end
		end
		return rotations, offset
	end, { fadeIn = 0 })
	if not (options and options.quiet) then
		Styles.death(style, body, { clip = clipId, moments = Causes.moments(clipId) })
		DeathVfx.style(style, body, Causes.moments(clipId))
	end
	return length
end

-- Hides a frozen copy of a body on this screen (the copy that stood in is what shows), and links the stand-in to it.
local function hideFrozen(model: Model)
	local alias = string.match(model.Name, "^Body_(.+)$")
	if not alias or model:GetAttribute("LDeathStyle") == nil then
		return
	end
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") or item:IsA("Decal") then
			(item :: any).LocalTransparencyModifier = 1
		end
	end
	for _, entry in pairs(standing) do
		if entry.alias == alias and not entry.gone then
			model.AncestryChanged:Connect(function()
				if not model:IsDescendantOf(workspace) then
					Fallen.clear(entry.userId)
				end
			end)
		end
	end
end

local function watchFrozen()
	if watch then
		return
	end
	watch = workspace.DescendantAdded:Connect(function(item)
		if item:IsA("Model") and string.sub(item.Name, 1, 5) == "Body_" then
			task.defer(hideFrozen, item)
		end
	end)
end

-- Takes the stand-in for this player away (and shows their real body again).
function Fallen.clear(userId: number)
	local entry = standing[userId]
	if not entry then
		return
	end
	standing[userId] = nil
	entry.gone = true
	pcall(function()
		entry.stage:destroy()
	end)
	if next(standing) == nil and watch then
		watch:Disconnect()
		watch = nil
	end
end

-- A death in a case with a death style: a copy stands in for `character` from `at` (the server time its collapse
-- starts), collapses with the cause's clip, lies still, then acts the style. Nothing for a style without an acting.
function Fallen.stand(userId: number, character: Model, at: number, cause: string, style: string, alias: string?)
	if not Fallen.has(style) then
		return
	end
	Fallen.clear(userId)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local copy = Stage.copyOf(character)
	if not copy then
		return
	end
	local stage = Stage.new()
	copy.Name = "Fallen_" .. character.Name
	copy:PivotTo(root.CFrame)
	stage:add(copy)
	stage:hide(character)
	local entry: Standing = { userId = userId, alias = alias, copy = copy, stage = stage, gone = false }
	standing[userId] = entry
	watchFrozen()
	local clip = Causes.clipFor(cause)
	local timing = Causes.timing(clip)
	local now = workspace:GetServerTimeNow()
	PoseController.bindWhenReady(copy, 2)
	PoseController.play(copy, clip, { startAt = os.clock() + (at - now), fadeIn = 0.15 })
	local styleAt = at + timing.length + ManualTiming.STYLE_AFTER
	task.delay(math.max(0, styleAt - workspace:GetServerTimeNow()), function()
		if entry.gone or not copy.Parent then
			return
		end
		Fallen.act(copy, style, clip)
	end)
	-- (if the server never freezes the body, the copy still goes in the end)
	local lasts = timing.length + ManualTiming.STYLE_AFTER + Causes.fallenLength(style) + FROZEN_WAIT
	task.delay(math.max(0, at - workspace:GetServerTimeNow()) + lasts, function()
		if entry.gone or standing[userId] ~= entry then
			return
		end
		-- (still no frozen body to follow: keep the copy only while the real body is in the world)
		local function check()
			if entry.gone then
				return
			end
			if not character:IsDescendantOf(workspace) then
				local frozen = workspace:FindFirstChild("Body_" .. (alias or ""), true)
				if not frozen then
					Fallen.clear(userId)
					return
				end
			end
			task.delay(5, check)
		end
		check()
	end)
end

return Fallen
