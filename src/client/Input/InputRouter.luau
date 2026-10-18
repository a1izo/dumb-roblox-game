-- Binds every action in Actions to its keyboard keys and gamepad button through ContextActionService. An action
-- only runs (and only swallows the input) when it is available; otherwise the input passes on to Roblox as usual.
-- The keys are the player's own where they set some (their profile's `keybinds`, Shared/Bindings), else the
-- defaults; they are bound again whenever the profile's set changes, and the action's keys (shown in its hint)
-- follow.

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Bindings = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Bindings"))

local ClientState = require(script.Parent.Parent.ClientState)
local Router = require(script.Parent.Parent.UI.Core.Router)
local Actions = require(script.Parent.Actions)

local InputRouter = {}

local function keyCodes(names: { string }): { Enum.KeyCode }
	local out = {}
	for _, name in ipairs(names) do
		local ok, key = pcall(function()
			return (Enum.KeyCode :: any)[name]
		end)
		if ok and key then
			table.insert(out, key)
		end
	end
	return out
end

local applied: any = false

-- Binds every action to the keys it has now (the saved set's, or the defaults).
function InputRouter.apply(saved: any)
	for _, action in ipairs(Actions.list) do
		if Bindings.get(action.id) then
			action.keys = keyCodes(Bindings.keys(action.id, "keyboard", saved))
			action.pad = keyCodes(Bindings.keys(action.id, "gamepad", saved))[1]
		end
		local name = "DeathsGambit_" .. action.id
		ContextActionService:UnbindAction(name)
		local inputs = table.clone(action.keys)
		if action.pad then
			table.insert(inputs, action.pad)
		end
		if #inputs > 0 then
			ContextActionService:BindAction(name, function(_, state: Enum.UserInputState)
				if state ~= Enum.UserInputState.Begin then
					return Enum.ContextActionResult.Pass
				end
				if UserInputService:GetFocusedTextBox() or not action.when(Router.view()) then
					return Enum.ContextActionResult.Pass
				end
				action.run()
				return Enum.ContextActionResult.Sink
			end, false, table.unpack(inputs))
		end
	end
	applied = saved
end

function InputRouter.init()
	local function fromProfile(): any
		local profile = ClientState.profile
		return profile and profile.keybinds or nil
	end
	-- (bound again only when the set's contents change: the profile comes often, a new table each time)
	local function signature(saved: any): string
		local parts = {}
		for _, platform in ipairs(Bindings.PLATFORMS) do
			for _, action in ipairs(Bindings.ACTIONS) do
				table.insert(parts, table.concat(Bindings.keys(action.id, platform, saved), "+"))
			end
		end
		return table.concat(parts, ",")
	end
	InputRouter.apply(fromProfile())
	local last = signature(applied)
	ClientState.ProfileChanged:Connect(function()
		local saved = fromProfile()
		local now = signature(saved)
		if now ~= last then
			last = now
			InputRouter.apply(saved)
		end
	end)
end

return InputRouter
