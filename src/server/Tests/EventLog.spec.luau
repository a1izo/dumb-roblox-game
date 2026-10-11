-- The camera clue's sightings: a low sighting (a note passed hand to hand, a jaywalker) never
-- buries a better one, repeats are throttled, and the clue names the place as it was logged.

local Services = script.Parent.Parent:WaitForChild("Services")
local EventLog = require(Services:WaitForChild("EventLog"))

local HERE = Vector3.new(0, 0, 0)

local function player(userId: number)
	return { userId = userId, alias = "Alias" .. userId }
end

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	local realNow = EventLog.now
	local clock = 0

	-- Each test starts from an empty log on a clock it steps by hand.
	local function fresh()
		EventLog.reset()
		clock = 0
		EventLog.now = function()
			return clock
		end
	end

	local function done()
		EventLog.now = realNow
		EventLog.reset()
	end

	describe("EventLog sightings", function()
		it("prefers a normal sighting over a newer low one", function()
			fresh()
			EventLog.sighting(player(1), "dropped a paper note", HERE)
			clock = 5
			EventLog.sighting(player(2), "passed a paper note", HERE, { priority = EventLog.LOW })
			expect(EventLog.takeSighting(90).userId).to.equal(1)
			expect(EventLog.takeSighting(90).userId).to.equal(2)
			expect(EventLog.takeSighting(90)).to.equal(nil)
			done()
		end)
		it("prefers a high sighting over a normal one, and the newest among equals", function()
			fresh()
			EventLog.sighting(player(1), "took a blank sheet of paper", HERE)
			clock = 1
			EventLog.sighting(player(2), "burned something", HERE, { priority = EventLog.HIGH })
			clock = 2
			EventLog.sighting(player(3), "picked up a paper note", HERE)
			expect(EventLog.takeSighting(90).userId).to.equal(2)
			expect(EventLog.takeSighting(90).userId).to.equal(3)
			expect(EventLog.takeSighting(90).userId).to.equal(1)
			done()
		end)
		it("returns a low sighting when it is the only one, with its own place", function()
			fresh()
			EventLog.sighting(player(4), "was jaywalking", HERE, { priority = EventLog.LOW, where = "at the scramble" })
			local sighting = EventLog.takeSighting(90)
			expect(sighting.userId).to.equal(4)
			expect(EventLog.place(sighting)).to.equal("at the scramble")
			done()
		end)
		it("leaves out sightings older than the window", function()
			fresh()
			EventLog.sighting(player(1), "dropped a paper note", HERE)
			clock = 100
			expect(EventLog.takeSighting(90)).to.equal(nil)
			done()
		end)
		it("throttles the same player's same key", function()
			fresh()
			local opts = { priority = EventLog.LOW, key = "jaywalk", every = 20 }
			EventLog.sighting(player(1), "was jaywalking", HERE, opts)
			clock = 10
			EventLog.sighting(player(1), "was jaywalking", HERE, opts)
			EventLog.sighting(player(2), "was jaywalking", HERE, opts)
			clock = 25
			EventLog.sighting(player(1), "was jaywalking", HERE, opts)
			local count = 0
			while EventLog.takeSighting(90) do
				count += 1
			end
			expect(count).to.equal(3)
			done()
		end)
		it("keeps at most 40 low sightings, dropping the oldest", function()
			fresh()
			for i = 1, 45 do
				clock = i * 0.1
				EventLog.sighting(player(i), "passed a paper note", HERE, { priority = EventLog.LOW })
			end
			local count, oldest = 0, math.huge
			while true do
				local sighting = EventLog.takeSighting(90)
				if not sighting then
					break
				end
				count += 1
				oldest = math.min(oldest, sighting.userId)
			end
			expect(count).to.equal(40)
			expect(oldest).to.equal(6)
			done()
		end)
		it("names the place near its area when no place is given", function()
			fresh()
			EventLog.sighting(player(1), "dropped a paper note", HERE)
			local sighting = EventLog.takeSighting(90)
			expect(EventLog.place(sighting)).to.equal("near " .. sighting.area)
			done()
		end)
	end)
end
