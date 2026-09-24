--!strict
-- Letter-flash rules: which letters a finished task reveals and how the masked
-- pattern looks, e.g. "H _ R _ _ O   K _ _ _ _ _ _ _".

local Util = require(script.Parent.Util)

local LetterReveal = {}

local WORD_GAP = "   "

-- 1-based indices of every letter (non-space character) in the name.
function LetterReveal.letterIndices(name: string): { number }
	local result = {}
	for i = 1, #name do
		if string.sub(name, i, i) ~= " " then
			table.insert(result, i)
		end
	end
	return result
end

-- Picks `count` letter positions that were not revealed before. When fewer remain, the
-- rest are taken from already revealed positions so a flash always shows letters.
function LetterReveal.pickNew(name: string, revealed: { [number]: boolean }, count: number, rng: Random): { number }
	local fresh = {}
	local old = {}
	for _, index in ipairs(LetterReveal.letterIndices(name)) do
		if revealed[index] then
			table.insert(old, index)
		else
			table.insert(fresh, index)
		end
	end
	Util.shuffle(fresh, rng)
	Util.shuffle(old, rng)
	local picked = {}
	for _, index in ipairs(fresh) do
		if #picked >= count then
			break
		end
		table.insert(picked, index)
	end
	for _, index in ipairs(old) do
		if #picked >= count then
			break
		end
		table.insert(picked, index)
	end
	table.sort(picked)
	return picked
end

-- Masks every letter except the shown positions. Words are separated by a wide gap.
function LetterReveal.mask(name: string, shown: { number }): string
	local visible: { [number]: boolean } = {}
	for _, index in ipairs(shown) do
		visible[index] = true
	end
	local words = {}
	local current = {}
	for i = 1, #name do
		local ch = string.sub(name, i, i)
		if ch == " " then
			table.insert(words, table.concat(current, " "))
			current = {}
		elseif visible[i] then
			table.insert(current, string.upper(ch))
		else
			table.insert(current, "_")
		end
	end
	table.insert(words, table.concat(current, " "))
	return table.concat(words, WORD_GAP)
end

-- A false flash for the follower's tampering: same word lengths as the real name, random
-- letters in random slots. It usually fits no name in the pools.
function LetterReveal.fakeMask(name: string, count: number, rng: Random): string
	local indices = LetterReveal.letterIndices(name)
	Util.shuffle(indices, rng)
	local chars = {}
	for i = 1, #name do
		chars[i] = string.sub(name, i, i)
	end
	local picked = {}
	for i = 1, math.min(count, #indices) do
		local index = indices[i]
		chars[index] = string.char(64 + rng:NextInteger(1, 26))
		table.insert(picked, index)
	end
	return LetterReveal.mask(table.concat(chars), picked)
end

return LetterReveal
