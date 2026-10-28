--!strict
-- What a player should be doing right now, as one to three short lines for the HUD. Built
-- only from the player's own role and private state, so it never reveals anything new.

local Terms = require(script.Parent.Terms)

local Objectives = {}

export type Line = { text: string, done: boolean? }

local function line(text: string, done: boolean?, vars: { [string]: any }?): Line
	return { text = Terms.f(text, vars), done = done }
end

-- role: internal role id; phase: phase id; private: the Private payload; living: alive in it.
function Objectives.lines(role: string?, phase: string, private: { [string]: any }, living: boolean): { Line }
	if phase == "Lobby" or phase == "Reveal" or phase == "Intro" or phase == "Outro" or role == nil then
		return {}
	end
	if not living then
		return {
			line(Terms.f("You are a {Specter}. The living can't see you")),
			line(Terms.f("You can still work case files")),
			line(Terms.f("Gather lost souls")),
		}
	end
	if phase == "Briefing" then
		return { line("Check your role and real name") }
	end
	local tasks = tonumber(private.tasksThisRound) or 0
	local known = if type(private.learned) == "table" then #private.learned else 0
	local lines: { Line } = {}

	if phase == "Investigation" then
		if role == "Kira" then
			table.insert(lines, line("Hack a station after someone uses it ({key.use})", known > 0))
			table.insert(lines, line("Write a name in {grimoire} ({key.manual}) unseen"))
		elseif role == "Follower" then
			table.insert(lines, line("Hack stations for names ({key.use}) and pass them to {hand}", known > 0))
			table.insert(lines, line("Cut the lights ({key.blackout}) for cover"))
			if private.eyes then
				table.insert(
					lines,
					line("Stare to read names ({key.stare}). {n}s left", nil, { n = private.eyes.lifeLeft })
				)
			elseif private.canDeal then
				table.insert(lines, line("You can take {eyes} ({key.stare})"))
			end
		else
			table.insert(lines, line("Work case files ({key.use})", tasks > 0))
			table.insert(lines, line("Watch for glowing eyes and a red book"))
			if role == "Watari" then
				table.insert(lines, line("Keep {zero} alive"))
			end
		end
		if private.carrying == "note" then
			table.insert(lines, line("Read ({key.note}) or pass ({key.pass}) your note"))
		end
	elseif phase == "Meeting" then
		table.insert(lines, line("Talk it over"))
		if private.isAce and not private.arrestUsed then
			table.insert(lines, line("Arrest a suspect ({key.arrest})"))
		end
	elseif phase == "Vote" then
		table.insert(lines, line("Vote or skip"))
		if private.isAce and not private.arrestUsed then
			table.insert(lines, line("You can still arrest ({key.arrest})"))
		end
	end
	return lines
end

return Objectives
