--!strict
-- Matching sets in the shop (the Sets suit): own every piece of one and its title is yours, with a
-- "Set complete" on screen. Pieces are cosmetic ids (Shared/Cosmetics); a set's title is a title item
-- whose source is "set". The last five are emote sets (a few of their pieces are only sold on the days
-- they are in Today's hand). Film Noir, Gilded Age and Seeing Red lost their trail when trails left the game
-- (2026-10-21), and the ties and the white pieces went with the owner's drops (2026-10-21): Film Noir and Gilded Age
-- were made up again from what is left, and Ivory Tower from the new pale pieces (Moth Lantern, Frost Script,
-- Shattered).

local Cosmetics = require(script.Parent.Cosmetics)

local Sets = {}

export type Set = { id: string, name: string, pieces: { string }, title: string }

Sets.LIST = {
	{
		id = "noir",
		name = "Film Noir",
		pieces = { "hat_fedora", "writing_typewriter" },
		title = "title_set_noir",
	},
	{
		id = "ivory",
		name = "Ivory Tower",
		pieces = { "specter_moth", "writing_frost", "death_glass" },
		title = "title_set_ivory",
	},
	{
		id = "gilded",
		name = "Gilded Age",
		pieces = { "book_gold", "hat_tophat" },
		title = "title_set_gilded",
	},
	{
		id = "red",
		name = "Seeing Red",
		pieces = { "hat_fedora_crimson", "book_red" },
		title = "title_set_red",
	},
	{
		id = "ninelives",
		name = "Nine Lives",
		pieces = { "death_ash", "death_strings", "death_crows", "death_stone" },
		title = "title_set_ninelives",
	},
	{
		id = "desk",
		name = "Detective's Desk",
		pieces = {
			"emote_deducing",
			"emote_chair_perch",
			"emote_sugar_tower",
			"emote_two_finger_grip",
			"emote_foot_scratch",
		},
		title = "title_set_desk",
	},
	{
		id = "successors",
		name = "The Successors",
		pieces = { "emote_hair_twirl", "emote_dice_tower", "emote_chocolate_snap" },
		title = "title_set_successors",
	},
	{
		id = "main",
		name = "Main Character",
		pieces = {
			"emote_impossible_lean",
			"emote_nah_id_win",
			"emote_blindfold_lift",
			"emote_menacing_pose",
			"emote_the_long_climb",
		},
		title = "title_set_main",
	},
	{
		id = "online",
		name = "Terminally Online",
		-- (emote_sus_lean is Animatronic Welcome now)
		pieces = {
			"emote_pre_dawn_bonk",
			"emote_mushroom_stroll",
			"emote_rat_dance",
			"emote_jawline_check",
			"emote_the_eyebrow",
			"emote_take_the_l",
			"emote_sus_lean",
		},
		title = "title_set_online",
	},
	{
		id = "floor",
		name = "Floor Filler",
		-- (emote_floss is The Smiling Lord now, emote_jumpstyle Excuse Me, Sir)
		pieces = {
			"emote_floss",
			"emote_the_classic",
			"emote_bounce_pump",
			"emote_griddy",
			"emote_jumpstyle",
			"emote_puppet_pop",
			"emote_office_party",
		},
		title = "title_set_floor",
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
