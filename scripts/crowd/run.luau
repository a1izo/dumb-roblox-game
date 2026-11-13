-- Runs the specs in the bundle (scripts/crowd/bundle.py) and returns the summary and every failure, as text.
-- From execute_luau in the Edit datamodel:
--   local root = game:GetObjects("rbxasset://dg_specs.rbxm")[1]
--   local text = require(root.Tools.run)(root)
--   root:Destroy()
--   return text

local LogService = game:GetService("LogService")

return function(root: Instance): string
	local lines = {}
	local connection = LogService.MessageOut:Connect(function(message)
		if string.find(message, "DeathsGambit tests", 1, true) then
			table.insert(lines, string.sub(message, 1, 900))
		end
	end)
	local TestRunner = require((root :: any).Server.Tests.TestRunner)
	local ok = TestRunner.run((root :: any).Server.Tests)
	task.wait(0.3)
	connection:Disconnect()
	return tostring(ok) .. "\n" .. table.concat(lines, "\n")
end
