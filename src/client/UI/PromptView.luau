-- Our look for proximity prompts ("Work case file", "Pick up", "Practice"...): a keycap with
-- the key for the current input, the action in handwriting, the object in small capitals, and
-- an ink line that fills while a hold prompt is held. On touch screens the keycap is the button.
-- Prompts opt in with Style = Custom; several prompts on one object stack upwards.

local ProximityPromptService = game:GetService("ProximityPromptService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Kit = require(script.Parent.Kit)
local Motion = require(script.Parent.Core.Motion)

local C = Kit.color
local T = Kit.Tokens

local PromptView = {}

type Shown = { gui: BillboardGui, adornee: Instance, fill: Frame }

local shown: { [ProximityPrompt]: Shown } = {}
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local GAMEPAD_NAMES = {
	[Enum.KeyCode.ButtonX] = "X",
	[Enum.KeyCode.ButtonY] = "Y",
	[Enum.KeyCode.ButtonA] = "A",
	[Enum.KeyCode.ButtonB] = "B",
	[Enum.KeyCode.ButtonL1] = "LB",
	[Enum.KeyCode.ButtonR1] = "RB",
	[Enum.KeyCode.DPadUp] = "D-Up",
	[Enum.KeyCode.DPadDown] = "D-Down",
	[Enum.KeyCode.DPadLeft] = "D-Left",
	[Enum.KeyCode.DPadRight] = "D-Right",
}

local function keyText(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType): string
	if inputType == Enum.ProximityPromptInputType.Gamepad then
		return GAMEPAD_NAMES[prompt.GamepadKeyCode] or prompt.GamepadKeyCode.Name
	elseif inputType == Enum.ProximityPromptInputType.Touch then
		return ""
	end
	local text = UserInputService:GetStringForKeyCode(prompt.KeyboardKeyCode)
	return if text ~= "" then string.upper(text) else prompt.KeyboardKeyCode.Name
end

-- Stacks the prompts on one object from the bottom up.
local function restack(adornee: Instance)
	local list = {}
	for prompt, entry in pairs(shown) do
		if entry.adornee == adornee then
			table.insert(list, prompt)
		end
	end
	table.sort(list, function(a, b)
		return a.Name < b.Name
	end)
	for index, prompt in ipairs(list) do
		shown[prompt].gui.SizeOffset = Vector2.new(0, (index - 1) * 1.08)
	end
end

local function hide(prompt: ProximityPrompt)
	local entry = shown[prompt]
	if not entry then
		return
	end
	shown[prompt] = nil
	entry.gui:Destroy()
	restack(entry.adornee)
end

local function show(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType)
	hide(prompt)
	local adornee = prompt.Parent
	if not adornee or not (adornee:IsA("BasePart") or adornee:IsA("Attachment") or adornee:IsA("Model")) then
		return
	end
	local touch = inputType == Enum.ProximityPromptInputType.Touch
	local gui = Kit.Base.make("BillboardGui", {
		Name = "Prompt_" .. prompt.Name,
		Adornee = adornee,
		AlwaysOnTop = true,
		LightInfluence = 0,
		Size = UDim2.fromOffset(300, 64),
		StudsOffset = Vector3.new(0, 2.2, 0),
		ResetOnSpawn = false,
		Active = touch,
		Parent = playerGui,
	})
	-- The key (or, on touch screens, the button to press).
	local cap = Kit.Base.hit({
		Name = "Key",
		Active = touch,
		Selectable = false,
		BackgroundColor3 = C.void,
		BackgroundTransparency = 0.15,
		Size = UDim2.fromOffset(52, 52),
		Position = UDim2.fromOffset(0, 6),
		Parent = gui,
	})
	Kit.Base.round(cap)
	Kit.Base.stroke(cap, C.bone, 2, 0.3)
	local key = keyText(prompt, inputType)
	if key ~= "" then
		Kit.label({
			Text = key,
			font = "mono",
			size = if #key > 2 then "micro" else "lead",
			TextXAlignment = Enum.TextXAlignment.Center,
			TextWrapped = false,
			AutomaticSize = Enum.AutomaticSize.None,
			Size = UDim2.fromScale(1, 1),
			Parent = cap,
		})
	else
		Kit.icon({
			name = "play",
			size = 22,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Parent = cap,
		})
	end
	local column = Kit.frame({
		Name = "Text",
		Position = UDim2.fromOffset(62, 0),
		Size = UDim2.new(1, -62, 1, 0),
		Parent = gui,
	})
	-- A soft dark wash behind the words so they read against any wall.
	local wash = Kit.Base.make("Frame", {
		Name = "Wash",
		BackgroundColor3 = C.void,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(-6, 4),
		Size = UDim2.new(1, 0, 1, -8),
		ZIndex = 0,
		Parent = column,
	})
	Kit.Base.make("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.75, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = wash,
	})
	Kit.text({
		face = "Head",
		text = prompt.ActionText,
		size = 22,
		color = C.bone,
		Position = UDim2.fromOffset(4, 2),
		ZIndex = 2,
		Parent = column,
	})
	Kit.label({
		Text = string.upper(prompt.ObjectText),
		font = "label",
		size = "micro",
		color = C.dim,
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.None,
		Position = UDim2.fromOffset(6, 38),
		Size = UDim2.new(1, -6, 0, 14),
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 2,
		Parent = column,
	})
	-- Hold progress: ink running along the bottom.
	local fill = Kit.Base.make("Frame", {
		Name = "Hold",
		BackgroundColor3 = C.white,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 4, 1, -6),
		Size = UDim2.fromOffset(0, 3),
		ZIndex = 2,
		Parent = column,
	})
	if touch then
		cap.InputBegan:Connect(function(input: InputObject)
			if
				input.UserInputType == Enum.UserInputType.Touch
				or input.UserInputType == Enum.UserInputType.MouseButton1
			then
				prompt:InputHoldBegin()
			end
		end)
		cap.InputEnded:Connect(function(input: InputObject)
			if
				input.UserInputType == Enum.UserInputType.Touch
				or input.UserInputType == Enum.UserInputType.MouseButton1
			then
				prompt:InputHoldEnd()
			end
		end)
	end
	shown[prompt] = { gui = gui, adornee = adornee, fill = fill }
	restack(adornee)
	Motion.pop(cap)
end

local function holdBegan(prompt: ProximityPrompt)
	local entry = shown[prompt]
	if entry and prompt.HoldDuration > 0 then
		entry.fill.Size = UDim2.fromOffset(0, 3)
		Motion.tween(entry.fill, { Size = UDim2.new(1, -8, 0, 3) }, prompt.HoldDuration, Enum.EasingStyle.Linear)
	end
end

local function holdEnded(prompt: ProximityPrompt)
	local entry = shown[prompt]
	if entry then
		Motion.tween(entry.fill, { Size = UDim2.fromOffset(0, 3) }, T.motion.quick)
	end
end

function PromptView.init()
	ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
		if prompt.Style == Enum.ProximityPromptStyle.Custom then
			show(prompt, inputType)
		end
	end)
	ProximityPromptService.PromptHidden:Connect(hide)
	ProximityPromptService.PromptButtonHoldBegan:Connect(holdBegan)
	ProximityPromptService.PromptButtonHoldEnded:Connect(holdEnded)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local entry = shown[prompt]
		if entry then
			holdEnded(prompt)
			local cap = entry.gui:FindFirstChild("Key")
			if cap and cap:IsA("GuiObject") then
				Motion.pulse(cap)
			end
		end
	end)
end

return PromptView
