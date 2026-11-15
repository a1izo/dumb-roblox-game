--!strict
-- The four death slots under a custom death you own (Shared/DeathLoadout), in the shop's Your look and the inventory:
-- numbered buttons in a row, the slot holding this death lit. A click puts the death in that slot (the one that was
-- there leaves the loadout), a click on the lit one takes it out. Diavolo writes from the four in a case.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local DeathLoadout = require(Shared:WaitForChild("DeathLoadout"))
local Net = require(Shared:WaitForChild("Net"))

local Kit = require(script.Parent.Parent.Kit)

local ShopRequest = Net.event("ShopRequest")

local DeathSlots = {}

-- A card's chip for a death in a slot ("Slot 2"), or nil when it is in none.
function DeathSlots.chip(profile: any, item: Cosmetics.Item): { text: string, filled: boolean }?
	local at = if profile then DeathLoadout.slotOf(profile.deathLoadout, item.id) else nil
	return if at then { text = "Slot " .. at, filled = true } else nil
end

-- Builds the four buttons into `parent`, a row as tall as a button, starting `from` of the way across it (0 to 1) with
-- `gap` pixels between. Returns the note for under the row.
function DeathSlots.build(parent: Instance, profile: any, item: Cosmetics.Item, from: number, gap: number): string
	local at = DeathLoadout.slotOf(profile.deathLoadout, item.id)
	local row = Kit.frame({
		Name = "DeathSlots",
		Position = UDim2.new(from, if from > 0 then gap / 2 else 0, 0, 0),
		Size = UDim2.new(1 - from, if from > 0 then -gap / 2 else 0, 1, 0),
		Parent = parent,
	})
	Kit.list(row, 4, true)
	local slots = DeathLoadout.SLOTS
	for index = 1, slots do
		local here = index == at
		Kit.button({
			text = tostring(index),
			variant = if here then "primary" else "secondary",
			size = "s",
			Size = UDim2.new(1 / slots, -4 * (slots - 1) / slots, 1, 0),
			LayoutOrder = index,
			Parent = row,
		}, function()
			ShopRequest:FireServer({ action = "deathSlot", itemId = item.id, slot = index, clear = here })
		end)
	end
	return if at then string.format("In slot %d. Click it again to remove.", at) else "Pick a death slot."
end

return DeathSlots
