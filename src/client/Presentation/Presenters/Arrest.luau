-- A warrant is served: a huge "0" slams onto the screen, police lights flash red and blue,
-- the cuffs click and the camera holds on the suspect. The announcement says who they were.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Terms = require(Shared:WaitForChild("Terms"))

local ClientState = require(script.Parent.Parent.Parent.ClientState)
local Motion = require(script.Parent.Parent.Parent.UI.Core.Motion)
local Screens = require(script.Parent.Parent.Parent.UI.Screens)
local Theme = require(script.Parent.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.Parent.UI.Widgets)
local Sfx = require(script.Parent.Parent.Parent.Audio.Sfx)
local CameraDirector = require(script.Parent.Parent.CameraDirector)
local Cinema = require(script.Parent.Parent.Cinema)
local InkFx = require(script.Parent.Parent.InkFx)

local C = Theme.colors

local SHOT = 2.1

local function glyph()
	local label = Widgets.label({
		Text = Terms.NAMES.zeroGlyph,
		Font = Theme.fonts.gothic,
		TextScaled = true,
		TextColor3 = C.paper,
		TextStrokeColor3 = C.ink,
		TextStrokeTransparency = 0,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.5, 0.8),
		ZIndex = 4,
		Parent = Screens.cinematic,
	})
	local scale = Instance.new("UIScale")
	scale.Scale = if Motion.isReduced() then 1 else 2.2
	scale.Parent = label
	Motion.tween(scale, { Scale = 1 }, 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(0.5, function()
		Motion.tween(label, { TextTransparency = 1, TextStrokeTransparency = 1 }, 0.4)
		task.wait(0.45)
		label:Destroy()
	end)
end

return function(cue)
	if not ClientState.isParticipant() then
		return
	end
	local data = cue.data
	Cinema.waitUntil(cue.at)
	glyph()
	task.wait(0.25)
	Sfx.play("handcuffs")
	local suspect = Cinema.character(tonumber(data.userId))
	local hand = if suspect then suspect:FindFirstChild("RightHand") else nil
	if hand and hand:IsA("BasePart") then
		InkFx.sparks(hand.Position)
	end
	for index = 0, 3 do
		task.delay(index * 0.35, Cinema.flash, if index % 2 == 0 then C.accent else C.team, 0.45, 0.3)
	end
	local character = Cinema.character(tonumber(data.userId))
	if not character then
		return
	end
	local token = CameraDirector.take(SHOT + 0.5)
	Cinema.letterbox(true)
	local removeOutline = Cinema.outline(character, if data.result == "innocent" then C.paper else C.accent)
	CameraDirector.cut(token, Cinema.faceShot(character, 7, 1.5, 3), 55)
	CameraDirector.move(token, Cinema.faceShot(character, 4.5, 0.8, 1), SHOT - 0.1, 45)
	task.wait(SHOT)
	removeOutline()
	Cinema.letterbox(false)
	CameraDirector.release(token)
end
