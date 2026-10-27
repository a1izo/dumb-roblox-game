--!strict
-- Every puzzle definition by id (the modules in Tasks/Puzzles).

local PuzzleKit = require(script.Parent.PuzzleKit)

local PuzzleSet = {}

-- The least time a case file takes to solve, unless its puzzle says otherwise (Def.minSeconds).
PuzzleSet.MIN_SECONDS = 2.5

local defs: { [string]: PuzzleKit.Def } = {}
for _, module in ipairs(script.Parent:WaitForChild("Puzzles"):GetChildren()) do
	if module:IsA("ModuleScript") then
		local def = require(module) :: any
		defs[def.id] = def
	end
end

function PuzzleSet.get(id: string): PuzzleKit.Def?
	return defs[id]
end

-- The least time anyone could really solve this puzzle in (seconds from the case file opening).
function PuzzleSet.minSeconds(id: string): number
	local def = defs[id]
	return if def and type(def.minSeconds) == "number" then def.minSeconds else PuzzleSet.MIN_SECONDS
end

function PuzzleSet.ids(): { string }
	local list = {}
	for id in pairs(defs) do
		table.insert(list, id)
	end
	table.sort(list)
	return list
end

-- Builds the puzzle and checks an answer, never erroring on bad input.
function PuzzleSet.verify(id: string, seed: number, answer: any): boolean
	local def = defs[id]
	if not def or type(seed) ~= "number" then
		return false
	end
	local ok, result = pcall(function()
		return def.check(def.generate(seed), answer)
	end)
	return ok and result == true
end

return PuzzleSet
