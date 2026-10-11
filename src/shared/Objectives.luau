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
			line("Gather lost souls for a few coins"),
			line(Terms.f("Chat with other {specters} only")),
		}
	end
	if phase == "Briefing" then
		return { line("Learn your role and your real name") }
	end
	local tasks = tonumber(private.tasksThisRound) or 0
	local lines: { Line } = {}

	if phase == "Investigation" then
		if role == "Kira" then
			table.insert(lines, line("Watch stations: finished case files flash 3 letters of the worker's real name"))
			table.insert(lines, line("Blend in: work or fake a case file (F)", tasks > 0))
		elseif role == "Follower" then
			table.insert(lines, line("Collect real names for {hand}"))
			if private.canTamper then
				table.insert(lines, line("Rig a station's next flash (hold T)"))
			end
			if private.eyes then
				local left = private.eyes.readsLeft or 0
				table.insert(lines, line("Read names with {eyes} (R): {n} left", left <= 0, { n = left }))
			elseif private.canDeal then
				table.insert(lines, line("You may accept {eyes} this round"))
			end
		elseif role == "L" then
			table.insert(lines, line("Read tips and the suspicion meter at {zeroDesk} (Z)"))
			table.insert(lines, line("Work a case file", tasks > 0))
		elseif role == "Watari" then
			table.insert(lines, line("Send your hint to {zero} through the tip box"))
			table.insert(lines, line("Work a case file", tasks > 0))
		else
			table.insert(lines, line("Work a case file at a station (E)", tasks > 0))
			table.insert(lines, line("Watch who works where, and remember the letters"))
		end
		if private.carrying == "note" then
			table.insert(lines, line("You carry a written note: read it (N), drop it (G) or pass it (X)"))
		end
	elseif phase == "DeathNote" then
		if role == "Kira" then
			table.insert(lines, line("Write one full real name in {grimoire}", private.canWrite == false))
		else
			table.insert(lines, line("File your case report: pick your top suspect", private.reported == true))
		end
	elseif phase == "Meeting" then
		table.insert(lines, line("Discuss in chat. Full real names of living players are blocked"))
		if role == "L" then
			table.insert(lines, line("Speak anonymously on {zeroScreen}"))
		end
	elseif phase == "Vote" then
		table.insert(lines, line("Vote someone out, or skip"))
		if role == "L" and not private.warrantUsed then
			table.insert(lines, line("Serve a warrant if you know {hand}'s full real name"))
		end
	end
	return lines
end

return Objectives
