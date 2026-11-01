-- Every task puzzle: built the same from the same seed, solved by its own answer, and not by a
-- wrong one or by junk a client could send.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tasks = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Tasks")
local PuzzleKit = require(Tasks:WaitForChild("PuzzleKit"))
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

	-- Each seed's puzzle has one right answer and the decoys the views promise.
	local SEEDS = 60
	local function each(id: string, fn: (any, any) -> ())
		local def = PuzzleSet.get(id) :: any
		for seed = 1, SEEDS do
			fn(def, def.generate(seed * 104729))
		end
	end

	describe("Puzzle designs", function()
		it("Timeline's stills run in time order by rank, in both clocks", function()
			each("Timeline", function(def, puzzle)
				local times = {}
				local twelve = 0
				for _, frame in ipairs(puzzle.frames) do
					times[frame.rank] = frame.time
					twelve += if frame.twelve then 1 else 0
				end
				for rank = 2, def.COUNT do
					expect(times[rank] > times[rank - 1]).to.equal(true)
				end
				expect(twelve).to.equal(def.COUNT / 2)
			end)
			expect(PuzzleKit.clock(22 * 3600 + 41 * 60 + 7, true)).to.equal("10:41:07 PM")
			expect(PuzzleKit.clock(22 * 3600 + 41 * 60 + 7)).to.equal("22:41:07")
		end)
		it("Enhance has exactly one person on the note, and near misses", function()
			each("Enhance", function(def, puzzle)
				local exact, near = 0, 0
				for i, person in ipairs(puzzle.people) do
					local fit = def.fits(person, puzzle.wanted)
					if fit == 3 then
						exact += 1
						expect(i).to.equal(puzzle.target)
					elseif fit == 2 then
						near += 1
					end
				end
				expect(exact).to.equal(1)
				expect(near >= def.NEAR).to.equal(true)
				expect(#puzzle.people).to.equal(def.COLS * def.ROWS)
			end)
		end)
		it("print puzzles show one true print among different ones", function()
			local function distinct(list, correct, sample)
				local keys = {}
				for i, spec in ipairs(list) do
					local key = PuzzleKit.printKey(spec)
					expect(keys[key]).to.equal(nil)
					keys[key] = true
					expect(key == PuzzleKit.printKey(sample)).to.equal(i == correct)
				end
			end
			each("PrintMatch", function(_, puzzle)
				for _, round in ipairs(puzzle.rounds) do
					distinct(round.choices, round.correct, round.sample)
				end
			end)
			each("Dust", function(_, puzzle)
				distinct(puzzle.cards, puzzle.correct, puzzle.print)
			end)
		end)
		it("Chromatography's pens all differ and one matches", function()
			each("Chromatography", function(_, puzzle)
				local function key(bands)
					local parts = {}
					for _, band in ipairs(bands) do
						table.insert(parts, band[1] .. ":" .. band[2])
					end
					table.sort(parts)
					return table.concat(parts, ",")
				end
				local seen = {}
				for i, pen in ipairs(puzzle.pens) do
					expect(seen[key(pen)]).to.equal(nil)
					seen[key(pen)] = true
					expect(key(pen) == key(puzzle.sample)).to.equal(i == puzzle.correct)
				end
			end)
		end)
		it("Dial's note points at one call", function()
			each("Dial", function(def, puzzle)
				local numbers, unknowns = {}, 0
				for _, entry in ipairs(puzzle.entries) do
					expect(numbers[entry.number]).to.equal(nil)
					numbers[entry.number] = true
					expect(#entry.number).to.equal(11)
					expect(string.sub(entry.number, 1, 3)).to.equal(def.PREFIX)
					unknowns += if entry.name == def.UNKNOWN then 1 else 0
				end
				expect(unknowns >= 2).to.equal(true)
				expect(def.pick(puzzle.entries, puzzle.rule).number).to.equal(puzzle.number)
			end)
		end)
		it("Cipher offers four places of one length and decodes with its key", function()
			each("Cipher", function(def, puzzle)
				local seen = {}
				for _, word in ipairs(puzzle.options) do
					expect(#word).to.equal(#puzzle.word)
					expect(seen[word]).to.equal(nil)
					seen[word] = true
				end
				expect(seen[puzzle.word]).to.equal(true)
				expect(def.shift(puzzle.encoded, -puzzle.key)).to.equal(string.format(def.MESSAGE, puzzle.word))
			end)
		end)
		it("Autopsy charts stay on the chart from either side", function()
			each("Autopsy", function(def, puzzle)
				expect(#def.report(puzzle)).to.equal(def.MARKS)
				for _, region in ipairs(def.REGIONS) do
					local r = def.rect(puzzle, region.id)
					expect(r[1] >= 0 and r[1] + r[3] <= 1.0001).to.equal(true)
				end
			end)
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
