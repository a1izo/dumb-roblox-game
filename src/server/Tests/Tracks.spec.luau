-- Tracks in the snow (the campus): which ground takes a print, how long prints are kept, and what
-- goes over the wire.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Tracks = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Tracks"))

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("Tracks.leavesPrint", function()
		it("takes prints on untrodden snow only", function()
			expect(Tracks.leavesPrint("Snow")).to.equal(true)
			expect(Tracks.leavesPrint("SnowThin")).to.equal(true)
			expect(Tracks.leavesPrint("SnowPath")).to.equal(false)
			expect(Tracks.leavesPrint("Cobble")).to.equal(false)
			expect(Tracks.leavesPrint(nil)).to.equal(false)
			expect(Tracks.leavesPrint(3)).to.equal(false)
		end)
		it("lasts a minute, one print a stride", function()
			expect(Tracks.LIFE).to.equal(60)
			expect(Tracks.STRIDE).to.be.near(2.2)
		end)
	end)

	describe("Tracks.newRecorder", function()
		it("keeps prints in the order they were made", function()
			local recorder = Tracks.newRecorder()
			recorder.add(1, 0, 1, 0, 10)
			recorder.add(2, 0, 2, 0, 11)
			local all = recorder.all(12)
			expect(#all).to.equal(2)
			expect(all[1].x).to.equal(1)
			expect(all[2].x).to.equal(2)
		end)
		it("drops the oldest beyond its cap", function()
			local recorder = Tracks.newRecorder(3)
			for index = 1, 5 do
				recorder.add(index, 0, 0, 0, index)
			end
			local all = recorder.all(6)
			expect(#all).to.equal(3)
			expect(all[1].x).to.equal(3)
		end)
		it("forgets prints older than their life", function()
			local recorder = Tracks.newRecorder(nil, 60)
			recorder.add(1, 0, 0, 0, 0)
			recorder.add(2, 0, 0, 0, 30)
			expect(#recorder.all(59)).to.equal(2)
			local later = recorder.all(61)
			expect(#later).to.equal(1)
			expect(later[1].x).to.equal(2)
			expect(#recorder.all(90)).to.equal(0)
		end)
		it("starts each investigation on fresh snow", function()
			local recorder = Tracks.newRecorder()
			recorder.add(1, 0, 0, 0, 0)
			recorder.clear()
			expect(#recorder.all(1)).to.equal(0)
		end)
		it("keeps no name with a print", function()
			local print_ = Tracks.newRecorder().add(1, 2, 3, 0.5, 9)
			local keys = {}
			for key in pairs(print_) do
				table.insert(keys, key)
			end
			table.sort(keys)
			expect(table.concat(keys, ",")).to.equal("heading,t,x,y,z")
		end)
	end)

	describe("Tracks.encode", function()
		it("brings prints back where they were, with their age", function()
			local prints = {
				{ x = -120.3, y = 0.5, z = 88.125, heading = 1.2, t = 100 },
				{ x = 12, y = -3.25, z = -40.5, heading = 5.9, t = 130 },
			}
			local data = Tracks.encode(prints, 140)
			expect(buffer.len(data)).to.equal(16)
			local back = Tracks.decode(data)
			expect(#back).to.equal(2)
			expect(back[1].x).to.be.near(-120.3, 1 / 8)
			expect(back[1].y).to.be.near(0.5, 1 / 8)
			expect(back[1].z).to.be.near(88.125, 1 / 8)
			expect(back[1].heading).to.be.near(1.2, 0.03)
			expect(back[1].age).to.be.near(40, 0.25)
			expect(back[2].age).to.be.near(10, 0.25)
			expect(back[2].heading).to.be.near(5.9, 0.03)
		end)
		it("is nothing for no prints", function()
			expect(#Tracks.decode(Tracks.encode({}, 0))).to.equal(0)
		end)
	end)
end
