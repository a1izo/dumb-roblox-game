--!strict
-- Name comparison rules shared by the Death Note, the warrant, the meeting chat filter
-- and the paper-note check.

local NameUtil = {}

-- Lowercase, trim and collapse runs of whitespace. Capital letters and extra spaces
-- do not matter when a name is typed; every other difference counts as a mistake.
function NameUtil.normalize(text: string): string
	local lowered = string.lower(text)
	local collapsed = string.gsub(lowered, "%s+", " ")
	return (string.gsub(collapsed, "^%s*(.-)%s*$", "%1"))
end

function NameUtil.fullName(first: string, last: string): string
	return first .. " " .. last
end

-- True when a typed name is exactly "First Last" apart from case and spacing.
function NameUtil.matches(typed: string, first: string, last: string): boolean
	return NameUtil.normalize(typed) == NameUtil.normalize(first .. " " .. last)
end

-- "Haruto  K." -> "harutok"
function NameUtil.lettersOnly(text: string): string
	local lowered = string.lower(text)
	return (string.gsub(lowered, "[^a-z]", ""))
end

-- True when the text contains the full real name, ignoring case, spacing and punctuation,
-- in either name order. Single letters and partial names do not match.
function NameUtil.containsFullName(text: string, first: string, last: string): boolean
	local haystack = NameUtil.lettersOnly(text)
	local forward = string.lower(first .. last)
	local backward = string.lower(last .. first)
	return string.find(haystack, forward, 1, true) ~= nil or string.find(haystack, backward, 1, true) ~= nil
end

return NameUtil
