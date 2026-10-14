--!strict
-- The emote wheel: eight slots a player fills with emotes they own (in the shop's Your look), played
-- from the quick-chat page with a click, a tap or the keys 1 to 8. Saved in the profile as `emoteWheel`,
-- eight clip ids with "" for an empty slot; a profile that never changed it has an empty table and gets
-- DEFAULT. Bought emotes land in the first empty slot.

local QuickChat = require(script.Parent.QuickChat)

local EmoteWheel = {}

EmoteWheel.SLOTS = 8

-- Everyone's emotes, leaving two slots for the first ones bought.
EmoteWheel.DEFAULT = { "wave", "point", "cheer", "laugh", "dance", "shrug", "", "" }

-- The wheel's eight slots from a saved one (a copy; unknown clips become empty).
function EmoteWheel.slots(saved: any): { string }
	local source = if type(saved) == "table" and #saved > 0 then saved else EmoteWheel.DEFAULT
	local slots = {}
	for index = 1, EmoteWheel.SLOTS do
		local id = source[index]
		slots[index] = if type(id) == "string" and QuickChat.emote(id) then id else ""
	end
	return slots
end

-- The slot an emote is in, or nil.
function EmoteWheel.slotOf(saved: any, clip: string): number?
	return table.find(EmoteWheel.slots(saved), clip)
end

-- Puts an emote in a slot (taking it out of any other slot it was in). Returns the new wheel.
function EmoteWheel.set(saved: any, slot: number, clip: string): { string }
	local slots = EmoteWheel.slots(saved)
	if slot < 1 or slot > EmoteWheel.SLOTS or slot ~= math.floor(slot) then
		return slots
	end
	if clip ~= "" then
		for index, id in ipairs(slots) do
			if id == clip then
				slots[index] = ""
			end
		end
	end
	slots[slot] = clip
	return slots
end

-- Puts an emote in the first empty slot if it is not on the wheel yet. Returns the new wheel and the slot
-- (nil when the wheel is full).
function EmoteWheel.place(saved: any, clip: string): ({ string }, number?)
	local slots = EmoteWheel.slots(saved)
	local at = table.find(slots, clip)
	if at then
		return slots, at
	end
	local empty = table.find(slots, "")
	if empty then
		slots[empty] = clip
	end
	return slots, empty
end

-- Does a profile (the client's payload: owned and passes are lists) let its player use this emote?
function EmoteWheel.owns(profile: any, emote: QuickChat.Emote): boolean
	if not emote.item and not emote.pass then
		return true
	end
	if not profile then
		return false
	end
	if emote.pass and table.find(profile.passes or {}, emote.pass) then
		return true
	end
	return emote.item ~= nil and table.find(profile.owned or {}, emote.item) ~= nil
end

return EmoteWheel
