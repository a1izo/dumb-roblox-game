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
			expect(table.concat(order, " ")).to.equal("card file write warrant ready")
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
			local old = Migrations.migrate({ coins = 10, stats = { matches = 3 } }, 50)
			expect(old.trial.paid).to.equal(false)
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
