-- Player profiles upgrade safely: old saves gain every new field, nothing is lost, running a
-- migration twice changes nothing, and a profile from a newer version is never changed.

local Migrations = require(script.Parent.Parent:WaitForChild("Data"):WaitForChild("Migrations"))

local START = 100

-- A profile exactly as the first version of the game saved it.
local function v1Profile()
	return {
		coins = 345,
		xp = 910,
		owned = { hat_cap = true, trail_ink = true },
		equipped = { hat = "hat_cap", trail = "trail_ink" },
		stats = { matches = 12, wins = 5, tasks = 40 },
	}
end

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("Migrations.migrate", function()
		it("gives a new player the defaults", function()
			local data, readOnly = Migrations.migrate(nil, START)
			expect(readOnly).to.equal(false)
			expect(data.v).to.equal(Migrations.CURRENT)
			expect(data.coins).to.equal(START)
			expect(data.settings.music).to.be.near(0.7)
		end)
		it("keeps everything a v1 profile had", function()
			local data = Migrations.migrate(v1Profile(), START)
			expect(data.coins).to.equal(345)
			expect(data.xp).to.equal(910)
			expect(data.owned.hat_cap).to.equal(true)
			expect(data.equipped.trail).to.equal("trail_ink")
			expect(data.stats.matches).to.equal(12)
			expect(data.stats.tasks).to.equal(40)
		end)
		it("adds the new fields to a v1 profile", function()
			local data = Migrations.migrate(v1Profile(), START)
			expect(data.v).to.equal(Migrations.CURRENT)
			expect(data.stats.kills).to.equal(0)
			expect(data.stats.roles.Kira.played).to.equal(0)
			expect(data.mastery.L).to.equal(0)
			expect(type(data.receipts)).to.equal("table")
			expect(data.streak.count).to.equal(0)
			expect(data.settings.hints).to.equal(true)
		end)
		it("changes nothing when run twice", function()
			local once = Migrations.migrate(v1Profile(), START)
			once.coins = 777
			once.settings.music = 0.25
			local twice, readOnly = Migrations.migrate(once, START)
			expect(readOnly).to.equal(false)
			expect(twice.coins).to.equal(777)
			expect(twice.settings.music).to.be.near(0.25)
			expect(twice.v).to.equal(Migrations.CURRENT)
		end)
		it("repairs fields of the wrong type", function()
			local broken = v1Profile()
			broken.coins = "lots"
			broken.stats = "none"
			local data = Migrations.migrate(broken, START)
			expect(data.coins).to.equal(START)
			expect(data.stats.wins).to.equal(0)
		end)
		it("never changes a profile from a newer version", function()
			local future = v1Profile()
			future.v = Migrations.CURRENT + 1
			future.newThing = { kept = true }
			local data, readOnly = Migrations.migrate(future, START)
			expect(readOnly).to.equal(true)
			expect(future.settings).to.equal(nil)
			expect(data.newThing.kept).to.equal(true)
			expect(data.settings ~= nil).to.equal(true)
		end)
	end)
end
