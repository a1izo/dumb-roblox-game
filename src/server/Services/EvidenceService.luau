-- The public evidence board. Every completed case-file task posts here with the
-- worker's alias, the station, the time and the clue. Nobody can hide or delay an entry.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local Match = require(script.Parent.Match)

local EvidenceRemote = Net.event("Evidence")
local GetEvidence = Net.func("GetEvidence")

local EvidenceService = {}

local entries = {}
local BOARD_LINES = 7

local function boardText(): string
	if #entries == 0 then
		return "No evidence yet.\nFinish case files to post clues."
	end
	local lines = {}
	for i = #entries, math.max(1, #entries - BOARD_LINES + 1), -1 do
		local entry = entries[i]
		table.insert(lines, string.format("[R%d %s] %s @ %s: %s", entry.round, entry.clock, entry.alias, entry.station, entry.clue))
	end
	return table.concat(lines, "\n")
end

local function updateBoards()
	local map = Match.map
	if not map then
		return
	end
	local text = boardText()
	for _, label in ipairs(map.boardLabels) do
		label.Text = text
	end
end

function EvidenceService.reset()
	entries = {}
	updateBoards()
end

-- entry: { alias, station, clue }
function EvidenceService.post(alias: string, station: string, clue: string)
	local entry = {
		id = #entries + 1,
		round = Match.round,
		clock = Match.clock(),
		alias = alias,
		station = station,
		clue = clue,
	}
	table.insert(entries, entry)
	EvidenceRemote:FireAllClients(entry)
	updateBoards()
end

function EvidenceService.count(): number
	return #entries
end

function EvidenceService.init()
	GetEvidence.OnServerInvoke = function()
		if not Match.active then
			return {}
		end
		return entries
	end
end

return EvidenceService
