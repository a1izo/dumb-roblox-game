-- Death's wager: who may bet on what, and when a guess is right.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Wager = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Wager"))

local function situation(overrides)
	local base = {
		active = true,
		phase = "Investigation",
		round = 2,
		living = { [11] = true, [12] = true },
		inCase = { [10] = true, [11] = true, [12] = true, [13] = true },
	}
	for key, value in pairs(overrides or {}) do
		base[key] = value
	end
	return base
end

local GHOST = { dead = true, kiraSide = false }
local SELF = 10

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("Wager.blocker", function()
		it("lets a Deathsinger guess Diavolo once", function()
			local book = Wager.newBook()
			expect(Wager.blocker(GHOST, book, "diavolo", 11, situation(), SELF)).to.equal(nil)
			book.diavolo = 11
			expect(Wager.blocker(GHOST, book, "diavolo", 12, situation(), SELF)).never.to.equal(nil)
		end)
		it("keeps Diavolo's side out of the Diavolo bet but not the votes", function()
			local coven = { dead = true, kiraSide = true }
			local book = Wager.newBook()
			expect(Wager.blocker(coven, book, "diavolo", 11, situation(), SELF)).never.to.equal(nil)
			expect(Wager.blocker(coven, book, "vote", 11, situation(), SELF)).to.equal(nil)
		end)
		it("refuses the living and a closed case", function()
			local book = Wager.newBook()
			expect(Wager.blocker({ dead = false, kiraSide = false }, book, "vote", 11, situation(), SELF)).never.to.equal(
				nil
			)
			expect(Wager.blocker(GHOST, book, "vote", 11, situation({ active = false }), SELF)).never.to.equal(nil)
			expect(Wager.blocker(GHOST, book, "vote", 11, situation({ phase = "Reveal" }), SELF)).never.to.equal(nil)
		end)
		it("closes vote guesses when the vote opens, one per round", function()
			local book = Wager.newBook()
			expect(Wager.blocker(GHOST, book, "vote", 11, situation({ phase = "Vote" }), SELF)).never.to.equal(nil)
			expect(Wager.blocker(GHOST, book, "vote", Wager.NOBODY, situation({ phase = "Meeting" }), SELF)).to.equal(
				nil
			)
			book.votes[2] = 11
			expect(Wager.blocker(GHOST, book, "vote", 12, situation(), SELF)).never.to.equal(nil)
			expect(Wager.blocker(GHOST, book, "vote", 12, situation({ round = 3 }), SELF)).to.equal(nil)
		end)
		it("only takes real targets", function()
			local book = Wager.newBook()
			expect(Wager.blocker(GHOST, book, "vote", 13, situation(), SELF)).never.to.equal(nil) -- dead
			expect(Wager.blocker(GHOST, book, "diavolo", SELF, situation(), SELF)).never.to.equal(nil)
			expect(Wager.blocker(GHOST, book, "diavolo", 99, situation(), SELF)).never.to.equal(nil)
		end)
	end)

	describe("Wager settling", function()
		it("calls a vote right, including no one removed", function()
			expect(Wager.voteRight(11, 11)).to.equal(true)
			expect(Wager.voteRight(11, 12)).to.equal(false)
			expect(Wager.voteRight(Wager.NOBODY, nil)).to.equal(true)
			expect(Wager.voteRight(11, nil)).to.equal(false)
			expect(Wager.voteRight(nil, 11)).to.equal(false)
		end)
		it("calls Diavolo right", function()
			expect(Wager.diavoloRight(11, 11)).to.equal(true)
			expect(Wager.diavoloRight(12, 11)).to.equal(false)
			expect(Wager.diavoloRight(nil, 11)).to.equal(false)
		end)
	end)
end
