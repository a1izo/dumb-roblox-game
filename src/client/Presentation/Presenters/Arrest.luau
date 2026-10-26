-- Ace makes an arrest: a huge Aktura "A" slams onto the screen, two faceless operatives in black
-- close in on the suspect, the cuffs click under flashing light, and a stamp says how it went. The
-- operatives are shadows made on this screen, never anyone's avatar (Ace stays hidden). Ace's verdict
-- style (gavel, cuffs, checkmate, sugar cubes) plays beside the arrest: on Ace's screen alone, or on
-- everyone's when the one arrested is Diavolo (the server decides who gets it).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Terms = require(Shared:WaitForChild("Terms"))

local ClientState = require(script.Parent.Parent.Parent.ClientState)
local Kit = require(script.Parent.Parent.Parent.UI.Kit)
local Motion = require(script.Parent.Parent.Parent.UI.Core.Motion)
local Screens = require(script.Parent.Parent.Parent.UI.Screens)
local Sfx = require(script.Parent.Parent.Parent.Audio.Sfx)
local CameraDirector = require(script.Parent.Parent.CameraDirector)
local Cinema = require(script.Parent.Parent.Cinema)
local DeathFx = require(script.Parent.Parent.DeathFx)
local ShotSolver = require(script.Parent.Parent.ShotSolver)
local StageLight = require(script.Parent.Parent.StageLight)
local Stage = require(script.Parent.Parent.Stage)
local Styles = require(script.Parent.Parent.Styles)

local C = Kit.color

local SHOT = 2.6

local function slamZero()
	local zero = Kit.text({
		face = "Title",
		text = Terms.NAMES.zeroGlyph,
		size = 420,
		color = C.bone,
		align = "center",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = 4,
		Parent = Screens.cinematic,
	})
	local scale = Instance.new("UIScale")
	scale.Scale = if Motion.isReduced() then 1 else 2.4
	scale.Parent = zero.frame
	Motion.tween(scale, { Scale = 1 }, 0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(0.55, function()
		zero:setTransparency(0)
		for step = 1, 8 do
			zero:setTransparency(step / 8)
			task.wait(0.04)
		end
		zero:destroy()
	end)
end

-- A faceless operative: a copy of the suspect's outline, all in black.
local function agent(stage: any, suspect: Model, mark: CFrame): Model?
	local actor = stage:cast(suspect, mark, "point", nil)
	if not actor then
		return nil
	end
	for _, item in ipairs(actor:GetDescendants()) do
		if item:IsA("BasePart") then
			item.Color = Color3.fromRGB(10, 10, 12)
			item.Material = Enum.Material.SmoothPlastic
			if item:IsA("MeshPart") then
				pcall(function()
					(item :: MeshPart).TextureID = ""
				end)
			end
		elseif item:IsA("Decal") or item:IsA("SurfaceAppearance") or item:IsA("Clothing") or item:IsA("Accessory") then
			item:Destroy()
		end
	end
	return actor
end

return function(cue)
	-- Players in the case and spectators watching it (the cues carry only public things).
	if not (ClientState.isParticipant() or ClientState.isWatching()) then
		return
	end
	local data = cue.data
	Cinema.waitUntil(cue.at)
	slamZero()
	task.wait(0.3)
	Sfx.play("handcuffs")
	for index = 0, 3 do
		task.delay(index * 0.35, Cinema.flash, if index % 2 == 0 then C.white else C.steel, 0.45, 0.3)
	end
	local suspect = Cinema.character(tonumber(data.userId))
	if not suspect then
		return
	end
	local hand = suspect:FindFirstChild("Right Arm")
	if hand and hand:IsA("BasePart") then
		DeathFx.sparks(hand.Position)
	end
	local stage = Stage.new()
	local pivot = suspect:GetPivot()
	local floor = ShotSolver.floor(pivot.Position)
	local base = CFrame.new(floor) * pivot.Rotation
	for _, side in ipairs({ -1, 1 }) do
		local spot = base * CFrame.new(side * 2.6, 0, -1.4)
		agent(stage, suspect, CFrame.lookAt(spot.Position, Vector3.new(floor.X, spot.Position.Y, floor.Z)))
	end
	local token = CameraDirector.take(SHOT + 0.5)
	Cinema.letterbox(true)
	local removeOutline = Cinema.outline(suspect, if data.result == "innocent" then C.bone else C.red)
	CameraDirector.cut(token, ShotSolver.frame(suspect, { distance = 9, height = 2, angle = 25 }), 55)
	CameraDirector.move(token, ShotSolver.frame(suspect, { distance = 5, height = 0.8, angle = 12 }), SHOT - 0.1, 44)
	local stamp = Kit.stamp({
		text = if data.result == "innocent" then "Innocent" else "Arrested",
		color = if data.result == "innocent" then C.steel else C.red,
		width = 320,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.72),
		ZIndex = 5,
		Parent = Screens.cinematic,
	})
	stamp.Visible = false
	-- (the room's lamps sink as the operatives close in; red and blue strike the suspect from either side, turn
	-- about, as the cuffs click)
	local lights: { () -> () } = { StageLight.dip(floor, 40, 0.4, SHOT) }
	local eye = (base * CFrame.new(0, 2, -9)).Position
	task.delay(0.9, function()
		stamp.Visible = true
		Motion.pop(stamp)
		Sfx.play("gavel")
		local red, blue = Color3.fromRGB(255, 50, 60), Color3.fromRGB(70, 110, 255)
		for k = 0, 3 do
			task.delay(k * 0.42, function()
				local out = StageLight.rim(
					suspect,
					eye + base.RightVector * (if k % 2 == 0 then 6 else -6),
					if k % 2 == 0 then red else blue,
					3
				)
				table.insert(lights, out)
				task.delay(0.36, out)
			end)
		end
	end)
	-- Ace's verdict style, beside the suspect.
	local removeVerdict =
		Styles.verdict(if type(data.verdict) == "string" then data.verdict else nil, Screens.cinematic)
	task.wait(SHOT)
	for _, put in ipairs(lights) do
		put()
	end
	stamp:Destroy()
	removeVerdict()
	removeOutline()
	stage:destroy()
	Cinema.letterbox(false)
	CameraDirector.release(token)
end
