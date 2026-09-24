-- Binds every action in Actions to its keyboard key and gamepad button through
-- ContextActionService. An action only runs (and only swallows the input) when it is
-- available; otherwise the input passes on to Roblox as usual.

local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

local Router = require(script.Parent.Parent.UI.Core.Router)
local Actions = require(script.Parent.Actions)

local InputRouter = {}

function InputRouter.init()
	for _, action in ipairs(Actions.list) do
		local inputs = table.clone(action.keys)
		if action.pad then
			table.insert(inputs, action.pad)
		end
		if #inputs > 0 then
			ContextActionService:BindAction("Inkbound_" .. action.id, function(_, state: Enum.UserInputState)
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
end

return InputRouter
