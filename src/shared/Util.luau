--!strict
-- Small helpers shared by the server and the clients.

local Util = {}

function Util.shuffle<T>(list: { T }, rng: Random): { T }
	for i = #list, 2, -1 do
		local j = rng:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

function Util.pick<T>(list: { T }, rng: Random): T?
	if #list == 0 then
		return nil
	end
	return list[rng:NextInteger(1, #list)]
end

-- 83 -> "01:23"
function Util.formatClock(seconds: number): string
	local total = math.max(0, math.floor(seconds))
	return string.format("%02d:%02d", total // 60, total % 60)
end

function Util.trim(text: string): string
	return (string.gsub(text, "^%s*(.-)%s*$", "%1"))
end

-- Cleans player-typed text: removes control characters and invalid UTF-8, trims it and
-- cuts it to maxLength characters without splitting a multi-byte character.
function Util.cleanText(text: string, maxLength: number): string
	local cleaned = string.gsub(text, "%c", " ")
	if utf8.len(cleaned) == nil then
		cleaned = string.gsub(cleaned, "[\128-\255]", "")
	end
	cleaned = Util.trim(cleaned)
	local length = utf8.len(cleaned) or #cleaned
	if length > maxLength then
		local cut = utf8.offset(cleaned, maxLength + 1)
		if cut then
			cleaned = string.sub(cleaned, 1, cut - 1)
		else
			cleaned = string.sub(cleaned, 1, maxLength)
		end
	end
	return cleaned
end

function Util.ordinal(n: number): string
	local lastTwo = n % 100
	if lastTwo >= 11 and lastTwo <= 13 then
		return tostring(n) .. "th"
	end
	local last = n % 10
	if last == 1 then
		return tostring(n) .. "st"
	elseif last == 2 then
		return tostring(n) .. "nd"
	elseif last == 3 then
		return tostring(n) .. "rd"
	end
	return tostring(n) .. "th"
end

function Util.deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, item in pairs(value) do
		copy[Util.deepCopy(key)] = Util.deepCopy(item)
	end
	return copy
end

function Util.count(map: { [any]: any }): number
	local n = 0
	for _ in pairs(map) do
		n += 1
	end
	return n
end

return Util
