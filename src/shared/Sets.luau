--!strict
-- Matching sets in the shop (the Sets suit): own every piece of one and its title is yours, with a
-- "Set complete" on screen. Pieces are cosmetic ids (Shared/Cosmetics); a set's title is a title item
-- whose source is "set".

local Cosmetics = require(script.Parent.Cosmetics)

local Sets = {}

export type Set = { id: string, name: string, pieces: { string }, title: string }

Sets.LIST = {
	{
		id = "noir",
		name = "Film Noir",
		pieces = { "hat_fedora", "tie_black", "trail_smoke" },
		title = "title_set_noir",
	},
	{
		id = "ivory",
		name = "Ivory Tower",
		pieces = { "hat_fedora_white", "tie_white", "book_white" },
		title = "title_set_ivory",
	},
	{
		id = "gilded",
		name = "Gilded Age",
		pieces = { "tie_gold", "trail_gold", "book_gold" },
		title = "title_set_gilded",
	},
	{
		id = "red",
		name = "Seeing Red",
		pieces = { "hat_fedora_crimson", "trail_crimson", "book_red" },
		title = "title_set_red",
	},
	{
		id = "ninelives",
		name = "Nine Lives",
		pieces = { "death_ash", "death_strings", "death_crows", "death_stone" },
		title = "title_set_ninelives",
	},
} :: { Set }

-- How many of a set's pieces `owns` says are owned.
function Sets.progress(set: Set, owns: (string) -> boolean): number
	local count = 0
	for _, id in ipairs(set.pieces) do
		if owns(id) then
			count += 1
		end
	end
	return count
end

-- The sets now complete whose title is not owned yet (owns tells what is owned, titles included).
function Sets.completed(owns: (string) -> boolean): { Set }
	local list = {}
	for _, set in ipairs(Sets.LIST) do
		if not owns(set.title) and Sets.progress(set, owns) == #set.pieces then
			table.insert(list, set)
		end
	end
	return list
end

-- The sets an item is a piece of.
function Sets.of(itemId: string): { Set }
	local list = {}
	for _, set in ipairs(Sets.LIST) do
		if table.find(set.pieces, itemId) then
			table.insert(list, set)
		end
	end
	return list
end

-- Every piece and title of every set exists in the catalog (for the specs).
function Sets.valid(): boolean
	for _, set in ipairs(Sets.LIST) do
		local title = Cosmetics.byId(set.title)
		if not title or title.kind ~= "title" or title.source ~= "set" then
			return false
		end
		for _, id in ipairs(set.pieces) do
			if not Cosmetics.byId(id) then
				return false
			end
		end
	end
	return true
end

return Sets
