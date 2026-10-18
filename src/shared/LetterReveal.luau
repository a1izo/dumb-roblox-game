--!strict
-- A name with only some letters shown, e.g. "H _ R _ _ O   K _ _ _ _ _ _ _" (the lobby's name duel).

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

return LetterReveal
