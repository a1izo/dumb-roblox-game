--!strict
-- Diavolo's death loadout: four slots a player fills with custom deaths they own (the shop's Your look and the
-- inventory's Custom deaths page), and writes from in a match. Saved in the profile as `deathLoadout`, four item ids
-- with "" for an empty slot; a profile that never filled it has an empty table. A death takes one slot at most.
--
-- The choice is made per name (the Manual already asks for a cause with every name, and the three plain causes sit
-- beside the four equipped deaths there): the Manual lists what the server says Diavolo may write, and the server
-- checks the choice again when the name arrives (`resolve`). A death that is not in a slot, or not owned, never
-- plays: the write falls back to the first plain cause, as a request for a cause that does not exist always did.
-- Bought deaths land in the first empty slot (as bought emotes do on the wheel, Shared/EmoteWheel).

local Cosmetics = require(script.Parent.Cosmetics)

local DeathLoadout = {}

DeathLoadout.SLOTS = 4

-- A custom death's id, or nil for anything else (a plain string that names another kind of item, a stray value).
local function reasonId(id: any): string?
	if type(id) ~= "string" then
		return nil
	end
	local item = Cosmetics.byId(id)
	return if item and item.kind == "reason" then id else nil
end

-- The four slots from a saved loadout (a copy): an id that is not a custom death, or is already in an earlier slot,
-- becomes empty.
function DeathLoadout.slots(saved: any): { string }
	local slots = {}
	local seen: { [string]: boolean } = {}
	for index = 1, DeathLoadout.SLOTS do
		local id = reasonId(if type(saved) == "table" then saved[index] else nil)
		if id and not seen[id] then
			seen[id] = true
			slots[index] = id
		else
			slots[index] = ""
		end
	end
	return slots
end

-- The slot a death is in, or nil.
function DeathLoadout.slotOf(saved: any, id: string): number?
	return table.find(DeathLoadout.slots(saved), id)
end

-- Puts a death in a slot (taking it out of any other slot it was in); "" empties the slot. An id that is not a
-- custom death, or a slot that does not exist, changes nothing. Returns the new loadout.
function DeathLoadout.set(saved: any, slot: number, id: string): { string }
	local slots = DeathLoadout.slots(saved)
	if slot < 1 or slot > DeathLoadout.SLOTS or slot ~= math.floor(slot) then
		return slots
	end
	if id == "" then
		slots[slot] = ""
		return slots
	end
	if not reasonId(id) then
		return slots
	end
	for index, other in ipairs(slots) do
		if other == id then
			slots[index] = ""
		end
	end
	slots[slot] = id
	return slots
end

-- Takes a death out of its slot. Returns the new loadout.
function DeathLoadout.remove(saved: any, id: string): { string }
	local slots = DeathLoadout.slots(saved)
	for index, other in ipairs(slots) do
		if other == id then
			slots[index] = ""
		end
	end
	return slots
end

-- Puts a death in the first empty slot if it is not in one yet. Returns the new loadout and its slot (nil when the
-- four are full, or it is not a custom death).
function DeathLoadout.place(saved: any, id: string): ({ string }, number?)
	local slots = DeathLoadout.slots(saved)
	if not reasonId(id) then
		return slots, nil
	end
	local at = table.find(slots, id)
	if at then
		return slots, at
	end
	local empty = table.find(slots, "")
	if empty then
		slots[empty] = id
	end
	return slots, empty
end

-- The deaths the player can write now: those in a slot that they own, in slot order. `owns(item)` is the caller's
-- ownership rule (the server's CosmeticsService.owns).
function DeathLoadout.usable(saved: any, owns: (Cosmetics.Item) -> boolean): { Cosmetics.Item }
	local list = {}
	for _, id in ipairs(DeathLoadout.slots(saved)) do
		local item = if id ~= "" then Cosmetics.byId(id) else nil
		if item and owns(item) then
			table.insert(list, item)
		end
	end
	return list
end

-- The cause to write for a request: one of the plain causes as asked, or the cause of one of the `usable` deaths as
-- asked; anything else (a death not equipped, not owned, not real, a wrong type) is the first plain cause.
function DeathLoadout.resolve(usable: { Cosmetics.Item }, plain: { string }, asked: any): string
	if type(asked) == "string" then
		if table.find(plain, asked) then
			return asked
		end
		for _, item in ipairs(usable) do
			if item.cause == asked then
				return asked
			end
		end
	end
	return plain[1]
end

return DeathLoadout
