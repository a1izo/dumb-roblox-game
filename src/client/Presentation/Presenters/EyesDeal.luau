-- The Specter's Eyes deal, seen only by the Cultist who took it: the screen floods red, the
-- Specter rises out of the floor in front of you and looms, a whisper, and the terms of the
-- deal. Nobody else gets this cue, and the Specter exists only on this screen.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Models = require(Shared:WaitForChild("Models"))
local Terms = require(Shared:WaitForChild("Terms"))

local Kit = require(script.Parent.Parent.Parent.UI.Kit)
local Mixer = require(script.Parent.Parent.Parent.Audio.Mixer)
local Sfx = require(script.Parent.Parent.Parent.Audio.Sfx)
local Cinema = require(script.Parent.Parent.Cinema)
local ShotSolver = require(script.Parent.Parent.ShotSolver)

local C = Kit.color

-- The Specter rises in front of the camera, sways, then sinks away. Returns a remover.
local function looming(seconds: number): () -> ()
	local camera = workspace.CurrentCamera
	if not camera then
		return function() end
	end
	local specter = Models.specter()
	local look = camera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
	-- On the floor in front of you (found with a ray, not guessed).
	local ground = ShotSolver.floor(camera.CFrame.Position + flat * 11)
	local facing = CFrame.lookAt(ground, ground - flat)
	specter:PivotTo(facing * CFrame.new(0, -9, 0))
	specter.Parent = camera
	local started = os.clock()
	local connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		local rise = math.min(1, t / 1.1)
		local eased = 1 - (1 - rise) ^ 3
		local sink = math.clamp((t - seconds + 0.8) / 0.8, 0, 1)
		local y = -9 + 9 * eased - 9 * sink * sink
		specter:PivotTo(
			facing * CFrame.new(math.sin(t * 1.3) * 0.3, y, 0) * CFrame.Angles(0, math.sin(t * 0.9) * 0.08, 0)
		)
	end)
	local function remove()
		connection:Disconnect()
		specter:Destroy()
	end
	task.delay(seconds, remove)
	return remove
end

return function(cue)
	local data = cue.data
	Cinema.waitUntil(cue.at)
	Mixer.duck("eyes", true)
	Sfx.play("eyesOpen")
	Cinema.flash(C.red, 0.75, 0.9)
	looming(3.8)
	local untint = Cinema.tint({ TintColor = Color3.fromRGB(255, 150, 150), Saturation = -0.4, Contrast = 0.2 }, 0.3)
	local removeVignette = Cinema.vignette(C.red, 0.4)
	local hide = Cinema.card({
		kicker = "The deal is struck",
		title = Terms.f("{EYES}"),
		subtitle = Terms.f(
			"Half your life for {reads} names. Your time runs out at the end of round {round}.",
			{ reads = tonumber(data.reads) or 0, round = tonumber(data.deathRound) or 0 }
		),
		color = C.void,
		textColor = C.red,
		y = 0.62,
	})
	task.wait(3.5)
	hide()
	untint()
	removeVignette()
	Mixer.duck("eyes", false)
end
