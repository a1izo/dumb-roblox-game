-- Diavolo's death loadout (Shared/DeathLoadout): four slots of custom deaths, no duplicates, only deaths the player
-- owns can be written, and the server's cause for a request never trusts the client's word.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local DeathLoadout = require(Shared:WaitForChild("DeathLoadout"))

local HEART, FROST, LIGHTNING, CHIP, CLOCK =
	"reason_heart", "reason_frost", "reason_lightning", "reason_chip", "reason_clock"

local function joined(slots: { string }): string
	return table.concat(slots, ",")
end

-- An ownership rule that owns exactly these ids.
local function owning(...: string): (Cosmetics.Item) -> boolean
	local ids = {}
	for _, id in ipairs({ ... }) do
		ids[id] = true
	end
	return function(item: Cosmetics.Item): boolean
		return ids[item.id] == true
	end
end

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("DeathLoadout.slots", function()
		it("has four slots, all empty for a profile that never filled it", function()
			expect(DeathLoadout.SLOTS).to.equal(4)
			expect(joined(DeathLoadout.slots({}))).to.equal(",,,")
			expect(joined(DeathLoadout.slots(nil))).to.equal(",,,")
			expect(joined(DeathLoadout.slots("junk"))).to.equal(",,,")
		end)
		it("keeps custom deaths in their slots and drops anything else", function()
			local slots = DeathLoadout.slots({ HEART, "book_red", 7, FROST, LIGHTNING })
			-- (a Manual cover, a number and a fifth entry are not custom deaths in the four slots)
			expect(joined(slots)).to.equal(HEART .. ",,," .. FROST)
		end)
		it("keeps a death in its first slot only", function()
			expect(joined(DeathLoadout.slots({ HEART, HEART, FROST, HEART }))).to.equal(HEART .. ",," .. FROST .. ",")
		end)
		it("does not change the table it was given", function()
			local saved = { HEART, HEART, "", "" }
			DeathLoadout.slots(saved)
			expect(saved[2]).to.equal(HEART)
		end)
	end)

	describe("DeathLoadout.set", function()
		it("puts a death in a slot and takes it out of the slot it was in", function()
			local slots = DeathLoadout.set({ HEART, "", "", "" }, 3, HEART)
			expect(joined(slots)).to.equal(",," .. HEART .. ",")
			expect(DeathLoadout.slotOf(slots, HEART)).to.equal(3)
		end)
		it("replaces what was in the slot", function()
			local slots = DeathLoadout.set({ HEART, FROST, "", "" }, 1, LIGHTNING)
			expect(joined(slots)).to.equal(LIGHTNING .. "," .. FROST .. ",,")
			expect(DeathLoadout.slotOf(slots, HEART)).to.equal(nil)
		end)
		it("empties a slot with an empty id", function()
			expect(joined(DeathLoadout.set({ HEART, FROST, "", "" }, 2, ""))).to.equal(HEART .. ",,,")
		end)
		it("refuses a slot that does not exist, and an id that is not a custom death", function()
			local before = { HEART, "", "", "" }
			for _, slot in ipairs({ 0, 5, -1, 1.5, math.huge }) do
				expect(joined(DeathLoadout.set(before, slot, FROST))).to.equal(HEART .. ",,,")
			end
			expect(joined(DeathLoadout.set(before, 2, "book_red"))).to.equal(HEART .. ",,,")
			expect(joined(DeathLoadout.set(before, 2, "nothing"))).to.equal(HEART .. ",,,")
		end)
	end)

	describe("DeathLoadout.place and remove", function()
		it("places a bought death in the first empty slot", function()
			local slots, at = DeathLoadout.place({ HEART, "", FROST, "" }, LIGHTNING)
			expect(at).to.equal(2)
			expect(joined(slots)).to.equal(HEART .. "," .. LIGHTNING .. "," .. FROST .. ",")
		end)
		it("leaves a death that is in a slot where it is", function()
			local slots, at = DeathLoadout.place({ HEART, FROST, "", "" }, FROST)
			expect(at).to.equal(2)
			expect(joined(slots)).to.equal(HEART .. "," .. FROST .. ",,")
		end)
		it("gives no slot when the four are full, and changes nothing", function()
			local full = { HEART, FROST, LIGHTNING, CHIP }
			local slots, at = DeathLoadout.place(full, CLOCK)
			expect(at).to.equal(nil)
			expect(joined(slots)).to.equal(joined(full))
		end)
		it("places no one who is not a custom death", function()
			local slots, at = DeathLoadout.place({}, "book_red")
			expect(at).to.equal(nil)
			expect(joined(slots)).to.equal(",,,")
		end)
		it("removes a death and keeps the others where they are", function()
			expect(joined(DeathLoadout.remove({ HEART, FROST, LIGHTNING, "" }, FROST))).to.equal(
				HEART .. ",," .. LIGHTNING .. ","
			)
		end)
	end)

	describe("DeathLoadout.usable", function()
		it("lists the equipped deaths a player owns, in slot order", function()
			local saved = { FROST, HEART, "", LIGHTNING }
			local list = DeathLoadout.usable(saved, owning(HEART, FROST, LIGHTNING))
			expect(#list).to.equal(3)
			expect(list[1].id).to.equal(FROST)
			expect(list[2].id).to.equal(HEART)
			expect(list[3].id).to.equal(LIGHTNING)
		end)
		it("leaves out an equipped death the player does not own", function()
			local list = DeathLoadout.usable({ HEART, FROST, "", "" }, owning(FROST))
			expect(#list).to.equal(1)
			expect(list[1].id).to.equal(FROST)
		end)
		it("leaves out a death that is owned but in no slot", function()
			expect(#DeathLoadout.usable({ HEART, "", "", "" }, owning(HEART, FROST, LIGHTNING, CHIP, CLOCK))).to.equal(
				1
			)
		end)
		it("never lists more than four", function()
			local all = owning(HEART, FROST, LIGHTNING, CHIP, CLOCK)
			expect(#DeathLoadout.usable({ HEART, FROST, LIGHTNING, CHIP, CLOCK }, all)).to.equal(4)
		end)
	end)

	describe("DeathLoadout.resolve (the server's word on a cause)", function()
		local heart = Cosmetics.byId(HEART) :: Cosmetics.Item
		local frost = Cosmetics.byId(FROST) :: Cosmetics.Item
		local usable = { heart }
		it("passes the plain causes through", function()
			for _, cause in ipairs(Config.DEATH_CAUSES) do
				expect(DeathLoadout.resolve({}, Config.DEATH_CAUSES, cause)).to.equal(cause)
			end
		end)
		it("passes the cause of an equipped, owned death", function()
			expect(DeathLoadout.resolve(usable, Config.DEATH_CAUSES, heart.cause)).to.equal(heart.cause)
		end)
		it("turns a death that is not equipped or not owned into a heart attack", function()
			-- (frost is neither in the usable list: not in a slot, or not owned, the list cannot tell and does not need to)
			expect(DeathLoadout.resolve(usable, Config.DEATH_CAUSES, frost.cause)).to.equal("Heart attack")
			expect(DeathLoadout.resolve({}, Config.DEATH_CAUSES, heart.cause)).to.equal("Heart attack")
		end)
		it("turns anything that is not a cause into a heart attack", function()
			for _, asked in ipairs({ "Falling piano", "", 12, true }) do
				expect(DeathLoadout.resolve(usable, Config.DEATH_CAUSES, asked)).to.equal("Heart attack")
			end
			expect(DeathLoadout.resolve(usable, Config.DEATH_CAUSES, nil)).to.equal("Heart attack")
			expect(DeathLoadout.resolve(usable, Config.DEATH_CAUSES, { heart.cause })).to.equal("Heart attack")
		end)
		it("asks for ownership and the slot together through usable", function()
			-- the whole rule as the server runs it: equipped, owned, then asked
			local saved = { HEART, "", "", "" }
			local owned = owning(HEART, FROST)
			local function causeFor(asked: string): string
				return DeathLoadout.resolve(DeathLoadout.usable(saved, owned), Config.DEATH_CAUSES, asked)
			end
			expect(causeFor(heart.cause)).to.equal(heart.cause)
			expect(causeFor(frost.cause)).to.equal("Heart attack") -- owned, not equipped
			saved = DeathLoadout.set(saved, 2, FROST)
			expect(causeFor(frost.cause)).to.equal(frost.cause)
			owned = owning(HEART)
			expect(causeFor(frost.cause)).to.equal("Heart attack") -- equipped, not owned
		end)
	end)

	describe("the shop's custom deaths", function()
		it("are all custom deaths a slot accepts", function()
			for _, item in ipairs(Cosmetics.ofKind("reason")) do
				expect(DeathLoadout.slotOf(DeathLoadout.set({}, 1, item.id), item.id)).to.equal(1)
				expect(type(item.cause)).to.equal("string")
			end
		end)
		it("each have a cause of their own, so a written cause names one death", function()
			local seen = {}
			for _, item in ipairs(Cosmetics.ofKind("reason")) do
				expect(seen[item.cause]).to.equal(nil)
				seen[item.cause] = true
				expect(table.find(Config.DEATH_CAUSES, item.cause)).to.equal(nil)
			end
		end)
	end)
end
