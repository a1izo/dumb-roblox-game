-- A small TestEZ-style runner (describe / it / expect) for the pure game-logic modules.
-- It runs automatically in Studio when Config.RUN_TESTS_IN_STUDIO is on and prints a
-- summary to the Output window. Spec modules are named "<Something>.spec".

local TestRunner = {}

local function describeValue(value: any): string
	if type(value) == "string" then
		return string.format("%q", value)
	end
	return tostring(value)
end

local function expect(value: any)
	local api = {}
	api.to = {
		equal = function(expected: any)
			if value ~= expected then
				error(string.format("expected %s, got %s", describeValue(expected), describeValue(value)), 2)
			end
		end,
		be = {
			ok = function()
				if not value then
					error("expected a truthy value, got " .. describeValue(value), 2)
				end
			end,
		},
	}
	api.never = {
		to = {
			equal = function(expected: any)
				if value == expected then
					error("expected a value other than " .. describeValue(expected), 2)
				end
			end,
		},
	}
	return api
end

function TestRunner.run(folder: Instance): boolean
	local passed, failed = 0, 0
	local failures = {}
	local path = {}

	local function describe(name: string, body: () -> ())
		table.insert(path, name)
		body()
		table.remove(path)
	end

	local function it(name: string, body: () -> ())
		local ok, err = pcall(body)
		if ok then
			passed += 1
		else
			failed += 1
			table.insert(failures, table.concat(path, " > ") .. " > " .. name .. ": " .. tostring(err))
		end
	end

	local api = { describe = describe, it = it, expect = expect }
	for _, module in ipairs(folder:GetChildren()) do
		if module:IsA("ModuleScript") and string.match(module.Name, "%.spec$") then
			local ok, spec = pcall(require, module)
			if ok and type(spec) == "function" then
				local ran, err = pcall(spec, api)
				if not ran then
					failed += 1
					table.insert(failures, module.Name .. " crashed: " .. tostring(err))
				end
			else
				failed += 1
				table.insert(failures, module.Name .. " could not be loaded: " .. tostring(spec))
			end
		end
	end

	print(string.format("[L game tests] %d passed, %d failed", passed, failed))
	for _, failure in ipairs(failures) do
		warn("[L game tests] " .. failure)
	end
	return failed == 0
end

return TestRunner
