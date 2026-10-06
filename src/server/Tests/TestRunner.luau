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

local function contains(haystack: any, needle: any): boolean
	if type(haystack) == "string" and type(needle) == "string" then
		return string.find(haystack, needle, 1, true) ~= nil
	end
	if type(haystack) == "table" then
		for _, item in pairs(haystack) do
			if item == needle then
				return true
			end
		end
	end
	return false
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
			near = function(expected: number, tolerance: number?)
				if type(value) ~= "number" or math.abs(value - expected) > (tolerance or 1e-6) then
					error(string.format("expected about %s, got %s", describeValue(expected), describeValue(value)), 2)
				end
			end,
		},
		-- A substring of a string, or a value inside a table.
		contain = function(needle: any)
			if not contains(value, needle) then
				error(string.format("expected %s to contain %s", describeValue(value), describeValue(needle)), 2)
			end
		end,
		-- value must be a function that errors (optionally with a message containing `part`).
		throw = function(part: string?)
			local ok, err = pcall(value)
			if ok then
				error("expected the function to throw", 2)
			end
			if part and not string.find(tostring(err), part, 1, true) then
				error(string.format("expected an error containing %q, got %s", part, tostring(err)), 2)
			end
		end,
	}
	api.never = {
		to = {
			equal = function(expected: any)
				if value == expected then
					error("expected a value other than " .. describeValue(expected), 2)
				end
			end,
			contain = function(needle: any)
				if contains(value, needle) then
					error(
						string.format("expected %s not to contain %s", describeValue(value), describeValue(needle)),
						2
					)
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

	print(string.format("[DeathsGambit tests] %d passed, %d failed", passed, failed))
	for _, failure in ipairs(failures) do
		warn("[DeathsGambit tests] " .. failure)
	end
	return failed == 0
end

return TestRunner
