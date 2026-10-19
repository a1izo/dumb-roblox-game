--!strict
-- The world's prompts (stations, the bell, paper, the lobby's games, the shop window, the Trial's and the
-- Academy's) take the player's own keys: a prompt made with a "Binding" attribute (an action id of
-- Shared/Bindings, "interact" or "pickUp") gets that action's first keyboard key and gamepad button, now and
-- whenever the player's set changes. PromptView shows whatever the prompt holds.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bindings = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Bindings"))

local ClientState = require(script.Parent.Parent.ClientState)

local PromptKeys = {}

local tracked: { [ProximityPrompt]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function saved(): any
	local profile = ClientState.profile
	return if profile then profile.keybinds else nil
end

local function fit(prompt: ProximityPrompt)
	local id = prompt:GetAttribute("Binding")
	if type(id) ~= "string" or not Bindings.get(id) then
		return
	end
	local set = saved()
	local key = Bindings.keyCodes(id, "keyboard", set)[1]
	local pad = Bindings.keyCodes(id, "gamepad", set)[1]
	if key then
		prompt.KeyboardKeyCode = key
	end
	if pad then
		prompt.GamepadKeyCode = pad
	end
end

local function adopt(item: Instance)
	if item:IsA("ProximityPrompt") and not tracked[item] then
		tracked[item] = true
		fit(item)
		item:GetAttributeChangedSignal("Binding"):Connect(function()
			fit(item)
		end)
	end
end

-- Fits every prompt to the current set (the profile's set changed).
function PromptKeys.refresh()
	for prompt in pairs(tracked) do
		if prompt.Parent then
			fit(prompt)
		end
	end
end

function PromptKeys.init()
	for _, item in ipairs(workspace:GetDescendants()) do
		adopt(item)
	end
	workspace.DescendantAdded:Connect(adopt)
	local last = ""
	ClientState.ProfileChanged:Connect(function()
		local set = saved()
		local now = Bindings.text("interact", "keyboard", set)
			.. Bindings.text("interact", "gamepad", set)
			.. Bindings.text("pickUp", "keyboard", set)
			.. Bindings.text("pickUp", "gamepad", set)
		if now ~= last then
			last = now
			PromptKeys.refresh()
		end
	end)
end

return PromptKeys
