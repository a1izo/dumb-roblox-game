-- The Trial's rules: its steps in order, who is offered it, and the one reward paid once.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Trial = require(Shared:WaitForChild("Trial"))

local Migrations = require(script.Parent.Parent:WaitForChild("Data"):WaitForChild("Migrations"))

local REWARD = 100

local function fresh()
	return (Migrations.migrate(nil, 50))
end

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("Trial", function()
		it("walks its steps in order", function()
			local done = {}
			local order = {}
			while true do
				local step = Trial.next(done)
				if not step then
					break
				end
				table.insert(order, step.id)
				done[step.id] = true
			end
			expect(table.concat(order, " ")).to.equal("card file write arrest ready")
			expect(Trial.complete(done)).to.equal(true)
			expect(Trial.complete({ card = true })).to.equal(false)
		end)

		it("uses drills the Academy has", function()
			for _, step in ipairs(Trial.STEPS) do
				if step.drill then
					expect(table.find(Config.TRAINING_DRILLS, step.drill) ~= nil).to.equal(true)
					expect(Trial.stepForDrill(step.drill)).to.equal(step)
				end
			end
			expect(Trial.stepForDrill("eyes")).to.equal(nil)
			-- The arrest is the Academy's "warrant" drill, whose id the profile saves.
			expect(Trial.stepForDrill("warrant").id).to.equal("arrest")
			expect(Trial.stepForDrill("grimoire").id).to.equal("write")
		end)

		it("is offered only to someone who has never played, done it or turned it down", function()
			local profile = { stats = { matches = 0 }, trial = Trial.defaults() }
			expect(Trial.offered(profile)).to.equal(true)
			profile.stats.matches = 1
			expect(Trial.offered(profile)).to.equal(false)
			profile.stats.matches = 0
			profile.trial.skipped = true
			expect(Trial.offered(profile)).to.equal(false)
			profile.trial.skipped = false
			profile.trial.done = true
			expect(Trial.offered(profile)).to.equal(false)
			expect(Trial.offered(nil)).to.equal(false)
			expect(Trial.offered({ stats = { matches = 0 } })).to.equal(false)
		end)

		it("gives every profile a trial record", function()
			local data = fresh()
			expect(data.trial.done).to.equal(false)
			expect(data.trial.skipped).to.equal(false)
			expect(data.trial.paid).to.equal(false)
			expect(data.trial.step).to.equal(0)
			local old = Migrations.migrate({ coins = 10, stats = { matches = 3 } }, 50)
			expect(old.trial.paid).to.equal(false)
			-- A record from before steps were saved gets the field.
			local earlier =
				Migrations.migrate({ coins = 10, trial = { done = false, skipped = true, paid = false } }, 50)
			expect(earlier.trial.step).to.equal(0)
			expect(earlier.trial.skipped).to.equal(true)
			for key, value in pairs(Trial.defaults()) do
				expect(data.trial[key]).to.equal(value)
			end
		end)

		it("counts steps in order and rebuilds them for a rejoin", function()
			expect(Trial.count({})).to.equal(0)
			expect(Trial.count({ card = true, file = true })).to.equal(2)
			-- A gap ends the count: a step done ahead of its turn is not counted yet.
			expect(Trial.count({ card = true, write = true })).to.equal(1)
			local done = Trial.doneUpTo(3)
			expect(Trial.count(done)).to.equal(3)
			expect(Trial.next(done).id).to.equal("arrest")
			expect(Trial.next(Trial.doneUpTo(0)).id).to.equal("card")
			expect(Trial.next(Trial.doneUpTo(99))).to.equal(nil)
		end)

		it("saves progress forward only, and not after it is done", function()
			local data = fresh()
			expect(Trial.advance(data, 2)).to.equal(true)
			expect(data.trial.step).to.equal(2)
			expect(Trial.advance(data, 1)).to.equal(false)
			expect(data.trial.step).to.equal(2)
			expect(Trial.advance(data, 50)).to.equal(true)
			expect(data.trial.step).to.equal(#Trial.STEPS)
			expect(Trial.advance(data, "3")).to.equal(false)
			expect(Trial.advance(data, 0 / 0)).to.equal(false)
			local finished = fresh()
			Trial.finish(finished, REWARD)
			expect(finished.trial.step).to.equal(#Trial.STEPS)
			expect(Trial.advance(finished, 1)).to.equal(false)
		end)

		it("writes every step's lines with no placeholder left over, and never of letters", function()
			local keys = { cardKey = "Hold C", stareKey = "R" }
			for _, step in ipairs(Trial.STEPS) do
				for _, line in ipairs({
					step.line,
					Trial.text(step.how, keys),
					if step.howNext then Trial.text(step.howNext, keys) else "-",
					Trial.text(step.why),
				}) do
					expect(string.find(line, "{", 1, true)).to.equal(nil)
					expect(#line > 0).to.equal(true)
					-- The letter leaks are gone: names are learned by staring.
					expect(string.find(string.lower(line), "letter", 1, true)).to.equal(nil)
				end
			end
			expect(Trial.text(Trial.BY_ID.card.how, keys)).to.equal("Hold C to flip it.")
			-- (the last step's line no longer counts the players a case needs; any count it gives must be the game's)
			local why = string.lower(Trial.text(Trial.BY_ID.ready.why))
			local counts =
				{ "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve" }
			for k, word in ipairs(counts) do
				if string.find(why, word .. " players", 1, true) then
					expect(k + 1).to.equal(Config.MIN_PLAYERS)
				end
			end
			local digits = string.match(why, "(%d+) players")
			if digits then
				expect(tonumber(digits)).to.equal(Config.MIN_PLAYERS)
			end
		end)

		it("teaches the stare before the Manual, as long as a stare takes", function()
			local write = Trial.BY_ID.write
			local how = Trial.text(write.how, { stareKey = "R" })
			expect(string.find(how, "Dummy B", 1, true) ~= nil).to.equal(true)
			-- (a press, then keeping still: letting go of the key does not break a stare)
			expect(string.find(how, "press R", 1, true) ~= nil).to.equal(true)
			expect(string.find(how, tostring(Config.STARE_TIME) .. "s", 1, true) ~= nil).to.equal(true)
			-- The second half (the Manual) has its own line; the other steps are done in one go.
			expect(write.howNext ~= nil).to.equal(true)
			for _, step in ipairs(Trial.STEPS) do
				if step ~= write then
					expect(step.howNext).to.equal(nil)
				end
			end
		end)

		it("knows when the profile is loaded far enough to decide the offer", function()
			expect(Trial.known(nil)).to.equal(false)
			expect(Trial.known({ stats = { matches = 0 } })).to.equal(false)
			expect(Trial.known({ stats = { matches = 0 }, trial = Trial.defaults() })).to.equal(true)
		end)

		it("pays a new player once", function()
			local data = fresh()
			expect(Trial.finish(data, REWARD)).to.equal(REWARD)
			expect(data.coins).to.equal(50 + REWARD)
			expect(data.trial.done).to.equal(true)
			expect(Trial.finish(data, REWARD)).to.equal(0)
			expect(data.coins).to.equal(50 + REWARD)
		end)

		it("does not pay again whoever was paid for the seven drills before", function()
			local data = fresh()
			-- As the old rule left it: every drill done, the reward paid then.
			data.training.done = true
			expect(Trial.paid(data)).to.equal(true)
			expect(Trial.finish(data, REWARD)).to.equal(0)
			expect(data.coins).to.equal(50)
			expect(data.trial.done).to.equal(true)
		end)

		it("still pays for the Trial after the drills were finished under the new rule", function()
			local data = fresh()
			Trial.drillsFinished(data)
			expect(data.training.done).to.equal(true)
			expect(Trial.paid(data)).to.equal(false)
			expect(Trial.finish(data, REWARD)).to.equal(REWARD)
			expect(Trial.finish(data, REWARD)).to.equal(0)
		end)

		it("remembers a skipped offer, and a finished Trial cannot be skipped", function()
			local data = fresh()
			expect(Trial.skip(data)).to.equal(true)
			expect(Trial.skip(data)).to.equal(false)
			expect(data.trial.skipped).to.equal(true)
			-- Skipping the offer does not close the Trial: it can still be begun at the gate, and pays.
			expect(Trial.finish(data, REWARD)).to.equal(REWARD)
			local other = fresh()
			Trial.finish(other, REWARD)
			expect(Trial.skip(other)).to.equal(false)
		end)
	end)
end
