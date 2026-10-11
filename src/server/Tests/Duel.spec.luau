-- The name duel under the lobby's ribs: names leak, the first to write the other's name wins.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Duel = require(Shared:WaitForChild("LobbyGames"):WaitForChild("Duel"))
local NamePools = require(Shared:WaitForChild("NamePools"))

local A, B = "Kenji Mori", "Sakura Takahashi"

local function letters(name: string): number
	return #string.gsub(name, " ", "")
end

local function showing(mask: string): number
	local count = 0
	for _ in string.gmatch(mask, "%a") do
		count += 1
	end
	return count
end

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("Duel", function()
		it("invents two different names from the pools", function()
			local rng = Random.new(11)
			for _ = 1, 40 do
				local a, b = Duel.names(rng)
				expect(a ~= b).to.equal(true)
				for _, name in ipairs({ a, b }) do
					local first, last = string.match(name, "^(%a+) (%a+)$")
					expect(table.find(NamePools.FIRST_NAMES, first) ~= nil).to.equal(true)
					expect(table.find(NamePools.LAST_NAMES, last) ~= nil).to.equal(true)
				end
			end
		end)

		it("shows nothing of either name at first", function()
			local state = Duel.new(A, B, 100)
			expect(Duel.mask(state, 1)).to.equal("_ _ _ _ _   _ _ _ _")
			expect(showing(Duel.mask(state, 2))).to.equal(0)
			expect(Duel.hidden(state, 1)).to.equal(letters(A))
			expect(Duel.due(state, 100)).to.equal(false)
			expect(Duel.due(state, 100 + Duel.LEAK)).to.equal(true)
		end)

		it("leaks a few new letters of each name at a time, until all are out", function()
			local state = Duel.new(A, B, 0)
			local rng = Random.new(3)
			local now = 0
			for round = 1, 8 do
				now += Duel.LEAK
				Duel.leak(state, now, rng)
				expect(Duel.due(state, now)).to.equal(false)
				expect(showing(Duel.mask(state, 1))).to.equal(math.min(round * Duel.LETTERS, letters(A)))
				expect(showing(Duel.mask(state, 2))).to.equal(math.min(round * Duel.LETTERS, letters(B)))
				expect(Duel.hidden(state, 2)).to.equal(letters(B) - math.min(round * Duel.LETTERS, letters(B)))
			end
			expect(Duel.mask(state, 1)).to.equal("K E N J I   M O R I")
			expect(Duel.mask(state, 2)).to.equal("S A K U R A   T A K A H A S H I")
		end)

		it("is won by writing the other's whole name, whatever the capitals and spaces", function()
			local state = Duel.new(A, B, 0)
			expect(Duel.guess(state, 1, "  sakura   TAKAHASHI ", 5)).to.equal("win")
			expect(state.over).to.equal(true)
			expect(Duel.guess(state, 2, A, 6)).to.equal("over")
			expect(Duel.due(state, 99)).to.equal(false)
			expect(Duel.expired(state, 99)).to.equal(false)
		end)

		it("locks out whoever writes a wrong name, for a moment", function()
			local state = Duel.new(A, B, 0)
			-- One's own name is not the other's.
			expect(Duel.guess(state, 1, A, 5)).to.equal("miss")
			expect(Duel.guess(state, 1, B, 5 + Duel.LOCKOUT - 0.1)).to.equal("locked")
			-- The other side is not held up by it.
			expect(Duel.guess(state, 2, "Kenji", 5.5)).to.equal("miss")
			expect(Duel.guess(state, 1, B, 5 + Duel.LOCKOUT)).to.equal("win")
		end)

		it("reads only so much of what is written", function()
			local state = Duel.new(A, B, 0)
			expect(Duel.guess(state, 2, A .. string.rep(" ", Duel.MAX_GUESS) .. "x", 1)).to.equal("win")
			local other = Duel.new(A, B, 0)
			expect(Duel.guess(other, 2, string.rep("x", Duel.MAX_GUESS) .. A, 1)).to.equal("miss")
		end)

		it("is a draw when the time is up", function()
			local state = Duel.new(A, B, 10)
			expect(Duel.expired(state, 10 + Duel.LIMIT - 0.1)).to.equal(false)
			expect(Duel.expired(state, 10 + Duel.LIMIT)).to.equal(true)
		end)
	end)
end
