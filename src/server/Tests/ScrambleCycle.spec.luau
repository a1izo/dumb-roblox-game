-- The Tokyo scramble's signal cycle: its phases in order, when stepping onto the crossing is
-- jaywalking, and the two roads' turns.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ScrambleCycle = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ScrambleCycle"))

local EPOCH = 1000

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	local function phaseAt(seconds: number): string
		return (ScrambleCycle.at(EPOCH, EPOCH + seconds))
	end

	describe("ScrambleCycle.at", function()
		it("is 50 seconds long: walk 11, flash 4, cars 32, amber 3", function()
			expect(ScrambleCycle.LENGTH).to.equal(50)
			expect(phaseAt(0)).to.equal("WALK")
			expect(phaseAt(10.9)).to.equal("WALK")
			expect(phaseAt(11)).to.equal("FLASH")
			expect(phaseAt(14.9)).to.equal("FLASH")
			expect(phaseAt(15)).to.equal("CARS")
			expect(phaseAt(46.9)).to.equal("CARS")
			expect(phaseAt(47)).to.equal("AMBER")
			expect(phaseAt(49.9)).to.equal("AMBER")
			expect(phaseAt(50)).to.equal("WALK")
		end)
		it("says how long a phase has run and has left", function()
			local phase, into, left = ScrambleCycle.at(EPOCH, EPOCH + 20)
			expect(phase).to.equal("CARS")
			expect(into).to.be.near(5)
			expect(left).to.be.near(27)
		end)
		it("goes round again, and works before its own start", function()
			expect(phaseAt(50 * 7 + 12)).to.equal("FLASH")
			expect(phaseAt(-1)).to.equal("AMBER")
		end)
	end)

	describe("ScrambleCycle.clearFor", function()
		it("counts down to the cars while the walk lamp is on, and is 0 otherwise", function()
			expect(ScrambleCycle.clearFor(EPOCH, EPOCH)).to.be.near(15)
			expect(ScrambleCycle.clearFor(EPOCH, EPOCH + 10)).to.be.near(5)
			-- Blinking: finish crossing, nobody starts.
			expect(ScrambleCycle.clearFor(EPOCH, EPOCH + 12)).to.equal(0)
			expect(ScrambleCycle.clearFor(EPOCH, EPOCH + 30)).to.equal(0)
		end)
	end)

	describe("ScrambleCycle.jaywalking", function()
		it("never counts on the walk lamp or its blink", function()
			for seconds = 0, 14.75, 0.25 do
				expect(ScrambleCycle.jaywalking(EPOCH, EPOCH + seconds)).to.equal(false)
			end
		end)
		it("gives a 2 second grace when the cars get their light", function()
			expect(ScrambleCycle.jaywalking(EPOCH, EPOCH + 15)).to.equal(false)
			expect(ScrambleCycle.jaywalking(EPOCH, EPOCH + 16.9)).to.equal(false)
			expect(ScrambleCycle.jaywalking(EPOCH, EPOCH + 17)).to.equal(true)
			expect(ScrambleCycle.jaywalking(EPOCH, EPOCH + 46)).to.equal(true)
			expect(ScrambleCycle.jaywalking(EPOCH, EPOCH + 48)).to.equal(true)
		end)
	end)

	describe("ScrambleCycle.roadLamp", function()
		it("gives each road half of the cars' time, ending on amber", function()
			expect(ScrambleCycle.roadLamp(EPOCH, EPOCH + 15, 1)).to.equal("green")
			expect(ScrambleCycle.roadLamp(EPOCH, EPOCH + 27.9, 1)).to.equal("green")
			expect(ScrambleCycle.roadLamp(EPOCH, EPOCH + 28, 1)).to.equal("amber")
			expect(ScrambleCycle.roadLamp(EPOCH, EPOCH + 31, 1)).to.equal("red")
			expect(ScrambleCycle.roadLamp(EPOCH, EPOCH + 30, 2)).to.equal("red")
			expect(ScrambleCycle.roadLamp(EPOCH, EPOCH + 31, 2)).to.equal("green")
			expect(ScrambleCycle.roadLamp(EPOCH, EPOCH + 46.9, 2)).to.equal("green")
			expect(ScrambleCycle.roadLamp(EPOCH, EPOCH + 47, 2)).to.equal("amber")
		end)
		it("never lets both roads go at once, nor any car while people cross", function()
			for seconds = 0, 49.75, 0.25 do
				local now = EPOCH + seconds
				local first = ScrambleCycle.roadLamp(EPOCH, now, 1)
				local second = ScrambleCycle.roadLamp(EPOCH, now, 2)
				expect(first ~= "red" and second ~= "red").to.equal(false)
				local phase = ScrambleCycle.at(EPOCH, now)
				if phase == "WALK" or phase == "FLASH" then
					expect(first).to.equal("red")
					expect(second).to.equal("red")
				end
			end
		end)
	end)

	describe("ScrambleCycle.walkLamp", function()
		it("shows walk, then blinks, then waits", function()
			expect(ScrambleCycle.walkLamp("WALK")).to.equal("walk")
			expect(ScrambleCycle.walkLamp("FLASH")).to.equal("blink")
			expect(ScrambleCycle.walkLamp("CARS")).to.equal("wait")
			expect(ScrambleCycle.walkLamp("AMBER")).to.equal("wait")
		end)
	end)
end
