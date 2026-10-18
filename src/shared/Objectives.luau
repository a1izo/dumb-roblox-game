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
			table.insert(lines, line("Stare at someone up close (R) to learn their real name", known > 0))
			table.insert(lines, line("Write a name in {grimoire} (P). Make sure nobody is watching"))
		elseif role == "Follower" then
			table.insert(lines, line("Stare to learn real names (R), and pass them to {hand} on a note", known > 0))
			table.insert(lines, line("Sabotage: blackout (Z), jam stations (B), barricade (T)"))
			if private.eyes then
				table.insert(lines, line("{Eyes}: about {n} s of life left", nil, { n = private.eyes.lifeLeft }))
			elseif private.canDeal then
				table.insert(lines, line("You may accept {eyes}: fast reads, a short life"))
			end
		else
			table.insert(lines, line("Work case files at the stations (E): fill the task bar", tasks > 0))
			table.insert(lines, line("Watch for glowing eyes and a burning red book"))
			if role == "Watari" then
				table.insert(lines, line("You know {zero}. Keep them alive; if they die, you name the next"))
			end
		end
		if private.carrying == "note" then
			table.insert(lines, line("You carry a written note: read it (N), drop it (G) or pass it (X)"))
		end
	elseif phase == "Meeting" then
		table.insert(lines, line("Talk it over. Full real names of living players are blocked"))
		if private.isAce and not private.arrestUsed then
			table.insert(lines, line("You may arrest one player (K). An innocent costs your life"))
		end
	elseif phase == "Vote" then
		table.insert(lines, line("Vote someone out, or skip"))
		if private.isAce and not private.arrestUsed then
			table.insert(lines, line("You may still arrest one player (K)"))
		end
	end
	return lines
end

return Objectives
