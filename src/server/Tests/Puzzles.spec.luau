-- Every task puzzle: built the same from the same seed, solved by its own answer, and not by a
-- wrong one or by junk a client could send.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tasks = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Tasks")
local PuzzleSet = require(Tasks:WaitForChild("PuzzleSet"))
local TaskTypes = require(Tasks:WaitForChild("TaskTypes"))

local JUNK = { 0, -1, 1.5, "x", {}, { 1, 2, 3 }, { "a" }, true, { {} } }

-- A wrong answer shaped like the right one.
local function wrong(answer: any): any
	if type(answer) == "number" then
		return answer + 1
	elseif type(answer) == "string" then
		return answer .. "0"
	elseif type(answer) == "table" then
		local copy = table.clone(answer)
		if #copy >= 2 and copy[1] ~= copy[2] then
			copy[1], copy[2] = copy[2], copy[1]
			-- A set-style answer is still right after a swap; change a value instead.
			if type(copy[1]) == "number" then
				copy[1] = copy[1] + 100
			end
		elseif #copy >= 1 and type(copy[1]) == "number" then
			copy[1] += 1
		end
		return copy
	end
	return nil
end

local function deepEqual(a: any, b: any): boolean
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return a == b
	end
	for key, value in pairs(a) do
		if not deepEqual(value, b[key]) then
			return false
		end
	end
	for key in pairs(b) do
		if a[key] == nil then
			return false
		end
	end
	return true
end

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("Task types", function()
		it("give every station type four puzzles that exist", function()
			for _, id in ipairs(TaskTypes.LIST) do
				local info = TaskTypes.get(id)
				expect(#info.puzzles).to.equal(4)
				for _, puzzle in ipairs(info.puzzles) do
					expect(PuzzleSet.get(puzzle) ~= nil).to.equal(true)
				end
				expect(TaskTypes.forDrill(info.drill)).to.equal(id)
			end
		end)
		it("fail loudly on an unknown type", function()
			expect(function()
				TaskTypes.get("Nope")
			end).to.throw()
		end)
	end)

	describe("Puzzles", function()
		for _, id in ipairs(PuzzleSet.ids()) do
			it(id .. " is deterministic, solvable and checks its answers", function()
				local def = PuzzleSet.get(id) :: any
				for seed = 1, 50 do
					local a, b = def.generate(seed * 7919), def.generate(seed * 7919)
					expect(deepEqual(a, b)).to.equal(true)
					local answer = def.solve(a)
					expect(def.check(a, answer)).to.equal(true)
					expect(PuzzleSet.verify(id, seed * 7919, answer)).to.equal(true)
					expect(def.check(a, wrong(answer))).to.equal(false)
					expect(PuzzleSet.verify(id, seed * 7919, nil)).to.equal(false)
					for _, junk in ipairs(JUNK) do
						-- (A guess shaped like an answer, { 1, 2, 3 }, is now and then the answer.)
						if not deepEqual(junk, answer) then
							expect(PuzzleSet.verify(id, seed * 7919, junk)).to.equal(false)
						end
					end
				end
			end)
		end
	end)
end
