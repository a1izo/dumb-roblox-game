-- The private role reveal at the start of the briefing: your own avatar, alone on a dark set far
-- above the world, acts out your role while the camera closes in and your role is written
-- across the screen. Only you see it: the set and the copy of your avatar exist on this
-- screen alone. Every role's reveal lasts exactly the same time, so its length says nothing.
--   the Hand   opens the Grimoire and laughs while the Specter rises behind
--   Cultist    kneels in prayer by a candle
--   Zero       crouched on a chair in front of a white "0"
--   the Butler under an umbrella, tipping the hat
--   Agent      flips up the Agency badge

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Activities = require(Shared:WaitForChild("Presentation"):WaitForChild("Activities"))
local Create = require(Shared:WaitForChild("Create"))
local Models = require(Shared:WaitForChild("Models"))
local Roles = require(Shared:WaitForChild("Roles"))
local Terms = require(Shared:WaitForChild("Terms"))

local Kit = require(script.Parent.Parent.UI.Kit)
local Sfx = require(script.Parent.Parent.Audio.Sfx)
local CameraDirector = require(script.Parent.CameraDirector)
local Cinema = require(script.Parent.Cinema)
local Stage = require(script.Parent.Stage)

local C = Kit.color

local RoleReveal = {}

RoleReveal.DURATION = 4

local VOID = Vector3.new(0, 1500, 0)

local function block(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	return Create("Part", {
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Size = size,
		CFrame = cf,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		Parent = parent,
	})
end

-- Builds the set: a black floor, a hard light from above and a coloured rim light.
local function buildSet(stage: any, rim: Color3)
	local set = Instance.new("Model")
	set.Name = "Void"
	block(set, Vector3.new(80, 1, 80), CFrame.new(VOID - Vector3.new(0, 0.5, 0)), Color3.fromRGB(10, 9, 12))
	local top = block(set, Vector3.new(0.2, 0.2, 0.2), CFrame.lookAt(VOID + Vector3.new(0, 16, 2), VOID), C.void)
	top.Transparency = 1
	Create(
		"SpotLight",
		{ Angle = 45, Range = 30, Brightness = 5, Face = Enum.NormalId.Front, Shadows = true, Parent = top }
	)
	local back = block(
		set,
		Vector3.new(0.2, 0.2, 0.2),
		CFrame.lookAt(VOID + Vector3.new(0, 5, 8), VOID + Vector3.new(0, 3, 0)),
		C.void
	)
	back.Transparency = 1
	Create(
		"SpotLight",
		{ Angle = 70, Range = 20, Brightness = 3, Color = rim, Face = Enum.NormalId.Front, Parent = back }
	)
	stage:add(set)
	return set
end

-- A tall Gothic "0" on a white screen behind Zero.
local function zeroScreen(set: Instance)
	local screen = block(
		set,
		Vector3.new(10, 12, 0.3),
		CFrame.new(VOID + Vector3.new(0, 6, 7)) * CFrame.Angles(0, math.pi, 0),
		C.white
	)
	screen.Material = Enum.Material.Neon
	screen.Color = Color3.fromRGB(235, 235, 232)
	local gui = Create("SurfaceGui", {
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 40,
		LightInfluence = 0,
		Parent = screen,
	})
	Create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = Terms.NAMES.zeroGlyph,
		FontFace = Kit.Tokens.font.display,
		TextScaled = true,
		TextColor3 = C.ink,
		Parent = gui,
	})
end

-- The Specter rises slowly behind the Hand. Returns a stopper.
local function specterRises(set: Instance): () -> ()
	local specter = Models.specter()
	local base = CFrame.lookAt(VOID + Vector3.new(0, 0, 5), VOID)
	specter:PivotTo(base * CFrame.new(0, -12, 0))
	specter.Parent = set
	local began = os.clock()
	local connection = RunService.RenderStepped:Connect(function()
		local t = math.clamp((os.clock() - began) / 1.8, 0, 1)
		local eased = 1 - (1 - t) ^ 3
		specter:PivotTo(base * CFrame.new(math.sin(os.clock() * 1.2) * 0.2, -12 + 12 * eased, 0))
	end)
	return function()
		connection:Disconnect()
	end
end

-- Plays the reveal for `role`. Returns when it is over (RoleReveal.DURATION seconds).
function RoleReveal.play(role: string)
	local character = Players.LocalPlayer.Character
	local spec = Activities.REVEAL[role] or Activities.REVEAL.TaskForce
	local hostile = role == "Kira" or role == "Follower"
	local stage = Stage.new()
	local set = buildSet(stage, if hostile then C.red else C.steel)
	local mark = CFrame.lookAt(VOID, VOID + Vector3.new(0, 0, -1))
	local stops: { () -> () } = {}
	if spec.seat then
		stage:chair(mark)
	end
	if role == "L" then
		zeroScreen(set)
	end
	local actor = if character then stage:cast(character, mark, spec.clip, spec.props) else nil
	local token = CameraDirector.take(RoleReveal.DURATION + 0.5)
	Cinema.letterbox(true)
	local target = VOID + Vector3.new(0, 2.6, 0)
	local began = os.clock()
	local move = RunService.RenderStepped:Connect(function()
		local t = math.clamp((os.clock() - began) / RoleReveal.DURATION, 0, 1)
		local eased = 1 - (1 - t) ^ 2
		local angle = math.rad(-28 + eased * 22)
		local distance = 13 - eased * 6.5
		local eye = target + Vector3.new(math.sin(angle) * distance, 1.8 - eased * 0.9, -math.cos(angle) * distance)
		CameraDirector.cut(token, CFrame.lookAt(eye, target), 50 - eased * 10)
	end)
	table.insert(stops, function()
		move:Disconnect()
	end)
	if role == "Kira" then
		task.delay(1.4, function()
			table.insert(stops, specterRises(set))
			Sfx.play("thunder", { volume = 0.5 })
		end)
		if spec.after and actor then
			local after = spec.after
			task.delay(2.4, function()
				if actor.Parent then
					stage:act(actor, after, { fadeIn = 0.2 })
					Sfx.play("laugh")
				end
			end)
		end
	end
	task.wait(1.6)
	local info = Roles.get(role)
	local hideCard = Cinema.card({
		kicker = "You are",
		title = info.display,
		color = if hostile then C.blood else C.void,
		textColor = if hostile then C.bone else C.bone,
		typewriter = true,
		y = 0.78,
	})
	task.wait(RoleReveal.DURATION - 1.6)
	hideCard()
	for _, stop in ipairs(stops) do
		stop()
	end
	stage:destroy()
	Cinema.letterbox(false)
	CameraDirector.release(token)
end

return RoleReveal
