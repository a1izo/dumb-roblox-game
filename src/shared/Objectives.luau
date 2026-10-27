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
			line(Terms.f("You are a {Specter}: fly about the case, unseen by the living")),
			line(Terms.f("Bureau? You can still work case files for {agency}")),
			line(Terms.f("Gather lost souls, and chat with other {specters} only")),
		}
	end
	if phase == "Briefing" then
		return { line("Learn your role and your real name") }
	end
	local tasks = tonumber(private.tasksThisRound) or 0
	local known = if type(private.learned) == "table" then #private.learned else 0
	local lines: { Line } = {}

	if phase == "Investigation" then
		if role == "Kira" then
			table.insert(
				lines,
				line("Hack a station ({key.use}) just after someone uses it: learn their name", known > 0)
			)
			table.insert(lines, line("Write a name in {grimoire} ({key.manual}). Make sure nobody is watching"))
		elseif role == "Follower" then
			table.insert(
				lines,
				line("Hack stations ({key.use}) for real names, and pass them to {hand} on a note", known > 0)
			)
			table.insert(
				lines,
				line("Sabotage: blackout ({key.blackout}), jam stations ({key.jam}), barricade ({key.barricade})")
			)
			if private.eyes then
				table.insert(
					lines,
					line(
						"{Eyes}: stare to read names ({key.stare}), {n} s of life left",
						nil,
						{ n = private.eyes.lifeLeft }
					)
				)
			elseif private.canDeal then
				table.insert(lines, line("You may accept {eyes}: read names at a glance, die in 90 s"))
			end
		else
			table.insert(lines, line("Work case files at the stations ({key.use}): fill the task bar", tasks > 0))
			table.insert(lines, line("Watch for glowing eyes and a burning red book"))
			if role == "Watari" then
				table.insert(lines, line("You know {zero}. Keep them alive; if they die, you name the next"))
			end
		end
		if private.carrying == "note" then
			table.insert(
				lines,
				line("You carry a written note: read it ({key.note}), drop it ({key.drop}) or pass it ({key.pass})")
			)
		end
	elseif phase == "Meeting" then
		table.insert(lines, line("Talk it over. Full real names of living players are blocked"))
		if private.isAce and not private.arrestUsed then
			table.insert(lines, line("You may arrest one player ({key.arrest}). An innocent costs your life"))
		end
	elseif phase == "Vote" then
		table.insert(lines, line("Vote someone out, or skip"))
		if private.isAce and not private.arrestUsed then
			table.insert(lines, line("You may still arrest one player ({key.arrest})"))
		end
	end
	return lines
end

return Objectives
