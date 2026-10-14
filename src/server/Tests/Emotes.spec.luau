-- Emotes: every shop emote reaches the wheel and quick chat once, sits in a section of the shop, has a
-- sound slot and only known faces; the wheel keeps eight slots, moves an emote rather than copying it, and
-- fills its empty slots with what is bought.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local Anim = Shared:WaitForChild("Anim")
local ClipPlayer = require(Anim:WaitForChild("ClipPlayer"))
local EmoteMedia = require(Shared:WaitForChild("EmoteMedia"))
local EmoteProps = require(Anim:WaitForChild("EmoteProps"))
local ModelCatalog = require(Shared:WaitForChild("ModelCatalog"))
local EmoteWheel = require(Shared:WaitForChild("EmoteWheel"))
local QuickChat = require(Shared:WaitForChild("QuickChat"))

-- The emotes that look like one of a case's signals, and which: lobby-only, and no others.
local SIGNALS = {
	emote_low_battery = "a death",
	emote_reapers_eyes = "the Eyes",
	emote_cuffed_together = "an arrest",
}

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("Emotes", function()
		it("lists every shop emote once, by its clip", function()
			local seen = {}
			for _, emote in ipairs(QuickChat.EMOTES) do
				expect(seen[emote.id]).to.equal(nil)
				seen[emote.id] = true
			end
			for _, item in ipairs(Cosmetics.ofKind("emote")) do
				local emote = QuickChat.emote(item.emote)
				expect(emote ~= nil).to.equal(true)
				expect((emote :: any).item).to.equal(item.id)
				expect((emote :: any).lobbyOnly).to.equal(item.lobbyOnly)
			end
		end)
		it("puts every emote in a section of the shop", function()
			local sections = {}
			for _, category in ipairs(Cosmetics.EMOTE_CATEGORIES) do
				sections[category.id] = true
			end
			for _, item in ipairs(Cosmetics.ofKind("emote")) do
				expect(sections[item.category]).to.equal(true)
			end
		end)
		it("keeps to the lobby exactly the emotes that look like a case's signals", function()
			for _, item in ipairs(Cosmetics.ofKind("emote")) do
				expect(item.lobbyOnly == true).to.equal(SIGNALS[item.id] ~= nil)
			end
		end)
		it("gives every stroll its walk, with a stride, and every stance a loop", function()
			for _, item in ipairs(Cosmetics.ofKind("emote")) do
				if item.stroll then
					local walk = ClipPlayer.get(item.emote .. "Walk")
					expect(walk ~= nil and walk.loop and (walk.stride or 0) > 0).to.equal(true)
					expect((ClipPlayer.get(item.emote) :: any).loop).to.equal(true)
					expect(item.category).to.equal("stroll")
				end
				if item.stance then
					expect((ClipPlayer.get(item.emote) :: any).loop).to.equal(true)
				end
			end
		end)
		it("gives every other ending a clip, found by its item", function()
			for _, item in ipairs(Cosmetics.ofKind("emote")) do
				if item.alt ~= nil then
					expect(ClipPlayer.exists(item.alt)).to.equal(true)
					expect(Cosmetics.emote(item.alt)).to.equal(item)
					expect(type(item.altChance)).to.equal("number")
				end
			end
		end)
		it("holds only props that exist, in clips that exist", function()
			for _, clip in ipairs(EmoteProps.clips()) do
				expect(ClipPlayer.exists(clip)).to.equal(true)
				for _, prop in ipairs(EmoteProps.of(clip)) do
					expect((ModelCatalog :: any)[prop.model] ~= nil).to.equal(true)
					expect(prop.size > 0).to.equal(true)
				end
			end
		end)
		it("has a sound slot for every emote and only known faces", function()
			for _, emote in ipairs(QuickChat.EMOTES) do
				expect(type(EmoteMedia.SOUNDS[emote.id])).to.equal("string")
			end
			for _, item in ipairs(Cosmetics.ITEMS) do
				if item.face ~= nil then
					expect(item.kind).to.equal("emote")
					expect(type(EmoteMedia.FACES[item.face])).to.equal("string")
				end
				if item.lobbyOnly ~= nil then
					expect(item.kind).to.equal("emote")
				end
			end
		end)
	end)

	describe("Emote wheel", function()
		it("starts with everyone's emotes and two empty slots", function()
			local slots = EmoteWheel.slots({})
			expect(#slots).to.equal(EmoteWheel.SLOTS)
			for _, id in ipairs(slots) do
				if id ~= "" then
					local emote = QuickChat.emote(id)
					expect(emote ~= nil and emote.item == nil and emote.pass == nil).to.equal(true)
				end
			end
			expect(slots[7]).to.equal("")
			expect(slots[8]).to.equal("")
		end)
		it("turns anything unknown into an empty slot", function()
			local slots = EmoteWheel.slots({ "wave", "nonsense", 42, "bow" })
			expect(slots[1]).to.equal("wave")
			expect(slots[2]).to.equal("")
			expect(slots[3]).to.equal("")
			expect(slots[4]).to.equal("bow")
			expect(slots[8]).to.equal("")
		end)
		it("moves an emote to a slot rather than copying it", function()
			local slots = EmoteWheel.set({}, 8, "wave")
			expect(slots[8]).to.equal("wave")
			expect(slots[1]).to.equal("")
			slots = EmoteWheel.set(slots, 3, "")
			expect(slots[3]).to.equal("")
			expect(EmoteWheel.set(slots, 9, "bow")[8]).to.equal("wave")
		end)
		it("puts what is bought in the first empty slot, until it is full", function()
			local slots, at = EmoteWheel.place({}, "facepalm")
			expect(at).to.equal(7)
			slots, at = EmoteWheel.place(slots, "salute")
			expect(at).to.equal(8)
			slots, at = EmoteWheel.place(slots, "bow")
			expect(at).to.equal(nil)
			local _, again = EmoteWheel.place(slots, "salute")
			expect(again).to.equal(8)
		end)
		it("knows which emotes a profile may use", function()
			local wave = QuickChat.emote("wave") :: any
			local groove = QuickChat.emote("dance2") :: any
			local coin = QuickChat.emote("coinFlip") :: any
			expect(EmoteWheel.owns(nil, wave)).to.equal(true)
			expect(EmoteWheel.owns({ owned = {}, passes = {} }, groove)).to.equal(false)
			expect(EmoteWheel.owns({ owned = {}, passes = { "emotes" } }, groove)).to.equal(true)
			expect(EmoteWheel.owns({ owned = {}, passes = { "emotes" } }, coin)).to.equal(false)
			expect(EmoteWheel.owns({ owned = { "emote_coin" }, passes = {} }, coin)).to.equal(true)
		end)
	end)
end
