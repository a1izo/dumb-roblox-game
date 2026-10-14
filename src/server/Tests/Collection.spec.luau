-- New stock: the collection milestones (counted from emote items, each paid once, in order) and the emote
-- sets (every piece an emote that is sold, no emote in two of them, each with its own set title).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local Collection = require(Shared:WaitForChild("Progression"):WaitForChild("Collection"))
local Sets = require(Shared:WaitForChild("Sets"))

local EMOTE_SETS = { "desk", "successors", "main", "online", "floor" }

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("Collection", function()
		it("names titles that exist, at rising counts the catalog can reach", function()
			expect(Collection.valid()).to.equal(true)
			expect(#Collection.MILESTONES).to.equal(3)
		end)
		it("counts only emote items", function()
			local count = Collection.count(function(item: Cosmetics.Item): boolean
				return item.kind == "emote" or item.kind == "hat"
			end)
			expect(count).to.equal(#Cosmetics.ofKind("emote"))
		end)
		it("pays each milestone once, the ones reached only", function()
			local owned = {}
			local function ownsTitle(id: string): boolean
				return owned[id] == true
			end
			expect(#Collection.due(9, ownsTitle)).to.equal(0)
			local due = Collection.due(26, ownsTitle)
			expect(#due).to.equal(2)
			expect(due[1].title).to.equal("title_c_mover")
			expect(due[2].coins).to.equal(250)
			owned.title_c_mover = true
			owned.title_c_showstopper = true
			expect(#Collection.due(26, ownsTitle)).to.equal(0)
			expect(#Collection.due(50, ownsTitle)).to.equal(1)
		end)
		it("names the next milestone, and none past the last", function()
			expect((Collection.nextAfter(0) :: any).count).to.equal(10)
			expect((Collection.nextAfter(10) :: any).count).to.equal(25)
			expect(Collection.nextAfter(50)).to.equal(nil)
			expect((Collection.ofTitle("title_c_living_legend") :: any).coins).to.equal(750)
			expect(Collection.ofTitle("title_detective")).to.equal(nil)
		end)
	end)

	describe("Emote sets", function()
		it("makes each of its pieces a sold emote, in one set only, with its own title", function()
			local inSet = {}
			local titles = {}
			for _, id in ipairs(EMOTE_SETS) do
				local found = nil
				for _, set in ipairs(Sets.LIST) do
					if set.id == id then
						found = set
					end
				end
				expect(found ~= nil).to.equal(true)
				local set = found :: Sets.Set
				expect(#set.pieces >= 3).to.equal(true)
				expect(titles[set.title]).to.equal(nil)
				titles[set.title] = true
				for _, piece in ipairs(set.pieces) do
					local item = Cosmetics.byId(piece)
					expect(item ~= nil and item.kind == "emote").to.equal(true)
					expect((item :: any).price ~= nil).to.equal(true)
					expect(inSet[piece]).to.equal(nil)
					inSet[piece] = true
				end
			end
			expect(Sets.valid()).to.equal(true)
		end)
		it("completes an emote set with its last piece", function()
			local owned = {
				emote_hair_twirl = true,
				emote_dice_tower = true,
			}
			local function owns(id: string): boolean
				return owned[id] == true
			end
			expect(#Sets.completed(owns)).to.equal(0)
			owned.emote_chocolate_snap = true
			local done = Sets.completed(owns)
			expect(#done).to.equal(1)
			expect(done[1].title).to.equal("title_set_successors")
		end)
	end)
end
